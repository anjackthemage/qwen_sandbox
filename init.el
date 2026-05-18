;;; init.el --- TUI-first C/C++ development configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Optimized for Emacs 30+ daemon mode with `emacsclient -t` (TUI primary).
;; C/C++ development via eglot + clangd.  CachyOS / Arch Linux.
;;
;; ── PHASED ROLLOUT ────────────────────────────────────────────────────────────
;;
;;  New tools are gated behind `:disabled t` in their use-package blocks.
;;  To activate a phase:
;;    1. Find every block marked "PHASE N — remove :disabled t to enable"
;;    2. Delete the `  :disabled t` line from each block
;;    3. Restart Emacs, or: M-x eval-buffer
;;
;;  Phase 1 — Build & Terminal      (cmake-integration, vterm)         ACTIVE
;;  Phase 2 — Org Notes & Tasks     (org base config, agenda, capture) ACTIVE *
;;  Phase 3 — Debugging             (dape + codelldb)                  DISABLED
;;  Phase 4 — Knowledge Graph       (org-roam, org-kanban)             DISABLED
;;  Phase 5 — Architecture Diagrams (plantuml, ob-mermaid)             DISABLED
;;
;;  * org is built-in — no download occurs.  Do this first:
;;      mkdir -p ~/org/multisim
;;    Then use C-c o c to capture your first note.
;;
;; ── PREREQUISITES (pacman) ────────────────────────────────────────────────────
;;
;; Always:
;;   pacman -S clang ripgrep bear pandoc
;;
;; Phase 1:
;;   pacman -S libvterm
;;
;; Phase 3 — one-time codelldb setup:
;;   wget https://github.com/vadimcn/codelldb/releases/latest/download/codelldb-x86_64-linux.vsix
;;   mkdir -p ~/.emacs.d/debug-adapters
;;   unzip codelldb-x86_64-linux.vsix -d ~/.emacs.d/debug-adapters/codelldb
;;
;; Phase 5:
;;   pacman -S plantuml nodejs npm
;;   npm install -g @mermaid-js/mermaid-cli
;;
;; First run (any phase): M-x nerd-icons-install-fonts
;;
;; Per-project compile_commands.json:
;;   cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
;;   ln -s build/compile_commands.json .

;;; Code:

;; ============================================================
;; Early performance
;; ============================================================
(setq gc-cons-threshold (* 128 1024 1024))
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 20 1024 1024))
            (message "Emacs loaded in %s with %d GCs."
                     (format "%.2f seconds"
                             (float-time
                              (time-subtract after-init-time before-init-time)))
                     gcs-done)))

(setq read-process-output-max (* 1024 1024))

;; ============================================================
;; Package system bootstrap
;; ============================================================
(require 'package)
(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; ============================================================
;; Redirect Custom to its own file
;; ============================================================
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file :noerror :nomessage))

