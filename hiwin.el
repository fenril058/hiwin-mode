;;; hiwin.el --- Visible active window mode. -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2009 k.sugita
;;               2010 tomoya <tomoya.ton@gmail.com>
;;               2011 k.sugita <ksugita0510@gmail.com>
;;               2016 ril
;;
;; Author: k.sugita
;; Keywords: faces, editing, emulating
;; Version: 2.3.2
;; URL: https://github.com/fenril058/hiwin-mode
;; Package-Requires: ((emacs "27.1"))
;;
;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Usage
;;
;; put followings your .emacs
;;   (require 'hiwin)
;;   (hiwin-activate)
;;   (set-face-background 'hiwin-face "gray80")
;;
;; if you want to ignore the *eshell* buffer,
;; put followings:
;;   (add-to-list 'hiwin-ignore-buffer-names "*eshell*")
;;
;; if you invisible active window, type M-x hiwin-deactivate.

;;; Changes
;;
;; 2026-11-08
;; - Refresh only the affected frame from window-state-change-functions.
;; - Redraw after customizing minibuffer-selected-window exclusion.
;; - Cover frame-scoped refresh and minibuffer exclusion with ERT.
;;
;; 2026-11-08
;; - Size the EOB padding to the window height instead of a fixed 96 lines.
;; - Allow explicit EOB padding line counts, including zero, via Customize.
;;
;; 2026-11-06
;; - Track overlays by window and reuse them when possible.
;; - Use window-state-change-functions for per-frame updates.
;; - Avoid selecting inactive windows or changing their point.
;; - Fix customization type and refresh exclusion settings.
;;
;; 204-09-26
;; - Hook先を`window-configuration-change-hook'から
;;   `window-state-change-hook'に変更した。
;; - Versionを2.2.1に変更した。
;;
;; 2022-06-29
;; - 下記の変更によりversionを2.2.0に変更した.
;;
;; 2022-06-28 ril
;; - `select-window'のNORECORD optionをtにして記録されないようにした.
;; - ミニバッファ直前のウィンドウを除外するかどうか選べるようにした.
;;   `hiwin-ignore-minibuffer-selected-window'がnon-nilのとき除外.
;;   デフォルトはnilで除外しない.
;; - `post-command-hook'ではなく`window-configuration-change-hook'
;;   にhookするようにした.  これで十分.
;;
;; 2022-06-27 ril
;; - Emacs 27以上の対応として `hiwin-face'に :extend t を追加.
;; - DocumationとCommnetをわかりやすいように変更.
;; - Versionを2.1.0に変更し, `hiwin-version'を追加.
;;
;; 2016-02-07 ril
;; - 変数名や関数名をいろいろと変更.
;; - ポイントがバッファの最後にある場合の対策
;; - 描画対象外バッファの設定を実装.
;;   `hiwin-ignore-buffer-names'から生成された正規表現
;;   `hiwin-ignore-buffer-name-regexp'にマッチするか否かで判定する.
;;
;; 2011-12-23 k.sugita
;; tails-marks.elを参考に以下の実装を見直し，修正
;; - ウィンドウ分割したとき，あるいはウィンドウ移動したとき
;;   オーバーレイを再作成するように修正
;; - 読み込み専用バッファの背景色を変更する処理を削除
;; - 非アクティブウィンドウの配色をフェイスで設定
;; - 描画対象外バッファの設定は未実装
;;
;; 2010-08-13 k.sugita
;; *Completions*表示時にMiniBufの表示が崩れるのを修正
;; 手動で画面リフレッシュできるようhiwin-refresh-winをinteractive化
;; 個人的な設定だったため，recenterのadviceを削除
;;
;; 2010-07-04 k.sugita
;; ローカルで再スクラッチしたファイルに tomoya氏，masutaka氏の修正を反映
;; readonlyなアクティブwindowの背景色を設定できるように機能変更
;;
;; 2010-06-07 tomoya
;; マイナーモード化
;;
;; 2009-09-13 k.sugita
;; ブログで公開
;; http://ksugita.blog62.fc2.com/blog-entry-8.html

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Code:

(defgroup hiwin nil
  "Visible active window mode."
  :group 'emacs)

(defconst hiwin-version "2.3.2"
  "Version number of hiwin-mode.")

(defcustom hiwin-mode-lighter " hiwin"
  "Lighter of hiwin-mode."
  :type 'string
  :group 'hiwin)

(defcustom hiwin-ignore-minibuffer-selected-window nil
  "If non-nil, do not dim the window selected before the minibuffer."
  :type 'boolean
  :set (lambda (symbol value)
         (set-default symbol value)
         (when (bound-and-true-p hiwin-mode)
           (hiwin-draw-ovl)))
  :group 'hiwin)

(defcustom hiwin-ignore-buffer-names '("+draft/" "*helm")
  "ハイライト対象外にするバッファ名のリスト.
バッファ名にこのリストの文字列が含まれるとき,
非アクティブウィンドウに表示されていても背景色を変えない."
  :type '(repeat string)
  :set (lambda (symbol value)
         (set-default symbol value)
         (when (bound-and-true-p hiwin-mode)
           (hiwin-refresh-ignore-buffer-names)))
  :group 'hiwin)

(defvar hiwin-ignore-buffer-name-regexp nil
  "ハイライト対象外のバッファ名の正規表現.
`hiwin-refresh-ignore-buffer-names'によって,
`hiwin-ignore-buffer-names'から生成される.")

(defface hiwin-face
  `((t ,@(and (>= emacs-major-version 27) '(:extend t))
       :background "gray25"))
  "非アクティブウィンドウのオーバーレイ描画用のフェイス.
Face for inactive window.")

(defcustom hiwin-eob-overlay-lines nil
  "Number of colored virtual lines displayed after the end of a buffer.
When nil, use one more line than the height of each inactive window.
This adapts the padding to window resizes instead of always displaying
a fixed number of newlines.

An integer specifies a fixed number of lines.  Set it to zero to
disable EOB padding.  For buffers using unusually small or variable
line heights, a larger fixed value may be useful."
  :type '(choice (const :tag "Fit to window height" nil)
                 (integer :tag "Fixed line count"))
  :set (lambda (symbol value)
         (set-default symbol value)
         (when (bound-and-true-p hiwin-mode)
           (hiwin-draw-ovl)))
  :group 'hiwin)

(defun hiwin--eob-line-count (window)
  "Return the number of virtual EOB lines required for WINDOW."
  (if (null hiwin-eob-overlay-lines)
      (1+ (window-body-height window))
    (max 0 hiwin-eob-overlay-lines)))

(defvar hiwin-overlays (make-hash-table :test #'eq)
  "Hash table mapping inactive windows to their overlays.")

(defun hiwin-delete-ovl ()
  "Delete every overlay managed by hiwin."
  (maphash (lambda (_window overlay)
             (delete-overlay overlay))
           hiwin-overlays)
  (clrhash hiwin-overlays))

(defun hiwin--ignored-window-p (window)
  "Return non-nil if WINDOW should not be dimmed."
  (or (window-minibuffer-p window)
      (and hiwin-ignore-minibuffer-selected-window
           (eq window (minibuffer-selected-window)))
      (and hiwin-ignore-buffer-name-regexp
           (string-match-p hiwin-ignore-buffer-name-regexp
                           (buffer-name (window-buffer window))))))

(defun hiwin--remove-window-overlay (window)
  "Remove the overlay belonging to WINDOW, if any."
  (let ((overlay (gethash window hiwin-overlays)))
    (when overlay
      (delete-overlay overlay)
      (remhash window hiwin-overlays))))

(defun hiwin--update-window (window)
  "Ensure WINDOW has an overlay exactly when it should be dimmed.
Do not select WINDOW or change its point."
  (if (or (not (window-live-p window))
          (eq window (frame-selected-window (window-frame window)))
          (hiwin--ignored-window-p window))
      (hiwin--remove-window-overlay window)
    (let* ((buffer (window-buffer window))
           (overlay (gethash window hiwin-overlays)))
      (with-current-buffer buffer
        (save-restriction
          (widen)
          (if overlay
              (unless (and (eq (overlay-buffer overlay) buffer)
                           (= (overlay-start overlay) (point-min))
                           (= (overlay-end overlay) (point-max)))
                (move-overlay overlay (point-min) (point-max) buffer))
            (setq overlay (make-overlay (point-min) (point-max)
                                        buffer nil t))
            (overlay-put overlay 'face 'hiwin-face)
            (overlay-put overlay 'window window)
            (overlay-put overlay 'priority 0)
            (puthash window overlay hiwin-overlays))
          ;; EOB has no real buffer text to cover.  Keep virtual lines,
          ;; but use only as many as WINDOW can display.
          (let ((lines (hiwin--eob-line-count window)))
            (unless (equal (overlay-get overlay 'hiwin-eob-lines) lines)
              (overlay-put overlay 'hiwin-eob-lines lines)
              (overlay-put overlay 'after-string
                           (when (> lines 0)
                             (propertize (make-string lines ?\n)
                                         'face 'hiwin-face))))))))))

(defun hiwin--refresh-frame (frame)
  "Refresh inactive overlays in the live FRAME."
  (when (frame-live-p frame)
    (dolist (window (window-list frame))
      (hiwin--update-window window))))

(defun hiwin--cleanup-stale-overlays ()
  "Discard overlays for deleted windows and frames."
  (let (stale-windows)
    (maphash (lambda (window _overlay)
               (unless (window-live-p window)
                 (push window stale-windows)))
             hiwin-overlays)
    (dolist (window stale-windows)
      (hiwin--remove-window-overlay window))))

(defun hiwin-draw-ovl ()
  "Refresh all inactive window overlays without recreating unchanged ones."
  (interactive)
  (dolist (frame (frame-list))
    (hiwin--refresh-frame frame))
  (hiwin--cleanup-stale-overlays))

(defun hiwin-create-ovl ()
  "Ensure inactive window overlays exist.
This function is retained for compatibility with older configurations."
  (hiwin-draw-ovl))

(defun hiwin-command-hook (&optional frame)
  "Refresh overlays after a state change on FRAME.
Called with FRAME by `window-state-change-functions'.  Without FRAME,
refresh all frames for compatibility with manual invocations."
  (when hiwin-mode
    (if frame
        (progn
          (hiwin--refresh-frame frame)
          (hiwin--cleanup-stale-overlays))
      (hiwin-draw-ovl))))

;;;###autoload
(defun hiwin-refresh-ignore-buffer-names ()
  "Update the regexp of buffer names excluded from dimming."
  (interactive)
  (setq hiwin-ignore-buffer-name-regexp
        (when hiwin-ignore-buffer-names
          (regexp-opt hiwin-ignore-buffer-names)))
  (when (bound-and-true-p hiwin-mode)
    (hiwin-draw-ovl)))

;;;###autoload
(define-minor-mode hiwin-mode
  "Highlight the active window by dimming the other windows."
  :global t
  :lighter hiwin-mode-lighter
  :group 'hiwin
  (if hiwin-mode
      (progn
        (hiwin-refresh-ignore-buffer-names)
        (add-hook 'window-state-change-functions #'hiwin-command-hook)
        (hiwin-draw-ovl))
    (remove-hook 'window-state-change-functions #'hiwin-command-hook)
    (hiwin-delete-ovl)))

;;;###autoload
(defun hiwin-activate ()
  "Turn on visible active window mode."
  (interactive)
  (hiwin-mode 1))

;;;###autoload
(defun hiwin-deactivate ()
  "Turn off visible active window mode."
  (interactive)
  (hiwin-mode -1))

;;;###autoload
(defun hiwin-version ()
  "Print `hiwin-version'."
  (interactive)
  (message "hiwin mode version %s" hiwin-version))

(provide 'hiwin)

;; Local Variables:
;; mode: emacs-lisp
;; coding: utf-8
;; End:

;;; hiwin.el ends here
