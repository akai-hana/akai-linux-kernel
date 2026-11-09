# akai-linux-kernel

Versioned, reproducible kernel configurations and patches for my Lenovo Legion
running Chimera Linux with a ZFS root. The current target is Linux **7.2.15**.

The goal is a lean kernel that keeps exactly the hardware I use, while
remaining rebuildable on another machine from this repository alone.

## Hardware profile

- Lenovo Legion laptop
- AMD Rembrandt integrated GPU + Navi 22 discrete GPU (`amdgpu`)
- MediaTek MT7921E Wi-Fi, Realtek R8169 Ethernet
- Realtek HDA audio, UVC webcam, i2c-hid touchpad
- NVMe storage, ZFS root on `rpool/ROOT/chimera`
- `legion-laptop` out-of-tree module for platform/fan controls
- Chimera Linux with **dinit** (`dinitctl`, not `systemctl`)

## Kernel variants

| Config | Status | Local version | `=y` / `=m` | Notes |
| --- | --- | --- | --- | --- |
| `config-7.2.15-eudaimonia-01` | known-good fallback, kernel `#8`, boot-tested | `-eudaimonia-01` | 2328 / 189 | Rebuilt from the known-good config with bridge support for Docker/netavark. BTF, Bluetooth and HDMI audio enabled. |
| `config-7.2.15-eudaimonia-02` | historical, do not use as-is | stored `-eudaimonia-01` | 2261 / 184 | Historical `#4`. Booted, but X failed because the boot entry was named `-02` while modules were installed for `-01`. The build script now derives the local version from the config filename. |
| `config-7.2.15-eudaimonia-03` | historical, do not use | `-eudaimonia-03` | 2117 / 165 | Historical lean `#7`. Panicked with `Attempted to kill init!`; cause not isolated. |
| `config-7.2.15-eudaimonia-04` | current default, kernel `#9`, boot-tested | `-eudaimonia-04` | 2252 / 170 | Conservative trim based on `-02`: bridge enabled; Bluetooth and HDMI audio disabled. ZFS/SPL and `legion-laptop` rebuilt. |

The current `-01` and `-04` builds were compiled with **clang/LLD 22.1.8**
(`CONFIG_CC_IS_CLANG=y`). The build script therefore defaults to `LLVM=1`.

## Repository layout

```
.
├── build.sh                 top-level dispatcher
├── verify.sh                top-level verifier
├── docs/
│   └── eudaimonia.md        checklist for adding this repo to the meta-repo
└── 7.2.15/
    ├── build.conf           versions, refs, default config
    ├── configs/             the four config variants
    ├── patches/
    │   ├── 0001-linux-tkg-and-local.patch
    │   ├── custom/          original preempt + BBR3 patches (reference)
    │   └── legion/          LenovoLegionLinux Makefile fix
    ├── scripts/
    │   ├── build.sh
    │   └── verify.sh
    ├── tkg/                 linux-tkg customization and base config
    └── zfs/                 ckms package configuration
```

The combined patch is against upstream `v7.2.15` (`03c639b`) and contains
96 files: 4249 insertions, 324 deletions. It includes the linux-tkg 7.2
changes (BORE scheduler, O3, native tuning, etc.), the preempt fixes, BBR3,
and the three new source files (`kernel/sched/bore.c`,
`include/linux/sched/bore.h`, `net/ipv4/tcp_bbr3.c`).

## Quick start

Requirements: Chimera Linux (or a compatible distro), root, the LLVM
toolchain, kernel build dependencies, `ckms` with the ZFS 2.4.4 source for a
ZFS-root machine, and network access for the kernel and LenovoLegionLinux
clones.

Build and install the default (`-04`) configuration:

```sh
git clone git@github.com:akai-hana/akai-linux-kernel.git
cd akai-linux-kernel
sudo ./build.sh
```

Reuse the already-patched source tree on this laptop:

```sh
sudo ./build.sh --source /usr/src/ltkg-7.2.15/linux-src-git-07 --skip-patches
```

Build the known-good fallback profile (BTF is enabled there, so `pahole` is required):

```sh
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-01
```

Compile only, without touching the installed system:

```sh
sudo ./build.sh --skip-install
```

Verify an installed release:

```sh
./verify.sh --krel 7.2.15-eudaimonia-04
```

Run `./build.sh --help` for every option.

## What build.sh does

1. Clones the stable kernel at `v7.2.15` (or reuses `--source`).
2. Applies `patches/0001-linux-tkg-and-local.patch` unless `--skip-patches`.
3. Copies the selected config and sets `CONFIG_LOCALVERSION` from the config
   filename. This deliberately overrides the stale value inside the `-02`
   config and refuses to continue if `make kernelrelease` does not match.
4. Runs `olddefconfig`, builds with `LLVM=1`, installs modules and the image.
5. Builds ZFS/SPL through `ckms`, with a fallback that compresses and installs
   the prebuilt signed `zfs.ko`/`spl.ko` when `ckms` reports "already
   installed" but the module tree is empty.
6. Builds and installs `legion-laptop` into `/lib/modules/<release>/extra`.
7. Runs `depmod`, `update-initramfs` (or `mkinitcpio`), and the verifier.

It **never changes the ZFSBootMenu default**. The bootloader choice stays a
manual, reversible step.

## Testing and rollback

The ZFSBootMenu property currently uses a trailing `$`:

```sh
zfs get org.zfsbootmenu:kernel rpool/ROOT/chimera
# vmlinuz-7.2.15-eudaimonia-04$
```

The lean `-04` kernel is the current default and has booted successfully.

If it fails, boot the `-01` entry from ZFSBootMenu and restore:

```sh
sudo zfs set org.zfsbootmenu:kernel='vmlinuz-7.2.15-eudaimonia-01$' rpool/ROOT/chimera
```

The historical `-03` (`#7`) panicked with `Attempted to kill init!`; the cause
is still unknown. pstore is enabled in `-04`, so check `/sys/fs/pstore` after a
failed boot.

## Notes

- No signing keys are stored in this repository. A fresh build generates its
  own key and signs the kernel modules; the ZFS/SPL modules are signed with the
  same build key. Never publish `certs/signing_key.pem`.
- ZFS host IDs and other machine-specific boot parameters are not hardcoded.
  Do not copy `spl.spl_hostid` from another machine.
- The `-02` config's stored `CONFIG_LOCALVERSION` is `-eudaimonia-01`; this was
  the cause of the X failure. Do not build it with the historical value.
- The `tkg/` files record how the tree was originally configured. The build
  script does not run linux-tkg; the combined patch is the authoritative input.
- On this system use `dinitctl`, not `systemctl`.

## License and credits

The scripts and configuration files are provided under GPL-2.0. The kernel
patches retain their upstream licenses and authorship. See [CREDITS.md](CREDITS.md).

For adding this repository to the `eudaimonia` meta-repository, see
[docs/eudaimonia.md](docs/eudaimonia.md).
