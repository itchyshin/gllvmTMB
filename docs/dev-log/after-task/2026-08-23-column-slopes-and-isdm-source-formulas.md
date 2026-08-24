# After Task: Column slopes and iSDM source formulas

**Branch**: merged feature work #1199–#1204; closure `codex/column-slopes-isdm-closure`  
**Date**: 2026-08-23  
**Roles (engaged)**: Ada, Boole, Curie, Gauss, Pat, Rose, Grace

## 1. Goal

Deliver safe multi-predictor response-column slopes for long-format models without changing existing one-predictor fits, and per-source iSDM observation formulas that remove hand-built masked columns.

## 2. Implemented

`phylo_indep(0 + lat + temp | trait, tree = tree)` is diagonal Gaussian slope covariance; `phylo_dep(...)` is full covariance. `phylo_slope(... || trait)` and `phylo_slope(... | trait)` are the readable helpers; matching `animal_slope()` helpers accept `pedigree =`, `A =`, or `Ainv =`. `0 + trait` remains the fixed column-intercept term and the structured term adds no random intercept.

`isdm_source(law, observation = ~ ...)` wraps a source law inside `isdm_sources()`. It source-masks its design and reference-codes only genuine aliases, so `~ observer + method` needs no user-added `0 +`.

## 4. Files Touched

Merged feature paths are recorded by `git diff --name-only 4180bdd4^..c50ec325`: R/API, TMB, compiled-fixture helpers, slope/source-formula tests, generated Rd, keyword-grid and three-source articles, Design 01/06/120, and release evidence. Closure paths: `docs/design/04-random-effects.md`, `docs/design/35-validation-debt-register.md`, `docs/dev-log/known-limitations.md`, `docs/dev-log/check-log.md`, this report, and the dated handover.

## 3a. Decisions and Rejected Alternatives

Helpers are the public slope surface; the 5 × 3 grid remains canonical. Automatic reference coding beats a required survey `0 +`. Deferred: a new slope family, wide column-predictor grammar, spatial/kernel/latent slope-only variants, and non-Gaussian multi-predictor claims.

## 5. Checks Run

- Targeted diagonal/full matrix-oracle and Gaussian recovery tests: PASS.
- RHS-routing suite: PASS (12 checks); iSDM source-formula suite, including mixed Poisson/cloglog sources: PASS.
- `devtools::document()` and `pkgdown::check_pkgdown()`: PASS; the article rendered against isolated current source: PASS.
- #1203 manual 3-OS R-CMD-check: PASS (macOS 25m55s, Ubuntu 37m53s, Windows 42m47s). #1204 manual 3-OS run `32690414532`: PASS (26m39s, 33m07s, 52m16s).
- Closure: `git diff --check` and `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: PASS.

## 6. Tests of the Tests

The slope design oracle proves no random intercept is added; RHS mismatch and unsupported axes fail loudly; recovery assesses covariance rather than Cholesky coordinates. iSDM tests combine three sources/mixed laws, source masking, aliases, missing data, and duplicate-effect refusal.

## 8. Consistency Audit

```sh
rg -n 'Slope-only random effects \(planned|phylo_slope\(x1 \+ x2 \| trait\).*full|0 \+ observer|po_source\(' docs vignettes R man README.md NEWS.md ROADMAP.md
```

Verdict: only intended current helper wording and the historical 2026-08-20 handover remain; no current surface teaches `po_source()` or required survey `0 +`.

## 7. Roadmap Tick

N/A: no ROADMAP row exists for these issue-bounded slices. Status is RE-03, FG-15, PHY-06, ANI-06, and ISDM-02 in the validation register.

## 7a. Issue Ledger

#1196 closed by #1203. #1192 and #1195 were commented and closed after #1204 and #1203. #1161 remains a separate inference/coverage question.

## 9. What Did Not Go Smoothly

An article render initially used an installed package that lagged source; isolated current-source rendering fixed the evidence path. Windows exposed absolute temporary C++ paths losing backslashes in `g++`; fixtures now compile from their directory. Boole caught animal extractor metadata initially labelled phylo; the correction shipped before release CI.

## 11. Team Learning

Boole: helpers above the grid make the API memorable. Gauss/Noether: the contract is `K_source %x% Sigma_slope`, not augmented intercept+slope. Curie: test structural zeros/free covariance, not convergence alone. Pat/Darwin: use natural survey formulas. Rose/Grace: current-source rendering and Windows are release gates.

## 10. Known Residuals

Gaussian long-format phylo/animal two-predictor slopes are covered. Do not advertise non-Gaussian multi-predictor slopes, wide column-predictor grammar, or spatial/kernel/latent slope-only variants. `isdm_source()` supplies source-masked fixed observation effects, not abundance, occupancy, or detectability identification.

## 12. Cross-Product Coverage

The covered cross-product is Gaussian × long-format × phylo/animal × two column predictors × diagonal/full covariance. Existing one-predictor slope coverage remains untouched. It does NOT cover non-Gaussian multi-predictor slopes, wide syntax, spatial/kernel/latent slope-only sources, REML/penalty variants, missing-predictor variants, aggregation variants, or prediction/interval calibration. Mixed-law source formulas are source-design evidence, not non-Gaussian multi-predictor-slope evidence.
