# Design 122 confirmatory campaign — independent adjudication of K1–K4

Adjudicator: independent reviewer, no prior involvement in Design 122, the
harness, or the campaign. Sources read: `docs/design/122-va-vs-laplace-recovery.md`
(§§0–17 in full), `dev/design122-campaign/CAMPAIGN-RESULTS.md`,
`dev/design122-campaign/run-campaign.R`, `dev/va-vs-laplace-prerun/RESULTS.md`
and `va-laplace-prerun.csv`, and the 24 raw chunk CSVs. Nothing was committed;
no repository file other than this one was written.

**Verdicts, up front:**

| Criterion | Verdict |
|---|---|
| **K1** (optimiser artefact voids the study) | **FIRED** — on its own pre-run data, on the gradient leg, in two of three arms. It was never evaluated before launch. |
| **K2** (convergence <70% downgrades the cell) | **FIRED** for 3 cells (all L2, all `binomial_probit, n=100`); firmly for cells 1 and 4, unresolvably-at-the-margin for cell 2. |
| **K3** ("cheap remedy wins", the pre-registered null) | **NOT FIRED.** The "VA wins" bar is literally cleared (4 cells / 3 distinct truth×n strata survive K2 and a bootstrap check). But the result is strongly heterogeneous — 15 of 24 cells favour L2 beyond the same margin — and K3 has no clause for that pattern. |
| **K4** (§0.2 silent-divergence transfer check) | **FIRED in the "transfers" direction** — 4 of 6 `binomial_probit` n=400 strata fail the upper-bound test. Design 108 §0.2's framing is retained. |

---

## Method — what was recomputed, and how

Everything below was recomputed from `results/chunk-001.csv` … `chunk-024.csv`
with `read.csv()` (quote-aware), not taken from `CAMPAIGN-RESULTS.md`.

Verified structural facts:

- **21,600 rows**, 21,600 unique `(cell_id, arm, seed)` triples, zero
  duplicates; 24 cells × 3 arms × 300 seeds exactly. The grid is
  2 families × n∈{100,400} × p∈{12,27} × 3 truths. `n = 1600` and the
  binomial-logit VJJ block were not run.
- **Infra-exclusion rule reproduced**: `arm=="VGH" & status=="error" &
  grepl("getParameterOrder|unable to load shared object", error)` selects
  **exactly 120 rows, all in `cell_id == 23`**, `wall_time_s` median 0.436 s,
  max 51.1 s, sum 873 s. No L0 or L2 row carries `status == "error"` anywhere.
- **50 further VGH error rows** in 14 other cells carry
  `"The variational fit did not pass its own health gate"` — genuine engine
  self-rejections, retained as data throughout, per §F2.

Recomputations that reproduce `CAMPAIGN-RESULTS.md` **exactly**:

- Per-arm convergence on the 21,480-row analysis set: L0 7,114/7,200 =
  **98.81%**, L2 6,499/7,200 = **90.26%**, VGH 7,030/7,080 = **99.29%**.
  (Note `converged` for L0/L2 is already `opt$convergence == 0 & pdHess`,
  per `run-campaign.R:388`; for VGH it is `fit$status == "healthy"`.)
- **Two-sided detector recomputed from scratch** (`rel_frob > 10 | kappa < 1/3`)
  agrees with the shipped `degenerate` column on every non-NA row. The 50
  guard-rejected VGH rows have NA `rel_frob`/`kappa`; I set them
  `degenerate = TRUE` by construction as §F2 requires — as `CAMPAIGN-RESULTS.md`
  correctly notes, the harness never shipped a distinct `guard_rejected` status,
  so this is applied in analysis, not instrumented.
- **Three denominators** (pooled, infra-excluded): raw = guard-inclusive here,
  because the only remaining `status=="error"` rows are the 50 guard rejections
  that the design requires to stay in. L0 1,067/7,200 = **14.82%**;
  L2 381/7,200 = **5.29%**; VGH 61/7,080 = **0.86%**. All-arm intersection
  (**7,030** of 7,200 seed-cells have a usable `Sigma_hat` in all three arms):
  L0 **15.01%**, L2 **5.36%**, VGH **11/7,030 = 0.16%**.
- The stratified truth × n degeneracy table (§4.2) reproduces to the row.
- TEST A: L0 6,984/7,200 pass (216 fails), L2 7,200/7,200, VGH 7,030/7,030
  with 50 NA. **All 7,030 usable VGH rows carry `testA_vgh_partial = TRUE`.**
