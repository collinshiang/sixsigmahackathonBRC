# BikeSmart Documentation Portal

Welcome to the comprehensive documentation suite for **BikeSmart**, developed by the **Big Red Crew** for the **Cornell Six Sigma Hackathon (October 2026)**.

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
devtools::load_all("deliverables/bikesmart")
```

### Run All Verification Tests
```bash
Rscript deliverables/bikesmart/tests/test_all.R
```

All 5 test suites (known-answer hand calculations, edge cases, and degenerate inputs) pass with zero errors.

