# INTEGRATION NOTES
# This file sources app/qc.R and finds it whether tests run from the repo root,
# tests/ or tests/testthat/. Keep it directly in tests/ so the contract's check,
# Rscript -e "testthat::test_dir('tests')", picks it up alongside
# test-pchart.R and test-failure_factor.R. The fixture is three hand-built
# bikes over one hour, so it runs in seconds and doesn't need the big CSV. If a
# teammate renames a function or column in qc.R, the matching test here must be
# updated to the new name, but never change an expected number to make a test
# pass: each one was worked out by hand and is the evidence the statistic is right.

# ---------------------------------------------------------------------------
# test-qc.R
# Known-answer and degenerate-case tests for app/qc.R
# Put this file directly in tests/ and run:  Rscript -e "testthat::test_dir('tests')"
# ---------------------------------------------------------------------------

library(testthat)
library(dplyr)

# Find qc.R whether tests run from the repo root, tests/, or tests/testthat/
qc_path <- Find(file.exists, c("app/qc.R", "../app/qc.R", "../../app/qc.R"))
if (is.null(qc_path)) stop("could not find app/qc.R")
source(qc_path)

make_rows <- function(bike, dock, times) {
  data.frame(BIKEID = bike, DOCID = dock, time = times, stringsAsFactors = FALSE)
}
at <- function(hhmm) as.POSIXct(paste0("2026-01-01 ", hhmm, ":00"), tz = "UTC")

# ---------------------------------------------------------------------------
# KNOWN-ANSWER DATA: a 1-hour log, 5-minute snapshots (13 of them, 00:00..01:00)
#
#  Bike A: dock X 00:00-00:10 | away 00:15-00:45 (7 snapshots) | dock Y 00:50-01:00
#  Bike B: dock Y the whole hour
#  Bike C: dock X 00:00-00:15 | away 00:20-01:00 (9 snapshots), still away at the end
#
# Ride time = away snapshots x 5 min:  A 35 min (0.5833 h), B 0, C 45 min (0.75 h)
# Stuck-bike runs: A 35 min (ended at 00:45), C 45 min (still open at 01:00)
#
# Service, x = 0.5 h (30 min):
#   A reaches 30 min at its 6th away snapshot, 00:40  -> due, due_at 00:40, docked at Y
#   C reaches 30 min at its 6th away snapshot, 00:45  -> due, due_at 00:45, out riding
#   B never rides                                      -> not due
#   Stations: Y has A and B docked, 1 due -> Y: n_bikes 2, n_due 1 (C is out, not counted)
# Service, x = 0.6 h (36 min):
#   A 35 min < 36 -> not due.  C reaches 40 >= 36 at 00:55 -> due.  Y: n_bikes 2, n_due 0
# Service log, A serviced at 00:30, x = 0.5 h:
#   A rides only after 00:30: 00:35, 00:40, 00:45 -> 15 min (0.25 h) -> not due
# ---------------------------------------------------------------------------

times <- seq(at("00:00"), at("01:00"), by = "5 min")
stopifnot(length(times) == 13)

docA <- c(rep("X", 3), rep("0", 7), rep("Y", 3))
docB <- rep("Y", 13)
docC <- c(rep("X", 4), rep("0", 9))

known_data <- bind_rows(
  make_rows("A", docA, times),
  make_rows("B", docB, times),
  make_rows("C", docC, times)
)
row_for <- function(df, bike) df[df$BIKEID == bike, ]

# ---- stuck-bike signal ------------------------------------------------------

test_that("transit_runs reproduces the hand-calculated durations", {
  runs <- transit_runs(known_data)
  expect_equal(row_for(runs, "A")$duration_min, 35)
  expect_equal(row_for(runs, "C")$duration_min, 45)
  expect_equal(nrow(row_for(runs, "B")), 0)
})

test_that("maintenance_alerts flags only the bike still away at the end", {
  alerts <- maintenance_alerts(known_data, threshold_min = 40)
  expect_equal(alerts$BIKEID, "C")
  expect_equal(alerts$duration_min, 45)
  expect_true(alerts$flagged)
  expect_false(maintenance_alerts(known_data, threshold_min = 50)$flagged)
})

test_that("stuck-bike degenerate cases", {
  empty <- data.frame(BIKEID = character(), DOCID = character(), time = character())
  expect_equal(nrow(transit_runs(empty)), 0)
  expect_equal(nrow(maintenance_alerts(empty)), 0)
  expect_equal(nrow(maintenance_alerts(make_rows("A", "X", times[1]))), 0)
  expect_equal(nrow(maintenance_alerts(make_rows("A", rep("X", 13), times))), 0)
  a <- maintenance_alerts(make_rows("A", rep("0", 13), times), threshold_min = 30)
  expect_equal(a$duration_min, 65)
  expect_true(a$flagged)
})

