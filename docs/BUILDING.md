# Building FilzaOS v1.0.9

This guide documents the repository's v1.0.9 build script. It customizes an Ubuntu live ISO; it does not build a Linux kernel or a complete operating system from scratch.

## Environment and layout

The script is designed for Ubuntu under WSL on Windows and expects:

```text
/mnt/d/FilzaOS/
├── source/ubuntu.iso
├── config/
├── scripts/build-filzaos-v1.0.9.sh
└── build/
```

The original ISO is not included in the Git repository. Place a compatible **Ubuntu 24.04.5 LTS amd64** ISO at:

```text
/mnt/d/FilzaOS/source/ubuntu.iso
```

The script uses native Linux workspace storage at:

```text
$HOME/filzaos-workspace
```

**Do not extract or rebuild the SquashFS root filesystems under `/mnt/d`.** Keep the working root filesystem in native WSL Linux storage so Linux permissions, ownership, device nodes, and filesystem metadata can be handled correctly.

## Dependencies

The script checks for `xorriso`, `unsquashfs`, `mksquashfs`, `sha256sum`, and `python3`. Install the corresponding packages on Ubuntu/WSL:

```bash
sudo apt update
sudo apt install -y xorriso squashfs-tools coreutils python3
```

## Build

Run:

```bash
bash /mnt/d/FilzaOS/scripts/build-filzaos-v1.0.9.sh
```

The script checks inputs, extracts both live filesystem layers and GRUB configuration, applies FilzaOS configuration, rebuilds the SquashFS images, reconstructs the ISO while replaying boot metadata, and checks for key boot files.

Expected output:

```text
/mnt/d/FilzaOS/build/FilzaOS-v1.0.9.iso
```

The script prints the output size and SHA-256 hash. Rebuilds may differ if source inputs, configuration, or tools differ, so do not assume every rebuild will have the published release hash.

## Storage and permissions notes

- Keep extracted root filesystems in `$HOME/filzaos-workspace`, not on the Windows-mounted drive.
- The script uses `sudo` for filesystem extraction and rebuilding and attempts to restore workspace ownership during cleanup.
- Confirm the source ISO, project configuration, and wallpaper assets exist before starting.
- After a successful build, the script removes older `FilzaOS-v*.iso` files from the configured build directory. Back up artifacts you need to retain before running it.

## Scope and limitations

This is a version-specific v1.0.9 build script, not a general-purpose distribution builder. Review it before changing paths or adapting it for later releases. Boot-test any generated ISO in a virtual machine before distributing it.
