#!/bin/bash
#
# Load dotfile dependencies, functions, environment variables and user
# specified plugins in $DOTFILES_PLUGINS.
#

#
# Source dependencies required for all plugins.
#
function dotfiles_load_deps() {
    CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$CURRENT_DIR/directories.sh"
    source "$CURRENT_DIR/functions.sh"

    PATH_append "$BIN_DIR"
}

#
# Source machine specific configuration if available.
#
function dotfiles_load_box_config() {
    overrides="$DOTFILES/boxen/$HOSTNAME.env"
    if [ -e "$overrides" ]; then
        . "$overrides"
    fi
}

#
# Source private configs that cannot be added to the public repo.
#
function dotfiles_load_private_config() {
    for file in $(dolisting "$DOTFILES"/private/*.env) ; do
        . "$file"
    done
}

#
# Loads the specified plugin or shows information about it.
#
#   --quiet : silence output related to loading plugin
#   --path  : print the plugin path only (do not load plugin)
#
function dotfiles_plugin() {
    local path_request=false
    local quiet=false

    while [ $# -gt 1 ] ; do
        if [ "$1" == "--path" ]; then
            path_request=true
            shift
        elif [ "$1" == "--quiet" ]; then
            quiet=true
            shift
        fi
    done

    local name="$1"
    if [ -z "$name" ]; then
        echo "Missing plugin name"
        return 1
    fi

    local location="$DOTFILES/plugins/${name}.sh"
    if [ ! -f "$location" ]; then
        echo "Plugin $name is missing"
        return 1
    fi

    if [ "$path_request" = true ]; then
        echo "$location"
    else
        if [ "$quiet" = false ]; then
            echo -n "Activating plugin $name"
        fi
        source "$location"
        if [ "$quiet" = false ]; then
            estatus
        fi
    fi
}

#
# Load user specified plugins.
#
function dotfiles_load_plugins() {
    [ -z "$DOTFILE_PLUGINS" ] && return

    local plugin
    for plugin in ${DOTFILE_PLUGINS[*]} ; do
        dotfiles_plugin --quiet "$plugin"
    done
}

dotfiles_load_deps
dotfiles_load_box_config
dotfiles_load_private_config
dotfiles_load_plugins
