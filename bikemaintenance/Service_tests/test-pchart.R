# INTEGRATION NOTES
# Sources app/pchart.R only, so it runs independently of qc.R. Keep it directly
# in tests/ next to the other two test files. All fixtures are tiny hand-built
# examples (three days of 100 bikes, two bikes over two days), not the big CSV.
# If the app wraps p_chart() or changes its output columns, update the column
# names here, but leave the hand-calculated expected numbers alone.

# test-pchart.R  -  put in tests/, run: Rscript -e "testthat::test_dir('tests')"
library(testthat)
library(dplyr)
pc_path <- Find(file.exists, c("app/pchart.R", "../app/pchart.R", "../../app/pchart.R"))
if (is.null(pc_path)) stop("could not find app/pchart.R")
source(pc_path)

# KNOWN ANSWER (hand calculation)
# Three days, 100 bikes each, 5 / 10 / 15 due.
# p-bar = 30 / 300 = 0.10;  sigma = sqrt(0.10 * 0.90 / 100) = 0.03
# UCL = 0.10 + 0.09 = 0.19;  LCL = 0.10 - 0.09 = 0.01;  no day out of control.
test_that("p_chart reproduces the hand calculation", {
  ch <- p_chart(d = c(5, 10, 15), n = c(100, 100, 100))
  expect_equal(ch$p, c(0.05, 0.10, 0.15))
  expect_equal(unique(ch$p_bar), 0.10)
  expect_equal(ch$ucl, rep(0.19, 3))
  expect_equal(ch$lcl, rep(0.01, 3))
  expect_false(any(ch$out_of_control))
})

test_that("a spike day is flagged out of control", {
  # p-bar = 50 / 400 = 0.125; sigma = sqrt(0.125 * 0.875 / 100) = 0.03307
  # UCL = 0.2242; day 4 at 0.20 is inside, so use 0.30 instead
  ch <- p_chart(d = c(5, 5, 10, 30), n = rep(100, 4))
  expect_equal(unique(ch$p_bar), 0.125)
  expect_equal(ch$ucl[1], 0.125 + 3 * sqrt(0.125 * 0.875 / 100))
  expect_equal(ch$out_of_control, c(FALSE, FALSE, FALSE, TRUE))
})

test_that("limits widen for smaller subgroups", {
  ch <- p_chart(d = c(10, 10), n = c(100, 25))
  expect_true(ch$ucl[2] > ch$ucl[1])
})

# DEGENERATE CASES
test_that("no defects at all: p-bar 0, limits collapse to 0, nothing flagged", {
  ch <- p_chart(d = c(0, 0, 0), n = c(50, 50, 50))
  expect_equal(unique(ch$p_bar), 0)
  expect_equal(ch$ucl, rep(0, 3))
  expect_false(any(ch$out_of_control))
})

test_that("every bike defective: limits capped at 1", {
  ch <- p_chart(d = c(20, 20), n = c(20, 20))
  expect_equal(ch$ucl, c(1, 1))
  expect_false(any(ch$out_of_control))
})

test_that("n = 1 subgroup works", {
  ch <- p_chart(d = 1, n = 1)
  expect_equal(ch$p, 1)
})

test_that("bad input errors", {
  expect_error(p_chart(numeric(0), numeric(0)), "at least one")
  expect_error(p_chart(c(1, 2), c(10)), "same length")
  expect_error(p_chart(c(1), c(0)), "positive")
  expect_error(p_chart(c(11), c(10)), "0 <= d <= n")
  expect_error(p_chart(c(NA), c(10)), "NA")
})

# daily_service_counts known answer
# Limit 0.25 h (15 min). Two days, snapshots every 5 min at 10:00..10:25 local.
# Bike A rides all 6 snapshots on day 1 (30 min -> crosses 15 and 30: due) and
#   none on day 2 (not due).
# Bike B rides 2 snapshots each day: 10 min day 1, 20 min total by day 2 -> due day 2.
# Day 1: n 2, d 1 (A).  Day 2: n 2, d 1 (B).
test_that("daily_service_counts reproduces the hand calculation", {
  mk <- function(day) seq(as.POSIXct(paste(day, "14:00:00"), tz = "UTC"),
                          by = "5 min", length.out = 6)   # 14:00 UTC = 10:00 New York
  t1 <- mk("2026-09-16"); t2 <- mk("2026-09-17")
  log <- bind_rows(
    data.frame(BIKEID = "A", DOCID = c(rep("0", 6), rep("X", 6)), time = c(t1, t2)),
    data.frame(BIKEID = "B", DOCID = c("0", "0", rep("X", 4), "0", "0", rep("X", 4)), time = c(t1, t2))
  )
  out <- daily_service_counts(log, service_interval_h = 0.25)
  expect_equal(out$day, as.Date(c("2026-09-16", "2026-09-17")))
  expect_equal(out$n, c(2, 2))
  expect_equal(out$d, c(1, 1))
})

test_that("daily_service_counts requires the limit and handles empty data", {
  expect_error(daily_service_counts(data.frame(BIKEID = "A", DOCID = "X", time = Sys.time())), "required")
  empty <- data.frame(BIKEID = character(), DOCID = character(), time = character())
  expect_equal(nrow(daily_service_counts(empty, service_interval_h = 5)), 0)
})

# start_hours: same two-day fixture, limit 15 min. B starts with 0.1 h (6 min).
# Day 1: B rides 10 min -> 16 min, crosses 15 -> due. Day 2: 26 min, next is 30 -> not due.
# A unchanged (due day 1 only). So d = 2 on day 1, 0 on day 2.
test_that("daily_service_counts applies start_hours", {
  mk <- function(day) seq(as.POSIXct(paste(day, "14:00:00"), tz = "UTC"), by = "5 min", length.out = 6)
  t1 <- mk("2026-09-16"); t2 <- mk("2026-09-17")
  log <- bind_rows(
    data.frame(BIKEID = "A", DOCID = c(rep("0", 6), rep("X", 6)), time = c(t1, t2)),
    data.frame(BIKEID = "B", DOCID = c("0", "0", rep("X", 4), "0", "0", rep("X", 4)), time = c(t1, t2))
  )
  out <- daily_service_counts(log, service_interval_h = 0.25,
                              start_hours = data.frame(BIKEID = "B", start_hours = 0.1))
  expect_equal(out$d, c(2, 0))
})
