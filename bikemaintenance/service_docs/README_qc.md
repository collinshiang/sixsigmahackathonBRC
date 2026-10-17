# qc.R — Maintenance Crew Dispatch

This file answers one question for the Big Red Crew bike-share tool: **which bikes
need the maintenance crew, and where should the van go first?**

Input is one log of where every bike was, every 5 minutes (`BIKEID`, `DOCID`,
`time`). `DOCID == "0"` means the bike was away from any dock at that moment,
i.e. being ridden (per `system_architecture.md`).

---

## 1. The two signals

### Signal 1 — accumulated ride hours → "this bike is due for service"

Every bike keeps a running total of how long it has been ridden since its last
service. When that total reaches **x hours** (`service_interval_h`), the bike
is due and the crew gets pinged. `due_at` records the exact snapshot when the
bike crossed x hours, which is when the ping fires.

- **Ride time** = number of snapshots with `DOCID == "0"` × 5 minutes.
- **The limit counts all riding since the last service,** across many rides,
  not one long ride.
- **Our team's limit: x = 60 ride hours** (raised from 5, then 20). Each bike
  needs service as soon as it has been ridden 60 hours since its last service.
  This is a team design choice, not a cited manufacturer or operator figure.
  **Reasoning: crew capacity.** With bikes riding about 8 h/day, a limit of x
  means about 8 × 405 / x bikes due per day; at x = 60 that's about 54/day,
  which matches the simulated result (38–68/day). If the crew's real capacity
  is known, set x from it; if a published service interval is found, cite it.
- **x has no default in the code on purpose.** The function stops with an
  error if it isn't set, so nobody runs it with a hidden number. Call it as
  `dispatch_recommendation(data, service_interval_h = 60)`.
- **Service log (optional).** Pass a table of `BIKEID`, `service_time` and each
  bike's counter restarts after its most recent service. Without one, counting
  starts at the beginning of the data, and a bike that's due stays due.

**Where the van goes:** stations are ranked by how many due bikes are docked
there right now (`n_due`), so each stop services the most bikes. Ties go to the
station whose due bikes are furthest past the limit (`overdue_hours`). Total
hours counts bikes that don't need service; an average can put a tiny station
first and waste a trip. Due bikes that are out
on a ride aren't counted; the van can't reach them until they dock.

### Signal 2 — stuck bike → "this bike may be lost or broken"

A bike away from a dock far longer than any real trip is more likely lost,
stolen or broken than being ridden. Any bike **still** away at the latest
snapshot for 90+ minutes (`threshold_min`) is flagged right away.

Why 90 minutes, from both Jersey City files:

| Trip length | Original file | Second file |
|---|---|---|
| Median | 15 min | 15 min |
| 95th percentile | 55 min | 55 min |
| 99th percentile | 85 min | 80 min |
| Longest | 185 min | 210 min |

---

## 2. Functions

| Function | What it returns |
|---|---|
| `service_status(data, service_interval_h, service_log = NULL)` | One row per bike: `BIKEID`, `ride_hours` (since last service), `due` (TRUE/FALSE), `due_at` (when it crossed x, NA if not due), `current_dock` ("0" = out riding). Highest ride hours first. |
| `station_service_priority(data, service_interval_h, service_log = NULL)` | One row per station: `DOCID`, `n_bikes` (docked now), `n_due`, `overdue_hours`, `total_ride_hours`. Most due bikes first, ties by overdue hours. |
| `maintenance_alerts(data, threshold_min = 90)` | Bikes still away at the latest snapshot: `BIKEID`, `duration_min`, `flagged`. Longest first. |
| `dispatch_recommendation(data, service_interval_h, threshold_min = 90, service_log = NULL)` | All three at once: `stuck_alerts`, `service_due`, `stations`. This is the one call the app layer needs. |
| `transit_runs(data)` | Helper: one row per continuous ride, with `duration_min`. |
| `simulate_start_hours(bike_ids, service_interval_h, seed = 42)` | **Simulated** table of `BIKEID`, `start_hours`: random ride hours (0 to x) each bike already has when the data begins, so the fleet doesn't all come due at once. |
| `parse_time(x)` | Helper: reads `2026-09-16T00:00:00-0400` safely (see below). |

`service_status`, `station_service_priority` and `dispatch_recommendation` also
take `start_hours` (optional, from `simulate_start_hours()` or a real table).
A bike's starting hours are dropped once the service log shows it serviced.

