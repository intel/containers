# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

ARG INTEL_REGISTRY=intel
FROM ${INTEL_REGISTRY}/compute-runtime:latest-runtime-ubi9.8

########################################
# Install Python and create a virtual environment
########################################

RUN dnf --disablerepo='intel-graphics-*' install -y \
        python3.11 \
        python3.11-devel \
        python3.11-pip && \
    python3.11 --version && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    mkdir -p /opt && \
    python3.11 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir --upgrade pip 'setuptools>=83.0.0' wheel
# binutils supplies addr2line and c++filt, which PyTorch uses for reliable debug tracebacks.
RUN dnf --disablerepo='intel-graphics-*' install -y binutils && \
    dnf clean all && \
    rm -rf /var/cache/dnf


########################################
# Install PyTorch for the XPU device backend
########################################

# DEVICE = <'cpu' or 'xpu'>
ENV DEVICE=xpu \
    TORCH_VERSION=2.14.0 \
    TORCH_AUDIO_VERSION=2.11.0 \
    TORCH_VISION_VERSION=0.29.0

# The cache mount keeps the downloaded wheels out of the image layer, so pip's own cache is left enabled.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --index-url https://download.pytorch.org/whl/${DEVICE} \
        torch==${TORCH_VERSION} \
        torchvision==${TORCH_VISION_VERSION} \
        torchaudio==${TORCH_AUDIO_VERSION} \
    && rm -rf /tmp/pip-*
# Bump pillow (pulled in by torchvision) to a CVE-free version.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install pillow==13.0.0 \
    && rm -rf /tmp/pip-*