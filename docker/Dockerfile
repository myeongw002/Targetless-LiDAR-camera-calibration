# syntax=docker/dockerfile:1.7
# RTX 5070 / Blackwell reproduction environment for
# gitouni/Targetless-LiDAR-camera-calibration
#
# Core stack intentionally follows the MinkowskiEngine CUDA 12.8 compatibility
# patch verified on RTX 5070 Ti (sm_120):
#   Ubuntu 22.04 + CUDA 12.8 + Python 3.10 + PyTorch 2.8 cu128

ARG CUDA_IMAGE=nvidia/cuda:12.8.1-devel-ubuntu22.04
FROM ${CUDA_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG MAKE_JOBS=4
ARG ME_PATCH_COMMIT=6fd7c649a8379db8b2a3066c05720053f65815de

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST=12.0 \
    FORCE_CUDA=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    CC=/usr/bin/gcc-11 \
    CXX=/usr/bin/g++-11

# Native dependencies for MinkowskiEngine, PCL tools, OpenMVG and OpenMVS.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc-11 g++-11 \
    cmake ninja-build git pkg-config wget curl ca-certificates p7zip-full \
    python3 python3-dev python3-pip python3-venv \
    libopenblas-dev \
    libpcl-dev \
    libpng-dev libjpeg-dev libtiff-dev \
    libglu1-mesa-dev libgl1-mesa-dev \
    libxi-dev libxrandr-dev libxinerama-dev libxcursor-dev libxxf86vm-dev \
    graphviz \
    libboost-all-dev \
    libcgal-dev libcgal-qt5-dev \
    libopencv-dev \
    freeglut3-dev libglew-dev libglfw3-dev \
    libatlas-base-dev libsuitesparse-dev libeigen3-dev \
    && rm -rf /var/lib/apt/lists/*

# Python 3.10 is native on Ubuntu 22.04. Keep NumPy <2 because Open3D 0.18.
RUN python3 -m pip install --upgrade \
      "pip==25.0.1" \
      "setuptools==75.3.2" \
      "wheel==0.45.1" \
      "ninja==1.11.1.3" && \
    python3 -m pip install \
      "torch==2.8.0" \
      "torchvision==0.23.0" \
      --index-url https://download.pytorch.org/whl/cu128 && \
    python3 -m pip install \
      "numpy==1.26.4" \
      "scipy==1.11.4" \
      "scikit-learn==1.3.2" \
      "open3d==0.18.0" \
      "PyYAML==6.0.2" \
      "tqdm==4.67.1" \
      "matplotlib==3.8.4" \
      "opencv-python-headless==4.10.0.84" \
      "Pillow==10.4.0"

# MinkowskiEngine 0.5.4 itself predates CUDA 12.8/CCCL. Fetch the exact
# upstream PR #639 head commit that adds CUDA 12.8 / torch 2.8 / GCC 11+
# compatibility and was verified on an RTX 5070 Ti (sm_120).
RUN mkdir -p /opt/MinkowskiEngine && \
    cd /opt/MinkowskiEngine && \
    git init && \
    git remote add origin https://github.com/NVIDIA/MinkowskiEngine.git && \
    git fetch --depth 1 origin pull/639/head && \
    git checkout ${ME_PATCH_COMMIT} && \
    python3 setup.py install --force_cuda --blas=openblas && \
    rm -rf build

# OpenMVG. The calibration repo's helper script is patched later to point here.
RUN git clone --recursive --depth 1 --branch v2.0 \
      https://github.com/openMVG/openMVG.git /opt/openMVG && \
    cmake -S /opt/openMVG/src -B /opt/openMVG_Build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/openmvg-install \
      -DOpenMVG_BUILD_TESTS=OFF \
      -DOpenMVG_BUILD_EXAMPLES=OFF \
      -DOpenMVG_USE_OPENMP=ON && \
    cmake --build /opt/openMVG_Build -j${MAKE_JOBS} && \
    cmake --install /opt/openMVG_Build

# OpenMVS. CUDA is deliberately disabled here. FCGF is the GPU-sensitive part;
# DensifyPointCloud can run on CPU and keeping OpenMVS off CUDA avoids mixing a
# second independent CUDA build surface into this legacy reproduction.
RUN git clone --depth 1 https://github.com/cdcseacave/VCG.git /opt/VCG && \
    git clone --depth 1 --branch v2.0.1 \
      https://github.com/cdcseacave/openMVS.git /opt/openMVS && \
    cmake -S /opt/openMVS -B /opt/openMVS_Build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/openmvs-install \
      -DVCG_ROOT=/opt/VCG \
      -DOpenMVS_USE_CUDA=OFF \
      -DOpenMVS_USE_CERES=OFF && \
    cmake --build /opt/openMVS_Build -j${MAKE_JOBS} && \
    cmake --install /opt/openMVS_Build

ENV PATH=/opt/openmvg-install/bin:/opt/openmvs-install/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/openmvs-install/lib:${LD_LIBRARY_PATH}

# The calibration repository is NOT cloned into the image.
# Mount a host-side clone to /workspace at runtime.
WORKDIR /workspace

COPY docker/entrypoint.sh /usr/local/bin/targetless-entrypoint
COPY docker/get_assets.sh /usr/local/bin/get-targetless-assets
COPY docker/smoke_test.sh /usr/local/bin/targetless-smoke-test
COPY docker/patch_repo.py /usr/local/bin/apply-targetless-patch
COPY docker/build_repo_cpp.sh /usr/local/bin/build-targetless-cpp
RUN chmod +x /usr/local/bin/targetless-entrypoint \
             /usr/local/bin/get-targetless-assets \
             /usr/local/bin/targetless-smoke-test \
             /usr/local/bin/apply-targetless-patch \
             /usr/local/bin/build-targetless-cpp

# Build-time import checks. Actual RTX 5070 CUDA execution is checked at runtime
# because docker build does not receive the host GPU by default.
RUN python3 - <<'PY'
import torch
import open3d as o3d
import MinkowskiEngine as ME
print('torch:', torch.__version__)
print('torch CUDA runtime:', torch.version.cuda)
print('Open3D:', o3d.__version__)
print('MinkowskiEngine:', ME.__version__)
assert torch.__version__.startswith('2.8.0')
assert torch.version.cuda == '12.8'
assert o3d.__version__ == '0.18.0'
PY

ENTRYPOINT ["/usr/local/bin/targetless-entrypoint"]
CMD ["bash"]
