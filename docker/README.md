# Docker environment

This directory provides a reproducible Ubuntu 22.04 environment for the targetless LiDAR-camera calibration pipeline, including support for recent NVIDIA Blackwell GPUs.

## Stack

- Ubuntu 22.04
- CUDA 12.8
- Python 3.10
- PyTorch 2.8.0 + cu128
- Open3D 0.18.0
- MinkowskiEngine 0.5.4 with the CUDA 12.8 / PyTorch 2.8 compatibility patch from NVIDIA/MinkowskiEngine PR #639
- OpenMVG 2.0
- OpenMVS 2.0.1
- PCL

The setup was tested on an NVIDIA GeForce RTX 5070 (compute capability 12.0 / sm_120).

## Build

From the repository's `docker/` directory:

```bash
cp .env.example .env
docker compose build
```

MinkowskiEngine is compiled from source. If the build uses too much memory, reduce the CMake parallelism:

```bash
MAKE_JOBS=2 docker compose build
```

The PyTorch extension build is also limited to two parallel jobs in the Docker image to avoid excessive RAM usage during MinkowskiEngine compilation.

## Verify GPU / MinkowskiEngine

```bash
docker compose run --rm targetless-calib targetless-smoke-test
```

On an RTX 5070, the output should include values similar to:

```text
torch: 2.8.0+cu128
torch CUDA runtime: 12.8
GPU: NVIDIA GeForce RTX 5070
compute capability: (12, 0)
Minkowski CUDA smoke test: PASS
```

## Download the FCGF checkpoint

```bash
docker compose run --rm targetless-calib get-targetless-assets
```

The checkpoint is stored as:

```text
FCGF/kitti_v0.3.pth
```

The helper downloads the current Hugging Face mirror first and falls back to the original legacy URL.

To also download the sample data:

```bash
docker compose run --rm targetless-calib get-targetless-assets --sample-data
```

## Apply compatibility fixes

The repository predates current Open3D and PyTorch releases. The helper below applies a small set of compatibility fixes to the mounted working tree:

```bash
docker compose run --rm targetless-calib apply-targetless-patch /workspace
```

The patch updates the OpenMVG helper paths, removes the Open3D-only `seed=` keyword when required, makes the official FCGF checkpoint load correctly with PyTorch 2.8, restores `reconstruction.py` point-cloud saving, and makes GUI-only calls optional in headless Docker runs.

Review the changes afterwards with:

```bash
git diff
```

## Build the repository's PCL tools

```bash
docker compose run --rm targetless-calib build-targetless-cpp
```

## Interactive shell

```bash
docker compose run --rm targetless-calib bash
```

The repository root is mounted at `/workspace`, so source edits on the host are immediately visible inside the container.

## GUI

GUI is disabled by default. If X11 forwarding is available:

```bash
ENABLE_GUI=1 xhost +local:docker
docker compose run --rm targetless-calib bash
```

Set `ENABLE_GUI=0` again for normal headless reproduction runs.