;; ============================================================
;; Daemon / server
;; ============================================================
(require 'server)
(unless (server-running-p)
  (server-start))

;; ============================================================
;; Catppuccin Theme (Mocha)
;; ============================================================
(use-package catppuccin-theme
  :config
  (setq catppuccin-flavor 'mocha)
  (load-theme 'catppuccin :no-confirm))

;; ============================================================
;; GUI-only settings
;; ============================================================
(defun my/apply-gui-settings (frame)
  "Apply GUI-specific font and display settings to FRAME."
  (when (display-graphic-p frame)
    (set-face-attribute 'default frame
                        :family "BlexMono Nerd Font Mono"
                        :height 130)
    (set-face-attribute 'fixed-pitch frame
                        :family "BlexMono Nerd Font Mono"
                        :height 130)
    (set-frame-parameter frame 'alpha-background 85)
    (set-fringe-mode 16)
    (pixel-scroll-precision-mode 1)))

(add-hook 'window-setup-hook
          (lambda () (my/apply-gui-settings (selected-frame))))
(add-hook 'after-make-frame-functions #'my/apply-gui-settings)

;; ============================================================
;; TUI settings
;; ============================================================
(defun my/apply-tui-settings (frame)
  "Apply terminal-specific visual tweaks to FRAME."
  (unless (display-graphic-p frame)
    (set-face-background 'default "none" frame)
    (set-face-attribute 'font-lock-comment-face frame
                        :foreground "#89dceb"
                        :slant 'italic)))

(add-hook 'after-make-frame-functions #'my/apply-tui-settings)
(add-hook 'window-setup-hook
          (lambda () (my/apply-tui-settings (selected-frame))))

;; ============================================================
;; General UI
;; ============================================================
(menu-bar-mode   -1)
(tool-bar-mode   -1)
(scroll-bar-mode -1)
(setq inhibit-startup-message t)
(setq use-short-answers t)
;;(setq confirm-kill-emacs #'yes-or-no-p)

(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)

(save-place-mode 1)

(recentf-mode 1)
(savehist-mode 1)
(setq savehist-file (expand-file-name "savehist" user-emacs-directory)
      savehist-additional-variables '(compile-command
				      isearch-ring
				      regexp-search-ring)
      savehist-save-minibuffer-history t)
(setq recentf-max-menu-items 30
      recentf-max-saved-items 100)

(global-auto-revert-mode 1)
(setq auto-revert-verbose nil)
(setq vc-follow-symlinks t)

;; ============================================================
;; Line numbers & column
;; ============================================================
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(setq-default display-line-numbers-type 'relative)
(column-number-mode 1)
(global-hl-line-mode 1)

;; ============================================================
;; nerd-icons  (M-x nerd-icons-install-fonts — once only)
;; ============================================================
(use-package nerd-icons
  :config (setq nerd-icons-font-family "BlexMono Nerd Font Mono"))

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-completion
  :after marginalia
  :config (nerd-icons-completion-mode))

;; ============================================================
;; doom-modeline
;; ============================================================
(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :custom
  (doom-modeline-height 32)
  (doom-modeline-bar-width 6)
  (doom-modeline-icon t)
  (doom-modeline-major-mode-icon t)
  (doom-modeline-buffer-file-name-style 'truncate-upto-project)
  (doom-modeline-column-zero-based nil)
  (doom-modeline-enable-word-count nil))

;; ============================================================
;; Dashboard
;;
;; The `agenda' widget is wired in now; it shows empty until you
;; create org files in Phase 2.  It does not error when empty.
;; ============================================================
(use-package dashboard
  :config
  (setq dashboard-startup-banner    'official
        dashboard-center-content    t
        dashboard-set-heading-icons t
        dashboard-set-file-icons    t
        dashboard-banner-logo-title "Commence to Clack'n"
        dashboard-items '((recents   . 7)
                          (projects  . 5)
                          (bookmarks . 5)
                          (agenda    . 5)))
  (dashboard-setup-startup-hook))

(setq initial-buffer-choice
      (lambda () (get-buffer-create "*dashboard*")))

;; ============================================================
;; Window management
;; ============================================================
(winner-mode 1)

;; auto-resize frames upon window resize
(add-hook 'window-size-change-functions
	  (lambda (frame)
	    ;; prevents layout collapse when terminal window size changes
	    (setq window-min-width 10
		  window-min-height 4)))

(defun my/setup-dev-layout ()
  "Four-pane C/C++ coding layout:
   ┌────────┬──────────────┬──────────────────┐
   │        │ reference A  │                  │
   │  Tree  │  (top-mid)   │  current buffer  │
   │  macs  ├──────────────┤  (right pane)    │
   │        │ reference B  │                  │
   └────────┴──────────────┴──────────────────┘
   Bind: C-c w l   Navigate: Shift-arrow"
  (interactive)
  (delete-other-windows)
  (let* ((main-window (selected-window))
	 (right-pane (split-window-right)))
    (select-window main-window)
    (split-window-below)
    (select-window right-pane)
      (treemacs)))

(defun my/setup-org-layout ()
  "Two-pane org layout: note (left 65%) + backlinks (right 35%).
   Requires Phase 4 (org-roam).  Bind: C-c w o"
  (interactive)
  (delete-other-windows)
  (let ((right (split-window-right (floor (* 0.65 (frame-width))))))
    (select-window right)
    (if (fboundp 'org-roam-buffer-toggle)
        (org-roam-buffer-toggle)
      (message "org-roam not active yet — enable Phase 4 in init.el"))
    (select-window (previous-window))))

(global-set-key (kbd "C-c w l") #'my/setup-dev-layout)
(global-set-key (kbd "C-c w o") #'my/setup-org-layout)
(global-set-key (kbd "C-c w u") #'winner-undo)
(global-set-key (kbd "C-c w r") #'winner-redo)
(windmove-default-keybindings)   ; Shift-arrow to move between panes

;; destination safety check for treemacs
(with-eval-after-load 'treemacs
  (treemacs-define-RET-action 'file-node-open
    #'treemacs-visit-node-in-most-recently-used-window)
  (treemacs-define-RET-action 'file-node-closed
			      #'treemacs-visit-node-in-most-recently-used-window))

;; ============================================================
;; EasySession
;; ============================================================
(use-package easysession
  :custom
  ; persist file buffers but not window splits
  (easysession-save-window-configs nil)
  (easysession-save-frames nil)
  :config
  (easysession-setup)
  ; auto-load session history on start/connect
  (easysession-load))

;; auto-open layout when in emacsclient
(defun my/auto-apply-client-layout (frame)
  "Applies 4-pane layout automatically when emacsclient frame opens."
  (with-selected-frame frame
    ;; Needs a delay so the terminal frame can render
    (run-with-idle-timer 0.1 nil (lambda ()
				     (my/setup-dev-layout)))))

;; trigger when running daemon mode
(if (daemonp)
    (add-hook 'after-make-frame-functions #'my/auto-apply-client-layout)
  (add-hook 'emacs-startup-hook #'my/setup-dev-layout))

;; ============================================================
;; Treemacs
;; ============================================================
(use-package treemacs
  :defer t
  :config
  (setq treemacs-width                          30
        treemacs-show-hidden-files              t
        treemacs-follow-mode                    t
        treemacs-filewatch-mode                 t
        treemacs-recenter-after-file-follow     nil)
  (treemacs-fringe-indicator-mode 'always)
  :bind ("C-c t" . treemacs-select-window))

(use-package treemacs-nerd-icons
  :after treemacs
  :config (treemacs-load-theme "nerd-icons"))

(use-package treemacs-magit
  :after (treemacs magit))

;; ============================================================
;; Git: magit + git-gutter
;; ============================================================
(use-package magit
  :bind ("C-x g" . magit-status)
  :config
  (setq magit-display-buffer-function
        #'magit-display-buffer-same-window-except-diff-v1))

(use-package git-gutter
  :config (global-git-gutter-mode +1)
  :custom (git-gutter:update-interval 1))

;; ============================================================
;; Minibuffer: vertico + orderless + marginalia + consult
;; ============================================================
(use-package vertico
  :init (vertico-mode)
  :custom
  (vertico-count 15)
  (vertico-cycle t))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file (styles partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :bind (("C-x b"   . consult-buffer)
         ("C-x p b" . consult-project-buffer)
         ("C-s"     . consult-line)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("C-c s"   . consult-ripgrep)
         ("C-c F"   . consult-find)
         ("C-c b"   . consult-bookmark))
  :config
  (setq consult-project-function
	(lambda (&optional _)
	  (when-let ((project (project-current)))
	    (project-root project))))
  (setq consult-preview-key "C-."))

;; ============================================================
;; Completion: company
;; ============================================================
(use-package company
  :hook (prog-mode . company-mode)
  :custom
  (company-idle-delay              0.2)
  (company-minimum-prefix-length  2)
  (company-show-quick-access      t)
  (company-tooltip-align-annotations t)
  (company-dabbrev-downcase       nil)
  (company-dabbrev-ignore-case    nil)
  :bind (:map company-active-map
              ("<tab>" . company-complete-selection)
              ("C-n"   . company-select-next)
              ("C-p"   . company-select-previous)
              ("M-d"   . company-show-doc-buffer)))

;; ============================================================
;; Snippets: yasnippet
;; ============================================================
(use-package yasnippet
  :hook (prog-mode . yas-minor-mode)
  :config (yas-reload-all))

(use-package yasnippet-snippets)

;; ============================================================
;; LSP: eglot (built-in, Emacs 29+)
;; ============================================================
(use-package eglot
  :ensure nil
  :hook ((c-mode   . eglot-ensure)
         (c++-mode . eglot-ensure))
  :config
  (setq eglot-events-buffer-size 0
        eglot-sync-connect       1
        eglot-ignored-server-capabilities
        '(:documentOnTypeFormattingProvider))
  (add-to-list 'eglot-server-programs
               '((c-mode c++-mode)
                 . ("clangd"
                    "--background-index"
                    "--clang-tidy"
                    "--header-insertion=never"
                    "--completion-style=detailed"
                    "--function-arg-placeholders=0"
                    "-j=8"))))

;; ============================================================
;; Diagnostics: flymake
;; ============================================================
(global-set-key (kbd "C-c ! l") #'flymake-show-buffer-diagnostics)
(global-set-key (kbd "C-c ! n") #'flymake-goto-next-error)
(global-set-key (kbd "C-c ! p") #'flymake-goto-prev-error)

;; ============================================================
;; C / C++ settings
;; ============================================================
(add-hook 'c-mode-common-hook
          (lambda ()
            (setq c-basic-offset   2
                  tab-width        2
                  indent-tabs-mode nil)
            (local-set-key (kbd "C-c o") #'ff-find-other-file)))

(setq ff-search-directories
      '("." "../include" "../inc" "../../include"
        "/usr/include" "/usr/local/include"))

;; ============================================================
;; project.el (built-in)
;;
;; cmake-integration-transient referenced at ?m below.
;; It is safe before Phase 1 loads — project.el calls it lazily.
;; ============================================================
(require 'project)
(setq project-switch-commands
      '((project-find-file           "Find file"  ?f)
        (consult-ripgrep             "Ripgrep"    ?s)
        (project-dired               "Dired"      ?d)
        (magit-project-status        "Magit"      ?g)
        (project-eshell              "Eshell"     ?e)
        (cmake-integration-transient "CMake"      ?m)))

;; ============================================================
;; Compilation (fallback for non-CMake builds)
;; ============================================================
(global-set-key (kbd "C-c c")   #'compile)
(global-set-key (kbd "C-c C-c") #'recompile)

(setq compilation-scroll-output 'first-error
      compilation-ask-about-save nil
      compile-command            "make -k ")

(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

;; ============================================================
;; PHASE 1 — Build: cmake-integration                     [ACTIVE]
;;
;; Reads CMakeLists.txt via CMake's File API.  Provides a transient
;; menu for configure / build / run, with optional dape debug launch.
;;
;; FIRST USE:
;;   C-c m m  → open transient menu (start here and explore)
;;   C-c m c  → configure project  (cmake -B build, choose preset)
;;   C-c m t  → pick a target and build
;;   C-c m b  → rebuild last target  ← your daily driver
;;   C-c m r  → run last built executable
;;   C-c m d  → debug last target (active after Phase 3 wiring below)
;;
;; NOTE: The dape launcher is commented out until Phase 3 is active.
;; ============================================================
(use-package cmake-integration
  :vc (:url "https://github.com/darcamo/cmake-integration.git" :rev :newest)
  :after project
  :bind (("C-c m m" . cmake-integration-transient)
         ("C-c m c" . cmake-integration-cmake-reconfigure-current-project)
         ("C-c m b" . cmake-integration-compile-last-target)
         ("C-c m r" . cmake-integration-run-last-target)
         ("C-c m t" . cmake-integration-set-target-and-build)
         ("C-c m d" . cmake-integration-debug-last-target))
  :config
  (setq cmake-integration-program-launcher-function 'comint)

  ;; ── PHASE 3 ── Uncomment this block when dape is enabled.
  ;; It wires C-c m d to launch a dape/codelldb session instead of GDB.
  ;;
  ;; (setq cmake-integration-debug-launcher-function
  ;;       (lambda (exe args)
  ;;         (dape (dape--config-eval-1
  ;;                `(codelldb-cpp
  ;;                  :program ,exe
  ;;                  :args ,(vconcat (split-string-and-unquote args)))))))
  )

;; ============================================================
;; PHASE 1 — Terminal: vterm                              [ACTIVE]
;;
;; Full terminal emulator inside Emacs (requires libvterm C library).
;; Handles htop, game-server stdout, fish shell, etc. correctly.
;;
;; Prerequisite: pacman -S libvterm
;;
;; FIRST USE:
;;   C-c v    → open vterm in a side window
;;   C-c 4 v  → open vterm replacing current window
;;   Inside vterm:
;;     C-c C-t  → toggle copy-mode (scroll and copy output as text)
;; ============================================================
(use-package vterm
  :defer t
  :bind (("C-c v"   . vterm-other-window)
         ("C-c 4 v" . vterm))
  :config
  (setq vterm-max-scrollback     10000
        vterm-kill-buffer-on-exit t
        vterm-shell (or (executable-find "fish")
                        (executable-find "bash")
                        "/bin/sh")))

;; ============================================================
;; Visual extras
;; ============================================================
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package which-key
  :init (which-key-mode)
  :custom (which-key-idle-delay 0.5))

(use-package highlight-symbol
  :hook (prog-mode . highlight-symbol-mode)
  :custom
  (highlight-symbol-idle-delay      0.3)
  (highlight-symbol-on-navigation-p t))

(use-package vundo
  :bind ("C-x u" . vundo))

(electric-pair-mode 1)

;; ============================================================
;; Markdown
;; ============================================================
(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode)
  :custom
  (markdown-command "pandoc --from markdown --to html5 --standalone"))

(use-package grip-mode
  :bind (:map markdown-mode-command-map ("g" . grip-mode)))

;; ============================================================
;; PHASE 2 — Org-mode base                                [ACTIVE]
;;
;; org is built-in — no download occurs.  This configures capture
;; templates, agenda files, and TODO keyword states.
;;
;; BEFORE FIRST USE:
;;   mkdir -p ~/org/multisim
;;   (inbox.org is created automatically on first capture)
;;
;; FIRST USE:
;;   C-c o c  → capture (templates: t=task  n=note  g=game idea  b=bug)
;;   C-c a    → agenda  (keys: a=week  t=all TODOs  q=quit)
;;   In any org file:
;;     M-RET       new heading at same level
;;     C-c C-t     cycle TODO state
;;     C-c C-s     schedule (appears in agenda week view)
;;     C-c C-d     set deadline
;;     TAB         fold / unfold heading
;;     C-c C-q     add / change tags
;;     C-c C-l     insert a hyperlink
;; ============================================================
(use-package org
  :ensure nil
  :hook ((org-mode . visual-line-mode)
         (org-mode . org-indent-mode))
  :custom
  (org-directory             "~/org")
  (org-default-notes-file    (expand-file-name "inbox.org" org-directory))
  (org-hide-emphasis-markers t)
  (org-startup-folded        'content)
  (org-log-done              'time)
  (org-return-follows-link   t)
  ;; Keyword states — must match org-kanban/layout in Phase 4.
  ;; Letters in parens are fast-select keys (C-c C-t then the letter).
  ;; ! = log timestamp on entry; @ = prompt for note on entry.
  (org-todo-keywords
   '((sequence "TODO(t)" "IN-PROGRESS(i!)" "WAITING(w@)" "|"
               "DONE(d!)" "CANCELLED(c@)")))
  (org-agenda-files
   (list org-directory
         (expand-file-name "multisim/" org-directory)))
  :bind (("C-c a"   . org-agenda)
         ("C-c o c" . org-capture)
         ("C-c o l" . org-store-link)
         ("C-c o i" . org-insert-link))
  :config
  (setq org-capture-templates
        '(("t" "Task" entry
           (file+headline org-default-notes-file "Tasks")
           "* TODO %?\n  Captured: %U\n  %a"
           :empty-lines 1)
          ("n" "Note" entry
           (file+headline org-default-notes-file "Notes")
           "* %?\n  Captured: %U"
           :empty-lines 1)
          ("g" "Game design idea" entry
           (file+headline "~/org/multisim/ideas.org" "Ideas")
           "* %?\n  Captured: %U\n\n  %i"
           :empty-lines 1)
          ("b" "Bug to investigate" entry
           (file+headline "~/org/multisim/bugs.org" "Bugs")
           "* TODO %? :bug:\n  File: %F  Line: %(line-number-at-pos)\n  %U"
           :empty-lines 1))))

;; ============================================================
;; PHASE 2 — Org-babel base languages (emacs-lisp + shell)  [ACTIVE]
;;
;; plantuml and mermaid are added separately in Phase 5.
;; ============================================================
(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell      . t)))
  (setq org-confirm-babel-evaluate nil))

