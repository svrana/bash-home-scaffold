#!/bin/bash
#
# Many of these from gentoo @
#   https://github.com/gentoo/gentoo-functions/blob/master/functions.sh
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/colors.sh"

# Safer way to list the contents of a directory as it doesn't have the 'empty
# dir bug'.
#
# char *dolisting(param)
#
#    print a list of the directory contents
#
#    NOTE: quote the params if they contain globs.
#          also, error checking is not that extensive
function dolisting() {
    local x=
    local y=
    local tmpstr=
    local mylist=
    local mypath="$*"

    if [[ ${mypath%/\*} != "${mypath}" ]] ; then
        mypath=${mypath%/\*}
    fi

    for x in ${mypath} ; do
        [[ ! -e ${x} ]] && continue

        if [[ ! -d ${x} ]] && [[ -L ${x} || -f ${x} ]] ; then
            mylist="${mylist} $(ls "${x}" 2> /dev/null)"
        else
            [[ ${x%/} != "${x}" ]] && x=${x%/}

            cd "${x}"; tmpstr=$(ls)

            for y in ${tmpstr} ; do
                mylist="${mylist} ${x}/${y}"
            done
        fi
    done

    echo "${mylist}"
}

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

# Remove all invalid directories from PATH
#
# @return String PATH
function PATH_clean() {
    local ruby_path=$(which ruby)
    if [ -z "$ruby_path" ]; then
        ebad "Could not find ruby!!" >&2
        return
    fi

    ruby -e "puts ENV['PATH'].split(':') \
        .inject([]) { |r,k| r << k if File.exist?(k) ; r } \
        .join(':')"
}

function PATH_prepend() {
    [ -z "$1" ] && return

    paths=$(echo "$1" | tr ":" "\n")
    for path in $paths ; do
        echo "GOT PATH element: $path"
        if [ "${PATH#*${path}}" = "${PATH}" ]; then
            export PATH=$path:$PATH
        fi
    done
}

function PATH_append() {
    [ -z "$1" ] && return

    paths=$(echo "$1" | tr ":" "\n")
    for path in $paths ; do
        if [ "${PATH#*${path}}" = "${PATH}" ]; then
            export PATH=$PATH:$path
        fi
    done
}

function CDPATH_append() {
    [ -z "$1" ] && return

    paths=$(echo "$1" | tr ":" "\n")
    for path in $paths ; do
        if [ "${CDPATH#*${path}}" = "${PATH}" ]; then
            export CDPATH=$CDPATH:$path
        fi
    done
}