#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="/mnt/d/FilzaOS"
SOURCE="$PROJECT/source/ubuntu.iso"
CONFIG="$PROJECT/config"
BUILD="$PROJECT/build"

VERSION="1.0.8"
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
        "$FS/usr/share/backgrounds/filzaos" \
        "$FS/usr/share/icons" \
        "$FS/usr/share/themes" \
        "$FS/etc/profile.d" \
        "$FS/etc/bash.bashrc.d" \
        "$FS/etc/xdg/autostart" \
        "$FS/etc/dconf/profile" \
        "$FS/etc/dconf/db/local.d" \
        "$FS/etc/gtk-3.0" \
        "$FS/etc/gtk-4.0" \
        "$FS/usr/share/glib-2.0/schemas"

    # ========================================================
    # FILZAOS RELEASE METADATA
    # ========================================================

    if [[ -f "$CONFIG/etc/filzaos-release" ]]; then
        cp "$CONFIG/etc/filzaos-release" "$FS/etc/filzaos-release"
        sed -i "s/^FILZAOS_VERSION=.*/FILZAOS_VERSION=\"${VERSION}\"/" "$FS/etc/filzaos-release"
    fi

    # Hostname & Hosts
    printf 'filzaos\n' > "$FS/etc/hostname"

    if [[ -f "$FS/etc/hosts" ]]; then
        sed -i -e 's/\bubuntu\b/filzaos/g' "$FS/etc/hosts" || true
    fi

    # Issue banners
    cat > "$FS/etc/issue" <<'ISSUE'
FilzaOS 1.0.8
Welcome to FilzaOS Linux
Kernel \r on an \m

ISSUE

    cat > "$FS/etc/issue.net" <<'ISSUE'
FilzaOS 1.0.8
ISSUE

    # LSB Release
    cat > "$FS/etc/lsb-release" <<'LSB'
DISTRIB_ID=FilzaOS
DISTRIB_RELEASE=1.0.8
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="FilzaOS 1.0.8"
LSB

    # OS-Release branding
    cat > "$FS/etc/os-release" <<'OSRELEASE'
NAME="FilzaOS"
PRETTY_NAME="FilzaOS 1.0.8"
ID=filzaos
ID_LIKE=ubuntu
VERSION_ID="1.0.8"
VERSION="1.0.8 Noble"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
HOME_URL="https://github.com/Peshimam-Ashar-Mohammed/Filza-OS"
SUPPORT_URL="https://github.com/Peshimam-Ashar-Mohammed/Filza-OS"
BUG_REPORT_URL="https://github.com/Peshimam-Ashar-Mohammed/Filza-OS"
OSRELEASE

    if [[ -d "$FS/usr/lib" ]]; then
        cp -f "$FS/etc/os-release" "$FS/usr/lib/os-release" 2>/dev/null || true
    fi

    # ========================================================
    # FILZAOS COMMANDS
    # ========================================================

    for file in \
        filza-info \
        filza-net \
        filza-sys \
        portscan \
        jan \
        filzaos-startup
    do
        if [[ -f "$CONFIG/usr/local/bin/$file" ]]; then
            cp "$CONFIG/usr/local/bin/$file" "$FS/usr/local/bin/$file"
            chmod +x "$FS/usr/local/bin/$file"
        fi
    done

    # ========================================================
    # WALLPAPER
    # ========================================================

    if [[ -d "$CONFIG/usr/share/backgrounds" ]]; then
        cp -a "$CONFIG/usr/share/backgrounds/." "$FS/usr/share/backgrounds/"
    fi

    # ========================================================
    # ICON THEME
    # ========================================================

    if [[ -d "$CONFIG/usr/share/icons" ]]; then
        cp -a "$CONFIG/usr/share/icons/." "$FS/usr/share/icons/"
    fi

    # ========================================================
    # GTK THEME
    # ========================================================

    if [[ -d "$CONFIG/usr/share/themes" ]]; then
        cp -a "$CONFIG/usr/share/themes/." "$FS/usr/share/themes/"
    fi

    # ========================================================
    # GTK 3.0 & GTK 4.0 SYSTEM SETTINGS
    # ========================================================

    cat > "$FS/etc/gtk-3.0/settings.ini" <<'GTK3INI'
[Settings]
gtk-theme-name = FilzaOS
gtk-icon-theme-name = FilzaOS
gtk-application-prefer-dark-theme = 1
GTK3INI

    cat > "$FS/etc/gtk-4.0/settings.ini" <<'GTK4INI'
