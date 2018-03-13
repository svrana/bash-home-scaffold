#!/bin/bash
#
# An enumeration of colors and column width calculation.
#

if tty -s ; then
    use_color=true
else
    use_color=false
fi

# Setup COLS and ENDCOL so eend can line up the [ ok ]
COLS="${COLUMNS:-0}"            # bash's internal COLUMNS variable
[ "$COLS" -eq 0 ] && COLS="$(set -- $(stty size 2>/dev/null) ; printf "$2\n")"
[ -z "$COLS" ] && COLS=80
[ "$COLS" -gt 0 ] || COLS=80	# width of [ ok ] == 7

if [ $use_color ]; then
    ENDCOL='\033[A\033['$(( COLS - 8 ))'C'
else
    ENDCOL=''
fi
export ENDCOL

if ! ${use_color} ; then
    export RED=
    export green=
    export GOOD=
    export BAD=
    export NORMAL=
    export BRACKET=
else
    export RED='\e[38;5;198m'
    export green='\e[38;5;82m'
    export GOOD=$green
    export BAD=$RED
    export NORMAL='\E[0m'
    export BRACKET='\E[34;01m'
fi
