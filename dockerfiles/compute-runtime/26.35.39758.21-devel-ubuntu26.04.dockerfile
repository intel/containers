# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

ARG PUBLIC_REGISTRY=library
FROM ${PUBLIC_REGISTRY}/ubuntu:26.04

# Install required packages
RUN set -xe && \
    apt-get update && \
    apt-get install -y --fix-missing --no-install-recommends \
        ca-certificates \
        gnupg \
        pkg-config \
        unzip \
        wget && \
    rm -rf /var/lib/apt/lists/*


########################################
# Install Intel Compute Runtime
########################################

ARG KEY_URL="https://repositories.intel.com/gpu/intel-graphics.key"
ARG REPOSITORY_URL="https://repositories.intel.com/gpu/ubuntu"
ARG REPOSITORY_NAME="intel-omix/"
# If version is empty the latest available content of the repository will be installed
ARG REPOSITORY_VERSION=0.5.0


# hadolint ignore=DL4006 # This applies to Alpine and BusyBox images
RUN . /etc/os-release \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        gnupg \
        wget \
    && wget -qO - "${KEY_URL}" | \
        gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] ${REPOSITORY_URL} ${VERSION_CODENAME}/${REPOSITORY_NAME}${REPOSITORY_VERSION} unified" | \
        tee "/etc/apt/sources.list.d/intel-gpu-${VERSION_CODENAME}.list" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        intel-gpu-compute-dev \
        clinfo \
    && rm -rf /var/lib/apt/lists/*
