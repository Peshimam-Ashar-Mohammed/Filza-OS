#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="/mnt/d/FilzaOS"
SOURCE="$PROJECT/source/ubuntu.iso"
CONFIG="$PROJECT/config"
BUILD="$PROJECT/build"

VERSION="1.0.6"
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
echo "                 FILZAOS v${VERSION}"
echo "============================================================"
echo

cleanup() {
    echo
    echo "[CLEANUP] Restoring workspace ownership..."
    sudo chown -R "$USER:$USER" "$WORKSPACE" 2>/dev/null || true
}
trap cleanup EXIT

# ============================================================
# 1. CHECK ENVIRONMENT
# ============================================================

echo "[1/10] Checking build environment..."

for cmd in \
    xorriso \
    unsquashfs \
    mksquashfs \
    sha256sum \
    python3
do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: Missing command: $cmd"
        exit 1
    }
done

[[ -f "$SOURCE" ]] || {
    echo "ERROR: Source ISO not found:"
    echo "$SOURCE"
    exit 1
}

[[ -d "$CONFIG" ]] || {
    echo "ERROR: FilzaOS config directory not found:"
    echo "$CONFIG"
    exit 1
}

[[ -x "$CONFIG/usr/local/bin/filzaos-startup" ]] || {
    echo "ERROR: filzaos-startup is missing or not executable."
    echo "$CONFIG/usr/local/bin/filzaos-startup"
    exit 1
}

[[ -f "$CONFIG/etc/xdg/autostart/filzaos-startup.desktop" ]] || {
    echo "ERROR: FilzaOS autostart entry missing."
    exit 1
}

[[ -f "$CONFIG/usr/share/backgrounds/filzaos/filzaos.png" ]] || {
    echo "ERROR: FilzaOS wallpaper missing."
    echo "$CONFIG/usr/share/backgrounds/filzaos/filzaos.png"
    exit 1
}

echo "Build environment OK."
echo

# ============================================================
# 2. PREPARE WORKSPACE
# ============================================================

echo "[2/10] Preparing native WSL workspace..."

mkdir -p "$BUILD"
mkdir -p "$WORKSPACE"

sudo chown -R "$USER:$USER" "$WORKSPACE"

rm -rf \
    "$ROOTFS" \
    "$LIVE_ROOTFS"

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

# ============================================================
# 3. EXTRACT ORIGINAL ISO
# ============================================================

echo "[3/10] Extracting Ubuntu filesystem..."

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
echo "Filesystem extraction complete."
echo

# ============================================================
# FUNCTION: INSTALL FILZAOS CUSTOMIZATION
# ============================================================

