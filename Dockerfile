# Base image
ARG DOCKER_BASE
FROM $DOCKER_BASE


################################################################################
# Install misc required packages
################################################################################
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y \
    openssh-server nano sudo htop ffmpeg libsm6 libxext6 gdb valgrind


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
RUN mkdir ~/Documents ~/Documents/Code


################################################################################
# Set paths
################################################################################
ENV PATH "/home/${UNAME}/.local/bin:$PATH"
RUN echo "export PATH=/home/${UNAME}/.local/bin:$PATH" >> ~/.bashrc
RUN echo "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> ~/.bashrc
RUN echo "source /home/${UNAME}/.bashrc" >> ~/.bash_profile
# Misc bash
RUN echo "export TERM=xterm" >> ~/.bashrc
RUN echo "export DEBUGPY_EXCEPTION_FILTER_USER_UNHANDLED=1" >> ~/.bashrc
# Colourful bash
RUN echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\]'" >> ~/.bashrc


################################################################################
# Github credentials
################################################################################
ARG GITHUB_NAME
ARG GITHUB_EMAIL
RUN git config --global user.name ${GITHUB_NAME}
RUN git config --global user.email ${GITHUB_EMAIL}


################################################################################
# Jupyter password
################################################################################
ARG JUPY_PWD_HASH
RUN jupyter notebook --generate-config
RUN echo "c.NotebookApp.password = '${JUPY_PWD_HASH}'" >> ~/.jupyter/jupyter_notebook_config.py


################################################################################
# Custom bashrc additions
################################################################################
RUN cd ~/Documents/Code/ && git clone https://github.com/rijobro/bash_profile.git
RUN echo "source /home/${UNAME}/Documents/Code/bash_profile/rich_bashrc.sh" >> ~/.bashrc


################################################################################
# Pulseaudio (send audio back to local terminal)
################################################################################
USER root
RUN apt install -y pulseaudio espeak
USER ${UNAME}
RUN echo 'export PULSE_SERVER="tcp:localhost:24713"' >> ~/.bashrc


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

EXPOSE 2222


################################################################################
# Pip install requirements and set up jupyter notebook
################################################################################
RUN python -m pip install --upgrade --user -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements.txt && \
	python -m pip install --upgrade --user -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt && \
    python -m pip install --upgrade --user -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/docs/requirements.txt &&  \
    python -m pip install --upgrade --user -r https://raw.githubusercontent.com/Project-MONAI/tutorials/master/requirements.txt && \
    python -m pip install --upgrade --user ipywidgets torchsummary scikit-learn jupyterthemes
# Set up jupyter notebook, w/ blue or green theme
RUN jt -t oceans16 -T -N
#RUN jt -t monokai -f fira -fs 13 -nf ptsans -nfs 11 -N -kl -cursw 5 -cursc r -cellw 95% -T


################################################################################
# NVIDIA OpenCV
################################################################################
# Dependencies
USER root
RUN apt install -y libavcodec-dev libavformat-dev libswscale-dev \
    libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev \
    libpng-dev libjpeg-dev libopenexr-dev libtiff-dev libwebp-dev \
    libpython2-dev python-numpy libgtk2.0-dev
USER ${UNAME}

RUN mkdir ~/Documents/Code/opencv
RUN cd ~/Documents/Code/opencv && \
    git clone https://github.com/opencv/opencv.git Source && \
    git clone https://github.com/opencv/opencv_contrib.git

COPY build_opencv.sh /home/${UNAME}/Documents/Code/opencv
RUN mkdir ~/Documents/Code/opencv/Build && cd ~/Documents/Code/opencv/Build && sh ../build_opencv.sh
# RUN pip install opencv-python


################################################################################
# VNC
################################################################################
RUN mkdir -p ~/.vnc
COPY xstartup /home/${UNAME}/.vnc
USER root
RUN apt install -y xfce4 xfce4-goodies tigervnc-standalone-server
RUN chmod +x /home/${UNAME}/.vnc/xstartup
USER ${UNAME}
# Run it to set the password (then kill it straight away)
ARG VNC_PWD
RUN printf "${VNC_PWD}\n${VNC_PWD}\n" | vncserver && vncserver -kill :1


################################################################################
# Qt creator
################################################################################
USER root
RUN sudo apt install -y libxcb-xinerama0
USER ${UNAME}
RUN mkdir ~/Documents/Code/Qt && cd ~/Documents/Code/Qt && wget https://code.qt.io/cgit/qbs/qbs.git/plain/scripts/install-qt.sh
RUN cd ~/Documents/Code/Qt && chmod +x install-qt.sh && ./install-qt.sh --version 4.14.2 -d ~/Documents/Code/Qt/Install qtcreator
RUN echo "export PATH=$PATH:~/Documents/Code/Qt/Install/Tools/QtCreator/bin" >> ~/.bashrc



################################################################################
# Libtorch
################################################################################
RUN wget -O libtorch.zip https://download.pytorch.org/libtorch/cu111/libtorch-cxx11-abi-shared-with-deps-1.8.1%2Bcu111.zip
RUN unzip libtorch.zip -d ~/Documents/Code
RUN rm libtorch.zip

################################################################################
# Clear apt install cache
################################################################################
USER root
RUN rm -rf /var/lib/apt/lists/*
USER ${UNAME}
################################################################################

CMD /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/.ssh/sshd.log
