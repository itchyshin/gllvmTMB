# Gate 3 — the corrected result, after a 3/3 NOT-DONE panel

**Date:** 2026-07-31. **Status:** the campaign is complete (2,160 datasets × 3 arms = 6,480 fits,
run on Totoro — see `2026-07-31-gate3-totoro-migration.md`). The first reporting pass was **wrong in
both directions** and was corrected only after adversarial review. This document is the corrected
record. **No decision is taken here**; the estimator, the R1/R2 choice and the fence remain the
maintainer's.

## How this was got wrong twice

Recorded first, because the errors are more instructive than the numbers.

1. **Overclaim.** The first pass reported *"va_jj passes 50/50"* — that is `pass_rmse` alone. The
   frozen rule is a **conjunction** (RMSE **and** collapse). Reporting half a conjunction as the
   verdict is the error.
2. **A pooled median hid the signal.** It reported that κ *"clears the contraction worry"* from a
   pooled median of 1.68. There is a real JJ contraction subgroup — `T-strong × n=400`, median
   κ 0.74, 86% of fits below 1 — invisible under the pool. This is exactly the
   *"check the gradient any pooled summary pools over"* failure the lane's own ledger warns about.
3. **Then an over-correction.** Told that GH scored better on the collapse half, the second pass
   reported a *"genuine crossover, neither arm wins."* That was also wrong: GH's collapse advantage
   is an **instrument artefact** (below), and declining a conclusion the evidence does support is a
   defect symmetric with the original overclaim.
4. **Three misquoted numbers**, all now corrected: the median `rmse_gap` is **−0.3437** (not −0.313);
   va_gh's R2 failure count is **38** (not 35 — that was an R1 figure carried across); and
   **26/35**, not all, of va_gh's R1 passes rest on a degenerate ML comparator.

A D-43 panel of three fresh reviewers returned **3/3 NOT-DONE**. An independent reimplementation then
reproduced every shipped number to float precision — **the analyser's arithmetic was never in doubt.
What failed was the reporting.**

## Three defects fixed in the analyser and runner

| # | Defect | Fix |
|---|---|---|
| 1 | R2 silently dropped 4 cells (108 → 100 rows) where the ML comparator was degenerate in **40 of 40** replicates, breaking the commitment that both rules are reported for every cell — and hiding a finding about Laplace | `.append_no_comparator_cells()` restores them as explicit `pass = NA` / `no_comparator` rows, with a printed warning naming the cells. A reporting convention, **not** a third rule: no estimand, tolerance or exclusion filter changes |
| 2 | `is.finite(x) & x <= tol` scored an **undefined** criterion as FAIL, in 6 cells where `n_ok == 0` | `ifelse(is.na(x), NA, x <= tol)` — NA propagates and is reported, never folded into the failure count |
| 3 | `max_abs_gradient` computed by the engine, dropped by the row builder | recorded, mirroring what the pre-registration already required for `max_projected_variance` |

Defect 2 was found only because the fix for defect 1 was applied inconsistently — the same class left
in place one function away.

## The corrected result

Full pre-registered conjunction. `scored` excludes cells where a criterion is undefined.

| Rule | Arm | **FULL PASS** | RMSE half | Collapse half |
|---|---|---|---|---|
| R1 (raw) | va_gh | 35/53 (1 NA) | 36/54 | 51/51 |
| R1 (raw) | va_jj | **45/51** (3 NA) | **54/54** | 45/51 |
| R2 (paired excl.) | va_gh | 12/49 (5 NA) | 13/50 | 47/47 |
| R2 (paired excl.) | va_jj | **41/47** (7 NA) | **50/50** | 41/47 |

**`va_jj` passes the RMSE criterion in every cell of the design, under both rules.** Its maximum
`rmse_gap` anywhere is **0.0393** against a 0.05 tolerance — a clean sweep, not a near miss. Head to
head and ignoring ML entirely, JJ has the lower `Sigma_B` error in **52/54** cells (R1, sign test
p = 1.7e-13) and 48/50 (R2). Leave-one-out on truth, q, p and n: JJ's R2 RMSE record is **100% in all
eleven leave-outs**. This is not carried by any one truth, rank, dimension or sample size.

