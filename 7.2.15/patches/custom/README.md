# Original custom patches

These are the original preempt and BBR3 patches from the linux-tkg custom
patch set used to build the 7.2.15 tree.

They are **reference only**. `../0001-linux-tkg-and-local.patch` already
contains their changes. Applying them again on top of the combined patch will
conflict.

- `100-preempt-3bc8ff7e4d03.patch` ... `113-preempt-db1abbd6d4bc.patch`:
  scheduler/SMP preemption fixes by Chuyi Zhou (ByteDance)
- `200-bbr3-af253e921d6f.patch`: BBRv3 congestion control by Oleksandr
  Natalenko, split into its own module by Eric Naim (CachyOS)
- `201-bbr3-7235d70addc6.patch`: BBR3 naming fix by Peter Jung

The filenames include the upstream commit prefixes. The full authorship and
sign-off information is in each patch header.
