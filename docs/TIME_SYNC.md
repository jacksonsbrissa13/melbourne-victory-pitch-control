# MV clip time alignment

## Working mapping

`SkillCorner match seconds ≈ 1133.3 + source video seconds`, period 1.

This is an **event-checked estimate**, with a working review tolerance of ±0.2 seconds. That tolerance is not a statistical confidence interval. Keep the offset adjustable during spatial alignment.

113 McByte frames now map to SkillCorner frames **13843–13955**, timestamps **18:53.3–19:04.5**. Each frame uses the nearest available 10 Hz SkillCorner sample. Nearest-sample rounding and uncertainty in the video alignment are separate quantities.

## Evidence

The original clip shows continuous play. Every broadcast-clock transition from 18:52→18:53 through 19:03→19:04 occurs between source timestamps `n + 0.16` and `n + 0.20` seconds. Assuming whole-second clock ticks, the broadcast-clock start falls between **18:52.80 and 18:52.84**, midpoint **18:52.82**. Reviewed transitions are in `broadcast_clock_anchors.csv` and `broadcast_clock_transitions.jpg`.

The broadcast clock alone is about half a second behind the SkillCorner action timestamps in this sequence:

| Action | Source clip time, approximately | SkillCorner possession end | Implied clip start |
|---|---:|---:|---:|
| Machach pass release | 6.00–6.04 s | 18:59.4 | 18:53.38 |
| Valadon shot release | 8.40–8.44 s | 19:01.7 | 18:53.28 |

Both actions support a start near **18:53.3** at SkillCorner's 0.1-second sampling scale. Possession end labels and smoothed ball coordinates limit finer precision. The exact cause of the clock/action discrepancy has not been established.

## Frame timing

The source is 25 fps; the tracking export is 10 fps. FFmpeg selects source frames at 0.04, 0.12, 0.24, 0.32… seconds, while output playback times are 0.00, 0.10, 0.20, 0.30… seconds. Decoded-frame checksums establish which source frame each tracked image uses. Use `source_time_seconds` for synchronization and `clip_time_seconds` for the rendered video's playback position.

## Files

- `frame_time_mapping.csv`: one row per McByte frame and its SkillCorner sample.
- `tracks_time_synced.csv`: original 1,712 McByte boxes with timing columns added.
- `skillcorner_clip_players.csv`: 2,486 player positions for the mapped frames, with names and shirt numbers from match metadata.
- `skillcorner_clip_ball.csv`: ball positions for the mapped frames.
- `time_alignment.json`: editable alignment settings and evidence.
- `MV_Clip_metadata_synced.json`: updated metadata; original download preserved.

No McByte track has been assigned a player identity. Load tables with `source("load_synced_clip.R")` from the R project root. To adjust the time offset, edit `skillcorner_start_seconds_estimated` in `time_alignment.json`, then run `python3 sync_clip_time.py` and reload the R script.
