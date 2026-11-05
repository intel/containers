# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

ARG INTEL_REGISTRY=intel
FROM ${INTEL_REGISTRY}/omix:0.5.0-runtime-ubi9

########################################
# Install Intel(R) Open Middleware Xe 
########################################

LABEL image.omix.version=0.5.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf install -y --allowerasing \
        cmake \
        curl \
        git \
        procps-ng \
        intel-omix-devel && \
    dnf clean all && \
    # Remove vulnerable oneapi-cli
    rm -f /opt/intel/oneapi/dev-utilities/latest/bin/oneapi-cli && \
    rm -rf /var/cache/dnf /var/log/dnf*

ENTRYPOINT ["/bin/bash", "-c", "source /opt/intel/oneapi/setvars.sh --force && exec \"$@\"", "--"]
CMD ["bash"]