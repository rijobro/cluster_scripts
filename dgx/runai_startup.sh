#!/bin/bash

set -e # exit on error

#####################################################################################
# Default variables
#####################################################################################
run_dir=$(pwd)
cmd="sleep infinity"

################################################################################
# Usage
################################################################################
print_usage()
{
	echo 'Script to be run at start of runai job.'
	echo
	echo 'Brief syntax:'
    echo "${0##*/} [OPTIONS(0)...] [ : [OPTIONS(N)...]] [-- <cmd>]"
	echo
    echo 'Full syntax:'
	echo "${0##*/} [-h|--help] [-d|--dir <val>] [-- <cmd>]"
	echo
	echo 'options without args:'
	echo '-h, --help                : Print this help.'
    echo
    echo 'options with args:'
	echo '-d, --dir <val>           : Directory to run from. Default: `pwd`.'
	echo
	echo 'NB: if `-- <cmd>` not given, `sleep infinity` is used.'
}

################################################################################
# Parse input arguments
################################################################################
while [[ $# -gt 0 ]]; do
	key="$1"
    shift
    if [ "$key" == "--" ]; then
        if [ "$#" -gt 0 ]; then
            cmd="$*"
        fi
        break
    fi
	case $key in
		-h|--help)
			print_usage
			exit 0
		;;
		-d|--dir)
            run_dir=$1
            shift
        ;;
		*)
			echo -e "\n\nUnknown argument: $key\n\n"
			print_usage
			exit 1
		;;
	esac
done

# Print vals
echo
echo "Path: ${run_dir}"
echo "Command: ${cmd}"
echo

#####################################################################################
# Correct "~" (runai bug), source bashrc, start jupyter and sshd
#####################################################################################

export HOME=/home/$(whoami)
source ~/.bashrc

# SSH server and jupyter notebook
nohup /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/.ssh/sshd.log &
nohup jupyter notebook --ip 0.0.0.0 --no-browser --notebook-dir="~" > ~/.jupyter_notebook.log 2>&1 &

#####################################################################################
# CD to running directory and execute command
#####################################################################################

cd $run_dir

echo Desired running dir: ${run_dir}
echo Current dir: $(pwd)

# the trap code is designed to send a stop (SIGTERM) signal to child processes,
# thus allowing python code to catch the signal and execute a callback
trap 'trap " " SIGTERM; kill 0; wait' SIGTERM

echo running ${cmd}
${cmd} &
wait $!