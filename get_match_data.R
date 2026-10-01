# Download and load one SkillCorner Open Data match into R.
# Default: Melbourne Victory v Auckland FC, 17 May 2025 (match 2017461).

match_id <- "2017461"
repo_raw <- "https://raw.githubusercontent.com/SkillCorner/opendata/master/data/matches"
match_dir <- file.path("data", "raw", match_id)
dir.create(match_dir, recursive = TRUE, showWarnings = FALSE)

match_files <- c(
  paste0(match_id, "_match.json"),
  paste0(match_id, "_tracking_extrapolated.jsonl"),
  paste0(match_id, "_dynamic_events.csv"),
  paste0(match_id, "_phases_of_play.csv")
)

for (filename in match_files) {
  destination <- file.path(match_dir, filename)
  if (!file.exists(destination)) {
    url <- paste(repo_raw, match_id, filename, sep = "/")
    message("Downloading ", filename)
    download.file(url, destination, mode = "wb", quiet = FALSE)
  }
}

# GitHub serves a small Git LFS pointer from raw.githubusercontent.com for the
# tracking file. Fetch its actual payload from media.githubusercontent.com.
tracking_path <- file.path(match_dir, paste0(match_id, "_tracking_extrapolated.jsonl"))
tracking_header <- readLines(tracking_path, n = 1L, warn = FALSE)
if (startsWith(tracking_header, "version https://git-lfs.github.com/spec/")) {
  tracking_url <- paste0(
    "https://media.githubusercontent.com/media/SkillCorner/opendata/master/data/matches/",
    match_id, "/", basename(tracking_path)
  )
  message("Downloading Git LFS tracking payload (~86 MB)")
  download.file(tracking_url, tracking_path, mode = "wb", quiet = FALSE)
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' required. Install with install.packages('jsonlite').")
}
if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Package 'readr' required. Install with install.packages('readr').")
}

# Metadata and tabular event layers are convenient for immediate exploration.
match <- jsonlite::fromJSON(file.path(match_dir, match_files[[1]]), simplifyVector = TRUE)
dynamic_events <- readr::read_csv(file.path(match_dir, match_files[[3]]), show_col_types = FALSE)
phases_of_play <- readr::read_csv(file.path(match_dir, match_files[[4]]), show_col_types = FALSE)

# Tracking is newline-delimited JSON with nested player/ball records. Keep its
# nested structure intact initially; flatten only fields needed by dashboard.
tracking <- jsonlite::stream_in(
  file(file.path(match_dir, match_files[[2]]), open = "r"),
  verbose = FALSE,
  simplifyVector = FALSE
)

message("Loaded match ", match_id, " into R.")
message("Frames: ", length(tracking), " | Events: ", nrow(dynamic_events),
        " | Phases: ", nrow(phases_of_play))
