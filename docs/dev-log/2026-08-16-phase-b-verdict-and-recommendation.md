# Phase B verdict and recommendation — Design 118 / Design 117 §6.2

**Status:** Phase B is COMPLETE and the pre-registered design **FAILED** its hold-out
gates. `MSPL-04` stays `blocked`. No public interval, SE, or `confint()` route opens.
This document is the maintainer-signable recommendation Design 117 §6.2 asked for.

## 1. The verdict

| Gate (§5.6) | Result |
|---|---|
| G1 — ≥90% of hold-out (cell,target) rows PASS | **0.0% — FAILS** |
| G2 — no hold-out coverage < 0.90 | MEETS |
| G3 — availability ≥ 0.95 per cell | MEETS (min 1.0000) |
| G4 — anchor refusal ≤ 0.10 | **FAILS** |
| G5 — every fitted γ carries its registered sign | MEETS |

Verdict rows: **PASS 0 · FAIL 12 · INDETERMINATE 0 · NO_DATA 105** (of 117 eligible).
The five DEV-10 / [#1020](https://github.com/itchyshin/gllvmTMB/issues/1020) cells were
attributed separately and never entered a denominator. No escalation was triggered.

**"0% PASS" is mostly a denominator fact, not 117 miscovering cells:** 105 rows had no
scoreable units left because nearly everything was refused. The 12 rows that were scored
all **overcover at exactly 1.000**.

## 2. Why it failed — a degenerate optimum in the pre-registered objective

The frozen map (rung M2, `gamma0 = -1.8733`, `c_n = +0.3259`) drives α\* to
**0.00857–0.00967** on essentially every post-fence hold-out row, below the `[0.01, 0.40]`
clip — and under §1.3 a clipped row is **refused**.

Refusal is *rewarded* by the objective. `b2_eval_rows` sets `avail = !clip_refused`, and
`b2_cv_metrics` / `b2_objective_value` filter to `n_avail > 0`: **refused units vanish
from the metric entirely.** Measured directly on the 102,536-row training set:

| candidate | objective | units scored | rows refused |
|---|---:|---:|---:|
| frozen map (M2) | **0.0690** | 30 | 95,578 |
| no-refusal map | 12.985 | 264 | — |

No non-refusing candidate tested scores better than 8.38. The optimizer did not fail —
it found, correctly, that **discarding the hard cells beats calibrating them.** This is a
specification defect in §2.4's objective interacting with §1.3's clip-as-refusal, not a
coding error and not evidence that calibration is impossible.

**Independently verified.** A fresh adversarial reviewer that did not produce the
diagnosis confirmed the mechanism and rejected the benign alternatives (optimizer
non-convergence; a sign error in `b2_alpha_star`, which matches §2.3 exactly).

## 3. Three corrections to this programme's own claims

Recorded because they change what the evidence supports, not merely how it is worded.

**3.1 The headline thesis does not hold on the B1 grid.** Design 118 inherited from Phase
A the claim that failures run toward *over*coverage, "the calibratable direction". On the
B1 training data **131 of 264 units cover BELOW 0.95, minimum 0.0078.** Roughly half the
population genuinely wants α\* < 0.05. The lane-B pattern did not carry over, and any
future design must not assume it.

**3.2 The failure is fence + clip jointly, not clip alone.** 26% of hold-out refusals are
*fence* refusals independent of the calibrator — B089 (probit) refuses 444/600. Probit is
a held-out block by design (§5.1), so the calibrator extrapolates to a link it never saw
in training. That is a property of the hold-out design, and it is doing real work in the
`NO_DATA` count.

**3.3 The admission rule compares incomparable denominators.** §2.3's ladder admits a rung
on `max_err`, but `max_err` is taken over *surviving* units — so a rung that refuses more
units is scored on a smaller, easier set. This is the proximate route by which M2 was
admitted over M0, and it is a second, independent defect in the selection rule.

## 4. What survives and is reusable

- **The B1 campaign itself**: 7,920/7,920 shards, 132/132 cells, sidecar coverage complete,
  250,380 rows. Fully re-analysable without new compute.
- **The endpoint machinery**: fast-path vs registered function agree to **max |diff| = 0**
  over 102,536 rows; bootstrap re-expression to 1.07e-14; hold-out identity 1.24e-14.
- **The fence**: G3 availability 1.0000; the separation screen catches saturation exactly.
- **The #1020 finding**: sharpened to inner Laplace dimension (`n_site × q`) combined with
  cloglog's low-p tail — a genuine package defect, filed with evidence.
- **G5**: registered signs held on every fitted coefficient.

## 5. Recommendation — and what it needs from the maintainer

**Do not patch the objective and re-run against this hold-out.** The defect was diagnosable
from training alone (the fit-time log printed `clip-refused 95578/102536` *before* any
hold-out read), so a corrected objective is legitimately motivatable — but §5.7's single
hold-out read is now **spent**, and re-scoring a repaired design against the same hold-out
would convert a pre-registered test into a fitted one.

A corrected Phase B therefore requires a **new pre-registration** deciding at least:

1. **How refusal is priced.** Options: score refused rows as non-covering; add an explicit
   refusal penalty; or replace clip-as-refusal with clamping so α\* stays in band and the
   row is still scored. Each is a different estimand — pick deliberately.
2. **A denominator-invariant admission rule**, so a rung cannot win by shrinking its own
   scoring set (§3.3).
3. **A fresh hold-out**, or an explicit decision to re-gate on a newly split hold-out from
   the existing 250,380 rows, with the split declared before any refit.
4. **Whether the design still targets one global map**, given §3.1 — half the population
   wanting α\* < 0.05 and half > 0.05 may simply not be representable by the registered
   ladder, which is itself a publishable finding.

**Standing fences are unchanged.** `MSPL-04` remains `blocked`; no export, no `NEWS`,
README or article claim; every unmeasured corner (spatial, q = 2 beyond what B1 measured,
non-binary families) stays fail-closed.

## 6. Provenance

Campaign: `/home/snakagaw/gllvmtmb-local-artifacts/b1-full-20260816` (Totoro, local only,
D-50). Outputs: `~/b1-consolidated/{b2-calibrator-fit.rds, b2-holdout-verdict.csv,
b2-holdout-attributed-1020.csv, calibrator-input.csv}`. Code at `claude/mspl-b0-prereqs`.
Campaign execution record: `docs/dev-log/2026-08-16-b1-campaign-results.md`.
