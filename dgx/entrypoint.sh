#!/bin/bash

#####################################################################################
# Output format
#####################################################################################
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


#####################################################################################
# Run a subset of pytorch's original entrypoint (runs checks)
#####################################################################################
for _file in /opt/nvidia/entrypoint.d/*.sh; do
    echo -e "${separator}${blue}Running ${_file}...${noColour}"
    source ${_file}
done
echo


#####################################################################################
# Source bashrc
#####################################################################################
echo -e "${separator}${blue}Sourcing .bashrc...${noColour}"
source "/home/$(whoami)/.bashrc"


#####################################################################################
# Check versions
#####################################################################################
echo -e "${separator}${blue}Code versions...${noColour}"
echo "Python version: $(python --version)"
echo "PyTorch version: $(python -c 'import torch; print(torch.__version__)')"
echo "Has GPU: $(python -c 'import torch; print(torch.cuda.is_available())')"


#####################################################################################
# Start sshd, jupyter and vnc (if there)
#####################################################################################
echo -e "${separator}${blue}Starting SSH server...${noColour}"
log_file=/home/$(whoami)/.ssh/sshd.log
nohup /usr/sbin/sshd -D -f /home/$(whoami)/.ssh/sshd_config -E ${log_file} &
sleep 5
([ -f $log_file ] && grep -q "Server listening" $log_file) || (echo SSH problem && cat $log_file && exit 1)
echo "SSH address: $(hostname -i)"
echo -e "${green}SSH server running!${noColour}"

echo -e "${separator}${blue}Starting jupyter server...${noColour}"
nohup jupyter notebook --ip 0.0.0.0 --no-browser --notebook-dir="/" \
    --config="/home/$(whoami)/.jupyter/jupyter_notebook_config.json" > /home/$(whoami)/.jupyter_notebook.log 2>&1 &
while true; do
    ([ -f /home/$(whoami)/.jupyter_notebook.log ] && grep -q "Serving notebooks from local directory" /home/$(whoami)/.jupyter_notebook.log) \
        && break || sleep 1
done
echo -e "${green}jupyter server running!${noColour}"

if [ -x "$(command -v vncserver)" ]; then
    echo -e "${separator}${blue}Starting vncserver...${noColour}"
    vncserver -SecurityTypes None 2>&1 || true
    echo -e "${green}vncserver running!${noColour}"
fi


#####################################################################################
# Run desired command
#####################################################################################
# This script can either be a wrapper around arbitrary command lines,
# or it will simply exec bash if no arguments were given.

# the trap code is designed to send a stop (SIGTERM) signal to child processes,
# thus allowing the executing code to catch the signal and execute a callback
trap 'trap " " SIGTERM; kill 0; wait' SIGTERM
if [[ $# -eq 0 ]]; then
    exec "/bin/bash"
else
    echo -e "${separator}${separator}${separator}"
    echo -e "${blue}Running command:${noColour}"
    echo -e "${blue}  \"exec "$@"\"${noColour}"
    exec "$@"
fi
wait $!
