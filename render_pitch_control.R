# Project the R model onto source footage using reviewed camera homographies.
# Requires jsonlite, magick and png. Run pitch_control_model.R first.

render_pitch_control <- function(clip_dir = file.path("data", "processed", "mv_clip"),
                                 opacity = 0.5, render_scale = 0.5) {
  surfaces <- jsonlite::fromJSON(file.path(clip_dir, "pitch_control_surfaces.json"),
                               simplifyVector = FALSE)
  camera <- jsonlite::fromJSON(file.path(clip_dir, "camera_homographies.json"),
                             simplifyVector = FALSE)
  projected <- read.csv(file.path(clip_dir, "skillcorner_clip_projected.csv"))
  projected$drawn_in_preview <- tolower(as.character(projected$drawn_in_preview)) == "true"
  ffmpeg <- Sys.which("ffmpeg")
  if (!nzchar(ffmpeg)) stop("ffmpeg not found.")
  run_ffmpeg <- function(args) {
    code <- system2(ffmpeg, vapply(args, shQuote, character(1)))
    if (code != 0) stop("ffmpeg failed with exit code ", code)
  }
  tmp <- tempfile("mv_control_")
  dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  source_dir <- file.path(tmp, "source"); dir.create(source_dir)
  render_dir <- file.path(tmp, "rendered"); dir.create(render_dir)
  run_ffmpeg(c("-v", "error", "-y", "-i", "MV_Clip.mp4", "-vf", "fps=10",
               "-q:v", "2", "-start_number", "1", file.path(source_dir, "%06d.jpg")))
  width <- 1280L; height <- 720L
  rw <- as.integer(width*render_scale); rh <- as.integer(height*render_scale)
  image_grid <- expand.grid(u = (seq_len(rw)-0.5)/render_scale,
                            v = (seq_len(rh)-0.5)/render_scale)
  pixels <- cbind(image_grid$u, image_grid$v, 1)
  xgrid <- unlist(surfaces$xgrid); ygrid <- unlist(surfaces$ygrid)
  nx <- length(xgrid); ny <- length(ygrid)
  bilinear <- function(values, x, y) {
    fx <- pmax(0, pmin(nx-1-1e-8, (x-min(xgrid))/diff(xgrid)[1]))
    fy <- pmax(0, pmin(ny-1-1e-8, (y-min(ygrid))/diff(ygrid)[1]))
    ix <- floor(fx); iy <- floor(fy)
    ax <- fx-ix; ay <- fy-iy
    k <- ix + nx*iy + 1L
    values[k]*(1-ax)*(1-ay) + values[k+1L]*ax*(1-ay) +
      values[k+nx]*(1-ax)*ay + values[k+nx+1L]*ax*ay
  }
  preview_dir <- file.path(clip_dir, "pitch_control_previews")
  dir.create(preview_dir, showWarnings = FALSE)
  home_colour <- c(40, 215, 250)/255
  away_colour <- c(255, 158, 55)/255
  nframes <- length(surfaces$frames)
  if (length(list.files(source_dir, pattern = "jpg$")) != nframes) stop("Frame mismatch.")
  for (i in seq_len(nframes)) {
    surface <- surfaces$frames[[i]]
    frame <- surface$frame
    transform <- camera[[i]]
    if (transform$frame != frame) stop("Camera and model frame mismatch.")
    h <- matrix(unlist(transform$pitch_to_image_homography), nrow = 3, byrow = TRUE)
    pitch <- pixels %*% t(solve(h))
    x <- pitch[, 1]/pitch[, 3]; y <- pitch[, 2]/pitch[, 3]
    valid <- is.finite(x) & is.finite(y) & pitch[, 3] > 0 &
      x >= min(xgrid) & x <= max(xgrid) & y >= min(ygrid) & y <= max(ygrid) &
      image_grid$v > 90 & image_grid$v < height-38
    x[!valid] <- 0; y[!valid] <- 0
    probability <- bilinear(unlist(surface$victory_control), x, y)
    sensitivity <- bilinear(unlist(surface$extrapolation_sensitivity), x, y)
    alpha <- opacity * abs(2*probability-1)^0.7 *
      (1-0.7*pmin(sensitivity/0.35, 1)) * valid
    original <- magick::image_read(file.path(source_dir, sprintf("%06d.jpg", frame)))
    small <- magick::image_resize(original, sprintf("%dx%d!", rw, rh))
    rgb <- magick::image_data(small, channels = "rgb")
    red <- as.integer(rgb[1, , ]); green <- as.integer(rgb[2, , ]); blue <- as.integer(rgb[3, , ])
    # Keep shading on grass-like source pixels, not boards, stands or uniforms.
    grass <- green > red*1.02 & green > blue*1.02
    alpha <- matrix(alpha*grass, nrow = rw, ncol = rh)
    # Pixel colour masking preserves most uniforms without rectangular box holes.
    heat <- array(0, dim = c(rh, rw, 4))
    for (channel in 1:3) {
      colour <- ifelse(probability >= 0.5,
        1 + (home_colour[channel]-1)*(2*probability-1),
        1 + (away_colour[channel]-1)*(1-2*probability))
      heat[, , channel] <- t(matrix(colour, nrow = rw))
    }
    heat[, , 4] <- t(alpha)
    overlay_path <- file.path(tmp, "heat.png")
    png::writePNG(heat, overlay_path)
    overlay <- magick::image_resize(magick::image_read(overlay_path), "1280x720!")
    composite <- magick::image_composite(original, overlay, operator = "over")
    drawn <- magick::image_draw(composite, pointsize = 17)
    markers <- projected[projected$frame == frame & projected$drawn_in_preview, ]
    for (j in seq_len(nrow(markers))) {
      p <- markers[j, ]; colour <- if (p$team_id == 868) "#28D7FA" else "#FF9E37"
      graphics::points(p$image_x, p$image_y, pch = 1, cex = 0.7, col = colour, lwd = 2)
      # Black text shadow keeps numbers readable over both teams' territories.
      for (dx in c(-1, 1)) for (dy in c(-1, 1)) {
        graphics::text(p$image_x+10+dx, p$image_y-13+dy, p$shirt_number,
                       col = "black", font = 2, cex = 0.9, adj = c(0, 0.5))
      }
      graphics::text(p$image_x+10, p$image_y-13, p$shirt_number,
                     col = colour, font = 2, cex = 0.9, adj = c(0, 0.5))
    }
    graphics::rect(0, height-38, width, height, col = "#111923", border = NA)
    graphics::text(14, height-19, "ESTIMATED PITCH CONTROL", col = "white", adj = c(0, 0.5), cex = 0.85)
    graphics::text(350, height-19, "Victory", col = "#28D7FA", adj = c(1, 0.5), cex = 0.8)
    for (k in 0:99) {
      p <- 1-k/99
      colour <- if (p >= 0.5) 1+(home_colour-1)*(2*p-1) else 1+(away_colour-1)*(1-2*p)
      graphics::rect(365+2*k, height-26, 368+2*k, height-12,
                     col = grDevices::rgb(colour[1], colour[2], colour[3]), border = NA)
    }
    graphics::text(585, height-19, "Auckland", col = "#FF9E37", adj = c(0, 0.5), cex = 0.8)
    graphics::text(1265, height-19, "Tracking: SkillCorner", col = "#AAB5C3", adj = c(1, 0.5), cex = 0.75)
    grDevices::dev.off()
    magick::image_write(drawn, file.path(render_dir, sprintf("%06d.jpg", frame)), quality = 94)
    if (frame %in% c(1, 26, 51, 76, 88, 101, 113)) {
      magick::image_write(drawn, file.path(preview_dir, sprintf("frame_%03d.png", frame)))
    }
    if (i %% 20 == 0 || i == nframes) message("Render: ", i, "/", nframes)
  }
  video_path <- file.path(clip_dir, "MV_Clip_pitch_control.mp4")
  run_ffmpeg(c("-v", "error", "-y", "-framerate", "10", "-start_number", "1",
    "-i", file.path(render_dir, "%06d.jpg"), "-i", "MV_Clip.mp4",
    "-map", "0:v:0", "-map", "1:a?", "-c:v", "libx264", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-shortest", video_path))
  message("Saved ", video_path)
  invisible(video_path)
}

pitch_control_video <- render_pitch_control()