# ---- accumulated ride hours / service signal --------------------------------

test_that("service_status, x = 0.5 h: known answer", {
  s <- service_status(known_data, service_interval_h = 0.5)

  expect_equal(row_for(s, "A")$ride_hours, 35 / 60)
  expect_true(row_for(s, "A")$due)
  expect_equal(row_for(s, "A")$due_at, at("00:40"))
  expect_equal(row_for(s, "A")$current_dock, "Y")

  expect_equal(row_for(s, "C")$ride_hours, 0.75)
  expect_true(row_for(s, "C")$due)
  expect_equal(row_for(s, "C")$due_at, at("00:45"))
  expect_equal(row_for(s, "C")$current_dock, "0")

  expect_equal(row_for(s, "B")$ride_hours, 0)
  expect_false(row_for(s, "B")$due)
  expect_true(is.na(row_for(s, "B")$due_at))
})

test_that("service_status, x = 0.6 h: A falls just short, C still due", {
  s <- service_status(known_data, service_interval_h = 0.6)
  expect_false(row_for(s, "A")$due)
  expect_true(row_for(s, "C")$due)
  expect_equal(row_for(s, "C")$due_at, at("00:55"))
})

test_that("station_service_priority counts only due bikes that are docked", {
  st <- station_service_priority(known_data, service_interval_h = 0.5)
  expect_equal(st$DOCID, "Y")
  expect_equal(st$n_bikes, 2)
  expect_equal(st$n_due, 1)   # A is due and docked; C is due but out riding
  expect_equal(st$total_ride_hours, 35 / 60)   # A 35 min + B 0
  expect_equal(st$overdue_hours, 5 / 60)       # A is 35 - 30 = 5 min past the limit

  st6 <- station_service_priority(known_data, service_interval_h = 0.6)
  expect_equal(st6$n_due, 0)
})

test_that("a service log resets the counter", {
  log <- data.frame(BIKEID = "A", service_time = at("00:30"))
  s <- service_status(known_data, service_interval_h = 0.5, service_log = log)
  expect_equal(row_for(s, "A")$ride_hours, 0.25)
  expect_false(row_for(s, "A")$due)
  expect_true(row_for(s, "C")$due)   # C was never serviced
})

test_that("dispatch_recommendation bundles all three outputs", {
  r <- dispatch_recommendation(known_data, service_interval_h = 0.5, threshold_min = 40)
  expect_named(r, c("stuck_alerts", "service_due", "stations"))
  expect_equal(r$stuck_alerts$BIKEID, "C")
  expect_setequal(r$service_due$BIKEID, c("A", "C"))
  expect_equal(r$stations$n_due, 1)
})

# ---- starting hours (simulated stagger) -------------------------------------
# Limit 0.5 h. B never rides but starts with 0.6 h -> due at the first snapshot.
# C starts with 0.2 h and rides 0.75 h -> 0.95 h. A not listed -> starts at 0.
test_that("start_hours adds to each bike's ride time", {
  sh <- data.frame(BIKEID = c("B", "C"), start_hours = c(0.6, 0.2))
  s <- service_status(known_data, service_interval_h = 0.5, start_hours = sh)
  expect_equal(row_for(s, "B")$ride_hours, 0.6)
  expect_true(row_for(s, "B")$due)
  expect_equal(row_for(s, "B")$due_at, at("00:00"))
  expect_equal(row_for(s, "C")$ride_hours, 0.95)
  expect_equal(row_for(s, "A")$ride_hours, 35 / 60)
})

test_that("a service in the log overrides start_hours", {
  sh <- data.frame(BIKEID = "B", start_hours = 0.6)
  log <- data.frame(BIKEID = "B", service_time = at("00:10"))
  s <- service_status(known_data, service_interval_h = 0.5, service_log = log, start_hours = sh)
  expect_equal(row_for(s, "B")$ride_hours, 0)
  expect_false(row_for(s, "B")$due)
})

test_that("start_hours input is checked", {
  expect_error(service_status(known_data, 0.5, start_hours = data.frame(BIKEID = "A", start_hours = -1)), "zero or more")
  expect_error(service_status(known_data, 0.5, start_hours = data.frame(BIKEID = "A")), "columns")
})

