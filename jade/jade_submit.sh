#!/bin/bash

set -e # exit on error

# cleanup -- delete temporary file
function cleanup {
	rm -f ${tmp_file}
}
trap cleanup EXIT

################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'SLURM submit script for JADE. Anything after the double hyphen will be executed as command in job.'
    echo '  This could be "python script.py", for example.'
    echo
    echo 'Brief syntax:'
    echo 'submit.sh [OPTIONS(0)...] [ : [OPTIONS(N)...]] -- <cmd>'
    echo
	echo 'Full syntax:'
	echo 'Syntax: submit.sh [-h|--help] [-p|--path <val>]'
	echo '                  [-t|--time <val>] [-g|--gpu <val>] [-n,--cpu <val>]'
    echo '                  [-J|--name <val>] [-m|--mail <val>] [-e|--env <val>]'
    echo '                  [-o|--out <val>] -- <cmd>'
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
    echo '-e, --env                 : Environment variables to export (comma separated).'
    echo '                             Default: MONAI_DATA_DIRECTORY.'
    echo '-o, --out                 : File to save output. Default: $HOME/job_logs/%j.out.'
    echo '                             %j is jobid. Folder will be created if necessary.'
	echo
}

################################################################################
# parse input arguments
################################################################################

while [[ $# -gt 0 ]]
do
	key="$1"
    shift
    if [ "$key" == "--" ]; then
        if [ "$#" -gt 0 ]; then
            cmd="'$*'"
        fi
        break
    fi
	case $key in
		-h|--help)
			print_usage
			exit 0
		;;
		-p|--path)
            script_path=$1
            shift
		;;
        -t|--time)
            time_limit=$1
            shift
		;;
        -g|--gpu)
            gpu=$1
            shift
		;;
        -n|--cpu)
            cpu=$1
            shift
		;;
        -J|--name)
            job_name=$1
            shift
		;;
        -m|--mail)
            mail="#SBATCH --mail-type=INVALID_DEPEND,END,FAIL,REQUEUE,STAGE_OUT\n#SBATCH --mail-user=${1}"
            shift
		;;
        -e|--env)
            env="#SBATCH --export=${1}"
            shift
		;;
        -o|--out)
            out=$1
            shift
		;;
		*)
			echo -e "\n\nUnknown argument: $key\n\n"
			print_usage
			exit 1
		;;
	esac
done

# Check cmd is present
if [ -z "${cmd}" ]; then
    echo 'Requires "-- <cmd>"'
    exit 1
fi

# Default variables
: ${script_path:=$(pwd)}
: ${time_limit:="06:00:00"}
: ${gpu:=1}
: ${cpu:=10}
: ${job_name:=${cmd}}
default_email="rich.brown@kcl.ac.uk"
default_env="MONAI_DATA_DIRECTORY"
: ${mail:="#SBATCH --mail-type=ALL\n#SBATCH --mail-user=${default_email}"}
: ${env:="#SBATCH --export=${default_env}"}
: ${out:="${HOME}/job_logs/%j.out"}

# Make sure output folder exists
mkdir -p $(dirname "$out")

# Print vals
echo
echo
echo "Time limit: ${time_limit}"
echo "Num GPUs: ${gpu}"
echo "Num CPUs: ${cpu}"
echo "Job name: ${job_name}"
echo "Log file: ${out}"
echo
echo "Command: ${cmd}"
echo "Path: ${script_path}"
echo

# Create submit file (temp, deleted by cleanup function)
tmp_file=/tmp/rb_submit_${RANDOM}.sh
cat > ${tmp_file} << EOL
#!/bin/bash

#SBATCH --nodes=1
#SBATCH -J ${job_name}
#SBATCH --gres=gpu:${gpu}
#SBATCH --time=${time_limit}
#SBATCH -p small
#SBATCH --chdir ${script_path}
#SBATCH -n ${cpu}
${env}
$(echo -e ${mail})
#SBATCH --out ${out}

source ~/.bashrc
conda activate monai

python ${script_name}
EOL

# Submit
sbatch_out=$(sbatch ${tmp_file})
# If successful, print job info
if [ "$?" -eq 0 ]; then
    job_id=$(echo "$sbatch_out" | awk '{print $NF}')
    # print info about job
    scontrol show job ${job_id}
fi
# Always print sbatch output
echo ${sbatch_out}
