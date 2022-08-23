#!/bin/bash

set -e # exit on error


#####################################################################################
# Default variables (search this file for "Post-processing defaults" to see others)
#####################################################################################
time="3days"
state=""

#####################################################################################
# Usage
#####################################################################################
print_usage()
{
    # Display Help
    echo 'SLURM sacct wrapper. Prints the information I find most useful, with'
    echo '  convenience wrappers for arguments I use most frequently.'
    echo
    echo 'Brief syntax:'
    echo 'jade_sacct.sh [OPTIONS(0)...] [ : [OPTIONS(N)...]] -- <cmd>'
    echo
    echo 'Full syntax:'
    echo 'Syntax: jade_submit.sh [-h|--help] [-t|--time] [-u|--units]'
    echo '                  [-s|--state <val>]'
    echo
    echo 'options without args:'
    echo '-h, --help                : Print this help.'
    echo
    echo '-t, --time <val>          : Time frame to report results. Default: 3days.'
    echo '-s, --state <val>         : State of jobs to prune. Default: all.'
    echo
}

#####################################################################################
# Parse input arguments
#####################################################################################
while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -h|--help)
            print_usage
            exit 0
        ;;
        -t|--time)
            time=$1
            shift
        ;;
        -s|--state)
            state=$1
            shift
        ;;
        *)
            echo -e "\n\nUnknown argument: $key\n\n"
            print_usage
            exit 1
        ;;
    esac
done

# If state isn't blank
if [ "${state}" != "" ]; then
    state_cmd="-s ${state}"
fi


echo Printing jobs over last $time
SLURM_TIME_FORMAT="%d/%m %H:%M:%S" sacct ${state_cmd} -S now-${time} -X --format="jobid,jobname%40,partition,elapsed,timelimit,state,submit,start"

