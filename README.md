# hiwin-mode

## Introduction

`hiwin.el` is a minor-mode of Emacs to change the background color of
the deactive window.

## Screenshot

![hiwin.JPG](image/hiwin.JPG)

## Requirements

- Emacs 27 or higher

## Installation & sample setting

With `use-package.el` and [vc-use-package.el](https://github.com/slotThe/vc-use-package)
```emacs-lisp
(use-package hiwin-mode
  :vc
  (:fetcher github :repo fenril058/hiwin-mode)
  :config
  (hiwin-mode 1))
```

With [leaf.el](https://github.com/conao3/leaf.el):
```emacs-lisp
(leaf hiwin-mode
  :vc
  (:url "https://github.com/fenril058/hiwin-mode" :branch "main")
  :custom-face
  (hiwin-face . '((((class color) (background light))
                   (:background "gray90"))))
  :global-minor-mode t)
```


## Basic Usage

Enable hiwin-mode.
```emacs-lisp
(hiwin-mode 1)
```

## Customization

#### hiwin-face

Face for deactive windows. For example;
```
(set-face-background 'hiwin-face "gray80")
```

#### hiwin-ignore-buffer-names

List of the buffer names which do not change background color when
they are in a deactive window.

Changing this option through Customize updates the display immediately.
If you change it with `setq` while `hiwin-mode` is enabled, run
`M-x hiwin-refresh-ignore-buffer-names` to rebuild the exclusion regexp.

#### hiwin-eob-overlay-lines

How many virtual, face-colored blank lines to draw past the end of a
buffer in an inactive window. By default, `nil` adapts to each window's
height rather than inserting 96 newlines into the display. Set to `0`
to disable the extra lines, or an integer to force a specific count.

The padding is implemented with an overlay's `after-string`, so it
can still affect display near the end of a buffer. It does not modify
the underlying buffer text.

#### hiwin-ignore-minibuffer-selected-window

When non-nil, the window selected immediately before entering the minibuffer
is not dimmed. The default is `nil`. Changes made through Customize take
effect immediately.

## Similar packages

- [auto-dim-other-buffers.el](https://github.com/mina86/auto-dim-other-buffers.el)
- [dimmer.el](https://github.com/gonewest818/dimmer.el)
