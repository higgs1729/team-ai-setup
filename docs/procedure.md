# 手順メモ

ChatGPT デスクトップアプリ(Codex 入り)を OpenAI の API キーで使う版。2026-11-04 に Claude 版(タグ claude-v2)から作り替えた。

## 前提(公式)

- API キーでのサインイン: サインアウトの画面で「Sign in another way」→ キー → 「Continue」。ログアウトはプロフィールのメニューの「Log out」: https://learn.chatgpt.com/docs/auth.md
- API キーでは、ワークスペースやクラウドに頼る機能が一部使えない。Codex のクラウドは ChatGPT でのサインインが要る。プラグインの一部は使えない。料金は API の従量: 同上
- 導入: `winget install --id 9PLM9XGG6VKS -s msstore`、ブラウザなら https://get.microsoft.com/installer/download/9PLM9XGG6VKS 。Git が無いと一部の機能が使えない: https://learn.chatgpt.com/docs/windows/windows-app.md
- Store を通らない MSIX: `https://persistent.oaistatic.com/codex-app-prod/ChatGPT-{x64|arm64}.msix`。公式の手順は管理者での `Add-AppxProvisionedPackage`(ライセンス XML 付き)だけ: https://learn.chatgpt.com/docs/enterprise/windows-deployment
- 「Codex を選ぶ」は quickstart の "select Codex from the ChatGPT dropdown": https://learn.chatgpt.com/docs/quickstart.md

## 判定と入れ方

- 判定: `Get-AppxPackage -Name OpenAI.Codex` の発行元が `CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B` のもの(この PC の実物: Family `OpenAI.Codex_2p2nqsd0c76g0`、版 26.1027.3384.0、表示名 ChatGPT)。次にスタートメニューの AppID が `OpenAI.Codex_2p2nqsd0c76g0!*` のもの。表示名(ChatGPT)だけでは見ない
- 起動: `explorer.exe shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App`
- 入れ方の順: winget(`--accept-source-agreements --accept-package-agreements` 付き)→ `Add-AppxPackage -Path <MSIX の URL>`(管理者なし。1 GB ほど)→ ブラウザで get.microsoft.com を開いて手で

## 確かめたこと(Windows 11 x64、PowerShell 5.1.26100)

- 構文: `[System.Management.Automation.Language.Parser]::ParseFile` でエラー 0
- 試験: `. .\setup.ps1 -LoadOnly` で関数を読み、`winget` `Add-AppxPackage` `Start-Process` `Set-Clipboard` `Read-Host` `Get-AppxPackage` `Get-StartApps` `Invoke-RestMethod` を同名の関数で差し替えて 42 件通過。本物の winget・Add-AppxPackage が見えている状態では入れる処理を呼ばない見張り付き。インストール・アプリの起動・クリップボード・環境変数・~/.codex には触れていない
- キーの確認: 偽のキーで `GET https://api.openai.com/v1/models`(Bearer)が 401 になり、クリップボードにもアプリにも進まない
- MSIX の URL は HEAD で 200(x64 1,003,521,886 バイト、arm64 1,076,519,636 バイト)

## 実機待ち(未確認)

- アプリの無い PC での一通り: 入る → 「Sign in another way」→ 貼り付け → 「Continue」→ Codex → フォルダを開く
- 画面の文言のうち公式に無いもの: キーの欄の名前、フォルダを開くボタンの名前、ドロップダウンの位置(「上の」)
- 管理者でない利用者が Store 署名の MSIX を `Add-AppxPackage` で入れられるか(公式の手順は管理者でのプロビジョニングだけ)
- Store が無効な PC で winget(msstore)がどう失敗するか
- `Set-Clipboard -Value ' '` でキーが消えるか、remove.cmd の環境変数の削除(どちらもモックだけ)
