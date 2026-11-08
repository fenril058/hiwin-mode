;;; hiwin-test.el --- Tests for hiwin.el -*- lexical-binding: t; -*-

(require 'ert)
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

(provide 'hiwin-test)
;;; hiwin-test.el ends here
