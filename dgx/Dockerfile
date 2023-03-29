# Base image
ARG DOCKER_BASE
FROM $DOCKER_BASE


################################################################################
# Install misc required packages
################################################################################
RUN apt update && apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y openssh-server nano sudo htop git


################################################################################
# Create user, assign to groups, set password, switch to new user
################################################################################
ARG UNAME
ARG PWD_HASH
ARG USER_ID
ARG GROUP_ID
ARG GROUPS
ARG GIDS
RUN addgroup --gid ${GROUP_ID} ${UNAME} && \
    adduser --ingroup ${UNAME} --system --shell /bin/bash --uid ${USER_ID} ${UNAME} && \
    _groups=($GROUPS) && _gids=($GIDS) && \
    for ((i=0; i<${#_groups[@]}; ++i)); do \
        group=${_groups[$i]} && \
        gid=${_gids[$i]} && \
        addgroup --gid $gid $group && \
        usermod -a -G $group $UNAME; \
    done && \
    printf "root:%s" "$PWD_HASH" | chpasswd -e && \
    printf "${UNAME}:%s" "$PWD_HASH" | chpasswd -e && \
    adduser ${UNAME} sudo && \
    touch /var/run/motd.new

# Change to user
WORKDIR /home/${UNAME}
USER ${UNAME}


################################################################################
# Set paths
################################################################################
ENV PATH "/home/${UNAME}/.local/bin:$PATH"
RUN echo "export HOME=/home/${UNAME}" >> ~/.bashrc && \
    echo "source /home/${UNAME}/.bashrc" >> ~/.bash_profile && \
    echo "export PATH=/home/${UNAME}/.local/bin:$PATH" >> ~/.bashrc && \
    echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\]'" >> ~/.bashrc


################################################################################
# Set up SSHD to be run as non-sudo user
################################################################################
RUN mkdir -p ~/.ssh && \
    ssh-keygen -f ~/.ssh/id_rsa -N '' -t rsa && \
    ssh-keygen -f ~/.ssh/id_dsa -N '' -t dsa

RUN echo "PasswordAuthentication yes" >> ~/.ssh/sshd_config && \
    echo "Port 2222" >> ~/.ssh/sshd_config && \
    echo "HostKey ~/.ssh/id_rsa" >> ~/.ssh/sshd_config && \
    echo "HostKey ~/.ssh/id_dsa" >> ~/.ssh/sshd_config && \
    echo "AuthorizedKeysFile  ~/.ssh/authorized_keys" >> ~/.ssh/sshd_config && \
    echo "ChallengeResponseAuthentication no" >> ~/.ssh/sshd_config && \
    echo "UsePAM no" >> ~/.ssh/sshd_config && \
    echo "Subsystem sftp /usr/lib/ssh/sftp-server" >> ~/.ssh/sshd_config && \
    echo "PidFile ~/.ssh/sshd.pid" >> ~/.ssh/sshd_config && \
    echo "PrintMotd no" >> ~/.ssh/sshd_config

# merge authorized keys and id_rsa. Latter means you can connect from machine that
# created the container, and the former means you can connect from all the places
# that can connect to that machine.
COPY authorized_keys .
COPY id_rsa.pub .
RUN paste -d "\n" authorized_keys id_rsa.pub > ~/.ssh/authorized_keys && \
    rm authorized_keys id_rsa.pub

# Our non-sudo SSHD will run on 2222
EXPOSE 2222


################################################################################
# Custom bashrc additions
################################################################################
ARG GIT_NAME
ARG GIT_EMAIL
RUN git clone https://github.com/rijobro/bash_profile.git && \
    echo "source /home/${UNAME}/bash_profile/rich_bashrc.sh" >> ~/.bashrc && \
    git config --global user.name "${GIT_NAME}" && \
    git config --global user.email "${GIT_EMAIL}"


################################################################################
# Get python version and install numpy/torch
################################################################################
ENV PY_VER="3.10"
ENV CONDA_NAME="py"
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b && \
    rm -f Miniconda3-latest-Linux-x86_64.sh && \
    /home/${UNAME}/miniconda3/bin/conda init
ENV PY_EXE=/home/${UNAME}/miniconda3/envs/${CONDA_NAME}/bin/python
# pytorch2.x
RUN eval "$(/home/${UNAME}/miniconda3/bin/conda shell.bash hook)" && \
    conda create -n ${CONDA_NAME} -c conda-forge python=${PY_VER} -y && \
    ${PY_EXE} -m pip install --upgrade pip && \
    ${PY_EXE} -m pip install numpy --pre torchvision --index-url https://download.pytorch.org/whl/nightly/cu117 && \
    echo "export LD_LIBRARY_PATH=/home/${UNAME}/miniconda3/envs/${CONDA_NAME}/lib/python${PY_VER}/site-packages/torch/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
# installing torchvision installs torch for us. Seems to cause an error if asked to install both torch and torchvision.


################################################################################
# Pip install requirements and set up jupyter notebook
################################################################################
RUN ${PY_EXE} -m pip install --upgrade \
    numpy scipy scikit-image tensorboard tensorboardx isort black black[jupyter] \
    torch-tb-profiler nvitop moviepy ipywidgets tqdm flake8 cucim \
    jupyterthemes nibabel ipython opencv-python-headless wandb \
    scikit-learn ipympl einops seaborn runai cython coverage parameterized pylint
RUN ${PY_EXE} -m pip install 'git+https://github.com/philferriere/cocoapi.git#egg=pycocotools&subdirectory=PythonAPI'

# Set up jupyter notebook w/ blue theme and set password
ARG JUPY_PWD_HASH
RUN mkdir ~/.jupyter && \
    echo "{\"NotebookApp\": {\"password\": \"${JUPY_PWD_HASH}\"}}" >> ~/.jupyter/jupyter_notebook_config.json && \
    /home/${UNAME}/miniconda3/envs/${CONDA_NAME}/bin/jt -t oceans16 -T -N

# cupy is finicky. Get libcuda path with "find / -name 'libcuda.so.*'"
RUN ${PY_EXE} -m pip install cupy-cuda12x
USER root
RUN libcuda=$(find / -name 'libcuda.so.1') && \
    echo libcuda: $libcuda && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$(dirname $libcuda)" >> /home/${UNAME}/.bashrc
USER ${UNAME}


################################################################################
# Test
################################################################################
COPY test_image.sh .
RUN bash test_image.sh && rm test_image.sh


################################################################################
# Clear apt install cache (smaller image for docker push)
################################################################################
USER root

RUN rm -rf /var/lib/apt/lists/*
USER ${UNAME}
