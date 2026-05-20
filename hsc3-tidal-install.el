;;; hsc3-tidal-install.el --- Installation script for hsc3 and TidalCycles
;;
;; Filename: hsc3-tidal-install.el
;; Description: Emacs Lisp script to automate the installation of vivid-tidal.
;; Author: Numa Tortolero
;; Created: mié may 13 20:20:23 2026 (-0400)
;; URL: https://github.com/superguaricho/hsc3-tidal
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;  This Emacs Lisp script automates the installation of hsc3-tidal,
;; a Haskell package for live coding music with SuperCollider. It clones
;; the Vivid-Tidal repository from GitHub, builds it using Cabal, and
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

(defvar hsc3-tidal-haskell-local-dir
  (expand-file-name "~/.local/share/haskell")
  "Base directory for local Haskell installations.
hsc3-tidal will be installed in a subdirectory here.")

(defvar hsc3-tidal-install-buffer "*hsc3-tidal installation*")

(defvar hsc3-tidal-install-pack-name "hsc3-tidal"
  "Name of the Vivid-Tidal package for installation and script generation.")

(defvar hsc3-tidal-install-version ""
  "Version of hsc3-tidal to install. Update this to install a different version.")

(defvar hsc3-tidal-install-dir
  (expand-file-name hsc3-tidal-install-pack-name hsc3-tidal-haskell-local-dir)
  "Directory where TidalCycles source will be cloned and built.")

(defvar hsc3-tidal-install-repo
  (format "https://github.com/superguaricho/%s" hsc3-tidal-install-pack-name))

(defvar hsc3-tidal-install-user-bin-dir (expand-file-name "~/.local/bin/")
  "Directory where the Tidal executable script will be placed.")

(defvar hsc3-tidal-install-bash-script
  (expand-file-name hsc3-tidal-install-pack-name hsc3-tidal-install-user-bin-dir)
  "Path to the Vivid-Tidal executable script.")

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
        (message "🛑 Vivid-Tidal installation process stopped."))
      (message "No active installation process found."))))

(defun hsc3-tidal-install-repo ()
  "Install the Vivid-Tidal package from git using cabal.
Returns the process object."
  (interactive)
  (or (file-directory-p hsc3-tidal-haskell-local-dir)
    (make-directory hsc3-tidal-haskell-local-dir t))
  (let ((coding-system-for-read 'utf-8-unix)
         (default-directory hsc3-tidal-haskell-local-dir)
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
      (cd default-directory)
      (let ((proc (start-process
                    (format "Clone %s" hsc3-tidal-install-pack-name)
                    hsc3-tidal-install-buffer
                    "git" "clone"  hsc3-tidal-install-repo)))
        (when proc
          (set-process-filter proc 'hsc3-tidal-install-process-filter)
          (display-buffer hsc3-tidal-install-buffer
            '((display-buffer-reuse-window display-buffer-at-bottom)
               (window-height . 0.1)
               (side . bottom))))
        proc))))

(defun hsc3-tidal-install-build-repo ()
  "Compiles the vivid-tidal package during the installation.
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
                      "Vivid-Tidal build"
                      hsc3-tidal-install-buffer
                      "cabal build")))
          (set-process-filter proc 'hsc3-tidal-install-process-filter)
          (display-buffer hsc3-tidal-install-buffer
            '((display-buffer-reuse-window display-buffer-at-bottom)
               (window-height . 0.4)
               (side . bottom)))
          proc)))
    (message "⚠️ Cabal not found or vivid-tidal directory missing.")
    nil))

;;;###autoload
(defun hsc3-tidal-install-build ()
  "Install and build Vivid-Tidal sequentially using process sentinels."
  (interactive)
  (let ((clone-proc (hsc3-tidal-install-repo)))
    (set-process-sentinel
      clone-proc
      (lambda (p event)
        (cond
          ((string-match-p "finished" event)
            (message "✅ Repo cloned. Starting build...")
            (let ((build-proc (hsc3-tidal-install-build-repo)))
              (when build-proc
                (set-process-sentinel
                  build-proc
                  (lambda (p2 event2)
                    (if (string-match-p "finished" event2)
                      (progn
                        (message "✅ Vivid-Tidal built successfully!")
                        (hsc3-tidal-install-scripts))
                      (message "❌ Build failed: %s" event2)))))))
          (t (message "❌ Clone failed: %s" event)))))))