apply_filzaos() {

    local FS="$1"

    echo "Applying FilzaOS configuration to:"
    echo "$FS"

    mkdir -p \
        "$FS/usr/local/bin" \
        "$FS/usr/local/sbin" \
        "$FS/usr/share/backgrounds" \
        "$FS/usr/share/icons" \
        "$FS/usr/share/themes" \
        "$FS/etc/profile.d" \
        "$FS/etc/xdg/autostart" \
        "$FS/etc/dconf/db/local.d"

    # ========================================================
    # FILZAOS RELEASE
    # ========================================================

    if [[ -f "$CONFIG/etc/filzaos-release" ]]; then

        cp \
            "$CONFIG/etc/filzaos-release" \
            "$FS/etc/filzaos-release"

        sed -i \
            "s/^FILZAOS_VERSION=.*/FILZAOS_VERSION=\"${VERSION}\"/" \
            "$FS/etc/filzaos-release"

    fi

    # ========================================================
    # HOSTNAME
    # ========================================================

    printf 'filzaos\n' > "$FS/etc/hostname"

    if [[ -f "$FS/etc/hosts" ]]; then

        sed -i \
            -e 's/\bubuntu\b/filzaos/g' \
            "$FS/etc/hosts" || true

    fi

    cat > "$FS/etc/issue" <<'ISSUE'
FilzaOS
Welcome to FilzaOS Linux
Kernel \r on an \m

ISSUE

    cat > "$FS/etc/issue.net" <<'ISSUE'
FilzaOS
ISSUE

    # ========================================================
    # SAFE OS-RELEASE BRANDING
    # ========================================================

    if [[ -f "$FS/etc/os-release" ]]; then

        cat > "$FS/etc/os-release" <<'OSRELEASE'
NAME="FilzaOS"
PRETTY_NAME="FilzaOS 1.0.6"
ID=filzaos
ID_LIKE=ubuntu
VERSION_ID="1.0.6"
VERSION="1.0.6 Noble"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
HOME_URL="https://github.com/Peshimam-Ashar-Mohammed/Filza-OS"
SUPPORT_URL="https://github.com/Peshimam-Ashar-Mohammed/Filza-OS"
BUG_REPORT_URL="https://github.com/Peshimam-Ashar-Mohammed/Filza-OS"
OSRELEASE

    fi

    # ========================================================
    # FILZAOS COMMANDS
    # ========================================================

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

            chmod +x \
                "$FS/usr/local/bin/$file"

        fi

    done

    # ========================================================
    # WALLPAPER
    # ========================================================

    if [[ -d "$CONFIG/usr/share/backgrounds" ]]; then

        cp -a \
            "$CONFIG/usr/share/backgrounds/." \
            "$FS/usr/share/backgrounds/"

    fi

    # ========================================================
    # ICON THEME
    # ========================================================

    if [[ -d "$CONFIG/usr/share/icons" ]]; then

        cp -a \
            "$CONFIG/usr/share/icons/." \
            "$FS/usr/share/icons/"

    fi

    # ========================================================
    # GTK THEME
    # ========================================================

    if [[ -d "$CONFIG/usr/share/themes" ]]; then

        cp -a \
            "$CONFIG/usr/share/themes/." \
            "$FS/usr/share/themes/"

    fi

    # ========================================================
    # PROFILE FILES
    # ========================================================

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

    # ========================================================
    # REMOVE OLD PROBLEMATIC THEME STARTUP
    # ========================================================

    rm -f \
        "$FS/etc/xdg/autostart/filzaos-theme.desktop" \
        "$FS/usr/local/bin/filzaos-theme-start" \
        "$FS/usr/local/sbin/filzaos-theme-start" \
        2>/dev/null || true

    # ========================================================
    # NEW SAFE FILZAOS STARTUP
    # ========================================================

    cp \
        "$CONFIG/usr/local/bin/filzaos-startup" \
        "$FS/usr/local/bin/filzaos-startup"

    chmod +x \
        "$FS/usr/local/bin/filzaos-startup"

    cp \
        "$CONFIG/etc/xdg/autostart/filzaos-startup.desktop" \
        "$FS/etc/xdg/autostart/filzaos-startup.desktop"

    # ========================================================
    # FORCE GNOME DEFAULTS
    # ========================================================

    cat > "$FS/etc/dconf/db/local.d/00-filzaos" <<'DCONF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-uri-dark='file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-options='zoom'

[org/gnome/desktop/interface]
gtk-theme='FilzaOS'
icon-theme='FilzaOS'
color-scheme='prefer-dark'
DCONF

    # ========================================================
    # DCONF PROFILE
    # ========================================================

    mkdir -p "$FS/etc/dconf/profile"

    cat > "$FS/etc/dconf/profile/user" <<'PROFILE'
user-db:user
system-db:local
PROFILE

    # Update dconf database if possible.
    if [[ -x "$FS/usr/bin/dconf" ]]; then

        chroot "$FS" \
            /usr/bin/dconf update \
            2>/dev/null || true

    fi

    # ========================================================
    # ICON CACHE
    # ========================================================

    if [[ -d "$FS/usr/share/icons/FilzaOS" ]] && \
       [[ -x "$FS/usr/sbin/gtk-update-icon-cache" ]]; then

        chroot "$FS" \
            /usr/sbin/gtk-update-icon-cache \
            -f \
            -t \
            /usr/share/icons/FilzaOS \
            2>/dev/null || true

    fi

    # ========================================================
    # REMOVE OLD FILZAOS THEME AUTOSTARTS
    # ========================================================

    find "$FS/etc/xdg/autostart" \
        -type f \
        -iname '*filzaos*theme*' \
        -delete \
        2>/dev/null || true

}

# ============================================================
# 4. APPLY CUSTOMIZATION
# ============================================================

echo "[4/10] Applying FilzaOS customization..."

apply_filzaos "$ROOTFS"
apply_filzaos "$LIVE_ROOTFS"

echo
echo "FilzaOS customization complete."
echo

# ============================================================
# 5. REMOVE UBUNTU INSTALLER
# ============================================================

echo "[5/10] Removing Ubuntu installer..."

remove_installer() {

    local FS="$1"

    # Desktop launchers
    find "$FS/usr/share/applications" \
        -type f \
        \( \
            -iname '*ubiquity*' \
            -o -iname '*ubuntu*installer*' \
            -o -iname '*install-ubuntu*' \
            -o -iname '*calamares*' \
        \) \
        -delete \
        2>/dev/null || true

    # Installer directories
    rm -rf \
        "$FS/usr/lib/ubiquity" \
        "$FS/usr/share/ubiquity" \
        "$FS/usr/lib/calamares" \
        "$FS/usr/share/calamares" \
        2>/dev/null || true

    # Live-session installer shortcuts
    find "$FS" \
        -type f \
        \( \
            -iname '*install-ubuntu*.desktop' \
            -o -iname '*ubuntu-desktop-installer*.desktop' \
            -o -iname '*ubiquity*.desktop' \
        \) \
        -delete \
        2>/dev/null || true

}

remove_installer "$ROOTFS"
remove_installer "$LIVE_ROOTFS"

echo "Ubuntu installer components removed."
echo

# ============================================================
# 6. BOOT DIAGNOSTICS
# ============================================================

