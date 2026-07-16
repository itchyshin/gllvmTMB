# After-task — FAM-20 (`multinomial()`) PROMOTED to `covered` (fixed-effect route)

**Date:** 2026-07-16 · **Author:** Claude (Fable 5) · **Branch:** `pr/multinomial-family` (PR #749).
Closes the multinomial arc: after a withheld first re-audit → gap closure → a **clean promotion-gate
re-audit** → maintainer sign-off, FAM-20 is promoted off `partial`.

## Gate — fresh 3-lens D-43 re-audit (all DONE)
Workflow `wf_9232b92b-6ef`, each lens fresh + defaulting NOT-DONE, on the final main-based state:
- **Likelihood = DONE** — TMB objective vs `nnet::multinom` diff 1.3e-8 (K=3) / 3.6e-8 (K=4);
  baseline invariance exact (spread 1.9e-11); C++ fid-16 kernel unchanged since the prior DONE.
- **Honesty = DONE** — all 9 fences loud, incl. **both** typed refuses `extract_correlations()`
  and the new `extract_Sigma()` on a live fit; Design 83 §3/§6 + register internally consistent
  (no phantom test names; `extract_Sigma` documented as aborting; no `extract_sigma`); **NEWS/README
  clean pre-promotion**. Two non-blocking doc cracks found → fixed (below).
- **Recovery = DONE** — calibrated 20-seed aggregate cells confirmed seed-robust (not lucky-seed);
  independently reproduced (60-seed sweep, unbiased, band ~4 SD margin); `dev/multinomial-recovery.R`
  is a genuine calibration, not a borrowed band.

**0 NOT-DONE → gate clears.** Maintainer sign-off given 2026-07-16. (Load-bearing claims were
re-verified by the orchestrator: NEWS/README grep clean, `extract_Sigma` abort test passing, the
Design 83 §5 `simulate` contradiction confirmed — the honesty lens ran while the safety classifier
was briefly unavailable, so its output was checked, not trusted blind.)

## Changes at promotion
- **Register (FAM-20):** leading label `partial` → **`covered` (fixed-effect recovery route)**;
  latent-scale correlation stays **N/A by design (Tier 2 deferred)**. Re-audit note updated to record
  the clear + sign-off; stale `48/0` count annotated (now 40/0 after the recovery refactor).
- **`extract_Sigma()` hard-refuse** (maintainer decision, committed `82782602`): typed
  `gllvmTMB_multinomial_sigma_undefined`, mirroring `extract_correlations()`; test added; suite 40/0/0.
- **Design 83 reconciliations (non-blocking cracks the audit found):** §5 S3-contract table
  `simulate()` row now says **fails loud / draw branch deferred** (was stale "add 16L to supported",
  contradicting §6 + shipped code); the extract-row lists the two typed aborts + `extract_repeatability`
  erroring on absent variance. Status header records the promotion.
- **NEWS.md:** reader-facing `multinomial()` entry — recovers per-category contrasts, `baseline=`,
  `predict(type="response")`; states fixed-effects-only + that latent-scale correlation is undefined
  and `extract_correlations()`/`extract_Sigma()` decline; K=2 → `binomial`; ordered → `ordinal_probit()`.

## Scope held / follow-ups
- **Article coverage (response-families)** is deliberately NOT batched — per CLAUDE.md the pkgdown /
  reader-doc pass is done one-by-one with the maintainer. That is the remaining public surface.
- **Tier 2** (the K−1-dim latent-scale correlation surface — the "K=5 → 4×4 table") stays deferred;
  scoped as a future arc (correlated category random effects, MCMCglmm/brms-style).
- Julia (GLLVM.jl) parity: separate later arc.

## Checks
- `test-multinomial.R` **40/0/0**, `test-enum-runtime-ids.R` **15/0/0** under `NOT_CRAN`; compiles on `main`.
- Promotion surfaces: NEWS + register + Design 83 + man page (`man/multinomial.Rd`, already present).
