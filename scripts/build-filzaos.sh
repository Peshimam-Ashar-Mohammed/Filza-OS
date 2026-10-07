#!/bin/bash

set -e

# ============================================================
# FILZAOS BUILD SYSTEM
# Ubuntu 24.04.5 LTS base
#
# IMPORTANT:
# - Temporary Linux filesystem lives inside WSL native storage.
# - Final ISO lives on D:
# - Original Ubuntu initrd is preserved.
# - BIOS + UEFI boot structure is replayed from the source ISO.
# ============================================================

PROJECT="/mnt/d/FilzaOS"
SOURCE="$PROJECT/source/ubuntu.iso"
BUILD="$PROJECT/build"
CONFIG="$PROJECT/config"

# Native WSL filesystem — DO NOT put Linux rootfs on /mnt/d
WORKSPACE="$HOME/filzaos-workspace"

# ------------------------------------------------------------
# CHECK REQUIRED TOOLS
# ------------------------------------------------------------

for TOOL in xorriso unsquashfs mksquashfs rsync sha256sum; do
    if ! command -v "$TOOL" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found: $TOOL"
        exit 1
    fi
done

# ------------------------------------------------------------
# CHECK SOURCE ISO
# ------------------------------------------------------------

if [ ! -f "$SOURCE" ]; then
    echo
    echo "ERROR: Ubuntu ISO not found:"
    echo "$SOURCE"
    exit 1
fi

# ------------------------------------------------------------
# AUTO VERSION
# ------------------------------------------------------------

LATEST=$(
    find "$BUILD" -maxdepth 1 -type f \
        -name 'FilzaOS-v1.0.*.iso' \
        -printf '%f\n' 2>/dev/null |
    sed -E 's/FilzaOS-v1\.0\.([0-9]+)\.iso/\1/' |
    sort -n |
    tail -1
)

if [ -z "$LATEST" ]; then
    PATCH=1
else
    PATCH=$((LATEST + 1))
fi

VERSION="1.0.$PATCH"
OUTPUT="$BUILD/FilzaOS-v$VERSION.iso"

# ------------------------------------------------------------
# HEADER
# ------------------------------------------------------------

echo
echo "============================================================"
echo "                    FILZAOS BUILD"
echo "============================================================"
echo "Version       : $VERSION"
echo "Source        : $SOURCE"
echo "Workspace     : $WORKSPACE"
echo "Output        : $OUTPUT"
echo "============================================================"
echo

# ------------------------------------------------------------
# CLEAN BUILD
# ------------------------------------------------------------

echo "[1/10] Cleaning..."

sudo rm -rf "$WORKSPACE"

mkdir -p "$WORKSPACE"
mkdir -p "$BUILD"

# Remove previous generated FilzaOS ISOs
find "$BUILD" \
    -maxdepth 1 \
    -type f \
    -name 'FilzaOS-v1.0.*.iso' \
    -delete

echo "Clean."

# ------------------------------------------------------------
# EXTRACT MAIN SQUASHFS
# ------------------------------------------------------------

echo
echo "[2/10] Extracting main SquashFS..."

xorriso \
    -osirrox on \
    -indev "$SOURCE" \
    -cpx /casper/minimal.squashfs \
    "$WORKSPACE/minimal.squashfs"

echo "Main SquashFS extracted."

# ------------------------------------------------------------
# EXTRACT LIVE SQUASHFS
# ------------------------------------------------------------

echo
echo "[3/10] Extracting live SquashFS..."

xorriso \
    -osirrox on \
    -indev "$SOURCE" \
    -cpx /casper/minimal.standard.live.squashfs \
    "$WORKSPACE/minimal.standard.live.squashfs"

echo "Live SquashFS extracted."

# ------------------------------------------------------------
# UNSQUASH MAIN ROOTFS
# ------------------------------------------------------------

echo
echo "[4/10] Extracting main Linux root filesystem..."

sudo unsquashfs \
    -d "$WORKSPACE/rootfs" \
    "$WORKSPACE/minimal.squashfs"

ROOTFS="$WORKSPACE/rootfs"

echo "Main rootfs extracted correctly."

