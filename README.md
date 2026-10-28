# team-ai-setup

チーム配布用の Claude Code セットアップ(Windows)。

## 取り込む

Windows PowerShell に貼り付けて Enter:

```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/higgs1729/team-ai-setup/main/install.ps1 | iex"
```

`%USERPROFILE%\team-ai-setup` に `setup.ps1` / `setup.cmd` / `remove.cmd` が置かれ、セットアップが始まる。
Claude Code が無ければ入れ、配られた API キーを貼り付けると登録される。既定のモデルは Sonnet になる。

もう一度やり直すときは、同じ 1 行か `setup.cmd` のダブルクリック。

## キーを消す

`%USERPROFILE%\team-ai-setup\remove.cmd` をダブルクリック。開いているターミナルは全部閉じる。
