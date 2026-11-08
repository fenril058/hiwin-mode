;;; hiwin-gui-test.el --- Display regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'hiwin)

(unless (display-graphic-p)
  (error "hiwin-gui-test.el needs a graphical Emacs frame"))

(defun hiwin-gui-test--point-y (window)
  "Return the screen Y coordinate of WINDOW's point after redisplay."
  (redisplay t)
  (let ((position (window-absolute-pixel-position (window-point window) window)))
    (unless position
      (ert-fail (format "No screen coordinates for %S" window)))
    (cdr position)))

(ert-deftest hiwin-gui-empty-buffer-cursor-stays-on-first-line ()
  "EOB virtual lines must not move the cursor of an empty inactive window."
  (let ((buffer (generate-new-buffer " *hiwin-gui-empty*")))
    (unwind-protect
        (save-window-excursion
          (hiwin-mode -1)
          (delete-other-windows)
          (let* ((window-min-width 1)
                 (selected (selected-window))
                 (other (split-window-right))
                 (hiwin-eob-overlay-lines 0)
                 baseline padded)
            (set-window-buffer selected buffer)
            (set-window-buffer other buffer)
            (set-window-point other 1)
            (set-window-start other 1 t)
            (hiwin-mode 1)
            (setq baseline (hiwin-gui-test--point-y other))
            (let ((hiwin-eob-overlay-lines 5))
              (hiwin-draw-ovl)
              (setq padded (hiwin-gui-test--point-y other))
              (message "EOB GUI regression: baseline Y=%S padded Y=%S" baseline padded)
              (should (= baseline padded))
              (should (equal (with-current-buffer buffer (buffer-string)) "")))
            (hiwin-mode -1)))
      (hiwin-mode -1)
      (kill-buffer buffer))))

(provide 'hiwin-gui-test)
;;; hiwin-gui-test.el ends here
