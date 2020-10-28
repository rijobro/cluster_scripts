#!/bin/bash

# Exit on error
set -e

upgrade_python=true
ssh_server=true

# Set password hashes. Create with:
#   bash: openssl passwd -1
#   jupy: python -c "from notebook.auth import passwd; print(passwd())"
ssh_pw='$1$rI/6m9Sa$3MAazPOmNTJm2IUnnCHOl0'
jupy_pw='argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'

# Remove default monai folder and mount our own
rm -rf /opt/monai/*
cd /root

# Set paths
export PYTHONPATH="/root/MONAI:/root/ptproto"
export MONAI_DATA_DIRECTORY="/root/data/MONAI"
export PATH="/opt/conda/bin:$PATH"
printf "export PYTHONPATH=%s\n" "$PYTHONPATH" >> ~/.bashrc
printf "export MONA_DATA_DIRECTORY=%s\n" "$MONAI_DATA_DIRECTORY" >> ~/.bashrc
printf "export PATH=%s\n" "$PATH" >> ~/.bashrc

# Mount our bash script
echo "source ~/bash_profile/rich_bashrc.sh" >> ~/.bashrc

# Set git info
git config --global user.name "Richard Brown"
git config --global user.email "33289025+rijobro@users.noreply.github.com"

# Reinstall conda -- use this if you need a more recent version of python
if [ "$upgrade_python" = true ] ; then
        conda install anaconda-clean -y
        anaconda-clean -y
        rm -rf ~/.conda ~/.jupyter /opt/conda || true
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        echo "879457af6a0bf5b34b48c12de31d4df0ee2f06a8e68768e5758c3293b2daf688 Miniconda3-latest-Linux-x86_64.sh" | sha256sum --check --status
        bash ./Miniconda3-latest-Linux-x86_64.sh -p /opt/conda -b
	rm Miniconda3-latest-Linux-x86_64.sh

	# Install requirements
	python -m pip install -r ~/MONAI/requirements.txt
	python -m pip install -r ~/MONAI/requirements-dev.txt
fi

# SSH server
if [ "$ssh_server" = true ]; then
	# Install ssh server
	apt update
	apt install -y openssh-server
	mkdir /var/run/sshd
	printf "root:%s" "$ssh_pw" | chpasswd -e
	sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
	sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
	mkdir -p /root/.ssh
	# Start the server
	service ssh start
fi

# Use 0000 umask for shared folders (needs to happen after starting sshd service)
umask 0000

# Install python extras
python -m pip install -r ~/MONAI/docs/requirements.txt
python -m pip install ipywidgets

# Dark jupyter theme
python -m pip install jupyterthemes
jt -t oceans16 -T -N

# Start jupyter
jupyter notebook --ip 0.0.0.0 --no-browser --allow-root --notebook-dir="~" --NotebookApp.password=${jupy_pw}

sleep infinity
