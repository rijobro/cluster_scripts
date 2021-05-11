#!/bin/bash

set -e # exit on error

################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'Script to submit a runai job.'
	echo
	echo 'Syntax: runai_create_and_submit.sh [-h|--help] [-g|--gpu <num>] [--job-name <name>]'
	echo '                                   [--ssh-port <num>] [--non-interactive]'
	echo
	echo 'options:'
	echo '-h, --help                : Print this help.'
	echo
	echo '--gpu <val>               : Number of gpus to submit. Default: 1.'
	echo '--job-name <val>          : Name of submitted job. Default: rb-monai.'
	echo '--ssh-port <val>          : SSH port. Default: 30022.'
	echo '--non-interactive         : By default, job is interactive. Use this to submit as non-interactive.'
	echo
}

################################################################################
# parse input arguments
################################################################################

# Default variables
gpu=1
job_name=rb-monai
im_name=rb-monai
ssh_port=30022
interactive="--interactive"

while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-h|--help)
			print_usage
			exit 0
		;;
		-g|--gpu)
			gpu=$2
			shift
		;;
		--job-name)
			job_name=$2
			shift
		;;
		--ssh-port)
			ssh_port=$2
			shift
		;;
		--non-interactive)
			interactive=""
		;;
		*)
			echo -e "\n\nUnknown argument: $key\n\n"
			print_usage
			exit 1
		;;
	esac
	shift
done

# Move to current directory
cd "$(dirname "$0")"

# Update docker image if necessary
./create_docker_im.sh --docker_push

# Delete previously running job
runai delete $job_name 2> /dev/null

# Submit job
runai submit $job_name $interactive \
	--service-type=nodeport \
	-i rijobro/$im_name:latest \
	-g $gpu \
	--port ${ssh_port}:2222 \
	--host-ipc \
	-v ~/Documents/Code/MONAI:/home/rbrown/Documents/Code/MONAI \
	-v ~/Documents/Code/monai-tutorials:/home/rbrown/Documents/Code/monai-tutorials \
	-v ~/Documents/Data:/home/rbrown/Documents/Data \
	-v ~/Documents/Code/dgxscripts:/home/rbrown/Documents/Code/dgxscripts \
	-v ~/Documents/Code/RealTimeSeg:/home/rbrown/Documents/Code/RealTimeSeg \
	-v ~/.vscode-server:/home/rbrown/.vscode-server \
	-v ~/Documents/Scratch:/home/rbrown/Documents/Scratch \
	--command -- sh /home/rbrown/Documents/Code/dgxscripts/monaistartup.sh \
		--ssh_server --pulse_audio --jupy \
		-e MONAI_DATA_DIRECTORY=/home/rbrown/Documents/Data/MONAI \
		-e SYNAPSE_USER=rijobro \
		-e SYNAPSE_PWD="synapsepassword4?" \
		-e PYTHONPATH='/home/rbrown/Documents/Code/MONAI:/home/rbrown/Documents/Code/ptproto:${PYTHONPATH}' \
		-a 'cdMONAI="cd /home/rbrown/Documents/Code/MONAI"'
#                -e LD_LIBRARY_PATH='${LD_LIBRARY_PATH}:/home/rbrown/Documents/Code/opencv/Install/lib/:~/Documents/Code/libtorch/lib/' \

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
	if [[ "$new_status" == "Failed" ]]; then
		runai logs $job_name
		break
	elif [[ "$new_status" == "Running" ]]; then
		break
	fi
	sleep .5
done

# Terminal notification
echo -e "\a"
