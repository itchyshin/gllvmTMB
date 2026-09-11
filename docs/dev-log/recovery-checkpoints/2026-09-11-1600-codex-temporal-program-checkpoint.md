# Temporal programme checkpoint — 2026-09-11 (rank-one spatial slice)

- Branch: `codex/temporal-program-20260909`, four prior local commits ahead of `origin/codex/temporal-program-20260909`; the rank-one spatial slice below is uncommitted.
- New slice: replicated AR1 `temporal_latent(..., d = 1, unique = FALSE) + spatial_indep()` with a fixed mesh and one intercept-only diagonal spatial source at `rho = 1`.
- Independent review found a stale wide-projection P1. It is repaired in `R/fit-multi.R`: ordinary spatial `A_proj` is rebuilt from prepared likelihood rows instead of trusting row-aligned `mesh$A_st`. The temporal-spatial test now verifies the wide projection/dense likelihood and has a genuine cross-series product control plus cross-trait and mean simulation moments.
- Retained direct-DGP receipt: nine attempts (`phi=-.4,0,.6`; seeds `2609261:2609263`) all pass the frozen strict gate. The checker emits `TEMPORAL_LATENT_SPATIAL_RECOVERY_PASS`; this is local fixed-fixture evidence only.

Passed after the repair:

```sh
Rscript --vanilla dev/temporal-program/verify.R self-test
Rscript --vanilla dev/temporal-program/verify.R latent-spatial
Rscript --vanilla dev/gapclose/build-capability-status.R --check
Rscript --vanilla -e 'devtools::document(quiet = TRUE); pkgdown::check_pkgdown(); devtools::check(args = c("--no-manual", "--no-vignettes"), quiet = TRUE)'
```

Next safest action: commit this bounded local slice; obtain exact authorization before pushing the five prior commits plus this one to `origin/codex/temporal-program-20260909` and dispatching the fresh three-OS check.
