# Claude デスクトップアプリ(Code タブ)を API キーで使うためのセットアップ(チーム配布用)
# 使い方: setup.cmd をダブルクリック。キーを消すときは remove.cmd
# キーはファイル・レジストリ・ログに書かない。アプリへはクリップボード経由で本人が貼る。
param(
    [switch]$Remove,
    [string]$Key,
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    [switch]$SkipEnv,
    [switch]$LoadOnly   # 試験用: 関数だけ読み込んで止まる(. .\setup.ps1 -LoadOnly)
)

$ErrorActionPreference = 'Stop'
$keyName = 'ANTHROPIC_API_KEY'            # 旧版(ターミナル版)が環境変数に登録していた名前
$minDesktopVersion = [version]'3.1623.1'  # これより前の版には「Use your Claude API account」が無い
$downloadPage = 'https://claude.com/download'
$script:InstalledVia = $null   # winget で入れたら 'winget'

function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "   注意: $msg" -ForegroundColor Yellow }

# ---- デスクトップアプリの判定 ----

# 入っていれば @{ Kind; Target; Version } を返す。Target は起動に使う AppID か exe のパス
function Find-ClaudeDesktop {
    # 1. MSIX(今の公式インストーラの入れ方)
    $pkg = $null
    try {
        $pkg = Get-AppxPackage -Name 'Claude' -ErrorAction Stop |
            Where-Object { $_.Publisher -like '*Anthropic*' } | Select-Object -First 1
    } catch { }
    if ($pkg) {
        $appId = 'Claude'
        try {
            $ids = @(($pkg | Get-AppxPackageManifest -ErrorAction Stop).Package.Applications.Application | ForEach-Object { $_.Id })
            if ($ids.Count -gt 0 -and $ids -notcontains 'Claude') { $appId = $ids[0] }
        } catch { }
        return [pscustomobject]@{ Kind = 'msix'; Target = "$($pkg.PackageFamilyName)!$appId"; Version = "$($pkg.Version)" }
    }
    # 2. 旧版の .exe インストーラ
    $exe = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
    if (Test-Path -LiteralPath $exe) {
        return [pscustomobject]@{ Kind = 'exe'; Target = $exe; Version = $null }
    }
    # 3. スタートメニュー
    $start = $null
    try {
        $start = Get-StartApps -ErrorAction Stop | Where-Object { $_.Name -eq 'Claude' } | Select-Object -First 1
    } catch { }
    if ($start) {
        return [pscustomobject]@{ Kind = 'startmenu'; Target = $start.AppID; Version = $null }
    }
    return $null
}

function Test-DesktopVersionOld($version) {
    if (-not $version) { return $false }
    try { return ([version]$version -lt $minDesktopVersion) } catch { return $false }
}

function Start-ClaudeDesktop($app) {
    if ($app.Kind -eq 'exe') {
        Start-Process -FilePath $app.Target
    } else {
        Start-Process -FilePath 'explorer.exe' -ArgumentList "shell:AppsFolder\$($app.Target)"
    }
}

# ---- インストール ----

# Win32_Processor.Architecture: 9 = x64, 12 = ARM64(5 を返す ARM 機もある)
function ConvertTo-CpuArch($CimArch, [string]$EnvArch) {
    if ($null -ne $CimArch) {
        switch ([int]$CimArch) { 9 { return 'x64' } 12 { return 'arm64' } 5 { return 'arm64' } }
    }
    switch ($EnvArch) { 'AMD64' { return 'x64' } 'ARM64' { return 'arm64' } }
    return $null
}

function Get-CpuArch {
    $cim = $null
    try { $cim = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Architecture } catch { }
    $envArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    return (ConvertTo-CpuArch $cim $envArch)
}

function Get-InstallerUrl([string]$Arch) {
    return "https://claude.ai/api/desktop/win32/$Arch/setup/latest/redirect"
}

# 入るまで待つ。PollCount 回(5 秒おき)見て、だめなら PromptCount 回 Enter を待って見直す
function Wait-ClaudeDesktop([int]$PollCount = 24, [int]$PromptCount = 2) {
    for ($i = 0; $i -lt $PollCount; $i++) {
        $app = Find-ClaudeDesktop
        if ($app) { return $app }
        Start-Sleep -Seconds 5
    }
    for ($i = 0; $i -lt $PromptCount; $i++) {
        $null = Read-Host '   インストールが終わったら、この画面で Enter を押してください'
        $app = Find-ClaudeDesktop
        if ($app) { return $app }
        Write-Note 'まだ Claude アプリが見つかりません。'
    }
    return $null
}

