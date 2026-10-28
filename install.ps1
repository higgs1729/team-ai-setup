# team-ai-setup を取り込む。README の 1 行(irm ... | iex)から呼ばれる。
# setup.ps1 / setup.cmd / remove.cmd を $env:USERPROFILE\team-ai-setup に落とし、setup.ps1 を & で流す(Read-Host が動くように)。
# iex で動くので param・exit・$PSScriptRoot は使わない(exit は窓ごと閉じる)。BOM なしで置く。
& {
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -Scope Process Bypass -Force   # この窓だけ。既定では .ps1 を動かせない PC がある
    $base = 'https://raw.githubusercontent.com/higgs1729/team-ai-setup/main'
    # 検証用: $TeamAiTest = @{ Dir = <置き場>; NoRun = $true }
    $test = Get-Variable TeamAiTest -ValueOnly -ErrorAction SilentlyContinue
    $dir = if ($test.Dir) { $test.Dir } else { Join-Path $env:USERPROFILE 'team-ai-setup' }

    Write-Host ''
    Write-Host '== team-ai-setup の取り込み' -ForegroundColor Cyan
    try {
        New-Item -ItemType Directory -Force $dir | Out-Null
        foreach ($f in 'setup.ps1', 'setup.cmd', 'remove.cmd') {
            $out = Join-Path $dir $f
            Invoke-WebRequest "$base/$f" -OutFile $out -UseBasicParsing
            Unblock-File $out
        }
        Write-Host "   OK: $dir に置きました" -ForegroundColor Green
    } catch {
        Write-Host "取ってこられませんでした: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'ネットにつながっているか確かめて、もう一度 1 行を貼ってやり直してください。'
        return
    }
    if ($test.NoRun) { return }
    & (Join-Path $dir 'setup.ps1')
}
