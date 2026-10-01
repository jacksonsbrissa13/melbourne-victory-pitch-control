# Melbourne Victory · Pitch Control

I built this football analysis prototype to synchronise open tracking data with broadcast footage, estimate spatial control in R, and display it directly on the pitch with a synchronised mini-pitch inset.

For this case study, I analysed Melbourne Victory vs Auckland FC on 17 May 2025, in the A-League semi-final first leg. I used SkillCorner match `2017461` and an 11.3-second sequence covering play leading into a Valadon shot.

## Video sample

![Annotated video sample showing team-coloured pitch control, shirt numbers and a synchronised mini pitch](docs/assets/annotated-video-sample.png)

*Sample frame from my annotated clip. Broadcast footage: A-Leagues highlights, with Paramount+ branding retained. Tracking data: SkillCorner. I added the estimated pitch-control surface, shirt labels and synchronised mini pitch. This is a visual example; timing and camera alignment remain approximate.*

## Pitch-only view

![R pitch-control snapshot](docs/assets/pitch-control-topdown.png)

## What I wanted to show

- How estimated team control changes as players move and the ball progresses.
- Team-coloured shirt numbers on the footage and a full-pitch view of the same moment.
- The influence of off-camera players, with a sensitivity diagnostic for extrapolated positions.

I use cyan for Melbourne Victory and orange for Auckland. At each location, my model estimates which team would be more likely to control a hypothetical ball sent there, using player position, velocity, reaction time and ball travel time. I interpret this as an instantaneous spatial-control surface, rather than an occupancy heatmap, pass-success model or goal probability.

I share the MP4 separately. In this repository, I have included code, reviewed calibration inputs, a pitch-only example figure and one annotated broadcast still. I have excluded video files, model weights and large generated datasets. My project currently runs as an offline analysis pipeline.

## My workflow

```mermaid
flowchart LR
    V[Local video clip] --> M[McByte++ in Colab]
    M --> T[Tracks and frame metadata]
    S[SkillCorner open data] --> A[Time alignment]
    T --> A
    A --> H[Reviewed camera homographies]
    A --> P[R pitch-control model]
    H --> R[Video renderer]
    P --> R
    R --> O[Annotated MP4 with mini pitch]
```

I use McByte++ to obtain video tracks and frame timing for review. For the final control model and shirt labels, I use SkillCorner positions and player identities from the match metadata. I have not assigned a final mapping from McByte track IDs to player identities.

## Start with the match data

I start by loading the match data into R. To follow the same steps, you need R and an internet connection. Open `MelbourneVictoryPitchControl.Rproj`, then run:

```r
source("setup.R")
source("get_match_data.R")
```

My download script retrieves match metadata, extrapolated tracking, dynamic events and phases of play, including the actual Git LFS tracking payload. It loads `match`, `tracking`, `dynamic_events` and `phases_of_play` into R. The tracking download is about 86 MB.

## Reproduce the clip analysis

I calibrated this analysis against a specific local clip: **`MV_Clip.mp4`**, at 1280×720, 25 fps and about 11.335 seconds. To reproduce my clip analysis, you need the same video, which I do not distribute here. My existing anchors are specific to this sequence; a different clip requires new timing and camera review.

1. Install FFmpeg (`ffmpeg` and `ffprobe` on PATH), R dependencies above, and Python dependencies:

   ```sh
   python3 -m pip install -r requirements.txt
   ```

2. Open [McBytePlusPlus_Colab.ipynb](McBytePlusPlus_Colab.ipynb) in Google Colab. Select a GPU runtime and run cells in order. Upload the clip when prompted. The notebook extracts numbered frames, installs dependencies in a separate Python environment, downloads pretrained weights, runs tracking and exports results. It includes fixes for headless OpenCV, Colab's Matplotlib backend and GPUs without BF16 support.

3. Put `MV_Clip.mp4` in the project root. Copy the Colab exports `MV_Clip_tracks.csv` and `MV_Clip_metadata.json` into `data/processed/mv_clip/`. The included metadata records the original run; replace it with your matching export. Keep the reviewed JSON calibration files in that directory.

4. Run from the project root:

   ```sh
   python3 sync_clip_time.py
   python3 project_clip_positions.py
   Rscript pitch_control_model.R
   Rscript render_pitch_control.R
   Rscript plot_pitch_control.R
   Rscript add_mini_pitch.R
   ```

5. Open `data/processed/mv_clip/MV_Clip_pitch_control_minipitch.mp4`. To explore tables in R, run `source("load_synced_clip.R")`.

Each R script above executes its default operation when sourced. I run rendering and model calculation locally without a GPU, and McByte++ inference on the Colab GPU. My saved McByte++ run used revision `be1bbc03f18e33e93e0a359bbcbfdfc4dc4ab6b9`; the notebook currently clones the upstream default branch and records its revision, so future results may differ.

## Methods and interpretation

