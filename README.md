# hiwin-mode

## Introduction

`hiwin.el` is a minor-mode of Emacs to change background color of
deactive window.

## Screenshot

![hiwin.JPG](image/hiwin.JPG)

## Requirements

- Emacs 23 or higher

## Installation

## Basic Usage
Enable hiwin-mode.
```lisp
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

You can custmize this variable BEFORE enabling `hiwin-mode`. If you
change it while enabling `hiwin-mode`, you have to run
`hiwin-refresh-ignore-buffer-names` to
refresh`hiwin-ignore-buffer-name-regexp`.

#### hiwin-ignore-minibuffer-selected-window

If the value is `non-nil`, the background color of the window selected
just before the minibuffer does not change. The default value is `nil`.
