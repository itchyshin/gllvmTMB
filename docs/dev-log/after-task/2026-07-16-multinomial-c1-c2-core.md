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

## Follow-up (remaining, not this session)
- **C1c — S3 surface:** `predict(type="response")` per-category probabilities; `predict("link")` K−1
  etas; `fitted.gllvmTMB_multi`; `simulate()` group-blocked softmax draw (add `16L` to `supported`);
  `residuals()` → `unsupported_family`; **`extract_correlations()`/`extract_sigma()` hard-refusal** for
  a fid-16 trait (currently a fixed-effects-only fit has no covariance tier, so it errors/empties, but an
  explicit typed refusal is cleaner and is a stated fence).
- **C2 full:** K=4 cell; 5-seed aggregate; K=2 byte-identity to `binomial(logit)`; mixed
  gaussian+poisson smoke; `dev/multinomial-recovery.R` band calibration on Totoro/DRAC.
- **C3:** honesty fencing (NEWS.md, README family matrix — roxygen done) + **Rose D-43 audit**
  (default NOT-DONE) before ANY public capability wording; then flip FAM-20 off `partial`.
- **Vf:** `document()` to generate `man/multinomial.Rd`; local `R CMD check --as-cran` 0E/0W/0N.

## Discipline notes
Isolated Lane-C worktree; scoped staging; local commits, no push. HIGH-RISK likelihood authorized
2026-07-16; `tmb-likelihood-review` applied via the self-review. FAM-20 stays `partial` (no D-43 audit
yet) — no public capability claim made.
