# ChatGPT デスクトップアプリ(Codex 入り)を OpenAI の API キーで使うためのセットアップ(チーム配布用)
# 使い方: setup.cmd をダブルクリック。キーを消すときは remove.cmd
# キーはファイル・レジストリ・環境変数・ログに書かない。アプリへはクリップボード経由で本人が貼る。
param(
    [switch]$Remove,
    [string]$Key,
    [switch]$SkipEnv,
    [switch]$LoadOnly   # 試験用: 関数だけ読み込んで止まる(. .\setup.ps1 -LoadOnly)
)

$ErrorActionPreference = 'Stop'
$oldKeyName = 'ANTHROPIC_API_KEY'   # 旧版(Claude)が環境変数に登録していた名前
# 実物のパッケージ(Store 版)と公式の Store ID
$appName = 'OpenAI.Codex'
$appPublisher = 'CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B'
$appFamily = 'OpenAI.Codex_2p2nqsd0c76g0'
$storeId = '9PLM9XGG6VKS'
$storePage = "https://get.microsoft.com/installer/download/$storeId"

function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "   注意: $msg" -ForegroundColor Yellow }

# ---- アプリの判定 ----

# 入っていれば @{ Target = <AppID>; Version } を返す。名前(ChatGPT)ではなくパッケージの発行元で見る
function Find-CodexApp {
    $pkg = $null
    try {
        $pkg = Get-AppxPackage -Name $appName -ErrorAction Stop |
            Where-Object { $_.Publisher -eq $appPublisher } | Select-Object -First 1
    } catch { }
    if ($pkg) {
        $appId = 'App'
        try {
            $ids = @(($pkg | Get-AppxPackageManifest -ErrorAction Stop).Package.Applications.Application | ForEach-Object { $_.Id })
            if ($ids.Count -gt 0 -and $ids -notcontains 'App') { $appId = $ids[0] }
        } catch { }
        return [pscustomobject]@{ Target = "$($pkg.PackageFamilyName)!$appId"; Version = "$($pkg.Version)" }
    }
    $start = $null
    try {
        $start = Get-StartApps -ErrorAction Stop | Where-Object { $_.AppID -like "$appFamily!*" } | Select-Object -First 1
    } catch { }
    if ($start) { return [pscustomobject]@{ Target = $start.AppID; Version = $null } }
    return $null
}

function Start-CodexApp($app) {
    Start-Process -FilePath 'explorer.exe' -ArgumentList "shell:AppsFolder\$($app.Target)"
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

# 公式の企業向け配布ページにある、Store を通らない MSIX
function Get-MsixUrl([string]$Arch) {
    return "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-$Arch.msix"
}

# 入るまで待つ。PollCount 回(5 秒おき)見て、だめなら PromptCount 回 Enter を待って見直す
function Wait-CodexApp([int]$PollCount = 12, [int]$PromptCount = 2) {
    for ($i = 0; $i -lt $PollCount; $i++) {
        $app = Find-CodexApp
        if ($app) { return $app }
        Start-Sleep -Seconds 5
    }
    for ($i = 0; $i -lt $PromptCount; $i++) {
        $null = Read-Host '   インストールが終わったら、この画面で Enter を押してください'
        $app = Find-CodexApp
        if ($app) { return $app }
        Write-Note 'まだ ChatGPT アプリが見つかりません。'
    }
    return $null
}

function Get-WingetArgs {
    return @('install', '--id', $storeId, '-s', 'msstore',
        '--accept-source-agreements', '--accept-package-agreements')
}

function Install-WithWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Note 'winget が無いので、別の方法で入れます。'
        return $null
    }
    Write-Host '   winget(Microsoft Store)で入れます(数分かかることがあります)'
    $code = $null
    try {
        $wingetArgs = Get-WingetArgs
        winget @wingetArgs | Out-Host
        $code = $LASTEXITCODE
    } catch {
        Write-Note "winget を動かせませんでした($($_.Exception.Message))"
        return $null
    }
    $app = Wait-CodexApp -PollCount 6 -PromptCount 0
    if (-not $app) { Write-Note "winget では入りませんでした(終了コード $code)。Store が止められている PC かもしれません。" }
    return $app
}

# 学校の PC は Store が無効なことがあるので、Store を通らない MSIX を直接入れてみる
function Install-WithMsix([string]$Arch) {
    if (-not $Arch) { return $null }
    Write-Host "   公式の MSIX($Arch 版、1 GB ほど)を直接入れてみます。時間がかかります"
    try {
        Add-AppxPackage -Path (Get-MsixUrl $Arch)
    } catch {
        Write-Note "直接は入れられませんでした($($_.Exception.Message))"
        return $null
    }
    return (Wait-CodexApp -PollCount 6 -PromptCount 0)
}

function Request-ManualInstall {
    Write-Note '自動では入れられないので、ブラウザで Microsoft Store のインストーラを開きます。'
    $opened = $false
    try { Start-Process $storePage; $opened = $true } catch { }
    Write-Host '   1. ダウンロードされたファイルを開いて、ChatGPT を入れる'
    Write-Host '   2. 終わったら、この画面に戻って Enter を押す'
    if (-not $opened) { Write-Host "   (ブラウザが開かないときは、自分で $storePage を開く)" }
    return (Wait-CodexApp -PollCount 0)
}

