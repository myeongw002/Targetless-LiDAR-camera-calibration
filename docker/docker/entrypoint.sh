#!/usr/bin/env bash
set -euo pipefail

cd /workspace

if [[ ! -f README.md ]]; then
  echo "[ERROR] /workspace does not contain the calibration repository."
  echo "Set TARGETLESS_REPO_PATH to your host clone path."
  exit 1
fi

mkdir -p tmp
exec "$@"