| Component | Working settings / evidence |
|---|---|
| Timing | Period 1; SkillCorner seconds ≈ `1133.3 + source_video_seconds`. Event-checked estimate, with ±0.2 s working review tolerance. |
| Sampling | 113 clip frames at 10 fps; SkillCorner frames 13843–13955. |
| Camera | Corner-projection proxy plus corrections fitted to 78 approximate manual ground contacts across six keyframes. |
| Spatial review | 40 separate manual observations: median error 20.9 px, 90th percentile 35.6 px, maximum 56.0 px at 1280×720. |
| Control model | 64×42 grid; reaction time 0.7 s; maximum travel speed 5 m/s; ball speed 15 m/s; arrival SD 0.45 s; control rate 4.3/s. |
| Video | Translucent grass-masked surface, team-coloured shirt labels, and a synchronised 300×196 px mini pitch. |

I developed the R model as an educational adaptation of arrival-time pitch control, informed by the repositories credited below. I have not fitted or probability-calibrated it against match outcomes. My numerical mass conservation and convergence checks establish calculation consistency; they do not establish predictive accuracy.

I include all 22 player positions, including extrapolations. I also calculate a detected-only comparison to measure sensitivity to off-camera inputs; its average full-pitch absolute difference is approximately 0.21 for this clip. I use this as a sensitivity diagnostic, not a confidence interval. I do not apply a goalkeeper bonus or offside filtering.

My timing and camera alignment remain approximate. I used manual fit and review anchors selected by the same reviewer, with provisional player correspondences. Video shading can drift, and the grass mask can affect coloured clothing. I retain these limitations when interpreting the visualisation.

I have documented further details here: [time synchronisation](docs/TIME_SYNC.md), [camera alignment](docs/SPATIAL_ALIGNMENT.md), [pitch-control model and rendering](docs/PITCH_CONTROL.md).

## Project files

| File | Purpose |
|---|---|
| `get_match_data.R` | Download and load SkillCorner match data. |
| `McBytePlusPlus_Colab.ipynb` | GPU tracking, frame extraction and export. |
| `sync_clip_time.py` | Match video frame timing to SkillCorner samples. |
| `project_clip_positions.py` | Fit camera corrections, project players and render a review overlay. |
| `pitch_control_model.R` | Estimate arrival-time control and extrapolation sensitivity. |
| `render_pitch_control.R` | Project the control surface onto footage. |
| `plot_pitch_control.R` | Produce a standalone pitch chart. |
| `add_mini_pitch.R` | Add the synchronised pitch chart to the MP4. |
| `load_synced_clip.R` | Load saved analysis tables into R. |
| `data/processed/mv_clip/*.json` | Curated timing, calibration, review anchors and original metadata. |

I save generated outputs under `data/processed/mv_clip/`. Modify model settings in `pitch_control_parameters()`; adjust rendering opacity with `render_pitch_control(opacity = 0.35)` after sourcing its script. Re-review spatial anchors whenever the time offset or clip changes.

## Credits and source repositories

I built this project using open data, tracking software and publicly shared football analytics methods. I credit the following authors and contributors for the data, software and ideas that informed my work:

- **[SkillCorner / opendata](https://github.com/SkillCorner/opendata)** — match metadata, player and ball tracking, dynamic events, phases of play and field-of-view projections. Primary data source.
- **[tstanczyk95 / McBytePlusPlus](https://github.com/tstanczyk95/McBytePlusPlus)** — McByte++ tracking software and pretrained-model setup used by the Colab notebook. Upstream code and weights remain external dependencies.
- **[Friends of Tracking / LaurieOnTracking](https://github.com/Friends-of-Tracking-Data-FoTD/LaurieOnTracking)** — educational arrival-time pitch-control implementation informing reaction, velocity, ball travel and competing team control.
- **[thecomeonman / CodaBonito](https://github.com/thecomeonman/CodaBonito)** — R pitch-control examples and football plotting methods informing the R approach.
- **[mkh1991 / pitch-control](https://github.com/mkh1991/pitch-control)** — modular pitch-control implementation informing model structure and calculation design.
- **[Vsll92 / football-pitch-control](https://github.com/Vsll92/football-pitch-control)** — visual inspiration for team-colour control surfaces and contested regions.
- **A-Leagues** — source highlights, titled *Melbourne Victory v Auckland FC – Shark Highlights | Isuzu UTE A-League 2024-25 | Semi-Final Leg One*, published 17 May 2025. One annotated broadcast still appears above; video footage is not included in this repository.

I wrote the local R control model and renderer for this project, using the research repositories above as references rather than installed dependencies. Each upstream project, dataset, pretrained model and video retains its own terms and attribution requirements. By publishing my code, I do not grant rights to redistribute those materials.

## Development

I developed this as an independent prototype; it is not an official Melbourne Victory or SkillCorner product. Next, I would like to improve camera calibration, review track-to-player identity matching, analyse additional sequences and explore an analyst-facing Shiny interface.

I welcome suggestions and contributions. For proposed changes, please describe the football question, affected pipeline stage and assumptions. Include reproducible inputs where redistribution is permitted; avoid committing video, weights, credentials or generated bulk data.
