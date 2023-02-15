#!/bin/bash

set -e # stop on error

#####################################################################################
# Default variables
#####################################################################################
docker_push=false
docker_base="nvcr.io/nvidia/pytorch:23.01-py3"
docker_im_name="${RUNAI_NAME}"
pwd_hash="${RUNAI_SSH_HASH}"
jupy_pwd_hash="${RUNAI_JUPY_HASH}"

################################################################################
# Usage
################################################################################
print_usage()
{
    # Display Help
    echo "Build docker image and upload it to docker hub."
    echo
    echo "Brief syntax:"
    echo "${0##*/} [OPTIONS(0)...] [ : [OPTIONS(N)...]]"
    echo
    echo "Full syntax:"
    echo "${0##*/} [-h|--help] [-d|--docker_push]"
    echo "                  [-b|--docker_base <val>] [-i|--docker_im_name]"
    echo "                  [-p|--pwd_hash <val] [-j|--jupy_pwd_hash <val>]"
    echo "                  [-a|--docker_args <val>]"
    echo
    echo "options:"
    echo "-h, --help              : Print this help."
    echo
    echo "-d, --docker_push       : Push the created image to dockerhub."
    echo "-b, --docker_base       : Base docker image. Default: ${docker_base}."
    echo "-i, --docker_im_name    : Name of image to be uploaded to docker hub. Default from"
    echo "                             environment variable ``RUNAI_NAME``."
    echo
    echo "-p, --pwd_hash          : Password hash for sudo access. Can be generated with \"openssl passwd -6\"."
    echo "                             Default from environment variable ``RUNAI_SSH_HASH``."
    echo "-j, --jupy_pwd_hash     : Jupyter notebook password hash. Default from environment variable ``RUNAI_JUPY_HASH``."
    echo "                             Can be generated with:"
    echo "                             ``python -c \"from notebook.auth import passwd; print(passwd())\"``."
    echo
    echo "-a, --docker_args       : Pass the any extra arguments onto the docker build (e.g., ``--docker_args --no-cache``)."
    echo
}

################################################################################
# Parse input arguments
################################################################################
while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    case $key in
        -h|--help)
            print_usage
            exit 0
        ;;
        -d|--docker_push)
            docker_push=true
        ;;
        -b|--docker_base)
            docker_base="$1"
            shift
        ;;
        -i|--docker_im_name)
            docker_im_name="$1"
            shift
        ;;
        -p|--pwd_hash)
            pwd_hash="$1"
            shift
        ;;
        -j|--jupy_pwd_hash)
            jupy_pwd_hash="$1"
            shift
        ;;
        -a|--docker_args)
            extra_docker_args="$1"
            shift
        ;;
        *)
            print_usage
            exit 1
        ;;
    esac
done

# Fixed variables
uname=$(whoami)
user_id=$UID
group_id=$(id -g)
groups=$(groups)
gids=$(getent group $(groups) | awk -F: '{print $3}')
auth_keys_path=$HOME/.ssh/authorized_keys
id_rsa_path=$HOME/.ssh/id_rsa.pub
docker_uname=$(docker info 2> /dev/null | sed '/Username:/!d;s/.* //')

# Print vals
echo
echo "Base docker image: ${docker_base}"
echo "Generated image name: ${docker_im_name}"
echo "Docker username: ${docker_uname}"
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

#####################################################################################
# Build
#####################################################################################
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
    --build-arg GIT_NAME="$(git config --get user.name)" \
    --build-arg GIT_EMAIL="$(git config --get user.email)" \
    --network=host \
    ${extra_docker_args}

#####################################################################################
# Push image
#####################################################################################
if [ $docker_push = true ]; then
    docker tag $docker_im_name ${docker_uname}/${docker_im_name}
    docker push ${docker_uname}/${docker_im_name}:latest
fi

# Terminal notification
echo -e "\a"
