# INTEGRATION NOTES
# Sources app/failure_factor.R only and needs no data files, so it runs in
# well under a second. Keep it directly in tests/ with the other test files.
# The rates in these tests (2%, 5%, 1%) are just for the hand calculation; they
# are not the team's real rates, so changing the real rates later never
# requires touching this file.

# test-failure_factor.R - put in tests/, run: Rscript -e "testthat::test_dir('tests')"
library(testthat)
ff_path <- Find(file.exists, c("app/failure_factor.R", "../app/failure_factor.R", "../../app/failure_factor.R"))
if (is.null(ff_path)) stop("could not find app/failure_factor.R")
source(ff_path)

# KNOWN ANSWER (hand calculation)
# flat tire 2%, battery 5%: 0.98 x 0.95 = 0.931
# add crash 1%: 0.931 x 0.99 = 0.92169
# 20 predicted bikes x 0.931 = 18.62 usable
rates2 <- c(flat_tire = 0.02, battery = 0.05)
rates3 <- c(flat_tire = 0.02, battery = 0.05, crash = 0.01)

test_that("failure_factor reproduces the hand calculation", {
  expect_equal(failure_factor(rates2), 0.931)
  expect_equal(failure_factor(rates3), 0.92169)
})

test_that("apply_failure_factor scales predictions", {
  expect_equal(apply_failure_factor(20, rates2), 18.62)
  expect_equal(apply_failure_factor(c(0, 10, 20), rates2), c(0, 9.31, 18.62))
})

test_that("failure_breakdown sorts worst first with cumulative factor", {
  b <- failure_breakdown(rates3)
  expect_equal(b$defect, c("battery", "flat_tire", "crash"))
  expect_equal(b$cumulative_factor, c(0.95, 0.931, 0.92169))
  expect_equal(tail(b$cumulative_factor, 1), failure_factor(rates3))
})

test_that("order of defects does not change the factor", {
  expect_equal(failure_factor(rev(rates3)), failure_factor(rates3))
})

# DEGENERATE CASES
test_that("no defects listed: factor is 1", {
  none <- setNames(numeric(0), character(0))
  expect_equal(failure_factor(none), 1)
  expect_equal(nrow(failure_breakdown(none)), 0)
})

test_that("all rates zero: factor is 1; any rate one: factor is 0", {
  expect_equal(failure_factor(c(a = 0, b = 0)), 1)
  expect_equal(failure_factor(c(a = 1, b = 0.3)), 0)
})

test_that("single defect: factor is 1 - rate", {
  expect_equal(failure_factor(c(flat_tire = 0.1)), 0.9)
})

test_that("bad input errors", {
  expect_error(failure_factor(c(flat_tire = 5)), "between 0 and 1")   # a percent, not a share
  expect_error(failure_factor(c(flat_tire = -0.1)), "between 0 and 1")
  expect_error(failure_factor(c(0.02, 0.05)), "needs a name")
  expect_error(failure_factor(c(a = NA)), "NA")
  expect_error(failure_factor("0.02"), "numeric")
  expect_error(apply_failure_factor(-1, rates2), "negative")
})
