# failure_factor.R — Failure factor

Separate from `qc.R` and `pchart.R`. It answers: **of the bikes we predict will
be at a dock, how many will actually be usable?**

## How it works
Give it the share of bikes with each defect. It multiplies together the share
*without* each defect:

```
factor = (1 − flat tire rate) × (1 − battery rate) × (1 − crash rate) × ...
```

Example: flat tires 2%, weak batteries 5% → 0.98 × 0.95 = **0.931**. If 20 bikes
are predicted at a dock, about 20 × 0.931 = **18.6** are usable.

## Functions
| Function | Returns |
|---|---|
| `failure_factor(rates)` | One number, 0 to 1: the usable share. |
| `failure_breakdown(rates)` | One row per defect, worst first: `rate`, `survive` (1 − rate), `cumulative_factor`. Shows which defect costs the most. |
| `apply_failure_factor(predicted, rates)` | `predicted × factor`, e.g. predicted bikes per dock → usable bikes. |

`rates` is a named vector of shares (not percents), e.g.
`c(flat_tire = 0.02, battery = 0.05, crash = 0.01)`. Add or remove defect types freely.

## Where the rates come from
**The team chooses them.** The bike log has no defect information, so these
are inputs, not something the code estimates. Cite a source for each in the
main README (an operator's maintenance report, a published study), or say
plainly they're assumed.

## Assumption
Defects are treated as independent. If they overlap (a crash often also
causes a flat), the factor slightly understates the usable share.

## Integration

Base R only, and it never reads the bike log. It plugs in at the end of the
dock-prediction step: `preds$usable <- apply_failure_factor(preds$predicted_bikes, rates)`.
Define `rates` once (a config list or the main README) and have every piece
read it from there, so the dashboard, predictions and slides all use the same
numbers. `failure_breakdown(rates)` gives a ready-made table for showing which
defect costs the most. Since the rates are team inputs, the app should show
where they came from.

## Tests
`test-failure_factor.R` checks the hand calculation (0.931, then 0.92169 with
a 1% crash rate, and 18.62 usable out of 20), plus: no defects → 1, any rate
of 1 → 0, a single defect → 1 − rate, and errors for percents entered as whole
numbers, missing names, or NA. Not yet run in R.
