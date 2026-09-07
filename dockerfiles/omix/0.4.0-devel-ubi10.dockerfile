# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

ARG INTEL_REGISTRY=intel
FROM ${INTEL_REGISTRY}/compute-runtime:latest-devel-ubi10.2

########################################
# Install Intel(R) Open Middleware Xe 
########################################

LABEL image.omix.version=0.4.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf install -y intel-omix-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/log/dnf*

ENTRYPOINT ["/bin/bash", "-c", "source /opt/intel/oneapi/setvars.sh --force && exec \"$@\"", "--"]
CMD ["bash"]