# 01. Project Purpose, Prompt & Intended Users

> **Current demonstration:** BikeSmart retains R-package exports and occupancy-based return discounts (20% below 25% occupancy, 10% from 25% to below 50%, otherwise 0%). All bike activity, station capacities and zoning are synthetic; real locations do not imply measured ridership or verified land use. Rider results use a saved reference instant, not a live feed.

> **Cornell Six Sigma Hackathon — Big Red Crew (October 2026)**  
> **Track:** On-Campus 24-Hour Sprint  
> **Challenge Prompt:** Urban Systems — Micro-Mobility Fleet Rebalancing & Quality Control

---

## 1. Executive Summary & Challenge Statement

Micro-mobility bike-share systems are a vital component of sustainable urban transit. However, bike-share operations face two continuous operational bottlenecks that degrade service quality and increase operating costs:
1. **Asymmetric Flow Imbalance (Spatial & Temporal):** Commuters ride bikes en masse from residential zones into commercial office districts in the morning, leaving residential docks completely empty (stockout) and downtown docks overflowing (full capacity blockouts).
2. **Fleet Wear, Mechanical Failures & Maintenance Backlog:** Bikes endure constant mechanical wear, flat tires, brake issues, and battery drainage. Without proactive statistical process control, fleets experience sudden failure cascades, lost/stolen bikes, and inefficient maintenance van routing where technicians visit stations with few defective bikes while severely overdue bikes remain stranded.

### The Challenge Prompt Followed
Under the **Urban Systems** prompt, our goal is to design and build an integrated quality control and predictive decision system that:
- Provides valid statistical quality control and reliability methods in R to monitor, detect, and mitigate fleet issues.
- Minimizes user burden by relying on minimal, easily obtainable inputs.
- Is demonstrated on 2–3 accurate test datasets.
- Is fully reproducible and packaged for deployment to any city.

---

## 2. Intended Users & Personas

BikeSmart is engineered with distinct user personas in mind, providing targeted value for both consumer-facing and operational roles:

```
+-----------------------------------------------------------------------------------+
|                                  BIKESMART USERS                                  |
+-----------------------------------------+-----------------------------------------+
|             Rider / Commuter            |         Fleet Maintenance Van Crew      |
| "Where can I reliably get/return a bike | "Which stations have the most due bikes |
|  without facing an empty or full dock?" |  so my visit services maximum bikes?"   |
+-----------------------------------------+-----------------------------------------+
|            Operations Manager           |               City Planner              |
| "Is our fleet failure rate in control,  | "How can we onboard new dock locations  |
|  or are special causes spiking defects?"|  and optimize network topology?"        |
+-----------------------------------------+-----------------------------------------+
```

### Persona 1: The Rider / Commuter
- **Profile:** Urban commuter or tourist traveling from a current location to a destination.
- **Pain Points:** 
  - Walking 10 minutes to a dock that showed 1 bike on an app, only for that bike to be taken before arrival.
  - Arriving at a destination dock that is 100% full, forcing a frantic search for nearby empty slots while the rental meter runs.
- **How BikeSmart Helps:** 
  - Computes **arrival-time inventory projections** rather than static snapshot counts.
  - Automatically filters candidate stations to those projected to have $\ge 1$ usable bike (for pickup) or $\ge 1$ free slot (for drop-off).
  - Rewards riders with **rebalancing discounts** (up to 20% off) for returning bikes to under-utilized stations, using dynamic pricing to encourage crowdsourced rebalancing.

### Persona 2: Fleet Maintenance Technicians & Mobile Van Drivers
- **Profile:** Mobile field technicians driving service vans tasked with inspecting, repairing, and replacing bikes across the city.
- **Pain Points:**
  - Inefficient routes: driving across town to a dock to repair a single bike, while another dock with 6 overdue bikes is neglected.
  - Stolen or abandoned bikes remaining undetected for days.
- **How BikeSmart Helps:**
  - **Ranked Station Service Priority:** Sorts stations by the number of docked bikes currently due for maintenance ($n_{due}$) and cumulative overdue hours.
  - **Recorded In-Transit Alerts:** Detects bikes that have been away from any dock for $>90$ minutes, marking long trips for review without proving theft, damage or abandonment.

> **Demo Access for Evaluators:** The maintenance portal for Personas 2 & 3 is accessible in the UI using demo credentials: **Email:** `maintenance@cornell.edu` | **Password:** `123`.

### Persona 3: System Operations & Quality Control Manager
- **Profile:** Fleet director monitoring fleet health, maintenance contracts, and safety standards.
- **Pain Points:**
  - Lack of visibility into whether maintenance defect rates are normal common-cause noise or abnormal special-cause spikes.
  - Overestimating usable fleet capacity because defective bikes remain docked and counted as "available".
- **How BikeSmart Helps:**
  - **Attribute Statistical Process Control (SPC) P-Charts:** Tracks daily proportion of bikes crossing maintenance thresholds against dynamic 3-sigma control limits ($UCL, LCL$), highlighting out-of-control operational surges.
  - **Multiplicative Failure Factor Modeling:** Quantifies the net proportion of rentable bikes across multiple independent defect types (flat tires, battery drain, mechanical failure) using Rolled Throughput Yield principles.

### Persona 4: Municipal Transport Planner / New City Operator
- **Profile:** Urban transit authority seeking to deploy bike-share infrastructure in a new municipality.
- **How BikeSmart Helps:**
  - Documents operator setup with station metadata, capacities, inventory history, road distances and timezone; this is not an automatic city-import interface.

---

## 3. Clear, Minimal User Input Requirements

To satisfy the Six Sigma Hackathon rubric ("Requires a minimal, reasonable number of inputs or requirements from the user/customer"):

1. **For Riders:**
   - Only inputs: a saved starting location, destination, and whether they want to pick up or return a bike.
   - No complex statistical configurations required. Walking speeds (3 mph) and cycling speeds (10 mph) use illustrative defaults.
2. **For Van Crews:**
   - One command: `dispatch_recommendation(data, service_interval_h = 60)`.
   - Returns a structured queue of where to drive and which bikes to service.
3. **For Fleet Managers:**
   - Standard 3-column bike position logs (`BIKEID`, `DOCID`, `time`).
   - These require operator bike-level records; public GBFS station-count feeds alone cannot reconstruct persistent individual-bike histories.

