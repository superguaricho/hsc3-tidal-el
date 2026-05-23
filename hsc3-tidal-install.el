;;; hsc3-tidal-install.el --- Installation script for hsc3 and TidalCycles -*- lexical-binding: t -*-
;;
;; Filename: hsc3-tidal-install.el
;; Description: Emacs Lisp script to automate the installation of hsc3-tidal.
;; Author: Numa Tortolero
;; Created: mié may 13 20:20:23 2026 (-0400)
;; URL: https://github.com/superguaricho/hsc3-tidal-el
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;  This Emacs Lisp script automates the installation of hsc3-tidal,
;; a Haskell package for live coding music with SuperCollider. It clones
;; the hsc3-tidal repository from GitHub, builds it using Cabal, and
;; sets up executable scripts for easy access. The installation
;; process is designed to be user-friendly, providing real-time feedback
;; in an Emacs buffer.
;; Users can also stop the installation process if needed and clean up
;; installation files if they wish to start fresh.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:

(defvar hsc3-tidal-install-haskell-local-dir
  (expand-file-name "~/.local/share/haskell")
  "Base directory for local Haskell installations.
hsc3-tidal will be installed in a subdirectory here.")

(defvar hsc3-tidal-install-pack-name "hsc3-tidal"
  "Name of the hsc3-tidal package for installation and script generation.")

(defvar hsc3-tidal-install-repo
  (format "https://github.com/superguaricho/%s" hsc3-tidal-install-pack-name)
  "Name of the hsc3-tidal package for installation and script generation.")

(defvar hsc3-tidal-install-buffer
  (format "*%s installation*" hsc3-tidal-install-pack-name))

(defvar hsc3-tidal-install-version ""
  "Version of hsc3-tidal to install.
Update this to install a different version.")

(defvar hsc3-tidal-install-dir
  (expand-file-name
    hsc3-tidal-install-pack-name hsc3-tidal-install-haskell-local-dir)
  "Directory where TidalCycles source will be cloned and built.")

(defvar hsc3-tidal-install-user-bin-dir (expand-file-name "~/.local/bin")
  "Directory where the Tidal executable script will be placed.")

(defvar hsc3-tidal-install-bash-script
  (expand-file-name hsc3-tidal-install-pack-name hsc3-tidal-install-user-bin-dir)
  "Path to the hsc3-tidal executable script.")

(defvar hsc3-tidal-install-ghci-script
  (expand-file-name (format "%s-emacs.ghci" hsc3-tidal-install-pack-name)
    hsc3-tidal-install-dir)
  "Path to the hsc3-tidal executable script.")

(defvar hsc3-tidal-install-ghci-script-file
  (expand-file-name "loadme.ghci" hsc3-tidal-install-dir)
  "Path to the hsc3-tidal executable script.")

(defvar hsc3-tidal-install--spinner-state 0
  "Internal state for the installation spinner animation.")

(defconst hsc3-tidal-install--spinner-chars ["|" "/" "-" "\\"]
  "Characters used for the spinner animation in the mode-line.")

(defun hsc3-tidal-install--update-spinner (proc)
  "Update the spinner in the mode-line for PROC."
  (when (process-live-p proc)
    (with-current-buffer (process-buffer proc)
      (setq hsc3-tidal-install--spinner-state (% (1+ hsc3-tidal-install--spinner-state) 4))
      (setq mode-line-process
        (format " [%s] %s"
          (aref hsc3-tidal-install--spinner-chars hsc3-tidal-install--spinner-state)
          (process-status proc)))
      (force-mode-line-update))))

(defun hsc3-tidal-install-process-filter (proc string)
  "Process PROC filter for process hsc3-tidal installation output STRING.
Updates the buffer with output from proc and string, and updates the spinner."
  (hsc3-tidal-install--update-spinner proc)
  (let ((buffer (process-buffer proc)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((inhibit-read-only t)
               (moving (= (point) (process-mark proc))))
          (save-excursion
            (goto-char (process-mark proc))
            (dolist (c (append string nil))
              (cond
                ((= c ?\r)
                  (goto-char (line-beginning-position))
                  (set-marker (process-mark proc) (point)))
                ((= c ?\n)
                  (goto-char (point-max))
                  (insert "\n")
                  (set-marker (process-mark proc) (point)))
                (t
                  (goto-char (process-mark proc))
                  (unless (eolp) (delete-char 1))
                  (insert c)
                  (set-marker (process-mark proc) (point))))))
          (ansi-color-apply-on-region (line-beginning-position) (point-max))
          (when moving
            (goto-char (process-mark proc))
            (dolist (win (get-buffer-window-list buffer nil t))
              (set-window-point win (process-mark proc)))))))))

;;;###autoload
(defun hsc3-tidal-install-stop ()
  "Stop any active Tidal installation process."
  (interactive)
  (let ((proc (get-buffer-process hsc3-tidal-install-buffer)))
    (if (and proc (process-live-p proc))
      (progn
        (set-process-sentinel proc nil) ;; Remove sentinel to avoid triggering build steps
        (kill-process proc)
        (message "🛑 hsc3-tidal installation process stopped."))
      (message "No active installation process found."))))

(defun hsc3-tidal-install-repo ()
  "Install the hsc3-tidal package from git using cabal.
Returns the process object."
  (interactive)
  (or (file-directory-p hsc3-tidal-install-haskell-local-dir)
    (make-directory hsc3-tidal-install-haskell-local-dir t))
  (let ((coding-system-for-read 'utf-8-unix)
         (process-connection-type t))
    (with-current-buffer (get-buffer-create hsc3-tidal-install-buffer)
      (let ((inhibit-read-only t))
        (erase-buffer))
      (setq-local window-point-insertion-type t)
      (setq-local scroll-conservatively 101)
      (add-hook 'kill-buffer-hook
        (lambda ()
          (let ((p (get-buffer-process (current-buffer))))
            (when (and p (process-live-p p)) (kill-process p))))
        nil t)
      (cd hsc3-tidal-install-haskell-local-dir)
      (let ((proc (start-process
                    "hsc3-tidal-install"
                    hsc3-tidal-install-buffer
                    "git" "clone" hsc3-tidal-install-repo)))
        (when proc
          (set-process-filter proc 'hsc3-tidal-install-process-filter)
          (display-buffer hsc3-tidal-install-buffer
            '((display-buffer-reuse-window display-buffer-at-bottom)
               (window-height . 0.1)
               (side . bottom))))
        proc))))

(defun hsc3-tidal-install-build-repo ()
  "Compiles the hsc3-tidal package during the installation.
Returns the process object."
  (interactive)
  (if (and (executable-find "cabal")
        (file-directory-p hsc3-tidal-install-dir))
    (let ((coding-system-for-read 'utf-8-unix)
           (default-directory hsc3-tidal-install-dir)
           (process-connection-type t))
      (with-current-buffer (get-buffer-create hsc3-tidal-install-buffer)
        (goto-char (point-max))
        (let ((inhibit-read-only t))
          (insert "\n--- Starting Cabal Build ---\n"))
        (cd hsc3-tidal-install-dir)
        (let ((proc (start-process-shell-command
                      "hsc3-tidal-build"
                      hsc3-tidal-install-buffer
                      "cabal build")))
          (set-process-filter proc 'hsc3-tidal-install-process-filter)
          (display-buffer hsc3-tidal-install-buffer
            '((display-buffer-reuse-window display-buffer-at-bottom)
               (window-height . 0.4)
               (side . bottom)))
          proc)))
    (message "⚠️ Cabal not found or hsc3-tidal directory missing.")
    nil))

;;;###autoload
(defun hsc3-tidal-install-bash-script ()
  "Install the hsc3-tidal executable bash script in `hsc3-tidal-install-user-bin-dir'."
  (interactive)
  (unless (file-directory-p hsc3-tidal-install-user-bin-dir)
    (make-directory hsc3-tidal-install-user-bin-dir t))
  (if (file-directory-p hsc3-tidal-install-user-bin-dir)
    (progn
      (with-temp-file hsc3-tidal-install-bash-script
        (insert hsc3-tidal-install-bash-script-string))
      (set-file-modes hsc3-tidal-install-bash-script #o755)
      (message
        "✅ hsc3-tidal bash script installed at %s"
        hsc3-tidal-install-bash-script)))
  (message "❌ Error: Could not create directory %s"
    hsc3-tidal-install-user-bin-dir))

;;;###autoload
(defun hsc3-tidal-install-ghci-scripts ()
  "Install the .ghci initialization files in the haskell local dir."
  (interactive)
  (when (file-directory-p hsc3-tidal-install-dir)
    (with-temp-file hsc3-tidal-install-ghci-script
      (insert hsc3-tidal-install-ghci-script-string))
    (with-temp-file hsc3-tidal-install-ghci-script-file
      (insert hsc3-tidal-install-ghci-loadme-string))
    (message "✅ hsc3-tidal GHCi scripts installed at %s"
      hsc3-tidal-install-dir)))

;;;###autoload
(defun hsc3-tidal-install-scripts ()
  "Install both bash and GHCi scripts."
  (interactive)
  (hsc3-tidal-install-bash-script)
  (hsc3-tidal-install-ghci-scripts))

;;;###autoload
(defun hsc3-tidal-install ()
  "Perform the complete hsc3-tidal installation sequentially (Clone -> Build -> Scripts)."
  (interactive)
  (message "🚀 Starting hsc3-tidal installation...")
  (let ((clone-proc (hsc3-tidal-install-repo)))
    (if clone-proc
      (set-process-sentinel
        clone-proc
        (lambda (p event)
          (cond
            ((string-match-p "finished" event)
              (message "✅ Repo cloned. Starting build...")
              (let ((build-proc (hsc3-tidal-install-build-repo)))
                (if build-proc
                  (set-process-sentinel
                    build-proc
                    (lambda (p2 event2)
                      (if (string-match-p "finished" event2)
                        (progn
                          (message "✅ hsc3-tidal built successfully!")
                          ;; Los scripts se instalan SOLO después del build con éxito
                          (hsc3-tidal-install-scripts))
                        (message "❌ Build failed: %s" event2))))
                  (message "❌ Could not start build process."))))
            ((string-match-p "\\(aborted\\|exited\\|failed\\)" event)
              (message "❌ Clone failed: %s" event)))))
      (message "❌ Could not start clone process."))))

;;;;

(defun hsc3-tidal-install-quit-buffer ()
  "Close the hsc3-tidal installation buffer if it exists and delete its window."
  (interactive)
  (let ((buffer (get-buffer hsc3-tidal-install-buffer)))
    (and buffer
      (let ((window (get-buffer-window buffer)))
        (and window (quit-window t window))
        (and buffer (buffer-live-p buffer) (kill-buffer buffer))))))
(defalias 'quit-install 'hsc3-tidal-install-quit-buffer)

(defun hsc3-tidal-install-clean ()
  "Remove hsc3-tidal installation files and directories."
  (interactive)
  (when (file-directory-p hsc3-tidal-install-dir)
    (delete-directory hsc3-tidal-install-dir t))
  (when (file-exists-p hsc3-tidal-install-bash-script)
    (delete-file hsc3-tidal-install-bash-script))
  (let ((ghci-path (expand-file-name "hsc3-tidal-emacs.ghci" hsc3-tidal-install-dir)))
    (when (file-exists-p ghci-path)
      (delete-file ghci-path)))
  (message "🧹 hsc3-tidal installation cleaned."))

(defconst hsc3-tidal-install-bash-script-string
  (format "#!/bin/sh
PACK=%s
PACKPATH=%s
cd $PACKPATH
cabal repl --repl-options=\"-ghci-script %s-emacs.ghci\" --repl-options=-Wno-missing-home-modules"
    hsc3-tidal-install-pack-name
    hsc3-tidal-install-dir
    hsc3-tidal-install-pack-name)
  "Content of the hsc3-tidal executable bash script.
It loads Boot.ghci to work from terminal.")

(defconst hsc3-tidal-install-ghci-script-string
  (format "
:def! boot \\_ -> return \":script loadme.ghci\"
:{
let l  = replicate 35 '-'
in do
  putStrLn \"\"
  putStrLn l
  putStrLn $ \"| Type :boot to start %s. |\"
  putStrLn l
  putStrLn \"\"
:}
    " hsc3-tidal-install-pack-name))

(defconst hsc3-tidal-install-ghci-loadme-string
  (format "
:set +m

import           Sound.Sc3
import           Sound.Tidal.Context

:script BootTidal.hs

import           Sound.Sc3.Tidal
import           Sound.Sc3.Tidal.Examples

loadExamples

:set prompt \"tidal> \"
:set prompt \"\4\"
"
    hsc3-tidal-install-dir
    "Template for the hsc3-tidal.ghci file with emacs support."))

(provide 'hsc3-tidal-install)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; hsc3-tidal-install.el ends here
