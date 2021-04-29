# Base image
ARG DOCKER_BASE
FROM $DOCKER_BASE

# Get all other variables we'll need
ARG UNAME
ARG PWD_HASH
ARG USER_ID
ARG GROUP_ID
ARG GROUPS
ARG GIDS
ARG GITHUB_NAME
ARG GITHUB_EMAIL
ARG JUPY_PWD_HASH
ARG VNC_PWD


################################################################################
# Install misc required packages
################################################################################
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y openssh-server nano sudo htop ffmpeg libsm6 libxext6 gdb


################################################################################
# Create user, assign to groups, set password, switch to new user
################################################################################
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
RUN mkdir ~/Documents ~/Documents/Code ~/.config ~/.config/autostart


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
RUN git config --global user.name ${GITHUB_NAME}
RUN git config --global user.email ${GITHUB_EMAIL}


################################################################################
# Jupyter password
################################################################################
RUN jupyter notebook --generate-config
RUN echo "c.NotebookApp.password = ${JUPY_PWD_HASH}" >> ~/.jupyter/jupyter_notebook_config.py


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
# Pip install requirements and set up jupyter notebook
################################################################################
RUN python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements.txt && \
	python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt && \
    python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/docs/requirements.txt &&  \
    python -m pip install -r https://raw.githubusercontent.com/Project-MONAI/tutorials/master/requirements.txt && \
    python -m pip install --user ipywidgets torchsummary scikit-learn nbdime jupyterlab
# Set up jupyter notebook, w/ blue or green theme
RUN python -m pip install --user jupyterthemes
RUN jt -t oceans16 -T -N
#RUN jt -t monokai -f fira -fs 13 -nf ptsans -nfs 11 -N -kl -cursw 5 -cursc r -cellw 95% -T


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

