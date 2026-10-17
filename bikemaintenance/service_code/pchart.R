# ---------------------------------------------------------------------------
# pchart.R
# P chart for "bikes needing maintenance per day". Separate from qc.R.
#
#   daily_service_counts(): from the bike log, for each day: n = bikes observed,
#     d = bikes that hit the service limit at least once that day.
#   p_chart(): the statistic. p-bar, per-day control limits, out-of-control flags.
#   plot_p_chart(): draws it (base R graphics, no extra packages).
#
# p chart formulas (Montgomery, Introduction to Statistical Quality Control):
#   p_i   = d_i / n_i
#   p-bar = sum(d_i) / sum(n_i)
#   UCL_i = p-bar + 3 * sqrt(p-bar * (1 - p-bar) / n_i)
#   LCL_i = max(0, p-bar - 3 * sqrt(p-bar * (1 - p-bar) / n_i))
# Limits vary by day when n varies. Assumes each bike is an independent
# Bernoulli trial with the same chance of needing service (binomial model).
# ---------------------------------------------------------------------------

# INTEGRATION NOTES
# Load with source("app/pchart.R"); it needs only dplyr, and plotting uses base
# R so no ggplot2 is required. It is independent of qc.R and takes the same raw
# bike log (BIKEID, DOCID, time). The typical chain is
# counts <- daily_service_counts(bikes, service_interval_h = 60, start_hours = sh)
# then chart <- p_chart(counts$d, counts$n, label = counts$day) then
# plot_p_chart(chart). Use the same service_interval_h as the van dispatch so
# both pieces tell the same story. p_chart() works on any counts, so another
# teammate's defect data (e.g. daily flat tires out of bikes inspected) can
# reuse it directly. In a Shiny app, call plot_p_chart() inside renderPlot(),
# or read the chart data frame and draw it yourself: columns are label, n, d,
# p, p_bar, lcl, ucl, out_of_control. The start_hours table is simulated
# (start_hours_jersey_city2.csv, or simulate_start_hours() from qc.R, which
# means sourcing qc.R first if you want to generate it); any chart built on it
# must be labelled simulated. Days are split in New York time by default.

library(dplyr)

pc_parse_time <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  out <- as.POSIXct(as.character(x), format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
  if (anyNA(out)) stop("pc_parse_time(): some timestamps could not be parsed; expected e.g. 2026-09-16T00:00:00-0400")
  out
}

#' The p chart statistic
#'
#' @param d integer vector, number defective in each subgroup (e.g. bikes due that day)
#' @param n integer vector, subgroup size (e.g. bikes observed that day), same length as d
#' @param label optional vector naming each subgroup (e.g. dates)
#' @return data.frame: label, n, d, p, p_bar, lcl, ucl, out_of_control
p_chart <- function(d, n, label = seq_along(d)) {
  if (length(d) == 0) stop("p_chart(): need at least one subgroup")
  if (length(d) != length(n) || length(label) != length(d)) stop("p_chart(): d, n and label must be the same length")
  if (anyNA(d) || anyNA(n)) stop("p_chart(): d and n must not contain NA")
  if (any(n <= 0)) stop("p_chart(): every subgroup size n must be positive")
  if (any(d < 0) || any(d > n)) stop("p_chart(): need 0 <= d <= n in every subgroup")

  p_bar <- sum(d) / sum(n)
  se <- sqrt(p_bar * (1 - p_bar) / n)
  p <- d / n
  ucl <- pmin(1, p_bar + 3 * se)
  lcl <- pmax(0, p_bar - 3 * se)

  data.frame(label = label, n = n, d = d, p = p, p_bar = p_bar,
             lcl = lcl, ucl = ucl, out_of_control = p > ucl | p < lcl)
}

