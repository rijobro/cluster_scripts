#!/bin/bash

set -e # exit on error

# Job name
jobname=rb-monai

# Move to current directory
cd "$(dirname "$0")"

# Update docker image if necessary
./create_docker_im.sh

# Delete previously running job
runai delete $jobname 2> /dev/null

# Submit job
runai submit $jobname \
	--service-type=nodeport \
	-i rijobro/$jobname:latest \
	-g 1 \
	--interactive \
	--port 30022:2222 \
	--port 30023:8888 \
	--host-ipc \
	-v ~/Documents/Code/bash_profile:/home/rbrown/bash_profile \
	-v ~/Documents/Code/MONAI:/home/rbrown/MONAI \
	-v ~/Documents/Code/monai-tutorials:/home/rbrown/monai-tutorials \
	-v ~/Documents/Data:/home/rbrown/data \
	-v ~/Documents/Code/dgxscripts:/home/rbrown/dgxscripts \
        -v ~/Documents/Code/real_time_seg:/home/rbrown/real_time_seg \
	-v ~/.vscode-server:/home/rbrown/.vscode-server \
	-v ~/Documents/Scratch:/home/rbrown/Scratch \
	--command -- sh /home/rbrown/dgxscripts/monaistartup.sh

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
