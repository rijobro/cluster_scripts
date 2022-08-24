#!/bin/bash

set -e # exit on error

#####################################################################################
# Default variables
#####################################################################################
run_dir=$(pwd)
cmd="sleep infinity"
gpu=1
job_name="${RUNAI_NAME}"
im_name="${RUNAI_NAME}"
env_vars="${RUNAI_ENVS}"

################################################################################
# Usage
################################################################################
print_usage()
{
	echo 'Script to submit a runai job.'
	echo
    echo 'Brief syntax:'
    echo "${0##*/} [OPTIONS(0)...] [ : [OPTIONS(N)...]] [-- <cmd>]"
    echo
    echo 'Full syntax:'
    echo "${0##*/} [-h|--help] [-f|--follow] [-d|--dir <val>]"
	echo '                  [-g|--gpu <val>] [-n|--node <val>]'
	echo '                  [-j|--job-name <val>] [-i|--im-name <val>]'
	echo '                  [-e|--env <val>] -- <cmd>'
	echo
    echo 'options without args:'
    echo '-h, --help                : Print this help.'
	echo '-f, --follow              : After submitting, follow job.'
	echo
    echo 'options with args:'
	echo '-d, --dir <val>           : Directory to run from. Default: `pwd`.'
	echo '-g, --gpu <val>           : Number of gpus to submit. Default: 1.'
	echo '-n, --node <val>          : Node to run on. Default is any.'
	echo '-j, --job-name <val>      : Name of submitted job. Default from'
	echo '                             environment variable `RUNAI_NAME`.'
	echo '-i, --im-name <val>       : Name of docker image to be run. Default from'
	echo '                             environment variable `RUNAI_NAME`.'
	echo '-e, --env <val>           : Comma-separated list of variables to copy'
	echo '                             from dgx to job. Default from'
	echo '                             environment variable `RUNAI_ENVS`.'
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
		-f|--follow)
            follow=true
        ;;
        -d|--dir)
            run_dir=$1
            shift
        ;;
		-g|--gpu)
			gpu=$1
			shift
		;;
		-n|--node)
			node="--node-type $1"
			shift
		;;
		-j|--job-name)
			job_name=$1
			shift
		;;
		-i|--im-name)
			im_name=$1
			shift
		;;
		-e|--env)
			env_vars="$1"
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
echo "Num GPUs: ${gpu}"
echo "Requested node: ${node:-Any}"
echo "Job name: ${job_name}"
echo "Image name: ${im_name}"
echo "Env vars: ${env_vars}"
echo
echo "Path: ${run_dir}"
echo "Command: ${cmd}"
echo

#####################################################################################
# Post-process input arguments
#####################################################################################
if [ "${env_vars}" != "" ]; then
	# remove spaces from env list
	env_vars="${env_vars//[[:blank:]]/}"
	# split at commas and convert to array
	env_vars=($(echo $env_vars | tr "," "\n"))
	env_cmd=""
	for i in "${env_vars[@]}"; do
		env_cmd="${env_cmd} -e $i=${!i}"
	done
fi

#####################################################################################
# Get ready to submit (get paths, delete prev. job if necessary)
#####################################################################################

# Get path to current file and move to current dir
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
cd "$script_dir"

# Delete previously running job if one by same name exists
runai delete job $job_name > /dev/null 2>&1 || true

#####################################################################################
# Submit job
#####################################################################################
runai submit $job_name $interactive $node $port $env_cmd \
	-i rijobro/$im_name:latest \
	-g $gpu \
	--host-ipc \
	-v ${HOME}:${HOME} \
	--backoff-limit 0 \
	-- ${script_dir}/runai_startup.sh -d ${run_dir} -- ${cmd}

#####################################################################################
# If desired, job status until RUNNING
#####################################################################################

if [ "$follow" = true ]; then
	# Get job status
	function get_status {
		pat="status: ([a-zA-Z]*)"
		[[ $(runai describe job $job_name -o yaml) =~ $pat ]] 2> /dev/null
		echo "${BASH_REMATCH[1]}"
	}

	# Print the statuses until Running
	old_status=$(get_status)
	while true; do
		new_status=$(get_status)
		if [[ "$new_status" != "" && "$new_status" != "$old_status" ]]; then
			echo Job status: $new_status
			old_status="$new_status"
		fi
		if [[ "$new_status" == "Failed" || "$new_status" == "Succeeded" || "$new_status" == "Completed" ]]; then
			runai logs $job_name
			break
		elif [[ "$new_status" == "Running" ]]; then
			runai logs ${job_name} -f
		fi
		sleep .5
	done
fi

# Terminal notification
echo -e "\a"
