#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="/mnt/d/FilzaOS"
SOURCE="$PROJECT/source/ubuntu.iso"
CONFIG="$PROJECT/config"
BUILD="$PROJECT/build"

VERSION="1.0.2"
ISO_OUT="$BUILD/FilzaOS-v${VERSION}.iso"

WORKSPACE="$HOME/filzaos-workspace"

MINIMAL_SRC="$WORKSPACE/minimal.squashfs"
LIVE_SRC="$WORKSPACE/minimal.standard.live.squashfs"

ROOTFS="$WORKSPACE/rootfs"
LIVE_ROOTFS="$WORKSPACE/live-rootfs"

MINIMAL_OUT="$WORKSPACE/minimal-custom.squashfs"
LIVE_OUT="$WORKSPACE/live-custom.squashfs"

GRUB_CFG="$WORKSPACE/grub.cfg"
SHA256S="$WORKSPACE/SHA256SUMS"

echo
echo "============================================================"
echo "                 FILZAOS v${VERSION} BUILD"
echo "============================================================"
echo

cleanup() {
    echo
    echo "[CLEANUP] Restoring workspace ownership..."
    sudo chown -R "$USER:$USER" "$WORKSPACE" 2>/dev/null || true
}
trap cleanup EXIT

echo "[1/9] Checking environment..."

for cmd in xorriso unsquashfs mksquashfs sha256sum python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing command: $cmd"
        exit 1
    fi
done

if [[ ! -f "$SOURCE" ]]; then
    echo "ERROR: Source ISO not found:"
    echo "$SOURCE"
    exit 1
fi

if [[ ! -d "$CONFIG" ]]; then
    echo "ERROR: FilzaOS config directory not found:"
    echo "$CONFIG"
    exit 1
fi

mkdir -p "$BUILD"
mkdir -p "$WORKSPACE"

# Make sure previous sudo-created files never block the build.
sudo chown -R "$USER:$USER" "$WORKSPACE"

echo "Environment OK."
echo

echo "[2/9] Preparing native WSL workspace..."

rm -rf "$ROOTFS" "$LIVE_ROOTFS"
rm -f "$MINIMAL_OUT" "$LIVE_OUT"

echo "Workspace:"
echo "$WORKSPACE"
echo

echo "[3/9] Extracting Ubuntu filesystem..."

if [[ ! -f "$MINIMAL_SRC" || ! -f "$LIVE_SRC" ]]; then

    echo "Reading SquashFS files from source ISO..."

    xorriso \
        -osirrox on \
        -indev "$SOURCE" \
        -extract /casper/minimal.squashfs "$MINIMAL_SRC" \
        -extract /casper/minimal.standard.live.squashfs "$LIVE_SRC" \
        -extract /boot/grub/grub.cfg "$GRUB_CFG" \
        -extract /casper/SHA256SUMS "$SHA256S" \
        -end

fi

sudo chown -R "$USER:$USER" "$WORKSPACE"

echo
echo "Extracting main root filesystem..."
sudo unsquashfs \
    -d "$ROOTFS" \
    "$MINIMAL_SRC"

echo
echo "Extracting live root filesystem..."
sudo unsquashfs \
    -d "$LIVE_ROOTFS" \
    "$LIVE_SRC"

sudo chown -R "$USER:$USER" "$ROOTFS"
sudo chown -R "$USER:$USER" "$LIVE_ROOTFS"

echo
echo "[4/9] Applying FilzaOS configuration..."

# Copy the complete FilzaOS configuration into BOTH filesystems.
cp -a "$CONFIG/." "$ROOTFS/"
cp -a "$CONFIG/." "$LIVE_ROOTFS/"

# Ensure important FilzaOS directories exist.
mkdir -p \
    "$ROOTFS/usr/local/bin" \
    "$ROOTFS/usr/local/sbin" \
    "$ROOTFS/etc/profile.d" \
    "$LIVE_ROOTFS/usr/local/bin" \
    "$LIVE_ROOTFS/usr/local/sbin" \
    "$LIVE_ROOTFS/etc/profile.d"

# Update FilzaOS version.
if [[ -f "$ROOTFS/etc/filzaos-release" ]]; then
    sed -i \
        -e "s/^FILZAOS_VERSION=.*/FILZAOS_VERSION=\"${VERSION}\"/" \
        "$ROOTFS/etc/filzaos-release"
