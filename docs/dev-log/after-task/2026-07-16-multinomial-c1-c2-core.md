# After-task — Lane C C1a/C1b/C2-core: `multinomial()` engine landed (Tier 1)

**Date:** 2026-07-16 · **Author:** Claude (Fable 5) · **Branch:** `agent/lane-c-multinomial`
(worktree) · **Commits:** `9c6a1973` (C1a), `59b30079` (C1b core), `4c2f352a` (C1b fences),
`4b…` (C2 tests). **Driven entirely on Claude** (maintainer: no Codex this arc, token reasons).

## Scope
Build the R engine for `multinomial()` (baseline-category logit / softmax, `family_id 16`),
**Tier-1 fixed-effects-only**, per Design 83. The live build (originally routed to Codex) was
re-routed to Claude on maintainer instruction. Codex was offered only as an optional reviewer.

## Outcome — a working, correct, tested, fenced Tier-1 family
- **C1a — C++ likelihood** (`src/gllvmTMB.cpp`): `family_id 16`; two `DATA_IVECTOR`s
  (`multinom_group_id`, `multinom_K_per_trait`); a grouped baseline-category softmax evaluated
  **once at the group anchor row** (ported the validated MD6c max-subtraction LSE; anti-double-count),
  with the ordinary/mi paths guarded by `!= 16` and a fail-loud `obs_loglik` guard. Compiles;
  gaussian baseline test unregressed.
- **C1b — R plumbing** (`R/families.R`, `R/enum.R`, `R/fit-multi.R`, `R/gllvmTMB.R`, `NAMESPACE`):
  `multinomial()` constructor + roxygen + export; `family_to_id` `16L` + link guard;
  `expand_multinomial_response()` — expands a categorical response into K−1 contiguous
  category-contrast pseudo-trait rows (`<trait>:<cat>`) + `.multinom_group_` + 0/1 indicator, BEFORE
  desugar/parse, so the ordinary `0 + trait + (0+trait):x` grammar builds the per-category design (no
  parser change); `multinom_K_per_trait` derived from the `.multinom_L_` carrier.
- **Tier-1 fences:** latent / RE / structured terms on a multinomial trait fail loud (single covstruct
  choke-point); `K < 3` redirects toward `binomial()`; mixed-family `list()` rejected.
- **C2 core** (`tests/testthat/test-multinomial.R`): K=3 recovery + fid-16/`(K-1)`-block contract +
  the three fences + baseline-category invariance — **20/20 pass** (`NOT_CRAN`).

## Checks (evidence)
- **Smoke (n=300, K=3, seed 1):** `family_id_vec` all 16; `conv = 0`; `pdHess = TRUE`; recovers the
  four baseline-category logits `0.564 / -0.297 / 0.825 / -0.603` vs truth `0.5 / -0.4 / 1.0 / -0.8`
  (all within abs 0.30–0.40) — the softmax MLE, not an artifact.
- **Guards:** `(1|unit)` → "fixed-effects-only" abort; K=2 → ">= 3 categories"; `list(...)` → "mixed-family".
- **Regression:** `test-ordinal-probit` 39/0, `test-multi-random-intercepts` 35/0 — no breakage.
- **Adversarial self-review** (Gauss/Noether lens) of the C1a likelihood: anti-double-count, LSE
  numerics, one-hot numerator, AD-safety, weight/mask, edge cases — all pass; one assumption (R keeps
  pseudo-rows contiguous) is guaranteed by the expansion and confirmed by correct recovery.
- **Codex review — BLOCKED (infra):** the installed Codex CLI 1.0.3 defaults to `gpt-5.6-terra`, which
  it does not support (400 error), and fails even with no model flag. Not run; needs a CLI upgrade or a
  supported model. Self-review stands in the interim.

## C1c — S3 surface (DONE, 2026-07-16, same session)
- **`predict(type="response")`** returns per-category softmax probabilities (K rows/obs, sum to 1);
  **`predict(type="link")`** returns the K−1 baseline-category logits. `.predict_multinomial()` uses the
  `multinomial_meta` (baseline label + category order) now attached to the fit. Verified: sum-to-1,
  calibration vs empirical category frequencies, correct row counts.