# ------------------------------------------------------------
# UNSQUASH LIVE ROOTFS
# ------------------------------------------------------------

echo
echo "[5/10] Extracting live-session filesystem..."

sudo unsquashfs \
    -d "$WORKSPACE/live-rootfs" \
    "$WORKSPACE/minimal.standard.live.squashfs"

LIVE_ROOTFS="$WORKSPACE/live-rootfs"

echo "Live rootfs extracted correctly."

# ------------------------------------------------------------
# APPLY FILZAOS CONFIG
# ------------------------------------------------------------

echo
echo "[6/10] Applying FilzaOS configuration..."

if [ -d "$CONFIG" ]; then

    sudo cp -a \
        "$CONFIG/." \
        "$ROOTFS/"

else

    echo "WARNING: config directory not found."
fi

# ------------------------------------------------------------
# FILZAOS RELEASE
# ------------------------------------------------------------

sudo mkdir -p "$ROOTFS/etc"

sudo tee "$ROOTFS/etc/filzaos-release" >/dev/null <<EOF
FILZAOS_NAME="FilzaOS"
FILZAOS_VERSION="$VERSION"
FILZAOS_CODENAME="Noble"
FILZAOS_BASE="Ubuntu 24.04.5 LTS"
FILZAOS_ARCH="amd64"
EOF

# ------------------------------------------------------------
# FILZAOS THEME
# ------------------------------------------------------------

if [ -f "$ROOTFS/etc/filzaos/theme.conf" ]; then

    sudo sed -i \
        "s/^FILZAOS_VERSION=.*/FILZAOS_VERSION=\"$VERSION\"/" \
        "$ROOTFS/etc/filzaos-release"

fi

# ------------------------------------------------------------
# HOSTNAME
# ------------------------------------------------------------

echo "filzaos" | sudo tee "$ROOTFS/etc/hostname" >/dev/null

sudo tee "$ROOTFS/etc/hosts" >/dev/null <<'EOF'
127.0.0.1       localhost
127.0.1.1       filzaos

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# ------------------------------------------------------------
# SCRIPT PERMISSIONS
# ------------------------------------------------------------

echo
echo "Fixing FilzaOS executable permissions..."

for FILE in \
    "$ROOTFS/usr/local/bin/filza-info" \
    "$ROOTFS/usr/local/bin/filza-sys" \
    "$ROOTFS/usr/local/bin/filza-net" \
    "$ROOTFS/usr/local/bin/portscan" \
    "$ROOTFS/usr/local/bin/jan" \
    "$ROOTFS/usr/local/bin/filzaos-theme-start" \
    "$ROOTFS/usr/local/bin/filzaos-terminal-theme" \
    "$ROOTFS/usr/local/bin/filzaos-session-init"
do

    if [ -f "$FILE" ]; then
        sudo chmod +x "$FILE"
    fi

done

# ------------------------------------------------------------
# DESKTOP README
# ------------------------------------------------------------

sudo mkdir -p "$ROOTFS/etc/skel/Desktop"

sudo tee "$ROOTFS/etc/skel/Desktop/FilzaOS-README.txt" >/dev/null <<'EOF'
FILZAOS

Your system. Your way.

FilzaOS Linux Remix
EOF

# ------------------------------------------------------------
# REMOVE UBUNTU INSTALLER
# ------------------------------------------------------------

echo
echo "[7/10] Removing Ubuntu Desktop Installer..."

# Main filesystem
sudo rm -f \
    "$ROOTFS/var/lib/snapd/desktop/applications/ubuntu-desktop-bootstrap_ubuntu-desktop-bootstrap.desktop" \
    "$ROOTFS/usr/lib/systemd/user/ubuntu-desktop-installer.service" \
    "$ROOTFS/etc/systemd/user/graphical-session.target.wants/ubuntu-desktop-installer.service"

# Live filesystem
sudo rm -f \
    "$LIVE_ROOTFS/var/lib/snapd/desktop/applications/ubuntu-desktop-bootstrap_ubuntu-desktop-bootstrap.desktop" \
    "$LIVE_ROOTFS/usr/lib/systemd/user/ubuntu-desktop-installer.service" \
    "$LIVE_ROOTFS/etc/systemd/user/graphical-session.target.wants/ubuntu-desktop-installer.service"

