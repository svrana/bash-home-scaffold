#!/bin/bash
#
# Links configuration files to their correct places.
# Runs installers.
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

_scaffold_deps=(
    helpers.sh
    config.sh
)

for dep in "${_scaffold_deps[@]}" ; do
     # shellcheck source=/dev/null
    . "$CURRENT_DIR/$dep"
done
unset _scaffold_deps

scaffold_config_check || exit 1


if [ -z "$PPA_KEYS" ]; then
    PPA_KEYS=(
    # name (descriptive only)   # keyserver     # key id
    )
fi

if [ -z "$PPA_LIST" ]; then
    PPA_LIST=(
    # name  repository  extras
    )
fi

# A list of installers in $DOTFILES/installers that will be sourced during
# install. These are typically actions that need only be done once and for
# which there might not be a corresponding plugin.
#
# All installers with the same name of a plugin in your DOTFILES_PLUGINS
# are sourced automatically.
if [ -z "$INSTALLERS" ]; then
    INSTALLERS=(
    )
fi

# A list of directories that should be created.
if [ -z "$CREATE_DIRS" ]; then
    CREATE_DIRS=(
    #    $BIN_DIR
    )
fi

if [ -z "$DIR_LINKS" ]; then
    DIR_LINKS=(
        # Target                        Link name
    )
fi

# A list of symbolic links pointing to files that should be created.
if [ -z "$FILE_LINKS" ]; then
    FILE_LINKS=(
        # Target                        Link name
        #"${RCS}/bash_profile         ~/.bash_profile"
        #"${RCS}/bashrc               ~/.bashrc"
    )
fi

if [ -z "$PACKAGE_LIST" ]; then
    PACKAGE_LIST=(
        # name of ubuntu package to install
    )
fi

if [ -z "$GLOBAL_NODE_PACKAGES" ]; then
    GLOBAL_NODE_PACKAGES=(
        # name of ubuntu package to install
    )
fi

if [ -z "$GLOBAL_GEMS" ]; then
    GLOBAL_GEMS=(
        # name of ubuntu package to install
    )
fi

#
# Runs each of the installers specified in the INSTALLERS array.
#
_run_installers() {
    local plugins
    # shellcheck disable=SC2026
    plugins=$(sed -rn '/export DOTFILE_PLUGINS=\(.*/','/\)/'p "$DOTFILES_BASHRC" | \
        sed 's/#.*//' | sed 's/export DOTFILE_PLUGINS=(//' | tr -d ')\n')

    for plugin in $plugins ; do
        local installer="$DOTFILES/installers/$plugin.sh"
        if [ -f "$installer" ]; then
            echo "Configuring $plugin"
            # shellcheck source=/dev/null
            source "$installer"
            estatus

            # source the plugin after its installation so it can be used
            # by subsequent plugins
            local plugin="$DOTFILES/plugins/$plugin.sh"
            if [ -f "$plugin" ]; then
                source "$plugin"
            fi
        fi
    done

    for installer in ${INSTALLERS[*]}; do
        local location="$DOTFILES/installers/${installer}.sh"
        if [ ! -f "$location" ]; then
            echo "Installer $installer missing"
            continue
        fi
        echo "Configuring $installer"
        # shellcheck source=/dev/null
        source "$location"
        estatus

        # source the plugin after its installation so it can be used
        # by subsequent plugins
        local plugin="$DOTFILES/plugins/$installer.sh"
        if [ -f "$plugin" ]; then
            source "$plugin"
        fi
    done
}

#
# Link each script in ./scripts to a directory in your path specified by
# $BIN_DIR.
#
_prep_scripts() {
    local i
    local scripts="$DOTFILES/scripts"
    local -i count=0
    local -i total=0

    for i in ${scripts}/* ; do
        if [ ! -e "$i" ]; then
            chmod +x "$i"
            count=$((count+1))
        fi
        total=$((count+1))
    done
    if [ $count -gt 0 ]; then
        egood "Added execute permission to $count scripts in ${scripts/$HOME\//\~/}"
    fi

    count=0
    total=0

    for i in ${scripts}/* ; do
        [ -e "$i" ] || continue
        local filename=${i##*/}

        if ! link_matches "${BIN_DIR}/$filename" "$i"  ; then
            ln -sf "$i" "${BIN_DIR}/$filename"
            count=$((count+1))
        fi
    done
    if [ $count -gt 0 ]; then
        egood "Created $count links to scripts in ${scripts/$HOME\//\~/} in ${BIN_DIR/$HOME\//\~/}"
    fi
}

#
# Determine if the filename passed in as the first argument is a link that
# is pointing at the second argument.
link_matches() {
    local link=$1
    local target=$2
    if [ -L "$link" ] && [ "$(readlink "$link")" == "$target" ]; then
        return 0
    fi
    return 1
}

