# Notes for the data team

From checking `jersey_city.csv` (first version) and `jersey_city-2.csv` (second
version) against what the maintenance, P chart and failure factor code needs.
Numbers below are measured from the files, not estimated.

**Please fix these in `simulate_data.R` and regenerate, not by editing the CSVs.**
The repo requires the data to be reproducible from the script, and editing
rides out of a CSV leaves bikes jumping between stations.

## What's already good
- Clean shape: 405 bikes, 27 stations, every 5 minutes, Sep 16 – Oct 15.
- Every station starts with 15 bikes, then counts drift (6 to 23 by the end).
- Clear weekday rush hours (about 60% of bikes out at 7–8 AM, 66% at 5 PM) and
  steadier weekend riding, with weekend late-night rides for nights out.

## 1. Riding is too heavy (most important)
| | First file | Second file |
|---|---|---|
| Share of time a bike is away from a dock | 4% | 33% |
| Ride hours per bike per day | about 1 | about 8 |
| Ride hours per bike over the month | 18–40 | 218–257 |

Eight hours a day per bike is far above typical bike-share use (we expect
roughly 1–2 hours; worth checking a source). The team's service limit is
now 60 ride hours (raised from 5, then 20). On the current file, without
staggered starting hours:
- all 405 bikes first come due between day 6.5 and day 9, so the van ranking
  can't tell stations apart;
- the P chart shows that wave: 27 of 30 days fall outside the control limits.
  That's a data artifact (every bike starts at zero hours), not a real
  process signal.

**Ask:** lower the ride rate toward realistic use (we expect 1–2 ride hours
a day; please check a source). **Heads-up on the trade-off:** at 1–2 h/day a
60-hour limit means a bike comes due only every 30–60 days, so in a 30-day
file only about 7–14 bikes a day come due. The P chart still works at that
rate, but the team should pick riding rate and limit together. This only
works with item 3: without staggered last-service dates the fleet still
comes due in one wave.

## 2. Bikes are used almost identically
In the second file every bike lands within about ±7% of the average monthly
hours. Real fleets have some bikes ridden much more than others.
**Ask:** give bikes different popularity (e.g. some bikes, or bikes at busy
stations, get picked more often) so wear differs between bikes.

## 3. No service log
The maintenance code can restart each bike's counter after a service, but
there's no service data. The van chart had to use made-up service times,
which can't go in the final demo.
Stopgap already done on the code side: `simulate_start_hours()` in `qc.R`
gives each bike random starting ride hours (`start_hours_jersey_city2.csv`).
At 60 h that fixed the P chart (27 of 30 days out of control → 0 of 30), but the van
ranking still needs a service log, because without one every bike is due by
month end.

**Ask:** generate `service_log.csv` with columns `BIKEID`, `service_time`
(same time format as the bike log), with last-service times **staggered**
across bikes so they don't all come due at once.

## 4. Weekday overnight riding is perfectly flat
On weekdays exactly 10% of bikes are out every hour from midnight to 4 AM.
Weekend nights look natural (about 40% at midnight to 1 AM, then dropping).
**Ask:** check whether the flat 10% is intended; real overnight riding would
taper off.

## 5. No stuck bikes to demo the alert
The longest away-from-dock stretch is 210 minutes, and long rides look like
the normal tail, not broken bikes. The 90-minute stuck-bike alert has nothing
clear to catch.
**Ask:** plant a few bikes (say 3–5) that leave a dock and stay away for
several hours, so the demo shows the alert working. Note them in the codebook.

## 6. Contract items still open (H-02)
- H-02 needs three datasets (Jersey City, Milwaukee, simulated city). We've
  only checked Jersey City.
- `data/README.md` should describe every column and say plainly that the data
  is simulated, including the assumptions above.

## Not a data-team job, but related
The defect rates for the failure factor (flat tires, battery, crashes) are
**inputs the team chooses**, not simulated. They need a cited source or a
stated reason in the README.

## Integration: what the code expects from you

Every R file reads the bike log with exactly three columns: `BIKEID`, `DOCID`
(`"0"` = away from a dock, stored as text) and `time` in the
`2026-09-16T00:00:00-0400` format, every 5 minutes. Please keep those names and
that format in any regenerated file; a different time format makes the code
stop with an error rather than guess. The service log should be `BIKEID`,
`service_time` in the same time format, and bike IDs must match the bike log
exactly (e.g. `JERSEY_CITY-B0001`). If you change the snapshot spacing, tell
us, since the code's `interval_min` setting has to match. Saving to `data/`
with the column names above means the code runs on it without changes.
