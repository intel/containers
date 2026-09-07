# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

FROM redhat/ubi9:9.8

# Install required packages
RUN set -xe && \
    dnf install -y --allowerasing \
        cmake \
        curl \
        git \
        gnupg \
        pkg-config \
        procps \
        sudo \
        unzip \
        wget \
        zip && \
    dnf clean all && \
    rm -rf /var/cache/dnf


########################################
# Install Intel Compute Runtime
########################################

ARG REPOSITORY_URL="https://repositories.intel.com/gpu/rhel"
ARG REPOSITORY_NAME="intel-omix/"
# If version is empty the latest available content of the repository will be installed
ARG REPOSITORY_VERSION=0.4.0


# hadolint ignore=DL4006 # This applies to Alpine and BusyBox images
RUN . "/etc/os-release" \
    && dnf install -y "dnf-command(config-manager)" \
    && dnf config-manager --add-repo "${REPOSITORY_URL}/${VERSION_ID}/${REPOSITORY_NAME}${REPOSITORY_VERSION}/unified/intel-gpu-${VERSION_ID}.repo" \
    && dnf install -y \
        intel-gpu-compute-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf
