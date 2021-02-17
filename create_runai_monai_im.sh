#!/bin/bash

set -e # stop on error

# Some variables
base_image=nvcr.io/nvidia/pytorch:20.12-py3
# base_image=nvidia/cuda:11.1-runtime-ubuntu18.04
# base_image=projectmonai/monai:latest
im_name=rb-monai
docker_uname=rijobro

# user password
password="monai"

# cleanup
function cleanup {
	rm -f create_user_groups.sh MonaiDockerfile id_rsa.pub authorized_keys
}
trap cleanup EXIT

# Move to current directory
cd "$(dirname "$0")"

# This file is used to loop over all groups that the local user is part of,
# create those groups in the container and add the user to those groups.
cat - <<EOF > create_user_groups.sh
_groups=(\$1)
_gids=(\$2)
uname=\$3
n=\${#_groups[@]}
for ((i=0;i<\${#_groups[@]};++i)); do
	group=\${_groups[\$i]}
	gid=\${_gids[\$i]}
	addgroup --gid \$gid \$group
        usermod -a -G \$group \$uname
done
EOF

# Copy in the authorized and  public keys so that it can be added to the authorized keys in the container
cat ~/.ssh/authorized_keys > authorized_keys
cp ~/.ssh/id_rsa.pub .

cat - <<EOF > MonaiDockerfile
FROM $base_image

# Install required packages
RUN apt update && apt upgrade -y && apt install -y openssh-server nano sudo htop && rm -rf /var/lib/apt/lists/*

# Get all the variables we'll need
ARG GROUPS
ARG GIDS
ARG USER_ID
ARG GROUP_ID
ARG UNAME
ARG PW

# Delete conda
RUN conda install anaconda-clean -y
RUN anaconda-clean -y
RUN rm -rf /opt/conda

# Add user and add to same groups as local
COPY create_user_groups.sh .
RUN addgroup --gid \${GROUP_ID} \${UNAME}
RUN adduser --ingroup \${UNAME} --system --shell /bin/bash --uid \${USER_ID} \${UNAME}
RUN cat create_user_groups.sh
RUN bash ./create_user_groups.sh "\$GROUPS" "\$GIDS" \${UNAME}
RUN echo "root:$password" | chpasswd
RUN echo "\${UNAME}:$password" | chpasswd
RUN adduser \${UNAME} sudo

RUN touch /var/run/motd.new

# Change to user
WORKDIR /home/\${UNAME}
USER \${UNAME}

# Reinstall conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash ./Miniconda3-latest-Linux-x86_64.sh -p /home/\${UNAME}/.conda -b
RUN rm Miniconda3-latest-Linux-x86_64.sh

# Set paths
ENV PATH "/home/\${UNAME}/.conda/bin:/home/\${UNAME}/.local/bin:\$PATH"
RUN echo "export PATH=/home/\${UNAME}/.conda/bin:/home/\${UNAME}/.local/bin:\$PATH" >> /home/\${UNAME}/.bashrc
RUN echo "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}" >> /home/\${UNAME}/.bashrc
RUN echo "source /home/\${UNAME}/.bashrc" >> /home/\${UNAME}/.bash_profile

# Install requirements
RUN python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements.txt && \
	python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt && \
	python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/docs/requirements.txt

# Set up SSHD to be run as non-sudo user
RUN mkdir -p /home/\${UNAME}/.ssh && \
	ssh-keygen -f /home/\${UNAME}/.ssh/id_rsa -N '' -t rsa && \
	ssh-keygen -f /home/\${UNAME}/.ssh/id_dsa -N '' -t dsa


RUN echo "PasswordAuthentication yes" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "Port 2222" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "HostKey /home/\${UNAME}/.ssh/id_rsa" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "HostKey /home/\${UNAME}/.ssh/id_dsa" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "AuthorizedKeysFile  .ssh/authorized_keys" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "ChallengeResponseAuthentication no" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "UsePAM no" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "Subsystem   sftp    /usr/lib/ssh/sftp-server" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "PidFile /home/\${UNAME}/.ssh/sshd.pid" >> /home/\${UNAME}/.ssh/sshd_config && \
	echo "PrintMotd no" >> /home/\${UNAME}/.ssh/sshd_config

# merge authorized keys and id_rsa. Latter means you can connect from machine that
# created the container, and the former means you can connect from all the places
# that can connect to that machine.
COPY authorized_keys .
COPY id_rsa.pub .
RUN paste -d "\n" authorized_keys id_rsa.pub > /home/\${UNAME}/.ssh/authorized_keys
RUN rm authorized_keys id_rsa.pub

# Set up jupyter notebook
RUN python -m pip install --user jupyterthemes
RUN jt -t oceans16 -T -N # Blue theme
#RUN jt -t monokai -f fira -fs 13 -nf ptsans -nfs 11 -N -kl -cursw 5 -cursc r -cellw 95% -T # Green theme

# Pip install anything else
RUN python -m pip install --user ipywidgets torchsummary scikit-learn nbdime
RUN nbdime config-git --enable --global

COPY monaistartup.sh .

EXPOSE 2222

CMD /usr/sbin/sshd -D -f /home/\${UNAME}/.ssh/sshd_config -E /home/\${UNAME}/.ssh/sshd.log

EOF

# if you have experimental features enabled add --squash to ensure the password isn't cached by the build process
docker build -t $im_name . \
	-f MonaiDockerfile  \
	--build-arg USER_ID=${UID} \
	--build-arg GROUP_ID=$(id -g) \
	--build-arg UNAME=$(whoami) \
	--build-arg GROUPS="$(groups)" \
	--build-arg GIDS="$(getent group $(groups) | awk -F: '{print $3}')"

# run with:
#docker run --rm -ti -d -p 3333:2222 ${im_name}

# Push image
docker tag $im_name ${docker_uname}/${im_name}
docker push ${docker_uname}/${im_name}:latest
