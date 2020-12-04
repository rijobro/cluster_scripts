#!/bin/bash

set -e # stop on error

im_name=rb-monai

password=$1
if [ -z "$password" ]; then
	read -s -p "Enter root password: " password
fi
echo

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



cat - <<EOF > MonaiDockerfile
FROM ubuntu:20.04

# Install sshd
RUN apt update && apt install -y openssh-server && rm -rf /var/lib/apt/lists/*
# Change sudo password (not necessary for cluster jobs as disabled)
RUN echo "root:$password" | chpasswd

# Add user and add to same groups as local
ARG GROUPS
ARG GIDS
ARG USER_ID
ARG GROUP_ID
ARG UNAME
RUN addgroup --gid \${GROUP_ID} \${UNAME}
RUN adduser --ingroup \${UNAME} --system --shell /bin/bash --uid \${USER_ID} \${UNAME}
COPY create_user_groups.sh .
RUN cat create_user_groups.sh
RUN bash ./create_user_groups.sh "\$GROUPS" "\$GIDS" \${UNAME}
RUN echo "\${UNAME}:$password" | chpasswd
RUN echo "+:\${UNAME}:ALL" >> /etc/security/access.conf

# Change to user
WORKDIR /home/\${UNAME}
USER \${UNAME}

# Set up SSHD to be run as non-sudo user
RUN mkdir -p /home/\${UNAME}/.ssh
RUN ssh-keygen -f /home/\${UNAME}/.ssh/id_rsa -N '' -t rsa
RUN ssh-keygen -f /home/\${UNAME}/.ssh/id_dsa -N '' -t dsa
RUN echo "PasswordAuthentication yes" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "Port 2222" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "HostKey /home/\${UNAME}/.ssh/id_rsa" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "HostKey /home/\${UNAME}/.ssh/id_dsa" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "AuthorizedKeysFile  .ssh/authorized_keys" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "ChallengeResponseAuthentication no" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "UsePAM no" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "Subsystem   sftp    /usr/lib/ssh/sftp-server" >> /home/\${UNAME}/.ssh/sshd_config
RUN echo "PidFile /home/\${UNAME}/sshd.pid" >> /home/\${UNAME}/.ssh/sshd_config

EXPOSE 2222

CMD /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/sshd.log

EOF

# if you have experimental features enabled add --squash to ensure the password isn't cached by the build process
docker build -t $im_name . \
	-f MonaiDockerfile  \
        --build-arg USER_ID=${UID} \
        --build-arg GROUP_ID=$(id -g) \
        --build-arg UNAME=$(whoami) \
        --build-arg SSHPW=$ssh_pw \
	--build-arg GROUPS="$(groups)" \
	--build-arg GIDS="$(getent group $(groups) | awk -F: '{print $3}')"

# run with:
#docker run --rm -ti -d -p 3333:22 ${im_name}

# Push image
docker tag $im_name rijobro/${im_name}
docker push rijobro/${im_name}:latest

# Cleanup
rm create_user_groups.sh MonaiDockerfile
