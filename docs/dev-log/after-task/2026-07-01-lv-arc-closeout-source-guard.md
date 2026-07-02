# After Task: LV Arc Closeout Source Guard

## Goal

Close the current LV arc as operating truth and remove the structural-source
`lv = ~ env` silent-drop foot-gun without widening source-specific grammar.

## Files Changed

- `R/brms-sugar.R`
- `tests/testthat/test-canonical-keywords.R`
- `docs/design/01-formula-grammar.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-01-lv-arc-closeout-source-guard.md`

## Implemented

The parser now rejects `lv = ~ env` on `phylo_latent()`,
`spatial_latent()`, `animal_latent()`, `kernel_latent()`, and the `phylo()` /
`spatial()` latent-mode wrappers before desugaring can drop the argument.
Mission Control now marks the current LV arc as closed: ordinary LV is covered,
phylo Gaussian Model A `B_eta_realized` evidence is frozen, source-specific
`lv` remains fail-loud, mixed-family remains point/postfit only, and
non-Gaussian/source-specific structural LV starts a separate gated arc.

## Validation

```sh
Rscript -e 'parse("R/brms-sugar.R"); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-stage37-mixed-family.R")'
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
```

Focused tallies:

- `test-canonical-keywords.R`: 67 pass, 3 skips.
- `test-ordinary-latent-random-regression.R`: 23 pass, 7 skips.
- `test-julia-bridge.R`: 380 pass, 14 expected Julia-path skips.
- `test-stage37-mixed-family.R`: 6 pass.

## Claim Boundary

This is a fail-loud guard, not structural-source `lv` support. Structural
random-slope syntax such as `spatial_latent(1 + env | site, d = K)` remains a
separate route from predictor-informed `lv = ~ env`. No source-specific
`lv = ~ env`, non-Gaussian structural LV, mixed-family CI, mask, fixed-X, or
`X_lv` claim is added.

## Rose Audit

PASS WITH NOTES. The LV arc can be closed as package truth only because the
unsupported source-specific `lv` spellings now fail visibly; future structural
or non-Gaussian LV work still needs a new target, derivation, ADEMP gate, and
maintainer authorization.
