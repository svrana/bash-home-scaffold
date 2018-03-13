#!/bin/bash
#
# Links configuration files to their correct places.
# Runs installers.
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

_scaffold_deps=(
    helpers.sh    # used for helper functions
    config.sh
)

# Must have directories set so applications no where to be installed
for dep in "${_scaffold_deps[@]}" ; do
    . "$CURRENT_DIR/$dep"
done

scaffold_config_check || exit 1

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

#
# Runs each of the installers specified in the INSTALLERS array.
#
function _run_installers() {
    local plugins
    plugins=$(sed -rn '/export DOTFILE_PLUGINS=\(.*/','/\)/'p "$DOTFILES_BASHRC" | \
        sed 's/#.*//' | sed 's/export DOTFILE_PLUGINS=(//' | tr -d ')\n')

    for plugin in $plugins ; do
        local installer="$DOTFILES/installers/$plugin.sh"
        if [ -f "$installer" ]; then
            echo -n "Configuring $plugin"
            source "$installer"
            estatus
        fi
    done

    for installer in ${INSTALLERS[*]}; do
        local location="$DOTFILES/installers/${installer}.sh"
        if [ ! -f "$location" ]; then
            echo "Installer $installer missing"
            return 1
        fi
        echo -n "Configuring $installer"
        source "$location"
        estatus
    done
}

#
# Link each script in ./scripts to a directory in your path specified by
# $BIN_DIR.
#
function _prep_scripts() {
    local i
    local scripts="$DOTFILES/scripts"
    local -i count=0

    for i in $(dolisting "$scripts"/*) ; do
        chmod +x "$i"
        count=$((count+1))
    done
    egood "Added execute permission to $count scripts in ${scripts/$HOME\//\~/}"
    count=0

    for i in $(dolisting "$scripts/*") ; do
        i=$(basename "$i")
        ln -sf "${scripts}/$i" "${BIN_DIR}/$i"
        count=$((count+1))
    done
    egood "Created $count links to scripts in ${scripts/$HOME\//\~/} in ${BIN_DIR/$HOME\//\~/}"
}

#
# Run chef solo. For system-wide changes, like packages.
#
function _chef_bootstrap() {
    local force=${1:-"false"}
    local first_run
    first_run=$(which chef-solo)

    if [ -z "$first_run" ]; then
        local TEMPDIR
        TEMPDIR=$(mktemp -d)
        curl -L https://omnitruck.chef.io/install.sh -o "$TEMPDIR/install.sh"
        sudo bash /tmp/install.sh -P chefdk
        estatus "Installed chefdk"
        rm -rf "$TEMPDIR"
        cp -r "$CURRENT_DIR/chef" "$DOTFILES"
        mkdir -p "$DOTFILES/scripts"
        cp chef-up "$DOTFILES/scripts"
    fi

    if [[ -z "$first_run" || "$force" = "true" ]]; then
        if ! command chef-up 2>/dev/null ; then
            "$CURRENT_DIR/chef-up"
        else
            chef-up
        fi
        estatus "Ran chef-solo"
    else
        egood "Skipped chef-solo run (use -f to force)"
    fi
}

#
# Create a symbolic link for each entry speciied in the FILE_LINKS and
# DIR_LINKS arrays.
#
function _make_links() {
    local -i count=0
    local spec
    for link_spec in "${DIR_LINKS[@]}" ; do
        spec=$(echo "$link_spec" | tr -s ' ')
        local target=${spec%% *}
        local link=${spec#* }
        ln -Tsf "$target" "$link"
        count=$((count+1))
    done
    egood "Created $count directory links"
    count=0

    for link_spec in "${FILE_LINKS[@]}" ; do
        spec=$(echo "$link_spec" | tr -s ' ')
        local target=${spec%% *}
        local link=${spec#* }
        link=${link/#~/$HOME} # expand ~/ to $HOME
        local len=${#HOME}
        if [ "$HOME" = "${link:0:len}" ]; then
            ln -sf "$target" "$link"
        else
            sudo ln -sf "$target" "$link"
        fi
        count=$((count+1))
    done

    egood "Created $count file links"
}

#
# Create each direcctory specified in the CREATE_DIRS array.
#
function _make_dirs() {
    local -i count=0
    for dir in "${CREATE_DIRS[@]}" ; do
        mkdir -p "${dir/#~/$HOME}"
        count=$((count+1))
    done

    egood "Created $count default directories"
}

# If we're managing this bashrc, then source it to load all the plugins.
function _maybe_source_bashrc() {
    for link_spec in "${FILE_LINKS[@]}" ; do
        spec=$(echo "$link_spec" | tr -s ' ')
        link=${spec#* }
        # shellcheck disable=SC2088
        if [ "$link" = "~/.bashrc" ]; then
            echo -e "Sourcing .bashrc"
            . ~/.bashrc
            estatus
        fi
    done
}

force_chef_run="false"
while getopts f opt
do
    case "$opt" in
        f)  force_chef_run="true";;
        \?)   # unknown flag
            echo >&2 \
                "usage: $0 [-f force chef-solo run ]"
            exit 1;;
    esac
done
shift "$((OPTIND-1))"

_chef_bootstrap "$force_chef_run"
_make_dirs
_make_links
_prep_scripts
_run_installers
_maybe_source_bashrc
