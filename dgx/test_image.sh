#!/bin/bash

# crash on error
set -e

#######################################################################################################################
# Output formatting
#######################################################################################################################
separator="--------------------------------------------------------------------------------\n"
# if stdout is a terminal
if [[ -t 1 ]]; then
    red="$(tput bold; tput setaf 1)"
    green="$(tput bold; tput setaf 2)"
    yellow="$(tput bold; tput setaf 3)"
    blue="$(tput bold; tput setaf 4)"
    noColour="$(tput sgr0)"
else
    red=""
    green=""
    yellow=""
    blue=""
    noColour=""
fi

# on error, display this error
disp_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${separator}${green}\nTESTING OF IMAGE SUCCEEDED!${noColour}"
    else
        echo -e "${separator}${red}\nTESTING OF IMAGE FAILED!${noColour}"
    fi
    exit $1
}
# trap fail EXIT
trap 'disp_result $?' EXIT

echo -e "\n\n${separator}${blue}TESTING DOCKER IMAGE!\n${noColour}"

processes=$(ps x)

# check sshd is running
echo -e "\n\n${separator}${blue}Checking SSHD is running...${noColour}"
echo $processes | grep /usr/sbin/sshd >/dev/null || (cat /home/$(whoami)/.ssh/sshd.log && exit 1)
echo -e "${green}SSHD is running!${noColour}"

# check jupyter is running
echo -e "\n\n${separator}${blue}Checking jupyter is running...${noColour}"
echo $processes | grep jupyter >/dev/null || exit 1
echo -e "${green}jupyter is running!${noColour}"

# check conda path
echo -e "\n\n${separator}${blue}Checking conda path...${noColour}"
res=$(which conda)
[[ $res == "/home/$(whoami)/miniconda/bin/conda" ]] || (echo "conda path: $res" && exit 1)
echo -e "${green}conda path is good!${noColour}"

# check correct env is activated
echo -e "\n\n${separator}${blue}Checking conda env...${noColour}"
[[ $CONDA_DEFAULT_ENV == py ]] || (echo "conda env: $CONDA_DEFAULT_ENV" && exit 1)
echo -e "${green}conda env is good!${noColour}"

cat .bashrc
exit 1

# check python path
echo -e "\n\n${separator}${blue}Checking python path...${noColour}"
res=$(which python)
[[ $res == "/home/$(whoami)/miniconda/envs/py/bin/python" ]] || (echo "python path: $res" && exit 1)
echo -e "${green}python is good!${noColour}"

# check pip path
echo -e "\n\n${separator}${blue}Checking pip path...${noColour}"
res=$(which pip)
[[ $res == "/home/$(whoami)/miniconda/envs/py/bin/pip" ]] || (echo "pip path: $res" && exit 1)
echo -e "${green}pip is good!${noColour}"

# check python version
echo -e "\n\n${separator}${blue}Checking python version...${noColour}"
res=$(python --version)
echo $res | grep "Python 3.10." || (echo "python version: $res" && exit 1)
echo -e "${green}python version is good!${noColour}"

# check torch
echo -e "\n\n${separator}${blue}Checking pytorch...${noColour}"
res=$(python -c "import torch; print(torch.__version__)")
[[ $res == "2.0.1+cu117" ]] || (echo "pytorch version: $res" && exit 1)
echo -e "${green}pytorch version is good!${noColour}"

# check cupy
echo -e "\n\n${separator}${blue}Checking cupy...${noColour}"
python -c "import cupy"
echo -e "${green}cupy is good!${noColour}"

# check cucim
echo -e "\n\n${separator}${blue}Checking cucim...${noColour}"
python -c "from cucim.core.operations.morphology import distance_transform_edt"
echo -e "${green}cucim is good!${noColour}"
