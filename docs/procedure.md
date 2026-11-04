# 手順メモ

デスクトップアプリ(Code タブ)を API キーで使う版。2026-11-04 に作り替えた。

## 前提(公式)

- デスクトップは `ANTHROPIC_API_KEY` を読まない: https://code.claude.com/docs/en/authentication
- 3.1623.1 以降はサインイン画面から「Use your Claude API account」でキーを入れられる: https://claude.com/docs/third-party/claude-desktop/claude-api
- インストーラ: `https://claude.ai/api/desktop/win32/{x64|arm64}/setup/latest/redirect`(winget の Anthropic.Claude は古いので使わない)
- worktree のセッションには Git が要る: https://code.claude.com/docs/en/desktop (Git and Git LFS errors)
- API キー(3P)で使えないもの: https://claude.com/docs/third-party/claude-desktop/feature-matrix

## 確かめたこと(Windows 11 x64、PowerShell 5.1.26100、Claude MSIX 4.4212.0.0)

- 構文: `[System.Management.Automation.Language.Parser]::ParseFile` でエラー 0
- 試験: `. .\setup.ps1 -LoadOnly` で関数を読み、`Start-Process` `Set-Clipboard` `Read-Host` `Get-AppxPackage` `Get-StartApps` `Invoke-RestMethod` を同名の関数で差し替えて 67 件通過。アプリの起動・クリップボード・環境変数・本人の settings.json には触れていない(`-ClaudeDir` は一時フォルダ、`-SkipEnv`)
- 判定: `Get-AppxPackage -Name Claude`(発行元 Anthropic)で拾える。起動は `explorer.exe shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude`。MSIX なのでスタートメニューの .lnk は無い
- インストーラの取得: PS 5.1 の `Invoke-WebRequest` は x64・arm64 とも 403(`cf-mitigated: challenge`)。そのため今は必ず「ダウンロードのページを開いて手で入れる」流れになる
- 署名の判定: 入っている Claude.exe は Valid・`CN="Anthropic, PBC"` で通り、explorer.exe と無署名のファイルは弾く
- キーの確認: 偽のキーで `/v1/models` が 401 になり、クリップボードにもアプリにも進まない

## 実機待ち

- アプリの無い PC で: 手で入れる → 「Use your Claude API account」→ 貼り付け → Code タブで動くか
- 取得が通る環境でのインストーラの形(.exe か .msix)と、`Start-Process -Wait` の後に判定が拾えるか
- settings.json の `model: sonnet` が Code タブの既定に効くか(効かなくても画面で選ぶ案内がある)
- サインアウトの表示の場所と名前、サインアウトでアプリ内のキーが消えるか
- 旧版の .exe(`%LOCALAPPDATA%\AnthropicClaude\claude.exe`)の判定。この PC に無いのでモックだけ
- remove.cmd の環境変数の削除と、`Set-Clipboard -Value ' '` でキーが消えるか(どちらもモックだけ)