- `max_abs_gradient > 1e-3`: L0 **35.96%**, L2 **100.00%** (min 0.0859),
  VGH **0.00%** (max 7.0e-4, 50 NA).

The stratified estimand I recomputed independently is the **primary K3 target**,
which `CAMPAIGN-RESULTS.md` does not report at all: the
`|off-diag| ≥ 0.1` stratified relative-Frobenius error
(`rel_frob_offdiag_strong`), per cell, on the **all-arm intersection**
denominator, together with the paired difference `Δ = rel_frob_VGH −
rel_frob_L2`, `MCSE_paired = SD(Δ)/√n_seeds`, per-cell median, per-seed win
fraction, a degeneracy/non-convergence-free re-computation, and a 2,000-draw
bootstrap SE of the RMSE difference itself. Full per-cell table in K3 below.

Signal strength is never pooled: every table below is indexed by truth, and
where K3/K4 name a finer stratum I use it.

---

## The excluded rows — verdict: **the exclusion is legitimate and does not bias the comparison**

The claim to test is whether removing 120 VGH rows at cell 23
(`ordinal_probit, n=400, p=27, T-mid`) could flatter VGH. Three independent
lines of evidence say no.

1. **Mechanism is estimator-independent.** All 120 rows failed at
   `dyn.load`/`getParameterOrder` — before any model was fitted. Median wall
   time 0.436 s against a VGH median of **629 s** on the surviving rows at the
   same cell. Nothing about the data, the seed, or the estimator's behaviour
   is encoded in the failure; the loss is determined by which of 96 workers
   raced into an empty shared build root.
2. **Missingness is empirically ignorable.** The 120 lost seeds are scattered,
   not contiguous (seeds 4…300, `diff != 1`). Testing the lost seeds against
   the retained seeds *using the other two arms at the same cell* — the direct
   MCAR check the data permit — gives: L0 `rel_frob_offdiag` mean 0.2698
   (lost) vs 0.2639 (retained), t-test p = 0.239; L2 0.2678 vs 0.2619,
   p = 0.230; convergence 100% in both subsets for both arms; degeneracy 0% in
   both subsets for both arms. The lost seeds are not the hard ones.
3. **The cell is not load-bearing anywhere.** Cell 23 does not clear the K3
   margin (it is one of the 15 cells where L2 is *better* beyond the margin,
   advantage −0.0038); its VGH degeneracy is 0; and K4 is `binomial_probit`-only,
   so cell 23 cannot enter it. No verdict in this document moves if cell 23 is
   deleted entirely.

**Sensitivity — the adversarial alternative.** If the 120 rows were instead
scored as VGH failures, VGH's overall convergence falls from 99.29% to
7,030/7,200 = **97.64%**, and cell 23's VGH convergence becomes 180/300 = 60%,
which would trip **K2** for that cell. That is a *downgrade of one ordinal cell
that already favours L2* — it cannot manufacture a VA advantage. The exclusion
is therefore accepted, with the caveat `CAMPAIGN-RESULTS.md` already states:
cell 23's VGH arm is n = 180 and its rate MCSE is inflated ×1.29.

One genuine instrumentation gap, distinct from the exclusion and worth
recording: the 50 guard-rejected VGH rows were **not** given a distinct status
string by the harness, so §F2's "guard-trips are logged as degenerate OUTCOMES"
was implemented in analysis rather than in the data. It happens to be applied
correctly here, but it is not what the pre-registration instrumented.

---

## K1 — optimiser artefact — **FIRED**

**K1 as written** (§6.2, restating §F1): *"TEST A fails for any arm
(|c_hat − 1| > 0.01), OR more than 10% of pre-run fits in any single arm have
`max_abs_gradient > 1e-3`… Action: halt, fix the harness, do not proceed to the
full campaign. This is checked entirely inside the pre-run (§7) and must clear
before any confirmatory launch is even proposed."*

The criterion's own locus is **the pre-run**. So I evaluated it there, on
`dev/va-vs-laplace-prerun/va-laplace-prerun.csv` (120 fits, 40 per arm):

| Arm | pre-run fits | rate `max_abs_gradient > 1e-3` | min | median | max |
|---|---:|---:|---:|---:|---:|
| L0 | 40 | **37.50%** | 1.59e-4 | 7.75e-4 | 2.998e-3 |
| L2 | 40 | **100.00%** | 0.1378 | 0.3154 | 1.370 |
| VGH | 40 | 0.00% | 5.4e-6 | 7.5e-5 | 3.5e-4 |

