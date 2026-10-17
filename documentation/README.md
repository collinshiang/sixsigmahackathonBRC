# BikeSmart Documentation Portal

> **Current demonstration:** BikeSmart retains R-package exports and occupancy-based return discounts (20% below 25% occupancy, 10% from 25% to below 50%, otherwise 0%). All bike activity, station capacities and zoning are synthetic; real locations do not imply measured ridership or verified land use. Rider results use a saved reference instant, not a live feed.

Welcome to the comprehensive documentation suite for **BikeSmart**, developed by the **Big Red Crew** for the **Cornell Six Sigma Hackathon (October 2026)**.

Meet the team in [Contributors](CONTRIBUTORS.md), with two-sentence biographies, public profile sources, and team-supplied headshots. The rider documentation page also includes the contributor cards.

---

## 📑 Documentation Index

| Document | Purpose & Key Contents |
|---|---|
| **[1. Project Purpose & Users](01_PROJECT_PURPOSE_AND_USERS.md)** | Challenge prompt description, tool mission, target personas (riders, van crew, operations managers), and use cases. |
| **[2. Tool Components & Functions](02_TOOL_COMPONENTS_AND_FUNCTIONS.md)** | Deep-dive into all 4 core analytic modules, complete function-by-function reference, signatures, inputs, outputs, and formulas. |
| **[3. City Onboarding & Requirements](03_CITY_ONBOARDING_AND_INPUT_REQUIREMENTS.md)** | How to apply BikeSmart to any city or dock network, required data schemas, coordinate systems, and validation checks. |
| **[4. Test Datasets & Demonstrations](04_TEST_DATASETS_AND_DEMONSTRATIONS.md)** | Overview of the 3 test datasets (Jersey City, Milwaukee, Tampa), codebook, and demonstrations of quality control in action. |
| **[5. Statistical Foundations & Formulas](05_STATISTICAL_FOUNDATIONS_AND_FORMULAS.md)** | Mathematical theory, proofs, Montgomery SQC control chart derivations, Fraser SIGMA reliability modeling, and Poisson flow summation. |
| **[6. Judging Rubric Alignment](06_JUDGING_RUBRIC_ALIGNMENT.md)** | Comprehensive 100-point rubric breakdown demonstrating compliance with every scoring criterion. |

---

## 🚀 Quick Start for Judges & Developers

### Load the R Package
```r
# From repository root
devtools::load_all("bikesmart")
```

### Run All Verification Tests
```bash
Rscript bikesmart/tests/test_all.R
```

All 5 test suites (known-answer hand calculations, edge cases, and degenerate inputs) pass with zero errors.

### 🔑 Demo Maintenance Sign-In Credentials
To inspect the maintenance workspace (fleet replay monitor, service log, dispatch priorities, in-transit alerts, quality P-charts, and reliability calculator):
- **Email / Username:** `maintenance@cornell.edu`
- **Password:** `123`

These demo credentials can be used directly on the live deployed web application or locally.

