#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VDIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO=$(cd -- "$VDIR/.." && pwd)
VERSION=$(basename -- "$VDIR")
CONF="$VDIR/build.conf"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

[[ -f "$CONF" ]] || die "missing $CONF"
# shellcheck disable=SC1090
. "$CONF"

[[ "$VERSION" == "$KERNEL_VERSION" ]] || warn "directory '$VERSION' != KERNEL_VERSION '$KERNEL_VERSION'"

CONFIG_PATH=""
LOCALVERSION=""
SOURCE_DIR=""
LEGION_SOURCE=""
BUILD_DIR="$REPO/.build"
JOBS="${JOBS:-$(nproc)}"
COMPILER="${COMPILER:-llvm}"
SKIP_PATCHES=0
SKIP_INSTALL=0
SKIP_ZFS=0
SKIP_LEGION=0
SKIP_INITRAMFS=0
SKIP_VERIFY=0
CLEAN=0

usage() {
    cat <<EOF
usage: $0 [options]

Build and install Linux $KERNEL_VERSION for the eudaimonia configuration.

options:
  --config PATH          kernel config to use
                         default: $DEFAULT_CONFIG
  --localversion SUFFIX  override CONFIG_LOCALVERSION, e.g. -eudaimonia-03
  --source DIR           use an existing (already patched, unless
                         --skip-patches is given) kernel source tree
  --build-dir DIR        clone/scratch directory (default: $BUILD_DIR)
  --legion-source DIR    use an existing LenovoLegionLinux checkout
  --jobs N, -j N         build parallelism (default: nproc)
  --compiler NAME        compiler toolchain: llvm (default) or gcc
  --skip-patches         do not apply patches/0001-... (tree must be ready)
  --skip-install         compile only; do not install anything
  --skip-zfs             do not build/install ZFS and SPL
  --skip-legion          do not build/install the legion-laptop module
  --skip-initramfs       do not run update-initramfs/mkinitcpio
  --skip-verify          do not run the post-install verifier
  --clean                run 'make clean' before building
  -h, --help             show this help

The localversion is derived from the config filename, e.g.
config-${KERNEL_VERSION}-eudaimonia-03 -> -eudaimonia-03. This overrides a
stale CONFIG_LOCALVERSION stored inside the config (the historical -02 bug).

The ZFSBootMenu default is never modified. Test the new kernel explicitly
and keep the known-good entry as fallback.
EOF
}

need_value() {
    [[ $# -ge 2 ]] || die "$1 requires a value"
}

while (($#)); do
    case "$1" in
        --config)
            need_value "$@"; CONFIG_PATH=$2; shift 2 ;;
        --config=*) CONFIG_PATH=${1#*=}; shift ;;
        --localversion)
            need_value "$@"; LOCALVERSION=$2; shift 2 ;;
        --localversion=*) LOCALVERSION=${1#*=}; shift ;;
        --source)
            need_value "$@"; SOURCE_DIR=$2; shift 2 ;;
        --source=*) SOURCE_DIR=${1#*=}; shift ;;
        --build-dir)
            need_value "$@"; BUILD_DIR=$2; shift 2 ;;
        --build-dir=*) BUILD_DIR=${1#*=}; shift ;;
        --legion-source)
            need_value "$@"; LEGION_SOURCE=$2; shift 2 ;;
        --legion-source=*) LEGION_SOURCE=${1#*=}; shift ;;
        --jobs|-j)
            need_value "$@"; JOBS=$2; shift 2 ;;
        --jobs=*) JOBS=${1#*=}; shift ;;
        --compiler)
            need_value "$@"; COMPILER=$2; shift 2 ;;
        --compiler=*) COMPILER=${1#*=}; shift ;;
        --skip-patches) SKIP_PATCHES=1; shift ;;
        --skip-install) SKIP_INSTALL=1; shift ;;
        --skip-zfs) SKIP_ZFS=1; shift ;;
        --skip-legion) SKIP_LEGION=1; shift ;;
        --skip-initramfs) SKIP_INITRAMFS=1; shift ;;
        --skip-verify) SKIP_VERIFY=1; shift ;;
        --clean) CLEAN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

[[ $EUID -eq 0 ]] || die "run as root: sudo $0 ..."
[[ "$JOBS" =~ ^[0-9]+$ ]] && [[ "$JOBS" -ge 1 ]] || die "invalid --jobs value: $JOBS"

