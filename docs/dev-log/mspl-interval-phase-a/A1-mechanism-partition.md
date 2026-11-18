# A1 — Mechanism partition of the 55 MSPL joint-gate failures

Slice A1 of the approved ultra-plan. READ-ONLY analysis. No fits were run; nothing under
either campaign root was modified. All numbers below cite the exact file + column they
came from. Analysis scripts are saved alongside this file in the same directory
(`/private/tmp/claude-503/.../scratchpad/phase-a/`); derived (small, aggregated) CSVs
produced by those scripts are saved in the same directory and are themselves cited below.

**Sources used**

- Committed summaries (`/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB/docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/`): `gate-map-108.tsv`, `joint-gate-failures-55.tsv`, `case-summary.tsv`, `method-summary.tsv`, `README.md`.
- Raw root (`/private/tmp/mspl-coverage-production-8b23cfd2-eqLdNa/`): `endpoint-rows.csv` (108,000 rows), `outer-fit-rows.csv` (12,000 rows), `bootstrap-attempts-wide.csv` (2.7 GB, 6,000,000 rows — filtered, never loaded whole), `manifest.csv` (12 rows), `summary.csv` (108 rows), `profile-traces.csv` (sampled for the `threshold` column only).
- Scripts: `01_q1_partition.R`, `02_q1_partition_correct_measure.R`, `03_q2_width_vs_location.R`, `04_q3_q4_calibration.R`.
- Derived files (all in this directory): `derived_gate_map_with_checks.csv`, `derived_joint_failures_classified.csv`, `derived_coverage_failures_reclassified.csv`, `derived_availability_only.csv`, `derived_endpoint_agg_by_cell.csv`, `derived_alpha_star_by_cell.csv`, `c011_outer_fits.csv`, `c011_bootstrap_attempts.csv`, `c003_c007_outer_fits.csv`.

Case-to-regime/link map (source: `manifest.csv`, columns `case_id, regime, link, beta_shift, lambda_scale`):
C001 baseline/logit, C002 low_prevalence/logit, C003 high_prevalence/logit, C004 strong_signal/logit,
C005 baseline/probit, C006 low_prevalence/probit, C007 high_prevalence/probit, C008 strong_signal/probit,
C009 baseline/cloglog, C010 low_prevalence/cloglog, C011 high_prevalence/cloglog, C012 strong_signal/cloglog.
Truth vectors (`endpoint-rows.csv` column `truth`, constant within case_id x target — verified, 0/36 combos have >1 distinct value): baseline & strong_signal → (−0.50, 0.10, 0.55); low_prevalence → (−2.00, −1.40, −0.95); high_prevalence → (1.00, 1.60, 2.05).

---

## Preliminary finding that governs everything below: `coverage_gate` is not one rule

Before any partition could be trusted I checked what `gate-map-108.tsv`'s `coverage_gate`
column is actually computed from. It does **not** uniformly use `unconditional_coverage`.

- For `method %in% c("profile","bootstrap")`: `coverage_gate == (unconditional_wilson_lower ≥ 0.92 & unconditional_wilson_upper ≤ 0.98)` — **exact match, 0 mismatches in 72 rows** (`01_q1_partition.R` output).
- For `method == "wald"`: `coverage_gate == (conditional_wilson_lower ≥ 0.92 & conditional_wilson_upper ≤ 0.98)` — **exact match, 0 mismatches in 36 rows**.

