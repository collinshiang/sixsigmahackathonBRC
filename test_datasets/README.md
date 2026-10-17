# Test Datasets for BikeSmart

> **Big Red Crew — Cornell Six Sigma Hackathon (October 2026)**

This directory packages the standardized test datasets for **BikeSmart**, providing ready-to-use inputs for demonstration, verification, and evaluation.

---

## 1. How These Datasets Satisfy Submission Requirements

The Six Sigma Hackathon judging rubric specifies:
- **Test Datasets (5 pts):** 2–3 accurate, working test datasets.
- **Dataset Explainers (5 pts):** A codebook and README describing what each file and variable means, and background information for collecting this data.
- **Demonstration (10 pts):** Clear demonstration of the tool using test datasets.

This directory satisfies all requirements:
1. **Three Complete Urban Networks:** Includes full metadata, distance graphs, and zoning for **Jersey City (NJ)**, **Milwaukee (WI)**, and **Tampa (FL)**.
2. **Field-Realistic Data Structure:** Real station coordinates from public GBFS feeds, road distances derived from actual OpenStreetMap bicycle networks, and diurnal commuting flow patterns.
3. **Comprehensive Codebook & Explainers:** Every variable, data type, coordinate system, and unit is documented in [`CODEBOOK.md`](CODEBOOK.md).

---

## 2. Alignment with Tool Input Requirements

As detailed in [`documentation/03_CITY_ONBOARDING_AND_INPUT_REQUIREMENTS.md`](../documentation/03_CITY_ONBOARDING_AND_INPUT_REQUIREMENTS.md), BikeSmart requires four core data assets:

| Required Input Asset | Provided File in `test_datasets/` | Purpose in Tool |
|---|---|---|
| **Station Registry** | `<city>/stations.csv` | Dock coordinates (`lat`, `lon`), capacity, display names. |
| **Road Network Distances** | `<city>/distances.csv` | Shortest path distances on bicycle-accessible roads. |
| **Land-Use Classification** | `<city>/zoning.csv` | Explanatory demand signal (`residential`, `office`, `retail`). |
| **Initial Usage Offsets** | `jersey_city/start_hours_jersey_city2.csv` | Staggered starting ride hours preventing artificial failure waves. |
| **User Locations & Routes** | `optimizer/user_locations.csv`, `user_dock_distances.csv` | Sourced starting points for rider recommendations. |
| **Continuous Movements** | `data/<city>.csv.gz` / `data/<city>.rds` | 30-day 5-minute snapshot logs for rate integration. |

> **Note on Large Movement Files:** To keep Git clone sizes reasonable and avoid duplicating multi-gigabyte files, the 30-day movement logs (3.5M rows per city) reside in the top-level `data/` directory (`data/jersey_city.rds`, `data/milwaukee.rds`, `data/tampa.rds`).

---

## 3. Directory Layout

```
test_datasets/
├── README.md                          # This file: purpose and requirements overview
├── CODEBOOK.md                        # Full variable definitions and units
├── jersey_city/
│   ├── stations.csv                   # 27 Citi Bike stations in JC District
│   ├── distances.csv                  # 729 pairwise bicycle road distances (miles)
│   ├── zoning.csv                     # 9 residential, 9 office, 9 retail stations
│   └── start_hours_jersey_city2.csv   # Staggered 0-60 h initial ride hours (seed 42)
├── milwaukee/
│   ├── stations.csv                   # 27 Bublr stations in downtown Milwaukee
│   ├── distances.csv                  # 729 pairwise road network distances (miles)
│   └── zoning.csv                     # Functional zoning lookup
├── tampa/
│   ├── stations.csv                   # 27 sourced intersection nodes in downtown Tampa
│   ├── distances.csv                  # 729 pairwise network distances (miles)
│   └── zoning.csv                     # Functional zoning lookup
└── optimizer/
    ├── user_locations.csv             # 30 real-world sourced starting locations (10/city)
    └── user_dock_distances.csv        # 1,620 pre-computed walking and cycling road routes
```

---

## 4. Quick Testing Instructions

You can load and verify these test datasets in R immediately:

```r
library(bikesmart)

# Load test datasets for Jersey City
jc_stations  <- read.csv("test_datasets/jersey_city/stations.csv")
jc_distances <- read.csv("test_datasets/jersey_city/distances.csv")
jc_zoning    <- read.csv("test_datasets/jersey_city/zoning.csv")
jc_sh        <- read.csv("test_datasets/jersey_city/start_hours_jersey_city2.csv")

cat("Loaded Jersey City test dataset successfully:\n")
cat(" - Stations:", nrow(jc_stations), "\n")
cat(" - Road Distances:", nrow(jc_distances), "\n")
cat(" - Zoning assignments:", nrow(jc_zoning), "\n")
cat(" - Starting Hours:", nrow(jc_sh), "\n")
```

