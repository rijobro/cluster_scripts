#!/bin/bash

set -e # exit on error
set -x # print command before doing it



# Some variables
base_image=projectmonai/monai:latest
im_name=rb-monai
docker_uname=rijobro
# Set password hashes. Create with:
#   bash: openssl passwd -1
#   jupy: python -c "from notebook.auth import passwd; print(passwd())"
ssh_pw='$1$rI/6m9Sa$3MAazPOmNTJm2IUnnCHOl0'
jupy_pw='argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'
vnc_pw='monai1'



# create a temporary directory
TMP_DIR=$(mktemp -d)





# write the following, up to EOF, to Dockerfile in the temp directory
cat - <<EOF > $TMP_DIR/Dockerfile

# Set base image
ARG BASEIMAGE
FROM \${BASEIMAGE}

# Remove default monai folder (so we can mount our own)
RUN rm -rf /opt/monai/*

# Colourful bash
RUN echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\] '" >> ~/.b$

# Set paths
ENV PYTHONPATH "~/MONAI:~/ptproto"
ENV MONAI_DATA_DIRECTORY "~/data/MONAI"
ENV PATH "/opt/conda/bin:$PATH"
RUN echo "source ~/bash_profile/rich_bashrc.sh" >> ~/.bashrc

# Reinstall conda
RUN conda install anaconda-clean -y
RUN anaconda-clean -y
RUN rm -rf ~/.conda ~/.jupyter /opt/conda || true
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash ./Miniconda3-latest-Linux-x86_64.sh -p /opt/conda -b
RUN rm Miniconda3-latest-Linux-x86_64.sh

# Install requirements
RUN python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt
RUN python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt

# SSHD
ARG SSHPW
RUN apt update && apt install -y openssh-server
RUN mkdir /var/run/sshd
RUN printf "root:%s" "$ssh_pw" | chpasswd -e
RUN sed -i 's/#*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd
ENV NOTVISIBLE="in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]

# Create user -- put this at the end, after you won't have sudo priv
#ARG USER_ID
#ARG GROUP_ID
#ARG UNAME
#RUN addgroup --gid \${GROUP_ID} usergroup
#RUN adduser --system --ingroup usergroup --disabled-password --uid \${USER_ID} \${UNAME}
#USER \${UNAME}
#WORKDIR /home/\${UNAME}

# Add user to sudo (pw same as username)
#RUN apt update && apt install -y sudo
#RUN echo "\${UNAME}:\${UNAME}" | chpasswd
#RUN usermod -aG sudo \${UNAME}

EOF

# Build image
docker build \
	--build-arg USER_ID=${UID} \
	--build-arg GROUP_ID=$(id -g) \
        --build-arg UNAME=$(whoami) \
	--build-arg BASEIMAGE=$base_image \
	--build-arg SSHPW=$ssh_pw \
	-t $im_name $TMP_DIR

# Push image
#docker tag $im_name ${docker_uname}/${im_name}
#docker push ${docker_uname}/${im_name}:latest
