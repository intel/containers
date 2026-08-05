# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

ARG INTEL_REGISTRY=intel
FROM ${INTEL_REGISTRY}/compute-runtime:latest-devel-ubuntu26.04

########################################
# Install Intel(R) Open Middleware Xe 
########################################

LABEL image.omix.version=0.3.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends intel-omix-dev && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash", "-c", "source /opt/intel/oneapi/setvars.sh --force && exec \"$@\"", "--"]
CMD ["bash"]