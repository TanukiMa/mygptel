;;; mygptel.el --- Ollama/Gemini backend switcher for gptel -*- lexical-binding: t; -*-

;; Configuration for using gptel from Emacs on Windows or WSL2 Debian GNU/Linux.
;;
;; When executing M-x gptel:
;;   1. Asks whether to use Ollama or Gemini.
;;   2. Asks which model to use for the selected provider
;;      (Ollama: fetches from `ollama list` equivalent,
;;       Gemini: queries ListModels API).
;; Then opens the gptel buffer with the chosen backend/model.
;;
;; The Gemini API key is retrieved from .authinfo (auth-source).
;; For example, add the following line to ~/.authinfo.gpg:
;;
;;   machine api.google.com login apikey password YOUR_GEMINI_API_KEY
;;
;; In your init.el, use (load-file "path/to/mygptel.el") or
;; (add-to-list 'load-path "...") followed by (require 'mygptel).

;;; Code:

(defun mygptel--check-dependencies ()
  "Check if required packages are installed. If not, warn the user."
  (unless (locate-library "gptel")
    (user-error
     "mygptel requires the 'gptel' package to function.
Please install it first:
  M-x package-install [Enter] gptel
Then restart Emacs or reload this file.")))

(mygptel--check-dependencies)
(require 'gptel)
(require 'auth-source)
(require 'url)

(defgroup mygptel nil
  "Ollama / Gemini backend switching configuration for gptel."
  :group 'gptel)

(defcustom mygptel-ollama-host "localhost:11434"
  "The host:port of the Ollama server.
Assumes Ollama is listening on localhost for both Windows / WSL2.
Change this if running on a different host."
  :type 'string
  :group 'mygptel)

(defcustom mygptel-gemini-authinfo-host "api.google.com"
  "The machine (host) name used to retrieve the Gemini API key from .authinfo.
Example: machine api.google.com login apikey password YOUR_KEY"
  :type 'string
  :group 'mygptel)

;;; Gemini API key

(defun mygptel-gemini-api-key ()
  "Retrieve the Gemini API key from auth-source (.authinfo)."
  (if-let* ((found (car (auth-source-search
                          :host mygptel-gemini-authinfo-host
                          :user "apikey"
                          :require '(:secret)
                          :max 1)))
            (secret (plist-get found :secret)))
      (if (functionp secret) (funcall secret) secret)
    (user-error
     "Gemini API key not found. Please add \"machine %s login apikey password YOUR_KEY\" to your .authinfo"
     mygptel-gemini-authinfo-host)))

;;; JSON retrieval helper

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

;;; Ollama

(defun mygptel--ollama-fetch-models ()
  "Return a list of installed model names from the local Ollama instance."
  (condition-case err
      (let* ((url (format "http://%s/api/tags" mygptel-ollama-host))
             (data (mygptel--url-get-json url))
             (models (plist-get data :models)))
        (mapcar (lambda (m) (plist-get m :name)) models))
    (error
     (user-error "Could not connect to Ollama (%s): %s"
                 mygptel-ollama-host (error-message-string err)))))

(defvar mygptel--ollama-backend nil
  "Cache for the Ollama backend created by gptel-make-ollama.")

(defun mygptel--ollama-backend (model-strings)
  "Create or update the Ollama backend using MODEL-STRINGS as available models."
  (setq mygptel--ollama-backend
        (gptel-make-ollama "Ollama"
          :host mygptel-ollama-host
          :stream t
          :models (mapcar #'intern model-strings))))

;;; Gemini

(defun mygptel--gemini-fetch-models ()
  "Return a list of model names supporting generateContent from the Gemini ListModels API."
  (condition-case err
      (let* ((key (mygptel-gemini-api-key))
             (url (format
                   "https://generativelanguage.googleapis.com/v1beta/models?key=%s"
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

(defvar mygptel--gemini-backend nil
  "Cache for the Gemini backend created by gptel-make-gemini.")

(defun mygptel--gemini-backend (model-strings)
  "Create or update the Gemini backend using MODEL-STRINGS as available models."
  (setq mygptel--gemini-backend
        (gptel-make-gemini "Gemini"
          :key #'mygptel-gemini-api-key
          :stream t
          :models (mapcar #'intern model-strings))))

;;; Provider/Model Selection

(defun mygptel--select-backend-and-model ()
  "Prompt the user to select a provider (Ollama/Gemini) then a model, and return (BACKEND . MODEL)."
  (let* ((provider (completing-read "LLM provider: " '("Ollama" "Gemini") nil t))
         (model-strings (pcase provider
                           ("Ollama" (mygptel--ollama-fetch-models))
                           ("Gemini" (mygptel--gemini-fetch-models))))
         (_ (unless model-strings
              (user-error "No available models found for %s" provider)))
         (model-name (completing-read (format "%s model: " provider)
                                       model-strings nil t))
         (backend (pcase provider
                    ("Ollama" (mygptel--ollama-backend model-strings))
                    ("Gemini" (mygptel--gemini-backend model-strings)))))
    (cons backend (intern model-name))))

;;; Intercept M-x gptel

;; Note: The (interactive ...) spec of the `gptel` command itself is evaluated
;; before the body of the advice. Since it determines the buffer name and
;; API key using the "pre-selection" default value of gptel-backend
;; (which is nil if unset), simply prompting for backend/model in the
;; advice body is too late (gptel will assume ChatGPT/OpenAI and prompt
;; for an API key).
;; Therefore, we provide (interactive ...) to the advice function itself
;; and use nadvice to prioritize it, bypassing the original interactive
;; spec to ensure backend/model selection happens first.
(defun mygptel--around-gptel (orig-fn &rest app-args)
  "Prompt for backend/model selection when calling `gptel` interactively."
  (interactive
   (progn
     (pcase-let ((`(,backend . ,model) (mygptel--select-backend-and-model)))
       (setq gptel-backend backend
             gptel-model model))
     (let* ((backend (default-value 'gptel-backend))
            (backend-name (format "*%s*" (gptel-backend-name backend))))
       (list (read-buffer "Create or choose gptel buffer: " backend-name)
             nil
             (and (use-region-p)
                  (buffer-substring (region-beginning) (region-end)))
             t))))
  (apply orig-fn app-args))

(advice-add 'gptel :around #'mygptel--around-gptel)

;;; Automatic local transcript saving (Markdown)

;; The save directory may vary by environment (Windows / WSL2),
;; so it's intended to be overridden in init.el: (setq mygptel-log-directory "...").
;;
;; Note: Computing the default value using `~` expansion or (getenv "HOME")
;; can be problematic. On Windows, if Emacs is started without a shell
;; (e.g., via shortcut), NTEmacs often rewrites HOME to %APPDATA% (Roaming).
;; This results in logs being saved to unexpected locations like
;; .../AppData/Roaming/Documents/mygptel/.
;; We avoid this by prioritizing USERPROFILE, which is always set by Windows.
(defvar mygptel-log-directory
  (expand-file-name "Documents/mygptel/"
                     (if (eq system-type 'windows-nt)
                         (or (getenv "USERPROFILE") (getenv "HOME") "~")
                       (or (getenv "HOME") "~")))
  "Directory to save LLM interaction logs (Markdown).
Can be overridden in init.el using `setq'.")

(defvar-local mygptel--log-file nil
  "The save path for this buffer's log file. Determined on first save and stored buffer-locally.")

(defun mygptel--log-file-for-buffer ()
  "Return the absolute path to the log file for the current buffer (determine if not yet created)."
  (or mygptel--log-file
      (let ((dir (expand-file-name mygptel-log-directory)))
        (make-directory dir t)
        (setq mygptel--log-file
              (expand-file-name
               (format "gptel-%d.md" (truncate (float-time)))
               dir)))))

(defun mygptel--save-transcript (_beg _end)
  "Save the entire buffer as Markdown locally whenever a gptel response is inserted."
  (when (bound-and-true-p gptel-mode)
    (write-region (point-min) (point-max) (mygptel--log-file-for-buffer) nil 'quiet)))

(add-hook 'gptel-post-response-functions #'mygptel--save-transcript)

(provide 'mygptel)
;;; mygptel.el ends here