test_that("simulate_start_hours is reproducible and stays within 0 to x", {
  a <- simulate_start_hours(c("A", "B", "C", "A"), service_interval_h = 20)
  expect_equal(nrow(a), 3)
  expect_true(all(a$start_hours >= 0 & a$start_hours <= 20))
  expect_equal(a, simulate_start_hours(c("A", "B", "C"), service_interval_h = 20))
})

# ---------------------------------------------------------------------------
# DEGENERATE CASES
# ---------------------------------------------------------------------------

test_that("service interval is required and must be positive", {
  expect_error(service_status(known_data), "service_interval_h is required")
  expect_error(service_status(known_data, service_interval_h = 0), "service_interval_h is required")
  expect_error(service_status(known_data, service_interval_h = -5), "service_interval_h is required")
  expect_error(service_status(known_data, service_interval_h = "5"), "service_interval_h is required")
})

test_that("empty data returns empty results without error", {
  empty <- data.frame(BIKEID = character(), DOCID = character(), time = character())
  expect_equal(nrow(service_status(empty, service_interval_h = 1)), 0)
  expect_equal(nrow(station_service_priority(empty, service_interval_h = 1)), 0)
})

test_that("n = 1: a single docked row", {
  one <- make_rows("A", "X", times[1])
  s <- service_status(one, service_interval_h = 1)
  expect_equal(s$ride_hours, 0)
  expect_false(s$due)
  st <- station_service_priority(one, service_interval_h = 1)
  expect_equal(st$n_bikes, 1)
  expect_equal(st$n_due, 0)
})

test_that("constant data: a bike that never leaves its dock", {
  constant <- make_rows("A", rep("X", 13), times)
  expect_equal(service_status(constant, service_interval_h = 1)$ride_hours, 0)
})

test_that("constant data: a bike that is always away", {
  away <- make_rows("A", rep("0", 13), times)
  s <- service_status(away, service_interval_h = 1)
  expect_equal(s$ride_hours, 65 / 60)
  expect_equal(s$due_at, at("00:55"))   # 12th away snapshot = 60 min
  expect_equal(nrow(station_service_priority(away, service_interval_h = 1)), 0)
})

# ---------------------------------------------------------------------------
# TIMESTAMP PARSING (regression: the CSV stores "2026-09-16T00:00:00-0400")
# ---------------------------------------------------------------------------

times_chr <- paste0(format(times, "%Y-%m-%dT%H:%M:%S", tz = "UTC"), "-0400")

test_that("parse_time keeps the time of day", {
  parsed <- parse_time(times_chr)
  expect_s3_class(parsed, "POSIXct")
  expect_equal(as.numeric(diff(parsed), units = "mins"), rep(5, 12))
  expect_identical(parse_time(times), times)
  expect_error(parse_time(c(times_chr[1], "not a time")), "could not be parsed")
})

test_that("known answers hold when time is a CSV-style string", {
  chr_data <- bind_rows(
    make_rows("A", docA, times_chr),
    make_rows("B", docB, times_chr),
    make_rows("C", docC, times_chr)
  )
  s <- service_status(chr_data, service_interval_h = 0.5)
  expect_equal(row_for(s, "A")$ride_hours, 35 / 60)
  expect_equal(maintenance_alerts(chr_data, threshold_min = 40)$duration_min, 45)
  expect_equal(station_service_priority(chr_data, service_interval_h = 0.5)$n_due, 1)
})

test_that("stations rank by due bikes docked, ties broken by overdue hours", {
  # Limit x = 15 min (0.25 h).
  # D rides 25 min -> dock X (10 over).  E, F ride 20 min -> dock Y (5 over each).
  # G rides 10 min -> dock X (not due).  Y has 2 due -> first; X has 1 due.
  dk <- function(n_away, dock) c(rep("0", n_away), rep(dock, 13 - n_away))
  d <- bind_rows(make_rows("D", dk(5, "X"), times), make_rows("E", dk(4, "Y"), times),
                 make_rows("F", dk(4, "Y"), times), make_rows("G", dk(2, "X"), times))
  st <- station_service_priority(d, service_interval_h = 0.25)
  expect_equal(st$DOCID, c("Y", "X"))
  expect_equal(st$n_due, c(2, 1))
  expect_equal(st$overdue_hours, c(10, 10) / 60)

  # Tie on n_due: H rides 30 min -> Z (15 over) beats D 25 min -> X (10 over)
  d2 <- bind_rows(make_rows("D", dk(5, "X"), times), make_rows("H", dk(6, "Z"), times))
  st2 <- station_service_priority(d2, service_interval_h = 0.25)
  expect_equal(st2$DOCID, c("Z", "X"))
})
