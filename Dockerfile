# Get all the variables we'll need
ARG DOCKER_BASE
ARG GROUPS
ARG GIDS
ARG USER_ID
ARG GROUP_ID
ARG UNAME
ARG PW

FROM $DOCKER_BASE

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install required packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y openssh-server nano sudo htop ffmpeg libsm6 libxext6 gdb

# Add user and add to same groups as local
COPY create_user_groups.sh .
RUN addgroup --gid ${GROUP_ID} ${UNAME}
RUN adduser --ingroup ${UNAME} --system --shell /bin/bash --uid ${USER_ID} ${UNAME}
RUN cat create_user_groups.sh
RUN bash ./create_user_groups.sh "$GROUPS" "$GIDS" ${UNAME}
RUN echo "root:$PW" | chpasswd
RUN echo "${UNAME}:$PW" | chpasswd
RUN adduser ${UNAME} sudo

RUN touch /var/run/motd.new

# Change to user
WORKDIR /home/${UNAME}
USER ${UNAME}

################################################################################
# Reinstall conda
################################################################################
# USER root
# RUN conda install anaconda-clean -y
# RUN anaconda-clean -y
# RUN rm -rf /opt/conda
# USER ${UNAME}
# RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# RUN bash ./Miniconda3-latest-Linux-x86_64.sh -p /home/${UNAME}/.conda -b
# RUN rm Miniconda3-latest-Linux-x86_64.sh
################################################################################

# Set paths
ENV PATH "/home/${UNAME}/.conda/bin:/home/${UNAME}/.local/bin:$PATH"
RUN echo "export PATH=/home/${UNAME}/.conda/bin:/home/${UNAME}/.local/bin:$PATH" >> /home/${UNAME}/.bashrc
RUN echo "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> /home/${UNAME}/.bashrc
RUN echo "source /home/${UNAME}/.bashrc" >> /home/${UNAME}/.bash_profile
# Misc bash
RUN echo "export TERM=xterm" >> ~/.bashrc
RUN echo "export DEBUGPY_EXCEPTION_FILTER_USER_UNHANDLED=1" >> ~/.bashrc

# Install requirements
RUN python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements.txt && 	python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt && 	python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/docs/requirements.txt &&         python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/tutorials/master/requirements.txt

# Set up SSHD to be run as non-sudo user
RUN mkdir -p /home/${UNAME}/.ssh && 	ssh-keygen -f /home/${UNAME}/.ssh/id_rsa -N '' -t rsa && 	ssh-keygen -f /home/${UNAME}/.ssh/id_dsa -N '' -t dsa


RUN echo "PasswordAuthentication yes" >> /home/${UNAME}/.ssh/sshd_config && 	echo "Port 2222" >> /home/${UNAME}/.ssh/sshd_config && 	echo "HostKey /home/${UNAME}/.ssh/id_rsa" >> /home/${UNAME}/.ssh/sshd_config && 	echo "HostKey /home/${UNAME}/.ssh/id_dsa" >> /home/${UNAME}/.ssh/sshd_config && 	echo "AuthorizedKeysFile  .ssh/authorized_keys" >> /home/${UNAME}/.ssh/sshd_config && 	echo "ChallengeResponseAuthentication no" >> /home/${UNAME}/.ssh/sshd_config && 	echo "UsePAM no" >> /home/${UNAME}/.ssh/sshd_config && 	echo "Subsystem   sftp    /usr/lib/ssh/sftp-server" >> /home/${UNAME}/.ssh/sshd_config && 	echo "PidFile /home/${UNAME}/.ssh/sshd.pid" >> /home/${UNAME}/.ssh/sshd_config && 	echo "PrintMotd no" >> /home/${UNAME}/.ssh/sshd_config