echo "Installer launcher removed."

# ------------------------------------------------------------
# LIVE SESSION CONFIG
# ------------------------------------------------------------

echo
echo "Configuring FilzaOS live session..."

sudo mkdir -p "$LIVE_ROOTFS/etc"

sudo tee "$LIVE_ROOTFS/etc/casper.conf" >/dev/null <<'EOF'
# FilzaOS live-session configuration

export USERNAME="filzaos"
export USERFULLNAME="FilzaOS Live User"
export HOST="filzaos"
export BUILD_SYSTEM="FilzaOS"
export FLAVOUR="FilzaOS"
EOF

# ------------------------------------------------------------
# REBUILD MAIN SQUASHFS
# ------------------------------------------------------------

echo
echo "[8/10] Rebuilding main SquashFS..."

rm -f "$WORKSPACE/FilzaOS-minimal.squashfs"

sudo mksquashfs \
    "$ROOTFS" \
    "$WORKSPACE/FilzaOS-minimal.squashfs" \
    -comp xz \
    -b 1M \
    -noappend

echo "Main SquashFS rebuilt."

# ------------------------------------------------------------
# REBUILD LIVE SQUASHFS
# ------------------------------------------------------------

echo
echo "Rebuilding live-session SquashFS..."

rm -f "$WORKSPACE/FilzaOS-standard-live.squashfs"

sudo mksquashfs \
    "$LIVE_ROOTFS" \
    "$WORKSPACE/FilzaOS-standard-live.squashfs" \
    -comp xz \
    -b 1M \
    -noappend

echo "Live SquashFS rebuilt."

# ------------------------------------------------------------
# COPY ORIGINAL SHA256SUMS
# ------------------------------------------------------------

echo
echo "Extracting original SHA256SUMS..."

rm -f "$WORKSPACE/SHA256SUMS"

xorriso \
    -osirrox on \
    -indev "$SOURCE" \
    -cpx /casper/SHA256SUMS \
    "$WORKSPACE/SHA256SUMS"

# ------------------------------------------------------------
# BUILD ISO
# ------------------------------------------------------------

echo
echo "[9/10] Building FilzaOS ISO..."

rm -f "$OUTPUT"

xorriso \
    -indev "$SOURCE" \
    -outdev "$OUTPUT" \
    -map "$WORKSPACE/FilzaOS-minimal.squashfs" \
        /casper/minimal.squashfs \
    -map "$WORKSPACE/FilzaOS-standard-live.squashfs" \
        /casper/minimal.standard.live.squashfs \
    -map "$WORKSPACE/SHA256SUMS" \
        /casper/SHA256SUMS \
    -volid "FILZAOS_$VERSION" \
    -boot_image any replay \
    -commit \
    -end

# ------------------------------------------------------------
# VERIFY ISO
# ------------------------------------------------------------

echo
echo "[10/10] Verifying build..."

if [ ! -f "$OUTPUT" ]; then

    echo
    echo "ERROR: ISO was not created."
    exit 1

fi

SIZE=$(du -h "$OUTPUT" | cut -f1)
SHA256=$(sha256sum "$OUTPUT" | awk '{print $1}')

echo
echo "============================================================"
echo "                 FILZAOS BUILD COMPLETE"
echo "============================================================"
echo
echo "Version        : $VERSION"
echo "ISO            : $OUTPUT"
echo "Size           : $SIZE"
echo "SHA256         : $SHA256"
echo
echo "Installer      : REMOVED"
echo "Original initrd: PRESERVED"
echo "BIOS           : PRESERVED"
echo "UEFI           : PRESERVED"
echo "============================================================"
echo

# ------------------------------------------------------------
# CLEAN WSL WORKSPACE
# ------------------------------------------------------------

echo "Cleaning temporary WSL workspace..."

sudo rm -rf "$WORKSPACE"

echo
echo "============================================================"
echo " FilzaOS v$VERSION READY"
echo "============================================================"
echo
echo "ISO:"
echo "$OUTPUT"
echo
