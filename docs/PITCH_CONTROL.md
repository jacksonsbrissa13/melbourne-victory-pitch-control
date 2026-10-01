# Pitch-control heatmap

## Research references

| Repository | Useful ideas |
|---|---|
| [Friends of Tracking / LaurieOnTracking](https://github.com/Friends-of-Tracking-Data-FoTD/LaurieOnTracking) | Educational implementation of arrival-time pitch control; reaction time, velocity, ball travel and competing team control. |
| [CodaBonito](https://github.com/thecomeonman/CodaBonito) | R functions and examples for the Friends of Tracking model and pitch plots. |
| [mkh1991 / pitch-control](https://github.com/mkh1991/pitch-control) | Python library with modular model inputs and accelerated pitch-control calculation. |
| [Vsll92 / football-pitch-control](https://github.com/Vsll92/football-pitch-control) | Visual inspiration: team colour surfaces, contested boundaries and opacity controls. |

Our model and renderer are independently written in R using these methodological ideas. No package from those repositories is required. This is a Spearman-style educational adaptation, not an exact reproduction or fitted provider model.

## What the colour means

At each instant, estimate which team would control a hypothetical ball moved to each pitch location. Cyan favours Victory; orange favours Auckland; evenly contested regions are more transparent. This measures estimated spatial control, not accumulated player occupancy, pass completion probability or goal probability.

Numbers use the existing projected SkillCorner shirt identities and team colours. No green calibration lines or McByte foot crosses are drawn. Labels retain the preliminary spatial-alignment status.

## Model

- All 22 SkillCorner positions are included, including off-camera extrapolations. Filtering to visible players alone would omit influences on the control surface.
- Velocity uses a centred 0.4-second difference followed by five-sample smoothing, with context on both sides of the clip. Speeds over 12 m/s are treated as invalid and set to zero.
- Predicted reaction position is current position plus velocity × 0.7 seconds. Travel after reacting uses a common 5 m/s speed.
- Arrival uncertainty uses a logistic distribution with 0.45-second scale expressed as standard deviation. Ball travel uses a constant 15 m/s speed.
- Competing arrival hazards are integrated using mass-preserving exponential steps of 0.08 seconds, up to 10 seconds beyond ball arrival. Both teams use the same control rate, 4.3 per second.
- No goalkeeper catch bonus or offside removal is applied. This is a spatial-control view, not a legal receiving-options model.
- Surfaces use a 64×42 pitch grid. Video uses inverse homography mapping and bilinear interpolation, avoiding cells painted across the horizon or outside pitch bounds.
- Grass-like image pixels receive the translucent overlay; uniforms and non-pitch areas are mostly preserved by pixel masking. Some coloured clothing and image edges can still receive shading.

## Quality and sensitivity

Every frame includes 22 players. Numerical probability mass is conserved to floating-point precision; unresolved mass is under 0.5% on this clip. These are numerical checks, not evidence that the model's probabilities are calibrated against outcomes.

The model is also calculated using detected players alone. The absolute difference is recorded as `extrapolation_sensitivity`; large differences reduce overlay opacity. This is a sensitivity diagnostic, not a confidence interval. The average full-pitch difference is about 0.21, so off-camera assumptions materially affect parts of the surface.

Camera alignment remains approximate: prior manual review had a median 21-pixel error and a maximum 56-pixel error. Timing and alignment are unchanged by the heatmap. Shading may drift relative to footage, and stronger interpretations need better calibration and model validation.

## Run and load

From the R project root:

```r
source("pitch_control_model.R")   # Recompute surfaces.
source("render_pitch_control.R")  # Render overlay using magick, png and ffmpeg.
source("plot_pitch_control.R")    # Export a top-down snapshot.
```

For existing results only, `source("load_synced_clip.R")` loads `pitch_control_grid`, `pitch_control_quality` and model parameters.

Main outputs: `MV_Clip_pitch_control.mp4`, `pitch_control_topdown.png`, `pitch_control.rds`, `pitch_control_grid.csv`, `pitch_control_quality.csv` and `pitch_control_surfaces.json`. All computations and rendering run locally without GPU inference. Rendering opacity is adjustable through `render_pitch_control(opacity = 0.35)` after sourcing its script.

## Synchronized mini pitch

`MV_Clip_pitch_control_minipitch.mp4` adds an animated R chart at bottom centre of the existing heatmap video. Its 300×196-pixel inset uses the same frame's surface, player positions, team-coloured shirt numbers and ball position; faint markers indicate extrapolated players. It sits 46 pixels above the image bottom, leaving the existing colour legend visible. Main video shading and numbers are retained.

Regenerate with `source("add_mini_pitch.R")`. Width and bottom gap can be adjusted with `add_mini_pitch(inset_width = 360, bottom_gap = 46)`. The inset covers a small part of the lower footage; it does not expand or crop the 1280×720 video.
