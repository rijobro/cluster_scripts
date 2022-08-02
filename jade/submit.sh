#!/bin/bash
#SBATCH --nodes=1
#SBATCH -J Torch
#SBATCH --gres=gpu:1
#SBATCH --time=06:00:00
#SBATCH -p small
#SBATCH -n 10

# exit when any command fails
set -e

source ~/.bashrc
conda activate monai

export MONAI_DATA_DIRECTORY=/jmain02/home/J2AD019/exk01/rjb87-exk01/Documents/Data/MONAI
cd /jmain02/home/J2AD019/exk01/rjb87-exk01/Documents/Code/VertSegMultiModel
python VertSeg/spine_localization.py
