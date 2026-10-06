#!/usr/bin/env bash
set -euo pipefail
cd /workspace
cmake -S cpp -B cpp/build -DCMAKE_BUILD_TYPE=Release
cmake --build cpp/build -j"${MAKE_JOBS:-4}"
echo "[OK] C++ tools built under /workspace/cpp/build"