RUN mkdir ~/Documents/Code/opencv/Build && cd ~/Documents/Code/opencv/Build && \
    cmake ../Source -G Ninja \
        -DCMAKE_INSTALL_PREFIX:PATH=~/Documents/Code/opencv/Install \
        -DOPENCV_EXTRA_MODULES_PATH:PATH=~/Documents/Code/opencv/opencv_contrib/modules \
        -DPYTHON_DEFAULT_EXECUTABLE:FILEPATH=$(which python3) \
        -DCMAKE_BUILD_TYPE:String=Debug \
        -DWITH_CUDA:BOOL=OFF \
        -DGLIBCXX_USE_CXX11_ABI=0 \
        -DCMAKE_CXX_FLAGS="-std=c++14" \
        -DBUILD_CUDA_STUBS:BOOL=OFF \
        -DBUILD_DOCS:BOOL=OFF \
        -DBUILD_EXAMPLES:BOOL=OFF \
        -DBUILD_IPP_IW:BOOL=OFF \
        -DBUILD_ITT:BOOL=OFF \
        -DBUILD_JASPER:BOOL=OFF \
        -DBUILD_JAVA:BOOL=OFF \
        -DBUILD_JPEG:BOOL=OFF \
        -DBUILD_OPENEXR:BOOL=OFF \
        -DBUILD_OPENJPEG:BOOL=OFF \
        -DBUILD_PACKAGE:BOOL=OFF \
        -DBUILD_PERF_TESTS:BOOL=OFF \
        -DBUILD_PNG:BOOL=OFF \
        -DBUILD_PROTOBUF:BOOL=OFF \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DBUILD_TBB:BOOL=OFF \
        -DBUILD_TESTS:BOOL=OFF \
        -DBUILD_TIFF:BOOL=OFF \
        -DBUILD_USE_SYMLINKS:BOOL=OFF \
        -DBUILD_WEBP:BOOL=OFF \
        -DBUILD_WITH_DEBUG_INFO:BOOL=OFF \
        -DBUILD_WITH_DYNAMIC_IPP:BOOL=OFF \
        -DBUILD_ZLIB:BOOL=OFF \
        -DBUILD_opencv_apps:BOOL=OFF \
        -DBUILD_opencv_aruco:BOOL=OFF \
        -DBUILD_opencv_bgsegm:BOOL=OFF \
        -DBUILD_opencv_bioinspired:BOOL=OFF \
        -DBUILD_opencv_calib3d:BOOL=OFF \
        -DBUILD_opencv_ccalib:BOOL=OFF \
        -DBUILD_opencv_core:BOOL=ON \
        -DBUILD_opencv_cudaarithm:BOOL=OFF \
        -DBUILD_opencv_cudabgsegm:BOOL=OFF \
        -DBUILD_opencv_cudacodec:BOOL=OFF \
        -DBUILD_opencv_cudafeatures2d:BOOL=OFF \
        -DBUILD_opencv_cudafilters:BOOL=OFF \
        -DBUILD_opencv_cudaimgproc:BOOL=OFF \
        -DBUILD_opencv_cudalegacy:BOOL=OFF \
        -DBUILD_opencv_cudaobjdetect:BOOL=OFF \
        -DBUILD_opencv_cudaoptflow:BOOL=OFF \
        -DBUILD_opencv_cudastereo:BOOL=OFF \
        -DBUILD_opencv_cudawarping:BOOL=OFF \
        -DBUILD_opencv_cudev:BOOL=OFF \
        -DBUILD_opencv_datasets:BOOL=OFF \
        -DBUILD_opencv_dnn:BOOL=OFF \
        -DBUILD_opencv_dnn_objdetect:BOOL=OFF \
        -DBUILD_opencv_dnn_superres:BOOL=OFF \
        -DBUILD_opencv_dpm:BOOL=OFF \
        -DBUILD_opencv_face:BOOL=OFF \
        -DBUILD_opencv_features2d:BOOL=OFF \
        -DBUILD_opencv_flann:BOOL=OFF \
        -DBUILD_opencv_freetype:BOOL=OFF \
        -DBUILD_opencv_fuzzy:BOOL=OFF \
        -DBUILD_opencv_gapi:BOOL=OFF \
        -DBUILD_opencv_hfs:BOOL=OFF \
        -DBUILD_opencv_highgui:BOOL=OFF \
        -DBUILD_opencv_img_hash:BOOL=OFF \
        -DBUILD_opencv_imgcodecs:BOOL=ON \
        -DBUILD_opencv_imgproc:BOOL=ON \
        -DBUILD_opencv_intensity_transform:BOOL=OFF \
        -DBUILD_opencv_java_bindings_generator:BOOL=OFF \
        -DBUILD_opencv_js:BOOL=OFF \
        -DBUILD_opencv_js_bindings_generator:BOOL=OFF \
        -DBUILD_opencv_line_descriptor:BOOL=OFF \
        -DBUILD_opencv_mcc:BOOL=OFF \
        -DBUILD_opencv_ml:BOOL=OFF \
        -DBUILD_opencv_objc_bindings_generator:BOOL=OFF \
        -DBUILD_opencv_objdetect:BOOL=OFF \
        -DBUILD_opencv_optflow:BOOL=OFF \
        -DBUILD_opencv_phase_unwrapping:BOOL=OFF \
        -DBUILD_opencv_photo:BOOL=OFF \
        -DBUILD_opencv_plot:BOOL=OFF \
        -DBUILD_opencv_pythOFF2:BOOL=OFF \
        -DBUILD_opencv_pythOFF3:BOOL=OFF \
        -DBUILD_opencv_pythOFF_bindings_generator:BOOL=OFF \
        -DBUILD_opencv_pythOFF_tests:BOOL=OFF \
        -DBUILD_opencv_quality:BOOL=OFF \
        -DBUILD_opencv_rapid:BOOL=OFF \
        -DBUILD_opencv_reg:BOOL=OFF \
        -DBUILD_opencv_rgbd:BOOL=OFF \
        -DBUILD_opencv_saliency:BOOL=OFF \
        -DBUILD_opencv_shape:BOOL=OFF \
        -DBUILD_opencv_stereo:BOOL=OFF \
        -DBUILD_opencv_stitching:BOOL=OFF \
        -DBUILD_opencv_structured_light:BOOL=OFF \
        -DBUILD_opencv_superres:BOOL=OFF \
        -DBUILD_opencv_surface_matching:BOOL=OFF \
        -DBUILD_opencv_text:BOOL=OFF \
        -DBUILD_opencv_tracking:BOOL=OFF \
        -DBUILD_opencv_ts:BOOL=OFF \
        -DBUILD_opencv_video:BOOL=ON \
        -DBUILD_opencv_videoio:BOOL=ON \
        -DBUILD_opencv_videostab:BOOL=OFF \
        -DBUILD_opencv_wechat_qrcode:BOOL=OFF \
        -DBUILD_opencv_world:BOOL=OFF \
        -DBUILD_opencv_xfeatures2d:BOOL=OFF \
        -DBUILD_opencv_ximgproc:BOOL=OFF \
        -DBUILD_opencv_xobjdetect:BOOL=OFF \
        -DBUILD_opencv_xphoto:BOOL=OFF \
        -DBUILD_opencv_python2:BOOL=OFF \
        -DBUILD_opencv_python_bindings_generator:BOOL=OFF \
        -DVIDEOIO_ENABLE_PLUGINS:BOOL=OFF \
        -DWITH_1394:BOOL=OFF \
        -DWITH_ADE:BOOL=OFF \
        -DWITH_ARAVIS:BOOL=OFF \
        -DWITH_CLP:BOOL=OFF \
        -DWITH_CUDA:BOOL=OFF \
        -DWITH_EIGEN:BOOL=OFF \
        -DWITH_FFMPEG:BOOL=OFF \
        -DWITH_FREETYPE:BOOL=OFF \
        -DWITH_GDAL:BOOL=OFF \
        -DWITH_GDCM:BOOL=OFF \
        -DWITH_GPHOTO2:BOOL=OFF \
        -DWITH_GSTREAMER:BOOL=OFF \
        -DWITH_GTK:BOOL=OFF \
        -DWITH_GTK_2_X:BOOL=OFF \
        -DWITH_HALIDE:BOOL=OFF \
        -DWITH_HPX:BOOL=OFF \
        -DWITH_IMGCODEC_HDR:BOOL=OFF \
        -DWITH_IMGCODEC_PFM:BOOL=OFF \
        -DWITH_IMGCODEC_PXM:BOOL=OFF \
        -DWITH_IMGCODEC_SUNRASTER:BOOL=OFF \
        -DWITH_INF_ENGINE:BOOL=OFF \
        -DWITH_IPP:BOOL=OFF \
        -DWITH_ITT:BOOL=OFF \
        -DWITH_JASPER:BOOL=OFF \
        -DWITH_JPEG:BOOL=OFF \
        -DWITH_JULIA:BOOL=OFF \
        -DWITH_LAPACK:BOOL=OFF \
        -DWITH_LIBREALSENSE:BOOL=OFF \
        -DWITH_MATLAB:BOOL=OFF \
        -DWITH_MFX:BOOL=OFF \
        -DWITH_NGRAPH:BOOL=OFF \
        -DWITH_NVCUVID:BOOL=OFF \
        -DWITH_ONNX:BOOL=OFF \
        -DWITH_OPENCL:BOOL=OFF \
        -DWITH_OPENCLAMDBLAS:BOOL=OFF \
        -DWITH_OPENCLAMDFFT:BOOL=OFF \
        -DWITH_OPENCL_SVM:BOOL=OFF \
        -DWITH_OPENEXR:BOOL=OFF \
        -DWITH_OPENGL:BOOL=OFF \
        -DWITH_OPENJPEG:BOOL=OFF \
        -DWITH_OPENMP:BOOL=OFF \
        -DWITH_OPENNI:BOOL=OFF \
        -DWITH_OPENNI2:BOOL=OFF \
        -DWITH_OPENVX:BOOL=OFF \
        -DWITH_PLAIDML:BOOL=OFF \
        -DWITH_PNG:BOOL=OFF \
        -DWITH_PROTOBUF:BOOL=OFF \
        -DWITH_PTHREADS_PF:BOOL=OFF \
        -DWITH_PVAPI:BOOL=OFF \
        -DWITH_QT:BOOL=OFF \
        -DWITH_QUIRC:BOOL=OFF \
        -DWITH_TBB:BOOL=OFF \
        -DWITH_TESSERACT:BOOL=OFF \
        -DWITH_TIFF:BOOL=OFF \
        -DWITH_UEYE:BOOL=OFF \
        -DWITH_V4L:BOOL=OFF \
        -DWITH_VA:BOOL=OFF \
        -DWITH_VA_INTEL:BOOL=OFF \
        -DWITH_VTK:BOOL=OFF \
        -DWITH_VULKAN:BOOL=OFF \
        -DWITH_WEBP:BOOL=OFF \
        -DWITH_XIMEA:BOOL=OFF \
        -DWITH_XINE:BOOL=OFF \
        -DBUILD_opencv_python_tests:BOOL=OFF \
        -DBUILD_opencv_python3:BOOL=OFF
RUN cd ~/Documents/Code/opencv/Build && ninja install
RUN echo "export PYTHONPATH=/home/${UNAME}/Documents/Code/opencv/Install/lib/python3.8/site-packages/:$PYTHONPATH" >> ~/.bashrc
# RUN pip install opencv-python


################################################################################
# VNC
################################################################################
COPY xstartup .
RUN mkdir -p ~/.vnc
RUN mv xstartup ~/.vnc/xstartup
USER root
RUN apt install -y xfce4 xfce4-goodies tigervnc-standalone-server
RUN chmod +x /home/${UNAME}/.vnc/xstartup
USER ${UNAME}
# Run it to set the password
RUN printf "${VNC_PWD}\n${VNC_PWD}\n" | vncserver


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

CMD /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/.ssh/sshd.log
