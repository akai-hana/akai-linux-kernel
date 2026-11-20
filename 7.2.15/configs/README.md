# 7.2.15 configs

These are snapshots of `/boot/config-7.2.15-eudaimonia-*` from the laptop.
They are used as-is by `../scripts/build.sh`, which only rewrites
`CONFIG_LOCALVERSION`.

| File | Local version inside | `=y` / `=m` | Purpose |
| --- | --- | --- | --- |
| `config-7.2.15-eudaimonia-01` | `-eudaimonia-01` | 2328 / 189 | Known-good fallback. Kernel `#8` adds `CONFIG_BRIDGE=y` and `CONFIG_BRIDGE_NETFILTER=y`. BTF, Bluetooth, HDMI audio. |
| `config-7.2.15-eudaimonia-02` | `-eudaimonia-01` (stale) | 2261 / 184 | Historical `#4`. Booted, but X failed because the boot entry was named `-02` while modules were installed under `-01`. |
| `config-7.2.15-eudaimonia-03` | `-eudaimonia-03` | 2117 / 165 | Historical lean `#7`. Panicked with `Attempted to kill init!`; do not use. |
| `config-7.2.15-eudaimonia-04` | `-eudaimonia-04` | 2252 / 170 | Previous build default and current ZFSBootMenu default. Conservative lean `#9` based on the `-02` config. Bridge enabled; Bluetooth and HDMI audio disabled. Boot-tested. |
| `config-7.2.15-eudaimonia-05` | `-eudaimonia-05` | 2038 / 163 | Current build default. Leaner AMD-only profile based on `-04`: no Intel CPU support, NUMA, hibernation, HSA/P2P, ATA/SATA, legacy USB HCI, inactive LSMs, or zswap. Adds the amd-pstate EPP boost patch and enables `CONFIG_FONT_TER16x32` for the 2560x1600 panel. Installed and statically verified, not yet boot-tested. |

The build script infers the target local version from the filename:

```
config-7.2.15-eudaimonia-02  ->  -eudaimonia-02
```

That is intentional. The `-02` file was built with `-eudaimonia-01` on disk,
so naming the boot entry `-02` produced a kernel whose modules were installed
under `-01`. Let the script fix it, or pass `--localversion` explicitly.

## Choosing one

`-05` is the build default. `-04` is the current ZFSBootMenu default and has
boot-tested successfully. `-01` is the known-good fallback.

```sh
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-05
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-04
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-01
```

`-01`, `-04`, and `-05` enable `CONFIG_DEBUG_INFO_BTF=y`, so `pahole` must be
installed. `-04` removes Bluetooth and HDMI audio, and keeps the Realtek ALC257
analog audio path. `-05` additionally removes Intel CPU support, NUMA,
hibernation, HSA/P2P, ATA/SATA, legacy USB HCI, inactive LSMs, and zswap, while
keeping AMD IOMMU/pstate, RAPL, KVM/VFIO/vhost, BBR3, and the same graphics,
audio, Wi-Fi, and Ethernet drivers. `-03` is historical and panics.

## Bridge support

Docker/netavark needs a kernel bridge. Without it, container creation fails
with `netlink error: Not supported (os error 95)`. `-01`, `-04`, and `-05`
contain:

```
CONFIG_STP=y
CONFIG_BRIDGE=y
CONFIG_LLC=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_VETH=m
```

`CONFIG_BRIDGE=y` makes `bridge` built-in, so it is available before any module
loading.

## Realtek codec module naming

The laptop has a Realtek ALC257. Newer kernels split the old
`snd-hda-codec-realtek` module, so `modinfo snd_hda_codec_realtek` can report
"MISSING" even when analog audio is fine. The ALC257 path is provided by
`snd-hda-codec-alc269` plus `snd-hda-codec-realtek-lib`, both of which are in
`-01`, `-04`, and `-05`.

Do not hand-edit a config and expect the local version to follow. Either rename
the file to match the desired `eudaimonia-XX` suffix or pass
`--localversion -eudaimonia-XX`.