;;;###autoload
(defun hsc3-tidal-install-bash-script ()
  "Install the Vivid-Tidal executable bash script in `hsc3-tidal-install-user-bin-dir'."
  (interactive)
  (unless (file-directory-p hsc3-tidal-install-user-bin-dir)
    (make-directory hsc3-tidal-install-user-bin-dir t))
  (if (file-directory-p hsc3-tidal-install-user-bin-dir)
    (progn
      (with-temp-file hsc3-tidal-install-bash-script
        (insert hsc3-tidal-install-bash-script-string))
      (set-file-modes hsc3-tidal-install-bash-script #o755)
      (message "✅ Vivid-Tidal bash script installed at %s" hsc3-tidal-bash-script))
    (message "❌ Error: Could not create directory %s" hsc3-tidal-install-user-bin-dir)))

;;;###autoload
(defun hsc3-tidal-install-ghci-script ()
  "Install the Vivid-Tidal.ghci initialization file in the haskell local dir."
  (interactive)
  (let ((ghci-path
          (expand-file-name
            (format "%s.ghci" hsc3-tidal-install-pack-name)
            hsc3-tidal-install-dir)))
    (unless (file-directory-p hsc3-tidal-haskell-local-dir)
      (make-directory hsc3-tidal-haskell-local-dir t))
    (with-temp-file ghci-path
      (insert hsc3-tidal-install-ghci-script-string))
    (message "✅ Vivid-Tidal GHCi script installed at %s" ghci-path)))

;;;###autoload
(defun hsc3-tidal-install-scripts ()
  "Install both bash and GHCi scripts."
  (interactive)
  (hsc3-tidal-install-bash-script)
  (hsc3-tidal-install-ghci-script))

;;;###autoload
(defun hsc3-tidal-install ()
  "Perform the complete Vivid-Tidal installation.
This chains: clone -> build -> script installation."
  (interactive)
  (message "🚀 Starting Vivid-Tidal installation...")
  (hsc3-tidal-install-build)
  (hsc3-tidal-install-scripts))

;;;;

(defun hsc3-tidal-install-quit-buffer ()
  "Close the Vivid-Tidal installation buffer if it exists and delete its window."
  (interactive)
  (let ((buffer (get-buffer hsc3-tidal-install-buffer)))
    (and buffer
      (let ((window (get-buffer-window buffer)))
        (and window (quit-window t window))
        (and buffer (buffer-live-p buffer) (kill-buffer buffer))))))
(defalias 'quit-install 'hsc3-tidal-install-quit-buffer)

(defun hsc3-tidal-install-clean ()
  "Remove Vivid-Tidal installation files and directories."
  (interactive)
  (when (file-directory-p hsc3-tidal-install-dir)
    (delete-directory hsc3-tidal-install-dir t))
  (when (file-exists-p hsc3-tidal-install-bash-script)
    (delete-file hsc3-tidal-install-bash-script))
  (let ((ghci-path (expand-file-name "Vivid-Tidal.ghci" hsc3-tidal-haskell-local-dir)))
    (when (file-exists-p ghci-path)
      (delete-file ghci-path)))
  (message "🧹 Vivid-Tidal installation cleaned."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst hsc3-tidal-install-bash-script-string
  (format "#!/bin/sh
PACK=%s
PACKPATH=%s
cd $PACKPATH
cabal repl --repl-options=\"-ghci-script Boot.ghci\" --repl-options=-Wno-missing-home-modules"
    hsc3-tidal-install-pack-name
    hsc3-tidal-install-dir)
  "Content of the vivid-tidal executable bash script.
It loads Boot.ghci to work from terminal.")

(defconst hsc3-tidal-install-ghci-script-string
  (format "
:cd %s
:set +m

import           Sound.Sc3
import           Sound.Tidal.Context

tidal <- starttidal (superdirttarget {olatency = 0.1, oaddress = \"127.0.0.1\", oport = 57120}) (defaultconfig {cframetimespan = 1/20})

let p = streamreplace tidal
    hush = streamhush tidal
    list = streamlist tidal
    mute = streammute tidal
    unmute = streamunmute tidal
    solo = streamsolo tidal
    unsolo = streamunsolo tidal
    once = streamonce tidal
    asap = once
    nudgeall = streamnudgeall tidal
    all = streamall tidal
    resetcycles = streamresetcycles tidal
    setcps = asap . cps
    xfade i = transition tidal true (sound.tidal.transition.xfadein 4) i
    xfadein i t = transition tidal true (sound.tidal.transition.xfadein t) i
    histpan i t = transition tidal true (sound.tidal.transition.histpan t) i
    wait i t = transition tidal true (sound.tidal.transition.wait t) i
    waitt i f t = transition tidal true (sound.tidal.transition.waitt f t) i
    jump i = transition tidal true (sound.tidal.transition.jump) i
    jumpin i t = transition tidal true (sound.tidal.transition.jumpin t) i
    jumpin' i t = transition tidal true (sound.tidal.transition.jumpin' t) i
    jumpmod i t = transition tidal true (sound.tidal.transition.jumpmod t) i
    mortal i lifespan release = transition tidal true (sound.tidal.transition.mortal lifespan release) i
    interpolate i = transition tidal true (sound.tidal.transition.interpolate) i
    interpolatein i t = transition tidal true (sound.tidal.transition.interpolatein t) i
    clutch i = transition tidal true (sound.tidal.transition.clutch) i
    clutchin i t = transition tidal true (sound.tidal.transition.clutchin t) i
    anticipate i = transition tidal true (sound.tidal.transition.anticipate) i
    anticipatein i t = transition tidal true (sound.tidal.transition.anticipatein t) i
    forid i t = transition tidal false (sound.tidal.transition.mortaloverlay t) i
    d1 = p 1
    d2 = p 2
    d3 = p 3
    d4 = p 4
    d5 = p 5
    d6 = p 6
    d7 = p 7
    d8 = p 8
    d9 = p 9
    d10 = p 10
    d11 = p 11
    d12 = p 12
    d13 = p 13
    d14 = p 14
    d15 = p 15
    d16 = p 16

:set prompt \"tidal> \"
:set prompt \"\\4\"
"
    hsc3-tidal-install-dir
    "Template for the hsc3-tidal.ghci file with emacs support."))

(provide 'hsc3-tidal-install)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; hsc3-tidal-install.el ends here
