;;; mygptel.el --- Dynamic backend switcher for gptel -*- lexical-binding: t; -*-

;; Configuration for using gptel from Emacs on Windows or WSL2 Debian GNU/Linux.
;;
;; This extension allows users to switch between Ollama and Gemini backends
;; dynamically whenever `M-x gptel` is called.
;;
;; Package-Requires: ((emacs "28.1") (gptel "0"))

;;; Code:

(require 'gptel)
(require 'auth-source)
(require 'url)
(require 'cl-lib)

(defgroup mygptel nil
  "Ollama / Gemini backend switching configuration for gptel."
  :group 'gptel)

(defcustom mygptel-ollama-host "localhost:11434"
  "The host:port of the Ollama server. Default is localhost:11434."
  :type 'string
  :group 'mygptel)

(defcustom mygptel-mistral-host "localhost:1234"
  "The host:port of the Mistral.rs server. Default is localhost:1234."
  :type 'string
  :group 'mygptel)

(defcustom mygptel-vllm-host "localhost:8000"
  "The host:port of the vLLM server. Default is localhost:8000."
  :type 'string
  :group 'mygptel)

(defcustom mygptel-sglang-host "localhost:30000"
  "The host:port of the SGLang server. Default is localhost:30000."
  :type 'string
  :group 'mygptel)

(defcustom mygptel-gemini-authinfo-host "api.google.com"
  "The machine (host) name used to retrieve the Gemini API key from .authinfo."
  :type 'string
  :group 'mygptel)

(defvar mygptel-log-directory
  (expand-file-name "Documents/mygptel/"
                    (if (eq system-type 'windows-nt)
                        (or (getenv "USERPROFILE") (getenv "HOME") "~")
                      (or (getenv "HOME") "~")))
  "Directory to save LLM interaction logs (Markdown).")

;;; API Key Management

(defun mygptel-gemini-api-key ()
  "Retrieve the Gemini API key from auth-source (.authinfo).
Returns the secret string or signals an error if not found."
  (if-let* ((found (car (auth-source-search
                          :host mygptel-gemini-authinfo-host
                          :user "apikey"
                          :require '(:secret)
                          :max 1)))
            (secret (plist-get found :secret)))
      (if (functionp secret) (funcall secret) secret)
    (user-error
     "Gemini API key not found in auth-source.
Please add the following line to ~/.authinfo or ~/.authinfo.gpg:
  machine %s login apikey password YOUR_GEMINI_API_KEY"
     mygptel-gemini-authinfo-host)))

;;; HTTP/JSON Helper

(defun mygptel--url-get-json (url)
  "Send a GET request to URL and return the response body as a JSON plist."
  (let ((buf (url-retrieve-synchronously url t t 10)))
    (unless buf
      (error "Request failed: %s" url))
    (unwind-protect
        (with-current-buffer buf
          (goto-char (point-min))
          (unless (re-search-forward "\n\n" nil t)
            (error "Failed to parse HTTP response: %s" url))
          (json-parse-buffer :object-type 'plist :array-type 'list))
      (kill-buffer buf))))

;;; OpenAI-Compatible Backend Helpers

(defun mygptel--openai-compatible-fetch-models (host)
  "Fetch model names from an OpenAI-compatible server at HOST."
  (condition-case err
      (let* ((url (format "http://%s/v1/models" host))
             (data (mygptel--url-get-json url))
             ;; OpenAI-compatible servers use either :objects or :data
             (models (or (plist-get data :objects) (plist-get data :data))))
        (mapcar (lambda (m) (plist-get m :id)) models))
    (error
     (user-error "Could not connect to OpenAI-compatible server at %s.
Error: %s" host (error-message-string err)))))

(defun mygptel--openai-compatible-create-backend (name host model-strings)
  "Create and return an OpenAI-compatible backend for NAME at HOST."
  (gptel-make-openai name
                     :host host
                     :key "dummy-key"
                     :stream t
                     :models (mapcar #'intern model-strings)))

;;; Backend Discovery & Creation

(defun mygptel--ollama-fetch-models ()
  "Fetch installed model names from the local Ollama instance."
  (condition-case err
      (let* ((url (format "http://%s/api/tags" mygptel-ollama-host))
             (data (mygptel--url-get-json url))
             (models (plist-get data :models)))
        (mapcar (lambda (m) (plist-get m :name)) models))
    (error
     (user-error "Could not connect to Ollama at %s. Please ensure it is running.
Error: %s"
                 mygptel-ollama-host (error-message-string err)))))

(defun mygptel--ollama-create-backend (model-strings)
  "Create and return an Ollama backend with the given MODEL-STRINGS."
  (gptel-make-ollama "Ollama"
                     :host mygptel-ollama-host
                     :stream t
                     :models (mapcar #'intern model-strings)))

(defun mygptel--gemini-fetch-models ()
  "Fetch Gemini model names that support generateContent."
  (condition-case err
      (let* ((key (mygptel-gemini-api-key))
             (url (format "https://generativelanguage.googleapis.com/v1beta/models?key=%s"
                          (url-hexify-string key)))
             (data (mygptel--url-get-json url))
             (models (plist-get data :models)))
        (delq nil
              (mapcar
               (lambda (m)
                 (when (member "generateContent"
                               (plist-get m :supportedGenerationMethods))
                   (string-remove-prefix "models/" (plist-get m :name))))
               models)))
    (error
     (user-error "Could not retrieve Gemini model list: %s"
                 (error-message-string err)))))

(defun mygptel--gemini-create-backend (model-strings)
  "Create and return a Gemini backend with the given MODEL-STRINGS."
  (gptel-make-gemini "Gemini"
                     :key #'mygptel-gemini-api-key
                     :stream t
                     :models (mapcar #'intern model-strings)))

;;; Selection Logic

(defvar mygptel-providers
  `((:name "Ollama"    :fetch mygptel--ollama-fetch-models    :create mygptel--ollama-create-backend)
    (:name "Gemini"    :fetch mygptel--gemini-fetch-models    :create mygptel--gemini-create-backend)
    (:name "Mistral.rs" :fetch mygptel--openai-compatible-fetch-models :create mygptel--openai-compatible-create-backend :host mygptel-mistral-host)
    (:name "vLLM"       :fetch mygptel--openai-compatible-fetch-models :create mygptel--openai-compatible-create-backend :host mygptel-vllm-host)
    (:name "SGLang"     :fetch mygptel--openai-compatible-fetch-models :create mygptel--openai-compatible-create-backend :host mygptel-sglang-host))
  "List of provider configurations.")

(defun mygptel--select-backend-and-model ()
  "Prompt the user to select provider and model.
Returns a cons cell (BACKEND . MODEL-SYMBOL)."
  (let* ((provider-name (completing-read "LLM provider: "
                                       (mapcar (lambda (p) (plist-get p :name)) mygptel-providers) nil t))
         (provider (car (cl-remove-if-not (lambda (p) (string= (plist-get p :name) provider-name))
                                         mygptel-providers)))
         (fetch-fn (plist-get provider :fetch))
         (create-fn (plist-get provider :create))
         (host-sym (plist-get provider :host))
         (host (if host-sym (symbol-value host-sym)))
         (model-strings (if host (funcall fetch-fn host) (funcall fetch-fn)))
         (_ (unless model-strings
              (user-error "No available models found for %s" provider-name)))
         (model-name (completing-read (format "%s model: " provider-name)
                                     model-strings nil t))
         (backend (if host (funcall create-fn provider-name host model-strings)
                           (funcall create-fn model-strings))))
    (cons backend (intern model-name))))

;;; Gptel Interception

(defun gptel-backend-switcher-around (orig-fn &rest app-args)
  "Intercept gptel command to prompt for backend/model selection."
  (interactive
   (pcase-let ((`(,backend . ,model) (mygptel--select-backend-and-model)))
     (setq gptel-backend backend
           gptel-model model)
     (let* ((backend-name (format "*%s*" (gptel-backend-name backend)))
            (buffer-name (read-buffer "Create or choose gptel buffer: " backend-name)))
       (list buffer-name
             nil
             (and (use-region-p)
                  (buffer-substring (region-beginning) (region-end)))
             t))))
  (apply orig-fn app-args))

(advice-add 'gptel :around #'gptel-backend-switcher-around)

;;; Transcript Saving

(defvar-local mygptel--log-file nil
  "Buffer-local path to the transcript log file.")

(defun mygptel--get-log-file ()
  "Compute or return the log file path for the current buffer."
  (or mygptel--log-file
      (let ((dir (expand-file-name mygptel-log-directory)))
        (make-directory dir t)
        (setq mygptel--log-file
              (expand-file-name
               (format "gptel-%d.md" (truncate (float-time)))
               dir)))))

(defun mygptel--save-transcript (_beg _end)
  "Save buffer content to Markdown file on every gptel response."
  (when (bound-and-true-p gptel-mode)
    (write-region (point-min) (point-max) (mygptel--get-log-file) nil 'quiet)))

(add-hook 'gptel-post-response-functions #'mygptel--save-transcript)

(provide 'mygptel)
;;; mygptel.el ends here
