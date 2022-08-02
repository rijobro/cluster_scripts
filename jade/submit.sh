#!/bin/bash

set -e # exit on error

################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'SLURM submit script for JADE.'
	echo
	echo 'Syntax: submit.sh [-h|--help] [-s|--script <val>] [-p|--path <val>]'
	echo '                  [-t|--time <val>] [-g|--gpu <val>] [-n,--cpu <val>]'
    echo '                  [-J|--name <val>] [-m|--mail <val>]'
	echo
    echo 'required:'
    echo '-s, --script              : Script to run.'
    echo
	echo 'options:'
	echo '-h, --help                : Print this help.'
	echo
    echo '-p, --path                : Path to run script from. Default: pwd.'
    echo '-t, --time                : Time limit. Default: 6h.'
    echo '-g, --gpu                 : Num GPUs. Default: 1.'
    echo '-n, --cpu                 : Num CPUs. Default: 10.'
    echo '-J, --name                : Job name. Default: `script_name`.'
    echo '-m, --mail                : Email address for jobs. Default: rich.brown@kcl.ac.uk.'
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
		-p|--path)
            script_path=$2
            shift
		;;
        -s|--script)
            script_name=$2
            shift
		;;
        -t|--time)
            time_limit=$2
            shift
		;;
        -g|--gpu)
            gpu=$2
            shift
		;;
        -n|--cpu)
            cpu=$2
            shift
		;;
        -J|--name)
            job_name=$2
            shift
		;;
        -m|--mail)
            mail=$2
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

# Check required arguments
if [ "$script_name" = "" ]; then
    echo -e "\n\nMissing argument: script_name (-s|--script).\n\n"
    exit 1
fi

# Default variables
: ${script_path:=$(pwd)}
: ${time_limit:="06:00:00"}
: ${gpu:=1}
: ${cpu:=10}
: ${job_name:=${script_name}}
: ${mail:="rich.brown@kcl.ac.uk"}

# Email notification
if [ -n "$mail" ]; then
    mail_options="#SBATCH --mail-type=ALL\n#SBATCH --mail-user=${mail}"
fi

# Print vals
echo
echo
echo "Time limit: ${time_limit}"
echo "Num GPUs: ${gpu}"
echo "Num CPUs: ${cpu}"
echo "Job name: ${job_name}"
echo
echo "Script: ${script_name}"
echo "Path: ${script_path}"
echo

# Create submit file (temp)
tmp_file=/tmp/rb_submit_${RANDOM}.sh
cat > ${tmp_file} << EOL
#!/bin/bash

#SBATCH --nodes=1
#SBATCH -J ${job_name}
#SBATCH --gres=gpu:${gpu}
#SBATCH --time=${time_limit}
#SBATCH -p small
#SBATCH -n ${cpu}
$(echo -e ${mail_options})

source ~/.bashrc
conda activate monai

export MONAI_DATA_DIRECTORY=/jmain02/home/J2AD019/exk01/rjb87-exk01/Documents/Data/MONAI

cd ${script_path}
python ${script_name}
EOL

# Submit and remove file
sbatch ${tmp_file}
rm ${tmp_file}