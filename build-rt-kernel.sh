#!/bin/bash
set -e

OUTDIR="$1"

if [ -z "$OUTDIR" ]; then
    echo "Usage: ./build-rt-kernel.sh <output-directory>"
    exit 1
fi

echo "=== Updating package lists ==="
apt-get update

echo "=== Installing build dependencies ==="
apt-get install -y build-essential bc bison flex libssl-dev libncurses-dev libelf-dev dwarves fakeroot wget

echo "=== Fetching Ubuntu kernel source ==="
cd /usr/src
apt-get source linux-image-unsigned-$(uname -r) || true

# Find the extracted kernel directory
KERNEL_DIR=$(find . -maxdepth 1 -type d -name "linux-*")
cd "$KERNEL_DIR"

echo "=== Downloading PREEMPT_RT patch ==="
VERSION=$(make kernelversion)
MAJOR=$(echo $VERSION | cut -d. -f1)
MINOR=$(echo $VERSION | cut -d. -f2)
PATCHLEVEL=$(echo $VERSION | cut -d. -f3)

RT_PATCH="patch-${VERSION}-rt.patch.gz"
wget https://cdn.kernel.org/pub/linux/kernel/projects/rt/${MAJOR}.${MINOR}/older/${RT_PATCH}
gunzip "${RT_PATCH}"
patch -p1 < "patch-${VERSION}-rt.patch"

echo "=== Copying default config ==="
cp /boot/config-$(uname -r) .config

echo "=== Enabling PREEMPT_RT ==="
scripts/config --disable CONFIG_PREEMPT_NONE
scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
scripts/config --enable CONFIG_PREEMPT
scripts/config --enable CONFIG_PREEMPT_RT

echo "=== Preparing kernel ==="
yes "" | make oldconfig

echo "=== Building kernel (this may take a while) ==="
make -j"$(nproc)" deb-pkg LOCALVERSION=-rt

echo "=== Copying artifacts to output directory ==="
cp ../*.deb "$OUTDIR"

echo "=== Kernel build complete ==="