**Two arms exceed the 10% bar; the second exceeds it by an order of
magnitude.** K1's gradient leg therefore fires on the pre-run, and it fires
again on the confirmatory data (L0 35.96%, L2 100.00%, VGH 0.00% — the pre-run
rates replicate almost exactly at 180× the sample size).

This leg **was never evaluated before launch.** `dev/va-vs-laplace-prerun/RESULTS.md`
states verbatim: *"`max_abs_gradient > 1e-3` rate was not separately tabulated
in this reply for space, but is a column in `va-laplace-prerun.csv` for the
design owner's own K1 check."* The column existed; the check was not run; the
campaign launched. The pre-registration's stated action ("halt, fix the
harness") was therefore never triggered because the trigger was never read.

**Diagnosis, offered so the verdict is usable rather than merely punitive.**
The two breaches are not the same thing:

- **L2's 100% is an instrument mismatch, not an optimiser failure.** The
  `aghq_ridge` penalty is applied at the R level (`R/fit-multi.R:5586-5592`)
  and is not inside `tmb_obj$fn()`, so `fit_health$max_gradient` is the
  gradient of the *unpenalised* objective evaluated at the *penalised* optimum.
  It has no reason to be near zero. This is the identical defect Design 122 §15
  found and fixed **for TEST A** — and did not fix for the gradient column.
  L2's TEST A c_hat values (`[1.0000, 1.0014]` in the pre-run, 7,200/7,200 pass
  in the campaign) say the L2 optimum is genuinely stationary for the objective
  L2 actually optimises.
- **L0's 36% has no such excuse.** L0 is unpenalised (`ridge_tau = Inf`), so
  the recorded gradient is the gradient of the objective L0 optimised. 36% of
  L0 fits sit above 1e-3. Context that matters: the package's own convergence
  tolerance is `.gllvmTMB_converged_gtol = 1e-2` (`R/diagnose.R:13`), and only
  **0.89%** of L0 fits exceed *that*. Design 122 deliberately declared a
  tolerance ten times tighter than the package's own (§F1 explains why: there
  was no generic one to borrow) and then never checked fits against it. L0's
  breach is concentrated at `n = 400` (53.3% vs 18.6% at n = 100) and in the
  ordinal cells (up to 76.7% at cell 21), i.e. exactly where the objective is
  largest — consistent with an unscaled absolute tolerance being the wrong
  instrument, not with 36% of Laplace fits being non-stationary.

**The TEST A leg.** Literally, *"TEST A fails for any arm"* read per-fit would
also fire: 216 L0 fits fail `|c_hat − 1| ≤ 0.01` (3.00%, c_hat ∈ [0.921,
1.046]), concentrated at n = 100, large p, weak/mid signal — cells 4 (79), 5
(49), 16 (27). §16 itself read a single rung-2 TEST A failure as a *correctly
caught degenerate fit, not a harness artefact*, i.e. arm-level not per-fit.
That ambiguity is real and I flag it rather than resolve it silently: under the
arm-level reading the TEST A leg does not fire; under the per-fit reading it
does. **The verdict does not depend on it** — the gradient leg fires under any
reading.

**MCSE governance.** The threshold is 10 percentage points.
- On the pre-run (n = 40/arm) the achieved rate MCSE for L0 is
  √(0.375·0.625/40) = **7.65 pp**, so 2×MCSE = 15.3 pp **exceeds** the 10 pp
  threshold: **governance NOT satisfied on the pre-run for L0.** (The observed
  0.375 is still separated from 0.10 by more than 2×MCSE, so the breach itself
  is resolvable; the *threshold* is not.) L2's rate is 1.000 with MCSE 0 —
  governance satisfied trivially.
- On the confirmatory data (n = 7,200/arm) L0's MCSE is 0.57 pp, 2×MCSE =
  1.13 pp ≪ 10 pp: **governance satisfied**, and the breach is confirmed at
  full size.

**Verdict: K1 FIRED.** The pre-registered consequence is that the study is
voided pending a harness fix. I record instead the honest, narrower reading the
evidence supports: **K1's gradient leg is measuring the wrong quantity for L2
and an inappropriately scaled quantity for L0, and this was discoverable before
launch and was not checked.** The remaining criteria are adjudicated below on
the explicit understanding that K1's own stop-and-fix action was bypassed, and
that a reader is entitled to treat every downstream number as provisional on
that ground alone.

