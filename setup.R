# Run once from the project root to install local R dependencies.
packages <- c("jsonlite", "readr", "ggplot2", "magick", "png")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("R dependencies ready. FFmpeg and Python dependencies are installed separately.")
