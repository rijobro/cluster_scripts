#!/bin/bash

# crash on error
set -e

# activate conda env
source ~/.bashrc &>2 /dev/null
conda activate py

echo -e "\n\n"

# check python path
res=$(which python)
echo python path: $res
echo $res | grep -q "miniconda3/envs/py/bin/python"
if [ $? != 0 ]; then
   echo "\n\nwrong python path.\n\n"
   exit 1
fi

# check python version
res=$(python --version)
echo python version: $res
if [[ $res =~ '^Python 3.10.**$' ]]; then
   echo -e "\n\nwrong python version.\n\n"
   exit 1
fi

# check torch
res=$(python -c "import torch; print(torch.__version__)")
echo pytorch version: $res
if [[ $res =~ '^2.1.0.dev**+cu117$' ]]; then
   echo -e "\n\nproblem with pytorch\n\n"
   exit 1
fi

# check cupy
res=$(python -c "import cupy")
if [ $? != 0 ]; then
   echo -e "\n\nproblem with cupy\n\n"
   exit 1
fi

# check cucim
res=$(python -c "from cucim.core.operations.morphology import distance_transform_edt")
if [ $? != 0 ]; then
   echo -e "\n\nproblem with cucim\n\n"
   exit 1
fi

echo -e "\n\n"