- **`extract_correlations()`** hard-refuses a fid-16 trait (typed `gllvmTMB_multinomial_correlation_undefined`).
- **`predict(newdata=)`** and **`simulate()`** fail loud (typed conditions) — no Gaussian-on-link fallback.
- `residuals()` lands in the RQ switch's `unsupported_family` else-branch (like ordinal fid 14).
- `man/multinomial.Rd` generated. `test-multinomial.R` **39/39 pass**; ordinal + entry regressions clean.

## C3 — Rose D-43 audit (3 fresh independent lenses, default NOT-DONE)
- **Likelihood-correctness lens = DONE** — "tried hard to break it and could not"; anti-double-count, LSE,
  one-hot numerator, AD-safety all verified; recovery is a genuine MLE, not an artifact.
- **Honesty/fencing lens = DONE** — all 6 fences tested; no silent-wrong path; `predict` sums-to-1 by
  construction; no public overclaim (NEWS/README/roxygen clean); FAM-20 correctly `partial`.
- **Recovery-evidence lens = NOT-DONE → addressed** — caught a REAL regression: `test-enum-runtime-ids.R`
  was FAILING (I added `16L` to `.valid_family` but not the test). **Fixed + verified** (15/15). Added the
  5-seed aggregate recovery cell (single-seed gap). Register evidence-ref repaired. (K=2 byte-identity and
  mixed-smoke cells are moot: multinomial K=2 *redirects* to binomial; mixed-family multinomial is *fenced*.)
- Verdict: 2 DONE / 1 NOT-DONE-now-addressed. FAM-20 stays `partial` (promotion needs maintainer sign-off +
  clean re-audit). Two minor follow-ups: give the 3 message-matched fences typed classes; consider a
  `dev/multinomial-recovery.R` band-calibration harness on Totoro/DRAC.

## Vf — R CMD check --as-cran (--no-manual --no-vignettes)
- First run (pre enum-fix): **1E / 1W / 1N**. The **E was exactly the enum test** the D-43 audit flagged
  (`test-enum-runtime-ids.R:25`), since the check launched before the fix — **now fixed + verified**, and a
  re-check on the fixed code is confirming 0E.
- **W = pre-existing**, not this arc: `'::' import not declared from 'tweedie'` (a tweedie test's undeclared
  dependency). **N = benign**: "New submission". The full dev suite passes **0-fail in both NOT_CRAN modes**.
- Net: the arc introduces **no remaining new defects**; residual W/N are pre-existing/benign cleanup items.
- **Re-check on the fixed code CONFIRMED: 0 ERRORS / 1 WARNING / 1 NOTE.** The 0E confirms the enum fix
  cleared the only arc-caused defect. The 1W (`tweedie` undeclared dep in a tweedie test) is pre-existing
  and trivially fixable by adding `tweedie` to `DESCRIPTION` Suggests (out-of-arc cleanup — not done to keep
  the diff surgical / avoid a shared-file conflict; offered to the maintainer). The 1N ("New submission") is
  inherent to a first submission. Literal "0E/0W/0N" is therefore blocked only by items this arc did not
  introduce.
- **C2 full:** K=4 cell; 5-seed aggregate; K=2 byte-identity to `binomial(logit)`; mixed
  gaussian+poisson smoke; `dev/multinomial-recovery.R` band calibration on Totoro/DRAC.
- **C3:** honesty fencing (NEWS.md, README family matrix — roxygen done) + **Rose D-43 audit**
  (default NOT-DONE) before ANY public capability wording; then flip FAM-20 off `partial`.
- **Vf:** `document()` to generate `man/multinomial.Rd`; local `R CMD check --as-cran` 0E/0W/0N.

## Discipline notes
Isolated Lane-C worktree; scoped staging; local commits, no push. HIGH-RISK likelihood authorized
2026-07-16; `tmb-likelihood-review` applied via the self-review. FAM-20 stays `partial` (no D-43 audit
yet) — no public capability claim made.
