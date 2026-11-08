# Credits

This repository collects configuration and patches from several projects. The
files retain their original licenses and authorship.

## Kernel and build inputs

- **Linux kernel** — stable `v7.2.15`
  <https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git>
  GPL-2.0.
- **linux-tkg** — patch selection and build framework
  <https://github.com/Frogging-Family/linux-tkg>
- **BORE scheduler** — firelzrd
  <https://github.com/firelzrd/bore-scheduler>
- **Preempt fixes** — Chuyi Zhou (ByteDance), from the linux-tkg custom patch
  set. See the headers in `7.2.15/patches/custom/`.
- **BBRv3** — Oleksandr Natalenko; split into its own module by Eric Naim
  (CachyOS); naming fix by Peter Jung. See the headers in
  `7.2.15/patches/custom/`.

## Modules and system integration

- **LenovoLegionLinux** — johnfanv2
  <https://github.com/johnfanv2/LenovoLegionLinux>
  GPL-2.0.
- **OpenZFS** — OpenZFS project
  <https://github.com/openzfs/zfs>
  CDDL. Only the `ckms.ini` configuration is included here.
- **Chimera Linux** and **ckms** — <https://chimera-linux.org>
- **ZFSBootMenu** — <https://github.com/zbm-dev/zfsbootmenu>

## Configuration

The `configs/`, `tkg/`, and local patch selections were produced for this
laptop's hardware profile. They contain no signing keys, host IDs, or other
machine secrets.

## License

The scripts and configuration files in this repository are released under
GPL-2.0; see [LICENSE](LICENSE). Patches remain under the license stated in
their source projects and headers. OpenZFS is CDDL-licensed and its source is
not included.
