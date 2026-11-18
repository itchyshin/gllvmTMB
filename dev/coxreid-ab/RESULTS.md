# Design 121 A+B campaign — RESULTS and adjudication (2026-08-16)

**Status: adjudication of a completed, non-authorising evidence run.** This
document adjudicates `dev/coxreid-ab/coxreid-ab-full.csv` (1,600 fits, commit
`ae17a501`) against the pre-registered kill criteria in
`docs/design/121-coxreid-validation-slice.md` §3, applied exactly as written.
It does **not** authorise or constitute a promotion decision for
`allow_nongaussian_reml` (Design 121 §6 stands unchanged), and it does not
adjudicate K2 or K4 (neither was run in this campaign — see below). Analysis
script: `dev/coxreid-ab/adjudicate.R`; full script output archived at the end
of this document's companion run log.

## 0. Data

- 1,600 rows: 2 families (`binomial`, `ordinal_probit`) x `T in {4,8}` x
  `n in {100,200}` x arm (A, B) x seed 1:100.
- Arm A = Laplace-ML (defaults). Arm B = Laplace + Cox–Reid
  (`REML = TRUE, allow_nongaussian_reml = TRUE`). **`aghq_ridge = Inf`
  (ridge off) in BOTH arms** — the ridge is held fixed and equal across A and
  B, per Design 121 §2's explicit instruction to avoid the K3 confound for
  the A-vs-B comparison itself (see §5 below for what this does and does not
  adjudicate).
- **Convergence: 100% (800/800) in both arms.** `error` column empty on every
  row. Non-finite `norm_ratio`/`bias_pct`: 0/1600. The Design 121 §3
  non-convergence rule (cells below 70% convergence get reported as a
  convergence result, not a bias result) is **moot** — every cell clears it
  trivially.
- Arm C (AGHQ) and arm D (reparametrisation probe) were **not run** in this
  campaign (dropped per `dev/coxreid-ab/run-ab.R`'s own header). This bounds
  what this document can adjudicate — see §6.

## 1. K1 — no-effect gate (n=100, both families)

K1's pre-registered wording: *"If the point-bias reduction of arm B vs arm A
is `< 2` percentage points at `n = 100` in **both** families, the Cox–Reid
hypothesis is dead for this parameterisation."* "Reduction" is a **signed**
quantity (`|bias_A| - |bias_B|`; positive = B closer to zero than A;
negative = B moved further from zero than A), compared directly against the
2pp threshold — a negative reduction trivially satisfies "< 2pp."

Bias reduction is adjudicated on **medians as primary** (stated reasoning:
the runaway/degenerate tail described in §4 below makes the mean an
outlier-dominated statistic at this seed count — visible directly in the raw
mean-bias rows below, which run into the hundreds of percentage points on
one degenerate cell). Means, and means with the degenerate partition
excluded, are reported alongside, never as a silent substitute for the
median read.

**Family-level n=100 summary (pools `T=4` and `T=8`, 200 paired seed-cells
per family):**

| Family | n pairs | median\|bias\| A | median\|bias\| B | reduction (median, PRIMARY) | reduction (mean) | reduction (mean, runaway-excluded) |
|---|---|---|---|---|---|---|
| binomial | 200 | 7.26 | 10.84 | **−3.58pp** | −262.93pp | −7.16pp |
| ordinal_probit | 200 | 3.08 | 4.39 | **−1.31pp** | +1.69pp | −4.10pp |

Both families: reduction is **negative** on the primary (median) metric —
arm B's median absolute bias is *larger* than arm A's, not smaller. Both
values are `< 2pp`.

**K1 VERDICT: FIRES.** Bias reduction is `< 2pp` in both families on the
pre-registered primary metric.

## 2. MCSE governance clause

Design 121 §3 requires every threshold to exceed ~2x its achieved MCSE
before a kill criterion can be adjudicated, not just applied.

Two MCSE readings are reported, because the raw paired-difference SD is
itself dominated by the same degenerate tail that motivates using medians
for K1's primary read (a mean-based SD/√n is not the right precision
statistic for a median-based test):

