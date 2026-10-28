# Claude Code のセットアップ(チーム配布用)
# 使い方: setup.cmd をダブルクリック。キーを消すときは remove.cmd
param(
    [switch]$Remove,
    [string]$Key,
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    [switch]$SkipEnv
)

$ErrorActionPreference = 'Stop'
$keyName = 'ANTHROPIC_API_KEY'

function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "   注意: $msg" -ForegroundColor Yellow }

if ($Remove) {
    Write-Step 'API キーをこの PC から消します'
    if (-not $SkipEnv) { [Environment]::SetEnvironmentVariable($keyName, $null, 'User') }
    Write-Ok 'キーを消しました。開いているターミナルは全部閉じてください。'
    exit 0
}

# 1. Claude Code が入っているか
Write-Step 'Claude Code の確認'
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    Write-Ok "インストール済み ($($claude.Source))"
} else {
    Write-Note 'Claude Code が見つからないので、インストールします(数分かかります)。'
    try {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Write-Ok 'インストールしました。'
    } catch {
        Write-Note "インストールに失敗しました: $($_.Exception.Message)"
        Write-Note '学校の PC の制限かもしれません。この画面を見せて相談してください。'
        exit 1
    }
}

# 2. キーの入力と確認
Write-Step 'API キーの登録'
if (-not $Key) {
    $Key = Read-Host 'もらった API キーを貼り付けて Enter(右クリックで貼り付けられます)'
}
$Key = $Key.Trim()
if ($Key -notmatch '^sk-ant-') {
    Write-Note 'キーは sk-ant- で始まるはずです。貼り付け直して、もう一度 setup.cmd を実行してください。'
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    $headers = @{ 'x-api-key' = $Key; 'anthropic-version' = '2023-06-01' }
    $null = Invoke-RestMethod -Uri 'https://api.anthropic.com/v1/models' -Headers $headers -TimeoutSec 15
    Write-Ok 'キーは有効です。'
} catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -eq 401) {
        Write-Note 'キーが間違っているか、止められています。配った人に確認してください。'
        exit 1
    }
    Write-Note "キーを確かめられませんでした($($_.Exception.Message))。登録は続けます。"
}

if (-not $SkipEnv) {
    [Environment]::SetEnvironmentVariable($keyName, $Key, 'User')
    $env:ANTHROPIC_API_KEY = $Key
}
Write-Ok 'キーを登録しました。'

# 3. 既定のモデルを Sonnet にする(既存の設定は残す)
Write-Step 'Claude Code の設定'
$settingsPath = Join-Path $ClaudeDir 'settings.json'
try {
    New-Item -ItemType Directory -Force $ClaudeDir | Out-Null
    $settings = New-Object psobject
    if (Test-Path $settingsPath) {
        $raw = [IO.File]::ReadAllText($settingsPath)
        if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json }
    }
    $settings | Add-Member -NotePropertyName model -NotePropertyValue 'sonnet' -Force
    $json = $settings | ConvertTo-Json -Depth 32
    [IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding $false))
    Write-Ok '既定のモデルを Sonnet にしました。'
} catch {
    Write-Note "設定ファイルを書けませんでした($($_.Exception.Message))。使うのには困りません。"
}

Write-Step '完了'
Write-Host '   1. この画面と、開いているターミナルを全部閉じる'
Write-Host '   2. 新しく PowerShell を開き、作業フォルダに移動して claude と入力'
Write-Host '   3. 「この API キーを使いますか」と聞かれたら Yes を選ぶ'
