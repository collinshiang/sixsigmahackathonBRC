# Simple-average projection of bikes docked at each station, by time of day.
#
# For every five-minute snapshot, count the bikes at each dock (DOCID != "0";
# a dock with no bikes counts as 0). The projection for a dock at a given
# time of day is the plain mean of that count across all days in the data.

library(dplyr)

dock_counts <- function(movement) {
  docks <- sort(unique(movement$DOCID[movement$DOCID != "0"]))
  observed <- movement |>
    filter(DOCID != "0") |>
    count(time, dock = DOCID)
  cross_join(tibble(time = unique(movement$time)), tibble(dock = docks)) |>
    left_join(observed, by = c("time", "dock")) |>
    mutate(n = coalesce(n, 0L))
}

simple_average_by_dock <- function(counts) {
  counts |>
    mutate(slot = as.numeric(format(time, "%H")) +
             as.numeric(format(time, "%M")) / 60) |>
    group_by(dock, slot) |>
    summarise(avg = mean(n), .groups = "drop")
}

plot_dock_averages <- function(avg, title = "") {
  docks <- unique(avg$dock)
  cols <- hcl.colors(length(docks), "Dark 3")
  plot(NA, xlim = c(0, 24), ylim = c(0, max(avg$avg)), xaxt = "n",
       xlab = "Time of day", ylab = "Average bikes docked", main = title)
  axis(1, at = seq(0, 24, 3), labels = sprintf("%02d:00", seq(0, 24, 3)))
  for (i in seq_along(docks)) {
    d <- avg[avg$dock == docks[i], ]
    lines(d$slot, d$avg, col = cols[i], lwd = 1.2)
  }
  invisible(cols)
}

movement <- readRDS("data/jersey_city.rds")
counts <- dock_counts(movement)
avg <- simple_average_by_dock(counts)
plot_dock_averages(avg, "Jersey City: avg bikes by dock")
