# Initial camera alignment

## Preview

Open `MV_Clip_alignment_preview.mp4` to review all 113 frames at 10 fps.

- Cyan circles: projected Melbourne Victory positions, with shirt numbers.
- Orange circles: projected Auckland positions, with shirt numbers.
- White crosses: bottom-centre of McByte boxes, an approximate foot location.
- Green lines: projected halfway line, centre circle, penalty area and goal area.

Only SkillCorner positions flagged `is_detected` and projected into the preview bounds are drawn. Detection flags do not establish identity correctness, and box bottom-centres can be displaced from the player's ground contact during running, falling or occlusion.

## Calibration

The supplied `image_corners_projection` describes a field-of-view polygon, not a calibrated pixel homography for this highlights file. Mapping its four vertices directly to video corners placed many player markers too high. A separate correction was therefore fitted using 78 approximate manually reviewed ground contacts across frames 1, 26, 51, 76, 101 and 113. The corner-based proxy follows the moving camera, with correction coefficients interpolated between these keyframes.

`spatial_calibration.json` preserves the provisional shirt/player correspondences and image observations. They are calibration seeds, not a final mapping of McByte track IDs to players. Timing remains the event-checked estimate at 18:53.3; changing that estimate requires re-reviewing spatial anchors.

## Checks and limits

40 separate manual ground-contact observations at frames 13, 38, 63 and 88 were excluded from fitting. Their approximate projection error was:

| Metric | Pixels at 1280×720 |
|---|---:|
| Median | 20.9 |
| 90th percentile | 35.6 |
| Maximum | 56.0 |

The same reviewer selected fit and review observations. Provisional identity, source tracking errors, manual placement, timing uncertainty and camera interpolation all contribute to these distances. These checks establish a useful initial visual alignment, not an independently certified calibration or final player identification. Residual drift remains between keyframes, especially with overlap and fast movement.

## Outputs and reuse

- `skillcorner_clip_projected.csv`: 2,486 player positions with pitch and image coordinates.
- `camera_homographies.json`: a pitch-to-image transform for each clip frame.
- `calibration_fit_residuals.csv`: fit errors for the calibration seeds.
- `projection_validation.csv`: review errors for the separate observations.
- `projection_review.json`: review summary.
- `projection_previews/`: selected annotated frames.

Reload `load_synced_clip.R` to create `skillcorner_clip_projected` and `projection_review` in R. These positions can propose associations to McByte tracks, with temporal consistency and manual review required before accepting identity mappings.

Regenerate with `project_clip_positions.py` using a Python environment with NumPy and Pillow, and ffmpeg on PATH. No model inference is required.

Schema reference: [SkillCorner tracking data description](https://github.com/SkillCorner/opendata#-tracking-data-description).