# winget-pkgs の Anthropic.Claude は msix(Scope 無し)と exe(Scope: user、--silent)を持つ。
# 管理者権限なしで入るよう、ユーザー単位の exe を指定する
function Get-WingetArgs {
    return @('install', '--id', 'Anthropic.Claude', '-e', '--silent',
        '--scope', 'user', '--installer-type', 'exe', '--source', 'winget',
        '--accept-source-agreements', '--accept-package-agreements')
}

function Install-ClaudeWithWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Note 'winget が無いので、別の方法で入れます。'
        return $null
    }
    Write-Host '   winget で入れます(数分かかることがあります)'
    $code = $null
    try {
        $wingetArgs = Get-WingetArgs
        winget @wingetArgs | Out-Host
        $code = $LASTEXITCODE
    } catch {
        Write-Note "winget を動かせませんでした($($_.Exception.Message))"
        return $null
    }
    $app = Wait-ClaudeDesktop -PollCount 6 -PromptCount 0
    if (-not $app) { Write-Note "winget では入りませんでした(終了コード $code)。" }
    return $app
}

function Request-ManualInstall([string]$Arch) {
    Write-Note '自動では入れられないので、ブラウザでインストーラを開きます。'
    $opened = $false
    if ($Arch) {
        try { Start-Process (Get-InstallerUrl $Arch); $opened = $true } catch { }
    }
    if (-not $opened) {
        try { Start-Process $downloadPage; $opened = $true } catch { }
    }
    Write-Host '   1. ブラウザでダウンロードが終わるのを待つ(ページが開いたときは、Windows 版を選んでダウンロードする)'
    Write-Host '   2. ダウンロードしたファイルを開いてインストールする'
    Write-Host '   3. 終わったら、この画面に戻って Enter を押す'
    if (-not $opened) { Write-Host "   (ブラウザが開かないときは、自分で $downloadPage を開く)" }
    return (Wait-ClaudeDesktop -PollCount 0)
}

# 1) winget 2) ブラウザで CPU に合うインストーラを開く。直接の取得は Cloudflare の 403 で止まるのでしない
function Install-ClaudeDesktop {
    $app = Install-ClaudeWithWinget
    if ($app) {
        $script:InstalledVia = 'winget'
        return $app
    }
    $arch = Get-CpuArch
    if (-not $arch) { Write-Note 'この PC の CPU の種類が分かりませんでした。' }
    return (Request-ManualInstall $arch)
}

# ---- キー ----

function Test-KeyFormat([string]$Value) {
    return ($Value -match '^sk-ant-\S+$')
}

# 'ok' / 'invalid'(401) / 'unknown'(ネットなどで確かめられない)
function Test-ApiKey([string]$Value) {
    try {
        $headers = @{ 'x-api-key' = $Value; 'anthropic-version' = '2023-06-01' }
        $null = Invoke-RestMethod -Uri 'https://api.anthropic.com/v1/models' -Headers $headers -TimeoutSec 15
        return 'ok'
    } catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 401) { return 'invalid' }
        $script:ApiKeyCheckError = $_.Exception.Message
        return 'unknown'
    }
}

# Win+V の履歴を使っている PC では、履歴にはキーが残る(README に書いてある)
function Clear-KeyFromClipboard {
    try { Set-Clipboard -Value ' ' } catch { }
}

# ---- 設定 ----

# 既定のモデルを Sonnet にする(既存の設定は残す)。デスクトップに効くかは未確認なので画面でも選んでもらう
function Set-DefaultModel([string]$Dir) {
    $settingsPath = Join-Path $Dir 'settings.json'
    New-Item -ItemType Directory -Force $Dir | Out-Null
    $settings = New-Object psobject
    if (Test-Path -LiteralPath $settingsPath) {
        $raw = [IO.File]::ReadAllText($settingsPath)
        if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json }
    }
    $settings | Add-Member -NotePropertyName model -NotePropertyValue 'sonnet' -Force
    $json = $settings | ConvertTo-Json -Depth 32
    [IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding $false))
}

if ($LoadOnly) { return }

$sp = [Net.ServicePointManager]::SecurityProtocol
[Net.ServicePointManager]::SecurityProtocol = $sp -bor [Net.SecurityProtocolType]::Tls12

