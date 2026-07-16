# After-task — FAM-20 (`multinomial()`) D-43 re-audit → WITHHELD (`partial` holds)

**Date:** 2026-07-16 · **Author:** Claude (Fable 5, orchestrator) · **Branch:**
`agent/lane-c-multinomial` (worktree, local/unpushed). Fresh 3-lens D-43 re-audit run as a
parallel Workflow (`wf_4ab0693a-138`); each lens a fresh, independent context defaulting to
**NOT-DONE**. Companion to `2026-07-16-multinomial-baseline-arg.md`.

## Question
Can validation-debt item **FAM-20** (the `multinomial()` family) be promoted off `partial`?
The register's promotion rule requires: recovery cells pass non-skipped with a declared band
**AND** a fresh D-43 audit clears it **AND** `R CMD check`.

## Verdict — WITHHELD. FAM-20 stays `partial`.
**Two of three lenses returned NOT-DONE → D-43 withholds the claim (≥2 rule).** No public
surface advertises multinomial; nothing was promoted. The likelihood itself is correct — the
gaps are in *evidence quality* and *doc honesty*, not in the math.

| Lens | Model | Verdict | Core finding |
|---|---|---|---|
| Likelihood-correctness | Opus | **DONE** | fid-16 softmax correct; TMB objective == hand-computed softmax NLL (diff 0) and matches `nnet::multinom` to 1.66e-9 — genuine MLE. Anchor-once anti-double-count, LSE numerics, AD-safety all verified. baseline= invariance holds. No gaps. |
| Honesty / fencing | Opus | **NOT-DONE** | Register **over-claims**: (1) it says `extract_correlations()`/`extract_sigma()` "hard-refuse", but the real export is `extract_Sigma` (capital S) and `extract_Sigma(mn_fit)` returns **NULL** — it does *not* hard-refuse, and is untested. (`extract_correlations()` *does* hard-refuse — typed condition, tested.) (2) The RE/structured fence "enforced by test-multinomial.R" is only *test-driven* for the cluster `(1\|unit)` path; latent/indep/dep/phylo_*/spatial_*/random-slope rely on the shared code guard (`fit-multi.R:1840`) but no test drives them. No public NEWS/README claim (good); FAM-20 still `partial` (good). |
| Recovery-evidence | Sonnet | **NOT-DONE** | The K=3 single-seed band (abs 0.40, n=300) passes **only because `seed=1L` is a favorable draw**: an independent 30-seed replication of the same DGP found ~20% of seeds exceed 0.40 on the `trait:3` intercept (max abs error 0.65), ~25–30% across the four checked params. Bands were **borrowed by analogy from ordinal**, never calibrated (`dev/multinomial-recovery.R` was never written). The promised **K=2 byte-identity to `binomial(logit)`** cell (Design 83 §6) is **missing** — the only K=2 test checks it *errors*. K=4 (n=600, 4% exceedance) and the 5-seed aggregate (~0%) are solid. |

Suite integrity confirmed by all three lenses independently: `test-multinomial.R` **48/0/0** under
`NOT_CRAN=true`, every one of 13 `test_that` blocks non-skipped.

## Escalation judgement (Rose plan-review fix #4)
B3 (recovery, Sonnet) was flagged as the swing lens that might need an Opus re-run *if* it hit a
band-adequacy ambiguity. It did **not** return an ambiguity — it returned a concrete, empirically
replicated defect (lucky-seed fragility) it explicitly labelled "not a borderline judgment call".
An Opus re-run was therefore judged unnecessary: the verdict is decisive on its own and is
corroborated by the design doc's admission that bands were borrowed and never calibrated.

## R CMD check --as-cran — a pre-existing 1 ERROR, NOT from this diff
- Two independent `--as-cran` runs (one concurrent with the lenses, one solo/uncontended) BOTH
  return **1 ERROR / 0 WARNING / 0 NOTE**, identical signature: `FAIL 3 | SKIP 819 | PASS 5238`,
  three `actual: TRUE / expected: FALSE` expectation failures. So this is **reproducible, not a
  contention flake** (my initial hypothesis, disproven by the solo re-run).
