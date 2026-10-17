# ---------------------------------------------------------------------------
# failure_factor.R
# Failure factor: the share of bikes expected to be usable, given defect rates.
# Separate from qc.R and pchart.R.
#
#   failure_factor(rates)          -> one number between 0 and 1
#   failure_breakdown(rates)       -> per-defect table (what each defect costs)
#   apply_failure_factor(x, rates) -> scales a prediction (e.g. bikes at a dock)
#
# Formula (same idea as rolled throughput yield):
#   factor = (1 - r_1) x (1 - r_2) x ... x (1 - r_k)
# where r_i is the share of bikes with defect i (crash, flat tire, battery...).
#
# Assumption: defects are independent. If they overlap (e.g. a crash often
# causes a flat), this slightly UNDERSTATES the usable share; if they tend to
# exclude each other, it slightly OVERSTATES it.
#
# The rates are INPUTS chosen by the team. They are not estimated from the
# bike log, which has no defect information. Cite their source in the README.
# ---------------------------------------------------------------------------

# INTEGRATION NOTES
# Load with source("app/failure_factor.R"); it uses base R only, no packages,
# and doesn't read the bike log at all. Its job is to sit at the end of the
# dock-prediction step: whoever builds predicted bikes per dock passes that
# vector to apply_failure_factor(predicted, rates) to get usable bikes, e.g.
# preds$usable <- apply_failure_factor(preds$predicted_bikes, rates). Define
# rates once, in one place (a small config list or the main README), as a
# named vector of shares like c(flat_tire = 0.02, battery = 0.05,
# crash = 0.01), and have every piece read it from there so the numbers stay
# consistent. Rates are shares, not percents: entering 5 for 5% errors on
# purpose. failure_breakdown(rates) returns a small table that drops straight
# into a dashboard to show which defect costs the most. The rates are team
# inputs, not measured, so the app should state where they came from.

check_rates <- function(rates) {
  if (!is.numeric(rates)) stop("rates must be numeric, e.g. c(flat_tire = 0.02, battery = 0.05)")
  if (length(rates) > 0 && (is.null(names(rates)) || any(names(rates) == "")))
    stop("every rate needs a name, e.g. c(flat_tire = 0.02)")
  if (anyNA(rates)) stop("rates must not contain NA")
  if (any(rates < 0 | rates > 1)) stop("every rate must be between 0 and 1 (a share, not a percent)")
  invisible(rates)
}

#' Share of bikes expected to be usable
#' @param rates named numeric vector of defect shares, each between 0 and 1
#' @return number between 0 and 1. No defects listed -> 1.
failure_factor <- function(rates) {
  check_rates(rates)
  prod(1 - rates)
}

#' What each defect costs on its own, and the combined factor
#' @param rates named numeric vector of defect shares
#' @return data.frame: defect, rate, survive (1 - rate), cumulative_factor
#'   (factor after including this defect and all above it), sorted worst first
failure_breakdown <- function(rates) {
  check_rates(rates)
  if (length(rates) == 0)
    return(data.frame(defect = character(), rate = numeric(), survive = numeric(), cumulative_factor = numeric()))
  rates <- sort(rates, decreasing = TRUE)
  data.frame(defect = names(rates), rate = unname(rates), survive = unname(1 - rates),
             cumulative_factor = unname(cumprod(1 - rates)), row.names = NULL)
}

#' Scale a prediction by the failure factor
#' @param predicted numeric vector, e.g. predicted bikes at each dock
#' @param rates named numeric vector of defect shares
#' @return predicted x failure_factor(rates), same length as predicted
apply_failure_factor <- function(predicted, rates) {
  if (!is.numeric(predicted)) stop("predicted must be numeric")
  if (any(predicted < 0, na.rm = TRUE)) stop("predicted must not be negative")
  predicted * failure_factor(rates)
}
