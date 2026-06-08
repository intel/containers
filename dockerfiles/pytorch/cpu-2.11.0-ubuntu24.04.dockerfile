# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

ARG PUBLIC_REGISTRY=library
FROM ${PUBLIC_REGISTRY}/ubuntu:24.04

# Install required packages
RUN set -xe && \
    apt-get update && \
    apt-get install -y --fix-missing --no-install-recommends \
        build-essential \
        cmake \
        curl \
        git \
        gnupg \
        pkg-config \
        software-properties-common \
        sudo \
        unzip \
        wget \
        zip && \
    # This is good to minimize the image size
    rm -rf /var/lib/apt/lists/*


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
# Install PyTorch with Intel XPU support
########################################

# DEVICE = <cpu or xpu>
ENV DEVICE=cpu \
    TORCH_VERSION=2.11.0 \
    TORCH_AUDIO_VERSION=2.11.0 \
    TORCH_VISION_VERSION=0.26.0

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/${DEVICE} \
        torch==${TORCH_VERSION} \
        torchvision==${TORCH_VISION_VERSION} \
        torchaudio==${TORCH_AUDIO_VERSION}