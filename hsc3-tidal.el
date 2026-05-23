;;; hsc3-tidal.el --- Start hsc3-tidal in GHCi and SuperCollider -*- lexical-binding: t -*-
;;
;; Filename: hsc3-tidal.el
;; Description: Start hsc3-tidal in GHCi and SuperCollider
;; Author: Numa Tortolero
;; Maintainer: Numa Tortolero
;; Created: vie may  8 11:51:51 2026 (-0400)
;; Version: 0.1.0.6
;; Package-Requires: ((osc "0.4") (haskell-mode "17.5"))
;; URL: https://github.com/superguaricho/hsc3-tidal-el
;; Keywords: haskell tidal supercollider live-coding
;; Compatibility: GNU Emacs 29.0.50
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;;   This package provides functions to start hsc3-tidal in GHCi and
;;  SuperCollider. It uses the haskell-live package to manage the GHCi
;;  session and the sclang package to manage the SuperCollider session.
;;  It also provides a test function to play some notes on startup.
;;
;;  This version synchronizes Haskell startup with SuperDirt being ready
;;  via OSC messages and uses native haskell-mode command queuing.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;

;;; Code:

(require 'haskell-live)
(require 'sclang)
(require 'hsc3-tidal-layouts nil t)
(require 'hsc3-tidal-superdirt-install nil t)
(require 'hsc3-tidal-install nil t)
(require 'hsc3-tidal-superdirt-start nil t)

(defvar hsc3-tidal-session-name "hsc3-tidal"
  "The name of the GHCi session for hsc3-tidal.")

(defvar hsc3-tidal-version "0.1.0.0"
  "The version of the hsc3-tidal package.")

(defvar hsc3-tidal-haskell-dir
  (expand-file-name "~/.local/share/haskell")
  "The directory where the haskell scripts for hsc3-tidal are located.")

(defvar hsc3-tidal-path
  (expand-file-name (format "%s/%s"
                      hsc3-tidal-haskell-dir
                      hsc3-tidal-session-name))
  "The path to the hsc3-tidal package.")

(defvar hsc3-tidal-repl-buffer
  (format "*%s*" hsc3-tidal-session-name)
  "The name of the buffer for hsc3-tidal session.")

(defvar hsc3-tidal-ghci-script
  (expand-file-name
    (format "%s%s.ghci" hsc3-tidal-session-name "-emacs")
    hsc3-tidal-path)
  "The name of the GHCi script to load hsc3-tidal.")

(defvar hsc3-tidal-command
  (let ((script hsc3-tidal-ghci-script))
    (if (file-exists-p script)
      (format ":script %s" script)
      nil))
  "Command to load tidalcycles in ghci.")

(defvar hsc3-tidal--target-buffer-name nil
  "Internal variable to store the name of the buffer to be linked.")

(defconst hsc3-tidal-test-string
  ":{
import Sound.Sc3
import Sound.Osc

:}
")

(defvar hsc3-tidal-test nil
  "Whether to play test notes on startup.")

(declare-function tidal-layout-3 "tidal-layouts" () t)

(defun hsc3-tidal-send-command (command)
  "Send COMMAND to the hsc3-tidal session."
  (let* ((session (haskell-live-get-session-by-name
                    hsc3-tidal-session-name))
          (proc (and session (haskell-session-process session))))
    (and proc (process-live-p (haskell-process-process proc))
      (haskell-process-send-string proc command))))

(defun hsc3-tidal-boot ()
  "Send the `:boot' command to the hsc3-tidal session."
  (interactive)
  (hsc3-tidal-send-command ":boot"))

(defun hsc3-tidal-test ()
  "Send the `hsc3-tidal-test-string' command to the hsc3-tidal session."
  (interactive)
  (hsc3-tidal-send-command hsc3-tidal-test-string))

(defun hsc3-tidal-startup ()
  "This function runs when GHCi is starting.
Synchronized via GHCi script prompt \\4."
  (interactive)
  (let ((proc (haskell-process)))
    (if proc
      (progn
        (haskell-process-queue-command
          proc
          (make-haskell-command
            :state proc
            :go (lambda (p)
                  (haskell-process-send-string p
                    hsc3-tidal-command)
                  (message
                    "⏳ Initializing hsc3-tidal with hsc3-tidal-emacs.ghci..."))))
        (haskell-process-queue-command
          proc
          (make-haskell-command
            :state proc
            :go (lambda (p)
                  (haskell-process-send-string p ":boot")
                  (message "🚀 Booting Tidal/Hsc3 environment..."))
            :complete (lambda (p _)
                        (when (fboundp 'hsc3-tidal-layouts-layout-3) (hsc3-tidal-layouts-layout-3))
                        (and hsc3-tidal-test
                          (haskell-process-send-string p
                            hsc3-tidal-test-string))
                        (message "✨ hsc3-tidal ready and synchronized!")))))
      (message "⚠️ Haskell process has not been found."))))

;;;###autoload
(defun hsc3-tidal-run ()
  "Run interactive hsc3 process."
  (interactive)
  (message "🚀 Triggering hsc3 Haskell startup...")
  (remove-hook 'hsc3-tidal-superdirt-startup-functions 'hsc3-tidal-run)
  (let ((haskell-buffer (haskell-live-get-haskell-buffer)))
    (if (not (get-buffer hsc3-tidal-repl-buffer))
      (let* ((session (haskell-live-get-session-by-name hsc3-tidal-session-name))
              (proc (and session (haskell-session-process session))))
        (and proc (process-live-p (haskell-process-process proc))
          (kill-process (haskell-process-process proc)))
        (setq haskell-process-type 'cabal-repl)
        (message "🔄 starting %s session..." hsc3-tidal-session-name)
        (if haskell-buffer
          (with-current-buffer haskell-buffer
            (haskell-live-process-start
              hsc3-tidal-session-name
              hsc3-tidal-path
              nil
              'hsc3-tidal-startup))
          (haskell-live-process-start
            hsc3-tidal-session-name
            hsc3-tidal-path
            nil
            'hsc3-tidal-startup)))
      (haskell-live-add-to-session hsc3-tidal-session-name))))

(setq hsc3-tidal-superdirt-startup-functions nil)

(declare-function hsc3-tidal-start-superdirt "hsc3-tidal-superdirt-start" () t)

;;;###autoload
(defun hsc3-tidal-sclang ()
  "Start sclang and wait for SuperDirt to be ready before starting hsc3-tidal."
  (interactive)
  (add-to-list 'hsc3-tidal-superdirt-startup-functions #'hsc3-tidal-run)
  (add-hook 'sclang-library-startup-hook #'hsc3-tidal-start-superdirt 95)
  (let ((proc (get-process sclang-process)))
    (if (and proc (process-live-p proc))
      (message "SuperDirt already running; waiting for ready signal...")
      (sclang-start))))
(keymap-set haskell-mode-map "C-c >" #'hsc3-tidal-sclang)

(defalias 'turpial 'hsc3-tidal-sclang)

(remove-hook 'hsc3-tidal-superdirt-startup-functions 'hsc3-tidal-run)

;;;###autoload
(defalias 'hsc3-tidal 'hsc3-tidal-sclang)

;;;###autoload
(defun hsc3-tidal-restart-tidal ()
  "Restart the hsc3-tidal session."
  (interactive)
  (haskell-process-show-repl-response hsc3-tidal-command))

;;;

(defun hsc3-tidal-kill-sc-buffers ()
  "Kill the supercollider buffers."
  (interactive)
  (let ((wsbuf (get-buffer "*SClang:Workspace*"))
         (postbuf (get-buffer sclang-post-buffer)))
    (and wsbuf (kill-buffer wsbuf))
    (and postbuf (kill-buffer postbuf))))

(defun hsc3-tidal-kill-sclang ()
  "Kill the supercollider system."
  (interactive)
  (sclang-kill)
  (hsc3-tidal-kill-sc-buffers))

;;;###autoload
(defun hsc3-tidal-kill ()
  "kill the ghci hsc3-tidal session."
  (interactive)
  (let ((main-buffer (current-buffer)))
    (and (or (get-process sclang-process)
           (get-buffer sclang-post-buffer))
      (kill-sclang))
    (and (get-buffer hsc3-tidal-repl-buffer)
      (kill-buffer hsc3-tidal-repl-buffer))
    (select-window (sclang-ext-get-main-window))
    (delete-other-windows)
    (switch-to-buffer main-buffer)))
(keymap-set haskell-mode-map "C-c <" #'hsc3-tidal-kill)

;;;###autoload
(defalias 'kill-hsc3-tidal 'hsc3-tidal-kill)

(provide 'hsc3-tidal)
;;; hsc3-tidal.el ends here