---

## K2 — convergence floor — **FIRED for three cells**

**K2 as written**: a confirmatory cell whose raw-denominator convergence rate
in *any* arm is below 70% is reported as a convergence result only; no accuracy
comparison is drawn from it.

Recomputed over all 72 cell × arm combinations (raw denominator, infra-excluded):

| cell | family | n | p | truth | arm | N | n_conv | rate | 2×MCSE | below 0.70 by |
|---:|---|---:|---:|---|---|---:|---:|---:|---:|---:|
| 4 | binomial_probit | 100 | 27 | T-weak | L2 | 300 | 161 | **53.67%** | 5.76 pp | 16.3 pp |
| 1 | binomial_probit | 100 | 12 | T-weak | L2 | 300 | 186 | **62.00%** | 5.60 pp | 8.0 pp |
| 2 | binomial_probit | 100 | 12 | T-mid | L2 | 300 | 208 | **69.33%** | 5.32 pp | 0.67 pp |

Minimum rate by arm across the whole grid: L0 **87.33%**, L2 **53.67%**,
VGH **97.00%**. Two further cells sit just above the bar (cell 5 at 76.00%,
cell 16 at 76.33%), both L2.

**MCSE governance.** Cells 4 and 1 sit 16.3 pp and 8.0 pp below the 70% bar
against a 2×MCSE of ~5.7 pp — resolved, K2 fires cleanly. **Cell 2 sits 0.67 pp
below the bar against a 2×MCSE of 5.3 pp — it is not distinguishable from 70%
at the achieved replication.** I apply K2 to it anyway (the rule is a
threshold, not a test), but the honest statement is that cell 2's downgrade is
a coin-flip of Monte Carlo error, not a finding.

**Consequence carried into K3:** cells 1, 2 and 4 are removed from the accuracy
adjudication. This matters — see K3.

---

## K3 — "cheap remedy wins" — **NOT FIRED**

Primary target: `rel_frob_offdiag_strong` (the `|off-diag| ≥ 0.1` entries of
`Sigma_B`). Denominator: **all-arm intersection** (7,030 of 7,200 paired
seed-cells; §F2's third denominator, and the one §15 mandates for these
contrasts). Paired difference `Δ = rel_frob_VGH − rel_frob_L2`;
`MCSE_paired = SD(Δ)/√n`; "advantage" = `RMSE_L2 − RMSE_VGH` (positive = VA
better); threshold = `2 × MCSE_paired`, exactly as §6.2 specifies.

