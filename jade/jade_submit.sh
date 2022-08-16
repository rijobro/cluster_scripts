#!/bin/bash

set -e # exit on error

# cleanup -- delete temporary file
function cleanup {
    rm -f ${tmp_file}
}
trap cleanup EXIT

#####################################################################################
# Default variables (search this file for "Post-processing defaults" to see others)
#####################################################################################
run_dir=$(pwd)
time_limit="06:00:00"
gpu=1
cpu=10
exp="${JADE_EXPORT}"
out="${HOME}/job_logs/%j.out"
partition=small
nodes=1
conda="${JADE_CONDA}"

#####################################################################################
# Usage
#####################################################################################
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
    echo 'Syntax: submit.sh [-h|--help] [-m|--mail] [-f|--follow]'
    echo '                  [-p|--dir <val>] [-t|--time <val>]'
    echo '                  [-g|--gpu <val>] [-n,--cpu <val>]'
    echo '                  [-J|--name <val>] [-e|--exp <val>]'
    echo '                  [-o|--out <val>] [-p|--partition <val>]'
    echo '                  [-n|--nodes <val>] [-c|--conda] -- <cmd>'
    echo
    echo 'options without args:'
    echo '-h, --help                : Print this help.'
    echo '-m, --mail                : Send status emails. Will read email address from environment'
    echo '                             variable `JADE_EMAIL`. If missing, an error will be raised.'
    echo '-f, --follow              : After submitting, follow job with `tail -f`.'
    echo
    echo '-d, --dir <val>           : Directory to run from. Default: `pwd`.'
    echo '-t, --time <val>          : Time limit. Default: 6h.'
    echo '-g, --gpu <val>           : Num GPUs. Default: 1.'
    echo '-n, --cpu <val>           : Num CPUs. Default: 10.'
    echo '-J, --name <val>          : Job name. Default: `<cmd>` (with `python ` stripped if present).'
    echo '-e, --exp <val>           : Environment variables to export (comma separated).'
    echo '                             Default read from environment variable `JADE_EXPORT`.'
    echo '                             If this environment variable is not present, nothing is exported.'
    echo '-o, --out <val>           : File to save output. Default: `$HOME/job_logs/%j.out`.'
    echo '                             %j is jobid. Folder will be created if necessary.'
    echo '-p, --partition <val>     : Partition to use. Default: small.'
    echo '-n, --nodes <val>         : Number of nodes. Default: 1.'
    echo '-c, --conda <val>         : Conda env to use. Default from `JADE_CONDA`. If empty,'
    echo '                             do not activate any environment.'
    echo
}

#####################################################################################
# Parse input arguments
#####################################################################################

while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    if [ "$key" == "--" ]; then
        if [ "$#" -gt 0 ]; then
            cmd="$*"
        fi
        break
    fi
    case $key in
        -h|--help)
            print_usage
            exit 0
        ;;
        -d|--dir)
            run_dir=$1
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
            use_mail=true
        ;;
        -f|--follow)
            follow=true
        ;;
        -e|--exp)
            exp="${1}"
            shift
        ;;
        -o|--out)
            out=$1
            shift
        ;;
        -p|--partition)
            partition=$1
            shift
        ;;
        -n|--nodes)
            nodes=$1
            shift
        ;;
        -c|--conda)
            conda=$1
            shift
        ;;
        *)
            echo -e "\n\nUnknown argument: $key\n\n"
            print_usage
            exit 1
        ;;
    esac
done

#####################################################################################
# Post-process input arguments
#####################################################################################

# Check cmd is present
if [ -z "${cmd}" ]; then
    echo 'Requires "-- <cmd>"'
    exit 1
fi

# Post-processing defaults.
log_fname=${out/\%j/${job_id}}
# default job name is cmd, with certain parts stripped.
default_job_name=$cmd
default_job_name=$(echo $default_job_name | sed -E -e 's/.*python//')
default_job_name=$(echo $default_job_name | sed -E -e 's/\.py//')
: ${job_name:=$default_job_name}

# If email desired
if [ "$use_mail" = true ]; then
    email_to_use="${JADE_EMAIL}"
    if [ -z "${email_to_use}" ]; then
        echo "Set JADE_EMAIL to use the --mail argument."
        exit 1
    fi
    mail="#SBATCH --mail-type=INVALID_DEPEND,END,FAIL,REQUEUE,STAGE_OUT\n#SBATCH --mail-user=${email_to_use}"
fi

# If environment variables to be exported
if [ "${exp}" != "" ]; then
    exp_cmd="#SBATCH --export=${exp}"
fi

if [ "${conda}" != "" ]; then
    conda_cmd="conda activate ${conda}"
fi

# Make sure output folder exists
mkdir -p $(dirname "$out")

# Print vals
echo
echo "Nodes: ${nodes}"
echo "Time limit: ${time_limit}"
echo "Num GPUs: ${gpu}"
echo "Num CPUs: ${cpu}"
echo "Job name: ${job_name}"
echo "Log file: ${out}"
echo "Partition: ${partition}"
echo "Exports: ${exp}"
echo "Conda env: ${conda}"
echo "Email: ${email_to_use}"
echo
echo "Command: ${cmd}"
echo "Path: ${run_dir}"
echo

#####################################################################################
# Create temporary submit file
#####################################################################################

# Create submit file (temp, deleted by cleanup function)
tmp_file=/tmp/tmp_submit_${RANDOM}.sh
cat > ${tmp_file} << EOL
#!/bin/bash

#SBATCH --nodes=${nodes}
#SBATCH -J ${job_name}
#SBATCH --gres=gpu:${gpu}
#SBATCH --time=${time_limit}
#SBATCH -p ${partition}
#SBATCH --chdir ${run_dir}
#SBATCH -n ${cpu}
${exp_cmd}
$(echo -e ${mail})
#SBATCH --out ${out}

set -e # exit on error

if test -f "${HOME}/.bashrc"; then
    source ${HOME}/.bashrc
fi

${conda_cmd}

echo running ${cmd}

${cmd}
EOL

#####################################################################################
# Submit and print info
#####################################################################################

# Submit
sbatch_out=$(sbatch ${tmp_file})
sbatch_success=$?
# If successful, print job info
if [ "$sbatch_success" -eq 0 ]; then
    job_id=$(echo "$sbatch_out" | awk '{print $NF}')
    # print info about job
    scontrol show job ${job_id}
fi
# Always print sbatch output
echo ${sbatch_out}

# If successful and following desired
if [ "$sbatch_success" -eq 0 ] && [ "$follow" = true ]; then
    echo "Waiting for job to start..."
    log_fname=${out/\%j/${job_id}}
    while [ ! -f $log_fname ]; do
        sleep 1
    done
    tail -f $log_fname
fi