#
# Create a symbolic link for each entry speciied in the FILE_LINKS and
# DIR_LINKS arrays.
#
_make_links() {
    local -i count=0
    local -i total=0
    local spec
    for link_spec in "${DIR_LINKS[@]}" ; do
        spec=$(echo "$link_spec" | tr -s ' ')
        local target=${spec%% *}
        local link=${spec#* }
        if [ -d "$target" ]; then
            if ! link_matches "$link" "$target"  ; then
                ln -Tsf "$target" "$link"
                count=$((count+1))
            fi
            total=$((total+1))
        else
            ebad "_make_links: target DIR_LINK ${target} does not exist"
        fi
    done
    if [ $count -gt 0 ]; then
        egood "Created $count of $total directory links"
    fi
    count=0
    total=0

    for link_spec in "${FILE_LINKS[@]}" ; do
        spec=$(echo "$link_spec" | tr -s ' ')
        local target=${spec%% *}
        local link=${spec#* }
        link=${link/#~/$HOME} # expand ~/ to $HOME

        # Check for hostname specific overrides and link those if they exist
        if [ -f "$target.${HOSTNAME}" ]; then
            target="$target.${HOSTNAME}"
        fi
        local len=${#HOME}
        if [ -f "$target" ]; then
            if ! link_matches "$link" "$target"  ; then
                if [ "$HOME" = "${link:0:len}" ]; then
                    ln -sf "$target" "$link"
                else
                    sudo ln -sf "$target" "$link"
                fi
                count=$((count+1))
            fi
            total=$((total+1))
        else
            ebad "_make_links: target FILE_LINK ${target} does not exist"
        fi
    done

    if [ $count -gt 0 ]; then
        egood "Created $count of $total file links"
    fi
    return 0
}

#
# Create each direcctory specified in the CREATE_DIRS array.
#
_make_dirs() {
    local -i count=0
    local -i total=0
    for dir in "${CREATE_DIRS[@]}" ; do
        if [ ! -d "${dir/#~/$HOME}" ]; then
            if ! mkdir -p "${dir/#~/$HOME}" ; then
                ebad "_make_dirs: error creating ${dir/#~/$HOME} directory"
                return 1
            fi
            count=$((count+1))
        fi
        total=$((total+1))
    done

    if [ $count -gt 0 ]; then
        egood "Created $count of $total default directories"
    fi
    return 0
}

# If we're managing this bashrc, then source it to load all the plugins.
_maybe_source_bashrc() {
    for link_spec in "${FILE_LINKS[@]}" ; do
        spec=$(echo "$link_spec" | tr -s ' ')
        link=${spec#* }
        # shellcheck disable=SC2088
        if [ "$link" = "~/.bashrc" ]; then
            echo -e "Sourcing .bashrc"
            # shellcheck disable=SC1090
            . ~/.bashrc
            estatus
        fi
    done
}

_install_packages() {
    for package in "${PACKAGE_LIST[@]}" ; do
        if ! install_package "$package" ; then
            return 1
        fi
    done
}

_install_npm_packages() {
    for package in "${GLOBAL_NODE_PACKAGES[@]}" ; do
        if ! install_npm_package "$package" ; then
            return 1
        fi
    done
}

_install_gems() {
    for gem in "${GLOBAL_GEMS[@]}" ; do
        if ! install_gem "$gem" ; then
            return 1
        fi
    done
}

_install_ppas() {
    local needsUpdate="0"
    for ppa_spec in "${PPA_LIST[@]}" ; do
        ppa_spec=$(echo "$ppa_spec" | tr -s ' ')
        IFS=$'\n' read -d "" -ra ppa <<< "${ppa_spec//' '/$'\n'}"
        # shellcheck disable=SC2068
        if ! add_to_source_list ${ppa[@]} ; then
            needsUpdate="1"
        fi
    done

    if [ "$needsUpdate" == "1" ]; then
        update
    fi
}

_install_ppa_keys() {
    for ppa_key_spec in "${PPA_KEYS[@]}" ; do
        ppa_key_spec=$(echo "$ppa_key_spec" | tr -s ' ')
        IFS=$'\n' read -d "" -ra key_spec <<< "${ppa_key_spec//' '/$'\n'}"
        # shellcheck disable=SC2068
        if ! apt_key_add ${key_spec[@]} ; then
            ebad "Error while adding key ppa key for $key_spec"
            return 1
        fi
    done
}


main() {
    while getopts f opt
    do
        case "$opt" in
        esac
    done
    shift "$((OPTIND-1))"

    if ! _install_ppa_keys ; then
         ebad "error installing ppa keys, premature exit"
         return 1
    fi

    if ! _install_ppas ; then
         ebad "error installing ppas, premature exit"
         return 1
    fi

    if ! _install_packages; then
        ebad "error installing packages, premature exit"
        return 1
    fi

    if ! _install_npm_packages; then
        ebad "error installing global npm packages, premature exit"
        return 1
    fi

    if ! _install_gems ; then
        ebad "error installing gems, premature exit"
        return 1
    fi

    if ! _make_dirs ; then
        ebad "error creating directories, premature exit"
        return 1
    fi

    if ! _make_links; then
        ebad "error creating links, premature exit"
        return 1
    fi

    _prep_scripts
    _run_installers
    _maybe_source_bashrc

    return 0
}
main

unset CURRENT_DIR
unset _scaffold_deps
