# Statistical Concepts Behind the Dock Projection

How `dock_projection.R` and `data/optimizer/run_demo.R` map onto the course
textbook, [*SIGMA*](https://timothyfraser.com/sigma/contents.html) (Chapters 1–12).

## Summary

The projection follows the **failure-function framework from Chapter 8
(System Reliability)**, built with the **observed-function tools from Chapter 7
(Probability Functions)**. A typical-week bike count plays the role of a
cumulative function, the docking rate plays the role of its change per time
step, and a projection is the difference of the cumulative function between
two times.

It is *structurally* a PDF/CDF pair, but the output is an **expected count of
bikes**, not a probability (see [Limitations](#limitations-not-strictly-a-pdfcdf)).

## Core mapping: Chapter 8 failure functions

| Ch. 8 concept | Course formula | Our implementation |
|---|---|---|
| Cumulative function $F(t)$ | accumulated quantity up to time $t$ | `avg_docked`: typical bikes docked in each weekday × 5-minute slot |
| Change in failure function $f(t)$ | $\dfrac{F(t + \Delta t) - F(t)}{\Delta t}$ | `rate = (avg_docked - prev_docked) / bin_minutes`, with $\Delta t = 5$ min |
| Change over an interval | $F(t_2) - F(t_1)$, e.g. `fplane(5000) - fplane(600)` | `change = typical(arrive_min) - typical(now_min)` |
| Average Failure Rate | $AFR(t_1, t_2) = \dfrac{H(t_2) - H(t_1)}{t_2 - t_1}$ | `change / walk_min`: average net docking rate during the trip |
| Units | rescaling rates (e.g. %/K hours) | zone plot rescales bikes/min to bikes/hour |

### Why the projection integrates the rate correctly

Adding up each 5-minute rate times 5 minutes over the trip cancels every
intermediate slot, leaving the end minus the start:

$$
\sum_{t = t_1}^{t_2} \text{rate}_t \times \Delta t \;=\; \text{avg\_docked}(t_2) - \text{avg\_docked}(t_1)
$$

So

$$
\text{projected bikes} = \text{live bikes} + \big[\text{avg\_docked}(t_{arrive}) - \text{avg\_docked}(t_{now})\big],
$$

kept between 0 and dock capacity, and projected spaces = capacity − projected bikes.

## Chapter 7: Probability Functions

- **Observed functions with `approxfun()`.** The course builds
  `dobs <- obs %>% density() %>% tidy() %>% approxfun()`. `predict_dock()` uses
  the same idea: it turns the smoothed typical-week curve into a function with
  `approxfun()` and evaluates it at any time, including times between
  5-minute slots.
- **Integration.** The course gets a CDF from a PDF with `cumsum()` or
  `mosaicCalc::antiD()`. Our projection integrates the rate by differencing its
  running total, as shown above.

## Supporting concepts from other chapters

| Chapter | Concept | Where it appears |
|---|---|---|
| 4: Distributions & Descriptive Statistics | Size, location | Each "Monday 07:30" value is the mean (location) over `n_days` observations (size). The 30-minute smoothing is also an average. |
| 5: Functions | Functions with default inputs | `predict_dock()` and `optimize_docks()`, e.g. `smooth_min = 30`, `travel_speed_mph` defaults to 3 (walk to pick up) or 10 (ride to return). |
| 6: Probability | Conditional probability, total probability | Each rate is conditional on weekday and time of day. The typical week combines all observed days into one average. |
| 9: Statistical Process Control | Subgroups, x̄, moving range | Each weekday × slot is a subgroup of size `n_days`. `avg_docked` is its x̄. A moving range (`diff()`) on the 5-minute series would separate normal noise from real rushes. |
| 11: Design of Experiments | t-tests, ANOVA | The zone plot compares office, residential and retail visually. ANOVA could test whether rates differ by zone, and a t-test could compare e.g. Tuesday vs. Saturday at a given time. |
| 12: Using GitHub and AI | Version control | Team workflow for this repository. |

## Limitations: not strictly a PDF/CDF

- A CDF never decreases and ends at 1. `avg_docked` rises and falls and is
  measured in bikes. The structure (rate → running total → difference) is the
  same, but the output is an **expected value**, not a probability.
- `optimize_docks()` excludes a dock when `projected_bikes < 1` (or
  `projected_spaces < 1`). That is a rule about the average, not about the
  chance of finding a bike or a space.
- Each slot's average comes from only 4–5 days, and the spread across those
  days is not measured.

## Extensions within Chapters 1–12

1. **Probability of finding a bike (Ch. 4 and 7).** Treat the count at
   arrival as Poisson with $\lambda$ = `projected_bikes`:

   ```r
   p_at_least_one <- 1 - ppois(0, lambda = projected_bikes)
   ```

   At $\lambda = 1$, $P(\geq 1) \approx 0.63$, so the dock is empty about 37%
   of the time even though it passes the current rule. Alternatively, build an
   observed PDF from each slot's daily counts with
   `density() %>% tidy() %>% approxfun()`.

2. **Confidence intervals (Ch. 10).** Standard error of each slot's mean
   $= s / \sqrt{n_{days}}$. This gives a range around each projection. With
   4–5 days per slot, the range will be wide, which puts a number on the
   sparse-movement concern.

3. **Several recommended docks (Ch. 8, complement rule).** If
   $p_i$ is the chance dock $i$ has a bike, the chance that at least one of
   the recommended docks does is

   $$1 - \prod_i (1 - p_i),$$

   assuming the docks are independent.

## Chapter references

- [Ch. 4: Distributions and Descriptive Statistics](https://timothyfraser.com/sigma/chapters/distributions-and-descriptive-statistics-in-r.html)
- [Ch. 5: Functions](https://timothyfraser.com/sigma/chapters/functions-in-r.html)
- [Ch. 6: Probability](https://timothyfraser.com/sigma/chapters/probability-in-r.html)
- [Ch. 7: Probability Functions](https://timothyfraser.com/sigma/chapters/probability-functions-in-r.html)
- [Ch. 8: System Reliability](https://timothyfraser.com/sigma/chapters/system-reliability-in-r.html)
- [Ch. 9: Statistical Process Control](https://timothyfraser.com/sigma/chapters/statistical-process-control-in-r.html)
- [Ch. 10: Indices and Confidence Intervals for SPC](https://timothyfraser.com/sigma/chapters/indices-and-confidence-intervals-for-statistical-process-control-in-r.html)
- [Ch. 11: Design of Experiments](https://timothyfraser.com/sigma/chapters/design-of-experiments-in-r.html)
- [Ch. 12: Using GitHub and AI](https://timothyfraser.com/sigma/chapters/using-github-and-ai.html)
