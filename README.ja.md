# mygptel

`mygptel` は、[gptel](https://github.com/karthink/gptel) のための軽量な Emacs Lisp 拡張で、**Ollama** と **Gemini** といった異なる LLM バックエンドを簡単かつ動的に切り替えて利用できるようにします。

対話的な `gptel` セッションを開始するたびに、プロバイダとモデルの選択を促すことで、複数の LLM の管理を簡略化します。

## 特徴

- **動的なバックエンド選択**: `M-x gptel` 実行時に、Ollama と Gemini のどちらを使用するかを選択できます。
- **モデルの自動取得**:
  - **Ollama**: ローカルの Ollama インスタンスからインストール済みのモデル一覧を取得します。
  - **Gemini**: Gemini の ListModels API を問い合わせ、コンテンツ生成に対応したモデル一覧を取得します。
- **安全な API キー管理**: Emacs の `auth-source` (例: `.authinfo` や `.authinfo.gpg`) と連携し、Gemini の API キーを安全に管理します。
- **対話ログの自動保存**: LLM との対話を Markdown ファイルとしてローカルディレクトリに自動保存します。
- **Windows & WSL2 最適化**: Windows 環境においてホームディレクトリのパスを適切に処理し、ログが意図しない場所（AppData など）に保存されるのを防ぎます。

## インストール

1. `mygptel.el` を Emacs の設定ディレクトリにコピーします。
2. `init.el` でファイルを読み込みます。

```elisp
(load-file "~/.emacs.d/mygptel.el")
;; または load-path に追加している場合は:
(require 'mygptel)
```

## 設定

### Gemini API キー
`.authinfo` または `.authinfo.gpg` ファイルに以下の行を追加してください。
```
machine api.google.com login apikey password YOUR_GEMINI_API_KEY
```

### カスタマイズ
`init.el` で以下の変数を設定できます。

- `mygptel-ollama-host`: Ollama サーバーのアドレスを指定します (デフォルト: `"localhost:11434"`)。
- `mygptel-gemini-authinfo-host`: `auth-source` で検索するホスト名を指定します (デフォルト: `"api.google.com"`)。
- `mygptel-log-directory`: 対話ログを保存するディレクトリを変更します。

## 使い方

`M-x gptel` を実行してください。以下の順に選択肢が表示されます。
1. **LLM provider**: "Ollama" または "Gemini" を選択します。
2. **Model**: そのプロバイダで利用可能なモデルを選択します。

選択後、選んだバックエンドの名前が付いたバッファで対話が始まります。

---
English documentation: [README.md](./README.md)
