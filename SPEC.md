# SPEC: Six Sigma Hackathon Team Project (Big Red Crew)

What our tool IS. This document defines the scope, personas, inputs, statistics, and deliverables for the Cornell Six Sigma Hackathon.

---

## 1. Team and Prompt
- **Team name:** Big Red Crew
- **Track:** On campus (24 hours sprint).
- **Prompt we chose:** Urban Systems — Micro-Mobility Fleet Rebalancing & Quality Control
- **Our public repo:** https://github.com/collinshiang/sixsigmahackathonBRC

---

## 2. User and Use Case (Rubric: Scope 5, User and Use Case 5)
- **Primary User:** The bike-share rider/commuter seeking reliable pickup and return locations.
- **Secondary Users:** Fleet maintenance technicians, mobile van drivers, and system quality control managers.
- **Decision the tool helps them make, and when:** 
  - *For Riders:* Which station to pick up from and return to, choosing stations projected to have available bikes/slots upon arrival, with dynamic discount incentives for returning to low-inventory stations.
  - *For Maintenance Crew:* Which stations to visit first with the mobile repair van (ranked by number of docked due bikes and overdue hours), and immediate alerts for bikes stuck in transit past 90 minutes.
- **Why this matches the prompt:** Directly tackles micro-mobility urban transit reliability by eliminating dock stockout/overflow failures and optimizing fleet maintenance logistics through statistical process control and predictive inventory balancing.

---

## 3. Inputs (Rubric: Minimal Inputs 5)
Only what users can easily measure or already provide:

| User Role | Input | Type and Units | Source |
|---|---|---|---|
| **Rider** | Starting location / current coordinates | Character ID or Lat/Lon | User selection or device GPS |
| **Rider** | Trip intent (pickup vs return) | Character (`pickup` or `return`) | User toggle |
| **Fleet Manager** | Bike position snapshot log | CSV / RDS (`BIKEID`, `DOCID`, `time`) | Operator GBFS standard feed |
| **Operator** | Station registry & capacities | CSV (`dockID`, `lat`, `lon`, `capacity`) | Operator infrastructure register |
| **Operator** | Road network distances | CSV (`dockID1`, `dockID2`, `distance` miles) | OpenStreetMap routing network |
| **Operator** | Maintenance service interval | Numeric (hours, e.g. 60–70 h) | Manufacturer service specification |

---

## 4. The Statistics, and Why (Rubric: Valid QC Analysis 25)
- **Methods:**
  1. **Attribute Statistical Process Control (SPC) P-Chart:** Monitored daily defect proportion $p_i = d_i / n_i$ with weighted center line $\bar{p}$ and dynamic 3-sigma control limits ($UCL_i, LCL_i$) adjusted for variable daily active bikes ($n_i$), per Montgomery *Introduction to Statistical Quality Control*.
  2. **Multiplicative Fleet Usable Factor (Reliability):** Rolled Throughput Yield analogy calculating usable fleet proportion across independent defect modes: $\prod_{j=1}^k (1 - r_j)$.
  3. **Discrete Rate Integration & Arrival Projection:** Failure-function framework (*SIGMA* Ch. 8) integrating typical-week net docking rates over the rider's travel time to project arrival-time inventory.
- **Why it fits the use case:** Separates normal common-cause daily maintenance variation from special-cause defect spikes, scales inventory to true usable bikes, and prevents riders from walking to docks that will empty before they arrive.
- **Assumptions and checks:**
  - *Binomial subgroup distribution:* Evaluated daily across active bikes ($n_i$).
  - *Defect independence:* Evaluated with lower-bound sensitivity breakdown.
  - *Weekly cyclostationarity:* Validated across 2,016 weekly 5-minute slots covering all 7 days.
- **Known-answer checks:**
  - *P-chart:* 3 days of 100 bikes with 5, 10, 15 due yields $\bar{p} = 0.10$, $UCL = 0.19$, $LCL = 0.01$ (verified in `bikesmart/tests/testthat/test-pchart.R`).
  - *Failure factor:* 2% flat tire, 5% battery yields $0.98 \times 0.95 = 0.931$; 20 predicted bikes yields 18.62 usable (verified in `test-failure-factor.R`).
  - *Dock projection:* 1.5 miles at 3 mph = 30 min walking time; arrival 08:30 (verified in `test-dock-projection.R`).

---

## 5. Delivery (Rubric: Working Tool 25)
- **Stack:** 
  1. Modular CRAN-style R package (`bikesmart/`) containing all pure statistical functions, `.Rd` manual pages, automated test suites, and Posit Connect documentation deployment.
  2. Interactive React + Vite + Leaflet web application (`bikesmart-ui/`) with Node API server (`serve.mjs`), supporting real-time rider planning, street-routed fleet playback, and maintenance crew portal.
- **Contract & Verification:**
  - `bikesmart/testme.R` & `bikesmart/tests/test_all.R`: Runs full test suite in one command.
  - `bikesmart/deployme.R`: Deploys documentation to Posit Connect server.
  - `bikesmart-ui/`: Runs locally via `npm run dev` or `node server/serve.mjs` with Playwright browser verification.

---

## 6. Outputs
- **For Riders:** Distance-ranked eligible stations, arrival-time projected bike/space availability, 10%–20% rebalancing discount badges, and interactive map route.
- **For Maintenance Crew:** Station visit ranking table sorted by docked due bikes ($n_{due}$) and overdue hours, stuck-bike alerts (>90 min away), and interactive P-chart with red out-of-control alarm points.

---

## 7. Test Datasets and Codebook (Rubric: Demo 10, Datasets 5, Codebook 5)
- **Datasets in `data/`:**
  1. `jersey_city`: 27 Citi Bike stations, 405 bikes, 8,640 five-minute snapshots across 30 days; transit hub dynamics.
  2. `milwaukee`: 27 Bublr stations, 405 bikes, 8,640 five-minute snapshots; recreational lakefront and mixed zoning flows.
  3. `tampa`: 27 downtown intersection stations, 405 bikes, 8,640 five-minute snapshots; grid street network.
- **Maintenance Datasets:** `data/start_hours_jersey_city2.csv` (staggered 0–60 h baseline) and `data/service_log_jersey_city.csv` (405 service records).
- **Codebooks:** Detailed variable definitions, units, and coordinate systems in `data/README.md` and `data/CODEBOOK.md`.

---

## 8. Documentation and Reproducibility (Rubric: Docs 10, Public Repo 5)
- Central documentation portal in `documentation/` with 6 detailed guides covering purpose, components, onboarding, test datasets, statistical foundations, and rubric alignment.
- Public GitHub repository with clean history and zero hardcoded secrets.

---

## 9. Out of Scope
- Global real-time cellular GPS hardware trackers on individual bikes.
- Live credit card transaction processing.
- Multi-city cross-transit fare payment integration.
