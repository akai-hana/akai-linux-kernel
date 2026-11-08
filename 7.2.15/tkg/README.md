# linux-tkg reference files

These files record how the 7.2.15 source tree was originally configured with
linux-tkg. They are **not** used by `../scripts/build.sh`.

- `customization.cfg`: the tkg configuration. It records `_compiler="llvm"`,
  `_version="v7.2.15"`, and `_kernel_localversion="eudaimonia-06"`.
- `kernelconfig.new`: the saved tkg base config. Its
  `CONFIG_LOCALVERSION` is empty.

The actual release name is not taken from `customization.cfg`. The selected
file in `../configs/` and `--localversion` are authoritative, and the build
script derives the local version from the config filename.

The applied tkg changes are contained in
`../patches/0001-linux-tkg-and-local.patch`. The upstream tkg patch directory
is not copied here because the combined patch is the exact applied result.
