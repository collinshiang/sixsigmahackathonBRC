# 02. Tool Components & Comprehensive Function Reference

> **Big Red Crew — BikeSmart R Package**

---

## 1. System Architecture Overview

`bikesmart` is divided into four cohesive, statistical, and operational modules:

```
+--------------------------------------------------------------------------------------------------+
|                                    BIKESMART ARCHITECTURE                                        |
+--------------------------------------------------------------------------------------------------+
|                                                                                                  |
|  [ MODULE 1: DOCK INVENTORY PROJECTION & INCENTIVE OPTIMIZATION ]                                |
|  - compute_dock_rates()  : Aggregates historical net docking rate per weekly 5-min slot          |
|  - predict_dock()        : Integrates typical rates over travel window to project arrival count  |
|  - return_discount()     : Incentive discounts (0%, 10%, 20%) based on projected dock occupancy  |
|  - optimize_docks()      : Filters by projected availability and ranks docks by road distance    |
|                                                                                                  |
|  [ MODULE 2: USABLE FLEET RELIABILITY & FAILURE FACTOR MODELING ]                                |
|  - failure_factor()      : Computes rolled throughput usable proportion across defects           |
|  - failure_breakdown()   : Pareto breakdown of per-defect survival impact                         |
|  - apply_failure_factor(): Scales projected inventory to true usable/rentable bike counts        |
|                                                                                                  |
|  [ MODULE 3: STATISTICAL PROCESS CONTROL (SPC) P-CHARTS ]                                        |
|  - daily_service_counts(): Extracts daily sample size (n) and bikes hitting service limits (d)   |
|  - p_chart()             : Computes p-bar, stepped 3-sigma control limits, and alarm flags       |
|  - plot_p_chart()        : Generates base-R SPC control chart with UCL/LCL step bands            |
|                                                                                                  |
|  [ MODULE 4: MAINTENANCE LOGISTICS & ANOMALY DETECTION ]                                        |
|  - service_status()      : Tracks cumulative ride hours per bike and service due timestamps      |
|  - maintenance_alerts()  : Detects stuck bikes in transit (>90 min) indicating loss or theft     |
|  - station_service_priority(): Ranks stations by docked due bikes to maximize van efficiency    |
|  - dispatch_recommendation(): Unified operational report for maintenance crews                  |
|                                                                                                  |
+--------------------------------------------------------------------------------------------------+
```

---

## 2. Complete Function Catalog

### Module 1: Dock Projection & Rebalancing Optimization (`dock_projection.R`)

#### `compute_dock_rates(df, bin_minutes = 5, tz = "America/Chicago")`
- **Purpose:** Analyzes multi-week historical bike snapshot logs to compute the typical net arrival/departure rate (bikes per minute) for every station and every 5-minute slot of the week ($7 \times 288 = 2,016$ slots).
- **Parameters:**
  - `df`: Data frame with columns `BIKEID` (character), `DOCID` (character), and `time` (POSIXct or parseable character string).
  - `bin_minutes`: Numeric slot width in minutes (default `5`; must divide 1440 evenly).
  - `tz`: IANA timezone string for the city (default `"America/Chicago"`).
- **Return Value:** Data frame with 2,016 rows per dock:
  - `DOCID`: Station identifier
  - `weekday`: Integer 1 (Monday) to 7 (Sunday)
  - `day`: Abbreviated day of week string (`"Mon"`, `"Tue"`, etc.)
  - `tod`: Time of day formatted string (`"HH:MM"`)
  - `slot`: Integer slot index (0 to 2,015)
  - `n_days`: Number of historical days observed for this slot
  - `avg_docked`: Historical average count of docked bikes
  - `prev_docked`: Historical average count in the preceding slot
  - `rate`: Net docking rate in bikes/minute: $(\text{avg\_docked} - \text{prev\_docked}) / \text{bin\_minutes}$
- **Formula:**
  $$\text{rate}_t = \frac{\bar{B}_t - \bar{B}_{t-1}}{\Delta t}$$