| cell | fam | n | p | truth | N | RMSE L0 | RMSE L2 | RMSE VGH | adv | 2·MCSE_p | clears | med L2 | med VGH | VGH-better seeds | boot 95% CI on adv |
|---:|---|---:|---:|---|---:|---:|---:|---:|---:|---:|:--:|---:|---:|---:|---|
| 1 | bin | 100 | 12 | T-weak | 295 | 61.14 | 10.105 | 2.246 | **+7.859** | 1.078 | ✔︎ | 1.230 | 1.316 | 40.7% | [0.07, 14.81] |
| 2 | bin | 100 | 12 | T-mid | 298 | 8.05 | 1.281 | 1.229 | +0.052 | 0.048 | ✔︎ | 0.984 | 1.122 | 13.4% | [−0.04, 0.15] |
| 3 | bin | 100 | 12 | T-strong | 300 | 175.45 | 1.040 | 0.740 | **+0.300** | 0.047 | ✔︎ | 0.708 | 0.675 | 50.3% | [0.22, 0.41] |
| 4 | bin | 100 | 27 | T-weak | 298 | 28.10 | 1.835 | 1.384 | **+0.451** | 0.109 | ✔︎ | 0.981 | 0.982 | 45.6% | [0.16, 0.80] |
| 5 | bin | 100 | 27 | T-mid | 300 | 910.03 | 1.002 | 0.924 | **+0.077** | 0.027 | ✔︎ | 0.838 | 0.867 | 21.3% | [0.04, 0.11] |
| 6 | bin | 100 | 27 | T-strong | 297 | 8.75 | 0.647 | 0.692 | −0.045 | 0.006 | ✘ (L2) | 0.608 | 0.643 | 9.8% | [−0.052, −0.038] |
| 7 | bin | 400 | 12 | T-weak | 294 | 0.80 | 0.792 | 0.917 | −0.125 | 0.031 | ✘ (L2) | 0.689 | 0.764 | 34.4% | [−0.17, −0.09] |
| 8 | bin | 400 | 12 | T-mid | 298 | 0.56 | 0.487 | 0.493 | −0.006 | 0.019 | ✘ | 0.426 | 0.475 | 11.4% | [−0.05, 0.07] |
| 9 | bin | 400 | 12 | T-strong | 300 | 1.18 | 0.486 | 0.302 | **+0.185** | 0.034 | ✔︎ | 0.296 | 0.286 | 67.7% | [0.12, 0.25] |
| 10 | bin | 400 | 27 | T-weak | 297 | 0.74 | 0.736 | 0.783 | −0.047 | 0.012 | ✘ (L2) | 0.659 | 0.665 | 24.6% | [−0.066, −0.031] |
| 11 | bin | 400 | 27 | T-mid | 300 | 0.34 | 0.338 | 0.349 | −0.011 | 0.0008 | ✘ (L2) | 0.329 | 0.339 | 4.0% | [−0.0116, −0.0100] |
| 12 | bin | 400 | 27 | T-strong | 300 | 0.57 | 0.313 | 0.283 | **+0.031** | 0.007 | ✔︎ | 0.276 | 0.270 | 63.7% | [0.019, 0.044] |
| 13 | ord | 100 | 12 | T-weak | 298 | 1.34 | 1.288 | 1.480 | −0.192 | 0.032 | ✘ (L2) | 0.978 | 1.003 | 29.2% | [−0.24, −0.15] |
| 14 | ord | 100 | 12 | T-mid | 293 | 26.19 | 0.883 | 0.986 | −0.103 | 0.015 | ✘ (L2) | 0.811 | 0.898 | 5.1% | [−0.12, −0.08] |
| 15 | ord | 100 | 12 | T-strong | 299 | 7.85 | 0.573 | 0.601 | −0.028 | 0.006 | ✘ (L2) | 0.487 | 0.524 | 13.0% | [−0.039, −0.016] |
| 16 | ord | 100 | 27 | T-weak | 296 | 4.24 | 1.168 | 1.276 | −0.108 | 0.028 | ✘ (L2) | 0.906 | 0.917 | 29.7% | [−0.15, −0.07] |
| 17 | ord | 100 | 27 | T-mid | 298 | 3.72 | 0.687 | 0.694 | −0.006 | 0.017 | ✘ | 0.622 | 0.653 | 3.0% | [−0.04, 0.05] |
| 18 | ord | 100 | 27 | T-strong | 300 | 1.25 | 0.468 | 0.509 | −0.040 | 0.003 | ✘ (L2) | 0.437 | 0.465 | 4.0% | [−0.045, −0.036] |
| 19 | ord | 400 | 12 | T-weak | 291 | 0.60 | 0.599 | 0.673 | −0.073 | 0.014 | ✘ (L2) | 0.513 | 0.566 | 24.1% | [−0.089, −0.059] |
| 20 | ord | 400 | 12 | T-mid | 298 | 0.37 | 0.367 | 0.394 | −0.027 | 0.003 | ✘ (L2) | 0.352 | 0.374 | 13.1% | [−0.031, −0.023] |
| 21 | ord | 400 | 12 | T-strong | 300 | 0.24 | 0.242 | 0.246 | −0.005 | 0.001 | ✘ (L2) | 0.229 | 0.234 | 39.7% | [−0.006, −0.003] |
| 22 | ord | 400 | 27 | T-weak | 300 | 0.56 | 0.559 | 0.580 | −0.021 | 0.007 | ✘ (L2) | 0.491 | 0.493 | 34.7% | [−0.032, −0.010] |
| 23 | ord | 400 | 27 | T-mid | 180 | 0.27 | 0.266 | 0.270 | −0.004 | 0.0005 | ✘ (L2) | 0.258 | 0.262 | 10.6% | [−0.0043, −0.0033] |
| 24 | ord | 400 | 27 | T-strong | 300 | 0.22 | 0.219 | 0.222 | −0.002 | 0.0004 | ✘ (L2) | 0.210 | 0.211 | 26.3% | [−0.0028, −0.0020] |

**Applying K3 literally.**

- **"Cheap remedy wins"** requires the VGH advantage to be smaller than
  `2 × MCSE_paired` in **every** confirmatory stratum. It is cleared in 7 of 24
  cells. **The pre-registered null does not obtain — K3 is NOT FIRED.**
