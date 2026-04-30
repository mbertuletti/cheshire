# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jannis Schoenleber <janniss@iis.ee.ethz.ch>

FROM ubuntu:22.04

RUN apt update && apt upgrade -y && apt install -y curl python3 python3-pip build-essential git cmake device-tree-compiler gdisk wget file cpio unzip rsync bc pkg-config libtool-bin autoconf automake bison flex locales libtinfo5 libxrender1 libxtst6 libxi6 libfreetype6 libfontconfig1 && \
    locale-gen en_US.UTF-8

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8

# riscv-gnu-compiler (GCC 13, supports zifencei and other modern extensions)
ARG RISCV_GCC_VERSION=2024.02.02
RUN curl -Ls -o riscv-gcc.tar.gz https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${RISCV_GCC_VERSION}/riscv64-elf-ubuntu-22.04-gcc-nightly-${RISCV_GCC_VERSION}-nightly.tar.gz && \
    mkdir -p /tools/riscv && chmod 777 /tools/riscv && \
    tar -C /tools/riscv -xf riscv-gcc.tar.gz --strip-components=1 && \
    rm riscv-gcc.tar.gz

ENV PATH="${PATH}:/tools/riscv/bin"

# python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

# mark mounted workspaces as safe for git
RUN git config --global --add safe.directory '*'

# bender
ARG BENDER_VERSION=0.27.1
RUN mkdir -p /tools/bender && chmod 777 /tools/bender && \
    curl -Ls -o /tmp/bender.tar.gz https://github.com/pulp-platform/bender/releases/download/v${BENDER_VERSION}/bender-${BENDER_VERSION}-x86_64-linux-gnu-ubuntu22.04.tar.gz && \
    tar -C /tools/bender -xf /tmp/bender.tar.gz && \
    rm /tmp/bender.tar.gz

ENV PATH="${PATH}:/tools/bender"

# slang
ARG SLANG_VERSION=v2.0
RUN mkdir -p /tools/slang && chmod 777 /tools/slang && \
    cd /tools/slang && \
    curl -Ls -o slang.tar.gz https://github.com/MikePopoloski/slang/archive/refs/tags/${SLANG_VERSION}.tar.gz && \
    tar -xf slang.tar.gz && cd slang-$(echo ${SLANG_VERSION} | sed 's/^v//') && \
    cmake -B build && cmake --build build -j$(nproc) && \
    cmake --install build --strip && \
    rm -rf /tools/slang

# SSH: redirect HTTPS to SSH for GitHub, ignore host ssh config, setup known_hosts
RUN git config --global url."git@github.com:".insteadOf "https://github.com/" && \
    mkdir -p /root/.ssh_local && ssh-keyscan github.com >> /root/.ssh_local/known_hosts 2>/dev/null && \
    git config --global core.sshCommand "ssh -F /dev/null -o UserKnownHostsFile=/root/.ssh_local/known_hosts"

