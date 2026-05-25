FROM ubuntu:22.04

ARG SDK_INSTALL_DIR=/opt/poky/sdk

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        file \
        xz-utils \
        python3 \
        diffstat \
        chrpath \
        socat \
        cpio \
        gzip \
        unzip \
        texinfo \
        locales \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

COPY sdk.sh /tmp/sdk.sh
RUN chmod +x /tmp/sdk.sh && \
    /tmp/sdk.sh -d ${SDK_INSTALL_DIR} -y && \
    rm /tmp/sdk.sh

ENV SDKPATH=${SDK_INSTALL_DIR}

CMD ["/bin/bash"]