fi

if [[ -f "$LIVE_ROOTFS/etc/filzaos-release" ]]; then
    sed -i \
        -e "s/^FILZAOS_VERSION=.*/FILZAOS_VERSION=\"${VERSION}\"/" \
        "$LIVE_ROOTFS/etc/filzaos-release"
fi

# FilzaOS hostname.
printf 'filzaos\n' > "$ROOTFS/etc/hostname"
printf 'filzaos\n' > "$LIVE_ROOTFS/etc/hostname"

echo
echo "FilzaOS configuration copied."

# ------------------------------------------------------------
# Preserve / reinforce FilzaOS visual configuration
# ------------------------------------------------------------

echo "Checking FilzaOS visual customization..."

for FS in "$ROOTFS" "$LIVE_ROOTFS"; do

    mkdir -p "$FS/usr/share/backgrounds"
    mkdir -p "$FS/usr/share/icons"
    mkdir -p "$FS/usr/share/themes"

    # Ensure FilzaOS wallpaper from config remains installed.
    if [[ -d "$CONFIG/usr/share/backgrounds" ]]; then
        cp -a "$CONFIG/usr/share/backgrounds/." \
            "$FS/usr/share/backgrounds/"
    fi

    # Preserve custom icons / purple folders.
    if [[ -d "$CONFIG/usr/share/icons" ]]; then
        cp -a "$CONFIG/usr/share/icons/." \
            "$FS/usr/share/icons/"
    fi

    # Preserve custom GTK / desktop themes.
    if [[ -d "$CONFIG/usr/share/themes" ]]; then
        cp -a "$CONFIG/usr/share/themes/." \
            "$FS/usr/share/themes/"
    fi

    # Preserve terminal configuration.
    if [[ -d "$CONFIG/etc/skel" ]]; then
        cp -a "$CONFIG/etc/skel/." \
            "$FS/etc/skel/"
    fi

    # Preserve profile scripts.
    if [[ -d "$CONFIG/etc/profile.d" ]]; then
        cp -a "$CONFIG/etc/profile.d/." \
            "$FS/etc/profile.d/"
    fi

done

echo "Wallpaper/icons/themes/terminal configuration preserved."

echo
echo "[5/9] Removing Ubuntu installer..."

remove_installer() {
    local FS="$1"

    rm -f \
        "$FS/usr/share/applications/ubiquity.desktop" \
        "$FS/usr/share/applications/ubuntu-desktop-installer.desktop" \
        "$FS/usr/share/applications/calamares.desktop" \
        "$FS/usr/share/applications/install-ubuntu.desktop" \
        2>/dev/null || true

    rm -rf \
        "$FS/usr/lib/ubiquity" \
        "$FS/usr/share/ubiquity" \
        "$FS/usr/lib/calamares" \
        "$FS/usr/share/calamares" \
        2>/dev/null || true
}

remove_installer "$ROOTFS"
remove_installer "$LIVE_ROOTFS"

echo "Ubuntu installer components removed."

echo
echo "[6/9] Adding FilzaOS boot diagnostics..."

create_boot_diagnostic() {

    local FS="$1"

    mkdir -p \
        "$FS/usr/local/sbin" \
        "$FS/etc/systemd/system" \
        "$FS/etc/systemd/system/multi-user.target.wants"

    cat > "$FS/usr/local/sbin/filzaos-boot-diagnostics" <<'SCRIPT'
#!/usr/bin/env bash

MESSAGE="
FILZAOS
--------------------
Starting live environment...
Starting graphics...
"

for TTY in /dev/tty1 /dev/console; do
    if [[ -w "$TTY" ]]; then
        printf '%s\n' "$MESSAGE" > "$TTY" 2>/dev/null || true
        break
    fi
done

exit 0
SCRIPT

    chmod +x "$FS/usr/local/sbin/filzaos-boot-diagnostics"

    cat > "$FS/etc/systemd/system/filzaos-boot-diagnostics.service" <<'SERVICE'
[Unit]
Description=FilzaOS Boot Diagnostics
After=local-fs.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/filzaos-boot-diagnostics
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

    ln -sf \
        /etc/systemd/system/filzaos-boot-diagnostics.service \
        "$FS/etc/systemd/system/multi-user.target.wants/filzaos-boot-diagnostics.service"
}

