# Linux 7.2.15

Base: upstream stable `v7.2.15` (`03c639b`, "Linux 7.2.15").
Patch set: `patches/0001-linux-tkg-and-local.patch` plus
`patches/0002-amd-pstate-epp-boost.patch`.
Toolchain: clang/LLD 22.1.8, `LLVM=1`, `CONFIG_CC_IS_CLANG=y`.

## Configurations

| Config | Local version | Size | `=y` / `=m` | Status |
| --- | --- | --- | --- | --- |
| `configs/config-7.2.15-eudaimonia-01` | `-eudaimonia-01` | 216,065 B | 2328 / 189 | Known-good fallback; kernel `#8`; rebuilt from the known-good config with `CONFIG_BRIDGE=y` and `CONFIG_BRIDGE_NETFILTER=y` for Docker/netavark. BTF, Bluetooth and HDMI audio enabled. Boot-tested. |
| `configs/config-7.2.15-eudaimonia-02` | stored `-eudaimonia-01` | 213,069 B | 2261 / 184 | Historical `#4`; booted but X failed because the module tree did not match. Do not build as-is. |
| `configs/config-7.2.15-eudaimonia-03` | `-eudaimonia-03` | 206,843 B | 2117 / 165 | Historical lean `#7`; panicked with `Attempted to kill init!`. Do not use. |
| `configs/config-7.2.15-eudaimonia-04` | `-eudaimonia-04` | 212,222 B | 2252 / 170 | Previous default and current ZFSBootMenu default; conservative lean `#9` based on the `-02` config. Bridge enabled; Bluetooth and HDMI audio disabled. Boot-tested. |
| `configs/config-7.2.15-eudaimonia-05` | `-eudaimonia-05` | 187,572 B | 2037 / 163 | Current build default; leaner AMD-only profile based on `-04`. Installed and statically verified, not yet boot-tested. Adds the amd-pstate EPP boost patch. |

### The `-02` local-version bug

The `-02` config was built while its `CONFIG_LOCALVERSION` still said
`-eudaimonia-01`. The boot entry was named `-02`, but the modules were
installed under `/lib/modules/7.2.15-eudaimonia-01`, so the running `-02`
kernel could not load its modules and X failed.

`scripts/build.sh` now derives the intended local version from the config
filename (`config-7.2.15-eudaimonia-02` -> `-eudaimonia-02`) and overrides the
stored value. It also refuses to continue if `make kernelrelease` does not
match `<version><localversion>`. Only pass `--localversion -eudaimonia-01` if
you explicitly want to reproduce the broken historical build.

### The lean `-04` profile

`-04` is based on the bootable `-02` config and removes Bluetooth and HDMI/DP
audio, which are not used on this laptop:

- no `CONFIG_BT`, `CONFIG_BT_HCIBTUSB`, `CONFIG_BT_MTK`
- no `CONFIG_SND_HDA_CODEC_HDMI` or HDMI ELD/ATI/GENERIC codec options
- no `CONFIG_DRM_PANIC` (also removes the QR panic screen)
- no `CONFIG_XEN`, `CONFIG_CRASH_DUMP`, `CONFIG_KVM_INTEL`, or
  `CONFIG_NUMA_BALANCING`

Retained: `SCHED_BORE`, BBR3, O3/native tuning, `DRM_AMDGPU=m`,
`DRM_AMD_DC=y`, `SND_HDA_INTEL=m` with Realtek/ALC269, `MT7921E=m`,
`R8169=m`, `AMD_IOMMU=y`, `X86_AMD_PSTATE=y`, NVMe, XHCI, pstore,
`CONFIG_DEBUG_INFO_BTF=y`, and the legion-laptop module.

The historical `-03` profile removed BTF and HDCP as well, but it panicked
before init; do not reuse it. The cause was not isolated, so `-04` deliberately
stays closer to the bootable `-02` config.

### The lean `-05` profile

`-05` starts from the boot-tested `-04` config and removes hardware and
features this laptop does not use, while keeping the gaming and container
paths. The main removals are:

- Intel CPU support: `PROCESSOR_SELECT=y` makes `CPU_SUP_INTEL` visible, then
  `CPU_SUP_INTEL`, `CPU_SUP_HYGON`, `CPU_SUP_CENTAUR`, and `CPU_SUP_ZHAOXIN`
  are disabled. `CPU_SUP_AMD=y` remains.
