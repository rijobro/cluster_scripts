#!/bin/bash


################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'Script to be run at start of docker job.'
	echo
	echo 'Syntax: runai_startup.sh [-h|--help] [--jupy] [--ssh_server]'
	echo '                         [--compile_monai] [--python_path val]'
	echo '                         [-e|--env name=val]'
	echo
	echo 'options:'
	echo '-h, --help                : Print this help.'
	echo
	echo '--compile_monai           : Compile MONAI code.'
	echo '--jupy                    : Start a jupyter notebook'
	echo '--ssh_server              : Start an SSH server.'
	echo
	echo '-e, --env <name=val>      : Environmental variable, given as "NAME=VAL".'
	echo '                            Can be used multiple times.'
	echo '-a, --alias <name=val>    : Alias, given as "NAME=VAL".'
	echo '                            Can be used multiple times.'
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
		--compile_monai)
			compile_monai=true
		;;
		--jupy)
			jupy=true
		;;
		--ssh_server)
			ssh_server=true
		;;
		-e|--env)
			if [[ -z "${envs}" ]]; then envs=(); fi
			envs+=($2)
			shift
		;;
		-a|--alias)
			if [[ -z "${aliases}" ]]; then aliases=(); fi
			aliases+=("$2")
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
: ${jupy:=false}
: ${ssh_server:=false}
: ${compile_monai:=false}

echo
echo
echo "Start jupyter session: ${jupy}"
echo "SSH server: ${ssh_server}"
echo "Compile MONAI: ${compile_monai}"
echo
echo "Environmental variables:"
for env in "${envs[@]}"; do
	echo -e "\t${env}"
done
echo "Aliases:"
for alias in "${aliases[@]}"; do
	echo -e "\t${alias}"
done
echo

set -e # exit on error
set -x # print command before doing it

export HOME=/home/$(whoami)
source ~/.bashrc

# Add any environmental variables
for env in "${envs[@]}"; do
	export ${env}
	printf "export ${env}\n" >> ~/.bashrc
done

# Add any aliases
for alias in "${aliases[@]}"; do
	alias "${alias}"
	printf "alias ${alias}\n" >> ~/.bashrc
done

# SSH server
if [ "$ssh_server" = true ]; then
	nohup /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/.ssh/sshd.log &
fi

# Jupyter notebook
if [ "$jupy" = true ]; then
	nohup jupyter notebook --ip 0.0.0.0 --no-browser --notebook-dir="~" > ~/.jupyter_notebook.log 2>&1 &
fi

# Compile MONAI cuda code
if [ "$compile_monai" = true ]; then
	cd ~/Documents/Code/MONAI
	BUILD_MONAI=1 python setup.py develop
fi
