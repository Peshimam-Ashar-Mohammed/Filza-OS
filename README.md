# FilzaOS

FilzaOS is a custom Linux distribution remix engineered on top of Ubuntu 24.04.5 LTS (Noble Numbat).

The project blends an aesthetic purple-accented desktop experience with custom CLI system utilities, native diagnostic tools, an integrated wallpaper & theme engine, and a hardened live-boot environment.

---

## What's New in FilzaOS v1.0.9

- **FilzaOS Boot Branding:** Integrated Plymouth text & splash boot identity displaying `FILZAOS` with custom purple color grading instead of default Ubuntu branding.
- **Custom Purple Icon Suite:** Full Freedesktop icon theme featuring purple folders, custom `inode-directory` MIME associations, specialized XDG user directory emblems (Home, Documents, Downloads, Music, Pictures, Videos, Public, Templates, Open, Remote, Recent), and scalable 16x16 symbolic sidebar icons.
- **Wallpaper Library & Engine (`filza-wallpaper`):** 
  - Six curated wallpapers installed into `/usr/share/backgrounds/filzaos/`:
    - `purple`: Signature FilzaOS Purple (Default)
    - `midnight`: Deep-space ultra-dark minimalist mode
    - `cyber-violet`: Sci-fi orbital space landscape
    - `light`: Futuristic lilac high-key clean landscape
    - `neon`: Cyberpunk cityscape purple-cyan landscape
    - `classic`: Original FilzaOS heritage wallpaper
  - Switch wallpapers on the fly via `filza-wallpaper <name>` or `filza-wallpaper random`.
- **Integrated Theme Switcher (`filza-theme`):** Instant system theme switching (`purple`, `midnight`, `cyber-violet`, `light`, `neon`, `classic`) controlling wallpaper, GTK theme, icon theme, GNOME color-scheme, and terminal color palette with reboot persistence.
- **FilzaOS Command Suite:**
  - `filza`: Master system command center with ASCII art identity.
  - `filza-info`: Complete hardware & distribution summary.
  - `filza-sys`: Real-time system diagnostics (`info`, `cpu`, `memory`, `disk`, `processes`, `services`).
  - `filza-net`: Network diagnostic utility (`info`, `ip`, `ping`, `route`, `ports`).
  - `filza-doctor`: 14-point automated distribution health & integrity verification.
  - `filza-fetch`: Lightweight ASCII system information display.
  - `filza-help`: Complete documentation and unique feature reference.
  - `portscan`: Built-in TCP socket scanner (`portscan <target>` / `portscan --common <target>`).
  - `jan`: Custom developer easter egg animation.
- **Terminal Styling:** Custom deep purple terminal palette (`#0B0614` background, `#E9D5FF` text, `#C084FC` cursor) with two-line `┌──[filzaos@filzaos]─[~] └─$` prompt.
- **Cleaned Desktop Environment:** Ubuntu installer shortcuts and bootstrap launchers completely removed from the desktop, dock, and application drawer.
- **Bootloader Integrity:** Preserved original Ubuntu 24.04 kernel infrastructure, untouched initrd, BIOS & UEFI dual-boot support, and GRUB menu customization.

---

## Base Architecture

- **Base:** Ubuntu 24.04.5 LTS
- **Codename:** Noble
- **Architecture:** amd64
- **Desktop Environment:** GNOME 46
- **Windowing:** Wayland & X11 compatible
- **Init System:** systemd

---

## Project Structure

```text
Filza-OS/
├── config/
│   ├── etc/
│   │   ├── bash.bashrc.d/
│   │   ├── filzaos-release
│   │   ├── gtk-3.0/
│   │   ├── gtk-4.0/
│   │   ├── profile.d/
│   │   └── xdg/autostart/
│   └── usr/
│       ├── local/bin/          # FilzaOS command tools
│       └── share/
│           ├── backgrounds/    # FilzaOS wallpaper collection
│           ├── icons/FilzaOS/  # Purple icon theme & SVGs
│           ├── plymouth/       # Boot splash & text branding
│           └── themes/FilzaOS/ # GTK 3 & 4 styling
├── scripts/
│   └── build-filzaos-v1.0.9.sh # Native WSL reproducible build script
├── source/
│   └── ubuntu.iso              # Base original Ubuntu Noble ISO
├── build/
│   └── FilzaOS-v1.0.9.iso      # Output bootable hybrid ISO
└── README.md
```

---

## Building FilzaOS

Builds are executed inside WSL using native Linux workspace storage:

```bash
bash /mnt/d/FilzaOS/scripts/build-filzaos-v1.0.9.sh
```
