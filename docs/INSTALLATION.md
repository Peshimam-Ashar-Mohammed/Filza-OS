# Installing and testing FilzaOS v1.0.9

FilzaOS v1.0.9 is an experimental live ISO based on Ubuntu 24.04.5 LTS.

## Download

Download **[FilzaOS-v1.0.9.iso from SourceForge](https://sourceforge.net/projects/filzaos/files/v1.0.9/FilzaOS-v1.0.9.iso/download)**. The image is approximately 6.1 GB.

## Verify the download

Published SHA-256:

```text
809dc6de3ccae84a099c01d4bd45fc00330875dd30081ae0b5aea87b8fcceb47
```

Windows PowerShell (run in the ISO's folder):

```powershell
Get-FileHash .\FilzaOS-v1.0.9.iso -Algorithm SHA256
```

Linux:

```bash
sha256sum FilzaOS-v1.0.9.iso
```

Compare the output with the published value. `SHA256SUMS` is a text file for integrity checking, not an installer or dependency.

## Recommended: boot in a virtual machine

1. Install and open a virtualization application such as VMware Workstation.
2. Create a new 64-bit Linux virtual machine.
3. Attach `FilzaOS-v1.0.9.iso` as its virtual CD/DVD image.
4. Start the VM and select **Try FilzaOS**. If graphics fail, try **FilzaOS (safe graphics)** if shown.
5. Explore the desktop and test commands such as `filza`, `filza-help`, `filza-info`, `filza-doctor`, `filza-theme`, and `filza-wallpaper`.

Use VM settings appropriate to your host hardware. This experimental release does not specify a verified minimum hardware requirement.

## Important limitation

Ubuntu installer components have been removed from v1.0.9. This release is for live-session experimentation and VM testing; it does **not** include a normal installer for installing FilzaOS to a physical disk. Do not repartition or overwrite a disk expecting an installer.

## Troubleshooting

- **Black screen or graphics issue:** reboot and try the safe-graphics entry if available.
- **Hash mismatch:** download the ISO again and recheck before using it.
- **VM does not boot:** confirm it is configured as a 64-bit x86 Linux guest and is booting from the ISO.
- **Unexpected behavior:** report the VM application, host OS, boot entry, and relevant errors in a GitHub issue.

FilzaOS is experimental. Back up important data before experimenting with OS images.
