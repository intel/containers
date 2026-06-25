# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

FROM intel/omix:0.1.0-devel-ubuntu24.04

# Define Git username and email to apply local patches
ARG GIT_USER_NAME=devel
ARG GIT_USER_EMAIL=devel@example.com

########################################
# Install Python and create a virtual environment
########################################

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv && \
    python3 --version && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt && \
    python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir --upgrade pip setuptools wheel

########################################
# Install dependencies
########################################

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends --fix-missing \
    ffmpeg \
    libsndfile1 \
    libsm6 \
    libxext6 \
    libgl1 \
    lsb-release \
    libaio-dev \
    numactl && \
    rm -rf /var/lib/apt/lists/*

# This Intel(R) oneAPI Collective Communications Library (oneCCL) contains several enhancements for Intel(R) Arc(TM) Pro graphics
# For details, please refer to https://github.com/uxlfoundation/oneCCL/releases/tag/2021.15.9
ARG ONECCL_INSTALLER="intel-oneccl-2021.15.9.14_offline.sh"
ARG ONECCL_INSTALLER_SHA256="f7ab81b6ed1b10dd35fadec366a78046d8af214888dfd625047ce8953d5aa4ef"
RUN wget --progress=dot:giga "https://github.com/uxlfoundation/oneCCL/releases/download/2021.15.9/${ONECCL_INSTALLER}" && \
    printf "%s  %s\n" "${ONECCL_INSTALLER_SHA256}" "${ONECCL_INSTALLER}" > /tmp/oneccl.sha256 && \
    sha256sum -c /tmp/oneccl.sha256 && \
    rm -f /tmp/oneccl.sha256 && \
    bash "${ONECCL_INSTALLER}" -a --silent --eula accept && \
    rm "${ONECCL_INSTALLER}" && \
    echo "source /opt/intel/oneapi/setvars.sh --force" >> /root/.bashrc && \
    echo "source /opt/intel/oneapi/ccl/2021.15/env/vars.sh --force" >> /root/.bashrc && \
    rm -f /opt/intel/oneapi/ccl/latest && \
    ln -s /opt/intel/oneapi/ccl/2021.15 /opt/intel/oneapi/ccl/latest

########################################
# Install vLLM
########################################

ENV VLLM_VERSION=0.21.0

RUN --mount=type=cache,target=/root/.cache/pip \
    apt-get update && \
    apt-get install -y --no-install-recommends git-all && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/vllm-project/vllm.git /opt/vllm

WORKDIR /opt/vllm

RUN --mount=type=cache,target=/root/.cache/pip \
    git checkout v${VLLM_VERSION} && \
    # Apply optimization and feature patches on top of upstream vLLM 0.21.0 to improve performance.
    git clone https://github.com/intel/llm-scaler.git /tmp/llm-scaler && \
    git -C /tmp/llm-scaler checkout omix-vllm-0.21.0 && \
    git -c user.name="${GIT_USER_NAME}" -c user.email="${GIT_USER_EMAIL}" am < "/tmp/llm-scaler/vllm/patches/v21.patch" && \
    rm -rf /tmp/llm-scaler && \
    # Install requirements
    pip install --no-cache-dir -v -r requirements/xpu.txt && \
    VLLM_TARGET_DEVICE=xpu pip install --no-build-isolation -e . -v && \
    # Fix triton
    pip uninstall -y triton triton-xpu && \
    pip install triton-xpu==3.7.0 --extra-index-url https://download.pytorch.org/whl/xpu && \
    # remove PyTorch bundled oneCCL to avoid conflicts
    pip uninstall -y oneccl oneccl-devel