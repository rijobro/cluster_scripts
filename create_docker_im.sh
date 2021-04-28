#!/bin/bash

set -e # stop on error

################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo "Build docker image and upload it to docker hub."
	echo
	echo "Syntax: create_docker_im.sh [-h|--help] [--docker_base im] [--docker_im_name name] [--docker_uname uname]"
	echo "                            [--uname uname] [--pwd pwd] [--user_id user_id] [--group_id group_id]"
	echo "                            [--groups groups] [--gids gids] [--auth_keys_path path] [--id_rsa_path path]"
	echo
	echo "options:"
	echo "-h, --help          : Print this help."
	echo
	echo "--docker_base       : Base docker image. Default: nvcr.io/nvidia/pytorch:21.04-py3."
	echo "--docker_im_name    : Name of image to be uploaded to docker hub. Default: rb-monai."
	echo "--docker_uname      : Docker username for uploading to docker hub. Default: rijobro."
	echo
	echo "--uname             : Username. Default: \$(whoami)."
	echo "--pwd               : Password for sudo access. Default: monai."
	echo "--user_id           : User ID. Default: \$UID."
	echo "--group_id          : Group ID. Default: \$(id -g)."
	echo "--groups            : Groups. Default: \$(groups)."
	echo "--gids              : GIDs. Default: \$(getent group \$(groups) | awk -F: '{print \$3}')."
	echo
	echo "--auth_keys_path    : Path to \"auth_keys_path\". Default: ~/.ssh/authorized_keys."
	echo "--id_rsa_path       : Path to \"id_rsa_path\". Default: ~/.ssh/id_rsa_path."
	echo
}

################################################################################
# parse input arguments
################################################################################
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-h|--help)
			print_usage
			exit 0
		;;
		--docker_base)
			docker_base="$2"
			shift
		;;
		--docker_im_name)
			docker_im_name="$2"
			shift
		;;
		--docker_uname)
			docker_uname="$2"
			shift
		;;
		--uname)
			uname="$2"
			shift
		;;
		--password)
			password="$2"
			shift
		;;
		--user_id)
			user_id="$2"
			shift
		;;
		--group_id)
			group_id="$2"
			shift
		;;
		--groups)
			groups="$2"
			shift
		;;
		--gids)
			gids="$2"
			shift
		;;
		--auth_keys_path)
			auth_keys_path="$2"
			shift
		;;
		--id_rsa_path)
			id_rsa_path="$2"
			shift
		;;
		*)
			print_usage
			exit 1
		;;
	esac
	shift
done

# Default variables
: "${docker_base:=nvcr.io/nvidia/pytorch:21.04-py3}"
: "${docker_im_name:=rb-monai}"
: "${docker_uname:=rijobro}"

: "${uname:=$(whoami)}"
: "${password:=monai}"
: "${user_id:=$UID}"
: "${group_id:=$(id -g)}"
: "${groups:=$(groups)}"
: "${gids:=$(getent group $(groups) | awk -F: '{print $3}')}"

: "${auth_keys_path:=$HOME/.ssh/authorized_keys}"
: "${id_rsa_path:=$HOME/.ssh/id_rsa.pub}"

echo
echo
echo "Base docker image: ${docker_base}"
echo "Generated image name: ${docker_im_name}"
echo "Docker username: ${docker_uname}"
echo
echo "Username: ${uname}"
echo "Password: ${password}"
echo "User ID: ${user_id}"
echo "Group ID: ${group_id}"
echo "Groups: ${groups}"
echo "GIDs: ${gids}"
echo
echo "Location of auth_keys_path: ${auth_keys_path}"
echo "Location of id_rsa_path: ${id_rsa_path}"
echo
echo


# cleanup
function cleanup {
	rm -f id_rsa.pub authorized_keys
}
trap cleanup EXIT

# Move to current directory
cd "$(dirname "$0")"

# Copy in the authorized and public keys so that it can be added to the authorized keys in the container
cat $auth_keys_path > authorized_keys
cp "${id_rsa_path}" .

docker build -t $docker_im_name . \
	-f Dockerfile \
	--build-arg DOCKER_BASE=$docker_base \
	--build-arg UNAME=${uname} \
	--build-arg PW=${password} \
	--build-arg USER_ID=${user_id} \
	--build-arg GROUP_ID=${group_id} \
	--build-arg GROUPS="${groups}" \
	--build-arg GIDS="${gids}" \
	--network=host

# run with:
#docker run --rm -ti -d -p 3333:2222 ${docker_im_name}

# Push image
docker tag $docker_im_name ${docker_uname}/${docker_im_name}
docker push ${docker_uname}/${docker_im_name}:latest
