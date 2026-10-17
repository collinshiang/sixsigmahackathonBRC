# pchart.R — P chart: bikes needing maintenance per day

Separate from `qc.R`. It answers: **is the share of bikes needing maintenance
each day stable, or are some days unusual?**

## How it works
1. `daily_service_counts(data, service_interval_h)` reads the bike log. Each
   bike's ride time adds up; every time it passes the service limit (e.g. 5
   hours) that bike needs maintenance, and the counter starts again (assumes
   it's serviced right away). For each day: `n` = bikes observed, `d` = bikes
   that needed maintenance at least once that day. Days use New York time.
2. `p_chart(d, n)` computes the chart:
   - daily share `p = d / n`
   - centre line `p-bar = total d / total n`
   - limits `p-bar ± 3 × sqrt(p-bar × (1 − p-bar) / n)`, kept between 0 and 1
   - `out_of_control` = TRUE when a day falls outside the limits
3. `plot_p_chart(chart)` draws it: black dots are days, red dots are out of
   control, blue line is p-bar, dashed lines are the limits.

Optional `start_hours` (from `simulate_start_hours()` in `qc.R`): each bike
starts with that many ride hours already used, so bikes come due on different
days instead of all at once.

## How to read it
Dots inside the dashed lines: normal day-to-day variation. A red dot: that
day had unusually many (or few) bikes needing maintenance; look for a cause.

## Example
```r
source("app/pchart.R")
bikes <- read.csv("data/jersey_city.csv")
source("app/qc.R")   # for simulate_start_hours()
sh <- read.csv("data/start_hours_jersey_city2.csv")   # or simulate_start_hours(unique(bikes$BIKEID), 60)
counts <- daily_service_counts(bikes, service_interval_h = 60, start_hours = sh)
chart <- p_chart(counts$d, counts$n, label = counts$day)
plot_p_chart(chart)
```

## Assumptions
- Binomial model: each bike independently has the same chance of needing
  service each day. Bikes ridden more are more likely due, so this is an
  approximation.
- A bike is serviced the moment it comes due.
- Source for formulas: Montgomery, *Introduction to Statistical Quality Control*.

## Data warning
Team limit is now 60 ride hours. On the current second Jersey City file
(about 8 ride hours per bike per day):
- **Without staggered starting hours the chart is unusable:** every bike starts
  the month at zero, so they all come due in one wave (days 6.5–9) that
  repeats. 27 of 30 days fall outside the limits. Judges reading that as "the
  process is out of control" would be misled. (At 5 h it sat flat at 100%; at
  20 h, 22 of 30 days were out.)
- **With simulated staggered starting hours (0–60 h, seed 42)** the wave is
  gone: p-bar 0.133, limits 0.082–0.183, daily share 0.094–0.168, and
  **0 of 30 days out of control**. About 54 bikes due per day (38–68). Three
  other random seeds also gave 0 days out. See `pchart_jersey_city2_60h.png`,
  made in Python mirroring this code, not in R.
- The starting hours must span the whole limit (0–60). A 0–20 spread would
  bunch the fleet into the first third of the cycle.

## Integration

Independent of `qc.R`: it reads the same raw bike log and needs only dplyr.
Chain `daily_service_counts()` → `p_chart()` → `plot_p_chart()`; in Shiny,
put `plot_p_chart()` inside `renderPlot()`, or draw your own chart from the
`p_chart()` data frame (`label, n, d, p, p_bar, lcl, ucl, out_of_control`).
`p_chart(d, n)` takes any daily counts, so it can chart other defects too,
such as flat tires found out of bikes inspected. Use the same 60-hour limit as
the van dispatch, and label any chart built on `start_hours` as simulated.

## Tests
`test-pchart.R` checks a hand-calculated example (5/10/15 due out of 100 each
→ p-bar 0.10, limits 0.01 and 0.19), a spike day, varying subgroup sizes, and
degenerate cases (no defects, all defective, n = 1, bad input). Not yet run in R.