# 1) winget(msstore) 2) 公式の MSIX を直接 3) ブラウザで手で
function Install-CodexApp {
    $app = Install-WithWinget
    if ($app) { return $app }
    $app = Install-WithMsix (Get-CpuArch)
    if ($app) { return $app }
    return (Request-ManualInstall)
}

# ---- キー ----

function Test-KeyFormat([string]$Value) {
    return ($Value -match '^sk-\S+$')
}

# 'ok' / 'invalid'(401) / 'unknown'(それ以外。続ける)
function Test-ApiKey([string]$Value) {
    try {
        $headers = @{ 'Authorization' = "Bearer $Value" }
        $null = Invoke-RestMethod -Uri 'https://api.openai.com/v1/models' -Headers $headers -TimeoutSec 15
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

if ($LoadOnly) { return }

$sp = [Net.ServicePointManager]::SecurityProtocol
[Net.ServicePointManager]::SecurityProtocol = $sp -bor [Net.SecurityProtocolType]::Tls12

if ($Remove) {
    Write-Step 'API キーをこの PC から消します'
    $had = $false
    if (-not $SkipEnv) {
        $had = [bool][Environment]::GetEnvironmentVariable($oldKeyName, 'User')
        [Environment]::SetEnvironmentVariable($oldKeyName, $null, 'User')
    }
    if ($had) {
        Write-Ok '前の版(Claude)が環境変数に登録したキーを消しました。開いているターミナルは全部閉じてください。'
    } else {
        Write-Ok '環境変数にキーはありませんでした。'
    }
    Write-Host '   ChatGPT アプリの中の OpenAI のキーは、アプリのプロフィールのメニューで「Log out」を押すと消えます。'
    Write-Host '   キーそのものを使えなくするには、配った人に止めてもらってください。'
    exit 0
}

# 1. アプリ
Write-Step 'ChatGPT デスクトップアプリ(Codex 入り)の確認'
$app = Find-CodexApp
if ($app) {
    $ver = if ($app.Version) { "(版 $($app.Version))" } else { '' }
    Write-Ok "インストール済み$ver"
} else {
    Write-Note 'ChatGPT アプリが見つからないので、インストールします。'
    $app = Install-CodexApp
    if (-not $app) {
        Write-Note 'ChatGPT アプリを入れられませんでした。入れ終わったら、もう一度 setup.cmd を実行してください。'
        Write-Note '学校や会社の PC の制限かもしれません。この画面を見せて相談してください。'
        exit 1
    }
    Write-Ok 'インストールを確かめました。'
}

# 2. キーの入力と確認
Write-Step 'API キーの確認'
if (-not $SkipEnv -and [Environment]::GetEnvironmentVariable($oldKeyName, 'User')) {
    Write-Note '前の版(Claude)が環境変数に登録したキーが残っています。remove.cmd で消せます。'
}
if (-not $Key) {
    $Key = Read-Host 'もらった OpenAI の API キーを貼り付けて Enter(右クリックで貼り付けられます)'
}
$Key = "$Key".Trim()
if (-not (Test-KeyFormat $Key)) {
    Write-Note 'キーは sk- で始まるはずです。貼り付け直して、もう一度 setup.cmd を実行してください。'
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

# 3. キーをクリップボードに入れてアプリを開く
Write-Step 'アプリにキーを入れる'
try {
    Set-Clipboard -Value $Key
    Write-Ok 'キーをコピーしました(Ctrl+V で貼れます)。ChatGPT アプリを開きます。'
} catch {
    Write-Note 'キーをコピーできませんでした。もらったキーを、自分でコピーして貼ってください。'
}
$Key = $null
try {
    Start-CodexApp $app
} catch {
    Write-Note "アプリを開けませんでした($($_.Exception.Message))。スタートメニューから ChatGPT を開いてください。"
}
Write-Host ''
Write-Host '   アプリの画面で:'
Write-Host '   1. サインインの画面で「Sign in another way」を押す'
Write-Host '   2. キーの欄に Ctrl+V で貼り付けて「Continue」を押す'
Write-Host '   3. 上のドロップダウンで「Codex」を選ぶ'
Write-Host '   4. 作業するフォルダを開く'
Write-Host '   すでに ChatGPT のアカウントで入っているときは、プロフィールのメニューで「Log out」してから 1 へ。'
Write-Host ''
$null = Read-Host '   貼り付けが終わったら、この画面で Enter を押してください(クリップボードからキーを消します)'
Clear-KeyFromClipboard
Write-Ok 'クリップボードを空にしました。'

Write-Step '完了'
Write-Host '   この画面は閉じてかまいません。料金は API の従量で、配った人の OpenAI の請求になります。'
Write-Host '   キーを消すときは、アプリのプロフィールのメニューで「Log out」を押してください。'
exit 0   # winget の終了コードを残さない
