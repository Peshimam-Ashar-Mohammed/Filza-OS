# FilzaOS

FilzaOS is a customized Linux distribution built on top of Ubuntu 24.04 LTS.

The project focuses on learning Linux systems, ISO construction, filesystem
customization, shell development, and operating-system tooling.

## Current Status

FilzaOS 1.0 currently includes:

- Custom FilzaOS branding
- Custom desktop wallpaper
- Dark GNOME configuration
- Purple GNOME accent
- FilzaOS theme autostart
- `filza-info` command
- BIOS + UEFI boot support
- Custom FilzaOS configuration files
- Reproducible ISO build script

## Base System

- Ubuntu 24.04.5 LTS
- Architecture: amd64
- Desktop: GNOME
- Init system: systemd

## Project Structure

```text
Filza-OS/
├── config/
│   ├── etc/
│   └── usr/
│
├── scripts/
│   └── build-filzaos.sh
│
├── source/
│   └── ubuntu.iso
│
├── build/
│   └── FilzaOS.iso
│
├── workspace/
│   └── build files
│
├── .gitignore
└── README.md
