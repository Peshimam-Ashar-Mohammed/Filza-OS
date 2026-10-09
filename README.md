FilzaOS
FilzaOS v1.0.9 — Initial Public Release
FilzaOS is an experimental Ubuntu-based Linux distribution remix built on Ubuntu 24.04.5 LTS (Noble Numbat). It gives the live desktop a distinct FilzaOS identity through custom boot branding, a purple-accented GNOME desktop, wallpapers and theme switching, terminal styling, and FilzaOS command-line utilities.
> **Project stage:** v1.0.9 is an early **Foundation + Identity** release. It is a customized Ubuntu-based remix, not an operating system built from scratch. More FilzaOS-specific commands and utilities are planned for future releases.
Download FilzaOS v1.0.9
Download FilzaOS-v1.0.9.iso from SourceForge
Base: Ubuntu 24.04.5 LTS (Noble Numbat)
Architecture: amd64 (64-bit x86)
Image size: approximately 6.1 GB
Boot: hybrid BIOS and UEFI image
Recommended first run: a virtual machine such as VMware
Verify the download (optional but recommended)
Published SHA-256 checksum:
```text
809dc6de3ccae84a099c01d4bd45fc00330875dd30081ae0b5aea87b8fcceb47  FilzaOS-v1.0.9.iso
```
On Windows, open PowerShell in the ISO's folder:
```powershell
Get-FileHash .\FilzaOS-v1.0.9.iso -Algorithm SHA256
```
On Linux:
```bash
sha256sum FilzaOS-v1.0.9.iso
```
Compare the calculated hash with the published value. `SHA256SUMS` is a text file for verification, not something users install. A matching checksum verifies that the file matches the published hash; it does not by itself prove that software is safe.
What's included in v1.0.9
FilzaOS boot identity: custom GRUB menu text, Plymouth text branding, and boot graphics.
Purple icon theme: custom folder/directory icons, user-directory icons, and symbolic sidebar icons.
Wallpaper collection: `purple`, `midnight`, `cyber-violet`, `light`, `neon`, and `classic`.
Wallpaper switching: `filza-wallpaper <name>` or `filza-wallpaper random`.
Theme switching: `filza-theme` coordinates wallpaper, GTK styling, icon theme, GNOME color preference, and terminal colors.
Terminal styling: deep-purple terminal palette and FilzaOS shell prompt.
Command suite:
`filza` — command center and system summary
`filza-info` — system/distribution information
`filza-sys` — CPU, memory, disk, process, and service diagnostics
`filza-net` — network information and diagnostics
`filza-doctor` — automated distribution health checks
`filza-fetch` — compact system information
`filza-help` — command reference
`portscan` — TCP port scanning utility
`jan` — developer easter egg
Desktop cleanup: Ubuntu installer shortcuts and related launcher components removed from this live image.
Preserved foundations: Ubuntu kernel/initrd infrastructure, systemd, GNOME, package metadata, and BIOS/UEFI boot structure.
Quick start
Download the ISO.
(Recommended) Verify its SHA-256 checksum.
Create a virtual machine in VMware Workstation or another compatible virtualization product.
Attach `FilzaOS-v1.0.9.iso` as the virtual optical disc and boot it.
Choose Try FilzaOS in the boot menu.
Important: The Ubuntu installer has been removed from v1.0.9. This release is intended for live-session experimentation and VM testing; it does not provide a normal installer for installing FilzaOS onto a physical disk. Do not overwrite or repartition a disk expecting an installer to be available.
See Installation and testing.
Project status and roadmap
This first public release establishes FilzaOS's identity and customization foundation. It is intentionally an early release; the roadmap will evolve with the project.
[ ] Add more FilzaOS-native commands and system utilities
[ ] Expand networking and diagnostics
[ ] Add automation and developer tools
[ ] Improve hardware/system reporting
[ ] Expand desktop customization and accessibility
[ ] Improve build automation and documentation
[ ] Evaluate installer options for a future release
Roadmap items are plans, not features included in v1.0.9.
Building from source
The v1.0.9 build script is designed for Ubuntu under WSL on Windows, using the project layout at `/mnt/d/FilzaOS`. Place a compatible original Ubuntu 24.04.5 LTS amd64 ISO at `/mnt/d/FilzaOS/source/ubuntu.iso`, install dependencies listed in Building FilzaOS, then run:
```bash
bash /mnt/d/FilzaOS/scripts/build-filzaos-v1.0.9.sh
```
The script keeps extracted root filesystems in native WSL Linux storage. Do not move its root filesystem workspace to `/mnt/d`. Review the build guide before running it. The script is version-specific, not a general-purpose distribution builder.
Repository structure
```text
Filza-OS/
├── config/                       # FilzaOS configuration and assets
├── scripts/
│   └── build-filzaos-v1.0.9.sh   # v1.0.9 ISO build workflow
├── docs/
│   ├── INSTALLATION.md
│   └── BUILDING.md
└── README.md
```
The original Ubuntu ISO and generated build artifacts are not stored in this Git repository.
Troubleshooting
Black screen: try the FilzaOS (safe graphics) GRUB entry if available.
Download seems incomplete: compare its SHA-256 hash with the published value and download again if it differs.
Command not found: open a terminal and check the command spelling with `filza-help`.
Missing source ISO during build: check `/mnt/d/FilzaOS/source/ubuntu.iso`.
For reproducible problems, open a GitHub issue and include the VM software, host OS, boot entry, and relevant error output. Never include passwords or tokens.
Important notes
FilzaOS v1.0.9 is experimental and is not represented as production-ready or security-hardened.
Test in a virtual machine first. Back up important data before experimenting with OS images.
FilzaOS is an independent community project, not an official Ubuntu flavor or Canonical product.
Ubuntu and third-party components retain their respective trademarks, copyrights, and licenses.
