FROM ubuntu:22.04

ARG ZIG_VERSION=0.15.2

# Install dependencies needed to download and extract Zig
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN curl -L https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz \
    | tar -xJ -C /usr/local && \
    ln -s /usr/local/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

WORKDIR /app

# Copy dependency manifest first for better layer caching
COPY build.zig build.zig.zon ./

# Fetch dependencies (cached as long as build.zig.zon doesn't change)
RUN zig build --fetch

# Copy sources
COPY src/ src/
COPY c-src/ c-src/

# Build — mirrors what update-demo.sh does
RUN zig build -Dtarget=x86_64-linux-gnu --release=fast --summary all
