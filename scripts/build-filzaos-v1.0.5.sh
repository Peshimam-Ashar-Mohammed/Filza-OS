#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="/mnt/d/FilzaOS"
SOURCE="$PROJECT/source/ubuntu.iso"
CONFIG="$PROJECT/config"
BUILD="$PROJECT/build"

VERSION="1.0.5"
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

echo "[1/9] Checking build environment..."

for cmd in xorriso unsquashfs mksquashfs sha256sum python3; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: Missing command: $cmd"
        exit 1
    }
done

[[ -f "$SOURCE" ]] || {
    echo "ERROR: Source ISO missing:"
    echo "$SOURCE"
    exit 1
}

[[ -d "$CONFIG" ]] || {
    echo "ERROR: FilzaOS config missing:"
    echo "$CONFIG"
    exit 1
}

[[ -x "$CONFIG/usr/local/bin/filzaos-startup" ]] || {
    echo "ERROR: FilzaOS startup script missing:"
    echo "$CONFIG/usr/local/bin/filzaos-startup"
    exit 1
}

[[ -f "$CONFIG/etc/xdg/autostart/filzaos-startup.desktop" ]] || {
    echo "ERROR: FilzaOS autostart entry missing:"
    echo "$CONFIG/etc/xdg/autostart/filzaos-startup.desktop"
    exit 1
}

mkdir -p "$BUILD" "$WORKSPACE"

sudo chown -R "$USER:$USER" "$WORKSPACE"

echo "Environment OK."
echo

echo "[2/9] Preparing native WSL workspace..."

rm -rf "$ROOTFS" "$LIVE_ROOTFS"

rm -f \
    "$MINIMAL_SRC" \
    "$LIVE_SRC" \
    "$MINIMAL_OUT" \
    "$LIVE_OUT" \
    "$GRUB_CFG" \
    "$SHA256S"

echo "Workspace:"
echo "$WORKSPACE"
echo

echo "[3/9] Extracting Ubuntu filesystem..."

xorriso \
    -osirrox on \
    -indev "$SOURCE" \
    -extract /casper/minimal.squashfs "$MINIMAL_SRC" \
    -extract /casper/minimal.standard.live.squashfs "$LIVE_SRC" \
    -extract /boot/grub/grub.cfg "$GRUB_CFG" \
    -extract /casper/SHA256SUMS "$SHA256S" \
    -end

sudo chown -R "$USER:$USER" "$WORKSPACE"

chmod u+rw "$GRUB_CFG"
chmod u+rw "$SHA256S"

echo
echo "Extracting main filesystem..."

sudo unsquashfs \
    -d "$ROOTFS" \
    "$MINIMAL_SRC"

echo
echo "Extracting live filesystem..."

sudo unsquashfs \
    -d "$LIVE_ROOTFS" \
    "$LIVE_SRC"

sudo chown -R "$USER:$USER" "$ROOTFS"
sudo chown -R "$USER:$USER" "$LIVE_ROOTFS"

echo
echo "[4/9] Applying FilzaOS configuration..."

apply_filzaos() {

    local FS="$1"

    mkdir -p \
        "$FS/usr/local/bin" \
        "$FS/usr/local/sbin" \
        "$FS/usr/share/backgrounds" \
        "$FS/usr/share/icons" \
        "$FS/usr/share/themes" \
        "$FS/etc/profile.d" \
        "$FS/etc/xdg/autostart"

    # --------------------------------------------------------
    # FilzaOS release information
    # --------------------------------------------------------

    cp \
        "$CONFIG/etc/filzaos-release" \
        "$FS/etc/filzaos-release"

    sed -i \
        "s/^FILZAOS_VERSION=.*/FILZAOS_VERSION=\"${VERSION}\"/" \
        "$FS/etc/filzaos-release"

    # --------------------------------------------------------
    # Hostname
    # --------------------------------------------------------

    printf 'filzaos\n' > "$FS/etc/hostname"

    # --------------------------------------------------------
    # FilzaOS commands
    # --------------------------------------------------------

    for file in \
        filza-info \
        filza-net \
        filza-sys \
        portscan \
        jan
    do
        if [[ -f "$CONFIG/usr/local/bin/$file" ]]; then
            cp \
                "$CONFIG/usr/local/bin/$file" \
                "$FS/usr/local/bin/$file"

            chmod +x "$FS/usr/local/bin/$file"
        fi
    done

    # --------------------------------------------------------
    # Wallpaper
    # --------------------------------------------------------

    if [[ -d "$CONFIG/usr/share/backgrounds" ]]; then
        cp -a \
            "$CONFIG/usr/share/backgrounds/." \
            "$FS/usr/share/backgrounds/"
    fi

    # --------------------------------------------------------
    # FilzaOS icon theme
    # --------------------------------------------------------

    if [[ -d "$CONFIG/usr/share/icons" ]]; then
        cp -a \
            "$CONFIG/usr/share/icons/." \
            "$FS/usr/share/icons/"
    fi

    # --------------------------------------------------------
    # FilzaOS GTK theme
    # --------------------------------------------------------

    if [[ -d "$CONFIG/usr/share/themes" ]]; then
        cp -a \
            "$CONFIG/usr/share/themes/." \
            "$FS/usr/share/themes/"
    fi

    # --------------------------------------------------------
    # Safe profile customization
    # --------------------------------------------------------

    if [[ -d "$CONFIG/etc/profile.d" ]]; then

        for file in "$CONFIG/etc/profile.d/"*.sh; do

            [[ -f "$file" ]] || continue

            case "$(basename "$file")" in
                filzaos-theme*)
                    continue
                    ;;
            esac

            cp "$file" "$FS/etc/profile.d/"

        done

    fi

    # --------------------------------------------------------
    # Remove OLD problematic theme autostart
    # --------------------------------------------------------

    rm -f \
        "$FS/etc/xdg/autostart/filzaos-theme.desktop" \
        "$FS/usr/local/bin/filzaos-theme-start" \
        "$FS/usr/local/sbin/filzaos-theme-start" \
        2>/dev/null || true

    # --------------------------------------------------------
    # Install NEW safe startup script
    # --------------------------------------------------------

    cp \
        "$CONFIG/usr/local/bin/filzaos-startup" \
        "$FS/usr/local/bin/filzaos-startup"

    chmod +x \
        "$FS/usr/local/bin/filzaos-startup"

    cp \
        "$CONFIG/etc/xdg/autostart/filzaos-startup.desktop" \
        "$FS/etc/xdg/autostart/filzaos-startup.desktop"

    # --------------------------------------------------------
    # Remove any duplicate old FilzaOS theme autostart
    # --------------------------------------------------------

    find "$FS/etc/xdg/autostart" \
        -type f \
        -iname '*filzaos*theme*' \
        -delete 2>/dev/null || true

}

