#!/bin/bash


################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'Script to be run at start of docker job.'
	echo
	echo 'Syntax: monaistartup.sh [-h|--help] [--compile_monai] [--python_path val]'
	echo
	echo 'options:'
	echo '-h, --help          : Print this help.'
	echo
	echo '--compile_monai     : Compile MONAI code.'
	echo '--python_path       : Extra elements to be prepended to PYTHONPATH'
	echo '                      (multiple elements can be colon separated).'
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
		--python_path)
			python_path=$2
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
: ${compile_monai:=false}

echo
echo
echo "Compile MONAI: ${compile_monai}"
echo "Prepend to PYTHONPATH: ${python_path}"
echo
echo

set -e # exit on error
set -x # print command before doing it

source ~/.bashrc

# Set paths
export PYTHONPATH="${python_path}:$PYTHONPATH"
printf "export PYTHONPATH=%s\n" "$PYTHONPATH" >> ~/.bashrc
echo $PYTHONPATH
exit 1

# Compile MONAI cuda code
if [ "$compile_monai" = true ]; then
	cd ~/Documents/Code/MONAI
	BUILD_MONAI=1 python setup.py develop
fi

sleep infinity
