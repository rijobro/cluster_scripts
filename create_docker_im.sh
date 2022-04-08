#!/bin/bash

set -e # stop on error

################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'Build docker image and upload it to docker hub.'
	echo
	echo 'Syntax: create_docker_im.sh [-h|--help] [--docker_push] [--docker_base im] [--docker_im_name name]'
	echo '                            [--pwd_hash pwd_hash] [--jupy_pwd_hash] [--docker_args args]'
	echo
	echo 'options:'
	echo '-h, --help          : Print this help.'
	echo
	echo '--docker_push       : Push the created image to dockerhub.'
	echo '--docker_base       : Base docker image. Default: nvcr.io/nvidia/pytorch:22.03-py3.'
	echo '--docker_im_name    : Name of image to be uploaded to docker hub. Default: rb-monai.'
	echo
	echo '--pwd_hash          : Password hash for sudo access. Can be generated with \"openssl passwd -6\".'
	echo '                      Default: $6$hlNDjzLqt8DuY.xq$Ko02k2AapMgOobZCM2bHmw8Fa4GTw9H8N0HJNWdj7yI0L7paM7WTRxP2/xwTFvxOkq/C/tmZZkV11FTu4mhY3/.'
	echo '--jupy_pwd_hash     : Jupyter notebook password hash. Can be generated with python -c "from notebook.auth import passwd; print(passwd())"'
	echo '                      Default: argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'
	echo
	echo '--docker_args       : Pass the any extra arguments onto the docker build (e.g., `--docker_args --no-cache`)'
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
		--docker_push)
			docker_push=true
		;;
		--docker_base)
			docker_base="$2"
			shift
		;;
		--docker_im_name)
			docker_im_name="$2"
			shift
		;;
		--pwd_hash)
			pwd_hash="$2"
			shift
		;;
		--jupy_pwd_hash)
			jupy_pwd_hash="$2"
			shift
		;;
		--docker_args)
			extra_docker_args="$2"
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
: ${docker_push:=false}
: ${docker_base:=nvcr.io/nvidia/pytorch:22.03-py3}
: ${docker_im_name:=rb-monai}
: ${pwd_hash:='$6$hlNDjzLqt8DuY.xq$Ko02k2AapMgOobZCM2bHmw8Fa4GTw9H8N0HJNWdj7yI0L7paM7WTRxP2/xwTFvxOkq/C/tmZZkV11FTu4mhY3/'}
: ${jupy_pwd_hash:='argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'}

# Fixed variables
uname=$(whoami)
user_id=$UID
group_id=$(id -g)
groups=$(groups)
gids=$(getent group $(groups) | awk -F: '{print $3}')
auth_keys_path=$HOME/.ssh/authorized_keys
id_rsa_path=$HOME/.ssh/id_rsa.pub
docker_uname=$(docker info 2> /dev/null | sed '/Username:/!d;s/.* //')

echo
echo
echo "Base docker image: ${docker_base}"
echo "Generated image name: ${docker_im_name}"
echo "Docker username: ${docker_uname}"
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
	--build-arg PWD_HASH="${pwd_hash}" \
	--build-arg USER_ID=${user_id} \
	--build-arg GROUP_ID=${group_id} \
	--build-arg GROUPS="${groups}" \
	--build-arg GIDS="${gids}" \
	--build-arg JUPY_PWD_HASH="${jupy_pwd_hash}" \
	--network=host \
	${extra_docker_args}

# Push image
if [ $docker_push = true ]; then
	docker tag $docker_im_name ${docker_uname}/${docker_im_name}
	docker push ${docker_uname}/${docker_im_name}:latest
fi
