# 05. Statistical Foundations & Mathematical Derivations

> **Current demonstration:** BikeSmart retains R-package exports and occupancy-based return discounts (20% below 25% occupancy, 10% from 25% to below 50%, otherwise 0%). All bike activity, station capacities and zoning are synthetic; real locations do not imply measured ridership or verified land use. Rider results use a saved reference instant, not a live feed.

> **Big Red Crew — BikeSmart Toolkit**  
> Mapping directly to course textbook *SIGMA* (Fraser) and *Statistical Quality Control* (Montgomery).

---

## 1. Statistical Process Control: Binomial Attribute P-Chart

### Theoretical Framework & Model
The maintenance rate of the bike fleet is monitored using an attribute control chart for fraction nonconforming (P-chart), following standard Six Sigma statistical process control principles (Montgomery, *Introduction to Statistical Quality Control*).

Let day $i$ have $n_i$ observed active bikes, where each bike independently has an underlying probability $p$ of requiring maintenance. The count of bikes crossing the maintenance threshold, $d_i$, follows a Binomial distribution:

$$d_i \sim \text{Binomial}(n_i, p)$$

The observed sample fraction nonconforming on day $i$ is:

$$p_i = \frac{d_i}{n_i}$$

### Parameter Estimation & Center Line
When the true process fraction nonconforming $p$ is unknown, it is estimated by the weighted average of subgroup proportions across $m$ preliminary subgroups:

$$\bar{p} = \frac{\sum_{i=1}^m d_i}{\sum_{i=1}^m n_i}$$

This estimator weights days by their subgroup sample size $n_i$, representing the minimum variance unbiased estimator (MVUE).

### Dynamic 3-Sigma Control Limits for Variable Subgroup Sizes
Because the number of active bikes observed daily $n_i$ can vary due to weather or weekend riding patterns, the standard error of $p_i$ varies by day:

$$\sigma_{p_i} = \sqrt{\frac{\bar{p}(1 - \bar{p})}{n_i}}$$

The 3-sigma upper and lower control limits are calculated per subgroup:

$$UCL_i = \min\left(1, \; \bar{p} + 3 \sqrt{\frac{\bar{p}(1 - \bar{p})}{n_i}}\right)$$

$$LCL_i = \max\left(0, \; \bar{p} - 3 \sqrt{\frac{\bar{p}(1 - \bar{p})}{n_i}}\right)$$

### Decision Rule
A process observation $p_i$ is flagged as **out-of-control** (special-cause variation) if:

$$p_i > UCL_i \quad \text{or} \quad p_i < LCL_i$$

---

## 2. System Reliability & Failure Function Integration

### Failure-Function Analogy (*SIGMA* Chapter 8)
In system reliability engineering, cumulative failure functions $F(t)$ and hazard/failure rates $f(t)$ describe the accumulation of events over time. In BikeSmart:
- The typical-week count of docked bikes plays the structural role of a cumulative function $F(t)$.
- The net docking rate plays the role of the marginal rate $f(t) = \frac{F(t + \Delta t) - F(t)}{\Delta t}$.
- Dock projection over a travel interval $[t_{\text{now}}, t_{\text{arrive}}]$ is obtained by integrating the net arrival rate over time:

$$\Delta B = \int_{t_{\text{now}}}^{t_{\text{arrive}}} r(t) \, dt$$

### Discrete Telescoping Sum Proof
In our discrete 5-minute sampling scheme with $\Delta t = 5$ minutes:

$$\sum_{k = t_{\text{now}}}^{t_{\text{arrive}}} \text{rate}_k \times \Delta t = \sum_{k = t_{\text{now}}}^{t_{\text{arrive}}} \left(\frac{\bar{B}_{k} - \bar{B}_{k-1}}{\Delta t}\right) \times \Delta t = \bar{B}(t_{\text{arrive}}) - \bar{B}(t_{\text{now}})$$

Every intermediate term cancels out in a telescoping series, proving that evaluating the smoothed typical-week function at arrival and subtracting the value at departure exactly integrates net rate flows over the journey.

### Bounding and Clamp Conditions
Because docks cannot hold fewer than zero bikes or more than physical capacity $C$:

$$B_{\text{projected}} = \max\left(0, \; \min\left(C, \; B_{\text{live}} + \Delta B\right)\right)$$

$$\text{Spaces}_{\text{projected}} = C - B_{\text{projected}}$$

---

## 3. Rolled Throughput Survival (Fleet Failure Factor)

### Mathematical Formulation
In Six Sigma manufacturing, **Rolled Throughput Yield (RTY)** models the probability that a unit passes through $k$ successive independent process steps without defect:

$$\text{RTY} = \prod_{i=1}^k (1 - \text{defect\_rate}_i)$$

In BikeSmart, we adapt this framework to model fleet mechanical reliability. A docked bike is rentable only if it is free of all disabling defects (e.g. flat tires, dead batteries, faulty brakes, broken shifters). Assuming defects occur independently:

$$\text{failure\_factor} = \prod_{i=1}^k (1 - r_i)$$

Where $r_i$ is the observed or surveyed defect rate for category $i$.

### Independence Assumption
The product is a model under independent defect categories. Correlated defects
require joint information; do not present the independent product as a guaranteed
bound or as measured fleet usability. Defect shares are hypothetical or supplied
inputs, not estimates derived from the movement-only dataset.

---

## 4. Bivariate Poisson Arrival / Departure Availability

When modeling instantaneous queueing at a station over short horizons:
- Let departures be Poisson distributed with parameter $\lambda_{\text{out}}$.
- Let arrivals be Poisson distributed with parameter $\lambda_{\text{in}}$.

With starting inventory $b_0$, the net change is $\Delta = \text{In} - \text{Out}$. The probability of finding at least one bike is:

$$P(b_0 + \text{In} - \text{Out} \ge 1) = P(\text{Out} - \text{In} \le b_0 - 1)$$

This is evaluated numerically by summing over the joint bivariate probability grid truncated at the 99.99th percentiles:

$$P(\ge 1 \text{ bike}) = \sum_{o=0}^{M_{\text{out}}} \sum_{i=0}^{M_{\text{in}}} \frac{e^{-\lambda_{\text{out}}} \lambda_{\text{out}}^o}{o!} \frac{e^{-\lambda_{\text{in}}} \lambda_{\text{in}}^i}{i!} \cdot \mathbb{I}(b_0 + i - o \ge 1)$$

