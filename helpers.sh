#!/bin/bash
#
# Many of these from gentoo @
#   https://github.com/gentoo/gentoo-functions/blob/master/functions.sh
#

_load_deps() {
    local CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$CURRENT_DIR/colors.sh"
}
_load_deps

# void ebox(void)
# 	indicates a failure in a "box"
ebox() {
    set_cols
    echo -e "${ENDCOL} ${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL}"
}

# void sbox(void)
# 	indicates a success in a "box"
sbox() {
    set_cols
    echo -e "${ENDCOL} ${BRACKET}[ ${GOOD}ok${BRACKET} ]${NORMAL}"
}

egood() {
    if [ "$*" ]; then
        echo "$*"
    fi
    sbox
}

ebad() {
    if [ "$*" ]; then
        echo "$*"
    fi
    ebox
}

estatus() {
    if [ $? -eq 0 ]; then
        egood "$*"
    else
        ebad "$*"
    fi
}

# Usage: split "string" "delimiter"
split() {
   IFS=$'\n' read -d "" -ra arr <<< "${1//$2/$'\n'}"
   printf '%s\n' "${arr[@]}"
}

PATH_append() {
    [ -z "$1" ] && return

    paths=$(split "$1" ":")
    for path in $paths ; do
        if [ "${PATH#*${path}}" = "${PATH}" ]; then
            export PATH=$PATH:$path
        fi
    done
}

PATH_prepend() {
    [ -z "$1" ] && return

    local paths
    paths=$(split "$1" ":")
    for path in $paths ; do
        if [ "${PATH#*${path}}" = "${PATH}" ]; then
            export PATH=$path:$PATH
        fi
    done
}

download() {
    local url="$1"
    local output="$2"

    if command -v "curl" &> /dev/null; then
        curl -LsSo "$output" "$url" &> /dev/null
        #     │││└─ write output to file
        #     ││└─ show error messages
        #     │└─ don't show the progress meter
        #     └─ follow redirects
        return $?

    elif command -v "wget" &> /dev/null; then
        wget -qO "$output" "$url" &> /dev/null
        #     │└─ write output to file
        #     └─ don't show output
        return $?
    fi

    return 1
}

kill_all_subprocesses() {
    local i=""

    for i in $(jobs -p); do
        kill "$i"
        wait "$i" &> /dev/null
    done
}

execute() {
    local -r CMDS="$1"
    local -r MSG="${2:-$1}"
    local -r TMP_FILE="$(mktemp /tmp/XXXXX)"

    local exitCode=0
    local cmdsPID=""

    # If the current process is ended,
    # also end all its subprocesses.
    set_trap "EXIT" "kill_all_subprocesses"

    # Execute commands in background
    eval "$CMDS" &> /dev/null 2> "$TMP_FILE" &
    cmdsPID=$!

    echo "$MSG"

    # Show a spinner if the commands require more time to complete.
    show_spinner "$cmdsPID" "$CMDS" "$MSG"

    # Wait for the commands to no longer be executing
    # in the background, and then get their exit code.
    wait "$cmdsPID" &> /dev/null
    exitCode=$?

    # Print output based on what happened.
    estatus

    if [ $exitCode -ne 0 ]; then
        print_error_stream < "$TMP_FILE"
    fi

    rm -rf "$TMP_FILE"

    return $exitCode
}

show_spinner() {
    local -r FRAMES='/-\|'

    # shellcheck disable=SC2034
    local -r NUMBER_OR_FRAMES=${#FRAMES}

    local -r CMDS="$2"
    local -r MSG="$3"
    local -r PID="$1"

    local i=0
    local frameText=""

    # Note: In order for the Travis CI site to display
    # things correctly, it needs special treatment, hence,
    ## the "is Travis CI?" checks.
    if [ "$TRAVIS" ]; then
        # Provide more space so that the text hopefully
        # doesn't reach the bottom line of the terminal window.
        #
        # This is a workaround for escape sequences not tracking
        # the buffer position (accounting for scrolling).
        #
        # See also: https://unix.stackexchange.com/a/278888
        printf "\n\n\n"
        tput cuu 3

        tput sc
    fi

    # Display spinner while the commands are being executed.
    while kill -0 "$PID" &>/dev/null; do
        if [ "$TRAVIS" ]; then
            frameText="[ ${FRAMES:i++%NUMBER_OR_FRAMES:1} ] "
            printf "%s" "$frameText"
        else
            frameText="${ENDCOL} ${BRACKET}[ ${NORMAL}${FRAMES:i++%NUMBER_OR_FRAMES:1} ${BRACKET}] "
            echo -e "$frameText"
        fi

        sleep 0.2

        # Clear frame text.
        if [ "$TRAVIS" ]; then
            tput rc
        else
            printf "\r"
        fi
    done
}

print_error() {
    print_in_red "   [✖] $1 $2\n"
}

print_error_stream() {
    while read -r line; do
        print_error "↳ ERROR: $line"
    done
}

print_in_color() {
    printf "%b" \
        "$(tput setaf "$2" 2> /dev/null)" \
        "$1" \
        "$(tput sgr0 2> /dev/null)"
}

set_trap() {
    trap -p "$1" | grep "$2" &> /dev/null || trap '$2' "$1"
}

add_key() {
    wget -qO - "$1" | sudo apt-key add - &> /dev/null
    #     │└─ write output to file
    #     └─ don't show output
}

add_to_source_list() {
    file="/etc/apt/sources.list.d/$1"
    line="deb $2"

    if [ -z "$file" ]; then
        ebad "Must specify a name for the source to add"
        return 1
    fi
    if [ -z "$2" ]; then
        ebad "Must specify a source url for the ppa"
        return 1
    fi

    if [ -f "file" ]; then
        if grep -qE "^$line$" "$file" ; then
            # file exists with the same content we want to add
            egood "$1 exists in $file"
            return 0
        fi
        # file exists but doesn't have the source we want
        sudo rm "$file"
    fi
    sudo sh -c "printf 'deb $2' >> '/etc/apt/sources.list.d/$1'"
    estatus "Added $1 to $file"
}

autoremove() {
    # Remove packages that were automatically installed to satisfy
    # dependencies for other packages and are no longer needed.
    execute "sudo apt-get autoremove -qqy" \
        "APT (autoremove)"
}

package_is_installed() {
    dpkg -s "$1" &> /dev/null
}

install_package() {
    declare -r EXTRA_ARGUMENTS="$2"
    declare -r PACKAGE="$1"

    if ! package_is_installed "$PACKAGE"; then
        execute "sudo apt-get install --allow-unauthenticated -qqy $EXTRA_ARGUMENTS $PACKAGE" "Installing $PACKAGE"
        #execute "sleep 5" "$PACKAGE"
        #                                      suppress output ─┘│
        #            assume "yes" as the answer to all prompts ──┘
        #egood "Already installed $PACKAGE"
    else
        egood "Installed $PACKAGE"
    fi
}
