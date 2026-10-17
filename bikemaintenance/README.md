# Big Red Crew: maintenance pieces (Vedant)

Folders mirror the repo, so you can copy them straight in:

- `app/`: qc.R (van dispatch + stuck-bike alert), pchart.R (P chart), failure_factor.R
- `tests/`: one test file per R file; run `Rscript -e "testthat::test_dir('tests')"` from the repo root
- `data/`: start_hours_jersey_city2.csv (SIMULATED starting ride hours, 0-60 h, seed 42)
- `docs/`: a README per R file, TESTING.md (start here), DATA_TEAM_NOTES.md
- `figures/`: pchart_jersey_city2_60h.png (simulated start hours; made in Python mirroring pchart.R)

Service limit: 60 ride hours. Nothing has been run in R yet; follow docs/TESTING.md first.
The old van dispatch chart is left out on purpose: it was made at 5 h with a made-up service log.
