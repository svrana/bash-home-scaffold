#!/bin/bash

# This file exists so that it can be sourced from install, where sourcing the
# .bashrc or load.sh is not appropriate b/c the dotfiles have not been
# installed yet. These must be set prior to install so that applications can be
# placed in the right place.

export TMP=/tmp
export CLOUD_ROOT=~/Cloud
export PHOTOS=~/Pictures
export BIN_DIR=~/.local/bin
export DOCUMENTS=~/Documents
export DOWNLOADS=~/Downloads
export MUSIC=~/Music
export PROJECTS=~/Projects
export APPS=~/Apps


cwd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export DOTFILES="${cwd}"
export RCS="${DOTFILES}/rcs"

unset cwd