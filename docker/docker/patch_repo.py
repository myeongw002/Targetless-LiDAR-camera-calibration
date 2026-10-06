#!/usr/bin/env python3
from pathlib import Path
import sys

repo = Path(sys.argv[1])

# 1) Replace the author's absolute OpenMVG paths with container paths.
sfm = repo / 'doc' / 'SfM_SequentialPipeline.py'
txt = sfm.read_text(encoding='utf-8')
txt = txt.replace(
    'OPENMVG_SFM_BIN = "/home/bit/CODE/Research/AutoCalib/openMVG/build/Linux-x86_64-RELEASE"',
    'OPENMVG_SFM_BIN = "/opt/openmvg-install/bin"',
)
txt = txt.replace(
    'CAMERA_SENSOR_WIDTH_DIRECTORY = "/home/bit/CODE/Research/AutoCalib/openMVG/src/openMVG/exif/sensor_width_database"',
    'CAMERA_SENSOR_WIDTH_DIRECTORY = "/opt/openMVG/src/openMVG/exif/sensor_width_database"',
)
sfm.write_text(txt, encoding='utf-8')

# 2) Open3D 0.18 does not expose the upstream repo's extra seed= keyword in
# registration_ransac_based_on_feature_matching. Remove only this API argument.
ransac = repo / 'ransac.py'
txt = ransac.read_text(encoding='utf-8')
txt = txt.replace(
    'o3d.pipelines.registration.RANSACConvergenceCriteria(max_iter, 0.999),seed=seed)',
    'o3d.pipelines.registration.RANSACConvergenceCriteria(max_iter, 0.999))',
)
ransac.write_text(txt, encoding='utf-8')

# 3) PyTorch >=2.6 changed torch.load defaults. This is the official FCGF
# checkpoint referenced by the upstream repo, so load it explicitly on CPU and
# keep the legacy checkpoint behavior before moving the model to CUDA.
fcgf = repo / 'FCGF' / 'fcgf_utils.py'
txt = fcgf.read_text(encoding='utf-8')
txt = txt.replace(
    "model.load_state_dict(torch.load(model_path)['state_dict'])",
    "model.load_state_dict(torch.load(model_path, map_location='cpu', weights_only=False)['state_dict'])",
)
fcgf.write_text(txt, encoding='utf-8')

# 4) README says reconstruction.py generates ranreg_union.pcd, but the current
# upstream line is commented. Restore saving and make visualization optional.
recon = repo / 'reconstruction.py'
txt = recon.read_text(encoding='utf-8')
old = '''    o3d.visualization.draw_geometries([scene_pcd],point_show_normal=False)\n    # o3d.io.write_point_cloud(args.result,scene_pcd)'''
new = '''    o3d.io.write_point_cloud(args.result,scene_pcd)\n    print("Saved merged point cloud:", args.result)\n    if os.environ.get("ENABLE_GUI", "0") == "1":\n        o3d.visualization.draw_geometries([scene_pcd],point_show_normal=False)'''
if old in txt:
    txt = txt.replace(old, new)
recon.write_text(txt, encoding='utf-8')

# 5) Reg7D writes tmp files without ensuring tmp/ exists and always opens GUI.
reg = repo / 'Reg7D.py'
txt = reg.read_text(encoding='utf-8')
needle = '''if __name__ == "__main__":\n    args = input_args()'''
replacement = '''if __name__ == "__main__":\n    args = input_args()\n    os.makedirs("tmp", exist_ok=True)\n    os.makedirs(args.save_dir, exist_ok=True)'''
if needle in txt:
    txt = txt.replace(needle, replacement)
txt = txt.replace(
    '    o3d.visualization.draw_geometries_with_key_callbacks([pcd1,pcd2],key_to_callback)',
    '    if os.environ.get("ENABLE_GUI", "0") == "1":\n'
    '        o3d.visualization.draw_geometries_with_key_callbacks([pcd1,pcd2],key_to_callback)',
)
reg.write_text(txt, encoding='utf-8')

print('Applied Targetless calibration compatibility patches.')
