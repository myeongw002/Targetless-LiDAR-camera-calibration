# RTX 5070 Docker — host git clone mount 방식

이 버전은 `Targetless-LiDAR-camera-calibration`을 Docker image 안에 clone하지 않습니다.
호스트에 clone한 원본 repository를 `/workspace`로 bind mount해서 사용합니다.

## 권장 폴더 구조

```text
~/workspace/
├── Targetless-LiDAR-camera-calibration/
└── targetless_calib_rtx5070_mounted/
    ├── Dockerfile
    ├── compose.yaml
    └── docker/
```

## 1. 호스트에서 clone

```bash
cd ~/workspace
git clone https://github.com/gitouni/Targetless-LiDAR-camera-calibration.git
cd Targetless-LiDAR-camera-calibration
git checkout 3b6b1dfde9091545593a451b4b9108ddda916732
```

패치를 원본 branch와 분리하고 싶으면:

```bash
git switch -c rtx5070-docker
```

## 2. Docker build

Docker bundle 폴더로 이동:

```bash
cd ~/workspace/targetless_calib_rtx5070_mounted
cp .env.example .env
MAKE_JOBS=4 docker compose build
```

`.env` 기본값은:

```text
TARGETLESS_REPO_PATH=../Targetless-LiDAR-camera-calibration
MAKE_JOBS=4
```

레포 위치가 다르면 `TARGETLESS_REPO_PATH`만 수정하면 됩니다.

## 3. mount 확인

```bash
docker compose run --rm targetless-calib \
  bash -lc 'pwd; git status; ls'
```

정상이면 `/workspace`에서 호스트 repository가 보입니다.

## 4. compatibility patch 적용

이미지 build 시에는 host source를 건드리지 않습니다.
명시적으로 한 번 실행합니다.

```bash
docker compose run --rm targetless-calib \
  apply-targetless-patch /workspace
```

이 명령은 bind mount된 **호스트 파일을 실제로 수정**합니다. 이후 호스트에서:

```bash
cd ../Targetless-LiDAR-camera-calibration
git diff
```

로 변경 내용을 확인할 수 있습니다.

패치 내용:

- OpenMVG helper의 저자 PC 절대경로 → container 경로
- Open3D 0.18에서 지원하지 않는 RANSAC `seed=` keyword 제거
- PyTorch 2.8의 `torch.load` 기본값 변화 대응
- `reconstruction.py`의 PCD 저장 활성화
- `Reg7D.py`의 `tmp/` 생성 및 GUI 선택화

## 5. repo의 C++ preprocessing tool build

레포가 image build 시점에는 mount되지 않으므로 C++ 도구도 runtime에 빌드합니다.

```bash
docker compose run --rm targetless-calib \
  build-targetless-cpp
```

결과는 호스트 repo의:

```text
cpp/build/pcl_preprocess
cpp/build/viewer
```

에 남습니다.

예:

```bash
docker compose run --rm targetless-calib \
  ./cpp/build/pcl_preprocess data/pcd data/proc_pcd
```

## 6. FCGF checkpoint

```bash
docker compose run --rm targetless-calib \
  get-targetless-assets
```

checkpoint는 host repo의:

```text
FCGF/kitti_v0.3.pth
```

에 저장됩니다.

## 7. RTX 5070 확인

```bash
docker compose run --rm targetless-calib \
  targetless-smoke-test
```

기대 핵심 출력:

```text
torch: 2.8.0+cu128
torch CUDA runtime: 12.8
GPU: NVIDIA GeForce RTX 5070
compute capability: (12, 0)
Minkowski CUDA smoke test: PASS
FCGF RTX GPU smoke test: PASS
```

## 개발 방식

이 구조에서는:

```text
VS Code / Git on host
       ↓
Targetless-LiDAR-camera-calibration/
       ↓ bind mount
/workspace in Docker
       ↓
CUDA / PyTorch / MinkowskiEngine / Open3D 환경
```

이 됩니다.

따라서 Python 코드를 수정할 때마다 Docker image를 다시 build할 필요가 없습니다.
호스트에서 수정하고 container를 다시 실행하면 즉시 반영됩니다.
