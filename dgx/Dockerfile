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


################################################################################
# Create DGX installation folder
################################################################################
RUN mkdir /dgx


################################################################################
# Set paths
################################################################################
ENV PATH "/home/${UNAME}/.local/bin:$PATH"
RUN echo "export HOME=/home/${UNAME}" >> /home/${UNAME}/.bashrc && \
    echo "source /home/${UNAME}/.bashrc" >> /home/${UNAME}/.bash_profile && \
    echo "export PATH=/home/${UNAME}/.local/bin:$PATH" >> /home/${UNAME}/.bashrc && \
    echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\]'" >> /home/${UNAME}/.bashrc


################################################################################
# Set up SSHD to be run as non-sudo user
################################################################################
RUN mkdir -p /dgx/.ssh && \
    ssh-keygen -f /dgx/.ssh/id_rsa -N '' -t rsa && \
    ssh-keygen -f /dgx/.ssh/id_dsa -N '' -t dsa

RUN echo "PasswordAuthentication yes" >> /dgx/.ssh/sshd_config && \
    echo "Port 2222" >> /dgx/.ssh/sshd_config && \
    echo "HostKey /dgx/.ssh/id_rsa" >> /dgx/.ssh/sshd_config && \
    echo "HostKey /dgx/.ssh/id_dsa" >> /dgx/.ssh/sshd_config && \
    echo "AuthorizedKeysFile  /dgx/.ssh/authorized_keys" >> /dgx/.ssh/sshd_config && \
    echo "ChallengeResponseAuthentication no" >> /dgx/.ssh/sshd_config && \
    echo "UsePAM no" >> /dgx/.ssh/sshd_config && \
    echo "Subsystem sftp /usr/lib/ssh/sftp-server" >> /dgx/.ssh/sshd_config && \
    echo "PidFile /dgx/.ssh/sshd.pid" >> /dgx/.ssh/sshd_config && \
    echo "PrintMotd no" >> /dgx/.ssh/sshd_config

# merge authorized keys and id_rsa. Latter means you can connect from machine that
# created the container, and the former means you can connect from all the places
# that can connect to that machine.
COPY authorized_keys .
COPY id_rsa.pub .
RUN paste -d "\n" authorized_keys id_rsa.pub > /dgx/.ssh/authorized_keys && \
    rm authorized_keys id_rsa.pub

# Our non-sudo SSHD will run on 2222
EXPOSE 2222


################################################################################
# Custom bashrc additions
################################################################################
ARG GIT_NAME
ARG GIT_EMAIL
RUN git clone https://github.com/rijobro/bash_profile.git /dgx/bash_profile && \
    echo "source /dgx/bash_profile/rich_bashrc.sh" >> /home/${UNAME}/.bashrc && \
    git config --global user.name "${GIT_NAME}" && \
    git config --global user.email "${GIT_EMAIL}"


################################################################################
# Install miniconda and get desired python version
################################################################################
# install miniconda
ARG PY_VER
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /dgx/miniconda && \
    rm -f Miniconda3-latest-Linux-x86_64.sh
# Set default python and pip (not yet installed). Remove local pip (as this comes earlier in PATH)
RUN update-alternatives --install /usr/bin/python python /dgx/miniconda/bin/python 1
RUN update-alternatives --install /usr/bin/pip pip /dgx/miniconda/bin/pip 1
RUN rm /usr/local/bin/pip


################################################################################
# Pip install requirements and set up jupyter notebook
################################################################################
RUN pip install --upgrade pip
# pip install torch
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cu117
# install everything else
RUN pip install --upgrade \
    numpy scipy scikit-image tensorboard tensorboardx isort black black[jupyter] \
    torch-tb-profiler nvitop moviepy ipywidgets tqdm flake8 cucim \
    jupyterthemes nibabel ipython opencv-python-headless wandb \
    scikit-learn ipympl einops seaborn runai cython coverage parameterized pylint
# install cocotools (needed by instavec)
RUN pip install 'git+https://github.com/philferriere/cocoapi.git#egg=pycocotools&subdirectory=PythonAPI'

# Set up jupyter notebook w/ blue theme and set password
ARG JUPY_PWD_HASH
RUN mkdir /dgx/.jupyter && \
    echo "{\"NotebookApp\": {\"password\": \"${JUPY_PWD_HASH}\"}}" >> /dgx/.jupyter/jupyter_notebook_config.json && \
    /dgx/miniconda/bin/jt -t oceans16 -T -N

# cupy is finicky. Get libcuda path with "find / -name 'libcuda.so.*'"
RUN pip install cupy-cuda12x
RUN libcuda=$(find / -name 'libcuda.so.1') && \
    echo libcuda: $libcuda && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$(dirname $libcuda)" >> /home/${UNAME}/.bashrc


################################################################################
# Clear apt cache (smaller image), remove nvidia print files, chmod folders
################################################################################
RUN rm /opt/nvidia/entrypoint.d/*banner.sh /opt/nvidia/entrypoint.d/*copyright.txt /opt/nvidia/entrypoint.d/*license.txt
RUN rm -rf /var/lib/apt/lists/*
RUN chmod -R 777 /dgx


################################################################################
# Set entry point, workdir and user
################################################################################
COPY entrypoint.sh /dgx/entrypoint.sh
ENTRYPOINT ["/dgx/entrypoint.sh"]
WORKDIR /home/${UNAME}
USER ${UNAME}
