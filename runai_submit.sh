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
	echo 'Syntax: runai_submit.sh [-h|--help] [-g|--gpu <num>] [--job-name <name>] [--im-name <name>]'
	echo '                        [--ssh-port <num>] [--non-interactive] [--create]'
	echo
	echo 'options:'
	echo '-h, --help                : Print this help.'
	echo
	echo '--gpu <val>               : Number of gpus to submit. Default: 1.'
	echo '--job-name <val>          : Name of submitted job. Default: rb-monai.'
	echo '--im-name <val>           : Name of docker image ot be run. Default: rb-monai.'
	echo '--ssh-port <val>          : make accessible via SSH through given port. If `--interactive`, default: 30069'
	echo '--interactive             : Submit as interactive job.'
	echo '--extra_cmds              : Extra commands to be appended to startup script (e.g., `cd somewhere && python some_file.py`).'
	echo
}

################################################################################
# parse input arguments
################################################################################

# Default variables
gpu=1
job_name=rb-monai
im_name=rb-monai

while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-h|--help)
			print_usage
			exit 0
		;;
		--create)
			create=true
		;;
		-g|--gpu)
			gpu=$2
			shift
		;;
		--job-name)
			job_name=$2
			shift
		;;
		--im-name)
			im_name=$2
			shift
		;;
		--ssh-port)
			use_ssh=true
			ssh_port=$2
			shift
		;;
		--interactive)
			interactive=true
		;;
		--extra_cmds)
			extra_cmds=$2
			shift
		;;
		*)
			echo -e "\n\nUnknown argument: $key\n\n"
			print_usage
			exit 1
		;;
	esac
	shift
done

# Default variables
: ${create:=false}
: ${ssh_port:=30069}

if [ "$interactive" = true ]; then
	use_ssh=true
	interactive="--interactive --service-type=nodeport"
fi

if [ "$use_ssh" = true ]; then
	ssh="--port ${ssh_port}:2222"
fi

# Move to current directory
cd "$(dirname "$0")"

# Delete previously running job
runai delete $job_name > /dev/null 2>&1

# Create startup script with any additional commands
mkdir -p ~/tmp
startup_file=monai_startup_$(date +"%Y-%m-%d_%H-%M-%S").sh
cp ~/Documents/Code/dgxscripts/monaistartup.sh ~/tmp/$startup_file
if [[ -v extra_cmds ]]; then
	echo -e $extra_cmds >> ~/tmp/$startup_file
else
	echo "sleep infinity" >> ~/tmp/$startup_file
fi


# Submit job
runai submit $job_name $interactive $ssh \
	-i rijobro/$im_name:latest \
	-g $gpu \
	--host-ipc \
	-v ~/Documents/Code:/home/rbrown/Documents/Code \
	-v ~/Documents/Data:/home/rbrown/Documents/Data \
	-v ~/.vscode-server:/home/rbrown/.vscode-server \
	-v ~/Documents/Scratch:/home/rbrown/Documents/Scratch \
	-v ~/tmp:/home/rbrown/tmp \
	--backoff-limit 0 \
	--run-as-user \
	--command -- sh /home/rbrown/tmp/$startup_file \
		--ssh_server --pulse_audio --jupy --tensorboard \
		-e MONAI_DATA_DIRECTORY=/home/rbrown/Documents/Data/MONAI \
		-e PYTHONPATH='/home/rbrown/Documents/Code/MONAI:${PYTHONPATH}' \
		-a 'cdMONAI="cd /home/rbrown/Documents/Code/MONAI"'

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
		break
	fi
	sleep .5
done

# Terminal notification
echo -e "\a"
