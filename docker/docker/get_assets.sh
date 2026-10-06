#!/usr/bin/env bash
set -euo pipefail
cd /workspace

MODEL_DST="FCGF/kitti_v0.3.pth"
HF_URL="https://huggingface.co/chrischoy/FCGF/resolve/main/KITTI-v0.3-ResUNetBN2C-conv1-5-nout32.pth"
LEGACY_URL="https://node1.chrischoy.org/data/publications/fcgf/KITTI-v0.3-ResUNetBN2C-conv1-5-nout32.pth"

mkdir -p FCGF
if [[ ! -s "$MODEL_DST" ]]; then
  echo "[assets] downloading FCGF KITTI checkpoint..."
  if ! wget -c "$HF_URL" -O "$MODEL_DST"; then
    echo "[assets] Hugging Face mirror failed; trying legacy URL..."
    wget -c "$LEGACY_URL" -O "$MODEL_DST"
  fi
fi

echo "[assets] FCGF checkpoint: $MODEL_DST"

if [[ "${1:-}" == "--sample-data" ]]; then
  DATA_URL="https://github.com/gitouni/Targetless-LiDAR-camera-calibration/releases/download/data/pre_data.7z"
  ARCHIVE="pre_data.7z"
  if [[ ! -s "$ARCHIVE" ]]; then
    echo "[assets] downloading upstream calibration sample data..."
    wget -c "$DATA_URL" -O "$ARCHIVE"
  fi
  echo "[assets] extracting sample archive into /workspace ..."
  7z x -y "$ARCHIVE" -o/workspace
fi
