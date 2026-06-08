# Intel AI Container Stack

## Introduction

This repository provides Dockerfiles and build scripts for creating container images with Intel GPU Drivers, oneAPI,
PyTorch (with XPU support), and deep learning essentials on various Linux distributions. The stack is designed for
high-performance deep learning workloads on Intel GPUs.

## Repository Structure

- `dockerfiles/`: contains folders each corresponding to a specific image in the stack serving a specific purpose. Under
  each folder, you will find Dockerfile(s).

## About the Stack
The stack consists of the following images:
### `dockerfiles/pytorch/`

**Intel(R) support for PyTorch***

The PyTorch\* Intel(R) container images are optimized for Intel(R) CPUs and Intel GPUs, providing a seamless experience for developers to build and deploy AI applications.

Below is an example command that can be used to build this image:
```shell
docker build -t intel/pytorch:xpu-2.11.0-ubuntu24.04 -f dockerfiles/pytorch/xpu-2.11.0-ubuntu24.04.dockerfile .
```
### `dockerfiles/compute-runtime/`

**Intel(R) Graphics Compute Runtime for oneAPI Level Zero and OpenCL(TM) Driver**

The Intel(R) Graphics Compute Runtime for oneAPI Level Zero and OpenCL(TM) Driver is an open source project providing compute API support (Level Zero, OpenCL) for Intel graphics hardware architectures (HD Graphics, Xe).

Below is an example command that can be used to build this image:
```shell
docker build -t intel/compute-runtime:26.14.37833.4-devel-ubuntu24.04 -f dockerfiles/compute-runtime/26.14.37833.4-devel-ubuntu24.04.dockerfile .
```
### `dockerfiles/omix/`

**Open Middleware X<sup>e</sup>**

Open Middleware X<sup>e</sup> is a set of highly optimized deep learning frameworks and tools for Intel GPUs to accelerate AI workloads.

Below is an example command that can be used to build this image:
```shell
docker build -t intel/omix:0.1.0-devel-ubuntu24.04 -f dockerfiles/omix/0.1.0-devel-ubuntu24.04.dockerfile .
```

## Prerequisites

To utilize containers with Intel GPU driver support, the host system must meet the following requirements:

- **Operating System**: A supported Linux distribution is required. A supported Linux distribution is required.
Refer to [Supported Linux Kernels](https://dgpu-docs.intel.com/driver/client/overview.html#selecting-the-right-operating-system-version) for specific version details.
- **Kernel Mode Driver (KMD)**: The system must have the appropriate KMD driver installed.

### Requirements for AI Containers

If you plan to use the following AI containers, the host system requires the latest kernel version to support
the necessary drivers and specific AI features:
*   `deep-learning-essentials`
*   `pytorch`

### Installing the Intel GPU Kernel (Ubuntu)

For optimal compatibility with the latest Intel GPU devices and features, install the kernel from the `intel-graphics` PPA.
Follow the steps below for Ubuntu:

1.  Update package index and install repository management tools:
    ```bash
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    ```

2.  Add the Intel Graphics PPA:
    ```bash
    sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
    ```

3.  Install the Intel GPU kernel package:
    ```bash
    sudo apt-get update
    sudo apt-get install -y linux-intel
    ```

## How to provide feedback

Use [GitHub Issues](/issues) for feature requests, bug reports, and minor inquiries. For broader questions and development-related discussions, use GitHub Discussions.

### Security

To report a vulnerability, refer to [Intel vulnerability reporting policy](https://www.intel.com/content/www/us/en/security-center/default.html).

## Container's default user

In most use-cases we expect that customers may want to install additional software on top of our containers. With this, the default user in these containers would be
root.
If your flow does not require root (e.g. git clone, build and test your application, push to your project artifactory), we recommend creating a dedicated non-root user,
setting up appropriate environment, and running the steps from that user rather than as root.

## License

This project is licensed under the terms of the MIT license. See [LICENSE](LICENSE) for more information.

## Notices and Disclaimers

© Intel Corporation. Intel, the Intel logo, and other Intel marks are trademarks of Intel Corporation or its subsidiaries. Other names and brands may be claimed as the property of others.