- **"VA wins"** requires the margin cleared in **≥2 independent (truth × n)
  strata**. The 7 clearing cells span 4 distinct (truth × n) strata. After K2
  removes cells 1, 2 and 4, **4 cells remain (3, 5, 9, 12) spanning 3 distinct
  (truth × n) strata: (T-strong, 100), (T-mid, 100), (T-strong, 400).** The bar
  is cleared. Evaluated instead directly at the (truth × n) level, 3 of 6 strata
  clear. **The "VA wins" bar is met on either reading.**

**Robustness of that conclusion — it survives three stress tests.**

1. *K2 downgrade*: survives (4 cells, 3 strata, as above).
2. *Tail dependence*: restricting to seeds where **neither** arm is degenerate
   **and both** converged, cells 3, 9 and 12 still clear (advantages +0.276,
   +0.149, +0.031 against thresholds 0.048, 0.030, 0.007); cell 5 clears
   marginally (+0.024 vs 0.024). Cells 1, 2 and 4 **reverse sign** on the clean
   subset (−0.161, −0.078, −0.071) — their entire apparent VA advantage is
   L2's degenerate/non-converged tail, which is precisely why K2 excludes them.
   The surviving signal is not a tail artefact.
3. *Bootstrap*: a 2,000-draw bootstrap CI on the RMSE difference itself excludes
   zero for cells 3, 5, 9, 12 (and 1, 4). It does **not** exclude zero for
   cell 2 — see the governance note below.

**MCSE governance — satisfied by construction, but the construction is
mismatched.** K3's threshold *is* `2 × MCSE_paired`, so governance holds
definitionally. However, the statistic compared against it — the difference of
two RMSEs — is **not** the statistic whose MCSE that is (the mean paired
difference). Bootstrapping the RMSE difference directly gives standard errors
up to ~9× larger than `MCSE_paired` (cell 1: 4.98 vs 0.539; cell 2: 0.0495 vs
0.0238). **The pre-registered threshold is therefore anti-conservative for the
quantity it gates**, and cell 2 is a concrete casualty: it clears the
pre-registered bar and fails the bootstrap. This is a defect in K3's
specification, not in the data. It does not change the verdict — cells 3, 9, 12
clear both bars comfortably — but any future restatement of K3 should compare
like with like.

**What K3's letter does not capture, and must be said.** In **15 of 24 cells
L2 is better than VGH beyond the same `2 × MCSE_paired` margin**, including
**11 of 12 ordinal cells** and every `n = 400` cell except the two T-strong
binomial ones. VGH's per-seed win fraction is below 50% in 21 of 24 cells and
its median error is worse than L2's in 21 of 24. K3 defines only "VA wins"
(≥2 strata clearing) and "cheap remedy wins" (margin never cleared anywhere),
and reserves "mixed" for the case where neither holds. It has **no clause for
a result that clears the VA bar in a few strata while showing the opposite sign,
beyond the same margin, in most of the others** — which is what happened.
Adjudicating strictly by the text yields "VA wins"; adjudicating by what the
text was evidently trying to establish — *a difference large enough and
consistent enough to justify Stages 3 and 5* (§1) — the consistency half fails.
I record the verdict as: **K3 NOT FIRED; the "VA wins" bar literally cleared,
confined to `binomial_probit` strong/mid signal, and contradicted in the
majority of the grid.**

*Secondary (`diag`) stratum, reported per §6.2 but not load-bearing:* VGH's
advantage clears the margin in 18 of 24 cells, driven by L2's very heavy
diagonal tail at n = 100 (e.g. cell 7: RMSE_L2 114.0 vs RMSE_VGH 2.74). All 6
non-clearing cells are ordinal.

---

## K4 — the §0.2 silent-divergence transfer check — **FIRED in the "transfers" direction**

L0, `binomial_probit`, raw denominator, canonical two-sided definition
(`silent_divergent = degenerate & convergence == 0 & pdHess == TRUE`; my
recomputation agrees with the shipped column on all 21,430 non-NA rows).
Stratified by (truth, n, p), never pooled. `n ≥ 400` strata are the ones K4
adjudicates; the `n = 100` block is shown for context only.

