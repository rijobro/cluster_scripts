# Base image
ARG DOCKER_BASE
FROM $DOCKER_BASE


################################################################################
# Install misc required packages
################################################################################
RUN apt update && apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y openssh-server nano sudo htop


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
USER root
RUN rm -rf /opt/conda
USER ${UNAME}
ENV PY_VER="3.11"
ENV CONDA_NAME="py${PY_VER}-pt2"
ENV PATH=/home/${UNAME}/miniconda3/bin:${PATH}
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b && \
    rm -f Miniconda3-latest-Linux-x86_64.sh && \
    eval "$(/home/${UNAME}/miniconda3/bin/conda shell.bash hook)" && \
    conda init && \
    conda create -n ${CONDA_NAME} -c conda-forge python=${PY_VER} -y && \
    conda activate ${CONDA_NAME} && \
    pip install --upgrade pip && \
    pip install numpy --pre torch --force-reinstall --index-url https://download.pytorch.org/whl/nightly/cu118 && \
    echo "export LD_LIBRARY_PATH=/home/rbrown/miniconda3/envs/${CONDA_NAME}/lib/python${PY_VER}/site-packages/torch/lib:$LD_LIBRARY_PATH" >> ~/.bashrc


################################################################################
# Pip install requirements and set up jupyter notebook
################################################################################
RUN /home/${UNAME}/miniconda3/envs/${CONDA_NAME}/bin/pip install --upgrade \
    numpy scipy scikit-image tensorboard tensorboardx isort black \
    torch-tb-profiler nvitop moviepy ipywidgets tqdm flake8 cucim cupy-cuda11x \
    jupyterthemes nibabel ipython opencv-python-headless wandb \
    scikit-learn ipympl einops seaborn runai

# Set up jupyter notebook w/ blue theme and set password
ARG JUPY_PWD_HASH
RUN mkdir ~/.jupyter && \
    echo "{\"NotebookApp\": {\"password\": \"${JUPY_PWD_HASH}\"}}" >> ~/.jupyter/jupyter_notebook_config.json && \
    /home/${UNAME}/miniconda3/envs/${CONDA_NAME}/bin/jt -t oceans16 -T -N


################################################################################
# Clear apt install cache (smaller image for docker push)
################################################################################
USER root
RUN rm -rf /var/lib/apt/lists/*
USER ${UNAME}
