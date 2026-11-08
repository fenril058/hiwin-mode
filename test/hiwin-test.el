;;; hiwin-test.el --- Tests for hiwin.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'hiwin)

(defmacro hiwin-test-with-windows (&rest body)
  "Run BODY with a clean window layout and restore it afterward."
  (declare (indent 0) (debug t))
  `(let ((window-min-width 1)
          (window-min-height 1))
     (save-window-excursion
       (unwind-protect
           (progn
             (hiwin-mode -1)
             (delete-other-windows)
             ,@body)
         (hiwin-mode -1)))))

(ert-deftest hiwin-test-selection-and-overlay-reuse ()
  (hiwin-test-with-windows
    (with-temp-buffer
      (insert "some test text\n")
      (let* ((first (selected-window))
             (second (split-window-right)))
        (set-window-buffer first (current-buffer))
        (set-window-buffer second (current-buffer))
        (hiwin-mode 1)
        (should (memq #'hiwin-command-hook window-state-change-functions))
        ;; The inactive window has an overlay even with the same buffer.
        (should-not (gethash first hiwin-overlays))
        (let ((overlay (gethash second hiwin-overlays)))
          (should (overlayp overlay))
          (should (eq second (overlay-get overlay 'window)))
          (hiwin-draw-ovl)
          (should (eq overlay (gethash second hiwin-overlays))))
        (select-window second)
        (hiwin-draw-ovl)
        (should-not (gethash second hiwin-overlays))
        (should (overlayp (gethash first hiwin-overlays)))
        (hiwin-mode -1)
        (should (= 0 (hash-table-count hiwin-overlays)))
        (should-not (memq #'hiwin-command-hook
                          window-state-change-functions))))))

(ert-deftest hiwin-test-does-not-move-window-point ()
  (hiwin-test-with-windows
    (with-temp-buffer
      (insert "abc\n")
      (let* ((first (selected-window))
             (second (split-window-right)))
        (set-window-buffer first (current-buffer))
        (set-window-buffer second (current-buffer))
        (set-window-point second (point-max))
        (hiwin-mode 1)
        (hiwin-draw-ovl)
        (should (= (window-point second) (point-max)))))))

(ert-deftest hiwin-test-buffer-change-reuses-overlay ()
  (hiwin-test-with-windows
    (let ((other (generate-new-buffer " *hiwin-test-other*")))
      (unwind-protect
          (with-temp-buffer
            (insert "first buffer")
            (let ((first (selected-window))
                  (second (split-window-right)))
              (set-window-buffer first (current-buffer))
              (set-window-buffer second (current-buffer))
              (hiwin-mode 1)
              (let ((overlay (gethash second hiwin-overlays)))
                (should (overlayp overlay))
                (set-window-buffer second other)
                (hiwin-draw-ovl)
                (should (eq overlay (gethash second hiwin-overlays)))
                (should (eq other (overlay-buffer overlay))))))
        (kill-buffer other)))))

(ert-deftest hiwin-test-excluded-buffer-and-deleted-window ()
  (hiwin-test-with-windows
    (let ((ignored (generate-new-buffer " *hiwin-test-excluded*"))
          (hiwin-ignore-buffer-names '("hiwin-test-excluded")))
      (unwind-protect
          (let ((second (split-window-right)))
            (set-window-buffer second ignored)
            (hiwin-mode 1)
            (should-not (gethash second hiwin-overlays))
            (setq hiwin-ignore-buffer-names nil)
            (hiwin-refresh-ignore-buffer-names)
            (should (overlayp (gethash second hiwin-overlays)))
            (delete-window second)
            (hiwin-draw-ovl)
            (should-not (gethash second hiwin-overlays)))
        (kill-buffer ignored)))))

(ert-deftest hiwin-test-eob-padding-follows-window-height ()
  (hiwin-test-with-windows
    (with-temp-buffer
      (let ((hiwin-eob-overlay-lines nil)
            (other (split-window-right)))
        (set-window-buffer other (current-buffer))
        (hiwin-mode 1)
        (let* ((overlay (gethash other hiwin-overlays))
               (padding (overlay-get overlay 'after-string)))
          (should (overlayp overlay))
          (should (= (length padding) (1+ (window-body-height other))))
          (should (eq (get-text-property 0 'face padding) 'hiwin-face))
          (should (= (window-point other) (point-max)))
          ;; A redundant refresh must not allocate another padding string.
          (hiwin-draw-ovl)
          (should (eq padding (overlay-get overlay 'after-string)))
          ;; Pretend that the window height changed: the padding must follow.
          (cl-letf (((symbol-function 'window-body-height)
                     (lambda (&rest _args) 12)))
            (hiwin-draw-ovl)
            (should (= (length (overlay-get overlay 'after-string)) 13)))
          ;; A zero override disables only the EOB padding, not the overlay.
          (let ((hiwin-eob-overlay-lines 0))
            (hiwin-draw-ovl)
            (should-not (overlay-get overlay 'after-string))
            (should (eq (gethash other hiwin-overlays) overlay)))
          ;; Explicit padding sizes remain compatible with old settings.
          (let ((hiwin-eob-overlay-lines 5))
            (hiwin-draw-ovl)
            (should (= (length (overlay-get overlay 'after-string)) 5)))
          (hiwin-draw-ovl)
          (should (= (length (overlay-get overlay 'after-string))
                     (1+ (window-body-height other)))))))))

(ert-deftest hiwin-test-minibuffer-exclusion-updates-on-customize ()
  (hiwin-test-with-windows
    (with-temp-buffer
      (let* ((original (default-value 'hiwin-ignore-minibuffer-selected-window))
             (first (selected-window))
             (other (split-window-right)))
        (set-window-buffer first (current-buffer))
        (set-window-buffer other (current-buffer))
        (hiwin-mode 1)
        (unwind-protect
            (cl-letf (((symbol-function 'minibuffer-selected-window)
                       (lambda () other)))
              (customize-set-variable 'hiwin-ignore-minibuffer-selected-window nil)
              (should (overlayp (gethash other hiwin-overlays)))
              (customize-set-variable 'hiwin-ignore-minibuffer-selected-window t)
              (should-not (gethash other hiwin-overlays))
              (should-not (gethash first hiwin-overlays))
              (customize-set-variable 'hiwin-ignore-minibuffer-selected-window nil)
              (should (overlayp (gethash other hiwin-overlays))))
          (customize-set-variable 'hiwin-ignore-minibuffer-selected-window
                                  original))))))

(ert-deftest hiwin-test-frame-scoped-update ()
  "A window-state callback refreshes only its reported frame."
  (hiwin-test-with-windows
    (with-temp-buffer
      (insert "frame-specific test\n")
      (let* ((first (selected-window))
             (second (split-window-right))
             (third (split-window-below first))
             (fourth (split-window-below second))
             (frame-a 'hiwin-test-frame-a)
             (frame-b 'hiwin-test-frame-b)
             (hiwin-overlays (make-hash-table :test #'eq))
             (hiwin-mode t)
             (hiwin-eob-overlay-lines 3))
        (dolist (window (list first second third fourth))
          (set-window-buffer window (current-buffer)))
        ;; Model two frames with separate selected and inactive windows.
        ;; Real windows keep the overlay/window operations meaningful in batch.
        (unwind-protect
            (cl-letf (((symbol-function 'frame-list)
                       (lambda () (list frame-a frame-b)))
                      ((symbol-function 'frame-live-p)
                       (lambda (frame) (memq frame (list frame-a frame-b))))
                      ((symbol-function 'window-list)
                       (lambda (&optional frame &rest _args)
                         (if (eq frame frame-a)
                             (list first third)
                           (list second fourth))))
                      ((symbol-function 'window-frame)
                       (lambda (window)
                         (if (memq window (list first third)) frame-a frame-b)))
                      ((symbol-function 'frame-selected-window)
                       (lambda (frame)
                         (if (eq frame frame-a) first second))))
              (hiwin-draw-ovl)
              (should (overlayp (gethash third hiwin-overlays)))
              (should (overlayp (gethash fourth hiwin-overlays)))
              (should-not (gethash first hiwin-overlays))
              (should-not (gethash second hiwin-overlays))
              (let* ((a (gethash third hiwin-overlays))
                     (b (gethash fourth hiwin-overlays))
                     (hiwin-eob-overlay-lines 7))
                (hiwin-command-hook frame-a)
                (should (= (length (overlay-get a 'after-string)) 7))
                (should (= (length (overlay-get b 'after-string)) 3))
                (should (eq a (gethash third hiwin-overlays)))
                (should (eq b (gethash fourth hiwin-overlays)))
                (hiwin-draw-ovl)
                (should (= (length (overlay-get b 'after-string)) 7))))
          (hiwin-delete-ovl))))))

(ert-deftest hiwin-test-theme-face-is-dynamic ()
  "Overlays refer to hiwin-face instead of snapshotting theme colors."
  (hiwin-test-with-windows
    (with-temp-buffer
      (let ((other (split-window-right)))
        (set-window-buffer other (current-buffer))
        (hiwin-mode 1)
        (let ((overlay (gethash other hiwin-overlays)))
          (should (eq (overlay-get overlay 'face) 'hiwin-face))
          (should (eq (get-text-property 0 'face
                                         (overlay-get overlay 'after-string))
                      'hiwin-face)))))))

(provide 'hiwin-test)
;;; hiwin-test.el ends here
