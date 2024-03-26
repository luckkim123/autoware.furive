# hadolint global ignore=DL3006,DL3008,DL3009,DL3015,DL3013,DL3027,DL3042
ARG BASE_IMAGE

FROM $BASE_IMAGE as base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO

# Install apt packages
# hadolint ignore=DL3008
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
  git \
  ssh \
  wget \
  cmake \
  curl \
  gosu \
  gnupg \
  vim \
  unzip \
  lsb-release \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Add GitHub to known hosts for private repositories
RUN mkdir -p ~/.ssh \
  && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Copy files
COPY setup-dev-env.sh ansible-galaxy-requirements.yaml amd64.env arm64.env /autoware/
COPY ansible/ /autoware/ansible/
WORKDIR /autoware

# Set up base environment
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module base --runtime openadk \
  && pip uninstall -y ansible ansible-core \
  && pip install vcstool \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache \
  && echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /etc/bash.bashrc

# Create entrypoint
CMD ["/bin/bash"]

FROM base as prebuilt
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO
ARG SETUP_ARGS
ARG ROS_DISTRO
ENV CCACHE_DIR=/ccache
ENV CC="/usr/lib/ccache/gcc"
ENV CXX="/usr/lib/ccache/g++"

# Set up development environment
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all ${SETUP_ARGS} --no-cuda-drivers openadk \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache \
  && find / -name 'libcu*.a' -delete \
  && find / -name 'libnv*.a' -delete
  
CMD ["/bin/bash"]

FROM prebuilt as devel
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install development tools and artifacts
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module dev-tools --download-artifacts openadk \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

# Change working directory to workspace
WORKDIR /workspace

# Create entrypoint
COPY docker/autoware-openadk/etc/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["/bin/bash"]

FROM base as runtime
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO
ARG LIB_DIR
ARG SETUP_ARGS

# Set up runtime environment and artifacts
COPY autoware.repos /autoware/
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all ${SETUP_ARGS} --download-artifacts --no-cuda-drivers --runtime openadk \
  && pip uninstall -y ansible ansible-core \
  && find /usr/lib/$LIB_DIR-linux-gnu -name "*.a" -type f -delete \
  && find / -name "*.o" -type f -delete \
  && find / -name "*.h" -type f -delete \
  && find / -name "*.hpp" -type f -delete \
  && rm -rf /root/.local/pipx /opt/ros/"$ROS_DISTRO"/include \
    /etc/apt/sources.list.d/cuda*.list \
    /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/nvidia-docker.list \
    /usr/include /usr/share/doc /usr/lib/gcc /usr/lib/jvm /usr/lib/llvm*

# Copy bash aliases
COPY docker/autoware-openadk/etc/.bash_aliases /root/.bash_aliases
RUN echo "source /autoware/install/setup.bash" > /etc/bash.bashrc

# Create entrypoint
COPY docker/autoware-openadk/etc/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