#### `predict_dock(rates, dock, live_bikes, capacity, walk_min, now = Sys.time(), smooth_min = 30, bin_minutes = 5, tz = "America/Chicago")`
- **Purpose:** Projects the number of available bikes and free docking slots at a station when a user arrives.
- **Parameters:**
  - `rates`: Output from `compute_dock_rates()`.
  - `dock`: Station name or ID.
  - `live_bikes`: Current count of bikes at departure time.
  - `capacity`: Station docking capacity.
  - `walk_min`: Estimated walking or riding time in minutes to reach the dock.
  - `now`: Departure timestamp (default `Sys.time()`).
  - `smooth_min`: Rolling centered average smoothing window in minutes (default `30`).
- **Return Value:** Named numeric vector:
  - `expected_bikes`: Clamped between $0$ and `capacity`.
  - `expected_spaces`: `capacity - expected_bikes`.
  - `change`: Net change integrated over the trip window.
- **Formula:**
  $$\Delta B = F_{\text{typical}}(t_{\text{arrive}}) - F_{\text{typical}}(t_{\text{now}})$$
  $$B_{\text{projected}} = \max\left(0, \min\left(\text{capacity}, B_{\text{live}} + \Delta B\right)\right)$$

#### `return_discount(projected_bikes, capacity)`
- **Purpose:** Implements crowdsourced rebalancing incentives by offering price discounts when riders return bikes to docks projected to have low occupancy.
- **Parameters:**
  - `projected_bikes`: Numeric vector of expected bikes before return.
  - `capacity`: Numeric vector of station capacities.
- **Return Value:** Integer vector of discount percentages:
  - Occupancy $< 25\% \implies 20\%$ discount
  - Occupancy $25\% \le \text{occ} < 50\% \implies 10\%$ discount
  - Occupancy $\ge 50\% \implies 0\%$ discount

#### `optimize_docks(user_location, stations, rates, mode = c("pickup", "return"), now = Sys.time(), user_distances, travel_speed_mph = NULL, ...)`
- **Purpose:** Evaluates all candidate stations from a user's starting point, filters out docks projected to fail (fewer than 1 available bike or slot at arrival), and returns viable docks ordered by shortest road network distance.
- **Parameters:**
  - `user_location`: Saved location ID (e.g. `"MKE-LOC01"`).
  - `stations`: Data frame with columns `dockID`, `live_bikes`, `capacity`.
  - `rates`: Output table from `compute_dock_rates()`.
  - `mode`: `"pickup"` (walking speed default: 3 mph) or `"return"` (cycling speed default: 10 mph).
  - `user_distances`: Distance lookup table (`location_id`, `mode`, `dockID`, `distance` in miles).
- **Return Value:** Ranked data frame sorted by `distance_miles` with `rank`, `dockID`, `distance_miles`, `travel_minutes`, `arrival_time`, `projected_bikes`, `projected_spaces`, and `discount_percent`. Excluded docks are attached in attribute `excluded_docks`.

---

### Module 2: Fleet Reliability & Failure Factor Modeling (`failure_factor.R`)

#### `failure_factor(rates)`
- **Purpose:** Calculates the overall usable fraction of bikes in the fleet given defect rates across multiple independent failure modes.
- **Parameters:**
  - `rates`: Named numeric vector of defect shares ($0 \le r_i \le 1$). E.g., `c(flat_tire = 0.02, dead_battery = 0.05, brake_failure = 0.01)`.
- **Return Value:** Single numeric value in $[0, 1]$.
- **Formula (Rolled Throughput Survival):**
  $$\text{factor} = \prod_{i=1}^k (1 - r_i)$$

#### `failure_breakdown(rates)`
- **Purpose:** Generates a Pareto table detailing the standalone survival rate and cumulative usable factor as each defect type is introduced, sorted from most severe to least severe.
- **Return Value:** Data frame with columns:
  - `defect`: Defect name
  - `rate`: Defect proportion ($r_i$)
  - `survive`: $1 - r_i$
  - `cumulative_factor`: Running cumulative product $\prod_{j=1}^i (1 - r_j)$