This is exactly what the campaign `README.md` states in prose ("Wald ... applied the same
equivalence gate to coverage conditional on an available positive-definite likelihood
Hessian") but it is easy to miss when reading `gate-map-108.tsv` numerically, and it
changes the undercoverage count by a factor of 4 (see Q1). All classification below uses
the **method-correct** coverage measure: unconditional for profile/bootstrap, conditional
for wald.

---

## Q1 — Partition of the 55 failures by mechanism

`joint-gate-failures-55.tsv` has 55 data rows, confirmed identical (by `case_id, method,
target`) to the 55 `gate_pass == FALSE` rows in `gate-map-108.tsv` (`01_q1_partition.R`).

Using the method-correct gate coverage (`gate_coverage` = `unconditional_coverage` for
profile/bootstrap, `conditional_coverage` for wald — see above), the 55 failures split as:

| Class | n | Definition |
|---|---:|---|
| (i) OVERcoverage | **26** | `coverage_gate==FALSE`, `gate_coverage > 0.98` |
| (ii) genuine UNDERcoverage | **6** | `coverage_gate==FALSE`, `gate_coverage < 0.92` |
| (iii) availability-only | **1** | `availability_gate==FALSE`, `coverage_gate==TRUE` |
| (iv) borderline/MCSE | **22** | `coverage_gate==FALSE`, `0.92 ≤ gate_coverage ≤ 0.98`, but the 90% Wilson CI around that coverage estimate still pokes outside `[0.92,0.98]` |

`26+6+1+22 = 55`. Source: `02_q1_partition_correct_measure.R`, derived
`derived_coverage_failures_reclassified.csv` / `derived_availability_only.csv`.

**This is a correction to the task's assumed clean 3-way split**: 22/55 (40%) of the
failures are not "really" over- or under-covering by their point estimate — the achieved
coverage sits inside `[0.92, 0.98]`, and the row fails only because Monte-Carlo sampling
uncertainty (n=1000 replicates → Wilson half-width ≈ ±0.014–0.016 near p=0.93–0.98) pushes
the 90% CI edge past the boundary. Of the 22: 12 have their Wilson upper edge poking above
0.98 (near-over) and 10 have their Wilson lower edge poking below 0.92 (near-under) — see
`derived_coverage_failures_reclassified.csv`. These 22 are gate-design artifacts (a tight
equivalence band evaluated with n=1000 replicates), not evidence of a distinct failure
mechanism, and I do not chase them further below.

### (i) OVERcoverage — 26 rows

Full list with cell IDs (`method|link|regime|targetN`) in `derived_coverage_failures_reclassified.csv`
(class `OVER (gate-coverage>0.98)`). Highlights: `bootstrap|probit|high_prevalence|target3`
(C007, coverage 1.000), `profile|cloglog|high_prevalence|target2` and `target3` (C011,
coverage 1.000 both), `profile|probit|high_prevalence|target1..3` (C007, 0.988/0.998/0.999),
`profile|probit|low_prevalence|target1..2` (C006, 1.000/0.994), plus 12 wald rows spread
across every link and most regimes at 0.98–0.996.

### (ii) genuine UNDERcoverage — 6 rows (CONFIRMS the prior report)

| cell_id | case | gate_coverage |
|---|---|---:|
| bootstrap\|cloglog\|high_prevalence\|target3 | C011 | **0.010** |
| bootstrap\|cloglog\|high_prevalence\|target2 | C011 | **0.358** |
| bootstrap\|cloglog\|high_prevalence\|target1 | C011 | 0.855 |
| bootstrap\|probit\|high_prevalence\|target2 | C007 | 0.879 |
| bootstrap\|cloglog\|baseline\|target3 | C009 | 0.906 |
| bootstrap\|cloglog\|strong_signal\|target3 | C012 | 0.913 |

**Prior report cross-check: CONFIRMED.** Exactly 6 genuine undercoverage rows, with 3 of
them concentrated in `bootstrap x cloglog x high_prevalence` (case C011, all 3 targets) at
coverages 0.855 / 0.358 / 0.010 — the 0.358 and 0.010 values named in the prior report are
exact. Note: a first, naive classification pass that used `unconditional_coverage`
uniformly (ignoring the wald-uses-conditional rule above) produced **24** "undercoverage"
rows instead of 6 — almost all of them wald rows whose low *unconditional* coverage is a
pure artefact of counting non-PD-Hessian cases as noncoverage, not genuine miscalibration
of the conditional interval. That naive number is wrong; the method-correct number (6) is
what the campaign's own gate actually enforces, and it matches the prior report.

### (iii) availability-only — 1 row in the strict sense

`profile|logit|high_prevalence|target3` (case C003): `availability = 0.945`,
`availability_gate = FALSE`, `unconditional_coverage = 0.944`, `conditional_coverage =
0.999`, `coverage_gate = TRUE`. See Q6 for the second availability-gate failure (C010,
which also fails on coverage and so is not "pure" availability-only).

---

## Q2 — WIDTH error or LOCATION error in the catastrophic pocket? **→ LOCATION**

Source: `endpoint-rows.csv` (`available==TRUE` rows only), aggregated per case/method/target
in `03_q2_width_vs_location.R` → `derived_endpoint_agg_by_cell.csv`. For each cell:
`mean_midpoint = mean((lower+upper)/2)`, `midpoint_offset = mean_midpoint − truth`,
`sd_estimate = sd(estimate)` (between-replicate SD of the point estimator, n=1000),
`offset_over_sd = midpoint_offset / sd_estimate`, `width_over_sd = mean(upper−lower) /
sd_estimate` (reference value for a well-calibrated 95% normal interval ≈ 2×1.95996 =
3.92).

**bootstrap × cloglog × high_prevalence (C011), per target:**

| target | truth | mean_estimate | sd_estimate | mean_midpoint | offset_over_sd | width_over_sd | coverage |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1.00 | 0.753 | 0.292 | 0.844 | **−0.53** | 3.80 | 0.855 |
| 2 | 1.60 | 1.327 | 0.274 | 1.261 | **−1.24** | 2.83 | 0.358 |
| 3 | 2.05 | 1.588 | 0.084 | 1.355 | **−8.26** | 6.13 | 0.010 |

**Verdict: LOCATION error, worst at target 3.** Target 3's interval is centred **8.26
empirical SDs** from the truth while its width is if anything *larger* than the ≈3.92
nominal reference (6.13) — a width fix cannot rescue a center that is off by 8 SDs. Target
1 is a milder, more genuinely mixed case (offset −0.53 SD, width close to nominal). Target
2 is the one row with a real width contribution (width_over_sd 2.83, ≈28% narrower than the
≈3.92 reference) layered on top of a substantial −1.24 SD offset — the only target in this
pocket where widening alone would meaningfully help, and even there the interval would
still need to be recentred to reach 95%.

**The bias is in the point estimator itself, not an artefact of bootstrap resampling.**
`mean_estimate` for target 2 and target 3 is **identical to 6 decimal places** between the
`bootstrap` and `profile` methods for case C011 (1.326948 / 1.587609 both), because both
methods report the same underlying outer MLE — the only thing that differs between methods
is how the interval around that point is built. This means the interval CANNOT be centred
correctly by changing width, method, or scale — the base MSPL point estimator is
systematically biased downward from the true value (1.00→0.75, 1.60→1.33, 2.05→1.59) in
this regime, and every interval method inherits that same biased centre. This is why
`profile` and `wald` OVERcover in the very same case/targets (see Q1's OVER list:
C011|profile|target2, target3 both at 1.000) — they simply build wide enough intervals to
still bracket the truth despite the bad centring, while bootstrap's narrower percentile
interval does not. See Q5 for the mechanism behind the bias.

---

## Q3 — How much of the overcoverage is calibratable, and does a single global adjustment work?

**Method** (source: `04_q3_q4_calibration.R`; stated explicitly because it is an
approximation): for every available endpoint row, `ratio_i = |truth − midpoint_i| /
halfwidth_i`. `c* = ` the empirical 95th percentile of `ratio_i` within a cell is the
multiplicative rescaling of the realized halfwidth that would hit exactly 95% coverage,
**assuming halfwidth scales linearly with the nominal critical value** (exactly true for
Wald; a first-order local approximation for profile/bootstrap, flagged). The realized
nominal level is confirmed to be 95% two-sided for every method: `profile-traces.csv`'s
`threshold` column is exactly `1.920729410347059 = qchisq(0.95,1)/2` (checked against
`R`'s `qchisq(0.95,1)/2 = 1.920729`, sampled from the first 200k rows, single unique
value). Given `z0 = qnorm(0.975) = 1.959964`: `z* = c*·z0`, `alpha*_wald = 2(1−Φ(z*))`.
A secondary chi-sq-scale mapping is also reported for profile as a cross-check
(`threshold* = threshold0·c*²`, `alpha*_chisq = 1 − pchisq(2·threshold*, 1)`); the two
mappings coincide to full precision in every row because the ratio itself is what's fed
through the same z0/threshold0 constant — this is expected under the stated approximation
and does not independently validate it (flagged as **UNVERIFIED beyond first order** for
profile/bootstrap; exact for Wald).

**Self-check:** across the 53 cells that already PASS the joint gate, `median(alpha*_wald)
= 0.0523`, `mean = 0.0539` — both close to the true nominal 0.05, as they should be for
already-well-calibrated intervals. This is evidence the method is behaving sensibly.

**The 26 overcovering cells, `alpha*_wald`:**

- Overall: median 0.117, IQR [0.108, 0.268], min 0.067, max 0.738, SD 0.160.
- By method: wald mean 0.151 (n=16, sd 0.094), profile mean 0.271 (n=8, sd 0.245), bootstrap mean 0.270 (n=2, sd 0.006).
- By link: logit mean 0.115 (n=7), probit mean 0.179 (n=13), cloglog mean 0.331 (n=6, sd 0.267 — driven entirely by C011, see below).
- By regime: baseline 0.107, low_prevalence 0.174, strong_signal 0.111, **high_prevalence 0.306 (sd 0.211)**.

**Is cloglog's high mean real, or is it one pocket?** Excluding case C011: cloglog's 3
remaining overcovering cells (C009 wald target2/3, C012 wald target3) have `alpha*_wald` =
0.100, 0.108, 0.114 — essentially identical to logit's 0.115 mean, and the smallest, most
tightly clustered group of all. **C011 alone supplies cloglog's apparent excess**: its
profile target2/3 and wald target3 rows need `alpha* = 0.738, 0.522, 0.403` — 3–7× larger
than every other overcovering cell in the dataset. Source:
`derived_alpha_star_by_cell.csv`, filtered by hand in the script output.

**Conclusion:** A single global adjustment (something in the ballpark of widening from
nominal 95% to an effective ~85–90% quantile scale, i.e. `alpha* ≈ 0.10–0.18`) would
plausibly bring **most** (≈20/26) of the ordinary overcovering cells close to the 0.95
target — they cluster tightly there regardless of link/regime once C011 is set aside. It
would **not** fix the C011 pocket, which needs 3–7× more adjustment and — per Q2/Q5 — is a
qualitatively different failure (a likelihood-ridge collapse, not garden-variety
conservatism) that a uniform level rescaling would either under-correct (if tuned to the
bulk) or badly over-widen every other cell (if tuned to C011). A `lm(alpha*_wald ~ link +
regime + method + target)` over all 108 cells gives R² = 0.247, with `regime` (p=0.002) and
`method` (p=0.0055) significant and `link`/`target` not — consistent with "mostly one
global number, plus a regime/method-specific nudge, plus one outlier pocket" rather than a
smooth multi-dimensional surface.

---

## Q4 — Is the required adjustment predictable from fit-time observables?

**Data-availability check first, per the task's instruction to say so rather than guess:**

- `link`, `regime` (proxy for the DGP knobs `beta_shift`/`lambda_scale`, from `manifest.csv`), `method`, `target` (b\_fix index), and `availability` (fraction of usable fits, from `gate-map-108.tsv`/`summary.csv`) — **available**, used above and in the regressions below.
- `N_eff`, `p_free`, and hence `c_n = 2·sqrt(p_free/N_eff)` — **NOT AVAILABLE** in any of the six provided files. `outer-fit-rows.csv` records only `seed, status, convergence, objective, b_fix_1..3, elapsed_seconds, message` — no sample size or parameter-count column. `manifest.csv` records DGP knobs (`beta_shift, lambda_scale, seed_base, n_outer` [= Monte-Carlo replicate count, not sample size], `bootstrap_reps, minimum_usable_bootstrap`) but no design dimensions. I did not substitute a guess for these; they are reported as an evidence gap.
- Convergence/condition diagnostics in `outer-fit-rows.csv`: **present but constant, hence uninformative**. `status == "ok"` in all 12,000 rows; `convergence == 0` in all 12,000 rows (verified by direct tabulation). Every outer fit "converged" by TMB's own flag, including the ones diagnosed in Q5 as landing on a degenerate attractor — so this column carries **zero discriminating signal** in this campaign and cannot be used as a predictor.

**Regression results** (`04_q3_q4_calibration.R`):

- `lm(alpha*_wald ~ link + regime + method + factor(target))`, n=108: **R² = 0.247**. ANOVA: `regime` F=5.26, p=0.0021; `method` F=5.49, p=0.0055; `link` F=1.14, p=0.32 (n.s.); `target` F=1.56, p=0.21 (n.s.).
- Swapping categorical `regime` for the continuous DGP knobs `beta_shift`+`lambda_scale`: `beta_shift` p=0.019, `lambda_scale` p=0.057 — i.e. the prevalence-shift magnitude itself (not just its category) carries signal.
- Restricted to `method=="bootstrap"` only (n=36, the method containing the catastrophic pocket): `lm(alpha*_wald ~ link + regime + target + availability)` — **R² = 0.16, adjusted R² = −0.05 (i.e. no real signal once overfitting is penalised)**; no individual term reaches p<0.05 (`probit` closest at p=0.094); `availability` drops out entirely because bootstrap availability is **constant at 1.0 for all 36 bootstrap cells** (`method-summary.tsv`: `availability_min=1, availability_max=1` for bootstrap), so it is collinear with the intercept and R silently omits it.
- `cor(alpha*_wald, |beta_shift|)` by link: logit 0.17, probit 0.39, **cloglog 0.30**.

**Answer: partially predictable, with an important caveat.** `regime`/`beta_shift`
(prevalence-shift magnitude) and `method` carry real signal (R²≈0.25 jointly across all
108 cells) — a calibrator conditioning on those two would capture most of the *systematic*
component of overcoverage. But within the method that actually matters for the safety
question (bootstrap), the regression has **no usable signal** (adjusted R² < 0): the
catastrophic pocket is not a smooth function of link/regime/target that a calibrator could
interpolate into — it is a **discrete regime-specific attractor** (Q5), present at C011 and
essentially nowhere else at that severity, and `availability` (the one observable that
might have flagged it) is uninformative because bootstrap's 475/500-usable-refit floor
masks it entirely — every C011 bootstrap cell still reports 100% availability despite ~78%
of the individual refits landing on the same degenerate value. **No observable in the
provided files distinguishes "this cell is fine" from "this cell is C011" at fit time** —
the only signal is in the *point-estimate distribution itself* (the exact-value pinning
documented in Q5), which is not a routinely-computed diagnostic.

---

## Q5 — Mechanism of the cloglog × high_prevalence pocket

Source: `outer-fit-rows.csv` filtered to C011/C003/C007 (→ `c011_outer_fits.csv`,
`c003_c007_outer_fits.csv`) and `bootstrap-attempts-wide.csv` filtered to C011 (→
`c011_bootstrap_attempts.csv`, 500,000 rows = 1000 outer × 500 bootstrap reps).

**Candidate (a) — cloglog information collapse: SUPPORTED, with a specific numeric
signature.** In the **original, non-bootstrap outer MLE fits** for C011 (n=1000
independent simulated datasets), `b_fix_3` (truth 2.05) is pinned to **exactly
1.596400 (±1e-4) in 929/1000 fits (92.9%)**, and `b_fix_2` (truth 1.60) is pinned to the
*same* value in 463/1000 (46.3%); 452/1000 fits have `b_fix_2 ≈ b_fix_3` to within 1e-6
simultaneously. This is not a `unconditional_redraw`/bootstrap artefact — it is present in
the base point estimator itself, across independently-seeded datasets, to 6 decimal places.
This matches a link-dependent likelihood-ridge collapse (candidate a's mechanism) rather
than ordinary sampling noise, and a severity gradient across links confirms the
link-dependence directly: the same "modal value captures most of the 1000 fits" pattern
appears at high_prevalence in **probit (C007)**, `b_fix_3` pinned to 2.3629 in **484/1000
(48.4%)** fits, but far more weakly in **logit (C003)**, modal `b_fix_3` value 2.2761 in
only **71/1000 (7.1%)** fits. Ranking cloglog (92.9%) > probit (48.4%) > logit (7.1%)
matches exactly the ranking of failure severity by link seen throughout Q1–Q4 (cloglog
alone produces the catastrophic 0.010/0.358 undercoverage; probit and logit do not).

**Candidate (b) — bootstrap resamples hitting a degenerate response: NOT SUPPORTED as the
root cause** (the specific "all-ones response" sub-claim is **UNVERIFIED** — no raw
response `y` data is in any provided file, so it cannot be checked directly). What **is**
verifiable: the pinning phenomenon is **not manufactured by resampling**. Across the
500,000 C011 bootstrap attempts, 78.4% land within 1e-4 of the same 1.5964 attractor for
`b_fix_3` (vs 92.9% in the un-resampled outer fits — resampling if anything *dilutes* the
pinning slightly, it does not create it). Per-outer-dataset bootstrap pin-rates: median
0.817, min 0.030, and **935/1000 outer datasets have >50% of their own 500 bootstrap
refits pinned** — the phenomenon is pervasive across essentially every simulated dataset,
not concentrated in a handful of pathological resamples. `status`/`convergence` in the
bootstrap data are uniformly `"ok"`/`0` (500,000/500,000), so nothing in the recorded
diagnostics distinguishes a "degenerate" resample from a "clean" one — they are
numerically indistinguishable except by the collapsed parameter value itself.

**Candidate (c) — endpoint ordering / boundary refit: not the operative mechanism for the
undercoverage pocket**, though a *related* symptom shows up elsewhere. The catastrophic
bootstrap rows are all `available==TRUE` — the CIs exist and are well-formed, just badly
centred (Q2), so there is no ordering/boundary-refit failure to find for those specific
rows. The bracket-search failure modes recorded in `endpoint-rows.csv$status`
(`profile_matched_crossed_truncated`, `profile_matched_optimizer_failed_crossed`, etc. —
see Q6) are a genuinely separate phenomenon confined to the `profile` method's rare
unavailable cases, not to bootstrap's undercoverage. It is plausible both symptoms share
the same underlying likelihood-ridge cause (a locally flat/non-monotonic profile trace
would both make bracket search unstable *and* make repeated re-optimisation collapse onto
the ridge's attractor point), but that link is inferential, not directly demonstrated here — flagged **UNVERIFIED**.

**Why bootstrap catastrophically undercovers while profile/wald overcover in the same
cells:** because profile builds its interval from the deviance/likelihood *surface*
directly, a flat ridge produces a *wide* profile interval (it has to travel far before the
deviance threshold 1.9207 is crossed) that happens to still bracket the truth — hence
`profile|cloglog|high_prevalence|target2,3` both hit exactly 1.000 coverage (Q1). Bootstrap
instead measures spread via refit-to-refit *dispersion*, and because ~78–93% of refits all
collapse onto the *same* attractor value, that dispersion (`sd_estimate` = 0.084 for
target3) is artificially small — the percentile interval is narrow and centred on the
biased attractor, not on the truth, so it essentially never reaches 2.05 (coverage 0.010).

**Verdict: (a) is the supported mechanism** — a link-dependent (worst for cloglog, present
but weaker for probit, weak for logit) information/identifiability collapse between
`b_fix_2` and `b_fix_3` under high prevalence, which pulls the softly-penalised MLE onto a
fixed attractor value in the large majority of both original fits and bootstrap refits.
(b) is not supported as an additional or root cause (resampling reproduces, not creates,
the collapse) though its specific "all-ones response" sub-claim is unverified for lack of
raw data. (c) is a separate, method-specific symptom (profile bracket-search failures) not
the mechanism behind the bootstrap undercoverage itself.

---

## Q6 — The 2 availability-only failures

Both are `method=="profile"` — the *only* method with any `availability_gate==FALSE` cells
(`method-summary.tsv`: `wald availability_fail=0`, `bootstrap availability_fail=0`,
`profile availability_fail=2`, `availability_min=0.928`, `availability_max=1`). Neither
`wald` nor `bootstrap` has a single availability failure anywhere in the 36-cell grid.

| cell | availability | availability_gate | coverage_gate | note |
|---|---:|---|---|---|
| `profile\|logit\|high_prevalence\|target3` (C003) | 0.945 | FALSE | TRUE | "pure" availability-only failure (Q1 class iii) |
| `profile\|cloglog\|low_prevalence\|target1` (C010) | 0.928 | FALSE | FALSE | compound failure — also fails coverage (Q1 borderline class), Wilson lower edge 0.908 < 0.92 |

**Clustering with an observable: yes — both are the largest-|truth| target in their
regime.** `truth` (from `endpoint-rows.csv`): high_prevalence gives `(1.00, 1.60, 2.05)` so
C003's target 3 (2.05) is the extreme; low_prevalence gives `(−2.00, −1.40, −0.95)` so
C010's target 1 (−2.00) is the extreme. Both unavailable cells sit at the coefficient
furthest from zero within an already-shifted-prevalence regime.

**Cause of unavailability** (`endpoint-rows.csv$status`/`message`, `available==FALSE`
rows only): every one of the 205 profile-unavailable rows across the full grid reports
`centre=matched` (the point estimate itself was found) with a **bracket-search failure on
one side** — `lower=crossed`/`upper=truncated` (55 of C003's 55 failures — literally 100%
of them), and for C010 a mix of `lower=refinement_failed` (37), `lower=optimizer_failed`
(20), `lower=truncated` (15), all with `upper=crossed`. This is a profile-likelihood
root-finding failure (the deviance-threshold crossing search cannot locate a valid
endpoint), concentrated at the extreme end of the parameter range — consistent with (though
not proof of) the same kind of likelihood-surface irregularity documented mechanistically
for C011 in Q5, here manifesting as a search failure rather than a collapsed point estimate.

---

## Summary table (all cite `derived_*` files above)

| Question | Answer | Confidence |
|---|---|---|
| Q1 partition | 26 OVER / 6 UNDER / 1 pure avail-only / 22 borderline (Wilson-boundary artefact) | Verified from `gate-map-108.tsv` + `joint-gate-failures-55.tsv`, exact |
| Q2 width vs location | **LOCATION** (target3: 8.26 empirical SDs off-centre; point-estimate bias identical across bootstrap/profile) | Verified from `endpoint-rows.csv` |
| Q3 calibratable? | Yes for ~20/26 ordinary overcovering cells (alpha* clusters 0.10–0.18); **no** for the C011 pocket (alpha* 0.40–0.74, 3–7× larger) | Verified, with a stated first-order-approximation caveat on the alpha* mapping |
| Q4 predictable? | Partial (R²=0.25 across all 108 cells via regime+method) but **no signal within bootstrap** (adjusted R² < 0); N_eff/p_free/c_n not available in provided files; convergence flag uninformative (constant) | Verified for what's computable; gap flagged for what isn't |
| Q5 mechanism | (a) SUPPORTED (link-graded information collapse, 92.9%/48.4%/7.1% pinning for cloglog/probit/logit); (b) not root cause (resampling doesn't create the collapse); (c) not the undercoverage mechanism (separate profile-only symptom) | Verified from `outer-fit-rows.csv` + `bootstrap-attempts-wide.csv` |
| Q6 availability-only | 2 cells (0.945, 0.928), both `profile`, both the largest-\|truth\| target in their regime; caused by bracket-search failure, not fit failure | Verified from `gate-map-108.tsv` + `endpoint-rows.csv` |