echo "[6/10] Installing FilzaOS boot diagnostics..."

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
Starting FilzaOS...
Starting live environment...
Starting graphics...
"

for TTY in /dev/tty1 /dev/console; do

    if [[ -w "$TTY" ]]; then

        printf '%s\n' "$MESSAGE" \
            > "$TTY" \
            2>/dev/null || true

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

# ============================================================
# 7. GRUB BRANDING + HOSTNAME
# ============================================================

echo "[7/10] Applying FilzaOS GRUB branding..."

chmod u+rw "$GRUB_CFG"

python3 - "$GRUB_CFG" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])

text = path.read_text(encoding="utf-8")

# Visible branding only.
replacements = {
    "Try or Install Ubuntu": "Try FilzaOS",
    "Try Ubuntu": "Try FilzaOS",
    "Install Ubuntu": "Start FilzaOS",
    "Ubuntu": "FilzaOS",
}

for old, new in replacements.items():
    text = text.replace(old, new)

# Remove quiet/splash so diagnostics remain visible.
text = re.sub(r'\bquiet\b', '', text)
text = re.sub(r'\bsplash\b', '', text)

new_lines = []

for line in text.splitlines():

    if "/casper/vmlinuz" in line:

        for arg in (
            "plymouth.enable=0",
            "systemd.show_status=1",
            "loglevel=4",
            "hostname=filzaos"
        ):

            if arg not in line:
                line += " " + arg

    new_lines.append(line)

text = "\n".join(new_lines) + "\n"

if "echo 'FILZAOS'" not in text:

    text = (
        "echo 'FILZAOS'\n"
        "echo '============================'\n"
        "echo 'Loading FilzaOS...'\n"
        "echo 'Starting FilzaOS system...'\n"
        "echo '============================'\n\n"
        + text
    )

path.write_text(text, encoding="utf-8")
PY

echo "GRUB branding complete."
echo

# ============================================================
# 8. REBUILD SQUASHFS
# ============================================================

echo "[8/10] Rebuilding SquashFS..."

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

sudo chown \
    "$USER:$USER" \
    "$MINIMAL_OUT" \
    "$LIVE_OUT"

echo
echo "SquashFS rebuild complete."
echo

# ============================================================
# 9. BUILD BOOTABLE ISO
# ============================================================

echo "[9/10] Building bootable FilzaOS ISO..."

rm -f "$ISO_OUT"

(
    cd "$WORKSPACE"

    rm -f "$SHA256S"

    sha256sum \
        "$MINIMAL_OUT" \
        "$LIVE_OUT" \
        > "$SHA256S"
)

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
    -volid "FILZAOS_1.0.6" \
    -boot_image any replay \
    -commit \
    -end

# ============================================================
# 10. VERIFY + CLEAN OLD ISOS
# ============================================================

echo
echo "[10/10] Verifying final ISO..."

[[ -f "$ISO_OUT" ]] || {
    echo
    echo "ERROR: ISO was not created."
    echo "Previous ISO files were NOT deleted."
    exit 1
}

ISO_SIZE=$(du -h "$ISO_OUT" | cut -f1)

ISO_HASH=$(sha256sum "$ISO_OUT" | awk '{print $1}')

echo
echo "============================================================"
echo "                 FILZAOS v${VERSION} READY"
echo "============================================================"
echo
echo "ISO:"
echo "$ISO_OUT"
echo
echo "Windows:"
echo "D:\\FilzaOS\\build\\FilzaOS-v1.0.6.iso"
echo
echo "Size:"
echo "$ISO_SIZE"
echo
echo "SHA256:"
echo "$ISO_HASH"
echo
echo "============================================================"
echo " CUSTOMIZATION"
echo "============================================================"
echo
echo "[✓] FilzaOS wallpaper"
echo "[✓] FilzaOS GTK theme"
echo "[✓] FilzaOS icon theme"
echo "[✓] Purple folder icons"
echo "[✓] Dark mode"
echo "[✓] Purple terminal prompt"
echo "[✓] FilzaOS hostname"
echo "[✓] FilzaOS startup"
echo "[✓] FilzaOS OS identity"
echo "[✓] Ubuntu installer removed"
echo "[✓] GRUB FilzaOS branding"
echo
echo "============================================================"
echo " BOOT"
echo "============================================================"
echo
echo "[✓] BIOS preserved"
echo "[✓] UEFI preserved"
echo "[✓] Original initrd preserved"
echo "[✓] GNOME session architecture preserved"
echo "[✓] Boot diagnostics enabled"
echo
echo "============================================================"
echo " CLEANUP"
echo "============================================================"
echo

echo "Removing previous FilzaOS ISO versions..."

find "$BUILD" \
    -maxdepth 1 \
    -type f \
    -name 'FilzaOS-v*.iso' \
    ! -name "$(basename "$ISO_OUT")" \
    -print \
    -delete

echo
echo "Only the successful newest ISO is retained:"
echo
ls -lh "$ISO_OUT"

echo
echo "============================================================"
echo "                 BUILD COMPLETE"
echo "============================================================"
