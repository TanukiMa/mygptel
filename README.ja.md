# mygptel

`mygptel` は、[gptel](https://github.com/karthink/gptel) のための軽量な Emacs Lisp 拡張で、**Ollama**, **Gemini**, および **OpenAI 互換ランタイム (Mistral.rs, vLLM, SGLang 等)** といった異なる LLM バックエンドを簡単かつ動的に切り替えて利用できるようにします。

対話的な `gptel` セッションを開始するたびに、プロバイダとモデルの選択を促すことで、複数の LLM の管理を簡略化します。

## 特徴

- **動的なバックエンド選択**: `M-x gptel` 実行時に、利用可能なプロバイダ（Ollama, Gemini, Mistral.rs, vLLM, SGLang 等）から選択できます。
- **モデルの自動取得**:
  - **Ollama**: ローカルの Ollama インスタンスからインストール済みのモデル一覧を取得します。
  - **Gemini**: Gemini の ListModels API を問い合わせ、コンテンツ生成に対応したモデル一覧を取得します。
  - **OpenAI 互換ランタイム**: `/v1/models` エンドポイントを介して、Mistral.rs, vLLM, SGLang 等のサーバーからモデル一覧を自動取得します。
- **安全な API キー管理**: Emacs の `auth-source` (例: `.authinfo` や `.authinfo.gpg`) と連携し、Gemini の API キーを安全に管理します。
- **対話ログの自動保存**: LLM との対話を Markdown ファイルとしてローカルディレクトリに自動保存します。
- **Windows & WSL2 最適化**: Windows 環境においてホームディレクトリのパスを適切に処理し、ログが意図しない場所（AppData など）に保存されるのを防ぎます。

## 前提条件

本パッケージを利用するには [gptel](https://github.com/karthink/gptel) が必要です。
`mygptel` をインストールする前に、`gptel` がインストールされていることを確認してください。

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
- `mygptel-mistral-host`: Mistral.rs サーバーのアドレスを指定します (デフォルト: `"localhost:1234"`)。
- `mygptel-vllm-host`: vLLM サーバーのアドレスを指定します (デフォルト: `"localhost:8000"`)。
- `mygptel-sglang-host`: SGLang サーバーのアドレスを指定します (デフォルト: `"localhost:30000"`)。
- `mygptel-gemini-authinfo-host`: `auth-source` で検索するホスト名を指定します (デフォルト: `"api.google.com"`)。
- `mygptel-log-directory`: 対話ログを保存するディレクトリを変更します。

## 使い方

`M-x gptel` を実行してください。以下の順に選択肢が表示されます。
1. **LLM provider**: 利用可能なプロバイダ（Ollama, Gemini, Mistral.rs, vLLM, SGLang など）を選択します。
2. **Model**: そのプロバイダで利用可能なモデルを選択します。

選択後、選んだバックエンドの名前が付いたバッファで対話が始まります。

## ライセンス

このプロジェクトは [GNU GPL v3](LICENSE) ライセンスの下で公開されています。

作者: Ma Tanuki

---
English documentation: [README.md](./README.md)