;; ============================================================
;; PHASE 3 — Debugger: dape + codelldb             [DISABLED]
;;
;; DAP-based debugger — richer than GDB/GUD, handles multi-threaded
;; programs correctly (critical for Jolt physics + network threads).
;;
;; SETUP (one-time, do before enabling):
;;   wget https://github.com/vadimcn/codelldb/releases/latest/download/codelldb-x86_64-linux.vsix
;;   mkdir -p ~/.emacs.d/debug-adapters
;;   unzip codelldb-x86_64-linux.vsix -d ~/.emacs.d/debug-adapters/codelldb
;;
;; TO ACTIVATE:
;;   1. Remove the `:disabled t` line from this block.
;;   2. Uncomment the cmake-integration dape launcher in Phase 1 above.
;;   3. Restart Emacs (or M-x eval-buffer).
;;
;; FIRST USE:
;;   C-x C-a C-b  → toggle breakpoint on current line
;;   M-x dape     → start session; type `codelldb-cpp', pick your binary
;;   C-c m d      → debug last cmake target (shortcut after wiring above)
;;   Stepping (use repeat-mode — press C-x C-a C-n once, then just n/i/o/c):
;;     C-x C-a C-n  step over
;;     C-x C-a C-i  step into
;;     C-x C-a C-o  step out
;;     C-x C-a C-c  continue
;;     C-x C-a q    quit session
;; ============================================================
(use-package dape
  :disabled t   ; ← PHASE 3: remove this line when ready
  :ensure t
  :defer t
  :config
  (setq dape-buffer-window-arrangement 'right
        dape-step-flymake-markers      t)

  ;; repeat-mode makes stepping ergonomic: after the first C-x C-a C-n,
  ;; you can press n/i/o/c alone to keep stepping.
  (repeat-mode 1)

  (add-to-list 'dape-configs
               `(codelldb-cpp
                 modes (c-mode c++-mode c-ts-mode c++-ts-mode)
                 command ,(expand-file-name
                           "~/.emacs.d/debug-adapters/codelldb/extension/adapter/codelldb")
                 command-args ("--port" :autoport)
                 port :autoport
                 :type    "lldb"
                 :request "launch"
                 :cwd     default-directory
                 :program (lambda ()
                            (read-file-name
                             "Debug binary: "
                             (when (project-current)
                               (project-root (project-current)))
                             nil t)))))

