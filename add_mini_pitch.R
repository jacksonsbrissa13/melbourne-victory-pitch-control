# Add a synchronized R pitch-control inset at bottom centre of the existing MP4.
# Uses saved surfaces; no model or camera recalculation required.
add_mini_pitch <- function(clip_dir = file.path("data", "processed", "mv_clip"),
                           inset_width = 300L, bottom_gap = 46L) {
  result <- readRDS(file.path(clip_dir, "pitch_control.rds"))
  players <- read.csv(file.path(clip_dir, "skillcorner_clip_players.csv"))
  players$team <- ifelse(players$team_id == 868, "Victory", "Auckland")
  players$observed <- tolower(as.character(players$is_detected)) == "true"
  ball <- read.csv(file.path(clip_dir, "skillcorner_clip_ball.csv"))
  frames <- sort(unique(result$grid$frame))
  inset_height <- as.integer(round(inset_width * 70/107))
  tmp <- tempfile("mv_mini_pitch_")
  dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  circle <- data.frame(x = 9.15*cos(seq(0, 2*pi, length.out = 100)),
                       y = 9.15*sin(seq(0, 2*pi, length.out = 100)))
  for (frame in frames) {
    grid <- result$grid[result$grid$frame == frame, ]
    p <- players[players$frame == frame, ]
    b <- ball[ball$frame == frame, ]
    chart <- ggplot2::ggplot(grid, ggplot2::aes(pitch_x, pitch_y)) +
      ggplot2::geom_raster(ggplot2::aes(fill = victory_control), interpolate = TRUE) +
      ggplot2::scale_fill_gradient2(low = "#FF9E37", mid = "#29444D", high = "#28D7FA",
        midpoint = 0.5, limits = c(0, 1), guide = "none") +
      ggplot2::annotate("rect", xmin = -52.5, xmax = 52.5, ymin = -34, ymax = 34,
                       fill = NA, colour = "#EDF4F7", linewidth = 0.22) +
      ggplot2::annotate("segment", x = 0, xend = 0, y = -34, yend = 34,
                       colour = "#EDF4F7", linewidth = 0.2) +
      ggplot2::geom_path(data = circle, ggplot2::aes(x, y), inherit.aes = FALSE,
                        colour = "#EDF4F7", linewidth = 0.2)
    for (side in c(-1, 1)) {
      chart <- chart +
        ggplot2::annotate("rect", xmin = min(side*36, side*52.5), xmax = max(side*36, side*52.5),
          ymin = -20.16, ymax = 20.16, fill = NA, colour = "#EDF4F7", linewidth = 0.2) +
        ggplot2::annotate("rect", xmin = min(side*47, side*52.5), xmax = max(side*47, side*52.5),
          ymin = -9.16, ymax = 9.16, fill = NA, colour = "#EDF4F7", linewidth = 0.2)
    }
    chart <- chart +
      ggplot2::geom_point(data = p, ggplot2::aes(pitch_x, pitch_y, colour = team, alpha = observed),
        inherit.aes = FALSE, shape = 21, fill = "#101A23", size = 2.9, stroke = 0.35) +
      ggplot2::geom_text(data = p, ggplot2::aes(pitch_x, pitch_y, label = shirt_number,
        colour = team, alpha = observed), inherit.aes = FALSE, size = 1.75, fontface = "bold") +
      ggplot2::geom_point(data = b, ggplot2::aes(x, y), inherit.aes = FALSE,
        colour = "white", shape = 16, size = 1.05) +
      ggplot2::scale_colour_manual(values = c(Victory = "#28D7FA", Auckland = "#FF9E37"), guide = "none") +
      ggplot2::scale_alpha_manual(values = c("TRUE" = 1, "FALSE" = 0.5), guide = "none") +
      ggplot2::coord_fixed(xlim = c(-53.5, 53.5), ylim = c(-35, 35), expand = FALSE) +
      ggplot2::theme_void() +
      ggplot2::theme(plot.background = ggplot2::element_rect(fill = "#101A23", colour = "#7C929F", linewidth = 0.35),
                     plot.margin = ggplot2::margin(1, 1, 1, 1))
    ggplot2::ggsave(file.path(tmp, sprintf("%06d.png", frame)), chart,
      width = inset_width, height = inset_height, units = "px", dpi = 120, bg = "#101A23")
    if (frame == 51L) {
      file.copy(file.path(tmp, sprintf("%06d.png", frame)),
                file.path(clip_dir, "mini_pitch_example.png"), overwrite = TRUE)
    }
    if (frame %% 20 == 0 || frame == max(frames)) message("Mini pitch: ", frame, "/", max(frames))
  }
  ffmpeg <- Sys.which("ffmpeg")
  if (!nzchar(ffmpeg)) stop("ffmpeg not found.")
  output <- file.path(clip_dir, "MV_Clip_pitch_control_minipitch.mp4")
  args <- c("-v", "error", "-y", "-i", file.path(clip_dir, "MV_Clip_pitch_control.mp4"),
    "-framerate", "10", "-start_number", "1", "-i", file.path(tmp, "%06d.png"),
    "-filter_complex", sprintf("[0:v][1:v]overlay=x=(main_w-overlay_w)/2:y=main_h-overlay_h-%d:shortest=1[v]", bottom_gap),
    "-map", "[v]", "-map", "0:a?", "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
    "-c:a", "copy", "-shortest", output)
  status <- system2(ffmpeg, vapply(args, shQuote, character(1)))
  if (status != 0) stop("Inset rendering failed.")
  message("Saved ", output)
  invisible(output)
}

mini_pitch_video <- add_mini_pitch()
