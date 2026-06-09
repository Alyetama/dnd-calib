# dnd-calib

Camera trap distance calibration workflow. Organizes deployment images by camera type, detects calibration signs via YOLO, generates bounding-box masks, and feeds the result into a depth-estimation pipeline to produce per-deployment distance calibration arrays.

---

## Workflow overview (`workflow_last.ipynb`)

```
Input CSVs + raw images
        │
        ▼
1. Load & filter metadata
        │
        ▼
2. Sort images into animal_images/ and human_images/ by deployment
        │
        ▼
3. Build dataset directory tree  ({dataset_name}/{camera}/{transects}/{deployment}/)
        │
        ▼
4. YOLO sign detection on calibration frames  →  bounding-box masks
        │
        ▼
5. Run main.py (CLI) for depth estimation & calibration regression
        │
        ▼
6. Aggregate results  →  depth_mmm.csv
```

---

## Prerequisites

### Required input files

| File | Description |
|---|---|
| `images_<id>.csv` | Full image metadata export (one row per image) |
| `deployments.csv` | Deployment-level metadata including `camera_name` |
| `images_with_exif_camera_details.csv` | Per-deployment EXIF make/model override |
| `cameras_specs.json` | FOV and sensor specs keyed by camera name |
| `signs_best.pt` | YOLO weights for calibration-sign detection |
| `animal_images/` | Animal images, flat or pre-sorted by deployment |
| `human_images/` | Calibration images sorted into per-deployment folders |

---

## Parameters

Edit the **PARAMETERS** cell at the top of the notebook before running:

```python
images_csv        = 'images_2007780.csv'
deployments_csv   = 'deployments.csv'
images_exif_csv   = 'images_with_exif_camera_details.csv'
dataset_name      = 'snapshotusa24_project'   # output root folder
device            = 'cuda'                    # or 'cpu'
cls_model_weights = 'signs_best.pt'
```

---

## Output structure

```
{dataset_name}/
└── {camera_name}/
    ├── transects/
    │   └── {deployment_id}/
    │       ├── calibration_frames/        # copied from human_images/
    │       ├── calibration_frames_masks/  # binary mask PNGs from YOLO
    │       └── detection_frames/          # copied from animal_images/
    └── results/
        ├── sampling/
        │   └── {deployment_id}/           # sampled detection frames
        ├── calibration_arrays/            # .npy arrays per deployment
        ├── results.csv                    # raw calibration output
        └── results-{camera_name}-full.csv # merged with image metadata
```

Top-level summary: `{dataset_name}/depth_mmm.csv` — mean, median, min, max depth per deployment.

---

## Running the depth-estimation CLI

After the notebook finishes building the directory tree and masks, run `main.py` once per camera model. Example commands (also embedded in the notebook):

**Browning Recon Force Elite**
```bash
python main.py \
    --cli \
    --bbox_confidence_threshold 0.60 \
    --bbox_sampling_percentile 20 \
    --calibration_regression_method ransac \
    --camera_horizontal_fov 41.0 \
    --camera_vertical_fov 41.0 \
    --detection_sampling_method bbox_percentile \
    --sample_from detection \
    --data_dir "../{dataset_name}/Browning Recon Force Elite" \
    --draw_world_position \
    --draw_detection_ids \
    --crop_bottom 100 \
    --depth_estimation_model dpt_pytorch
```

**Reconyx Hyperfire 1**
```bash
python main.py \
    --cli \
    --bbox_confidence_threshold 0.60 \
    --bbox_sampling_percentile 20 \
    --calibration_regression_method ransac \
    --camera_horizontal_fov 42.2 \
    --camera_vertical_fov 32.3 \
    --detection_sampling_method bbox_percentile \
    --sample_from detection \
    --data_dir "../{dataset_name}/Reconyx Hyperfire 1" \
    --draw_world_position \
    --draw_detection_ids \
    --crop_bottom 65 \
    --crop_top 35 \
    --depth_estimation_model dpt_pytorch
```

> **Note:** If using CUDA, set the library path first:
> ```bash
> export LD_LIBRARY_PATH=/home/biodiv/mambaforge/envs/dnd/lib/python3.11/site-packages/nvidia/cudnn/lib:$LD_LIBRARY_PATH
> ```

---

## Camera crop settings

Each supported camera model has a data-strip (timestamp banner) that must be cropped before depth estimation. These values are saved automatically to `camera_crop_mapping.json`:

| Camera | crop_top | crop_bottom |
|---|---|---|
| Browning Recon Force Elite | 0 | 100 |
| Reconyx Hyperfire 1 | 35 | 65 |
| Bushnell | 0 | 106 |

---

## Key design notes

- **Deployment ID normalisation** — slashes, spaces, commas, dots, and colons in deployment IDs are replaced with hyphens to produce safe directory names.
- **EXIF override** — camera make/model from EXIF (`images_with_exif_camera_details.csv`) takes precedence over the `camera_name` field in `deployments.csv`.
- **Sign detection failure handling** — frames where YOLO finds no sign are collected in `failed_signs` and skipped; the mask count assertion (`l1 == l2`) at the end of the mask step will catch any mismatch before the CLI is run.
- **Idempotency** — image-copy steps check destination counts before copying, so re-running the notebook on a partially completed dataset is safe.
