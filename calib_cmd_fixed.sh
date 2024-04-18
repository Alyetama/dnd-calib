
export LD_LIBRARY_PATH=/home/biodiv/mambaforge/envs/dnd/lib/python3.11/site-packages/nvidia/cudnn/lib:$LD_LIBRARY_PATH

python main.py \
    --cli \
    --bbox_confidence_threshold 0.50 \
    --bbox_sampling_percentile 20 \
    --calibration_regression_method "ransac" \
    --camera_horizontal_fov 38.2 \
    --camera_vertical_fov 29.1 \
    --detection_sampling_method "sam" \
    --max_depth 24 \
    --min_depth 1 \
    --sample_from "detection" \
    --data_dir "../pilot_mnt_data_reconyx-hf2" \
    --draw_world_position \
    --calibrate_metric \
    --draw_detection_ids \
    --multiple_animal_reduction only_centermost