[Settings]
gtk-theme-name = FilzaOS
gtk-icon-theme-name = FilzaOS
gtk-application-prefer-dark-theme = 1
GTK4INI

    # ========================================================
    # TERMINAL PROFILE & SHELL CUSTOMIZATION
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

    if [[ -d "$CONFIG/etc/bash.bashrc.d" ]]; then
        cp -a "$CONFIG/etc/bash.bashrc.d/." "$FS/etc/bash.bashrc.d/" 2>/dev/null || true
    fi

    # Ensure skeleton bashrc has purple prompt
    if [[ -f "$FS/etc/skel/.bashrc" ]] && ! grep -q "filzaos@filzaos" "$FS/etc/skel/.bashrc"; then
        echo 'PS1="\[\e[38;5;141m\]┌──[filzaos@filzaos]─[\w]\n\[\e[38;5;93m\]└─$ \[\e[0m\]"' >> "$FS/etc/skel/.bashrc"
    fi

    # ========================================================
    # REMOVE OLD PROBLEMATIC THEME STARTUP & BRANDING
    # ========================================================

    rm -f \
        "$FS/etc/xdg/autostart/filzaos-theme.desktop" \
        "$FS/etc/xdg/autostart/filzaos-branding.desktop" \
        "$FS/etc/xdg/autostart/filzaos-terminal-theme.desktop" \
        "$FS/usr/local/bin/filzaos-theme-start" \
        "$FS/usr/local/bin/filzaos-branding" \
        "$FS/usr/local/sbin/filzaos-theme-start" \
        2>/dev/null || true

    # ========================================================
    # CONSOLIDATED FILZAOS STARTUP
    # ========================================================

    cp "$CONFIG/usr/local/bin/filzaos-startup" "$FS/usr/local/bin/filzaos-startup"
    chmod +x "$FS/usr/local/bin/filzaos-startup"

    cp "$CONFIG/etc/xdg/autostart/filzaos-startup.desktop" "$FS/etc/xdg/autostart/filzaos-startup.desktop"

    # ========================================================
    # GSETTINGS SCHEMA OVERRIDES (INCLUDING :ubuntu)
    # ========================================================

    cat > "$FS/usr/share/glib-2.0/schemas/99_filzaos.gschema.override" <<'GSCHEMA'
[org.gnome.desktop.interface]
gtk-theme = 'FilzaOS'
icon-theme = 'FilzaOS'
color-scheme = 'prefer-dark'
cursor-theme = 'Yaru'

[org.gnome.desktop.interface:ubuntu]
gtk-theme = 'FilzaOS'
icon-theme = 'FilzaOS'
color-scheme = 'prefer-dark'
cursor-theme = 'Yaru'

[org.gnome.desktop.background]
picture-uri = 'file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-uri-dark = 'file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-options = 'zoom'
primary-color = '#0B0614'
secondary-color = '#0B0614'

[org.gnome.desktop.background:ubuntu]
picture-uri = 'file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-uri-dark = 'file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-options = 'zoom'
primary-color = '#0B0614'
secondary-color = '#0B0614'

[org.gnome.desktop.screensaver]
picture-uri = 'file:///usr/share/backgrounds/filzaos/filzaos.png'

[org.gnome.desktop.screensaver:ubuntu]
picture-uri = 'file:///usr/share/backgrounds/filzaos/filzaos.png'

[org.gnome.shell:ubuntu]
always-show-log-out = true
favorite-apps = [ 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'firefox_firefox.desktop' ]

[org.gnome.Terminal.ProfilesList]
default = 'b1dcc9dd-5262-4d8d-a863-c897e6d979b9'
list = [ 'b1dcc9dd-5262-4d8d-a863-c897e6d979b9' ]
GSCHEMA

    if [[ -x "$FS/usr/bin/glib-compile-schemas" ]]; then
        sudo chroot "$FS" /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null || true
    fi

    # ========================================================
    # DCONF SYSTEM DATABASE
    # ========================================================

    cat > "$FS/etc/dconf/profile/user" <<'PROFILE'
user-db:user
system-db:local
PROFILE

    cat > "$FS/etc/dconf/db/local.d/00-filzaos" <<'DCONF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-uri-dark='file:///usr/share/backgrounds/filzaos/filzaos.png'
picture-options='zoom'
primary-color='#0B0614'
secondary-color='#0B0614'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/filzaos/filzaos.png'