| truth | n | p | N | k | rate | MCSE | rate + 2·MCSE | upper bound < 2%? |
|---|---:|---:|---:|---:|---:|---:|---:|:--:|
| T-weak | 100 | 12 | 300 | 171 | 57.00% | 2.86 pp | 62.72% | — (context) |
| T-mid | 100 | 12 | 300 | 126 | 42.00% | 2.85 pp | 47.70% | — |
| T-strong | 100 | 12 | 300 | 185 | 61.67% | 2.81 pp | 67.28% | — |
| T-weak | 100 | 27 | 300 | 108 | 36.00% | 2.77 pp | 41.54% | — |
| T-mid | 100 | 27 | 300 | 106 | 35.33% | 2.76 pp | 40.85% | — |
| T-strong | 100 | 27 | 300 | 59 | 19.67% | 2.29 pp | 24.26% | — |
| **T-weak** | **400** | **12** | 300 | 70 | **23.33%** | 2.44 pp | **28.22%** | **NO** |
| **T-strong** | **400** | **12** | 300 | 27 | **9.00%** | 1.65 pp | **12.31%** | **NO** |
| **T-mid** | **400** | **12** | 300 | 5 | **1.67%** | 0.74 pp | **3.15%** | **NO** |
| **T-weak** | **400** | **27** | 300 | 6 | **2.00%** | 0.81 pp | **3.62%** | **NO** |
| T-mid | 400 | 27 | 300 | 2 | 0.67% | 0.47 pp | 1.61% | yes |
| T-strong | 400 | 27 | 300 | 2 | 0.67% | 0.47 pp | 1.61% | yes |

**4 of 6 `n ≥ 400` strata fail the upper-bound test.** K4's own rule: *"If any
`n ≥ 400` stratum fails to clear that upper-bound test, Design 108 §0.2's
silent-divergence argument … is read as transferring, at least partially, to
probit at this design's sizes."* It fails in four, two of them by a wide margin
(23.3% and 9.0% point estimates). **The §0.2 justification for the VA programme
is retained.**

The two-sided and one-sided (Stage-8-comparable) forms are identical on every
stratum here — no `kappa`-only contractions among L0's converged fits — so the
number is directly comparable with Stage 8's published rates. What replicates
qualitatively is the *decay with n* (n = 100 rates 19.7–61.7% → n = 400 rates
0.67–23.3%) and the *p-dependence*; what does **not** replicate is Stage 8's
"0.6% at n ≥ 1600"-style near-elimination, because this campaign has no
n ≥ 1600 tier at all and because on this DGP the weak-signal `p = 12` corner is
still at 23.3% at n = 400.

**MCSE governance: satisfied.** The threshold is 2 percentage points; the
achieved rate MCSE at n_seeds = 300 is 0.47 pp for the two passing strata, so
2×MCSE = 0.94 pp < 2 pp. The bar is resolvable at this replication, and K4's
own construction (comparing the rate's *upper* 2×MCSE bound, not its point
estimate, against the bar) is the conservative direction.

**Context worth recording alongside, descriptively.** At the same n = 400
binomial strata, L2's silent-divergence rate is 0–13.3% (13.3% at T-weak p = 12,
0.3–1.7% elsewhere, 0% at T-strong) and **VGH's is 0.00% in all six strata**.
Per §F2 and §6.2 this cross-arm comparison is **descriptive only and is not a
kill conjunct** — VGH's rate uses `degenerate & status == "ok"`, a different
instrument from the Laplace arms' `convergence == 0 & pdHess == TRUE`, and
VGH's engine self-rejects 50 fits upstream that the Laplace arms have no
analogue for. The ridge alone removes most, but not all, of L0's silent
divergence.

---

## Answer to the motivating question

