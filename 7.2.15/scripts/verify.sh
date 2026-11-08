#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VDIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO=$(cd -- "$VDIR/.." && pwd)
CONF="$VDIR/build.conf"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
pass() { printf '  ok   %s\n' "$*"; OK=$((OK + 1)); }
bad() { printf '  FAIL %s\n' "$*"; FAIL=$((FAIL + 1)); }
note() { printf '  warn %s\n' "$*"; WARN=$((WARN + 1)); }

[[ -f "$CONF" ]] || die "missing $CONF"
# shellcheck disable=SC1090
. "$CONF"

KREL=""
SKIP_ZFS=0
SKIP_LEGION=0
SKIP_INITRAMFS=0

usage() {
    cat <<EOF
usage: $0 [--krel RELEASE] [--skip-zfs] [--skip-legion] [--skip-initramfs]

Verify the installed $KERNEL_VERSION kernel, modules, ZFS/SPL, legion-laptop,
initramfs and key config options. Without --krel the running kernel is used.

This script only reads the system. It exits non-zero if a hard check fails.
EOF
}

need_value() {
    [[ $# -ge 2 ]] || die "$1 requires a value"
}

while (($#)); do
    case "$1" in
        --krel)
            need_value "$@"; KREL=$2; shift 2 ;;
        --krel=*) KREL=${1#*=}; shift ;;
        --skip-zfs) SKIP_ZFS=1; shift ;;
        --skip-legion) SKIP_LEGION=1; shift ;;
        --skip-initramfs) SKIP_INITRAMFS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

[[ -n "$KREL" ]] || KREL=$(uname -r)
[[ -n "$KREL" ]] || die "cannot determine kernel release"
MODDIR="/lib/modules/$KREL"
CONFIG="/boot/config-$KREL"

OK=0
FAIL=0
WARN=0

printf 'verifying %s\n' "$KREL"

check_file() {
    if [[ -s "$1" ]]; then
        pass "$1"
    else
        bad "missing or empty: $1"
    fi
}

config_is() {
    local sym=$1 want=$2
    if grep -q "^${sym}=${want}$" "$CONFIG" 2>/dev/null; then
        pass "config $sym=$want"
    else
        bad "config $sym is not '$want'"
    fi
}

config_not() {
    local sym=$1
    if grep -q "^${sym}[= ]" "$CONFIG" 2>/dev/null; then
        bad "config $sym is enabled (expected absent)"
    else
        pass "config $sym absent"
    fi
}

check_module() {
    local m=$1 v k
    v=$(modinfo -k "$KREL" -F vermagic "$m" 2>/dev/null || true)
    if [[ "$v" == "$KREL" || "$v" == "$KREL "* ]]; then
        pass "module $m vermagic: $v"
    else
        bad "module $m missing or wrong vermagic: ${v:-<none>}"
    fi
    k=$(modinfo -k "$KREL" -F sig_key "$m" 2>/dev/null || true)
    if [[ -n "$k" ]]; then
        pass "module $m signed: $k"
    else
        note "module $m is not signed"
    fi
}

check_file "/boot/vmlinuz-$KREL"
check_file "/boot/System.map-$KREL"
check_file "$CONFIG"
if [[ $SKIP_INITRAMFS -eq 0 ]]; then
    check_file "/boot/initrd.img-$KREL"
fi

if [[ -f "$CONFIG" ]]; then
    lv=$(sed -n 's/^CONFIG_LOCALVERSION="\(.*\)"$/\1/p' "$CONFIG" | head -n 1)
    if [[ "${KERNEL_VERSION}${lv}" == "$KREL" ]]; then
        pass "config localversion matches release (${KERNEL_VERSION}${lv})"
    else
        bad "config localversion mismatch: ${KERNEL_VERSION}${lv} != $KREL"
    fi

    config_is CONFIG_SCHED_BORE y
    config_is CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3 y
    config_is CONFIG_MODULE_SIG y
    config_is CONFIG_MODULE_SIG_ALL y
    config_is CONFIG_MODULE_COMPRESS_ZSTD y
    config_is CONFIG_DRM_AMD_DC y
    config_is CONFIG_AMD_IOMMU y
    config_is CONFIG_X86_AMD_PSTATE y
    config_is CONFIG_DRM_AMDGPU m
    config_is CONFIG_MT7921E m
    config_is CONFIG_R8169 m
    config_is CONFIG_SND_HDA_INTEL m
    config_is CONFIG_NVME_CORE y
    config_is CONFIG_PSTORE y
    config_not CONFIG_MODULE_SIG_FORCE

    if [[ "$KREL" == *-eudaimonia-03* ]]; then
        config_is CONFIG_TCP_CONG_BBR3 m
        config_not CONFIG_BT
        config_not CONFIG_SND_HDA_CODEC_HDMI
        config_not CONFIG_DRM_AMD_DC_HDCP
        config_not CONFIG_DEBUG_INFO_BTF
    else
        note "lean-profile checks skipped for $KREL (only -03 is lean)"
    fi
fi

if [[ -d "$MODDIR" ]]; then
    pass "$MODDIR"
    if [[ -f "$MODDIR/modules.dep" ]]; then
        pass "$MODDIR/modules.dep"
        if [[ $SKIP_ZFS -eq 0 ]] && ! grep -qE 'extra/zfs\.ko[^:]*:.*extra/spl\.ko' "$MODDIR/modules.dep"; then
            bad "modules.dep lacks zfs -> spl dependency"
        fi
    else
        bad "missing $MODDIR/modules.dep"
    fi
else
    bad "missing module tree: $MODDIR"
fi

if [[ $SKIP_ZFS -eq 0 ]]; then
    check_module zfs
    check_module spl
fi
if [[ $SKIP_LEGION -eq 0 ]]; then
    check_module legion-laptop
fi
if [[ "$KREL" == *-eudaimonia-03* ]]; then
    check_module tcp_bbr3
fi

if [[ $SKIP_INITRAMFS -eq 0 && -s "/boot/initrd.img-$KREL" ]]; then
    if command -v lsinitramfs >/dev/null 2>&1; then
        LIST=$(lsinitramfs "/boot/initrd.img-$KREL" 2>/dev/null || true)
        if [[ -z "$LIST" ]]; then
            bad "lsinitramfs could not read /boot/initrd.img-$KREL"
        else
            if [[ $SKIP_ZFS -eq 0 ]]; then
                for pat in 'zfs\.ko' 'spl\.ko' 'scripts/local-top/zfs' 'conf/conf.d/zfs'; do
                    if grep -Eq "$pat" <<<"$LIST"; then
                        pass "initramfs contains $pat"
                    else
                        bad "initramfs lacks $pat"
                    fi
                done
                for pat in '(^|/)(zfs|zpool|mount\.zfs)$'; do
                    if grep -Eq "$pat" <<<"$LIST"; then
                        pass "initramfs contains ZFS userspace tools"
                    else
                        bad "initramfs lacks ZFS userspace tools"
                    fi
                done
            fi
        fi
    else
        note "lsinitramfs not found; skipping initramfs content checks"
    fi
fi

printf '\n%d passed, %d failed, %d warnings\n' "$OK" "$FAIL" "$WARN"
[[ $FAIL -eq 0 ]]
