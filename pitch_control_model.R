# Independent R implementation of a Spearman-style competitive arrival model.
# Inspiration: Friends-of-Tracking-Data-FoTD/LaurieOnTracking and CodaBonito.
# This is an educational estimate, not a fitted provider model or pass-success model.

pitch_control_parameters <- list(
  max_speed = 5, reaction_time = 0.7, arrival_sd = 0.45,
  control_rate = 4.3, ball_speed = 15, integration_dt = 0.08,
  integration_horizon = 10, unresolved_tolerance = 0.005,
  grid_nx = 64L, grid_ny = 42L, velocity_ceiling = 12
)

control_surface <- function(players, ball, grid, params, detected_only = FALSE) {
  if (detected_only) players <- players[players$is_detected, ]
  if (!any(players$team_id == 868) || !any(players$team_id == 4177)) {
    stop("Both teams must be present.")
  }
  rx <- players$x + params$reaction_time * players$vx
  ry <- players$y + params$reaction_time * players$vy
  arrival <- params$reaction_time + sqrt(
    outer(rx, grid$x, "-")^2 + outer(ry, grid$y, "-")^2
  ) / params$max_speed
  ball_arrival <- sqrt((grid$x-ball$x)^2 + (grid$y-ball$y)^2) / params$ball_speed
  # Every grid cell has its own ball arrival time. Integrate from that time.
  relative_arrival <- sweep(arrival, 2, ball_arrival, "-")
  home <- players$team_id == 868
  p_home <- p_away <- numeric(nrow(grid))
  remaining <- rep(1, nrow(grid))
  logistic_scale <- pi / (sqrt(3) * params$arrival_sd)
  steps <- ceiling(params$integration_horizon / params$integration_dt)
  for (step in seq_len(steps)) {
    elapsed <- (step - 0.5) * params$integration_dt
    ready <- matrix(plogis(logistic_scale * (elapsed-relative_arrival)),
                    nrow = nrow(players))
    h_home <- params$control_rate * colSums(ready[home, , drop = FALSE])
    h_away <- params$control_rate * colSums(ready[!home, , drop = FALSE])
    hazard <- h_home + h_away
    # Exponential competing-hazard step preserves probability mass and bounds.
    gained <- remaining * (-expm1(-hazard * params$integration_dt))
    share <- ifelse(hazard > 0, h_home / hazard, 0.5)
    p_home <- p_home + gained * share
    p_away <- p_away + gained * (1-share)
    remaining <- remaining - gained
    if (max(remaining) < params$unresolved_tolerance) break
  }
  list(home = p_home / (p_home+p_away), unresolved = remaining,
       mass_error = max(abs(p_home+p_away+remaining-1)))
}