### The certifiable region

> **`va_jj` passes the FULL conjunction in 100% of `q ≤ 2` cells, under BOTH rules — 36/36 (R1) and
> 34/34 (R2)** — spanning all three truths, both `n`, and every `p ∈ {8, 20, 80}`.

Because it holds under both pre-declared rules, this conclusion **does not depend on the recorded
§11 departure**. Every one of JJ's six collapse failures sits in a single corner, `q = 4` **and**
`p = 8`, nowhere else, under either rule:

| truth | q | p | n | collapse rate |
|---|---|---|---|---|
| T-mid | 4 | 8 | 100 | 0.314 |
| T-mid | 4 | 8 | 400 | 0.320 |
| T-strong | 4 | 8 | 100 | 0.444 |
| T-strong | 4 | 8 | 400 | 0.769 |
| T-weak | 4 | 8 | 100 | 0.261 |
| T-weak | 4 | 8 | 400 | 0.333 |

Their MCSEs are 0.066–0.111 and every lower 2·MCSE bound is strictly above 0.05 — genuine breaches,
not noise. Four latent axes are not identifiable from eight responses; the gate is detecting a real
identification limit.

## 🔴 The collapse criterion does not measure what it appears to

Load-bearing, and it is why the "GH wins collapse" reading is void.

**`any_axis_collapsed` is TRUE zero times in 6,480 rows for `va_gh`.** Not rare — never. Its
degenerate solutions are intercepted upstream by a variance-domain guard (165 rejections) that
**`va_jj` does not have at all**. Those rows are written `FALSE`, then removed from the collapse
denominator by `status == "ok"`: va_gh loses **39.4%** of its attempts from that denominator, va_jj
**28.2%**. The two arms are not measured with the same instrument.

Under the alternative denominator the direction **flips** (va_gh 12/54, va_jj 26/54). That reading is
not obviously right either — non-ok is not the same as collapsed — but the pre-registration's own
words (*"no filtering on status/admitted anywhere, with every attempted fit in the denominator"*)
point toward the reading in which **va_gh loses**. `analyse-gate3.R:76-84` flags this departure
honestly; it must not be dropped when the numbers are quoted.

A conflation also worth killing: *"fails collapse in ~18% of cells"* is **not** "above the 5%
tolerance." The tolerance is a **per-cell rate**. `va_jj`'s pooled collapse rate is **4.45%** on the
ok denominator and **4.31%** over all 2,160 attempts — **below** the pre-registered 5%.

## What this does and does not support

**Supported.** `va_jj` clears the full frozen conjunction across the entire `q ≤ 2` design under both
rules. Its RMSE behaviour is the best of the three arms everywhere measured. `va_gh` cannot be
recommended on RMSE: 13/50 under R2, and 26 of its 35 R1 passes rest on a compromised comparator.

**Not supported.** Any claim at `q = 4` and `p = 8` (real axis collapse). Any use of the collapse
criterion to rank the two arms (different instruments). Any statement about `n = 400, p = 80`, where
`rate_ok` falls to 6% and the RMSE is a survivor statistic — and note the earlier hypothesis that
this is a *miscalibrated health gate* was **refuted**: rejected fits there score 1.124 against
admitted fits' 1.040 (Wilcoxon p = 0.89), both at or above 1.0, the score of returning the zero
matrix. Repairing the gate would surface more usable fits, not better ones.

**Untested.** Whether the verdict reproduces on the original machine (see the migration record).

> Related: `2026-07-30-gate3-preregistration.md` (frozen design) ·
> `2026-07-31-gate0-scope-extension-and-s11-departure.md` (the recorded §11 departure) ·
> `2026-07-31-gate3-totoro-migration.md` · `docs/design/85-*` §§10-11 (READ-ONLY)
