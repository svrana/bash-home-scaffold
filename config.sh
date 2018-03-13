#!/bin/bash

function _set_scaffold_dir() {
    cwd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    export SCAFFOLD_DIR="${cwd}"
}

function scaffold_config_check() {
    if [ -z "$DOTFILES" ]; then
        ebad "\$DOTFILES not set. Point it to your source controlled dotfiles"
        return 1
    fi

    if [ -z "$DOTFILES_BASHRC" ]; then
        # can't be ~/.bashrc b/c it won't be linked on initial setup. Plugins
        # are extracted from .bashrc
        ebad "\$DOTFILES_BASHRC not set. Point it to the full-path of the source controlled version of your .bashrc file"
        return 1
    fi

    if [ -z "$BIN_DIR" ]; then
        ebad "\$BIN_DIR not set. Point it to the location to link (usually in your path). Defaulting to ~/.local/bin"
        export BIN_DIR=${BIN_DIR:~/.local/bin}
    fi

    return 0
}

_set_scaffold_dir
