# mygptel

`mygptel` is a lightweight Emacs Lisp extension for [gptel](https://github.com/karthink/gptel) that allows you to easily switch between different LLM backends—specifically **Ollama** and **Gemini**—on the fly.

It simplifies the process of managing multiple providers by prompting you to select the provider and the model every time you start an interactive `gptel` session.

## Features

- **Dynamic Backend Selection**: Promptly choose between Ollama and Gemini when running `M-x gptel`.
- **Automatic Model Discovery**:
  - **Ollama**: Fetches available models from your local Ollama instance.
  - **Gemini**: Queries the Gemini ListModels API to find models that support content generation.
- **Secure API Key Management**: Integrates with Emacs `auth-source` (e.g., `.authinfo` or `.authinfo.gpg`) to securely handle Gemini API keys.
- **Automatic Transcript Saving**: Automatically saves your conversations as Markdown files in a local directory, ensuring you never lose your AI interactions.
- **Windows & WSL2 Optimized**: Handles home directory paths correctly on Windows to ensure logs are saved in the expected location.

## Installation

1. Copy `mygptel.el` to your Emacs configuration directory.
2. In your `init.el`, load the file:

```elisp
(load-file "~/.emacs.d/mygptel.el")
;; or if you add it to your load-path:
(require 'mygptel)
```

## Configuration

### Gemini API Key
Add your API key to your `.authinfo` or `.authinfo.gpg` file:
```
machine api.google.com login apikey password YOUR_GEMINI_API_KEY
```

### Customization
You can customize the following variables in your `init.el`:

- `mygptel-ollama-host`: Set the Ollama server address (default: `"localhost:11434"`).
- `mygptel-gemini-authinfo-host`: Set the host name for `auth-source` lookup (default: `"api.google.com"`).
- `mygptel-log-directory`: Change the directory where transcripts are saved.

## Usage

Simply run `M-x gptel`. You will be prompted:
1. **LLM provider**: Choose "Ollama" or "Gemini".
2. **Model**: Choose from the list of available models for that provider.

The conversation will then start in a buffer named after the selected backend.

---
日本語のドキュメントはこちら: [README.ja.md](./README.ja.md)
