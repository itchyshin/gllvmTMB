# After-task: `extract_latent_scores()` public accessor

**Date:** 2026-09-04  
**Lane:** gllvmTMB twin (`gllvmTMB-gllvm-twin-20260904`)  
**Design:** `docs/dev-log/design-notes/2026-09-04-latent-score-accessor.md`  
**Gate:** Shinichi locked **accessor — go** (G0 gate #6)

## Scope

- New export `extract_latent_scores(x, level)` with S3 methods for fitted
  objects (`gllvmTMB_multi`, `gllvmTMB_va`) and `gllvmTMB_site_trait_sim`.
- Fit path: thin delegate to `extract_ordination(..., component = "innovation")`.
- `simulate_site_trait()`: additive `truth$z_B` / `truth$z_W` + S3 class on return.
- Tests, roxygen, `06-extractors-contract.md` row, NEWS snippet.

## Outcome

Implementation matches design note. No TMB/C++ touch. Harness can now call one
public function for `z_hat` and `u_true` without reading `last.par.best`.

## Checks

```sh
cd /Users/z3437171/local-scratch/lanes/gllvmTMB-gllvm-twin-20260904
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all("."); devtools::test(filter = "extract-latent-scores")'
grep extract_latent_scores NAMESPACE
```

- `devtools::document()` — OK (`man/extract_latent_scores.Rd`, NAMESPACE export + 4 S3 methods)
- `devtools::load_all(".")` + `devtools::test(filter = "extract-latent-scores")` → **FAIL 0 | WARN 0 | SKIP 0 | PASS 21** (7 tests)
- `NAMESPACE`: `export(extract_latent_scores)` + S3 methods confirmed

## Files touched

| File | Change |
|------|--------|
| `R/extract-latent-scores.R` | New implementation + roxygen |
| `R/simulate-site-trait.R` | `truth$z_B`/`z_W`, S3 class |
| `tests/testthat/test-extract-latent-scores.R` | New |
| `man/extract_latent_scores.Rd` | Generated |
| `man/simulate_site_trait.Rd` | Regenerated |
| `NAMESPACE` | Export + S3 |
| `docs/design/06-extractors-contract.md` | Matrix row + subsection |
| `NEWS.md` | Snippet |
| `docs/dev-log/check-log.md` | Entry |

## Definition of Done

| Item | Status |
|------|--------|
| Implementation | ✅ |
| Tests (`NOT_CRAN`, `load_all`) | ✅ 21 pass |
| Roxygen / NAMESPACE | ✅ |
| Extractors contract | ✅ |
| check-log | ✅ |
| After-task report | ✅ (this file) |
| Rose audit | Pending pre-merge (narrow API slice; no user-facing article cascade in v1) |

## Follow-up

- Wire `dev/gapclose/arcG/` harness to `extract_latent_scores()` (separate slice).
- Cell-1 real fit through harness; then Totoro campaign (not in this slice).