- **The 3 failures are check-only** — they run under `R CMD check` (`is_checking()` path, ~165 more
  tests than `load_all`) but are **skipped under `devtools::load_all()` + `test_dir`**, where the
  full suite is **0 FAIL / 0 ERROR** (4560 pass / 984 skip). None are multinomial tests.
- **Causation ruled out:** commit `4d39b21a` touches exactly **4 files** — `R/gllvmTMB.R`
  (multinomial expansion only), `test-multinomial.R`, and two docs. It touches no plotting,
  profile, identifiability, or snapshot code, so it **cannot** alter these unrelated `expect_true`/
  `expect_false` results. This is **pre-existing** (environment / snapshot drift — the branch's
  prior after-task claimed 0E, which my change does not explain; a dependency/render-env shift is
  the likely cause).
- **The 3 failing tests (from a preserved-dir `--as-cran` run) — none multinomial:**
  1. `test-plot-visual-snapshots.R:321` — "dispatcher communality stacked bars" — *vdiffr:
     "Snapshot of `testcase` has changed"* (visual/render drift).
  2. `test-plot-visual-snapshots.R:334` — "dispatcher variance partition" — *vdiffr: snapshot changed*.
  3. `test-tweedie-fixed-p.R:34` — tweedie `logit_p_tweedie` TMB-mapping assertion
     (`expected all(is.na(map$logit_p_tweedie)) == FALSE`, got TRUE).
- **Separate maintainer item**, out of scope for the multinomial work and independent of the FAM-20
  verdict (withheld regardless). The two vdiffr diffs are a `snapshot_review()`/`snapshot_accept()`
  or render-env call; the tweedie assertion is a deterministic mapping check worth a look — but both
  pre-date and are untouched by `4d39b21a`.

## `extract_Sigma` finding — independently re-verified (this session)
On a live K=3 multinomial fit: `extract_correlations()` **hard-refuses** (typed
`gllvmTMB_multinomial_correlation_undefined`) as advertised; but `extract_Sigma()` (capital S; there
is **no** `extract_sigma()`) returns **`NULL`**, not the "hard-refuse" the register claimed. The
register wording is corrected; the open design question (should `extract_Sigma` hard-refuse for
consistency?) is flagged for the maintainer.

## What must happen before FAM-20 can be promoted (the backlog)
1. **Calibrate the K=3 (and re-confirm K=4) recovery bands** over 20–50 seeds — write the
   long-promised `dev/multinomial-recovery.R` and run it on **Totoro/DRAC** (never GitHub
   Actions, D-50). Replace the lucky-seed single-seed cell with a seed-robust band (or a
   multi-seed pass-rate criterion like the aggregate cell already uses).
2. **Add the missing K=2 byte-identity cell** — fit K=2 and assert numeric equivalence to
   `binomial(logit)` to ~1e-6 (Design 83 §6 target), separate from the existing "K=2 errors" test.
3. **Correct the register honesty gaps** (done in this session — see below) and decide the open
   design question: should `extract_Sigma()` on a multinomial fit **hard-refuse** (consistency
   with `extract_correlations()`) or is returning `NULL` intended? Maintainer call.
4. Optionally add tests that individually drive each fenced RE term (currently only the cluster
   path is exercised).
5. Re-run the D-43 audit; only then, with maintainer sign-off, flip the leading label and write
   NEWS/README wording.

## Doc corrections made this session (honesty, not promotion)
Surgical register edits to remove the two over-claims the honesty lens found (accurate wording +
the open `extract_Sigma` design question flagged). FAM-20 leading label unchanged (`partial`).

## Discipline
Local-only; branch unpushed. High-value negative result: a batch "looks done" would have promoted
a family whose headline recovery band is a single-seed artifact. The audit paid for itself.
