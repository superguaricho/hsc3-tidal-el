;;; hsc3-tidal-layouts.el -- Layout windows handler for hsc3-tidal  -*- lexical-binding: t -*-

;; Copyright (C) 2020 numa.tortolero@gmail.com
;; Author: numa.tortolero@gmail.com
;; Homepage: https://github.com/superguaricho/hsc3-tidal-el

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;    Functions to manage window layout in sclang-mode and haskell-mode.
;;      What these codes do, is display the sclang interpreter window and
;;      the haskell repl window in different layouts.
;;
;;    You have 4 different layouts to choose from, that you can
;;      activate with C-c C-0, C-c C-1, C-c C-2 and C-c C-3.
;;
;;   This file es part of my sclang-ext package. See the README.md
;;   or the sclang-ext.el commentary to know about how install it.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'sclang)
(require 'haskell-live)

(autoload 'hsc3-tidal-layouts-haskell-session-buffer
  "hsc3-tidal-layouts-start-ghci")

(defvar sclang-post-buffer)
(defvar hsc3-tidal-layouts-post-buffer
  (or sclang-post-buffer "*SCLang:PostBuffer"))

(defun hsc3-tidal-layouts-haskell-buffer ()
  "Get the work Haskell buffer from current session."
  (and
    (equal major-mode 'haskell-mode)
    (default-boundp 'haskell-session)
    (haskell-session-get haskell-session 'interactive-buffer)))

(defun hsc3-tidal-layouts-python-buffer ()
  "Get the work Python buffer from current session."
  (and
    (equal major-mode 'python-mode)
    nil))

;;;

(defun hsc3-tidal-layouts-side-window-p (window)
  "Return non nil if WINDOW is a side window."
  (window-parameter window 'window-side))

(defun hsc3-tidal-layouts-main-window-p (window)
  "Return non nil if WINDOW is the main window."
  (not (hsc3-tidal-layouts-side-window-p window)))

(defun hsc3-tidal-layouts-get-main-window ()
  "Walk the current frame window list. Return the  not lateral window."
  (interactive)
  (let ((current-win (selected-window)))
    (if (hsc3-tidal-layouts-main-window-p current-win)
      current-win
      (cl-find-if (lambda (w)
                    (hsc3-tidal-layouts-main-window-p w))
        (window-list)))))

(defun hsc3-tidal-layouts-get-sclang-buffer ()
  "Get the SCLang post buffer."
  (get-buffer sclang-post-buffer))

(defun hsc3-tidal-layouts-layout-0 ()
  "Set 3x3 window layout.
Haskell repl at bottom of main window.
SCLang post buffer at bottom of Haskell repl buffer."
  (interactive)
  (let* ((topmost-window (frame-first-window))
          (main-buffer (window-buffer topmost-window))
          (main-window (hsc3-tidal-layouts-get-main-window))
          (point (point)))
    (delete-other-windows main-window)
    (save-excursion
      (switch-to-buffer (get-buffer main-buffer))
      (display-buffer (get-buffer (hsc3-tidal-layouts-haskell-buffer))
        '((display-buffer-below-selected)
           (inhibit-same-window . t)
           (window-height . 0.35)))
      (display-buffer (hsc3-tidal-layouts-get-sclang-buffer)
        '((display-buffer-at-bottom)
           (inhibit-same-window . t)
           (window-height . 0.15)))
      (select-window (get-buffer-window main-buffer))
      (goto-char point)
      t)))

(defun hsc3-tidal-layouts-layout-1 ()
  "Set 3x3 window layout.
Haskell repl at right side.
SCLang post buffer at bottom main en Haskell repl buffers."
  (interactive)
  (let* ((topmost-window (frame-first-window))
          (main-buffer (window-buffer topmost-window))
          (main-window (hsc3-tidal-layouts-get-main-window))
          (point (point)))
    (delete-other-windows main-window)
    (save-excursion
      (switch-to-buffer (get-buffer main-buffer))
      (display-buffer (hsc3-tidal-layouts-haskell-buffer)
        '((display-buffer-in-side-window)
           (inhibit-same-window . t)
           (side . right)
           (window-width . 0.4)))
      (display-buffer-in-side-window
        (hsc3-tidal-layouts-get-sclang-buffer)
        '((display-buffer-below)
           (inhibit-same-window . t)
           (window-height . 0.3)))
      (select-window (get-buffer-window main-buffer))
      (goto-char point)
      t)))

(defun hsc3-tidal-layouts-layout-2 ()
  "Set 3x3 window layout with.
Haskell repl buffer at right side.
SCLang post buffer at bottom of main buffer."
  (interactive)
  (let* ((topmost-window (frame-first-window))
          (main-buffer (window-buffer topmost-window))
          (main-window (hsc3-tidal-layouts-get-main-window))
          (point (point)))
    (delete-other-windows main-window)
    (save-excursion
      (switch-to-buffer (get-buffer main-buffer)
        (display-buffer (hsc3-tidal-layouts-haskell-buffer))
        '((display-buffer-in-side-window)
           (inhibit-same-window . t)
           (side . right)
           (window-width . 0.4)))
      (display-buffer
        (hsc3-tidal-layouts-get-sclang-buffer)
        '((display-buffer-below-selected)
           (inhibit-same-window . t)
           (window-height . 0.3)))
      (select-window (get-buffer-window main-buffer))
      (goto-char point)
      t)))

(defun hsc3-tidal-layouts-layout-3 ()
  "Set 3x3 window layout:
Haskell repl at right side.
SCLang post buffer at bottom of Haskell repl Buffer."
  (interactive)
  (let* ((topmost-window (frame-first-window))
          (main-buffer (window-buffer topmost-window))
          (main-window (hsc3-tidal-layouts-get-main-window))
          (point (point)))
    (delete-other-windows main-window)
    (save-excursion
      (switch-to-buffer (hsc3-tidal-layouts-haskell-buffer))
      (and (hsc3-tidal-layouts-get-sclang-buffer)
        (display-buffer (hsc3-tidal-layouts-get-sclang-buffer)
          '((display-buffer-below-selected)
             (inhibit-same-window . t)
             (window-height . 0.3))))
      (display-buffer (get-buffer main-buffer)
        '((display-buffer-in-side-window)
           (inhibit-same-window . t)
           (side . left)
           (window-width . 0.6)))
      (select-window (get-buffer-window main-buffer))
      (goto-char point)
      t)))

(defun hsc3-tidal-layouts-layout-keybindings ()
  "`sclang-ext' keybindings in `sclang-mode' MAP."
  (interactive)
  (local-set-key (kbd "C-c C-0") 'hsc3-tidal-layouts-layout-0)
  (local-set-key (kbd "C-c C-1") 'hsc3-tidal-layouts-layout-1)
  (local-set-key (kbd "C-c C-2") 'hsc3-tidal-layouts-layout-2)
  (local-set-key (kbd "C-c C-3") 'hsc3-tidal-layouts-layout-3)
  )
(add-hook 'sclang-mode-hook 'hsc3-tidal-layouts-layout-keybindings)
(add-hook 'haskell-mode-hook 'hsc3-tidal-layouts-layout-keybindings)

(provide 'hsc3-tidal-layouts)
;;; hsc3-tidal-layouts.el ends here