if ($Remove) {
    Write-Step 'API キーをこの PC から消します'
    $had = $false
    if (-not $SkipEnv) {
        $had = [bool][Environment]::GetEnvironmentVariable($keyName, 'User')
        [Environment]::SetEnvironmentVariable($keyName, $null, 'User')
    }
    if ($had) {
        Write-Ok '前の版が環境変数に登録したキーを消しました。開いているターミナルは全部閉じてください。'
    } else {
        Write-Ok '環境変数にキーはありませんでした。'
    }
    Write-Host '   Claude アプリの中のキーは、アプリからサインアウトすると消えます。'
    Write-Host '   (左のサイドバーの下にあるアカウントのメニューから、サインアウト/ログアウトを選ぶ)'
    Write-Host '   キーそのものを使えなくするには、配った人に止めてもらってください。'
    exit 0
}

# 1. デスクトップアプリ
Write-Step 'Claude アプリ(デスクトップ版)の確認'
$app = Find-ClaudeDesktop
if ($app) {
    $ver = if ($app.Version) { "(版 $($app.Version))" } else { '' }
    Write-Ok "インストール済み$ver"
} else {
    Write-Note 'Claude アプリが見つからないので、インストールします。'
    $app = Install-ClaudeDesktop
    if (-not $app) {
        Write-Note 'Claude アプリを入れられませんでした。入れ終わったら、もう一度 setup.cmd を実行してください。'
        Write-Note '学校や会社の PC の制限かもしれません。この画面を見せて相談してください。'
        exit 1
    }
    Write-Ok 'インストールを確かめました。'
}
if ((Test-DesktopVersionOld $app.Version) -or $script:InstalledVia -eq 'winget') {
    $verText = if ($app.Version) { "($($app.Version))" } else { '(winget で入る版)' }
    Write-Note "アプリの版が古い$($verText)ので、開いたあと自動の更新が終わるまで少し待ってください。"
}

# 2. キーの入力と確認
Write-Step 'API キーの確認'
if (-not $SkipEnv -and [Environment]::GetEnvironmentVariable($keyName, 'User')) {
    Write-Note '前の版が環境変数に登録したキーが残っています。デスクトップ版は使わないので、remove.cmd で消せます。'
}
if (-not $Key) {
    $Key = Read-Host 'もらった API キーを貼り付けて Enter(右クリックで貼り付けられます)'
}
$Key = "$Key".Trim()
if (-not (Test-KeyFormat $Key)) {
    Write-Note 'キーは sk-ant- で始まるはずです。貼り付け直して、もう一度 setup.cmd を実行してください。'
    exit 1
}
switch (Test-ApiKey $Key) {
    'ok'      { Write-Ok 'キーは有効です。' }
    'invalid' {
        Write-Note 'キーが間違っているか、止められています。配った人に確認してください。'
        exit 1
    }
    default   { Write-Note "キーを確かめられませんでした($script:ApiKeyCheckError)。このまま続けます。" }
}

# 3. 既定のモデル
Write-Step 'Claude Code の設定'
try {
    Set-DefaultModel $ClaudeDir
    Write-Ok '既定のモデルを Sonnet にしました。'
} catch {
    Write-Note "設定ファイルを書けませんでした($($_.Exception.Message))。使うのには困りません。"
}

# 4. キーをクリップボードに入れてアプリを開く
Write-Step 'アプリにキーを入れる'
try {
    Set-Clipboard -Value $Key
    Write-Ok 'キーをコピーしました(Ctrl+V で貼れます)。Claude アプリを開きます。'
} catch {
    Write-Note 'キーをコピーできませんでした。もらったキーを、自分でコピーして貼ってください。'
}
$Key = $null
try {
    Start-ClaudeDesktop $app
} catch {
    Write-Note "アプリを開けませんでした($($_.Exception.Message))。スタートメニューから Claude を開いてください。"
}
Write-Host ''
Write-Host '   アプリの画面で:'
Write-Host '   1. サインインの画面で「Use your Claude API account」を押す'
Write-Host '   2. API キーの欄をクリックし、Ctrl+V で貼り付けて進む'
Write-Host '      「Use your Claude API account」が無いときは、アプリが更新中です。'
Write-Host '      アプリを閉じて、開き直してください(閉じても画面右下に残るときは、そこから終了する)。'
Write-Host '   3. 上の「Code」を押し、作業するフォルダを選ぶ'
Write-Host '   4. 入力欄の下にあるモデルの選択で「Sonnet」を選ぶ'
Write-Host '   すでにサインインしてある画面が出たときは、そのまま 3 へ進んでください。'
Write-Host ''
$null = Read-Host '   貼り付けが終わったら、この画面で Enter を押してください(クリップボードからキーを消します)'
Clear-KeyFromClipboard
Write-Ok 'クリップボードを空にしました。'

Write-Step '完了'
Write-Host '   この画面は閉じてかまいません。'
Write-Host '   キーを消すときは remove.cmd をダブルクリックし、アプリからもサインアウトしてください。'
