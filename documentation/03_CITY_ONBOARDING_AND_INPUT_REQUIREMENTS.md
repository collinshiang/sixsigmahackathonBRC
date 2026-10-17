# 03. Applying BikeSmart to Another City: Data Requirements & Onboarding Guide

> **Big Red Crew — BikeSmart Toolkit**

This guide outlines the specifications, required data schemas, and validation protocols necessary to deploy **BikeSmart** to any new municipality or commercial bike-share system.

---

## 1. Required System Inputs

To apply BikeSmart to a new city, the transit authority or fleet operator supplies standard network metadata and historical logs:

```
+------------------------------------------------------------------------------------------------+
|                                    CITY INPUT ARCHITECTURE                                     |
+--------------------------+----------------------------+----------------------------------------+
|       Data Asset         |          Format            |                Purpose                 |
+--------------------------+----------------------------+----------------------------------------+
| 1. Station Registry      | stations.csv               | Dock names, coordinates, capacities    |
| 2. Pairwise Distances    | distances.csv              | Shortest bicycle road network paths    |
| 3. Historical Movements  | 5-min snapshots (or trips) | Establishes typical weekly flow rates  |
| 4. System Configuration  | Timezone, service interval | Day boundaries, preventive limit       |
+--------------------------+----------------------------+----------------------------------------+
```

### Table 1: Input Requirements Breakdown

| Information | Purpose in BikeSmart | Recommended Source |
|---|---|---|
| **Dock IDs & Coordinates** | Station identification, distance calculation, map rendering. | Operator GBFS feed (`station_information.json`). |
| **Operational Capacity** | Determines dock boundaries and full-station lockout conditions. | Operator infrastructure register (`capacity`). |
| **Live Bike Inventory** | Baseline inventory ($B_{\text{live}}$) at the moment of prediction. | Operator GBFS feed (`station_status.json`). |
| **Historical Activity** | Computes typical weekly net arrival rates $\Delta B(t)$. | 5-minute snapshot logs or trip checkout/checkin logs. |
| **Bicycle Road Distances** | Calculates travel time and distance ranking for candidates. | OpenStreetMap (OSM) routing graph or distance matrix. |
| **City Timezone** | Aligns diurnal commute patterns and daylight savings time. | Standard IANA name (e.g. `America/New_York`, `America/Chicago`). |
| **Starting Ride Hours** | Prevents artificial maintenance synchronization waves. | Fleet service register (`service_log.csv`) or simulated offset. |

---

## 2. Standardized File Schemas

### 1. `stations.csv` (Station Registry)
```csv
station_id,dockID,lat,lon,capacity
JC001,Exchange Place,40.7163,-74.0328,30
JC002,Grove St PATH,40.7195,-74.0431,30
```
- `station_id`: Unique character identifier.
- `dockID`: Published display name or intersection name (matches movement log `DOCID`).
- `lat`, `lon`: WGS84 decimal degrees.
- `capacity`: Total operational docks at the station.

### 2. `distances.csv` (Pairwise Road Distance Matrix)
```csv
dockID1,dockID2,distance
Exchange Place,Exchange Place,0.0
Exchange Place,Grove St PATH,0.85
```
- For $N$ docks, contains $N^2$ ordered pairs.
- Self-distances are $0.0$.
- Directional asymmetry is preserved (e.g., one-way street networks).
- Units must be strictly in **miles** (or consistently converted).

### 3. Historical Movement Snapshots (`movement.csv` or `.rds`)
```csv
BIKEID,DOCID,time
JC-B0001,Exchange Place,2026-09-16T08:00:00-0400
JC-B0002,0,2026-09-16T08:00:00-0400
```
- `BIKEID`: Persistent unique bike identifier.
- `DOCID`: Dock name where docked, or the character `"0"` while away in transit.
- `time`: ISO-8601 string with UTC offset (or POSIXct). Exactly one observation per bike every 5 minutes.

### 4. `service_log.csv` (Optional Maintenance History)
```csv
BIKEID,service_time
JC-B0001,2026-09-20T14:30:00-0400
```
- Restarts the bike's ride-hour counter after maintenance.

---

## 3. Step-by-Step City Onboarding Workflow

Deploying BikeSmart to a new city takes five straightforward steps:

```
+-------------------------------------------------------------------------------------------+
|                                CITY ONBOARDING PIPELINE                                   |
+-------------------------------------------------------------------------------------------+
|                                                                                           |
|  [STEP 1] Ingest Station Metadata & Validate Coordinates                                  |
|           - Confirm distinct IDs, valid WGS84 ranges, and positive capacities.             |
|                                                                                           |
|  [STEP 2] Build Road Network Matrix                                                       |
|           - Compute bicycle shortest paths across OSM ways; verify all pairs connected.   |
|                                                                                           |
|  [STEP 3] Compute Typical-Week Net Docking Rates                                          |
|           - Run `compute_dock_rates(history, bin_minutes = 5, tz = city_tz)`.             |
|                                                                                           |
|  [STEP 4] Establish Fleet Maintenance Baseline                                            |
|           - Set `service_interval_h` based on operator manufacturer specifications.      |
|           - Generate initial offset with `simulate_start_hours()` or load `service_log`.   |
|                                                                                           |
|  [STEP 5] Deploy Predictive Rebalancing & Quality Control API/UI                          |
|           - Point front-end / dispatch console to the newly calculated rate tables.       |
|                                                                                           |
+-------------------------------------------------------------------------------------------+
```

---

## 4. Verification & Data Quality Checks

Before putting a new city into service, run the following automated integrity checks:

1. **Unique Key Verification:** Ensure no duplicate `BIKEID`/`time` pairs exist in the movement log, and no duplicate station names exist.
2. **Coordinate & Distance Bounds:** Ensure road distances are strictly non-negative, finite, and triangle inequalities hold where bidirectional routing exists.
3. **Weekly Slot Completeness:** The historical observation window must cover all 2,016 weekly slots to ensure `predict_dock()` can evaluate any future arrival time.
4. **Timezone Offset Integrity:** Ensure timestamps retain local daylight saving rules without silent truncations.