- Intel platform pieces: `X86_INTEL_PSTATE`, `INTEL_IDLE`, Intel IOMMU,
  `INTEL_SCU*`, `INTEL_SOC_PMIC*`, `X86_INTEL_LPSS`, and `INTEL_TURBO_MAX_3`
  are absent. `INTEL_RAPL=m` is kept because the RAPL driver supports AMD.
- NUMA, memory hotplug/hotremove, ACPI hotplug, and hibernation.
- HSA/ROCm device memory: `HSA_AMD*`, `DEVICE_PRIVATE`, `ZONE_DEVICE`,
  `PCI_P2PDMA`, and `HSA_AMD_SVM` are disabled. `HMM_MIRROR` and
  `DRM_AMDGPU_USERPTR` remain for the graphics stack.
- ATA/SATA, legacy USB EHCI/OHCI/UHCI, old PMIC/MFD/GPIO/PINCTRL/SPI drivers,
  DVB/media capture hardware, and inactive LSMs.
- `ZSWAP`/`ZSMALLOC`, `FUSE_DAX`/`FUSE_PASSTHROUGH`, `DRM_AMD_SECURE_DISPLAY`,
  and unused TCP congestion modules. The default congestion control remains
  `cubic`; BBR/BBR3 stay available.

Retained: `SCHED_BORE`, BBR3, O3/native tuning, `DRM_AMDGPU=m`,
`DRM_AMD_DC=y`, `SND_HDA_INTEL=m` with Realtek/ALC269, `MT7921E=m`,
`R8169=m`, `AMD_IOMMU=y`, `X86_AMD_PSTATE=y`, `INTEL_RAPL=m`, NVMe, XHCI,
USB4/Thunderbolt, bridge/veth/nftables, KVM/AMD-V, VFIO, vhost, pstore,
`CONFIG_DEBUG_INFO_BTF=y`, and the legion-laptop module. `KEXEC` and
`KEXEC_FILE` remain for ZFSBootMenu; only `KEXEC_JUMP` is gone because
hibernation is disabled.

AMD CPU mitigations (`RETPOLINE`, `RETHUNK`, `UNRET_ENTRY`, `IBPB_ENTRY`,
`SRSO`, `SLS`, `RETBLEED`, `SPECTRE_V1/V2`, `SSB`, `TSA`, `VMSCAPE`) remain.
Only Intel-specific mitigations disappear with `CPU_SUP_INTEL`.

### Docker bridge and audio

`-01`, `-04`, and `-05` set `CONFIG_BRIDGE=y`, `CONFIG_BRIDGE_NETFILTER=y`,
`CONFIG_STP=y`, and `CONFIG_LLC=y`; `CONFIG_VETH=m` remains. This fixes the
netavark `Not supported (os error 95)` error.

The Realtek ALC257 is handled by `snd-hda-codec-alc269` plus
`snd-hda-codec-realtek-lib`. There is no module literally named
`snd-hda-codec-realtek` in this kernel, so `modinfo snd_hda_codec_realtek`
reporting "MISSING" is expected and does not mean analog audio is broken.

`-04` still carries `X86_INTEL_PSTATE=y` because it keeps `CPU_SUP_INTEL`.
`-05` disables Intel CPU support, so `X86_INTEL_PSTATE` and `INTEL_IDLE` are
absent; AMD uses `X86_AMD_PSTATE=y`. `MODULE_SIG=y` and `MODULE_SIG_ALL=y` are
enabled, while `MODULE_SIG_FORCE` is off.

## Build

From the repository root:

```sh
sudo ./build.sh
```

This uses `configs/config-7.2.15-eudaimonia-05` by default. Other examples:

```sh
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-01
sudo ./build.sh --source /usr/src/ltkg-7.2.15/linux-src-git-07 --skip-patches
sudo ./build.sh --skip-install
sudo ./build.sh --skip-zfs --skip-legion
```

Useful options: `--localversion`, `--build-dir`, `--legion-source`,
`--compiler`, `--jobs`, `--clean`, `--skip-verify`. Run with `--help`.

The script clones the kernel into `.build/linux-7.2.15` unless `--source` is
given. It applies the combined patch, copies the selected config, sets
`CONFIG_LOCALVERSION`, runs `olddefconfig`, builds with `LLVM=1`, installs the
modules and image, builds ZFS/SPL, builds `legion-laptop`, regenerates the
initramfs, and runs the verifier.

### Existing source tree

The laptop's current tree is `/usr/src/ltkg-7.2.15/linux-src-git-07`. It is
already patched and contains the build signing key, so:

```sh
sudo ./build.sh --source /usr/src/ltkg-7.2.15/linux-src-git-07 --skip-patches
```

The script overwrites that tree's `.config`. It does not reset the tree.

## ZFS, SPL and legion-laptop

ZFS/SPL 2.4.4 are built through `ckms` against the new kernel. The package
configuration is stored in `zfs/ckms.ini`; the source must already be available
as `/var/lib/ckms/zfs/2.4.4/source` (on this machine it points to
`/usr/src/zfs-2.4.4`). The build script installs `ckms.ini` if it is missing,
but it cannot supply the OpenZFS source.

`ckms` can report `already installed` even after the module tree was cleaned.
The script then looks for the signed build output under
`/var/lib/ckms/zfs/2.4.4/<release>/` and installs it as
`/lib/modules/<release>/extra/zfs.ko.zst` and `spl.ko.zst`.

The `-05` module tree contains 167 module files (including ZFS, SPL, and
legion-laptop) and is 16 MiB on disk. ZFS/SPL and legion-laptop all report:

```
vermagic: 7.2.15-eudaimonia-05 SMP preempt mod_unload
```

ZFS/SPL are signed by the local build key. The current key ID reported by
`modinfo -F sig_key zfs` is
`07:2A:1A:97:E6:F2:3C:72:B2:AA:AC:FC:E3:90:21:44:90:20:BB:39`. The key is not
part of this repository, and a fresh build can generate a different key. The
installed `legion-laptop.ko` is currently unsigned, which is harmless because
`MODULE_SIG_FORCE` is off; the verifier reports it as a warning.

`legion-laptop` comes from
`https://github.com/johnfanv2/LenovoLegionLinux.git` at
`7c19579d13ce686cf1e237699b9a78e80d03c977`. The small patch changes
`kernel_module/Makefile` from `uname --kernel-release` to `uname -r`, because
Chimera's BSD-derived `uname` does not support the GNU long option. The script
clones the repo by default or accepts `--legion-source`.

## Verify

```sh
./verify.sh --krel 7.2.15-eudaimonia-05
```

It checks the four `/boot` artifacts, the config's local version and key
options, the module tree and `modules.dep`, ZFS/SPL/legion-laptop vermagic and
signatures, and the initramfs contents (`zfs.ko`, `spl.ko`,
`scripts/local-top/zfs`, `conf/conf.d/zfs`, `zfs`, `zpool`, `mount.zfs`).

The `-05` initramfs is 12,276,479 bytes; the image is 12,529,664 bytes.

## Boot testing

The current ZFSBootMenu default is still the boot-tested `-04`:

```
org.zfsbootmenu:kernel = vmlinuz-7.2.15-eudaimonia-04$
```

`-05` is installed under `/boot` but has not been boot-tested. Select its
entry explicitly from ZFSBootMenu, or switch the property manually:

```sh
sudo zfs set org.zfsbootmenu:kernel='vmlinuz-7.2.15-eudaimonia-05$' rpool/ROOT/chimera
```

The lean `-04` kernel remains the safe default until `-05` boots.

Roll back to `-01` from ZFSBootMenu if the kernel panics or X fails:

```sh
sudo zfs set org.zfsbootmenu:kernel='vmlinuz-7.2.15-eudaimonia-01$' rpool/ROOT/chimera
```

The historical `-03` (`#7`) panicked with `Attempted to kill init!`; the cause
is unknown. pstore is enabled in `-04` and `-05`, so inspect
`/sys/fs/pstore` after a failed boot.

Do not copy the machine's ZFS host ID or `root=zfs:...` command line into other
machines. On dinit systems, use `dinitctl`; `systemctl` is not available.

## amd-pstate EPP boost

`-05` includes `patches/0002-amd-pstate-epp-boost.patch`. The feature is
opt-in and defaults off:

```sh
echo 1 > /sys/module/amd_pstate/parameters/epp_boost
```

It only acts in active mode on MSR/CPPC systems. The boot command line forces
EPP `performance`, so the boost has little effect until EPP is lowered to
`balance_performance` or dynamic EPP is enabled.

## linux-tkg reference files

`tkg/customization.cfg` is the linux-tkg configuration used to produce the
source tree, and `tkg/kernelconfig.new` is its saved base config. They are
reference material only; the build script does not run linux-tkg. The
`customization.cfg` still records `_kernel_localversion="eudaimonia-06"` and
`_compiler="llvm"`; the selected config and `--localversion` are authoritative.