;; ============================================================
;; PHASE 4 — Knowledge Graph: org-roam               [DISABLED]
;;
;; Linked GDD wiki.  Each design concept is a node (.org file) under
;; ~/org/multisim/.  Nodes link bidirectionally.  All plain text, in git.
;;
;; TO ACTIVATE: remove `:disabled t` from org-roam, websocket,
;; org-roam-ui, AND org-kanban blocks in this section.
;;
;; FIRST USE:
;;   C-c n f  → find or create a node  (start: type "combat system")
;;   C-c n c  → capture with template  (d=note  s=system  e=entity  j=journal)
;;   C-c n i  → insert a link to another node (inside a node)
;;   C-c n l  → toggle backlinks panel (what links TO this node?)
;;   C-c w o  → two-pane layout: note + backlinks side by side
;;   C-c n u  → open interactive graph in browser (org-roam-ui)
;; ============================================================
(use-package org-roam
  :disabled t   ; ← PHASE 4: remove this line when ready
  :after org
  :init (setq org-roam-v2-ack t)
  :custom
  (org-roam-directory          (expand-file-name "multisim/" org-directory))
  (org-roam-db-location        (expand-file-name "multisim/.org-roam.db" org-directory))
  (org-roam-completion-everywhere t)
  (org-roam-capture-templates
   '(("d" "Design note" plain "%?"
      :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n#+date: %U\n\n")
      :unnarrowed t)
     ("s" "Game system" plain
      "* Overview\n\n%?\n\n* Implementation Status\n\n- [ ] \n\n* Dependencies\n\n* Related Nodes\n"
      :target (file+head "systems/%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n#+filetags: :system:\n#+date: %U\n\n")
      :unnarrowed t)
     ("e" "Entity / actor" plain
      "* Description\n\n%?\n\n* Components\n\n- \n\n* Behavior\n\n* Visual Reference\n"
      :target (file+head "entities/%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n#+filetags: :entity:\n#+date: %U\n\n")
      :unnarrowed t)
     ("j" "Dev journal" plain
      "* What I worked on\n\n%?\n\n* What I learned\n\n* Blockers\n\n* Tomorrow\n"
      :target (file+head "journal/%<%Y-%m-%d>.org"
                         "#+title: Dev Journal %<%Y-%m-%d>\n#+filetags: :journal:\n\n")
      :unnarrowed t)))
  :bind (("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n l" . org-roam-buffer-toggle)
         ("C-c n c" . org-roam-capture)
         ("C-c n g" . org-roam-graph))
  :config (org-roam-db-autosync-mode))

