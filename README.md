# Targetless LiDAR camera calibration
## Official Implementation of the paper "Targetless Extrinsic Calibration of Camera and Low-resolution 3-D LiDAR".

![](doc/Abstract.jpg)

* Paper: [[IEEE](https://ieeexplore.ieee.org/document/10097551)] | [[TechRxiv](https://figshare.com/s/0b4cd10ff392b010e19c)]
* Data: Our [data](https://github.com/gitouni/Targetless-LiDAR-camera-calibration/releases/download/data/pre_data.7z) is available for reproduction.
* All advice, citations, and support will be acknowledged and appreciated.
* Feel free to propose any issues you meet.
* Thanks for citing our work:

```text
@ARTICLE{10097551,
  author={Ou, Ni and Cai, Hanyu and Yang, Jiawen and Wang, Junzheng},
  journal={IEEE Sensors Journal},
  title={Targetless Extrinsic Calibration of Camera and Low-Resolution 3-D LiDAR},
  year={2023},
  volume={23},
  number={10},
  pages={10889-10899},
  doi={10.1109/JSEN.2023.3263833}}
```

## RTX 5070 Docker branch

This branch keeps the original algorithm while providing a modern runtime for RTX 5070 / Blackwell GPUs.

The Docker setup is under [`docker/`](docker/) and mounts this repository to `/workspace` instead of cloning another copy into the image.

Main runtime stack:

```text
Ubuntu 22.04
CUDA 12.8
Python 3.10
PyTorch 2.8.0 + cu128
MinkowskiEngine 0.5.4 with CUDA 12.8 compatibility patch
Open3D 0.18.0
```

See [`docker/README.md`](docker/README.md) for Docker build and run instructions.

# Environment

Original implementation environment:

* Ubuntu 18.04/20.04 or Windows 10
* Python 3.8 or later
* g++ 7 or later
* cmake 3.1.0 or later

# Dependencies

* [OpenMVG](https://github.com/openMVG/openMVG)
* [OpenMVS](https://github.com/cdcseacave/openMVS)
* [MinkowskiEngine](https://github.com/NVIDIA/MinkowskiEngine#installation)
* [Open3D](https://github.com/isl-org/Open3D)
* [scikit-learn](https://scikit-learn.org/stable/)

<details>
  <summary>How to install OpenMVG</summary>

Install OpenMVG according to its build instructions. Remember to enable `-DOpenMVG_USE_OPENMP=ON` if OpenMP is available.
</details>

# Repository layout

```text
.
├── src/        # Python executables / pipeline code
├── config/     # Runtime configuration and calibration parameter files
├── FCGF/       # FCGF model code and checkpoint
├── RANSAC/     # RANSAC helper code
├── view/       # Visualization helpers
├── cpp/        # PCL preprocessing tools
├── docker/     # RTX 5070 Docker environment
└── doc/        # Figures and OpenMVG helper script
```

The main runtime configuration is [`config/config.yml`](config/config.yml):

```yaml
work_dir: building_imu
res_dir: res
method: ranreg
```

# Reprojection Comparison with Ground-Truth

| Proposed Calibration | Checkboard Calibration |
| --- | --- |
| ![](https://github.com/gitouni/Targetless-LiDAR-camera-calibration/blob/main/doc/demo_Proposed_010.png) | ![](https://github.com/gitouni/Targetless-LiDAR-camera-calibration/blob/main/doc/demo_GT_010.png) |

You can use [`src/view_projection.py`](src/view_projection.py) and the provided data to generate similar figures.

# Step 1: Prepare Image and LiDAR data

Add synchronized image and LiDAR data to `./data/img` and `./data/pcd`. If you do not have your own data, download the provided sample data.

```bash
mkdir -p data/img data/pcd
```

Use the C++ tools to preprocess LiDAR data and save it to `./data/proc_pcd`.

```bash
cd cpp
mkdir -p build && cd build
cmake ..
make
./preprocess ../../data/pcd ../../data/proc_pcd
```

This preprocessing pipeline is accelerated by OpenMP. You can use the viewer executable to check the filtered PCD files.

# Step 2: Estimate image poses using OpenMVG

SequentialSfM is recommended for this task.

The helper script is [`doc/SfM_SequentialPipeline.py`](doc/SfM_SequentialPipeline.py).

```bash
python doc/SfM_SequentialPipeline.py input_dir output_dir ins_file
```

After SfM finishes, `sfm_data.json` can be found in the reconstruction output directory.

# Step 3: Estimate initial LiDAR poses with RANSAC

Set the global naming parameters in [`config/config.yml`](config/config.yml), then run:

```bash
python src/multiway_reg.py --input_dir data/proc_pcd
```

The result is an Open3D PoseGraph such as:

```text
res/<work_dir>/ranreg_raw.json
```

This process is one of the most time-consuming parts of the framework.

Useful arguments include:

* `step`: use one PCD every N frames.
* `pose_graph`: output PoseGraph filename.
* `voxel_size`: downsampling voxel size.
* `radius`: information-matrix radius.
* `ne_method`: normal estimation method.

# Step 4: Cluster Extraction and Integration (CEI)

## 4.1 Cluster extraction

Use RANSAC hand-eye calibration to extract inlier LiDAR poses:

```bash
python src/TL_solve_ransac.py \
  --camera_json /path/to/sfm_data.json \
  --pcd_json /path/to/ranreg_raw.json
```

The process generates a clique description such as:

```text
res/<work_dir>/clique_ranreg.json
```

| Raw graph | Clique Extraction |
| --- | --- |
| ![](doc/recon_raw_graph.png) | ![](doc/recon_clique.png) |

## 4.2 Refine each subgraph

```bash
python src/clique_split_refine.py \
  --input_dir data/proc_pcd \
  --clique_file clique_ranreg.json \
  --init_pose_graph ranreg_raw.json
```

This generates `clique_desc_ranreg.json` and the per-clique pose graphs under `res/<work_dir>/`.

## 4.3 Integrate subgraphs using FCGF

Place the pretrained FCGF KITTI checkpoint at:

```text
FCGF/kitti_v0.3.pth
```

The original checkpoint filename is:

```text
KITTI-v0.3-ResUNetBN2C-conv1-5-nout32.pth
```

Then run:

```bash
python src/clique_merge_refine.py \
  --input_dir data/proc_pcd \
  --clique_desc clique_desc_ranreg.json \
  --feat_method FCGF
```

This integrates the refined subgraphs and generates `ranreg_union.json`.

<img src="https://github.com/gitouni/Targetless-LiDAR-camera-calibration/blob/main/doc/recon_final_graph.png" width="600">

To reconstruct the merged LiDAR point cloud:

```bash
python src/reconstruction.py \
  --input_dir data/proc_pcd \
  --pose_graph res/<work_dir>/ranreg_union.json \
  --clique_file res/<work_dir>/clique_ranreg.json
```

# Step 5: Hand-eye calibration

Run hand-eye calibration using the inlier camera and LiDAR poses:

```bash
python src/TL_solve.py \
  --camera_json /path/to/sfm_data.json \
  --pcd_json /path/to/ranreg_union.json \
  --save_sol res/<work_dir>/ranreg_sol.npz
```

Use `--gt_TCL_file` only when a ground-truth extrinsic matrix is available.

# Step 6: Scene registration

After OpenMVS produces `scene_dense.ply`, run the final scene registration:

```bash
python src/Reg7D.py \
  --camera_pcd /path/to/scene_dense.ply \
  --lidar_pcd /path/to/ranreg_union.pcd \
  --TL_init /path/to/TL_ranreg_sol.npz
```

`src/Reg7D.py` now reads `work_dir`, `res_dir`, and `method` from [`config/config.yml`](config/config.yml).

The final transform is written under `res/<work_dir>/`.

| Before SR | After SR |
| --- | --- |
| ![](doc/reg_HE_full.png) | ![](doc/reg_7DOF.png) |

# Running inside Docker

From the `docker/` directory:

```bash
docker compose run --rm targetless-calib bash
```

The host repository is mounted directly at:

```text
/workspace
```

The compose environment sets:

```text
PYTHONPATH=/workspace:/workspace/src
```

so both modules under `src/` and the root-level `FCGF`, `RANSAC`, and `view` packages can be imported while keeping the source tree organized.
