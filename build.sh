#!/usr/bin/env bash
# Top-level dispatcher. Version-specific logic lives in <version>/scripts/.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VERSION="${KERNEL_VERSION:-7.2.15}"
ARGS=()

while (($#)); do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] || { echo "error: --version needs a value" >&2; exit 2; }
            VERSION=$2
            shift 2
            ;;
        --version=*)
            VERSION=${1#*=}
            shift
            ;;
        -h|--help)
            if [[ -x "$ROOT/$VERSION/scripts/build.sh" ]]; then
                exec "$ROOT/$VERSION/scripts/build.sh" --help
            fi
            echo "usage: $0 [--version X.Y.Z] [build options]"
            echo "Available versions:"
            for d in "$ROOT"/*/; do
                [[ -x "$d/scripts/build.sh" ]] || continue
                printf '  %s\n' "$(basename -- "$d")"
            done
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

SCRIPT="$ROOT/$VERSION/scripts/build.sh"
[[ -x "$SCRIPT" ]] || { echo "error: no build script for version '$VERSION'" >&2; exit 1; }
exec "$SCRIPT" "${ARGS[@]}"