# merge authorized keys and id_rsa. Latter means you can connect from machine that
# created the container, and the former means you can connect from all the places
# that can connect to that machine.
COPY authorized_keys .
COPY id_rsa.pub .
RUN paste -d "\n" authorized_keys id_rsa.pub > /home/${UNAME}/.ssh/authorized_keys
RUN rm authorized_keys id_rsa.pub

# Set up jupyter notebook
RUN python -m pip install --user jupyterthemes
RUN jt -t oceans16 -T -N # Blue theme
#RUN jt -t monokai -f fira -fs 13 -nf ptsans -nfs 11 -N -kl -cursw 5 -cursc r -cellw 95% -T # Green theme

# Pip install anything else
RUN python -m pip install --user ipywidgets torchsummary scikit-learn nbdime jupyterlab
RUN nbdime config-git --enable --global

################################################################################
# NVIDIA OpenCV
################################################################################
# Dependencies
#USER root
#RUN apt install -y libavcodec-dev libavformat-dev libswscale-dev #	libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev # 	libpng-dev libjpeg-dev libopenexr-dev libtiff-dev libwebp-dev # 	libpython2-dev python-numpy libgtk2.0-dev
# USER ${UNAME}

# RUN mkdir opencv
# RUN cd opencv && git clone https://github.com/opencv/opencv.git Source
# RUN cd opencv && git clone https://github.com/opencv/opencv_contrib.git
# RUN mkdir opencv/Build && cd opencv/Build

# RUN cd opencv/Build && cmake ../Source -DCMAKE_INSTALL_PREFIX:PATH=/home/${UNAME}/opencv/Install # 	-DWITH_CUDA:BOOL=ON -DOPENCV_EXTRA_MODULES_PATH:PATH=/home/${UNAME}/opencv/opencv_contrib/modules # 	-DPYTHON3_LIBRARIES:FILEPATH=/home/${UNAME}/.conda/lib/libpython3.8.a # 	-DPYTHON3_INCLUDE_DIRS:PATH=/home/${UNAME}/.conda/include/python3.8 # 	-DPYTHON3_EXECUTABLE:FILEPATH=/home/${UNAME}/.conda/bin/python3 # 	-DPYTHON3_NUMPY_INCLUDE_DIRS:PATH=/home/${UNAME}/.conda/lib/python3.8/site-packages/numpy/core/include # 	-DPYTHON2_LIBRARIES:FILEPATH=/usr/lib/x86_64-linux-gnu/libpython2.7.so # 	-DPYTHON2_INCLUDE_DIRS:PATH=/usr/include/python2.7 # 	-DPYTHON2_EXECUTABLE:FILEPATH=/usr/bin/python2.7 # 	-DPYTHON_DEFAULT_EXECUTABLE:FILEPATH=/home/${UNAME}/.conda/bin/python3 # 	-DGLIBCXX_USE_CXX11_ABI=0
# RUN cd opencv/Build && make -j10 install
RUN pip install opencv-python
################################################################################

################################################################################
# VNC
################################################################################
COPY xstartup .
RUN mkdir -p /home/${UNAME}/.vnc
RUN mv xstartup /home/${UNAME}/.vnc/xstartup
USER root
RUN apt install -y xfce4 xfce4-goodies tigervnc-standalone-server
RUN chmod +x /home/${UNAME}/.vnc/xstartup
USER ${UNAME}
################################################################################

################################################################################
# Qt creator
################################################################################
RUN mkdir Qt && mkdir Qt/Build
RUN cd Qt && git clone https://code.qt.io/qt-creator/qt-creator.git Source
RUN qmake --version
#RUN wget https://download.qt.io/official_releases/qt/5.12/5.12.10/qt-opensource-linux-x64-5.12.10.run
#RUN chmod +x ./qt-opensource-linux-x64-5.12.10.run
################################################################################

EXPOSE 2222

CMD /usr/sbin/sshd -D -f /home/${UNAME}/.ssh/sshd_config -E /home/${UNAME}/.ssh/sshd.log

