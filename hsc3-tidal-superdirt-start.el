;;; hsc3-tidal-superdirt-start.el --- SuperDirt initialization for sclang in Emacs -*- lexical-binding: t -*-
;;
;; Filename: hsc3-tidal-superdirt-start.el
;; Description: SuperDirt initialization for sclang in Emacs
;; Author: Numa Tortolero
;; Maintainer: Numa Tortolero
;; Created: vie ene 23 22:36:06 2026 (-0400)
;; URL: https://github.com/superguaricho/hsc3-tidal-el
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;   This Emacs Lisp file provides initialization for SuperDirt
;;   when using SuperCollider (sclang) within Emacs. It includes
;;   functions to start SuperDirt with enhanced memory settings,

;;   set up an OSC listener in Emacs to monitor SuperDirt's status,
;;   and display notifications when SuperCollider and SuperDirt
;;   are ready.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Code:

(require 'sclang)
(require 'tidal-osc)
(require 'hsc3-tidal-superdirt-install)

(declare-function haskell-interactive-switch "haskell")

(add-to-list 'load-path
  (file-name-directory (or load-file-name buffer-file-name)))

(setq sclang-show-workspace-on-startup nil)

;;;###autoload
(defvar hsc3-tidal-superdirt-startup-functions nil
  "List of functions to run when SuperDirt starts up.")

;; -----------------------------------------------------------------------------
;; OSC Monitor for SuperDirt
;; -----------------------------------------------------------------------------

(defvar hsc3-tidal-emacs-osc-server nil)
(defvar hsc3-tidal-superdirt-boot-hook nil)
(defvar hsc3-tidal-osc-server nil
  "OSC server process in Emacs for SuperDirt communication.")

(defun hsc3-tidal-on-superdirt-ready-osc ()
  "Action when Emacs receives OSC from SuperDirt."
  (message "📡 OSCSIGNAL -> SuperDirt is READY! 📡")
  (beep)
  (message "hsc3-tidal-superdirt-startup-functions: %s"
    hsc3-tidal-superdirt-startup-functions)
  (and hsc3-tidal-superdirt-startup-functions
    (mapc #'funcall hsc3-tidal-superdirt-startup-functions)))

(defun hsc3-tidal-remove-emacs-osc-listener ()
  "Stop the OSC listener in Emacs on port 7777."
  (interactive)
  (and (get-process "OSCserver")
    (ignore-errors (delete-process "OSCserver")))
  (and hsc3-tidal-osc-server
    (process-status hsc3-tidal-osc-server)
    (delete-process hsc3-tidal-osc-server)))

(defun hsc3-tidal-start-emacs-osc-listener ()
  "Restart the OSC listener in Emacs on port 7777."
  (interactive)
  (hsc3-tidal-remove-emacs-osc-listener)
  (message "👂 Emacs: Starting OSC listener on port 7777...")
  (setq hsc3-tidal-osc-server
    (osc-make-server "127.0.0.1" 7777
      (lambda (path &rest args)
        (cond
          ((string= path "/dirt/ready")
            (run-hooks 'hsc3-tidal-superdirt-boot-hook)))))))

(add-hook 'hsc3-tidal-superdirt-boot-hook #'hsc3-tidal-on-superdirt-ready-osc)

(declare-function hsc3-tidal-superdirt-install-get-resdir
  "hsc3-tidal-superdirt-install")

(defvar hsc3-tidal-superdirt-start-resdir
  (or (hsc3-tidal-superdirt-install-get-resdir)
    (expand-file-name "~/.local/share/SuperCollider")))

(defvar hsc3-tidal-superdirt-start-synthsdir
  (expand-file-name "synthdefs" hsc3-tidal-superdirt-start-resdir))

;;;###autoload
(defun hsc3-tidal-start-superdirt ()
  "Start SuperDirt with extended memory options."
  (interactive)
  (hsc3-tidal-start-emacs-osc-listener)
  (message "📡 Sending configuration from SuperDirt to SCLang (port 7777)...")
  (sclang-eval-string
    (format
      "(
s.options.numBuffers = 1024 * 256;
s.options.memSize = 8192 * 32;
s.options.numWireBufs = 2048;
s.options.maxNodes = 1024 * 32;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.waitForBoot {
    // 1. Ensure SuperDirt is running
    if (~dirt.isNil, {
        ~dirt = SuperDirt(2, s);
        ~dirt.loadSoundFiles;
        ~dirt.start(57120, 0 ! 12);
        SuperDirt.default = ~dirt;
        s.latency = 0.3;
        \"hsc3: SuperDirt STARTED\".postln;
    }, {
        \"hsc3: SuperDirt already running, ensuring listeners...\".postln;
    });

    // 2. Always ensure OSC listeners are installed (Idempotent with OSCdef)
    thisProcess.openUDPPort(57120);

    ~printCheatSheet = {
        \"\".postln;
        \"--- hsc3 Sample Cheat Sheet ---\".postln;
        [\\bd, \\sn, \\cp, \\hh, \\arpy, \\casio, \\drum].do { |name|
            if (~dirt.notNil and: { ~dirt.buffers[name].notNil }) {
                (\"Sample '\" ++ name ++ \"' -> Buffer: \" ++ ~dirt.buffers[name][0].bufnum).postln;
            };
        };
        \"-------------------------------\".postln;
    };

    OSCdef(\\hsc3Reload, { |msg|
        var path = \"%s\".standardizePath;
        if(path.endsWith(Platform.pathSeparator.asString).not) { path = path ++ Platform.pathSeparator };
        \"hsc3: Syncing Server and SuperDirt...\".postln;
        fork {
            s.sendMsg(\"/d_loadDir\", path);
            s.sync;

            // Populate SynthDescLib and SuperDirt explicitly
            pathMatch(path ++ \"*.scsyndef\").do { |file|
                var descs = SynthDesc.read(file);
                if (descs.notNil) {
                    descs.do { |desc|
                        SynthDescLib.global.add(desc);
                        if (~dirt.notNil) {
                            ~dirt.soundLibrary.addSynth(desc.name.asSymbol);
                        };
                    };
                };
            };

            s.sync;
            0.2.wait;
            if (~dirt.notNil) { ~dirt.loadSynthDefs };
            \"hsc3: Sync complete. All definitions ready.\".postln;
            0.5.wait;
            ~printCheatSheet.value;
        };
    }, '/hsc3/reload');

    OSCdef(\\hsc3Cheat, { ~printCheatSheet.value; }, '/hsc3/cheat');

    \"hsc3: OSC Listeners INSTALLED/UPDATED on port 57120\".postln;

    // 3. Notify Emacs that SuperDirt and hsc3 are ready (Port 7777) ---
    s.sync;
    NetAddr(\"127.0.0.1\", 7777).sendMsg(\"/dirt/ready\", \"SuperDirt is ready\");
    \"hsc3: SuperDirt is ready. Notifying Emacs on port 7777...\".postln;
};
)"
      hsc3-tidal-superdirt-start-synthsdir)))

(add-hook 'sclang-library-startup-hook #'hsc3-tidal-start-superdirt 95)

(provide 'hsc3-tidal-superdirt-start)
;;; hsc3-tidal-superdirt-start.el ends here
