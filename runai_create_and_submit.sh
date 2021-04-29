#!/bin/bash

set -e # exit on error

# Job name
jobname=rb-monai

# Move to current directory
cd "$(dirname "$0")"

# Update docker image if necessary
./create_docker_im.sh --docker_push

# Delete previously running job
runai delete $jobname 2> /dev/null

# Submit job
runai submit $jobname \
	--service-type=nodeport \
	-i rijobro/$jobname:latest \
	-g 1 \
	--interactive \
	--port 30022:2222 \
	--host-ipc \
	-v ~/Documents/Code/MONAI:/home/rbrown/Documents/Code/MONAI \
	-v ~/Documents/Code/monai-tutorials:/home/rbrown/Documents/Code/monai-tutorials \
	-v ~/Documents/Data:/home/rbrown/Documents/Data \
	-v ~/Documents/Code/dgxscripts:/home/rbrown/Documents/Code/dgxscripts \
	-v ~/Documents/Code/real_time_seg:/home/rbrown/Documents/Code/real_time_seg \
	-v ~/.vscode-server:/home/rbrown/.vscode-server \
	-v ~/Documents/Scratch:/home/rbrown/Documents/Scratch \
	-e MONAI_DATA_DIRECTORY=/home/rbrown/Documents/Data/MONAI \
	-e SYNAPSE_USER=rijobro \
	-e SYNAPSE_PWD="synapsepassword4?" \
	--command -- sh /home/rbrown/Documents/Code/dgxscripts/monaistartup.sh \
		--python_path /home/rbrown/Documents/Code/MONAI:/home/rbrown/Documents/Code/ptproto \
		--ssh_server --pulse_audio --jupy

# Get job status
function get_status {
	pat="status: ([a-zA-Z]*)"
	[[ $(runai describe job $jobname -o yaml) =~ $pat ]] 2> /dev/null
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
	if [[ "$new_status" == "Running" ]]; then
		break
	fi
	sleep .5
done

# Terminal notification
echo -e "\a"