echo
echo "Applying to main filesystem..."
apply_filzaos "$ROOTFS"

echo
echo "Applying to live filesystem..."
apply_filzaos "$LIVE_ROOTFS"

echo
echo "FilzaOS customization installed."

echo
echo "[5/9] Removing Ubuntu installer..."

remove_installer() {

    local FS="$1"

    rm -f \
        "$FS/usr/share/applications/ubiquity.desktop" \
        "$FS/usr/share/applications/ubuntu-desktop-installer.desktop" \
        "$FS/usr/share/applications/install-ubuntu.desktop" \
        "$FS/usr/share/applications/calamares.desktop" \
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

echo "Ubuntu installer removed."

echo
echo "[6/9] Adding FilzaOS boot diagnostics..."

add_boot_diagnostics() {

    local FS="$1"

    mkdir -p \
        "$FS/usr/local/sbin" \
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

    chmod +x \
        "$FS/usr/local/sbin/filzaos-boot-diagnostics"

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

add_boot_diagnostics "$ROOTFS"
add_boot_diagnostics "$LIVE_ROOTFS"

echo "Boot diagnostics installed."

echo
echo "[7/9] Configuring GRUB diagnostics..."

chmod u+rw "$GRUB_CFG"

python3 - "$GRUB_CFG" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])

text = path.read_text(encoding="utf-8")

text = re.sub(r'\bquiet\b', '', text)
text = re.sub(r'\bsplash\b', '', text)

lines = []

for line in text.splitlines():

    if "/casper/vmlinuz" in line:

        for arg in (
            "plymouth.enable=0",
            "systemd.show_status=1",
            "loglevel=4"
        ):
            if arg not in line:
                line += " " + arg

    lines.append(line)

text = "\n".join(lines) + "\n"

if "echo 'FILZAOS'" not in text:

    text = (
        "echo 'FILZAOS'\n"
        "echo '--------------------'\n"
        "echo 'Loading system...'\n\n"
        + text
    )

path.write_text(text, encoding="utf-8")
PY

echo "GRUB diagnostics configured."

echo
echo "[8/9] Rebuilding SquashFS..."

sudo chown -R root:root "$ROOTFS"
sudo chown -R root:root "$LIVE_ROOTFS"

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
echo "[9/9] Building bootable ISO..."

(
    cd "$WORKSPACE"

    rm -f "$SHA256S"

    sha256sum \
        "$MINIMAL_OUT" \
        "$LIVE_OUT" \
        > "$SHA256S"
)

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
    -volid "FILZAOS_1.0.5" \
    -boot_image any replay \
    -commit \
    -end

echo
echo "============================================================"
echo "                 FILZAOS v${VERSION} READY"
echo "============================================================"
echo
echo "ISO:"
echo "$ISO_OUT"
echo
echo "Windows:"
echo "D:\\FilzaOS\\build\\FilzaOS-v1.0.5.iso"
echo
echo "Desktop:"
echo "  [✓] FilzaOS wallpaper"
echo "  [✓] FilzaOS GTK theme"
echo "  [✓] FilzaOS purple icons/folders"
echo "  [✓] Dark mode"
echo "  [✓] FilzaOS startup script"
echo "  [✓] Startup runs after GNOME loads"
echo
echo "Boot:"
echo "  [✓] BIOS preserved"
echo "  [✓] UEFI preserved"
echo "  [✓] Original initrd preserved"
echo "  [✓] Installer removed"
echo "  [✓] GNOME session untouched"
echo
echo "Output:"
ls -lh "$ISO_OUT"
echo
echo "SHA256:"
sha256sum "$ISO_OUT"
echo
echo "============================================================"