All functions also take `interval_min` (default 5) in case a dataset uses a
different snapshot spacing.

---

## 3. Design decisions worth knowing about

- **Timestamps are parsed explicitly.** R's plain `as.POSIXct()` can silently
  drop the time of day from the CSV's format, which would collapse every
  bike's timeline. `parse_time()` uses an explicit format and stops with an
  error if anything can't be read.
- **"Now" means the latest snapshot in the data.** Current dock, stuck bikes
  and station rankings all use it.
- **No statistics outside this file.** Per `CLAUDE.md`, the app only calls
  these functions and displays the result.

## 4. What the data represents

The data is sampled every 5 minutes for a month and is meant to show busy and
lean periods. When a rack is empty, its bikes are out being ridden. Share of
bikes out riding in the second Jersey City file, by hour:

| Period | Weekdays | Weekends |
|---|---|---|
| Morning rush (7–8 AM) | about 60% | under 20% |
| Midday | about 25–35% | about 45–50% |
| Evening rush (5–6 PM) | about 63–66% | about 50% |
| Overnight (midnight–1 AM) | 10% | about 40% (night outs) |

The overnight weekend riding is intentional: it represents people coming home
from nights out. Weekday overnight is exactly 10% every hour from midnight to
4 AM, which looks flatter than real riding would; worth a check by the data team.

Because bikes keep moving between stations, station counts change all day. Every
station starts with 15 bikes, but by the end of the month they range from 6 to 23.

## 5. Known data limitation

In the second Jersey City file, every bike rides 218–257 hours over the month
(about 8 hours a day each, with very little spread). Any single x makes nearly
the whole fleet come due at about the same time. At x = 60 all 405 bikes
first come due between about 157 and 216 hours into the month (day 6.5 to 9),
with 90% of them inside 36 hours; at x = 5 it was all within the first day. To show the van choosing
between stations, the simulated data should include a service log with
staggered last-service dates, or more uneven usage between bikes.

**Simulated starting hours (stopgap).** `simulate_start_hours()` gives each
bike a random 0–60 ride hours at the start (spread over the whole limit), saved as
`start_hours_jersey_city2.csv` (seed 42). It removes the day-one wave but does
**not** fix the van ranking on its own: without a service log, a due bike stays
due, and every bike rides 218+ hours this month, so by the last snapshot all
405 are due. The van ranking still needs a real or simulated service log.

## 6. Visual output for the team

`van_dispatch_jersey_city2.png` shows where the van should go, without opening
any CSV. Each bar is a station: red is the number of due bikes docked there,
grey is docked bikes that aren't due, and the top three stops are highlighted.
The same numbers are in `van_dispatch_jersey_city2.csv`.

**This chart is out of date: made at the old limit, x = 5, with a made-up
service log. Don't use it; regenerate at x = 60 once there's a service log.** At x = 5 on the second Jersey City file, the top stops were
Washington St (10 due of 23 docked), Columbus Drive (10 of 17) and
Grove St PATH (9 of 15).

**Read this caveat before sharing it.** The data has no service records, so
the chart uses an *illustrative* service log: each bike's last service is set
to a random time in the final 24 hours. Without that, every bike would show as
due. The chart was also made in Python by mirroring `qc.R`, not by running the
R code. Replace it with a chart from the real R output once the data team adds
a simulated service log.

## Integration

`source("app/qc.R")`, then make one call:
`dispatch_recommendation(bikes, service_interval_h = 60, service_log = log, start_hours = sh)`.
It returns three plain data frames: `stuck_alerts`, `service_due` and
`stations` (row 1 = first van stop). The app layer (task H-04) turns these into
crew pings and a map or table; this file does no plotting, file writing or
alerting. Before showing results, convert `due_at` to New York time
(`format(due_at, tz = "America/New_York")`), and remember that without a
service log every bike that passes the limit stays due. Use the same
`service_interval_h` here and in the P chart so the two agree. Function names
don't clash with `pchart.R` or `failure_factor.R`, so all three can be sourced
in one session.

## 7. Tests

`test-qc.R` goes directly in `tests/`. Run:

```
Rscript -e "testthat::test_dir('tests')"
```

It checks hand-calculated answers on a 3-bike, 1-hour example (written out in
comments at the top of the file), plus degenerate cases: missing or invalid x,
empty data, a single row, a bike that never moves, a bike that's always away,
and CSV-style string timestamps.
