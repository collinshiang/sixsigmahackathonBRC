# Test Datasets Codebook

> **Big Red Crew — Cornell Six Sigma Hackathon**

This codebook defines every table, column, data type, unit of measurement, and collection background for the test datasets included with **BikeSmart**.

---

## 1. Station Registry: `stations.csv`

Present in `jersey_city/`, `milwaukee/`, and `tampa/`.

| Column | Type | Units / Format | Description |
|---|---|---|---|
| `station_id` | character | alphanumeric | Official system identifier from GBFS feed (or OSM node ID in Tampa). |
| `dockID` | character | string | Published station name. Trailing whitespace in original feed is preserved to match joins. |
| `lat` | numeric | WGS84 decimal degrees | Latitude coordinate of the station. |
| `lon` | numeric | WGS84 decimal degrees | Longitude coordinate of the station. |
| `capacity` | integer | slots | Total physical docking slots installed at the station (baseline: 30). |

**Collection Background:** Sourced from real municipal GBFS (General Bikeshare Feed Specification) feeds:
- Jersey City: Citi Bike station information (`https://gbfs.lyft.com/gbfs/2.3/bkn/en/station_information.json`).
- Milwaukee: Bublr Bikes feed (`https://gbfs.bcycle.com/1/bcycle_bublr/station_information.json`).
- Tampa: OpenStreetMap road junction nodes in downtown Tampa.

---

## 2. Road Network Distances: `distances.csv`

Present in `jersey_city/`, `milwaukee/`, and `tampa/`. 729 rows per file ($27 \times 27$ dock matrix).

| Column | Type | Units / Format | Description |
|---|---|---|---|
| `dockID1` | character | string | Origin station name. |
| `dockID2` | character | string | Destination station name. |
| `distance` | numeric | miles | Shortest bicycle-legal path distance computed on the OpenStreetMap road graph. |

**Collection Background:** Generated using Dijkstra's shortest path algorithm over an OpenStreetMap bicycle routing graph (respecting one-way streets, bicycle lanes, and multi-use paths). Self-distances (`dockID1 == dockID2`) are exactly 0.0 miles.

---

## 3. Zoning Classification: `zoning.csv`

Present in `jersey_city/`, `milwaukee/`, and `tampa/`. 27 rows per file.

| Column | Type | Units / Format | Description |
|---|---|---|---|
| `dockID` | character | string | Station name matching `stations.csv`. |
| `zone` | character | string | Functional land use: `residential`, `office`, or `retail`. |

**Collection Background:** Synthetic assignments to equal residential, office and retail groups; not verified real land use. Used to model diurnal commuter movements (e.g., net morning departures from residential docks toward office docks).

---

## 4. Starting Ride Hours: `start_hours_jersey_city2.csv`

Present in `jersey_city/`. 405 rows.

| Column | Type | Units / Format | Description |
|---|---|---|---|
| `BIKEID` | character | string | Persistent bike identifier (`JERSEY_CITY-B0001` through `B0405`). |
| `start_hours` | numeric | hours | Ride hours accrued prior to the start of observation (random uniform $0$ to $60$ h, seed 42). |

**Collection Background:** Represents the maintenance status of a fleet in steady state. Without staggered initial hours, a simulated fleet would all come due for service simultaneously in an artificial failure wave.

---

## 5. Optimizer Locations & Routes: `optimizer/`

### A. `user_locations.csv` (30 rows; 10 per city)
| Column | Type | Units / Format | Description |
|---|---|---|---|
| `city` | character | string | City name (`jersey_city`, `milwaukee`, `tampa`). |
| `location_id` | character | string | Unique origin ID (e.g. `JC-U01`, `MKE-U05`). |
| `name` | character | string | Real sourced address / landmark name. |
| `lat`, `lon` | numeric | WGS84 decimal degrees | Coordinates of the user origin. |

### B. `user_dock_distances.csv` (1,620 rows)
| Column | Type | Units / Format | Description |
|---|---|---|---|
| `location_id` | character | string | Sourced user origin ID. |
| `mode` | character | `pickup` or `return` | Travel mode (`pickup` = walking; `return` = cycling). |
| `dockID` | character | string | Destination station name. |
| `distance` | numeric | miles | Road distance from user origin to the dock. |

---

## 6. Continuous Movement Snapshots (Top-level `data/`)

### Movement Files: `jersey_city.rds`, `milwaukee.rds`, `tampa.rds`
3,499,200 rows per file (405 bikes $\times$ 8,640 five-minute snapshots across 30 days).

| Column | Type | Units / Format | Description |
|---|---|---|---|
| `BIKEID` | character | string | Unique bike identifier. |
| `DOCID` | character | string | Dock name where the bike is currently docked, or `"0"` if in transit. |
| `time` | POSIXct | timezone-aware timestamp | Observation instant (5-minute intervals, Sept 16 – Oct 15, 2026). |

