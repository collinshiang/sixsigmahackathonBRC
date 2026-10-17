
# ---------------------------------------------------------------------------
# app/qc.R
# Core maintenance-dispatch statistic for the bike-share rebalancing tool.
#
# Computed from one bike-position log (BIKEID, DOCID, time):
#   maintenance_alerts(): bikes still away from a dock (DOCID == "0") longer
#     than threshold_min (default 90) -> likely lost/stolen/broken, flag now.
#   service_status(): each bike's ride hours accumulate since its last
#     service; when they reach service_interval_h (x hours) the bike is due
#     and due_at records the moment the crew should have been pinged.
#   station_service_priority(): ranks stations by how many due bikes are
#     docked there right now, so one van stop services the most bikes.
#
# Inputs are plain: a data frame with columns BIKEID, DOCID, time.
# Outputs are plain: data frames of numbers. No plotting, no I/O side effects.
# ---------------------------------------------------------------------------

# INTEGRATION NOTES
# Load with source("app/qc.R") from the repo root; it needs dplyr (tidyr is
# loaded but unused and can be dropped). Input is the raw bike log as read by
# read.csv(): columns BIKEID, DOCID, time, with DOCID "0" meaning the bike is
# away from a dock and time as text like 2026-09-16T00:00:00-0400 (POSIXct is
# also fine). The one call the app layer (CONTRACT task H-04) needs is
# dispatch_recommendation(data, service_interval_h = 60, service_log = ...,
# start_hours = ...), which returns a list of three plain data frames:
# stuck_alerts (BIKEID, duration_min, flagged), service_due (BIKEID,
# ride_hours, due, due_at, current_dock) and stations (DOCID, n_bikes, n_due,
# overdue_hours, total_ride_hours), already sorted so row 1 is the van's first
# stop. Nothing here plots, writes files or sends alerts; turning service_due
# and stuck_alerts into crew pings is the app's job. Three things trip people
# up: service_interval_h has no default and errors if missing; due_at prints in
# UTC, so convert with format(x, tz = "America/New_York") before showing it;
# and without a service_log every bike that ever passes the limit stays due,
# so on the current data all 405 bikes read as due. Helper names (parse_time,
# rank_stations, check_start_hours) don't clash with pchart.R or
# failure_factor.R, so all three files can be sourced together.

library(dplyr)
library(tidyr)