;; PHASE 4 — dependency of org-roam-ui
(use-package websocket
  :disabled t   ; ← PHASE 4: remove this line when ready
  :after org-roam)

;; PHASE 4 — interactive web graph of your GDD
(use-package org-roam-ui
  :disabled t   ; ← PHASE 4: remove this line when ready
  :after org-roam
  :bind ("C-c n u" . org-roam-ui-open)
  :config
  (setq org-roam-ui-sync-theme    t
        org-roam-ui-follow        t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start  nil))

;; PHASE 4 — visual task board from org TODO keyword states
;;
;; FIRST USE (after enabling):
;;   Open any org file → M-x org-kanban/initialize
;;   In the board: <right>/<left> to advance/rewind a task's state
;;                 RET to jump to that task's heading
;;
;; Column widths must match the org-todo-keywords defined in Phase 2.
(use-package org-kanban
  :disabled t   ; ← PHASE 4: remove this line when ready
  :after org
  :config
  (setq org-kanban/layout
        '(("TODO"        . 30)
          ("IN-PROGRESS" . 30)
          ("WAITING"     . 25)
          ("DONE"        . 25))))

;; ============================================================
;; PHASE 5 — Diagrams: plantuml-mode                  [DISABLED]
;;
;; Major mode for standalone .plantuml/.puml files.
;; Main value is through org-babel (see block below).
;;
;; Prerequisite: pacman -S plantuml
;;
;; TO ACTIVATE:
;;   1. Remove `:disabled t` from this block.
;;   2. Change `nil' to `t' in the org-babel plantuml block below.
;;   3. Remove `:disabled t` from ob-mermaid if you also want Mermaid.
;;   4. Restart Emacs.
;;
;; FIRST USE — paste into any .org file and press C-c C-c on the block:
;;
;;   #+begin_src plantuml :file ecs.png
;;     package "Player" {
;;       [Transform] [Velocity] [Health] [NetworkOwner]
;;     }
;;     package "Enemy" {
;;       [Transform] [NavAgent] [Health] [ServerAuthority]
;;     }
;;   #+end_src
;;
;;   #+begin_src plantuml :file ai-states.png
;;     [*] --> Idle
;;     Idle --> Chase  : player_spotted
;;     Chase --> Attack : in_range
;;     Attack --> Chase : out_of_range
;;     Chase --> Idle   : lost_player
;;   #+end_src
;; ============================================================
(use-package plantuml-mode
  :disabled t   ; ← PHASE 5: remove this line when ready
  :mode ("\\.plantuml\\'" "\\.puml\\'")
  :config
  (setq plantuml-default-exec-mode 'executable
        plantuml-executable-path   "/usr/bin/plantuml"))

