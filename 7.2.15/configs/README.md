# 7.2.15 configs

These are snapshots of `/boot/config-7.2.15-eudaimonia-*` from the laptop.
They are used as-is by `../scripts/build.sh`, which only rewrites
`CONFIG_LOCALVERSION`.

| File | Local version inside | `=y` / `=m` | Purpose |
| --- | --- | --- | --- |
| `config-7.2.15-eudaimonia-01` | `-eudaimonia-01` | 2322 / 191 | Known-good fallback. BTF, Bluetooth, HDMI audio. |
| `config-7.2.15-eudaimonia-02` | `-eudaimonia-01` (stale) | 2261 / 184 | Historical. The stale local version caused the X failure. |
| `config-7.2.15-eudaimonia-03` | `-eudaimonia-03` | 2117 / 165 | Lean current profile. Bluetooth and HDMI audio disabled. |

The build script infers the target local version from the filename:

```
config-7.2.15-eudaimonia-02  ->  -eudaimonia-02
```

That is intentional. The `-02` file was built with `-eudaimonia-01` on disk,
so naming the boot entry `-02` produced a kernel whose modules were installed
under `-01`. Let the script fix it, or pass `--localversion` explicitly.

## Choosing one

```sh
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-03
sudo ./build.sh --config 7.2.15/configs/config-7.2.15-eudaimonia-01
```

`-01` enables `CONFIG_DEBUG_INFO_BTF=y`, so `pahole` must be installed. `-03`
does not. `-01` also enables Bluetooth and HDMI audio, which `-03` removes.

Do not hand-edit a config and expect the local version to follow. Either rename
the file to match the desired `eudaimonia-XX` suffix or pass
`--localversion -eudaimonia-XX`.
