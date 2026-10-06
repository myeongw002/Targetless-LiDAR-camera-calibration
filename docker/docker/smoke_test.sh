#!/usr/bin/env bash
set -euo pipefail
cd /workspace

python3 - <<'PY'
import numpy as np
import torch
import open3d as o3d
import MinkowskiEngine as ME
import sklearn, scipy, yaml, cv2

print('=== versions ===')
print('torch:', torch.__version__)
print('torch CUDA runtime:', torch.version.cuda)
print('Open3D:', o3d.__version__)
print('MinkowskiEngine:', ME.__version__)
print('NumPy:', np.__version__)
print('scikit-learn:', sklearn.__version__)
print('scipy:', scipy.__version__)
print('OpenCV:', cv2.__version__)

assert torch.__version__.startswith('2.8.0')
assert torch.version.cuda == '12.8'
assert o3d.__version__ == '0.18.0'

print('\n=== GPU ===')
assert torch.cuda.is_available(), 'CUDA is not visible inside container'
print('GPU:', torch.cuda.get_device_name(0))
print('compute capability:', torch.cuda.get_device_capability(0))
print('arch list:', torch.cuda.get_arch_list())

# Real MinkowskiEngine sparse convolution, not just an import test.
coords = torch.tensor([
    [0, 0, 0],
    [1, 0, 0],
    [0, 1, 0],
    [0, 0, 1],
], dtype=torch.int32)
bcoords = ME.utils.batched_coordinates([coords], device='cuda')
feats = torch.ones((len(coords), 1), dtype=torch.float32, device='cuda')
x = ME.SparseTensor(features=feats, coordinates=bcoords)
conv = ME.MinkowskiConvolution(1, 4, kernel_size=3, dimension=3).cuda()
y = conv(x)
torch.cuda.synchronize()
print('Minkowski sparse conv:', tuple(y.F.shape), y.F.device)
print('Minkowski CUDA smoke test: PASS')
PY

for exe in \
  openMVG_main_SfMInit_ImageListing \
  openMVG_main_SfM \
  openMVG_main_openMVG2openMVS \
  DensifyPointCloud
do
  command -v "$exe" >/dev/null
  echo "$exe: $(command -v "$exe")"
done

if [[ -x cpp/build/pcl_preprocess ]]; then
  echo "pcl_preprocess: /workspace/cpp/build/pcl_preprocess"
else
  echo "pcl_preprocess not built yet; run: build-targetless-cpp"
fi

# If the user already downloaded the FCGF checkpoint, verify the actual model
# can be constructed and run through the repository extractor.
if [[ -s FCGF/kitti_v0.3.pth ]]; then
  python3 - <<'PY'
import numpy as np
from FCGF.fcgf_utils import FCGF_Extractor

pts = np.array([
    [0.0, 0.0, 0.0],
    [0.3, 0.0, 0.0],
    [0.0, 0.3, 0.0],
    [0.0, 0.0, 0.3],
    [0.3, 0.3, 0.3],
], dtype=np.float32)
extractor = FCGF_Extractor('kitti_v0.3.pth', device='cuda:0')
feat = extractor.extract_fcgf(pts)
print('FCGF feature shape:', feat.shape)
assert feat.shape == (len(pts), 32)
print('FCGF RTX GPU smoke test: PASS')
PY
else
  echo 'FCGF checkpoint not found; run: get-targetless-assets'
fi
