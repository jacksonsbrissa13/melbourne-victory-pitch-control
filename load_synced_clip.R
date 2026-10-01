# Run from the MelbVictory_Dashboard project root.
# These tables share McByte frame numbers; player identity mapping comes later.
clip_dir <- file.path("data", "processed", "mv_clip")
frame_time_mapping <- readr::read_csv(
  file.path(clip_dir, "frame_time_mapping.csv"), show_col_types = FALSE)
mcbyte_tracks_synced <- readr::read_csv(
  file.path(clip_dir, "tracks_time_synced.csv"), show_col_types = FALSE)
skillcorner_clip_players <- readr::read_csv(
  file.path(clip_dir, "skillcorner_clip_players.csv"), show_col_types = FALSE)
skillcorner_clip_ball <- readr::read_csv(
  file.path(clip_dir, "skillcorner_clip_ball.csv"), show_col_types = FALSE)
time_alignment <- jsonlite::fromJSON(file.path(clip_dir, "time_alignment.json"))

projection_path <- file.path(clip_dir, "skillcorner_clip_projected.csv")
if (file.exists(projection_path)) {
  skillcorner_clip_projected <- readr::read_csv(projection_path, show_col_types = FALSE)
  projection_review <- jsonlite::fromJSON(file.path(clip_dir, "projection_review.json"))
  message("Loaded projected image positions. Manual review median error: ",
          projection_review$median_review_error_pixels, " pixels.")
}

control_path <- file.path(clip_dir, "pitch_control.rds")
if (file.exists(control_path)) {
  pitch_control_result <- readRDS(control_path)
  pitch_control_grid <- pitch_control_result$grid
  pitch_control_quality <- pitch_control_result$quality
  pitch_control_parameters <- pitch_control_result$params
  message("Loaded R pitch-control surfaces for ", nrow(pitch_control_quality), " frames.")
}

message("Loaded ", nrow(frame_time_mapping), " clip frames; estimated start ",
        time_alignment$skillcorner_start_label, ".")
message("Alignment status: ", time_alignment$status,
        ". Player identity mapping is not yet assigned.")
