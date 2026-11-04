# 手順メモ

デスクトップアプリ(Code タブ)を API キーで使う版。2026-11-04 に作り替えた。

## 前提(公式)

- デスクトップは `ANTHROPIC_API_KEY` を読まない: https://code.claude.com/docs/en/authentication
- 3.1623.1 以降はサインイン画面から「Use your Claude API account」でキーを入れられる: https://claude.com/docs/third-party/claude-desktop/claude-api
- インストーラ: `https://claude.ai/api/desktop/win32/{x64|arm64}/setup/latest/redirect`
- worktree のセッションには Git が要る: https://code.claude.com/docs/en/desktop (Git and Git LFS errors)
- API キー(3P)で使えないもの: https://claude.com/docs/third-party/claude-desktop/feature-matrix
- 旧来の .exe で入れると Cowork が無い(Code タブには触れていない): https://claude.com/docs/third-party/claude-desktop/installation

## 入れ方の順

1. winget: `winget install --id Anthropic.Claude -e --silent --scope user --installer-type exe --source winget --accept-source-agreements --accept-package-agreements`
   - manifest(winget-pkgs `manifests/a/Anthropic/Claude/2.42304.2/Anthropic.Claude.installer.yaml`)は x64・arm64 とも msix と exe を持つ。msix は Scope の指定が無く、packagedServices・localSystemServices を含む(入れるのに管理者が要りそう、未確認)。exe は `Scope: user`・`Silent: --silent`・`ProductCode: AnthropicClaude`
   - そのため `--scope user --installer-type exe` を付ける。入り先は `%LOCALAPPDATA%\AnthropicClaude\claude.exe`(判定の 2 番目で拾う)
   - 版は 2.42304.2 と古い。起動後の自動更新を待つ前提で「版が古い」の案内を出す
2. winget が無い・失敗: ブラウザで CPU に合う上の URL を開く(開けなければ https://claude.com/download)。Enter を待って判定し直す
- 直接の取得はしない。PS 5.1 の `Invoke-WebRequest` は x64・arm64 とも 403(`cf-mitigated: challenge`)だった

## 確かめたこと(Windows 11 x64、PowerShell 5.1.26100、winget v1.29.380、Claude MSIX 4.4212.0.0)

- 構文: `[System.Management.Automation.Language.Parser]::ParseFile` でエラー 0
- 試験: `. .\setup.ps1 -LoadOnly` で関数を読み、`winget` `Start-Process` `Set-Clipboard` `Read-Host` `Get-AppxPackage` `Get-StartApps` `Invoke-RestMethod` を同名の関数で差し替えて試す。winget 版は 38 件通過(winget 成功 / 0 以外でも入っていれば使う / 失敗 / 例外 / 無し / 直リンクが開けない / CPU 不明、通しの実行 3 通り)。本物の winget.exe が見えている状態では入れる処理を呼ばない見張りを付けた。winget・インストーラ・アプリの起動・クリップボード・環境変数・本人の settings.json には触れていない
- 判定: `Get-AppxPackage -Name Claude`(発行元 Anthropic)で拾える。起動は `explorer.exe shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude`
- キーの確認: 偽のキーで `/v1/models` が 401 になり、クリップボードにもアプリにも進まない(前回の試験)

## 実機待ち

- アプリの無い PC で: winget で入る → 自動更新で 3.1623.1 以上になる → 「Use your Claude API account」→ 貼り付け → Code タブで動くか
- exe(旧来の入れ方)の版が今も自動更新されるか。exe で Code タブが使えるか
- 古い winget(`--installer-type` が無い版)では失敗してブラウザの流れに落ちる
- ブラウザで直リンクを開くと、Cloudflare を通ってダウンロードが始まるか
- settings.json の `model: sonnet` が Code タブの既定に効くか(効かなくても画面で選ぶ案内がある)
- サインアウトの表示の場所と名前、サインアウトでアプリ内のキーが消えるか
- remove.cmd の環境変数の削除と、`Set-Clipboard -Value ' '` でキーが消えるか(どちらもモックだけ)