#' Daily counts of bikes needing maintenance, from the bike log
#'
#' Each bike's ride time accumulates (DOCID == "0" snapshots x interval_min).
#' Every time it crosses another multiple of the service limit, that's one
#' "needs maintenance" event; the counter effectively resets there (assumes
#' the bike is serviced as soon as it comes due). A bike is defective on a day
#' if it had at least one such event that day.
#'
#' @param data data.frame with BIKEID, DOCID, time
#' @param service_interval_h numeric, REQUIRED, ride hours between services
#' @param tz time zone for day boundaries (default "America/New_York")
#' @param interval_min sampling interval in minutes (default 5)
#' @param start_hours optional data.frame with BIKEID, start_hours: ride hours
#'   already built up before the data begins (simulate_start_hours() in qc.R).
#'   Bikes not listed start at 0.
#' @return data.frame: day, n (bikes observed), d (bikes due at least once)
daily_service_counts <- function(data, service_interval_h, tz = "America/New_York", interval_min = 5,
                                 start_hours = NULL) {
  if (missing(service_interval_h) || !is.numeric(service_interval_h) ||
      length(service_interval_h) != 1 || is.na(service_interval_h) || service_interval_h <= 0) {
    stop("service_interval_h is required: a positive number of ride hours between services")
  }
  if (nrow(data) == 0) return(data.frame(day = as.Date(character()), n = integer(), d = integer()))

  limit_min <- service_interval_h * 60
  data <- data %>% mutate(BIKEID = as.character(BIKEID), offset_min = 0)
  if (!is.null(start_hours)) {
    if (!all(c("BIKEID", "start_hours") %in% names(start_hours)))
      stop("start_hours needs columns BIKEID and start_hours")
    if (anyNA(start_hours$start_hours) || any(start_hours$start_hours < 0))
      stop("start_hours must be zero or more, with no NA")
    sh <- data.frame(BIKEID = as.character(start_hours$BIKEID), sh = start_hours$start_hours)
    data <- data %>% left_join(sh, by = "BIKEID") %>%
      mutate(offset_min = coalesce(sh, 0) * 60) %>% select(-sh)
  }
  data %>%
    mutate(time = pc_parse_time(time), DOCID = as.character(DOCID)) %>%
    arrange(BIKEID, time) %>%
    group_by(BIKEID) %>%
    mutate(ride_min = offset_min + cumsum(DOCID == "0") * interval_min,
           cycles   = floor(ride_min / limit_min + 1e-9),
           event    = cycles > lag(cycles, default = floor(first(offset_min) / limit_min + 1e-9))) %>%
    ungroup() %>%
    mutate(day = as.Date(time, tz = tz)) %>%
    group_by(day, BIKEID) %>%
    summarise(due = any(event), .groups = "drop") %>%
    group_by(day) %>%
    summarise(n = n(), d = sum(due), .groups = "drop") %>%
    arrange(day)
}

#' Draw a p chart from p_chart() output
#'
#' @param chart data.frame from p_chart()
#' @param main chart title
plot_p_chart <- function(chart, main = "P chart: share of bikes needing maintenance per day") {
  x <- seq_len(nrow(chart))
  yr <- range(c(0, chart$p, chart$ucl, chart$lcl), na.rm = TRUE)
  plot(x, chart$p, type = "b", pch = 19, ylim = yr, xaxt = "n",
       xlab = "Day", ylab = "Proportion of bikes needing maintenance", main = main,
       col = ifelse(chart$out_of_control, "red", "black"))
  axis(1, at = x, labels = as.character(chart$label), las = 2, cex.axis = 0.7)
  abline(h = chart$p_bar[1], col = "blue")
  lines(x, chart$ucl, type = "s", lty = 2, col = "darkgray")
  lines(x, chart$lcl, type = "s", lty = 2, col = "darkgray")
  legend("topright", c("daily share", "out of control", "center (p-bar)", "3-sigma limits"),
         col = c("black", "red", "blue", "darkgray"), pch = c(19, 19, NA, NA),
         lty = c(NA, NA, 1, 2), bty = "n", cex = 0.8)
  invisible(chart)
}
