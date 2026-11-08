#!/usr/bin/env bash
# Top-level dispatcher for post-install verification.
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
            if [[ -x "$ROOT/$VERSION/scripts/verify.sh" ]]; then
                exec "$ROOT/$VERSION/scripts/verify.sh" --help
            fi
            echo "usage: $0 [--version X.Y.Z] [--krel RELEASE]"
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

SCRIPT="$ROOT/$VERSION/scripts/verify.sh"
[[ -x "$SCRIPT" ]] || { echo "error: no verify script for version '$VERSION'" >&2; exit 1; }
exec "$SCRIPT" "${ARGS[@]}"
