# ZFS/SPL 2.4.4 via ckms

`ckms.ini` is the Chimera Kernel Module System package configuration for
OpenZFS 2.4.4. It builds the `zfs` and `spl` modules into
`/lib/modules/<release>/extra`, strips them, and runs the initramfs hook.

The expected state on this laptop is:

```
/var/lib/ckms/zfs/2.4.4/ckms.ini
/var/lib/ckms/zfs/2.4.4/source -> /usr/src/zfs-2.4.4
/var/lib/ckms/zfs/2.4.4/<release>/x86_64/module/zfs.ko
/var/lib/ckms/zfs/2.4.4/<release>/x86_64/module/spl.ko
```

`../scripts/build.sh` runs:

```sh
ckms -k <release> install zfs=2.4.4
```

and then falls back to the prebuilt `zfs.ko`/`spl.ko` under the state
directory if ckms reports "already installed" but the module tree is empty.
The fallback compresses with `zstd -19` and installs into `extra/`.

The OpenZFS source is **not** included in this repository. On another machine,
install the distribution's `zfs` ckms package (which provides the source and
this configuration) before running the build script, or pass `--skip-zfs` for
a non-ZFS test build.

The modules are signed with the kernel build key. No private key or host ID is
stored here. OpenZFS is CDDL-licensed; only the small ckms configuration file
is included.
