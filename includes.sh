#!/bin/bash
set -e
set -u

export txtred="$(tput setaf 1)"
export blkred="$(tput setaf 1)$(tput blink)"
export txtgrn="$(tput setaf 2)"
export txtylw="$(tput setaf 3)"
export txtblu="$(tput setaf 4)"
export txtrst="$(tput sgr 0)"

function header {
	echo -e "\n$txtblu===== $1 =====$txtrst"
}

function error {
	echo -e "$blkred*** $1 ***$txtrst"
}

function success {
	echo -e "$txtgrn* $1 *$txtrst"
}
