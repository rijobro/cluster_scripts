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
	echo '                            [--docker_uname uname] [--uname uname] [--pwd_hash pwd_hash] [--user_id user_id]'
	echo '                            [--group_id group_id] [--groups groups] [--gids gids]'
	echo '                            [--github_name name] [--github_email email]'
	echo '                            [--jupy_pwd_hash] [--vnc_pwd]'
	echo '                            [--auth_keys_path path] [--id_rsa_path path]'
	echo '                            [--docker-args args]'
	echo
	echo 'options:'
	echo '-h, --help          : Print this help.'
	echo
	echo '--docker_push       : Push the created image to dockerhub.'
	echo '--docker_base       : Base docker image. Default: nvcr.io/nvidia/pytorch:21.04-py3.'
	echo '--docker_im_name    : Name of image to be uploaded to docker hub. Default: rb-monai.'
	echo '--docker_uname      : Docker username for uploading to docker hub. Default: rijobro.'
	echo
	echo '--uname             : Username. Default: $(whoami).'
	echo '--pwd_hash          : Password hash for sudo access. Can be generated with \"openssl passwd -6\".'
	echo '                      Default: $6$JbDH1Je1XZgHvoBy$IBbclXaWLHv1ToyPYFS8sw7fCTfssidMqtF/gkJWxoF37m58wrK/3OK4CzotnoneB43i8O01MoOeb57zvx3Sk/.'
	echo '--user_id           : User ID. Default: $UID.'
	echo '--group_id          : Group ID. Default: $(id -g).'
	echo '--groups            : Groups. Default: $(groups).'
	echo '--gids              : GIDs. Default: $(getent group $(groups) | awk -F: "{print $3}").'
	echo
	echo '--github_name       : Name for github. Default: $(git config user.name)'
	echo '--github_email      : Email for github. Default: $(git config user.email)'
	echo
	echo '--jupy_pwd_hash     : Jupyter notebook password hash. Can be generated with python -c "from notebook.auth import passwd; print(passwd())"'
	echo '                      Default: argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'
	echo
	echo '--vnc_pwd           : VNC password (plain text). Default: monai1'
	echo
	echo '--auth_keys_path    : Path to "auth_keys_path". Default: ~/.ssh/authorized_keys.'
	echo '--id_rsa_path       : Path to "id_rsa_path". Default: ~/.ssh/id_rsa_path.'
	echo
	echo '--docker-args       : Pass the any extra arguments onto the docker build'
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
		--docker_uname)
			docker_uname="$2"
			shift
		;;
		--uname)
			uname="$2"
			shift
		;;
		--pwd_hash)
			pwd_hash="$2"
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
		--github_name)
			github_name="$2"
			shift
		;;
		--github_email)
			github_email="$2"
			shift
		;;
		--jupy_pwd_hash)
			jupy_pwd_hash="$2"
			shift
		;;
		--vnc_pwd)
			vnc_pwd="$2"
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
		--docker-args)
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
: ${docker_base:=nvcr.io/nvidia/pytorch:21.04-py3}
: ${docker_im_name:=rb-monai}
: ${docker_uname:=rijobro}

: ${uname:=$(whoami)}
: ${pwd_hash:='$6$JbDH1Je1XZgHvoBy$IBbclXaWLHv1ToyPYFS8sw7fCTfssidMqtF/gkJWxoF37m58wrK/3OK4CzotnoneB43i8O01MoOeb57zvx3Sk/'}
: ${user_id:=$UID}
: ${group_id:=$(id -g)}
: ${groups:=$(groups)}
: ${gids:=$(getent group $(groups) | awk -F: '{print $3}')}

: ${github_name:=$(git config user.name)}
: ${github_email:=$(git config user.email)}

: ${jupy_pwd_hash:='argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'}
: ${vnc_pwd:=monai1}

: ${auth_keys_path:=$HOME/.ssh/authorized_keys}
: ${id_rsa_path:=$HOME/.ssh/id_rsa.pub}

echo
echo
echo "Base docker image: ${docker_base}"
echo "Generated image name: ${docker_im_name}"
echo "Docker username: ${docker_uname}"
echo
echo "Username: ${uname}"
echo "Password hash: ${pwd_hash}"
echo "User ID: ${user_id}"
echo "Group ID: ${group_id}"
echo "Groups: ${groups}"
echo "GIDs: ${gids}"
echo
echo "Github email: ${github_email}"
echo "Github name: ${github_email}"
echo
echo "Jupyter password hash: ${jupy_pwd_hash}"
echo
echo "VNC password: ${vnc_pwd}"
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
	--build-arg PWD_HASH="${pwd_hash}" \
	--build-arg USER_ID=${user_id} \
	--build-arg GROUP_ID=${group_id} \
	--build-arg GROUPS="${groups}" \
	--build-arg GIDS="${gids}" \
	--build-arg GITHUB_NAME="${github_name}" \
	--build-arg GITHUB_EMAIL="${github_email}" \
	--build-arg JUPY_PWD_HASH="${jupy_pwd_hash}" \
	--build-arg VNC_PWD="${vnc_pwd}" \
	--network=host \
	${extra_docker_args}

# run with:
#docker run --rm -ti -d -p 3333:2222 ${docker_im_name}

# Push image
if [ $docker_push = true ]; then
	docker tag $docker_im_name ${docker_uname}/${docker_im_name}
	docker push ${docker_uname}/${docker_im_name}:latest
fi
