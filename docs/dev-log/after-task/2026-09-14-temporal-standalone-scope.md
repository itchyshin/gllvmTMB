# After Task: Standalone temporal-provider scope

## 1. Goal

Restrict the public temporal provider to standalone AR1 and OU models, remove temporal combinations with phylogenetic, animal, spatial, and kernel sources from the public grammar and lifecycle paths, and retain the earlier work only as low-priority developer history.

## 2. Implemented

- `temporal_indep()`, `temporal_dep()`, and `temporal_latent()` remain standalone temporal modes with their AR1/OU contracts.
- The parser now rejects every temporal term combined with another covariance source before TMB construction, with an error that directs users to standalone temporal models and identifies the deferred extension.
- Temporal forecast, profile, bootstrap, and selection helpers reject non-temporal source tiers rather than entering their former source-pair algorithms.
- Source-pair tests now live under `dev/temporal-program/retained-source-pair-tests/`; they are preserved history, not package tests or acceptance gates.

## 4. Files Touched

- Implementation and lifecycle guards: `R/temporal.R`, `R/temporal-forecast.R`, `R/temporal-profile.R`, `R/temporal-bootstrap.R`, `R/temporal-selection.R`, and `R/methods-gllvmTMB.R`.
- Tests and retained evidence: `tests/testthat/test-temporal-sixth-source-api.R`, `tests/testthat/test-temporal-sixth-source-engine.R`, the retained-source-pair directory, and `dev/temporal-program/verify.R`.
- Public contract and generated help: `README.md`, `NEWS.md`, `vignettes/articles/temporal-ar1.Rmd`, `vignettes/articles/api-keyword-grid.Rmd`, `man/*.Rd`, and design documents 00, 01, 03, 04, 06, and 35.
- Programme record: `dev/temporal-program/PLAN.md` and `RESUME.md`.

## 3a. Decisions and Rejected Alternatives

- **Decision**: retain a 5 × 3 stable-unit grid plus one standalone temporal provider.
  **Rationale**: temporal ordering and time-scale semantics need their own model contract; the user explicitly removed temporal–source combinations from current scope.
  **Rejected alternative**: maintain a six-row source grid with temporal–phylo/animal/spatial/kernel combinations; this would retain a wide, poorly motivated and unverified public surface.
  **Confidence**: high.
- **Decision**: keep source-pair tests and receipts as developer history instead of deleting them.
  **Rationale**: retained failed and partial evidence remains useful when a separately justified future contract is proposed.
  **Rejected alternative**: remove the evidence entirely; that would erase the provenance for the deferral.
  **Confidence**: high.

## 5. Checks Run

- `Rscript --vanilla dev/temporal-program/verify.R lifecycle` — passed: `TEMPORAL_PROGRAM_LIFECYCLE_PASS`.
- `Rscript --vanilla dev/temporal-program/verify.R plan` — passed: `TEMPORAL_PROGRAM_PLAN_PASS`.
- `Rscript --vanilla dev/gapclose/build-capability-status.R --check` — passed: 80 rows and no unmapped register rows.
- Focused API, engine, oracle, forecast, profile, bootstrap, and selection tests — passed after the source-pair blocks were moved out of `tests/testthat`.
- `devtools::document()` and `pkgdown::check_pkgdown()` — passed; the temporal article rendered after installing the development package.
- `git diff --check` and `git diff --cached --check` — passed before commit.

## 6. Tests of the Tests

`test-temporal-sixth-source-api.R` was added test-first: it initially failed because temporal plus a kernel reached the old source-pair route, then passed after the parser refusal was installed. It is a boundary test for the removed admission route. The existing engine refusal tests cover all four structured-source families.

## 8. Consistency Audit

- `rg -n 'stable-unit grid plus temporal.*stable-unit|temporal.*grid plus temporal|6 ?× ?3|6x3' docs/design/00-vision.md docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/04-random-effects.md vignettes/articles/api-keyword-grid.Rmd README.md NEWS.md` — no stale six-grid wording.
- `rg -n 'qualified temporal|source pair|source-pair|temporal_(indep|dep|latent).*\\+.*(kernel|phylo|animal|spatial)' README.md NEWS.md vignettes/articles man R/temporal.R R/temporal-forecast.R R/temporal-profile.R R/temporal-bootstrap.R R/temporal-selection.R` — no public source-pair admission wording.

## 7a. Issue Ledger

No GitHub issue was created or closed. The validation-debt register is the issue ledger for this scope decision: TEMP-06-02 through TEMP-06-14 are now `blocked` retained developer history. No roadmap chip changed because this is a scope contraction, not a new capability.

## 9. What Did Not Go Smoothly

A raw local `R CMD check --no-manual .` stopped immediately because this local R invocation reported empty `Author` and `Maintainer` fields despite the package's valid `Authors@R` field. No package metadata was changed. A fresh three-OS package receipt is still required for this commit.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Boole:** a parser-level refusal is safer than allowing a formula to reach a partially supported TMB/lifecycle path. **Rose:** public code, generated help, article wording, register status, and test discovery must move together when a capability is deferred. **Curie:** retained source-pair fixtures remain evidence, but cannot function as package acceptance tests for a refused model.

## 10. Known Residuals

Standalone temporal AR1/OU remains locally implemented with bounded evidence only. Temporal combinations with phylogenetic, animal, spatial, or kernel sources are blocked, developer-only future work. Generic temporal forecasts, intervals, profiles, selection, and bootstrap remain limited to their existing explicitly bounded standalone contracts. Push this commit and obtain a fresh three-OS package-check receipt before any stronger local verification claim.
EOF
cat >> docs/dev-log/check-log.md <<'"'"'EOF'"'"'

## 2026-09-14 — temporal provider narrowed to standalone AR1/OU

- Public temporal syntax now retains the 5 × 3 stable-unit grid plus one standalone temporal provider. `temporal_indep()`, `temporal_dep()`, and `temporal_latent()` reject combinations with phylogenetic, animal, spatial, or kernel sources before TMB construction.
- The former source-pair lifecycle code is no longer reachable through the public parser. Its package tests were moved to `dev/temporal-program/retained-source-pair-tests/` as developer-only historical evidence; TEMP-06-02 through TEMP-06-14 are `blocked`, low-priority future work.
- Checks passed: `Rscript --vanilla dev/temporal-program/verify.R lifecycle`; `Rscript --vanilla dev/temporal-program/verify.R plan`; `Rscript --vanilla dev/gapclose/build-capability-status.R --check`; focused temporal API/engine/oracle/lifecycle tests; `devtools::document()`; `pkgdown::check_pkgdown()`; and rendered `vignettes/articles/temporal-ar1.Rmd` against the installed development package.
- A raw local `R CMD check --no-manual .` stopped before checking code because this R invocation rejected the package's `Authors@R` metadata as missing `Author`/`Maintainer`; it is not accepted as package-check evidence. Fresh three-OS CI is required for commit `f24d83c66`.
EOF
## 12. Cross-Product Coverage

This scope change covers parser admission, lifecycle refusal, generated help, articles, package-test discovery, and the validation register for every temporal–phylo, animal, spatial, and kernel combination. It does NOT cover a future separable temporal-by-source covariance model, its identifiability, forecasting, profiles, bootstrap, selection, recovery, or cross-platform validation; each would need a new model contract and evidence.