create_boot_diagnostic "$ROOTFS"
create_boot_diagnostic "$LIVE_ROOTFS"

echo "Boot diagnostics installed."

echo
echo "[7/9] Making GRUB diagnostics visible..."
chmod u+rw "$GRUB_CFG"
chmod u+rw "$GRUB_CFG"

python3 - "$GRUB_CFG" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])

text = path.read_text(encoding="utf-8")

# Remove graphical boot hiding.
text = re.sub(r'\bquiet\b', '', text)
text = re.sub(r'\bsplash\b', '', text)

# Add kernel diagnostics only to Linux kernel command lines.
lines = []

for line in text.splitlines():

    if "/casper/vmlinuz" in line:

        additions = [
            "plymouth.enable=0",
            "systemd.show_status=1",
            "loglevel=4"
        ]

        for arg in additions:
            if arg not in line:
                line += " " + arg

    lines.append(line)

text = "\n".join(lines) + "\n"

# Add a simple GRUB-visible FilzaOS message before boot.
if "echo 'FILZAOS'" not in text:
    text = text.replace(
        "menuentry",
        "echo 'FILZAOS'\necho '--------------------'\necho 'Loading system...'\n\nmenuentry",
        1
    )

path.write_text(text, encoding="utf-8")
PY

echo "GRUB diagnostics enabled."

echo
echo "[8/9] Rebuilding FilzaOS SquashFS..."

sudo chown -R root:root "$ROOTFS"
sudo chown -R root:root "$LIVE_ROOTFS"

rm -f "$MINIMAL_OUT" "$LIVE_OUT"

sudo mksquashfs \
    "$ROOTFS" \
    "$MINIMAL_OUT" \
    -comp xz \
    -b 1048576 \
    -noappend

sudo mksquashfs \
    "$LIVE_ROOTFS" \
    "$LIVE_OUT" \
    -comp xz \
    -b 1048576 \
    -noappend

sudo chown "$USER:$USER" \
    "$MINIMAL_OUT" \
    "$LIVE_OUT"

echo
echo "SquashFS images created."

echo
echo "[9/9] Rebuilding bootable ISO..."

# Recreate checksum file using the rebuilt images.
(
    cd "$WORKSPACE"

    sha256sum "$MINIMAL_OUT" \
        "$LIVE_OUT" \
        > "$SHA256S"
)

# Copy the original ISO structure and replace only the pieces we intentionally
# customized. xorriso replay preserves the original BIOS/UEFI boot metadata.
rm -f "$ISO_OUT"

xorriso \
    -indev "$SOURCE" \
    -outdev "$ISO_OUT" \
    -map "$MINIMAL_OUT" \
        /casper/minimal.squashfs \
    -map "$LIVE_OUT" \
        /casper/minimal.standard.live.squashfs \
    -map "$SHA256S" \
        /casper/SHA256SUMS \
    -map "$GRUB_CFG" \
        /boot/grub/grub.cfg \
    -volid "FILZAOS_1.0.2" \
    -boot_image any replay \
    -commit \
    -end

echo
echo "============================================================"
echo "                 BUILD COMPLETE"
echo "============================================================"
echo
echo "ISO:"
echo "$ISO_OUT"
echo
echo "Windows:"
echo "D:\\FilzaOS\\build\\FilzaOS-v1.0.2.iso"
echo
echo "FilzaOS customization:"
echo "  [✓] Custom wallpaper"
echo "  [✓] Purple icon/folder theme"
echo "  [✓] Purple GTK/theme files"
echo "  [✓] Purple terminal configuration"
echo "  [✓] FilzaOS commands"
echo
echo "Boot:"
echo "  [✓] BIOS preserved"
echo "  [✓] UEFI preserved"
echo "  [✓] Original initrd preserved"
echo "  [✓] Plymouth disabled for diagnostics"
echo "  [✓] GRUB diagnostics enabled"
echo "  [✓] Ubuntu installer removed"
echo "  [✓] GNOME/session NOT modified"
echo
echo "Output size:"
ls -lh "$ISO_OUT"
echo
echo "SHA256:"
sha256sum "$ISO_OUT"
echo
echo "============================================================"