if [[ -z "$CONFIG_PATH" ]]; then
    CONFIG_PATH="$REPO/$DEFAULT_CONFIG"
elif [[ "$CONFIG_PATH" != /* ]]; then
    CONFIG_PATH="$PWD/$CONFIG_PATH"
fi
CONFIG_DIR=$(cd -- "$(dirname -- "$CONFIG_PATH")" 2>/dev/null && pwd) \
    || die "config directory not found: $CONFIG_PATH"
CONFIG_PATH="$CONFIG_DIR/$(basename -- "$CONFIG_PATH")"
[[ -f "$CONFIG_PATH" ]] || die "config not found: $CONFIG_PATH"

[[ "$KERNEL_PATCH" = /* ]] || KERNEL_PATCH="$REPO/$KERNEL_PATCH"
[[ "$LEGION_PATCH" = /* ]] || LEGION_PATCH="$REPO/$LEGION_PATCH"
[[ -f "$KERNEL_PATCH" ]] || die "kernel patch not found: $KERNEL_PATCH"
[[ -f "$LEGION_PATCH" ]] || die "legion patch not found: $LEGION_PATCH"

if [[ -n "$SOURCE_DIR" ]]; then
    SOURCE_DIR=$(cd -- "$SOURCE_DIR" 2>/dev/null && pwd) \
        || die "source directory not found: $SOURCE_DIR"
fi

mkdir -p "$BUILD_DIR"
BUILD_DIR=$(cd -- "$BUILD_DIR" && pwd)
[[ -n "$SOURCE_DIR" ]] || SOURCE_DIR="$BUILD_DIR/linux-$KERNEL_VERSION"

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }
for cmd in make bc bison flex perl cpio zstd openssl rsync git depmod install; do
    need_cmd "$cmd"
done

SED_TMPDIR=""
cleanup() { [[ -n "$SED_TMPDIR" ]] && rm -rf -- "$SED_TMPDIR"; }
trap cleanup EXIT

ensure_gnu_sed() {
    if sed --version 2>/dev/null | grep -q 'GNU sed'; then
        return
    fi
    if [[ -x /usr/local/gnubin/sed ]]; then
        PATH="/usr/local/gnubin:$PATH"
        export PATH
        log "using GNU sed from /usr/local/gnubin"
        return
    fi
    if command -v gsed >/dev/null 2>&1; then
        SED_TMPDIR=$(mktemp -d)
        ln -s "$(command -v gsed)" "$SED_TMPDIR/sed"
        PATH="$SED_TMPDIR:$PATH"
        export PATH
        log "using GNU sed from gsed"
        return
    fi
    die "GNU sed is required for the kernel build; install gsed or add GNU sed to PATH"
}

ensure_gnu_sed

MAKE_ARGS=()
case "$COMPILER" in
    llvm)
        MAKE_ARGS=(LLVM=1)
        for cmd in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
            need_cmd "$cmd"
        done
        ;;
    gcc)
        MAKE_ARGS=(CC=gcc)
        need_cmd gcc
        ;;
    *)
        die "unknown compiler '$COMPILER' (use llvm or gcc)"
        ;;
esac
if [[ $SKIP_INSTALL -eq 0 ]]; then
    if ! command -v update-initramfs >/dev/null 2>&1 && ! command -v mkinitcpio >/dev/null 2>&1; then
        die "neither update-initramfs nor mkinitcpio found (use --skip-initramfs)"
    fi
fi
if [[ $SKIP_INSTALL -eq 0 && $SKIP_ZFS -eq 0 ]]; then
    need_cmd ckms
fi

if [[ -d "$SOURCE_DIR/.git" ]]; then
    log "using kernel source: $SOURCE_DIR"
else
    if [[ -d "$SOURCE_DIR" && -n "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]]; then
        die "source directory exists but is not a git tree: $SOURCE_DIR"
    fi
    log "cloning $KERNEL_GIT_URL ($KERNEL_GIT_REF)"
    git clone --depth 1 --branch "$KERNEL_GIT_REF" "$KERNEL_GIT_URL" "$SOURCE_DIR"
fi

log "source version: $(git -C "$SOURCE_DIR" describe --tags --always 2>/dev/null || echo unknown)"

if [[ $SKIP_PATCHES -eq 0 ]]; then
    if git -C "$SOURCE_DIR" apply --check "$KERNEL_PATCH" 2>/dev/null; then
        log "applying $KERNEL_PATCH"
        git -C "$SOURCE_DIR" apply "$KERNEL_PATCH"
    elif git -C "$SOURCE_DIR" apply --reverse --check "$KERNEL_PATCH" 2>/dev/null; then
        log "kernel patch is already applied"
    else
        die "kernel patch does not apply; prepare the tree or use --skip-patches if it is already patched"
    fi
fi

log "using config: $CONFIG_PATH"
install -m 644 "$CONFIG_PATH" "$SOURCE_DIR/.config"

stored_lv=$(sed -n 's/^CONFIG_LOCALVERSION="\(.*\)"$/\1/p' "$CONFIG_PATH" | head -n 1)
if [[ -n "$LOCALVERSION" ]]; then
    log "localversion from command line: $LOCALVERSION"
else
    base=$(basename -- "$CONFIG_PATH")
    prefix="config-${KERNEL_VERSION}-eudaimonia-"
    if [[ "$base" == "$prefix"* && -n "${base#"$prefix"}" ]]; then
        LOCALVERSION="-eudaimonia-${base#"$prefix"}"
        if [[ -n "$stored_lv" && "$stored_lv" != "$LOCALVERSION" ]]; then
            warn "config stores CONFIG_LOCALVERSION=$stored_lv; overriding with $LOCALVERSION"
        fi
        log "localversion from config filename: $LOCALVERSION"
    elif [[ -n "$stored_lv" ]]; then
        LOCALVERSION=$stored_lv
        log "localversion from config: $LOCALVERSION"
    else
        die "cannot determine localversion; pass --localversion"
    fi
fi
[[ "$LOCALVERSION" == -* ]] || LOCALVERSION="-$LOCALVERSION"

"$SOURCE_DIR/scripts/config" --file "$SOURCE_DIR/.config" --set-str LOCALVERSION "$LOCALVERSION"
make -C "$SOURCE_DIR" "${MAKE_ARGS[@]}" olddefconfig

if grep -q '^CONFIG_DEBUG_INFO_BTF=y' "$SOURCE_DIR/.config"; then
    need_cmd pahole
fi

KREL=$(make -C "$SOURCE_DIR" "${MAKE_ARGS[@]}" -s kernelrelease | tail -n 1)
[[ -n "$KREL" ]] || die "make kernelrelease returned an empty release"
EXPECTED="${KERNEL_VERSION}${LOCALVERSION}"
[[ "$KREL" == "$EXPECTED" ]] || die "kernelrelease mismatch: got '$KREL', expected '$EXPECTED'"
log "kernel release: $KREL"

if [[ $CLEAN -eq 1 ]]; then
    log "cleaning build tree"
    make -C "$SOURCE_DIR" "${MAKE_ARGS[@]}" clean
fi

log "building with $JOBS jobs ($COMPILER)"
make -C "$SOURCE_DIR" "${MAKE_ARGS[@]}" -j"$JOBS"

if [[ $SKIP_INSTALL -eq 1 ]]; then
    log "skipping installation (--skip-install)"
    log "built: $KREL"
    exit 0
fi

log "installing modules"
make -C "$SOURCE_DIR" "${MAKE_ARGS[@]}" -j"$JOBS" modules_install
log "installing kernel image"
make -C "$SOURCE_DIR" "${MAKE_ARGS[@]}" install

install -m 644 "$SOURCE_DIR/.config" "/boot/config-$KREL"
[[ -f "$SOURCE_DIR/System.map" ]] && install -m 644 "$SOURCE_DIR/System.map" "/boot/System.map-$KREL"
[[ -s "/boot/vmlinuz-$KREL" ]] || die "missing /boot/vmlinuz-$KREL after make install"
MODDIR="/lib/modules/$KREL"
[[ -d "$MODDIR" ]] || die "missing module tree: $MODDIR"
if [[ ! -e "$MODDIR/build" ]]; then
    ln -s "$SOURCE_DIR" "$MODDIR/build"
fi

if [[ $SKIP_ZFS -eq 0 ]]; then
    log "building/installing ZFS and SPL $ZFS_VERSION for $KREL"
    rm -f "$MODDIR"/extra/zfs.ko "$MODDIR"/extra/zfs.ko.* \
          "$MODDIR"/extra/spl.ko "$MODDIR"/extra/spl.ko.* 2>/dev/null || true

    CKMS_STATE="${CKMS_STATE:-/var/lib/ckms}"
    CKMS_ARGS=(-k "$KREL")
    [[ -n "${CKMS_STATE:-}" ]] && CKMS_ARGS+=(-s "$CKMS_STATE")
    if [[ ! -f "$CKMS_STATE/zfs/$ZFS_VERSION/ckms.ini" && -f "$VDIR/zfs/ckms.ini" ]]; then
        install -D -m 644 "$VDIR/zfs/ckms.ini" "$CKMS_STATE/zfs/$ZFS_VERSION/ckms.ini"
        warn "installed ckms.ini; the ZFS source must already exist at $CKMS_STATE/zfs/$ZFS_VERSION/source"
    fi

    if ! ckms "${CKMS_ARGS[@]}" install "zfs=$ZFS_VERSION"; then
        warn "ckms install returned an error; checking for prebuilt modules"
    fi

    for m in zfs spl; do
        if ! modinfo -k "$KREL" -F vermagic "$m" >/dev/null 2>&1; then
            src=$(find "$CKMS_STATE/zfs/$ZFS_VERSION/$KREL" -type f -name "$m.ko" 2>/dev/null | head -n 1)
            [[ -n "$src" ]] || die "ZFS module '$m' was not installed and no prebuilt $m.ko exists for $KREL"
            install -d "$MODDIR/extra"
            zstd -q -f -19 "$src" -o "$MODDIR/extra/$m.ko.zst"
            log "installed $m.ko.zst from ckms build output"
        fi
    done
    depmod -a "$KREL"
fi

if [[ $SKIP_LEGION -eq 0 ]]; then
    if [[ -n "$LEGION_SOURCE" ]]; then
        LEGION_SRC=$(cd -- "$LEGION_SOURCE" 2>/dev/null && pwd) \
            || die "legion source not found: $LEGION_SOURCE"
        log "using legion source: $LEGION_SRC"
    else
        LEGION_SRC="$BUILD_DIR/LenovoLegionLinux"
        if [[ ! -d "$LEGION_SRC/.git" ]]; then
            log "cloning $LEGION_GIT_URL"
            git clone "$LEGION_GIT_URL" "$LEGION_SRC"
        fi
        git -C "$LEGION_SRC" fetch --all --tags
        git -C "$LEGION_SRC" checkout --detach "$LEGION_GIT_REF"
    fi

    if git -C "$LEGION_SRC" apply --check "$LEGION_PATCH" 2>/dev/null; then
        git -C "$LEGION_SRC" apply "$LEGION_PATCH"
    elif git -C "$LEGION_SRC" apply --reverse --check "$LEGION_PATCH" 2>/dev/null; then
        log "legion patch is already applied"
    else
        die "legion patch does not apply to $LEGION_SRC"
    fi

    log "building legion-laptop for $KREL"
    make -C "$LEGION_SRC/kernel_module" KERNELVERSION="$KREL" -j"$JOBS"
    install -D -m 644 "$LEGION_SRC/kernel_module/legion-laptop.ko" "$MODDIR/extra/legion-laptop.ko"
    depmod -a "$KREL"
fi

if [[ $SKIP_INITRAMFS -eq 0 ]]; then
    log "updating initramfs for $KREL"
    if command -v update-initramfs >/dev/null 2>&1; then
        update-initramfs -u -k "$KREL"
    elif command -v mkinitcpio >/dev/null 2>&1; then
        mkinitcpio -k "$KREL" -g "/boot/initrd.img-$KREL"
    else
        die "no initramfs tool found (use --skip-initramfs)"
    fi
fi

if [[ $SKIP_VERIFY -eq 0 ]]; then
    VERIFY_ARGS=(--krel "$KREL")
    [[ $SKIP_ZFS -eq 1 ]] && VERIFY_ARGS+=(--skip-zfs)
    [[ $SKIP_LEGION -eq 1 ]] && VERIFY_ARGS+=(--skip-legion)
    [[ $SKIP_INITRAMFS -eq 1 ]] && VERIFY_ARGS+=(--skip-initramfs)
    "$VDIR/scripts/verify.sh" "${VERIFY_ARGS[@]}"
fi

cat <<EOF

Built and installed: $KREL

The ZFSBootMenu default was NOT changed. Test this entry explicitly and keep
the known-good kernel as fallback. On dinit systems use dinitctl, not systemctl.
EOF