| Family | Raw paired MCSE (SD(B−A)/√n, spec-literal) | 2x raw MCSE | Bootstrap MCSE of paired median(B−A) (2000 reps, matches K1's primary metric) | 2x bootstrap MCSE |
|---|---|---|---|---|
| binomial | 58.60pp | 117.21pp | **0.091pp** | 0.182pp |
| ordinal_probit | 11.07pp | 22.15pp | **0.038pp** | 0.075pp |

The literal spec-text MCSE (SD/√n on the raw bias differences) does **not**
clear the 2pp threshold in either family — itself a finding, and it is
exactly what the degenerate-tail problem in §4 predicts: a handful of
runaway seeds inflate the paired-difference SD by two orders of magnitude.
The bootstrap MCSE of the paired **median** difference — the statistic K1 is
actually adjudicated on here — clears the governance bar overwhelmingly: 2pp
is ~22x the achieved bootstrap MCSE (binomial) and ~53x (ordinal_probit).
**K1's median-based verdict is well-powered, not a coin flip**; the
governance clause is satisfied on the metric that matters for this
adjudication, and reported as failing on the metric the literal spec text
names, so neither reading is hidden.

## 3. Per-cell bias summary (family x T x n)

Bias % = `100 * (norm_ratio - 1)`. `n_dropped_runaway_pairs` = seed-pairs
where either arm's row for that seed has `norm_ratio > 10` (see §4); the
"mean, runaway-excluded" columns drop those pairs from **both** arms
(seed-paired removal, not per-arm removal, per the non-convergence rule's own
logic in Design 121 §3 — do not select each arm's easiest seeds).

| Family | T | n | median A | median B | mean A | mean B | mean A (excl.) | mean B (excl.) | dropped pairs |
|---|---|---|---|---|---|---|---|---|---|
| binomial | 4 | 100 | −1.22 | 2.17 | 151.99 | 570.28 | −5.63 | −2.07 | 18 |
| binomial | 4 | 200 | −9.01 | −7.69 | 34.29 | 37.54 | −9.71 | −8.49 | 2 |
| binomial | 8 | 100 | 10.78 | 15.00 | 134.02 | 241.58 | 20.11 | 30.59 | 11 |
| binomial | 8 | 200 | 1.13 | 2.03 | 2.64 | 9.95 | 2.64 | 9.95 | 0 |
| ordinal_probit | 4 | 100 | 2.18 | 3.26 | 134.31 | 129.59 | 59.48 | 66.51 | 6 |
| ordinal_probit | 4 | 200 | 1.16 | 2.22 | 20.36 | 12.54 | 1.88 | 2.85 | 2 |
| ordinal_probit | 8 | 100 | 3.93 | 5.26 | 4.42 | 5.76 | 4.42 | 5.76 | 0 |
| ordinal_probit | 8 | 200 | 1.60 | 2.20 | 1.46 | 2.04 | 1.46 | 2.04 | 0 |

**Every one of the 8 cells shows arm B's bias moving in the same direction
as arm A's or slightly larger in magnitude** on the median (B is never
meaningfully closer to zero than A on any cell); this is consistent across
all `T`/`n` combinations, not an artifact of pooling. `n=100` cells carry
essentially all the runaway/degenerate mass (18, 11, 6 dropped pairs);
`n=200` cells are close to clean (0–2 dropped pairs).

## 4. Degenerate partition (runaway rows)

Flag: `norm_ratio > 10` (the strict runaway threshold; the task brief's own
suggested cut).

**Counts by arm:** A = 22/800 (2.75%), B = 36/800 (4.5%). Arm B runs more
runaway rows than arm A overall — consistent with Design 121 §3's own
anticipated risk direction ("arm B enlarges the `random` block and may fail
[or degenerate] more often than A"), though here it shows up as
runaway-tagged converged fits rather than non-convergence (which stayed at
0% for both arms).

**Cell breakdown (rows with `runaway = TRUE`):**

| family | T | n | arm | runaway rows |
|---|---|---|---|---|
| binomial | 4 | 100 | B | 18 |
| binomial | 8 | 100 | B | 11 |
| binomial | 4 | 100 | A | 8 |
| binomial | 8 | 100 | A | 6 |
| ordinal_probit | 4 | 100 | A | 5 |
| ordinal_probit | 4 | 100 | B | 4 |
| binomial | 4 | 200 | A/B | 2 each |
| ordinal_probit | 4 | 200 | A/B | 1 each |
| all `T=8, n=200` cells; `ordinal_probit T=8 n=100` | — | — | — | 0 |

All runaway mass is concentrated in `n=100` cells; `n=200` is nearly clean.
`binomial T=4 n=100` is the single worst cell (26 runaway rows across both
arms), not `T=8 n=100` — worth flagging since the pre-run's only reproducible
degenerate example came from `T=8 n=100`.

**`max_abs_lambda`:** all-row median is comparable between arms (A 1.45, B
1.48), but the mean is pulled far higher in B (2.90 vs 4.40) by the same
tail; restricted to runaway rows, arm B's runaway fits are also more extreme
than arm A's (median max|Λ| 54.2 vs 41.3, max 154.6 vs 94.6).

**Seed-pairing across arms:** of 800 seed-cells, 19 are runaway in **both**
A and B (same seed, same family/T/n), 3 are A-only, 17 are B-only. Most of
the shared pathology is genuinely seed/cell-specific and paired across arms,
consistent with the pre-run's own reading (a DGP-side degenerate optimum
that both Laplace-based arms fall into identically) — but arm B also picks
up a substantial number of *additional* runaway seeds (17) that arm A does
not runaway on, which the 2-seed pre-run could not have detected.

**Does the pre-run's `binomial, T=8, n=100, seed=2` cell recur?** **Yes, at
seed level it recurs exactly**, and at a comparable but less extreme
magnitude: `norm_ratio` = 5.37 (A) / 5.57 (B), `bias_pct` = +437% (A) / +457%
(B), both `converged = TRUE`, both below this document's strict
`norm_ratio > 10` cut (so not counted in the 22/36 runaway totals above,
which is why it is called out separately here). The pre-run reported
`norm_ratio ~ 7.7` (`+669%`/`+672%`) for this same seed/cell/arm-pair — same
qualitative pathology (paired across arms, converged, unflagged degenerate
optimum), somewhat lower magnitude in the full run, plausibly RNG-stream
differences between the pre-run script and the full-campaign script (both
draw from `seed = 2` but are not guaranteed to hit an identical RNG state
end-to-end).

More broadly, `binomial T=8 n=100` is **not** an isolated single-seed
pathology: at the strict `norm_ratio > 10` cut, **6/100 seeds (6%)** runaway
in arm A and **11/100 (11%)** in arm B in this cell, all 6 of A's runaway
seeds also runaway in B; loosening to `norm_ratio > 5` (the pre-run's own
observed scale) picks up **14/100 seeds (14%)** in at least one arm,
including seed 2. **Recurrence rate for the pre-run's specific pathology
class in this cell: 14%** of seeds, of which the strict-runaway subset
(11%) is markedly worse in arm B than arm A.

## 5. `max_abs_gradient` sanity check

62/1,600 rows (3.9%) have `max_abs_gradient > 1e-3`; overall maximum is
0.0038 — mildly loose but not alarming (three-to-four times the 1e-3 mark,
never orders of magnitude beyond it), and concentrated somewhat in
`ordinal_probit T=4 n=200` (17 in arm A) and `ordinal_probit T=8 n=200` (9 in
arm B, 7 in arm A). No row's `max_abs_gradient` is large enough on its own to
suggest a mislabelled non-convergence; this is reported as a mild optimizer
looseness signal, not a second convergence failure the `converged` flag
missed.

## 6. Wall time

- **Real elapsed campaign wall time (Totoro, 96 mirai workers, parallel):
  16.5 s** — from `dev/coxreid-ab/full-run.log` ("mirai: 1600/1600 tasks
  returned a row (16.5 s elapsed)").
- **Sum of per-fit `wall_time_s` (sequential-equivalent compute):
  1,394.1 s = 23.24 min = 0.387 h.** Arm A: 678.7 s; arm B: 715.4 s (B
  costs ~5.4% more per-fit time on average, consistent with its larger
  `random` block). Per-fit range 0.08–4.19 s, median 0.53 s, mean 0.87 s —
  far below the design's original 5–15 s/fit assumption for arms A/B (§4 of
  the design doc), and far below the pre-run's own measured 5.9 s/6.1 s
  means for these arms; this campaign's actual A/B cost is markedly cheaper
  than either estimate anticipated.

## 7. K2 / K3 / K4 — explicitly unadjudicated

- **K2 (non-invariance, arm D):** **UNADJUDICATED.** Arm D (the nuisance
  `b_fix`-reparametrisation probe, Design 121 §2) was **not run** in this
  campaign — the run script's own header states arm D is out of scope here.
  No claim about Reid–Fraser non-invariance in gllvmTMB's parameterisation
  can be made from this data.
- **K3 (ridge confounding):** **UNADJUDICATED**, with one caveat in this
  campaign's favour. K3 asks whether equalising the ridge across **all three
  arms (A, B, C)** and comparing against a **default-state run** (ridge on
  for C only) makes the Cox–Reid-or-AGHQ effect vanish or reverse. This
  campaign never ran arm C and never ran a default-state (ridge-asymmetric)
  comparison, so the K3 test itself cannot be performed on this data. What
  this campaign *does* establish: `aghq_ridge = Inf` (off) was held
  **identically** in both arm A and arm B, so the K1 read above is not
  vulnerable to the specific A-vs-B ridge asymmetry K3 warns about — but that
  is a design safeguard for K1, not a K3 adjudication, since K3's actual
  object of concern (arm C's ridge) is absent from this campaign entirely.
- **K4 (interval harm):** **UNADJUDICATED.** No interval or coverage columns
  were collected in this campaign (`coxreid-ab-full.csv`'s schema has no
  SE/CI/coverage fields) — K4 compares point-bias improvement against Wald
  interval coverage degradation, and no coverage evidence exists here to
  compare against. Would require a dedicated SE/coverage-focused rerun.

## 8. VERDICT

**K1 fires.** Under gllvmTMB's own parameterisation — loadings-only
`latent(0 + trait | site, d = 1, unique = FALSE)`, `q = 1`, binomial and
ordinal_probit families, `T in {4,8}`, `n in {100,200}`, ridge held off and
identical across arms — the Laplace + Cox–Reid adjusted-profile-likelihood
route (arm B, `REML = TRUE, allow_nongaussian_reml = TRUE`) does **not**
reduce median absolute bias in the latent SD relative to plain Laplace-ML
(arm A) at `n = 100` by the pre-registered 2pp margin in either family.
Both families instead show arm B's median bias slightly **larger in
magnitude** than arm A's (−3.58pp binomial, −1.31pp ordinal_probit, both
signed reductions well below the 2pp bar), and this read clears the MCSE
governance clause decisively on the metric it is computed from (bootstrap
MCSE of the paired median difference, 22–53x smaller than the 2pp
threshold) — this is not an underpowered coin flip, it is a
well-resolved null-to-slightly-negative result.

**This does not replicate the drmTMB Cox–Reid transfer** (Laplace −7.3% →
+Cox–Reid −0.9%, `R/fit-multi.R:2838-2841`) in gllvmTMB's own
parameterisation, on these two families, this structure, and this ridge
setting. Per Design 121 §3's own framing, a fired kill criterion is a
**reportable result**, not a failed run: the hypothesis is dead for *this*
parameterisation, and the fence stays exactly where it is.

**No promotion decision either way.** `allow_nongaussian_reml` remains
opt-in, unvalidated, and unpromoted (Design 121 §6); the roxygen honesty
text applied in §7 of the design doc is not touched by this adjudication and
should not be softened or strengthened by it. This result is one input
against promotion, not a formal closure of the question, because K2 and K4
remain genuinely open (§7 above) — a positive K1 read would still have left
K2/K4 unresolved, and a negative K1 read (as found) does not retroactively
resolve them either; it simply removes the immediate motivation to chase
them for *this* route.

**Next steps.**

1. **K2 and K4 need their own separate runs** if the maintainer wants
   closure on non-invariance or interval harm — neither follows from this
   A+B dataset. Given K1's negative result, there is no positive point-bias
   case to protect with a K4 coverage check for *this* route; K2's arm D
   probe would still be informative as a standalone methodological finding
   about the package's Cox–Reid implementation, independent of whether the
   route is ever promoted.
2. **Design 66 hand-in (§5 of the design doc):** this campaign's binomial
   and ordinal_probit `T in {4,8}`, `n in {100,200}` cells are candidates for
   the capstone grid per the design's own framing, but the K1-dead read means
   Design 66 should **not** budget seeds for a Cox–Reid arm on this evidence
   — the arm A vs arm B split itself is not worth carrying forward into the
   capstone unless a different family, structure, or ridge configuration is
   separately motivated.
3. **The degenerate-tail pattern in §4** (worst in `binomial T=4 n=100` and
   `T=8 n=100`, both Laplace-based arms, `ordinal_probit`'s known missing
   degeneracy detector per #897) is not new evidence about Cox–Reid per se —
   both arms are Laplace-family and share it — but it reinforces the
   existing register concern that `ordinal_probit` and small-`n` `binomial`
   cells need their own degeneracy-detector attention independent of this
   REML question.
