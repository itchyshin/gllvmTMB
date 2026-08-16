# Design 66 scoping one-pager — three claimants, one seed budget (2026-08-16)

For the capstone-scoping conversation. Everything below is input; the cells,
seeds, families, gate, and compute split are Shinichi's call. The rule this
page enforces: **one merged grid, one seed budget** — no freestanding
campaigns duplicating cells.

## The three claimants

### 1. VA-vs-Laplace recovery study — recommended FIRST

The standing recommended next arc (Live Phase Snapshot, 2026-08-02): the
4,320-fit campaign partly undercut Design 108 §0.2's own justification
(Laplace silent divergence decays with n; `aghq_ridge = 2` suppresses it),
and Stage 7 records tips-vs-augmented as statistically unsettled. This study
tests the premise the 10,000-species programme rests on — it goes first
because its answer changes what the other two claimants should even measure
against. Scope: needs Shinichi (cells/seeds/families/gate).

### 2. Cox–Reid REML slice (Design 121) — recommended SECOND, after redesign of arm C

Pre-registered in `docs/design/121-coxreid-validation-slice.md`; the D-139
pre-run test (48 fits) RAN 2026-08-16 — results in
`dev/coxreid-prerun/RESULTS.md`. What it measured changes the ask:

- **Cost:** ~18.2 h sequential-equivalent for the full 2,400 fits — not the
  3–10 h assumed. Arms A/B (Laplace ± Cox–Reid) are cheap (~6 s/fit; the
  A+B half of the grid is ~2.7 h); **arm C (AGHQ k=7, ridge `Inf`) is the
  entire overrun** (mean 69.9 s, max 345 s).
- **Arm C is not runnable as designed:** 9/16 converged (56%), below the
  design's own 70% cell bar. Ridge-off AGHQ is unstable here; the ridge
  choice needs a decision (all-on at a named value, or a lower `k`, or
  drop arm C into the VA-vs-Laplace study where AGHQ is already scoped).
- **Effect-size reality check (2 seeds — direction only, not evidence):**
  binomial medians A +2.4% vs B +3.8%; ordinal A +2.2% vs B +3.3%. The
  drmTMB prior predicted CR pulls a *downward* Laplace bias toward zero; at
  these scales the point bias is already near zero-to-positive and CR
  nudged it *up*. If 100 seeds confirm that, **K1 fires and the hypothesis
  dies cheaply** — which is a publishable negative and a fine outcome.
- **A Cox–Reid-orthogonal finding:** one reproducible degenerate cell
  (binomial, T=8, n=100, seed 2: ratio ~7.7, identical in arms A and B).
  Per the partition-failures-by-mechanism rule, the full run should
  pre-classify runaway fits (report `max|Lambda|` per arm) rather than
  average over them.

**Recommended shape if approved:** run the A+B half (~2.7 h, Totoro,
trivially within D-143) with 100 seeds to adjudicate K1 properly; hold arm
C until the ridge/k decision, or fold AGHQ evidence into claimant 1.

### 3. Slope-evidence cells — recommended THIRD

Serves the standing 2026-08-01 directive ("at least one random slope per
distribution") and the paper's calibration story: PHY-11 (binomial indep
recovery), PHY-16 (ordinal indep recovery, currently 3/6 converged),
RE-14 promotions (lognormal/Student-t/betabinomial beyond C1 admission),
CI-08/CI-10 interval calibration. Sequenced third on Fisher's argument:
certifying slope calibration on an engine with unresolved variance-bias
questions risks blessing two cancelling errors — claimants 1 and 2 settle
the engine questions first. Note the unhidden slope article (2026-08-16) is
already register-honest about these gaps, so nothing user-facing is blocked
on this claimant.

## Decision boxes (Shinichi)

- [ ] Claimant order confirmed / reordered: ______
- [ ] VA-vs-Laplace: cells/families/seeds/gate: ______
- [ ] Cox–Reid A+B half at 100 seeds (~2.7 h Totoro): approve / defer
- [ ] Arm C: ridge value + k: ______ / fold into claimant 1 / drop
- [ ] Slope cells admitted to the grid now / after 1–2 report: ______
- [ ] One seed budget total (fits): ______

## Provenance

Pre-run: `dev/coxreid-prerun/` (48/48 rows, smoke-first, ridge pinned
`Inf`, two harness corrections documented in RESULTS.md). Kill criteria and
MCSE clause: Design 121 §3. Compute rules: D-139, D-143, D-50 (no Actions).
