# team-ai-setup

チーム配布用のセットアップ(Windows)。ChatGPT デスクトップアプリ(Codex 入り)を、配られた OpenAI の API キーで使えるようにする。

## 取り込む

Windows PowerShell に貼り付けて Enter:

```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/higgs1729/team-ai-setup/main/install.ps1 | iex"
```

`%USERPROFILE%\team-ai-setup` に `setup.ps1` / `setup.cmd` / `remove.cmd` が置かれ、セットアップが始まる。

- ChatGPT アプリが無ければ入れる。順に、winget(Microsoft Store)→ 公式の MSIX を直接 → ブラウザで Microsoft Store のインストーラを開いて手で
- 配られた API キー(`sk-` で始まる)を貼ると、使えるキーか確かめてからクリップボードにコピーし、アプリを開く
- キーはファイル・環境変数・レジストリには書かない。アプリの中にだけ入る

もう一度やり直すときは、同じ 1 行か `setup.cmd` のダブルクリック。

## アプリにキーを貼る

1. サインインの画面で「Sign in another way」を押す
2. キーの欄に Ctrl+V で貼り付けて「Continue」を押す
3. 上のドロップダウンで「Codex」を選ぶ
4. 作業するフォルダを開く

すでに ChatGPT のアカウントで入っているときは、プロフィールのメニューで「Log out」してから 1 へ。
貼り終えたらセットアップの画面で Enter を押す。クリップボードからキーが消える。
Win+V のクリップボード履歴を使っている人は、履歴からもキーを消す。

## キーを消す

1. アプリのプロフィールのメニューで「Log out」を押す。アプリの中のキーはこれで消える
2. 前の版(Claude)を入れていた人は、`%USERPROFILE%\team-ai-setup\remove.cmd` をダブルクリック。環境変数 `ANTHROPIC_API_KEY` に残ったキーを消す

キーそのものを使えなくするのは、配った人が行う。

## API キーで使うときの違い

- 料金は API の従量。ChatGPT のプランに含まれる分ではなく、配った人の OpenAI Platform の請求になる
- ChatGPT のワークスペースやクラウドに頼る機能は、一部が使えないか制限される。Codex のクラウドは ChatGPT でのサインインが要る
- プラグインの一部は使えない(接続に対応していない OAuth が要るもの)。OpenAI が選んだプラグインは使える

## Git

Git は無くても動く。無いと一部の機能(変更を見る・元に戻すレビューの画面など)が使えない。入れるときは PowerShell で `winget install Git.Git`。
