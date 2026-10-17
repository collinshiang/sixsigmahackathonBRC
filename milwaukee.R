library(dplyr)
library(ggplot2)

CITY_TZ <- "America/Chicago"
BIN_MINUTES <- 5

milwaukee <- readRDS("data/milwaukee.rds")

# ------------------------------------------------------------------
# Timestamp handling
# ------------------------------------------------------------------

parse_city_time <- function(x, tz) {
  if (inherits(x, "POSIXt")) {
    # Preserve the actual instant; do not strip and reinterpret its clock.
    return(as.POSIXct(x))
  }

  x <- as.character(x)

  # Supports our
