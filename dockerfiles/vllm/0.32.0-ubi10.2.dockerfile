# Copyright (c) 2026 Intel Corporation
# SPDX-License-Identifier: MIT

######################### RUST BUILD IMAGE #########################
# Build the Rust frontend (`vllm-rs`) in a dedicated stage so the main image
# doesn't need the rust toolchain. Runs in parallel with vllm-base.
#
# Unlike upstream Dockerfile.xpu (which COPYs the rust build inputs from the
# host build context), this stage clones the vLLM repo so nothing is copied
# from the host. UBI base per request.
FROM redhat/ubi10:10.2 AS rust-build-cache

RUN dnf install -y \
        ca-certificates \
        curl \
        git \
        gcc \
        gcc-c++ \
        make \
        perl-core \
        perl-FindBin \
        perl-IPC-Cmd \
        perl-Data-Dumper \
        perl-File-Compare \
        perl-File-Copy \
        python3.12 \
        python3-pip && \
    dnf clean all && \
    rm -rf /var/cache/dnf

WORKDIR /workspace

# Full clone (no --depth) so setuptools_scm can derive the exact version from
# tags/history during the relink stage below.
# Then install the Rust build requirements published in the cloned tree.
RUN git clone --branch releases/v0.32.0 https://github.com/vllm-project/vllm.git . && \
    python3 -m pip install --no-cache-dir -r requirements/build/rust.txt

# Cap cargo parallelism to avoid exhausting the CI host's open-file limit
# (rustc spawns enough concurrent processes to hit RLIMIT_NOFILE otherwise).
ENV CARGO_BUILD_JOBS=4

# Build with a stable version so this target snapshot is keyed only by Rust
# inputs. The child stage below relinks the crates that embed the exact version.
RUN --mount=type=cache,target=/root/.cargo/registry,sharing=locked \
    --mount=type=cache,target=/root/.cargo/git,sharing=locked \
    SETUPTOOLS_SCM_PRETEND_VERSION="0.0.0+docker.cache" bash tools/build_rust.sh

# Relink with the exact Git-derived package version. The .git dir is already
# present from the clone above, so no host bind mount is required.
FROM rust-build-cache AS rust-build

RUN --mount=type=cache,target=/root/.cargo/registry,sharing=locked \
    --mount=type=cache,target=/root/.cargo/git,sharing=locked \
    SETUPTOOLS_SCM_PRETEND_METADATA="{dirty=false}" bash tools/build_rust.sh


######################### BASE IMAGE #########################
# GPU drivers (UMD) and XPU-Manager are provided by the intel/compute-runtime
# base image, so the UMD/XPU-Manager install steps from upstream Dockerfile.xpu
# are intentionally omitted here.
FROM amr-registry.caas.intel.com/layered-containers-cache/production/compute-runtime:26.31.39395.16-runtime-ubi10 AS vllm-base

WORKDIR /workspace/

ARG PYTHON_VERSION=3.12
ARG PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/xpu"

# EPEL provides libsndfile. ffmpeg omitted: ffmpeg-free needs SDL2 (CRB-only,
# absent on UBI). Install a static ffmpeg build if audio/video decode is needed.
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm && \
    dnf install -y --allowerasing \
        gcc \
        gcc-c++ \
        make \
        ca-certificates \
        curl \
        git \
        gnupg2 \
        libsndfile \
        libSM \
        libXext \
        libaio-devel \
        mesa-libGL \
        numactl \
        numactl-libs \
        wget \
        vim-minimal \
        python3.12 \
        python3.12-devel \
        python3-pip && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Install uv and create the runtime virtual environment (mirrors upstream).
ENV PATH="/root/.local/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
# hadolint ignore=DL4006 # sh only consumes the installer script; pipefail not needed
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv venv --python ${PYTHON_VERSION} --seed ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

SHELL ["/bin/bash", "-c"]

WORKDIR /workspace/vllm