#### `apply_failure_factor(predicted, rates)`
- **Purpose:** Scales inventory predictions by the usable fleet factor so operations and riders know the actual usable count of bikes.
- **Return Value:** Numeric vector: $\text{predicted} \times \text{failure\_factor(rates)}$.

---

### Module 3: Attribute Statistical Process Control P-Charts (`pchart.R`)

#### `daily_service_counts(data, service_interval_h, tz = "America/New_York", interval_min = 5, start_hours = NULL)`
- **Purpose:** Reads 5-minute snapshot logs, tracks each bike's accumulated ride hours ($DOCID == "0" \times 5 \text{ min}$), and counts daily active bikes ($n$) and bikes that crossed maintenance thresholds ($d$).
- **Parameters:**
  - `data`: Movement log (`BIKEID`, `DOCID`, `time`).
  - `service_interval_h`: Required positive number of ride hours between preventive services (e.g., 60 h).
  - `tz`: Calendar timezone for day boundaries.
  - `start_hours`: Optional initial ride hour offsets (`BIKEID`, `start_hours`).
- **Return Value:** Data frame with `day`, `n` (bikes observed), `d` (bikes due).

#### `p_chart(d, n, label = seq_along(d))`
- **Purpose:** Computes standard binomial attribute control chart statistics.
- **Parameters:**
  - `d`: Integer vector of defect/maintenance occurrences.
  - `n`: Integer vector of sample sizes (active bikes).
  - `label`: Vector naming subgroups (e.g. dates).
- **Return Value:** Data frame with columns:
  - `label`, `n`, `d`, `p` ($d_i / n_i$), `p_bar` ($\sum d / \sum n$), `lcl`, `ucl`, `out_of_control` (TRUE/FALSE).
- **Formulas:**
  $$\bar{p} = \frac{\sum_{i=1}^m d_i}{\sum_{i=1}^m n_i}$$
  $$UCL_i = \min\left(1, \bar{p} + 3\sqrt{\frac{\bar{p}(1 - \bar{p})}{n_i}}\right), \quad LCL_i = \max\left(0, \bar{p} - 3\sqrt{\frac{\bar{p}(1 - \bar{p})}{n_i}}\right)$$

#### `plot_p_chart(chart, main = ...)`
- **Purpose:** Renders the control chart using base R graphics:
  - Black line and points for in-control days.
  - Prominent red dots for out-of-control days ($p_i > UCL_i$ or $p_i < LCL_i$).
  - Blue horizontal center line ($\bar{p}$).
  - Stepped dashed gray lines for $UCL_i$ and $LCL_i$.

---

### Module 4: Maintenance Operations & Logistics (`maintenance_qc.R`)

#### `service_status(data, service_interval_h, service_log = NULL, interval_min = 5, start_hours = NULL)`
- **Purpose:** Tracks cumulative ride hours since last service for every bike.
- **Return Value:** Data frame with `BIKEID`, `ride_hours`, `due` (TRUE/FALSE), `due_at` (timestamp when limit crossed), `current_dock` ("0" if currently ridden).

#### `maintenance_alerts(data, threshold_min = 90, interval_min = 5)`
- **Purpose:** Anomaly detection. Flags bikes away from docks ($DOCID == "0"$) continuously for $\ge 90$ minutes at the latest snapshot (99th percentile of real trip lengths is 80–85 minutes).
- **Return Value:** Data frame with `BIKEID`, `duration_min`, `flagged`.

#### `station_service_priority(data, service_interval_h, service_log = NULL, ...)`
- **Purpose:** Optimizes mobile maintenance van routes. Groups docked due bikes by station and ranks stations with the most due bikes ($n_{due}$) first; ties broken by cumulative overdue hours.
- **Return Value:** Data frame with `DOCID`, `n_bikes`, `n_due`, `overdue_hours`, `total_ride_hours`.

#### `dispatch_recommendation(data, service_interval_h, threshold_min = 90, ...)`
- **Purpose:** Master operational function that bundles `stuck_alerts`, `service_due`, and `stations` into a single unified list.

