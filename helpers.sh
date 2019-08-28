#!/bin/bash
#
# Many of these from gentoo @
#   https://github.com/gentoo/gentoo-functions/blob/master/functions.sh
#


if [ -z "$use_color" ]; then
    if tty -s ; then
        use_color=true
        export RED='\e[38;5;198m'
        export green='\e[38;5;82m'
        export GOOD=$green
        export BAD=$RED
        export NORMAL='\E[0m'
        export BRACKET='\E[34;01m'
    else
        use_color=false
        export RED=
        export green=
        export GOOD=
        export BAD=
        export NORMAL=
        export BRACKET=
    fi
fi

set_cols() {
    # Setup COLS and ENDCOL so eend can line up the [ ok ]
    COLS="${COLUMNS:-0}"            # bash's internal COLUMNS variable
    [ "$COLS" -eq 0 ] && COLS=$(tput cols)

    if [ $use_color ]; then
        ENDCOL='\033[A\033['$(( COLS - 7 ))'C'
    else
        ENDCOL=''
    fi
    export ENDCOL
    export COL
}

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

trim_string() {
    # Usage: trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
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
        print_error "execute: $CMDS"
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
    echo -e "$ ${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL} $1 $2"
}

print_error_stream() {
    while read -r line; do
        print_error "↳ ERROR: $line"
    done
}

set_trap() {
    trap -p "$1" | grep "$2" &> /dev/null || trap '$2' "$1"
}

apt_key_installed() {
    local -r first=${keyid:0:4}
    local -r second=${keyid:4}

    if apt-key fingerprint 2>/dev/null | grep -q "$first $second"; then
        return 0
    fi
    return 1
}

apt_key_add() {
    local name=$1
    local keyserver=$2
    local keyid=$3

    if [ -z "$name" ]; then
        ebad "apt_key_add: must specifiy a key name for descriptive purposes ($*)"
        return 1
    fi
    if [ -z "$keyserver" ]; then
        ebad "apt_key_add: must specify a keyserver from which to download key for $name"
        return 1
    fi
    if [ -z "$keyid" ]; then
        ebad "apt_key_add: Must specify a keyid for $name key. Last 8 chars of the key, concatenated"
        return 1
    fi

    if ! apt_key_installed "$keyid" ; then
        keyid=$(echo "$keyid" | tr -d ' ')
        execute 'sudo apt-key adv --keyserver "$keyserver" --recv-keys "$keyid"' \
            "Adding $name ppa key"
        #estatus "Added gpg key from keyserver $keyserver for $name"
    else
       egood "Already installed gpg key for $name from $keyserver"
    fi
    return 0
}

add_to_source_list() {
    local -r name="$1"
    shift
    local -r file="/etc/apt/sources.list.d/$name.list"
    local line="deb \"$1\"" ; shift
    line="$line $*"

    if [ -z "$name" ]; then
        ebad "Must specify a name for the source to add"
        return 1
    fi

    if [ -f "$file" ]; then
        if grep -qE "^$line$" "$file" ; then
            # file exists with the same content we want to add
            egood "Already installed PPA $name"
            return 0
        fi
        # file exists but doesn't have the source we want
        sudo mv "$file"{,.save}
    fi
    sudo sh -c "printf '${line}\n' >> $file"
    estatus "Added $name ppa at $file"
    return 1
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

npm_package_is_installed() {
    npm -g ls "$1" &> /dev/null
}

install_npm_package() {
    declare -r PACKAGE="$1"
    if ! npm_package_is_installed "$PACKAGE"; then
        execute "sudo npm -g install $PACKAGE" "Installing $PACKAGE with npm -g"
    else
        egood "Already installed global npm package $PACKAGE"
    fi
}

gem_is_installed() {
    gem list -i "$1" &> /dev/null

}

install_gem() {
    declare -r GEM="$1"
    if ! gem_is_installed "$GEM"; then
        execute "sudo gem install $GEM" \
        "Installing $GEM with gem"
    else
        egood "Already installed global gem $GEM"
    fi
}

snap_is_installed() {
    snap list "$1" &> /dev/null
}

install_snap() {
    declare -r SNAP="$1"
    if ! snap_is_installed "$SNAP"; then
        execute "sudo snap install $SNAP" \
        "Installing $SNAP with snap"
    else
        egood "Already installed snap $SNAP"
    fi
}


install_package() {
    declare -r EXTRA_ARGUMENTS="$2"
    declare -r PACKAGE="$1"

    if ! package_is_installed "$PACKAGE"; then
        execute "sudo apt-get install -qy $EXTRA_ARGUMENTS $PACKAGE" "Installing $PACKAGE"
        #execute "sleep 5" "$PACKAGE"
    else
        egood "Already installed $PACKAGE"
    fi
}

update() {
    # Resynchronize the package index files from their sources.
    execute \
        "sudo apt-get update -qqy" \
        "APT (update)"

}

user_in_group() {
    declare -r user="$1"
    declare -r group="$2"

    group_list=$(groups "$user" | cut -d: -f2)
    group_list=$(trim_string "$group_list")
    group_list=$(split "$group_list" " ")

    for grp in $group_list ; do
        if [ "$grp" = "$group" ] ; then
            return 0
        fi
    done

    return 1
}

add_user_to_group() {
    declare -r user="$1"
    declare -r group="$2"

    if ! user_in_group "$user" "$group" ; then
        echo "user $user not in $group"
        sudo usermod -a -G "$group" "$user"
        estatus "Added $user to $group group"
    else
        egood "User $user already in $group group"
    fi
}
