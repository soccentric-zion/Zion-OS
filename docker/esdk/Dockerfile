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
        gcc \
        g++ \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN useradd -m -s /bin/bash yocto

COPY esdk.sh /tmp/esdk.sh
RUN chmod +x /tmp/esdk.sh && \
    mkdir -p ${ESDK_INSTALL_DIR} && \
    chown yocto:yocto ${ESDK_INSTALL_DIR} && \
    su yocto -c "/tmp/esdk.sh -d ${ESDK_INSTALL_DIR} -y" && \
    rm /tmp/esdk.sh

ENV ESDKPATH=${ESDK_INSTALL_DIR}

USER yocto
CMD ["/bin/bash"]