**On these grids the VA route does not deliver a demonstrated payoff over the
cheap ridge remedy, and the campaign as run cannot certify one.** Three things
have to be said together. First, K1 fired and was never checked: 36% of L0
fits and 100% of L2 fits breach the pre-registration's own declared gradient
tolerance in the pre-run data that was supposed to gate the launch, and while
the L2 breach is demonstrably an instrument mismatch (an R-level ridge penalty
outside `tmb_obj$fn()`, the same defect §15 fixed for TEST A and not for the
gradient column) and the L0 breach is plausibly a tolerance chosen ten times
tighter than the package's own 1e-2, neither was adjudicated before 21,600 fits
were spent — so every accuracy number here is provisional on a stop-and-fix
that did not happen. Second, on the primary `|off-diag| ≥ 0.1` estimand the
result is genuinely split and the split is not in VA's favour: K3's literal
"VA wins" bar is cleared — cells 3, 5, 9 and 12 (`binomial_probit`, T-strong
and T-mid) survive K2, the tail-free re-computation and a bootstrap — but L2 is
better beyond the identical margin in 15 of 24 cells, including 11 of 12
ordinal cells and every n = 400 cell outside T-strong binomial, and VGH's
median error is worse than L2's in 21 of 24 cells. What VA reliably buys is not
central accuracy but the absence of a tail: VGH's `max|Λ̂|` never exceeds 3.25
anywhere in the grid against L0's 3,822 and L2's 8.87, its two-sided degeneracy
rate is 0.16% on the intersection denominator against L2's 5.36% and L0's
15.01%, and its silent-divergence rate is 0% at every n = 400 binomial stratum.
But the ridge already buys most of that at a fraction of the cost — L2 removes
L0's degeneracy from 14.8% to 5.3% and its n = 400 silent divergence from
23.3%/9.0% to 13.3%/0% — while VGH costs ~769 s/fit against L2's ~94 s, and
83% of the campaign's 365 core-hours. Third, VA's remaining advantage is
measured on a weaker instrument than the design demanded: all 7,030 VGH TEST A
certificates are the **fixed-variational fallback**, which §F1 explicitly warns
"would let VGH pass TEST A trivially", so VGH's 100% pass rate is not evidence
that its reported optima are optima of its own objective. Meanwhile K4 fired in
the *transfers* direction — Laplace's silent divergence is emphatically alive on
probit at n = 400 (up to 23.3%) — so the *motivation* for a non-Laplace route
survives; it simply is not shown to require this one. If the question is
"should Design 108 Stages 3 and 5 be built on the strength of this evidence",
the honest answer is that this campaign supports a narrow, family- and
signal-specific claim (VA beats the ridge on `Sigma_B` off-diagonals for strong
binomial-probit signal), refutes it for ordinal-probit outright, and does so
under a fired K1 and a fallback certificate — which is not the demonstrated,
consistent payoff §1 set out to require.

---

## What this campaign cannot say

- **Anything about `n = 1600`.** The confirmatory tier was cut to n ∈ {100, 400}
  under §15 on cost grounds. Both K4's headline question (does the divergence
  rate decay to negligibility at large n?) and Design 108's actual target size
  (N = 5,397) sit entirely outside the measured range. The observed decay from
  n = 100 to n = 400 is a two-point ladder.
- **Anything about the VJJ evaluator.** The §5.3 binomial-logit continuity
  block was not run. The harness was therefore never checked against Gate 3's
  known JJ-beats-GH result before it was used to make novel probit claims —
  the stated purpose of that block (§5.3).
- **Anything about the `p = 80` corner.** The exploratory cells were not run.
- **Anything about VGH ordinal cutpoints.** Withdrawn by the §17 pre-registered
  amendment before data existed; confirmed in the data as 3,480/3,480 NA with
  captured error strings. No cross-arm cutpoint comparison is possible, and
  §F3's joint (`max|Λ̂|`, `max|τ̂ − τ|`) runaway diagnostic is therefore
  unavailable for the VA arm — the family with no degeneracy detector (#897) is
  also the family where VA's joint diagnostic is missing.
- **Whether VGH's reported optima are optima of VGH's own objective.** Only the
  fixed-variational fallback certificate exists (7,030/7,030), never the primary
  re-optimised-per-`c` test §F1 requires. The pre-registration itself says why
  that distinction matters.
- **Whether L0's and VGH's gradients are comparable.** L0/L2 report
  `fit_health$max_gradient` (TMB Laplace objective); VGH reports
  `diagnostics$max_abs_gradient` (the VA engine's own). VGH's 0.00% breach rate
  is not evidence that VGH optimises more tightly than L0 — it is a different
  measuring stick, an instrument asymmetry §F2 anticipated for the degeneracy
  and silent-divergence columns but not for this one.
- **Anything about intervals, coverage, or standard errors.** Out of scope by
  §0; the VA route is `calibrated = FALSE` throughout.
- **Anything about missing data, phylogeny, spatial tiers, `q > 2`, or
  warm-started VA.** All excluded by construction (§3.7, §9, §F1's cold-start
  commitment).
- **A clean verdict on the L2 arm's optimiser behaviour**, because L2's
  gradient column measures the wrong objective. L2's convergence rate (90.26%
  overall, 53.7–69.3% in three n = 100 cells) is computed from
  `opt$convergence == 0 & pdHess`, which is not affected by that defect — but
  a reader should not read L2's 100% gradient breach as a convergence problem,
  nor its three sub-70% cells as an instrument problem.