#' Parse timestamps safely
#'
#' The bike logs store time as ISO-8601 strings with a UTC offset, e.g.
#' "2026-09-16T00:00:00-0400". Plain as.POSIXct() on that string can silently
#' read only the date and drop the time of day, so we parse with an explicit
#' format and fail loudly if anything cannot be read.
#'
#' @param x POSIXct (returned unchanged) or character like "2026-09-16T00:00:00-0400"
#' @return POSIXct in UTC
parse_time <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  out <- as.POSIXct(as.character(x), format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
  if (anyNA(out)) {
    # fall back to "YYYY-MM-DD HH:MM:SS" (no offset) before giving up
    alt <- as.POSIXct(as.character(x), format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    out <- ifelse(is.na(out), alt, out)
    out <- as.POSIXct(out, origin = "1970-01-01", tz = "UTC")
  }
  if (anyNA(out)) stop("parse_time(): some timestamps could not be parsed; expected e.g. 2026-09-16T00:00:00-0400")
  out
}

#' Identify contiguous "in transit" runs (DOCID == "0") per bike
#'
#' @param data data.frame with BIKEID, DOCID, time (POSIXct or parseable string)
#' @param interval_min numeric, the sampling interval in minutes (default 5)
#' @return data.frame: BIKEID, run_id, start, end, duration_min
transit_runs <- function(data, interval_min = 5) {
  stopifnot(all(c("BIKEID", "DOCID", "time") %in% names(data)))

  data <- data %>%
    mutate(time = parse_time(time)) %>%
    arrange(BIKEID, time) %>%
    mutate(is_transit = DOCID == "0")

  if (nrow(data) == 0) {
    return(data.frame(BIKEID = character(), run_id = integer(),
                       start = as.POSIXct(character()), end = as.POSIXct(character()),
                       duration_min = numeric()))
  }

  data <- data %>%
    group_by(BIKEID) %>%
    mutate(run_change = cumsum(is_transit != lag(is_transit, default = first(is_transit)))) %>%
    ungroup()

  data %>%
    filter(is_transit) %>%
    group_by(BIKEID, run_id = run_change) %>%
    summarise(start = min(time), end = max(time), n = n(), .groups = "drop") %>%
    mutate(duration_min = as.numeric(difftime(end, start, units = "mins")) + interval_min)
}

#' Flag bikes currently stuck in transit past a threshold
#'
#' Only runs still open at the latest snapshot can alert: a bike that had a
#' long ride earlier but has re-docked is not an active problem.
#'
#' @param data data.frame with BIKEID, DOCID, time
#' @param threshold_min numeric, minutes away from a dock before flagging (default 90,
#'   past ~99% of real trips in both Jersey City files)
#' @param interval_min numeric, sampling interval in minutes (default 5)
#' @return data.frame: BIKEID, duration_min, flagged, ordered by duration_min desc
maintenance_alerts <- function(data, threshold_min = 90, interval_min = 5) {
  stopifnot(is.numeric(threshold_min), threshold_min > 0)
  empty <- data.frame(BIKEID = character(), duration_min = numeric(), flagged = logical())
  if (nrow(data) == 0) return(empty)

  data <- data %>% mutate(time = parse_time(time))
  latest_time <- max(data$time)

  runs <- transit_runs(data, interval_min = interval_min)
  if (nrow(runs) == 0) return(empty)

  runs %>%
    filter(end == latest_time) %>%
    group_by(BIKEID) %>%
    slice_max(duration_min, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    transmute(BIKEID, duration_min, flagged = duration_min >= threshold_min) %>%
    arrange(desc(duration_min))
}

#' Accumulated ride hours per bike, and whether it is due for service
#'
#' Ride time = number of 5-minute snapshots where the bike is away from a dock
#' (DOCID == "0") since its last service, times interval_min. A bike becomes
#' due the moment its accumulated ride time reaches service_interval_h; due_at
#' is that moment (when the maintenance crew should be pinged).
#'
#' @param data data.frame with BIKEID, DOCID, time
#' @param service_interval_h numeric, REQUIRED, ride hours between services (x).
#'   No default on purpose: set it from a cited maintenance schedule.
#' @param service_log optional data.frame with BIKEID, service_time. Ride time
#'   counts only after each bike's most recent service (on or before the latest
#'   snapshot). Without a log, counting starts at the beginning of the data.
#' @param interval_min numeric, sampling interval in minutes (default 5)
#' @param start_hours optional data.frame with BIKEID, start_hours: ride hours a
#'   bike had already built up before the data begins (e.g. from
#'   simulate_start_hours()). Ignored for a bike once the service_log shows it
#'   serviced, since service resets the counter. Bikes not listed start at 0.
#' @return data.frame: BIKEID, ride_hours, due, due_at, current_dock
#'   (current_dock "0" = out on a ride), ordered by ride_hours desc
service_status <- function(data, service_interval_h, service_log = NULL, interval_min = 5,
                           start_hours = NULL) {
  if (missing(service_interval_h) || !is.numeric(service_interval_h) ||
      length(service_interval_h) != 1 || is.na(service_interval_h) || service_interval_h <= 0) {
    stop("service_interval_h is required: a positive number of ride hours between services")
  }

  if (nrow(data) == 0) {
    return(data.frame(BIKEID = character(), ride_hours = numeric(), due = logical(),
                      due_at = as.POSIXct(character(), tz = "UTC"), current_dock = character()))
  }

  data <- data %>%
    mutate(time = parse_time(time), DOCID = as.character(DOCID)) %>%
    arrange(BIKEID, time)
  latest_time <- max(data$time)

  current <- data %>%
    group_by(BIKEID) %>%
    slice_max(time, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(BIKEID, current_dock = DOCID)

  if (!is.null(service_log)) {
    stopifnot(all(c("BIKEID", "service_time") %in% names(service_log)))
    last_service <- service_log %>%
      mutate(service_time = parse_time(service_time)) %>%
      filter(service_time <= latest_time) %>%
      group_by(BIKEID) %>%
      summarise(last_service = max(service_time), .groups = "drop")
    data <- data %>%
      left_join(last_service, by = "BIKEID") %>%
      filter(is.na(last_service) | time > last_service)
  }

  data$offset_min <- 0
  if (!is.null(start_hours)) {
    sh <- check_start_hours(start_hours)
    data <- data %>%
      left_join(sh, by = "BIKEID", suffix = c("", ".sh")) %>%
      mutate(offset_min = coalesce(start_hours, 0) * 60) %>%
      select(-start_hours)
    if ("last_service" %in% names(data)) {
      data <- data %>% mutate(offset_min = ifelse(is.na(last_service), offset_min, 0))
    }
  }

  limit_min <- service_interval_h * 60
  usage <- data %>%
    group_by(BIKEID) %>%
    mutate(ride_min = offset_min + cumsum(DOCID == "0") * interval_min) %>%
    summarise(
      ride_hours = max(ride_min) / 60,
      # first snapshot where accumulated ride time reaches the limit; time[NA] keeps the time zone
      due_at = time[which(ride_min >= limit_min - 1e-9)[1]],
      .groups = "drop"
    )

  current %>%
    left_join(usage, by = "BIKEID") %>%
    mutate(ride_hours = coalesce(ride_hours, 0),
           due = !is.na(due_at)) %>%
    select(BIKEID, ride_hours, due, due_at, current_dock) %>%
    arrange(desc(ride_hours))
}

# internal: turn a service_status() table into a station ranking.
# Rank by n_due (due bikes docked now = bikes one van stop can service);
# ties broken by overdue_hours (how far past the limit those due bikes are).
rank_stations <- function(status, service_interval_h) {
  status %>%
    filter(current_dock != "0") %>%
    group_by(DOCID = current_dock) %>%
    summarise(n_bikes = n(),
              n_due = sum(due),
              overdue_hours = sum(pmax(ride_hours - service_interval_h, 0)),
              total_ride_hours = sum(ride_hours),
              .groups = "drop") %>%
    arrange(desc(n_due), desc(overdue_hours))
}

#' Rank stations by how many due-for-service bikes are docked there now
#'
#' Due bikes that are out on a ride (current_dock "0") are not counted: the
#' van cannot service them until they dock.
#'
#' @inheritParams service_status
#' @return data.frame: DOCID, n_bikes, n_due, overdue_hours, total_ride_hours,
#'   ordered by n_due desc, then overdue_hours desc
station_service_priority <- function(data, service_interval_h, service_log = NULL, interval_min = 5,
                                     start_hours = NULL) {
  rank_stations(service_status(data, service_interval_h, service_log, interval_min, start_hours),
                service_interval_h)
}

# internal: validate a start_hours table
check_start_hours <- function(start_hours) {
  if (!all(c("BIKEID", "start_hours") %in% names(start_hours)))
    stop("start_hours needs columns BIKEID and start_hours")
  if (anyNA(start_hours$start_hours) || any(start_hours$start_hours < 0))
    stop("start_hours must be zero or more, with no NA")
  if (anyDuplicated(start_hours$BIKEID)) stop("start_hours has a bike listed twice")
  data.frame(BIKEID = as.character(start_hours$BIKEID), start_hours = start_hours$start_hours)
}

#' SIMULATED starting ride hours, so the fleet doesn't all come due at once
#'
#' Each bike gets a random number of ride hours already used, spread evenly
#' between 0 and service_interval_h, as if bikes were last serviced at
#' different times before the data begins. This is made up, not measured:
#' label any chart that uses it as simulated.
#'
#' @param bike_ids vector of bike IDs
#' @param service_interval_h the service limit (x)
#' @param seed random seed, so the same table comes out every time (default 42)
#' @return data.frame: BIKEID, start_hours
simulate_start_hours <- function(bike_ids, service_interval_h, seed = 42) {
  if (!is.numeric(service_interval_h) || length(service_interval_h) != 1 || service_interval_h <= 0)
    stop("service_interval_h must be a positive number")
  bike_ids <- unique(as.character(bike_ids))
  set.seed(seed)
  data.frame(BIKEID = bike_ids,
             start_hours = round(runif(length(bike_ids), 0, service_interval_h), 2))
}

#' Combined dispatch recommendation for the maintenance crew
#'
#' @inheritParams service_status
#' @param threshold_min numeric, minutes away from a dock before a stuck-bike alert (default 90)
#' @return list(stuck_alerts, service_due, stations)
dispatch_recommendation <- function(data, service_interval_h, threshold_min = 90,
                                    service_log = NULL, interval_min = 5, start_hours = NULL) {
  status <- service_status(data, service_interval_h, service_log, interval_min, start_hours)
  list(
    stuck_alerts = maintenance_alerts(data, threshold_min = threshold_min, interval_min = interval_min),
    service_due  = status %>% filter(due),
    stations     = rank_stations(status, service_interval_h)
  )
}
