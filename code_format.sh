#!/bin/bash

# don't exit on error.
set -e

# cd to base directory (directory of this file)
cd "$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

#######################################################################################################################
# Output formatting
#######################################################################################################################
# if stdout is a terminal
if [[ -t 1 ]]; then
    separator="--------------------------------------------------------------------------------\n"
    red="$(tput bold; tput setaf 1)"
    green="$(tput bold; tput setaf 2)"
    yellow="$(tput bold; tput setaf 3)"
    blue="$(tput bold; tput setaf 4)"
    noColour="$(tput sgr0)"
else
    separator=""
    red=""
    green=""
    yellow=""
    blue=""
    noColour=""
fi

#######################################################################################################################
# Usage
#######################################################################################################################
function print_usage {
    echo "runtests.sh [-h|--help]"
    echo
    echo "Code format checker."
    echo ""
    echo "options:"
    echo "    -h|--help             : Print this message and quit."
    echo
}

#######################################################################################################################
# Parse input arguments
#######################################################################################################################
while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    case $key in
        -h|--help)
            print_usage
            exit 0
        ;;
        *)
            echo ${red}Unknown argument: $key${noColour}
            print_usage
            exit 1
        ;;
    esac
done

#######################################################################################################################
# utility functions
#######################################################################################################################
Isort=-1
Black=-1
Flake8=-1
Pylint=-1

function print_results {
    all_good=true
    for name in Isort Black Flake8 Pylint; do
        val=${!name}
        echo -n "$name: "
        if [ $val -eq -1 ]; then
            echo -n "${yellow}Not run."
        elif [ $val -eq -0 ]; then
            echo -n "${green}Good!"
        else
            echo -n "${red}Failure (code: ${val})."
            all_good=false
        fi
        echo ${noColour}
    done
    [[ $all_good = true ]] || exit 1
}

function check_pass() {
    for name in "$@"; do
        [ "${!name}" = "0" ] || return 1
    done
    return 0
}

# arg 1 is name (e.g., "isort"), arg 2 is command (e.g., "isort . --profile black").
function check() {
    name="${1}"; exe="${2}"
    # run
    echo -e ${separator}${blue}Running ${name}...${noColour}
    $exe
    success=$?
    [ $success -eq 0 ] && msg="${green}Good!" || msg="${red}Failed!"
    echo ${msg}${noColour}
    return $success
}

function check_dependencies() {
    # check dependencies
    all_good=true
    for dep in $*; do
        command -v $dep >/dev/null 2>&1 || \
            { echo "${red}${dep} missing.${noColour}"; all_good=false; }
    done
    if [ $all_good = false ]; then exit 1; fi
}
check_dependencies isort black flake8 pylint

#######################################################################################################################
# isort
#######################################################################################################################
check isort "isort . --profile black"
Isort=$?

#######################################################################################################################
# black
#######################################################################################################################
check black "black . --line-length 120"
Black=$?

#######################################################################################################################
# flake8
#######################################################################################################################
ignores="E203,E402,W503,B027,E741"
cmd="flake8 . --ignore=$ignores --max-line-length 120 --count --statistics"
check flake8 "${cmd}"
Flake8=$?

#######################################################################################################################
# pylint
#######################################################################################################################
all_files=$(find . -type f -name "*.py")
ignores="C0103"
#"C0103,R0913,R0912,R0903,R0914,W0212,R1702,R0801,R0902,R0401"
cmd="pylint --max-line-length 120 --disable=$ignores ${all_files}"
check pylint "${cmd}"
Pylint=$?

#######################################################################################################################
# Print results
#######################################################################################################################
echo
print_results