ENV UV_HTTP_TIMEOUT=500

# Configure package index for XPU
ENV PIP_EXTRA_INDEX_URL=${PIP_EXTRA_INDEX_URL}
ENV UV_EXTRA_INDEX_URL=${PIP_EXTRA_INDEX_URL}
ENV UV_INDEX_STRATEGY="unsafe-best-match"
ENV UV_LINK_MODE="copy"

RUN --mount=type=cache,target=/root/.cache/uv \
    git clone --branch releases/v0.32.0 https://github.com/vllm-project/vllm.git . && \
    uv pip install --upgrade pip

ENV LD_LIBRARY_PATH=/opt/venv/lib:/usr/local/lib
CMD ["/bin/bash"]


######################### WHEEL BUILD STAGE #########################
# Produces a standalone dist/*.whl artifact (independent of the runtime image
# below).
FROM vllm-base AS vllm-build

ARG GIT_REPO_CHECK=0

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install grpcio-tools protobuf nanobind && \
    uv pip install -r requirements/xpu.txt

# Drop the pre-built Rust artifacts into the cloned source tree. setup.py
# detects them and ships them as-is, skipping the local Rust build.
COPY --from=rust-build /workspace/vllm/vllm-rs vllm/vllm-rs
COPY --from=rust-build /workspace/vllm/_rust_*.so vllm/
# Also ship the CVE-patched manifest/lockfile so image scanners see the crate versions actually built.
COPY --from=rust-build /workspace/rust/Cargo.toml /workspace/rust/Cargo.lock rust/

RUN if [ "$GIT_REPO_CHECK" != 0 ]; then bash tools/check_repo.sh; fi

RUN --mount=type=cache,target=/root/.cache/uv \
    VLLM_TARGET_DEVICE=xpu python3 setup.py bdist_wheel --dist-dir=dist --py-limited-api=cp38


######################### UCX + NIXL BUILD STAGE #########################
# Build UCX and NIXL in a dedicated stage so compiler/autotools layers are
# never included in the final runtime image.
FROM vllm-base AS ucx-nixl-build

# Keep UCX_VERSION aligned with the UCX that NIXL itself builds against for this
# NIXL_VERSION (nixl contrib/Dockerfile.manylinux: ARG UCX_REF), so XPU runs the
# same UCX commit as the released nixl-cu* wheels rather than an untested pairing.
ARG UCX_VERSION=v1.21.x
ARG NIXL_VERSION=v1.3.2

# Build-time only: compiler, autotools, verbs dev headers, and the Level-Zero
# dev headers required by `./configure --with-ze=yes` (base ships only the L0
# runtime). diffutils provides cmp/diff used by libtool/configure.
RUN dnf install -y --allowerasing \
        gcc \
        gcc-c++ \
        make \
        autoconf \
        automake \
        libtool \
        diffutils \
        pkgconf-pkg-config \
        libibverbs-devel \
        librdmacm-devel \
        level-zero-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Build UCX and produce a NIXL wheel so the final image needs no compiler.
# patchelf (installed via uv) is used by the NIXL wheel build to rewrite
# RPATH entries, making the wheel portable across stages.
# hadolint ignore=DL3003
RUN --mount=type=cache,target=/root/.cache/uv \
    git clone --depth 1 --branch "${UCX_VERSION}" https://github.com/openucx/ucx /tmp/ucx_source && \
    cd /tmp/ucx_source && \
    bash autogen.sh && \
    ./configure --prefix=/opt/ucx --with-ze=yes --enable-examples --enable-mt && \
    make CFLAGS="-Wno-error=incompatible-pointer-types" -j"$(nproc)" && make install && \
    git clone --depth 1 --branch "${NIXL_VERSION}" https://github.com/ai-dynamo/nixl /tmp/nixl_source && \
    cd /tmp/nixl_source && \
    uv pip install --upgrade meson pybind11 patchelf && \
    uv pip install -r requirements.txt && \
    PKG_CONFIG_PATH=/opt/ucx/lib/pkgconfig \
    LD_LIBRARY_PATH=/opt/ucx/lib \
    python -m pip wheel --no-deps . -w /tmp/nixl_wheels/ && \
    find /opt/ucx -type f \( -name '*.a' -o -name '*.la' \) -delete && \
    rm -rf /opt/ucx/include /opt/ucx/share /opt/ucx/etc /opt/ucx/lib/cmake \
           /tmp/ucx_source /tmp/nixl_source


