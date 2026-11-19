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

`scripts/build.sh` does this automatically. `series` lists the patches for
tooling that understands a quilt-style series file.

The original tkg patch directory is not duplicated here: the combined patch is
the exact result, including new files. The `tkg/` directory records the tkg
configuration used to create it.

## amd-pstate EPP boost

`0002-amd-pstate-epp-boost.patch` adds the CachyOS `7.2/amd-pstate` per-core
EPP boost for recently-busy CPUs, targeting game render threads that sleep on
futexes between frames. It is a backport of five commits:

- `f1e489611c83` cpufreq/amd-pstate: Cache firmware programmed EPP value
- `7f81fd315ee6` cpufreq/amd-pstate: Document missing kernel-doc members
- `23d537e7da52` cpufreq/amd-pstate: Update `cppc_req_cached` before writing MSR
- `ed74145e0698` cpufreq/amd-pstate: Add per-core EPP boost for recently-busy CPUs
- `d0501b00998e` cpufreq/amd-pstate: Document `epp_boost` parameter

The other commits in that series are already present in `v7.2.15`
(`58483b9d3aa9`, `9ca9911f0916`, `52385bbd5760`, `33ebf18e6d24`,
`eb21749db712`, `d47bfc6e6372`).

The feature is opt-in and defaults to off. Enable it at runtime with:

```sh
echo 1 > /sys/module/amd_pstate/parameters/epp_boost
```

It only acts in active mode on MSR/CPPC systems. With the current boot command
line forcing EPP `performance`, it has little effect; it becomes useful if EPP
is lowered to `balance_performance` or dynamic EPP is enabled.

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