;; PHASE 5 — Add plantuml to org-babel
;;
;; This extends the Phase 2 babel config already running above.
;; Change `nil' to `t' when plantuml-mode is enabled (see above).
(with-eval-after-load 'org
  (when nil   ; ← PHASE 5: change `nil' to `t' to activate
    (add-to-list 'org-babel-load-languages '(plantuml . t))
    (org-babel-do-load-languages 'org-babel-load-languages
                                 org-babel-load-languages)
    (setq org-plantuml-exec-mode       'plantuml
          org-plantuml-executable-path "/usr/bin/plantuml")))

;; PHASE 5 — Mermaid diagrams in org-babel
;;
;; Simpler syntax for flowcharts and Gantt charts.
;; Prerequisite: npm install -g @mermaid-js/mermaid-cli  (provides `mmdc')
;;
;; TO ACTIVATE: remove `:disabled t` below.
;;
;; FIRST USE — paste into any .org file and press C-c C-c:
;;
;;   #+begin_src mermaid :file milestones.png
;;     gantt
;;       title Game Dev Milestones
;;       section Engine
;;         Raylib + Jolt     :done,   t1, 2024-01-01, 14d
;;         ENet multiplayer  :active, t2, after t1, 21d
;;         Flecs ECS         :        t3, after t2, 21d
;;       section AI
;;         Recast navmesh    :        t4, after t3, 14d
;;   #+end_src
(use-package ob-mermaid
  :disabled t   ; ← PHASE 5: remove this line when ready
  :after org
  :config
  (setq ob-mermaid-cli-path (or (executable-find "mmdc")
                                "/usr/local/bin/mmdc"))
  (with-eval-after-load 'org
    (add-to-list 'org-babel-load-languages '(mermaid . t))
    (org-babel-do-load-languages 'org-babel-load-languages
                                 org-babel-load-languages)))

;; ============================================================
;; Backup & auto-save
;; ============================================================
(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save-list/" user-emacs-directory) t)))
(setq backup-by-copying    t
      kept-new-versions    8
      kept-old-versions    2
      delete-old-versions  t
      version-control      t)

;;; init.el ends here

;; ============================================================
;; COMPANION: Alacritty font (NOT elisp — add to alacritty.toml)
;;
;; [font]
;; normal = { family = "BlexMono Nerd Font Mono", style = "Regular" }
;; bold   = { family = "BlexMono Nerd Font Mono", style = "Bold" }
;; italic = { family = "BlexMono Nerd Font Mono", style = "Italic" }
;; size   = 12.0
;;
;; ============================================================
;; COMPANION: Per-project .dir-locals.el (place at project root)
;;
;; ((nil . ((cmake-integration-build-dir . "build/debug")
;;          (dape-command . (codelldb-cpp
;;                           :program "/home/you/multisim/build/debug/game-client"
;;                           :args [])))))
;;
;; ============================================================
;; COMPANION: Per-project .clangd (place at project root)
;;
;; CompileFlags:
;;   Add: ["-std=c++17", "-Wall", "-Wextra"]
;;   Compiler: clang++
;; ============================================================
