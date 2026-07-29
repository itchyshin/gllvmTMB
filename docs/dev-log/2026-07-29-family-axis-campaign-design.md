# Design — the AGHQ family-axis campaign (slice B4)

**Status: DESIGN ONLY. Not run, not funded, no compute spent.** Written 2026-07-29 while the
reasoning behind it was fresh, so the next session does not re-derive it.

## The question changed today — this records the version that survived review

**Before.** *"Why does binomial never stall — 0.0000 in 144,000 fits — when poisson is 0.7401 and
gaussian 0.8956?"* Candidate mechanisms floated: bounded support, logit curvature, absence of a
free dispersion parameter.

**After.** That framing rested on a metric whose label was broader than what it measured. The
campaign's `stalled` column is `grepl("^STALLED", stop_reason)`, which matches only the
**warm-start** stall branch (`R/fit-multi.R:5524`) out of three stuck states. See
`2026-07-29-binomial-stall-interrogation.md` and its D-43 disposition.

**The question that survives is sharper, and still unexplained:**

> Why does binomial **never return the Laplace warm start bit-for-bit** — 0 in 144,000, exact and
> flat across all 72 regime cells — while gaussian does so in 89.6% of fits?

That predicate is not a labelling accident. Its guard (`R/fit-multi.R:5521-5522`) is
`identical(par_cur, par_start_aghq) && g_cur >= grad_tol`: AGHQ returned the Laplace answer
unchanged, at a gradient above tolerance. A D-43 panel affirmed it as the defensible stall
definition and rejected the two broader ones. **So the response variable for this campaign is D1,
the warm-start indicator — not a broadened definition.**

One candidate is already dead without new compute: **absence of a free dispersion parameter**.
Poisson also lacks one and warm-stalls 74% of the time.

## Why the existing 432k campaign cannot answer it

**Bounded support and the logit link are perfectly confounded.** Only binomial has either. No
amount of re-analysis separates them, because the design contains no family that is bounded with a
non-logit link, and none that is unbounded with logit.

## The design that breaks the confound

Each row is a family; the contrasts are the columns. The families that break the confound **are**
the unmeasured families, so this single campaign discharges both open items — exercise AGHQ beyond
three families, and explain the warm-start asymmetry.

| family | fid | support | link | free dispersion | role in the design |
|---|---|---|---|---|---|
| binomial | 1 | bounded | logit | no | the anomaly: 0/144,000 |
| betabinomial | 8 | bounded | logit | **yes** | binomial + dispersion — isolates dispersion |
| Beta | 7 | bounded (0,1) | logit | yes | continuous bounded — separates support from discreteness |
| ordinal_probit | 14 | ordered | **probit** | no | **bounded WITHOUT logit — the key cell** |
| poisson | 2 | unbounded ≥0 | log | no | 0.7401 |
| nbinom2 | 5 | unbounded ≥0 | log | yes | poisson + dispersion |
| Gamma | 4 | unbounded >0 | log | yes | continuous analogue of poisson/nbinom2 |
| lognormal | 3 | unbounded >0 | log | yes | log-link continuous, second reading |
| gaussian | 0 | unbounded ℝ | identity | yes | 0.8956, the opposite extreme |
| student | 9 | unbounded ℝ | identity | yes | gaussian + heavy tails |

**The decisive cell is `ordinal_probit`**: bounded and discrete but *not* logit. If it behaves like
binomial, support is the mechanism and the link is not. If it behaves like gaussian, the link is.

**Crossed with:** `lam_sd ∈ {0.5, 1, 2, 3}` — the one factor with a demonstrated monotone
dose-response — and `n ∈ {100, 200, 400}`. Hold `aghq_k` fixed at 9 unless a node arm is
specifically wanted; the paired-design finding below means a node arm needs a paired analysis.

## Requirements carried forward from what went wrong

1. **Record the stop branch as a categorical column**, not free text. The entire H3 detour happened
   because `stop_reason` had to be regex-matched. Emit the branch identity directly, plus a numeric
   `max_abs_grad` — the gradient is currently interpolated into a string and has to be parsed back
   out.
2. **Assert `aghq_used == TRUE` per family before any number counts.** AGHQ eligibility is narrow
   and structural; a family that silently routes to Laplace yields measurements that look valid and
   mean nothing. Verified for gaussian/poisson/Gamma (81 nodes at d=2, k=9); unverified for the rest.
3. **Pass explicit links.** `stats::Gamma()` defaults to `inverse` and is rejected; that is what
   made Gamma look like a crash. `dev/aghq-families/family_spec.R` already does this for all 16.
4. **The design is PAIRED if a node arm is included.** Every DGP is fit once per `aghq_k` with
   `eta_max` byte-identical across levels. Unpaired MCSE is the wrong variance — use McNemar. This
   is what invalidated the H3-inversion claim; do not repeat it.
5. **Synthesize a row on worker death.** Every R-catchable error already yields a row, but a native
   crash under `mclapply` returns `NULL` silently and the harness cannot detect it.
6. **Smoke first**, one rep per family, reading values past the guards — not merely row counts.

## Reuse, do not rebuild

`dev/aghq-families/{driver,family_spec,kill_rule,run_family}.R` (commit `23aca9c0`) already builds
cells for all 16 admitted families and is audited
(`2026-07-29-aghq-family-harness-audit.md`). It was **built but never run to completion** — there
are no results files for it anywhere. It needs the two new columns from requirement 1, not a
rewrite.

## Cost

Not estimated. The certificate campaign (2 cells × 20k reps) is ~172 CPU-hours; this design is
10 families × 4 `lam_sd` × 3 `n`, so per-rep cost and rep count must be smoked before any estimate
is quoted. **Do not launch on an unmeasured estimate.**