build_pitch_control <- function(clip_dir = file.path("data", "processed", "mv_clip"),
                                params = pitch_control_parameters) {
  timeline <- read.csv(file.path(clip_dir, "frame_time_mapping.csv"))
  metadata <- jsonlite::fromJSON("data/raw/2017461/2017461_match.json")
  roster <- metadata$players
  raw <- readLines("data/raw/2017461/2017461_tracking_extrapolated.jsonl", warn = FALSE)
  wanted <- seq(min(timeline$skillcorner_frame)-10L, max(timeline$skillcorner_frame)+10L)
  records <- lapply(raw[wanted+1L], jsonlite::fromJSON, simplifyVector = FALSE)
  if (!all(vapply(records, function(r) r$frame, numeric(1)) == wanted)) {
    stop("JSONL row order changed; frame lookup must be updated.")
  }
  samples <- do.call(rbind, lapply(records, function(r) {
    do.call(rbind, lapply(r$player_data, function(p) {
      data.frame(skillcorner_frame = r$frame, player_id = p$player_id,
                 x = p$x, y = p$y, is_detected = p$is_detected)
    }))
  }))
  samples$team_id <- roster$team_id[match(samples$player_id, roster$id)]
  samples$vx <- samples$vy <- 0
  for (id in unique(samples$player_id)) {
    ix <- which(samples$player_id == id)
    ix <- ix[order(samples$skillcorner_frame[ix])]
    n <- length(ix)
    left <- pmax(1L, seq_len(n)-2L)
    right <- pmin(n, seq_len(n)+2L)
    dt <- (samples$skillcorner_frame[ix[right]]-samples$skillcorner_frame[ix[left]])/10
    vx <- (samples$x[ix[right]]-samples$x[ix[left]])/dt
    vy <- (samples$y[ix[right]]-samples$y[ix[left]])/dt
    vx <- as.numeric(stats::filter(vx, rep(1/5, 5), sides = 2))
    vy <- as.numeric(stats::filter(vy, rep(1/5, 5), sides = 2))
    vx[!is.finite(vx)] <- 0; vy[!is.finite(vy)] <- 0
    invalid <- sqrt(vx^2+vy^2) > params$velocity_ceiling
    vx[invalid] <- 0; vy[invalid] <- 0
    samples$vx[ix] <- vx; samples$vy[ix] <- vy
  }
  xgrid <- seq(-metadata$pitch_length/2, metadata$pitch_length/2,
               length.out = params$grid_nx)
  ygrid <- seq(-metadata$pitch_width/2, metadata$pitch_width/2,
               length.out = params$grid_ny)
  grid <- expand.grid(x = xgrid, y = ygrid)
  surfaces <- vector("list", nrow(timeline))
  long <- vector("list", nrow(timeline))
  quality <- vector("list", nrow(timeline))
  for (i in seq_len(nrow(timeline))) {
    t <- timeline[i, ]
    players <- samples[samples$skillcorner_frame == t$skillcorner_frame, ]
    rec <- records[[match(t$skillcorner_frame, wanted)]]
    ball <- rec$ball_data
    if (anyNA(c(ball$x, ball$y))) stop("Ball position missing.")
    full <- control_surface(players, ball, grid, params)
    visible <- control_surface(players, ball, grid, params, detected_only = TRUE)
    sensitivity <- abs(full$home-visible$home)
    if (any(!is.finite(full$home)) || any(full$home < 0 | full$home > 1)) {
      stop("Invalid probability surface.")
    }
    surfaces[[i]] <- list(frame = t$frame, victory_control = unname(full$home),
                          extrapolation_sensitivity = unname(sensitivity))
    long[[i]] <- data.frame(frame = t$frame, pitch_x = grid$x, pitch_y = grid$y,
                           victory_control = full$home, auckland_control = 1-full$home,
                           unresolved_probability = full$unresolved,
                           extrapolation_sensitivity = sensitivity)
    quality[[i]] <- data.frame(frame = t$frame, n_players = nrow(players),
      n_detected = sum(players$is_detected), n_extrapolated = sum(!players$is_detected),
      ball_detected = ball$is_detected, max_unresolved = max(full$unresolved),
      mass_error = full$mass_error, average_victory_control = mean(full$home),
      mean_extrapolation_sensitivity = mean(sensitivity))
    if (i %% 20 == 0 || i == nrow(timeline)) message("Pitch control: ", i, "/", nrow(timeline))
  }
  pitch_control_grid <- do.call(rbind, long)
  pitch_control_quality <- do.call(rbind, quality)
  write.csv(pitch_control_grid, file.path(clip_dir, "pitch_control_grid.csv"), row.names = FALSE)
  write.csv(pitch_control_quality, file.path(clip_dir, "pitch_control_quality.csv"), row.names = FALSE)
  saveRDS(list(grid = pitch_control_grid, quality = pitch_control_quality, params = params),
          file.path(clip_dir, "pitch_control.rds"))
  jsonlite::write_json(list(model = "Spearman-style competitive arrival estimate",
    parameters = params, xgrid = xgrid, ygrid = ygrid, frames = surfaces,
    notes = c("All 22 SkillCorner players used, including extrapolated positions.",
      "Velocities: centred 0.4-second difference, then 5-sample smoothing with padded context.",
      "Equal control rates; no goalkeeper bonus or offside removal.",
      "Colours show conditional team control after integration, not pass success or accumulated occupancy.",
      "Sensitivity compares all-player and detected-only estimates; not calibrated uncertainty.")),
    file.path(clip_dir, "pitch_control_surfaces.json"), auto_unbox = TRUE, digits = 8, pretty = FALSE)
  invisible(list(grid = pitch_control_grid, quality = pitch_control_quality, params = params))
}

pitch_control_result <- build_pitch_control()
