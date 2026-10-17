# How to test the R files

Do this before showing results to anyone. Nothing here has been run in R yet,
so the tests are the first real check. Takes about 10 minutes.

## 1. Put the files in the repo

| File | Goes in |
|---|---|
| `qc.R` | `app/qc.R` |
| `pchart.R` | `app/pchart.R` |
| `failure_factor.R` | `app/failure_factor.R` |
| `test-qc.R` | `tests/test-qc.R` |
| `test-pchart.R` | `tests/test-pchart.R` |
| `test-failure_factor.R` | `tests/test-failure_factor.R` |
| `start_hours_jersey_city2.csv` | `data/` (label it simulated) |
| `README_qc.md`, `README_pchart.md`, `README_failure_factor.md` | `app/` (or wherever the team keeps docs) |

Put the test files **directly in `tests/`**, not in `tests/testthat/`.

## 2. Install the packages (once)

Open R or RStudio and run:

```r
install.packages(c("dplyr", "tidyr", "testthat"))
```

## 3. Run all the tests

In a terminal, from the **repo root** (the folder with `SPEC.md`):

```
Rscript -e "testthat::test_dir('tests')"
```

Or in RStudio, set the working directory to the repo root first:

```r
setwd("path/to/sixsigmahackathonBRC")
testthat::test_dir("tests")
```

## 4. Read the result

- **All pass:** you'll see a summary with `[ FAIL 0 | ... | PASS n ]`. Copy that
  line; `CONTRACT.yaml` asks you to quote it when checking in task H-03.
- **Something fails:** the output names the test and shows what it expected
  versus what it got. Copy the **whole** output and paste it back to Claude.
  Don't change the expected numbers in the tests to make them pass: they were
  worked out by hand and are the point of the check.
- **"could not find app/qc.R"** (or pchart / failure_factor): the file isn't in
  `app/`, or you're not running from the repo root.
- **"there is no package called ..."**: redo step 2.

## 5. Try it on real data (after tests pass)

```r
source("app/qc.R"); source("app/pchart.R"); source("app/failure_factor.R")
bikes <- read.csv("data/jersey_city.csv")      # use the file name in data/

# Van dispatch
r <- dispatch_recommendation(bikes, service_interval_h = 60)
head(r$stations)       # where the van should go first
r$stuck_alerts         # bikes away 90+ minutes right now

# P chart
sh <- read.csv("data/start_hours_jersey_city2.csv")  # SIMULATED; matches the chart
counts <- daily_service_counts(bikes, service_interval_h = 60, start_hours = sh)
plot_p_chart(p_chart(counts$d, counts$n, label = counts$day))

# Failure factor (rates are placeholders until the team picks real ones)
failure_factor(c(flat_tire = 0.02, battery = 0.05, crash = 0.01))
```

The full CSV has 3.5 million rows, so these can take a minute. With the
starting hours the P chart should sit around 0.13 (limits about 0.08–0.18)
with no days out of control. Without `start_hours` it zig-zags far outside its
limits. `dispatch_recommendation()` will show all 405 bikes due until there's
a service log; that's expected.

## 6. Known gaps to fix before submitting

- Times in `due_at` print in UTC, 4 hours ahead of New York.
- The 60-hour limit and the defect rates need a cited source or a stated reason.
- `SPEC.md` still has `FILL IN` lines and lists the rider as the user.

## 7. Integration

All three test files are independent: each sources only its own `app/` file
and uses small hand-built data, so one failing file doesn't break the others,
and none needs the 3.5-million-row CSV. When teammates merge their code, run
the full `testthat::test_dir('tests')` again so their test files and these run
together; that combined output is what to quote for the contract. If someone
renames a function or column, update the name in the tests but leave the
expected numbers alone. Source order doesn't matter, except that
`simulate_start_hours()` lives in `qc.R`, so source it before generating start
hours for the P chart.
