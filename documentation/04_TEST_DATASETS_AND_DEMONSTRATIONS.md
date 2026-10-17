# 04. Test Datasets, Codebook & Quality Control Demonstrations

> **Big Red Crew — BikeSmart Toolkit**

This document describes the three accurate test datasets that accompany **BikeSmart**, their provenance, codebooks, and how they demonstrate every quality control feature in the package.

---

## 1. Overview of Test Datasets

To satisfy the hackathon rubric ("2–3 accurate, working test datasets demonstrating the tool"), the project provides complete data packages for three distinct urban networks:

```
+--------------------------------------------------------------------------------------------------+
|                                    TEST DATASETS OVERVIEW                                        |
+---------------+-----------+-----------+----------------+-----------------------------------------+
|     City      | Stations  |   Bikes   |    Timezone    |               Key Features              |
+---------------+-----------+-----------+----------------+-----------------------------------------+
| Jersey City   | 27 docks  | 405 bikes | America/NY     | Dense transit hub, heavy commuter rush  |
| Milwaukee     | 27 docks  | 405 bikes | America/Chicago| Lakefront recreation, mixed zoning flows|
| Tampa         | 27 docks  | 405 bikes | America/NY     | Grid street network, multi-modal routes |
+---------------+-----------+-----------+----------------+-----------------------------------------+
```

Each city contains:
- `<city>.csv.gz` & `<city>.rds`: 30-day 5-minute continuous bike movement snapshot logs (3,499,200 rows per city; 8,640 snapshots from Sept 16 through Oct 15, 2026).
- `stations/<city>.csv`: Station metadata lookup table with real geographic coordinates.
- `distances/<city>.csv`: Complete $27 \times 27 = 729$ pairwise bicycle road network distance matrix (miles).
- `zoning/<city>.csv`: Functional land use classification (residential, office, retail).
- `optimizer/`: Sourced user starting locations and pre-computed walking/cycling routes.

---

## 2. Complete Variable Codebooks

### A. Movement Snapshot Codebook (`BIKEID`, `DOCID`, `time`)
| Variable | Data Type | Description |
|---|---|---|
| `BIKEID` | Character | Unique persistent identifier for each bike in the fleet (e.g. `JC-B0001`, `MKE-B0012`). |
| `DOCID` | Character | Station identifier where the bike is docked, or `"0"` while away from docks in transit. |
| `time` | POSIXct / ISO String | Exact timestamp of observation at 5-minute sampling intervals. Includes UTC offset. |

### B. Station Registry Codebook (`station_id`, `dockID`, `lat`, `lon`, `capacity`)
| Variable | Data Type | Description |
|---|---|---|
| `station_id` | Character | Official GBFS / OSM station identifier. |
| `dockID` | Character | Published station display name (matches `DOCID` in movement log). |
| `lat`, `lon` | Numeric | Geographic coordinates in WGS84 decimal degrees. |
| `capacity` | Integer | Total docking slots at the station (default baseline: 30 slots). |

### C. Distance Matrix Codebook (`dockID1`, `dockID2`, `distance`)
| Variable | Data Type | Description |
|---|---|---|
| `dockID1` | Character | Origin station name. |
| `dockID2` | Character | Destination station name. |
| `distance` | Numeric | Shortest road network distance in miles via bicycle-accessible ways. |

### D. Zoning Codebook (`dockID`, `zone`)
| Variable | Data Type | Description |
|---|---|---|
| `dockID` | Character | Station name. |
| `zone` | Character | Land use type: `residential`, `office`, or `retail`. |

---

## 3. How the Test Datasets Demonstrate Quality Control

The test datasets are specifically engineered to demonstrate the four statistical quality control principles of BikeSmart:

### 1. Commuter Tide & Zone Imbalance Demonstration
- **Observation:** In the morning (07:00–09:00), net docking rates at residential docks drop negative (heavy departures), while office docks show sharp positive rates (+15 to +20 bikes/hr).
- **Tool Demonstration:** 
  - `compute_dock_rates()` accurately captures the diurnal cycle.
  - `predict_dock()` prevents riders from walking to a residential dock that will be depleted by the time they arrive.
  - `return_discount()` triggers a 20% discount for riders returning bikes to depleted residential stations during evening return flows.

### 2. P-Chart In-Control vs. Out-of-Control Demonstration
- **Common-Cause Stability:** With realistic staggered starting hours (`start_hours_jersey_city2.csv`, uniformly distributed 0–60 h), daily maintenance rates hover steadily around $\bar{p} = 0.133$ with zero points exceeding the 3-sigma limits ($LCL \approx 0.082, UCL \approx 0.183$).
- **Special-Cause Detection:** If a sudden fleet-wide defect event occurs (e.g. vandalism or severe storm damage causing 30+ bikes to fail in one day), `p_chart()` immediately triggers `out_of_control = TRUE` and `plot_p_chart()` paints the day in red.

### 3. Maintenance Logistics & Van Stop Optimization Demonstration
- **Observation:** Across 27 stations, docked bikes needing service are unevenly distributed: certain high-traffic hubs accumulate 4–6 overdue bikes, while outlying docks have 0.
- **Tool Demonstration:** `station_service_priority()` ranks hubs at the top of the queue, allowing the maintenance van to service 80% of overdue bikes in just 3 station stops.

### 4. Anomaly Detection for Stuck / Stolen Bikes
- **Observation:** Normal trip durations have a median of 15 minutes and a 99th percentile of 80–85 minutes.
- **Tool Demonstration:** `maintenance_alerts(threshold_min = 90)` isolates bikes still undocked past 90 minutes, allowing operators to immediately dispatch recovery crews.