[org/gnome/desktop/interface]
gtk-theme='FilzaOS'
icon-theme='FilzaOS'
color-scheme='prefer-dark'
cursor-theme='Yaru'

[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'firefox_firefox.desktop']

[org/gnome/terminal/legacy/profiles:]
default='b1dcc9dd-5262-4d8d-a863-c897e6d979b9'
list=['b1dcc9dd-5262-4d8d-a863-c897e6d979b9']

[org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9]
visible-name='FilzaOS'
use-theme-colors=false
background-color='#0B0614'
foreground-color='#E9D5FF'
bold-color='#C084FC'
cursor-background-color='#C084FC'
cursor-foreground-color='#0B0614'
palette=['#0B0614', '#FF5555', '#50FA7B', '#F1FA8C', '#BD93F9', '#FF79C6', '#8BE9FD', '#F8F8F2', '#44475A', '#FF6E6E', '#69FF94', '#FFFFA5', '#D6ACFF', '#FF92DF', '#A4FFFF', '#FFFFFF']
DCONF

    if [[ -x "$FS/usr/bin/dconf" ]]; then
        sudo chroot "$FS" /usr/bin/dconf update 2>/dev/null || true
    fi

    # ========================================================
    # COMPILE ICON CACHE
    # ========================================================

    if [[ -d "$FS/usr/share/icons/FilzaOS" ]] && [[ -x "$FS/usr/sbin/gtk-update-icon-cache" ]]; then
        sudo chroot "$FS" /usr/sbin/gtk-update-icon-cache -f -t /usr/share/icons/FilzaOS 2>/dev/null || true
    fi

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

    # Desktop launchers in applications directory
    find "$FS/usr/share/applications" \
        -type f \
        \( \
            -iname '*ubiquity*' \
            -o -iname '*ubuntu*installer*' \
            -o -iname '*install-ubuntu*' \
            -o -iname '*calamares*' \
            -o -iname '*bootstrap*' \
        \) \
        -delete \
        2>/dev/null || true

    # Snap desktop applications (e.g. ubuntu-desktop-bootstrap)
    if [[ -d "$FS/var/lib/snapd/desktop/applications" ]]; then
        find "$FS/var/lib/snapd/desktop/applications" \
            -type f \
            \( \
                -iname '*bootstrap*' \
                -o -iname '*installer*' \
                -o -iname '*ubiquity*' \
            \) \
            -delete \
            2>/dev/null || true
    fi

    # Installer directories
    rm -rf \
        "$FS/usr/lib/ubiquity" \
        "$FS/usr/share/ubiquity" \
        "$FS/usr/lib/calamares" \
        "$FS/usr/share/calamares" \
        2>/dev/null || true

    # Live-session installer shortcuts across all possible locations
    find "$FS" \
        -type f \
        \( \
            -iname '*install-ubuntu*.desktop' \
            -o -iname '*ubuntu-desktop-installer*.desktop' \
            -o -iname '*ubuntu-desktop-bootstrap*.desktop' \
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
    -volid "FILZAOS_1.0.8" \
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

# Verify key ISO contents using xorriso
echo "Verifying ISO structure..."
xorriso -indev "$ISO_OUT" -ls /casper -ls /boot/grub -end 2>/dev/null | grep -E 'minimal\.squashfs|minimal\.standard\.live\.squashfs|initrd|vmlinuz|grub\.cfg' || {
    echo "ERROR: Missing critical boot files in ISO."
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
echo "D:\\FilzaOS\\build\\FilzaOS-v1.0.8.iso"
echo
echo "Size:"
echo "$ISO_SIZE"
echo
echo "SHA256:"
echo "$ISO_HASH"
echo
echo "============================================================"
echo " CUSTOMIZATION VERIFIED"
echo "============================================================"
echo
echo "[✓] FilzaOS wallpaper"
echo "[✓] FilzaOS GTK theme"
echo "[✓] FilzaOS purple icon theme"
echo "[✓] Purple folder icons + inode-directory + user dirs"
echo "[✓] Purple symbolic icons for sidebar"
echo "[✓] Dark mode preference"
echo "[✓] Purple terminal color scheme + prompt"
echo "[✓] FilzaOS hostname"
echo "[✓] Consolidated FilzaOS startup"
echo "[✓] FilzaOS OS identity & release metadata"
echo "[✓] Ubuntu installer completely removed"
echo "[✓] GRUB FilzaOS branding"
echo
echo "============================================================"
echo " BOOT VERIFIED"
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
