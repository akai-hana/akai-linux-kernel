# Adding this repository to eudaimonia

`eudaimonia` is the meta-repository that collects the system's repositories as
git submodules. The canonical remote is
`git@github.com:akai-hana/eudaimonia.git`.

The copy on this machine is currently at **`~/eudaimonia`**, not
`~/git/eudaimonia`. The steps below use `E=${E:-$HOME/eudaimonia}`; adjust the
path if the meta-repo is moved.

## 0. Repair the meta-repository first

`git status` in `~/eudaimonia` currently fails with:

```
fatal: bad object HEAD
error: object file .git/objects/29/ed1c65e6fa33224f09ffcded78b9aa0e59e3a6 is empty
```

Do not add a submodule to a corrupt repository. Back it up and repair it:

```sh
cp -a "$HOME/eudaimonia" "$HOME/eudaimonia.bak-$(date +%Y%m%d)"
cd "$HOME/eudaimonia"
git fsck --full
```

If the corrupt object is still referenced and cannot be repaired, re-clone and
carry over any local changes:

```sh
git clone --recurse-submodules \
    git@github.com:akai-hana/eudaimonia.git "$HOME/eudaimonia-new"
```

Do not delete the backup until the new checkout, the submodules, and the local
uncommitted work have been compared and restored.

## 1. Add the kernel repository as a submodule

From a healthy meta-repository:

```sh
cd "$HOME/eudaimonia"
git submodule add git@github.com:akai-hana/akai-linux-kernel.git akai-linux-kernel
git commit -m "add akai-linux-kernel"
git push
```

This creates:

- `~/eudaimonia/akai-linux-kernel/` (a second checkout, pinned to a commit)
- a `[submodule "akai-linux-kernel"]` entry in `.gitmodules`
- a gitlink entry for the pinned commit

The primary working copy at `~/git/akai-linux-kernel` is separate. The GitHub
repository remains the source of truth.

## 2. Update the meta-repo scripts

- `pull.sh` already runs `git submodule update --init --recursive` and then
  `git submodule foreach 'git checkout main'`; the new module needs no change.
- `update.sh` is supposed to auto-register unregistered repositories, but it
  reads `git config --get REMOTE.origin.url`. The correct key is
  `remote.origin.url`. Fix that before relying on the auto-add path, and note
  that the script runs `git rm --cached -r` before adding.
- `push.sh` loops over every top-level directory and auto-commits. It will also
  enter the kernel submodule. Because submodule checkouts are usually detached,
  do not leave uncommitted changes there. Commit and push the kernel repo
  first, then update the meta-repo pointer. Review `push.sh` output rather
  than letting it commit inside the submodule.
- Optionally add a line to `README.md` describing the kernel repository. The
  `.gitmodules` file is already the authoritative list.

## 3. Initialize and pin

```sh
cd "$HOME/eudaimonia"
git submodule update --init akai-linux-kernel
git -C akai-linux-kernel checkout main
git -C akai-linux-kernel pull --ff-only
cd "$HOME/eudaimonia"
git add akai-linux-kernel
git commit -m "update akai-linux-kernel"
git push
```

Keep the gitlink at a tested commit. The kernel repository can contain
configs, patches, and scripts that are safe to publish; it must not contain
`certs/signing_key.pem`, ZFS host IDs, or machine-specific boot credentials.

## 4. Validate

```sh
cd "$HOME/eudaimonia"
git submodule status akai-linux-kernel
git ls-tree HEAD akai-linux-kernel
git -C akai-linux-kernel remote -v
git -C akai-linux-kernel log --oneline -1
```

Expected:

- `submodule status` starts with a commit hash followed by
  `akai-linux-kernel`
- `git ls-tree` shows a `160000 commit ... akai-linux-kernel` entry
- the remote is `git@github.com:akai-hana/akai-linux-kernel.git`

## Checklist

- [ ] Back up `~/eudaimonia` and repair the corrupt `.git` object / HEAD
- [ ] Clone or repair the meta-repository until `git status` and `git fsck`
      are clean
- [ ] `git submodule add git@github.com:akai-hana/akai-linux-kernel.git akai-linux-kernel`
- [ ] Confirm `.gitmodules` contains the new URL and path
- [ ] Commit the gitlink at a tested kernel repository commit
- [ ] Push both the kernel repository and the meta-repository
- [ ] Fix `update.sh` (`REMOTE.origin.url` -> `remote.origin.url`) if used
- [ ] Review `push.sh` behavior for detached submodule checkouts
- [ ] Run `pull.sh` and confirm the submodule initializes on a clean machine
- [ ] Confirm the kernel repo contains no signing keys, host IDs, or machine
      secrets
- [ ] Optionally mention the kernel module in the eudaimonia README
