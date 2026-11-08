# 7.2.15 patches

## Combined kernel patch

`0001-linux-tkg-and-local.patch` is the complete applied change set against
upstream `v7.2.15` (`03c639b`):

- 96 files changed, 4249 insertions, 324 deletions
- 7,061 lines / 253,267 bytes
- includes the three files added by the patch set:
  `include/linux/sched/bore.h`, `kernel/sched/bore.c`,
  `net/ipv4/tcp_bbr3.c`

It contains:

- linux-tkg 7.2 patch selections and build tweaks (BORE scheduler, O3,
  `-march=native`/`-mtune=native`, `scripts/setlocalversion` behavior)
- the preempt fixes in `custom/` (100-113)
- BBR3 in `custom/` (200-201)
- the local fix set recorded in the source tree

Apply it with `git apply` from the kernel root:

```sh
git clone --depth 1 --branch v7.2.15 \
    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux
git apply --check /path/to/0001-linux-tkg-and-local.patch
git apply /path/to/0001-linux-tkg-and-local.patch
```

`scripts/build.sh` does this automatically. `series` lists the patch for
tooling that understands a quilt-style series file.

The original tkg patch directory is not duplicated here: the combined patch is
the exact result, including new files. The `tkg/` directory records the tkg
configuration used to create it.

## `custom/`

Original preempt and BBR3 patches, kept for provenance and review:

- `100-preempt-*` through `113-preempt-*`: by Chuyi Zhou (ByteDance), from the
  linux-tkg custom patch set
- `200-bbr3-*`: BBRv3, from Oleksandr Natalenko, with follow-ups by Eric Naim
  (CachyOS) and Peter Jung
- `201-bbr3-*`: BBR3 naming fix

**Do not apply these separately after `0001-...`.** Their changes are already
inside the combined patch; applying them again will conflict.

## `legion/`

`legion/0001-lenovo-legion-makefile-uname.patch` applies to
`LenovoLegionLinux` at `7c19579d13ce686cf1e237699b9a78e80d03c977`:

```diff
-KERNELVERSION  ?= $(shell uname --kernel-release)
+KERNELVERSION  ?= $(shell uname -r)
```

Chimera's BSD-derived `uname` rejects the GNU `--kernel-release` spelling.
Apply from the LenovoLegionLinux repository root with `git apply -p1`.