######################### RUNTIME IMAGE #########################
FROM vllm-base AS vllm-runtime
ENV UV_COMPILE_BYTECODE=1

# Must match the ucx-nixl-build stage above: ARG does not cross stages, so a
# stale value here installs a meta package that disagrees with the built wheel.
ARG NIXL_VERSION=v1.3.2

# Copy compiled UCX runtime libraries and the pre-built NIXL wheel.
# No compiler or autotools are installed in this stage.
COPY --from=ucx-nixl-build /opt/ucx /opt/ucx
COPY --from=ucx-nixl-build /tmp/nixl_wheels /tmp/nixl_wheels

ENV LD_LIBRARY_PATH=/opt/ucx/lib:${LD_LIBRARY_PATH}

# Install RDMA runtime libraries (no build tools) and the pre-built NIXL wheel.
RUN --mount=type=cache,target=/root/.cache/uv \
    dnf install -y --allowerasing \
        libibverbs \
        librdmacm \
        libibumad \
        level-zero-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    uv pip install --no-deps /tmp/nixl_wheels/nixl*.whl && \
    uv pip install --no-deps nixl==${NIXL_VERSION} && \
    rm -rf /tmp/nixl_wheels

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install grpcio-tools protobuf nanobind && \
    uv pip install -r requirements/xpu.txt && \
    # vLLM uses Python API only, no need to keep Java API
    find "${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/ray/jars" -name "*.jar" -delete
#    uv pip install --no-build-isolation -r requirements/test/xpu.txt

# Drop the pre-built Rust artifacts into the cloned source tree. setup.py
# detects them and ships them as-is, skipping the local Rust build.
COPY --from=rust-build /workspace/vllm/vllm-rs vllm/vllm-rs
COPY --from=rust-build /workspace/vllm/_rust_*.so vllm/
# Also ship the CVE-patched manifest/lockfile so image scanners see the crate versions actually built.
COPY --from=rust-build /workspace/rust/Cargo.toml /workspace/rust/Cargo.lock rust/

ARG GIT_REPO_CHECK=0
RUN if [ "$GIT_REPO_CHECK" != 0 ]; then bash tools/check_repo.sh; fi

ENV VLLM_TARGET_DEVICE=xpu
ENV VLLM_WORKER_MULTIPROC_METHOD=spawn

# Install vLLM, then replace 2026.1.2 DLE packages with 2026.1.3 (as in upstream
# Dockerfile.xpu). No .git bind mount needed: the source tree is cloned.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --no-build-isolation --no-deps . && \
    uv pip install -e tests/vllm_test_utils && \
    uv pip install \
      "intel-cmplr-lib-rt==2026.1.2" \
      "intel-cmplr-lib-ur==2026.1.2" \
      "intel-cmplr-lic-rt==2026.1.2" \
      "intel-sycl-rt==2026.1.2" \
      "oneccl-devel==2022.1.2; platform_system == 'Linux' and platform_machine == 'x86_64'" \
      "oneccl==2022.1.2; platform_system == 'Linux' and platform_machine == 'x86_64'" \
      "dpcpp-cpp-rt==2026.1.2" \
      "intel-opencl-rt==2026.1.2" \
      "intel-openmp==2026.1.2" \
      "intel-pti==1.1.0"

ENTRYPOINT ["vllm", "serve"]