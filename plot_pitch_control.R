# Standalone top-down view of the same R surface used in the video overlay.
source("load_synced_clip.R")
frame_to_plot <- 51L
surface <- pitch_control_grid[pitch_control_grid$frame == frame_to_plot, ]
players <- skillcorner_clip_players[skillcorner_clip_players$frame == frame_to_plot, ]
players$team <- ifelse(players$team_id == 868, "Victory", "Auckland")
players$observed <- tolower(as.character(players$is_detected)) == "true"
ball <- skillcorner_clip_ball[skillcorner_clip_ball$frame == frame_to_plot, ]
pitch_control_plot <- ggplot2::ggplot(surface, ggplot2::aes(pitch_x, pitch_y)) +
  ggplot2::geom_raster(ggplot2::aes(fill = victory_control), interpolate = TRUE) +
  ggplot2::scale_fill_gradient2(low = "#FF9E37", mid = "#29444D", high = "#28D7FA",
    midpoint = 0.5, limits = c(0, 1), name = "Estimated Victory control",
    breaks = c(0, 0.5, 1), labels = c("Auckland", "Contested", "Victory")) +
  ggplot2::guides(fill = ggplot2::guide_colourbar(
    barwidth = grid::unit(9, "cm"), barheight = grid::unit(0.4, "cm"),
    title.position = "top", title.hjust = 0.5)) +
  ggplot2::annotate("rect", xmin = -52.5, xmax = 52.5, ymin = -34, ymax = 34,
                   fill = NA, colour = "white", linewidth = 0.4) +
  ggplot2::annotate("segment", x = 0, xend = 0, y = -34, yend = 34, colour = "white") +
  ggplot2::annotate("rect", xmin = 36, xmax = 52.5, ymin = -20.16, ymax = 20.16,
                   fill = NA, colour = "white") +
  ggplot2::annotate("rect", xmin = -52.5, xmax = -36, ymin = -20.16, ymax = 20.16,
                   fill = NA, colour = "white") +
  ggplot2::geom_point(data = players, ggplot2::aes(pitch_x, pitch_y, colour = team,
    alpha = observed), inherit.aes = FALSE, shape = 21, fill = "#101A23", size = 6, stroke = 1) +
  ggplot2::geom_text(data = players, ggplot2::aes(pitch_x, pitch_y, label = shirt_number,
    colour = team, alpha = observed), inherit.aes = FALSE, size = 3, fontface = "bold") +
  ggplot2::geom_point(data = ball, ggplot2::aes(x, y), inherit.aes = FALSE,
                      colour = "white", shape = 16, size = 2) +
  ggplot2::scale_colour_manual(values = c(Victory = "#28D7FA", Auckland = "#FF9E37"), guide = "none") +
  ggplot2::scale_alpha_manual(values = c("TRUE" = 1, "FALSE" = 0.45), guide = "none") +
  ggplot2::coord_fixed(xlim = c(-53, 53), ylim = c(-35, 35), expand = FALSE) +
  ggplot2::labs(title = "Who controls the space?",
    subtitle = "Victory v Auckland | clip 5.0 s | model estimate",
    caption = "SkillCorner tracking | faint players: extrapolated positions | Spearman-style model") +
  ggplot2::theme_void(base_size = 12) +
  ggplot2::theme(plot.background = ggplot2::element_rect(fill = "#101A23", colour = NA),
    panel.background = ggplot2::element_rect(fill = "#101A23", colour = NA),
    text = ggplot2::element_text(colour = "white"), legend.position = "bottom",
    plot.title = ggplot2::element_text(face = "bold", size = 20),
    plot.subtitle = ggplot2::element_text(colour = "#B6C4CD"),
    plot.caption = ggplot2::element_text(colour = "#9CADBA"),
    plot.margin = ggplot2::margin(15, 20, 15, 20))
ggplot2::ggsave(file.path(clip_dir, "pitch_control_topdown.png"), pitch_control_plot,
                width = 12, height = 9, dpi = 150, bg = "#101A23")
