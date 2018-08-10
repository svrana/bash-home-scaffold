#!/bin/bash
#
# Many of these from gentoo @
#   https://github.com/gentoo/gentoo-functions/blob/master/functions.sh
#

function _load_deps() {
    local CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$CURRENT_DIR/colors.sh"
}
_load_deps

# void ebox(void)
# 	indicates a failure in a "box"
function ebox() {
    echo -e "${ENDCOL}  ${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL}"
}

# void sbox(void)
# 	indicates a success in a "box"
function sbox() {
    echo -e "${ENDCOL}  ${BRACKET}[ ${GOOD}ok${BRACKET} ]${NORMAL}"
}

function egood() {
    echo "$*"
    sbox
}

function ebad() {
    echo "$*"
    ebox
}

function estatus() {
    if [ $? -eq 0 ]; then
        egood "$*"
    else
        ebad "$*"
    fi
}


# Usage: split "string" "delimiter"
function split() {
   IFS=$'\n' read -d "" -ra arr <<< "${1//$2/$'\n'}"
   printf '%s\n' "${arr[@]}"
}


function PATH_append() {
    [ -z "$1" ] && return

    paths=$(split "$1" ":")
    for path in $paths ; do
        if [ "${PATH#*${path}}" = "${PATH}" ]; then
            export PATH=$PATH:$path
        fi
    done
}
