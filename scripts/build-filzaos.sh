#!/bin/bash
set -e

PROJECT="/mnt/d/FilzaOS"
SOURCE="$PROJECT/source/ubuntu.iso"
WORKSPACE="$PROJECT/workspace"
BUILD="$PROJECT/build"

ROOTFS="$HOME/filzaos-rootfs"

echo "======================================"
echo "        FILZAOS BUILD SYSTEM"
echo "======================================"

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: Ubuntu ISO not found:"
    echo "$SOURCE"
    exit 1
fi

echo "[1/6] Cleaning previous build..."

rm -rf "$ROOTFS"
rm -f "$WORKSPACE/FilzaOS-minimal.squashfs"
rm -f "$BUILD/FilzaOS.iso"

mkdir -p "$WORKSPACE"
mkdir -p "$BUILD"

echo "[2/6] Extracting Ubuntu filesystem..."

xorriso -osirrox on \
    -indev "$SOURCE" \
    -cpx /casper/minimal.squashfs \
    "$WORKSPACE/minimal.squashfs"

sudo unsquashfs -d "$ROOTFS" \
    "$WORKSPACE/minimal.squashfs"

echo "[3/6] Applying FilzaOS configuration..."

sudo cp -a "$PROJECT/config/." "$ROOTFS/"

sudo chmod +x "$ROOTFS/usr/local/bin/filza-info"
sudo chmod +x "$ROOTFS/usr/local/bin/filzaos-theme-start"

echo "[4/6] Building FilzaOS filesystem..."

sudo mksquashfs \
    "$ROOTFS" \
    "$WORKSPACE/FilzaOS-minimal.squashfs" \
    -comp xz \
    -b 131072 \
    -noappend

echo "[5/6] Updating SHA256SUMS..."

xorriso -osirrox on \
    -indev "$SOURCE" \
    -cpx /casper/SHA256SUMS \
    "$WORKSPACE/original-SHA256SUMS"

HASH=$(sha256sum "$WORKSPACE/FilzaOS-minimal.squashfs" | awk '{print $1}')

grep -v "minimal.squashfs" \
    "$WORKSPACE/original-SHA256SUMS" \
    > "$WORKSPACE/SHA256SUMS"

echo "$HASH *minimal.squashfs" >> "$WORKSPACE/SHA256SUMS"

echo "[6/6] Building FilzaOS ISO..."

xorriso \
    -indev "$SOURCE" \
    -outdev "$BUILD/FilzaOS.iso" \
    -map "$WORKSPACE/FilzaOS-minimal.squashfs" /casper/minimal.squashfs \
    -map "$WORKSPACE/SHA256SUMS" /casper/SHA256SUMS \
    -volid "FILZAOS_1.0" \
    -boot_image any replay \
    -commit \
    -end

echo ""
echo "======================================"
echo "      FILZAOS BUILD COMPLETE"
echo "======================================"
echo ""
echo "ISO:"
echo "$BUILD/FilzaOS.iso"
echo ""
echo "SHA256:"
sha256sum "$BUILD/FilzaOS.iso"
