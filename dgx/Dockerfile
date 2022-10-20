# Base image
ARG DOCKER_BASE
FROM $DOCKER_BASE


################################################################################
# Install misc required packages
################################################################################
RUN apt update && apt upgrade -y && apt install -y openssh-server nano sudo htop


################################################################################
# Create user, assign to groups, set password, switch to new user
################################################################################
ARG UNAME
ARG PWD_HASH
ARG USER_ID
ARG GROUP_ID
ARG GROUPS
ARG GIDS
RUN addgroup --gid ${GROUP_ID} ${UNAME}
RUN adduser --ingroup ${UNAME} --system --shell /bin/bash --uid ${USER_ID} ${UNAME}
RUN _groups=($GROUPS) && _gids=($GIDS) && \
    for ((i=0; i<${#_groups[@]}; ++i)); do \
        group=${_groups[$i]} && \
        gid=${_gids[$i]} && \
        addgroup --gid $gid $group && \
        usermod -a -G $group $UNAME; \
    done
RUN printf "root:%s" "$PWD_HASH" | chpasswd -e
RUN printf "${UNAME}:%s" "$PWD_HASH" | chpasswd -e
RUN adduser ${UNAME} sudo

RUN touch /var/run/motd.new

# Change to user
WORKDIR /home/${UNAME}
USER ${UNAME}


################################################################################
# Set paths
################################################################################
RUN echo "export HOME=/home/${UNAME}" >> ~/.bashrc
RUN echo "source /home/${UNAME}/.bashrc" >> ~/.bash_profile
ENV PATH "/home/${UNAME}/.local/bin:$PATH"
RUN echo "export PATH=/home/${UNAME}/.local/bin:$PATH" >> ~/.bashrc
# Colourful bash
RUN echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\]'" >> ~/.bashrc


################################################################################
# Jupyter password
################################################################################
ARG JUPY_PWD_HASH
RUN jupyter notebook --generate-config
RUN echo "c.NotebookApp.password = '${JUPY_PWD_HASH}'" >> ~/.jupyter/jupyter_notebook_config.py


################################################################################
# Custom bashrc additions
################################################################################
RUN git clone https://github.com/rijobro/bash_profile.git
RUN echo "source bash_profile/rich_bashrc.sh" >> ~/.bashrc


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
RUN paste -d "\n" authorized_keys id_rsa.pub > ~/.ssh/authorized_keys
RUN rm authorized_keys id_rsa.pub

# Our non-sudo SSHD will run on 2222
EXPOSE 2222


################################################################################
# Pip install requirements and set up jupyter notebook
################################################################################
USER root
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements.txt
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/docs/requirements.txt
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/tutorials/master/requirements.txt
RUN python -m pip install --upgrade ipywidgets torchsummary scikit-learn jupyterthemes
RUN python -m pip install --upgrade tensorboardx
RUN pip uninstall opencv-python opencv-contrib-python opencv-contrib-python-headless && pip install opencv-contrib-python==4.5.5.62
# moviepy
RUN DEBIAN_FRONTEND=noninteractive apt install ffmpeg -y
RUN git clone https://github.com/Zulko/moviepy.git && cd moviepy && python setup.py install
RUN python -m pip install --upgrade nvitop

USER ${UNAME}

# Set up jupyter notebook, w/ blue theme
RUN jt -t oceans16 -T -N


################################################################################
# Clear apt install cache (smaller image for docker push)
################################################################################
USER root
RUN rm -rf /var/lib/apt/lists/*
USER ${UNAME}
