FROM ubuntu:22.04

ARG ESDK_INSTALL_DIR=/opt/poky/esdk

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        file \
        xz-utils \
        bzip2 \
        gawk \
        python3 \
        python3-pip \
        python3-venv \
        diffstat \
        wget \
        chrpath \
        socat \
        cpio \
        gzip \
        unzip \
        texinfo \
        locales \
        git \
        openssh-client \
        gcc \
        g++ \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN useradd -m -s /bin/bash yocto

# The eSDK fetches the private Zion-HAL source over SSH (AUTOREV), so the
# container needs the host's SSH keys. These are copied in from docker/esdk/ssh/
# (gitignored) and only used to fetch the private repo during eSDK preparation.
COPY ssh/ /tmp/ssh/
RUN mkdir -p /home/yocto/.ssh && \
    cp /tmp/ssh/id_* /tmp/ssh/config /home/yocto/.ssh/ 2>/dev/null || true && \
    chmod 600 /home/yocto/.ssh/id_* /home/yocto/.ssh/config 2>/dev/null || true && \
    ssh-keyscan github.com >> /home/yocto/.ssh/known_hosts 2>/dev/null && \
    chown -R yocto:yocto /home/yocto/.ssh && \
    rm -rf /tmp/ssh

COPY esdk.sh /tmp/esdk.sh
RUN chmod +x /tmp/esdk.sh && \
    mkdir -p ${ESDK_INSTALL_DIR} && \
    chown yocto:yocto ${ESDK_INSTALL_DIR} && \
    su yocto -c "/tmp/esdk.sh -d ${ESDK_INSTALL_DIR} -y" && \
    rm /tmp/esdk.sh

ENV ESDKPATH=${ESDK_INSTALL_DIR}

USER yocto
CMD ["/bin/bash"]
