# team-ai-setup

チーム配布用のセットアップ(Windows)。Claude のデスクトップアプリの Code タブを、配られた API キーで使えるようにする。

## 取り込む

Windows PowerShell に貼り付けて Enter:

```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/higgs1729/team-ai-setup/main/install.ps1 | iex"
```

`%USERPROFILE%\team-ai-setup` に `setup.ps1` / `setup.cmd` / `remove.cmd` が置かれ、セットアップが始まる。

- Claude アプリが無ければ入れる。自動で取ってこられないときはダウンロードのページが開くので、Windows 版を落として入れ、画面に戻って Enter を押す
- 配られた API キーを貼ると、使えるキーか確かめてからクリップボードにコピーし、アプリを開く
- キーはファイル・環境変数・レジストリには書かない。アプリの中にだけ入る
- `~/.claude/settings.json` の既定のモデルを Sonnet にする

もう一度やり直すときは、同じ 1 行か `setup.cmd` のダブルクリック。

## アプリにキーを貼る

1. サインインの画面で「Use your Claude API account」を押す
2. API キーの欄をクリックし、Ctrl+V で貼り付けて進む
   - 「Use your Claude API account」が無いときは、アプリが更新中。アプリを閉じて開き直す
3. 上の「Code」を押し、作業するフォルダを選ぶ
4. 入力欄の下にあるモデルの選択で「Sonnet」を選ぶ

貼り終えたらセットアップの画面で Enter を押す。クリップボードからキーが消える。
Win+V のクリップボード履歴を使っている人は、履歴からもキーを消す。

## キーを消す

1. アプリからサインアウトする(左のサイドバーの下にあるアカウントのメニュー)。アプリの中のキーはこれで消える
2. `%USERPROFILE%\team-ai-setup\remove.cmd` をダブルクリック。前の版(ターミナル版)が環境変数 `ANTHROPIC_API_KEY` に登録したキーを消す

キーそのものを使えなくするのは、配った人が行う。

## API キーでは使えないもの

API キーでサインインしたアプリでは、次は使えない。

- クラウドのセッション(Anthropic のクラウドで動かすもの)
- Remote Control(スマホやブラウザから操作するもの)
- Chrome 拡張(Claude in Chrome)
- claude.ai のコネクタ

会話はその PC の中だけに残る。ほかの PC や claude.ai からは見えない。

## Git

Git は無くても使える。ただし、セッションごとに作業コピーを分ける worktree のセッションには Git が要る(Windows は [Git for Windows](https://git-scm.com/downloads/win))。
