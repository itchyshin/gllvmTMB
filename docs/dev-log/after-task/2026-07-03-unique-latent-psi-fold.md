# After Task: Source-Specific `*_latent(unique = TRUE)` Psi Fold

**Branch**: `codex/unique-latent-psi-fold`
**Date**: `2026-07-03`
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Fisher / Curie / Emmy / Grace / Rose / Shannon`

## 1. Goal

Finish the source-specific and kernel latent-Psi contract in a clean implementation lane:
`phylo_latent()`, `animal_latent()`, `spatial_latent()`, and
`kernel_latent()` remain loadings-only by default, while
`*_latent(..., unique = TRUE)` requests the folded decomposition
`Sigma_source = Lambda_source Lambda_source^T + Psi_source`. Ordinary
`latent()` is unchanged: it still carries Psi by default and uses
`residual = FALSE` for the old no-Psi subset.

## 2. Implemented

- Added explicit `unique = FALSE` formals and literal-logical validation for
  `phylo_latent()`, `animal_latent()`, `spatial_latent()`, and
  `kernel_latent()`.
- Kept compatibility syntax:
  `*_latent(..., unique = FALSE) + *_unique()` remains accepted.
- Added duplicate-Psi guards:
  `*_latent(..., unique = TRUE) + *_unique()` now errors.
- Wired `spatial_latent(..., unique = TRUE)` through both SPDE random-effect
  blocks: shared latent spatial fields `omega_spde_lv` and per-trait unique
  fields `omega_spde`.
- Updated the spatial TMB report to expose `Lambda_spde`,
  `Sigma_spde_shared`, `sd_spde_unique`, `Psi_spde_unique`, and total
  `Sigma_spde = Lambda_spde Lambda_spde^T + diag(Psi_spde)`.
- Updated covariance/profile extractors so spatial total covariance includes
  Psi when the fitted model has `spatial_latent(unique = TRUE)` or the
  compatibility pair.
- Reused the existing dense relatedness path for phylo, animal, and kernel
  latent-Psi folds, including `A =` / `Ainv =` forwarding for phylo wrapper
  calls.
- Updated documentation, vignettes, generated Rd, NEWS, formula grammar,
  random-effect/design notes, validation-debt rows, and capability wording.

## 3. Files Changed

Implementation and extractors:

- `R/brms-sugar.R`
- `R/animal-keyword.R`
- `R/kernel-keywords.R`
- `R/unique-keyword.R`
- `R/fit-multi.R`
- `R/extract-sigma.R`
- `R/methods-gllvmTMB.R`
- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `src/gllvmTMB.cpp`

Tests:

- `tests/testthat/test-spatial-latent-unique-fold.R`
- `tests/testthat/test-phylo-latent-unique-fold.R`
- `tests/testthat/test-animal-latent-unique-fold.R`
- `tests/testthat/test-kernel-latent-unique-fold.R`

Status, design, and public prose:

- `AGENTS.md`
- `CLAUDE.md`
- `NEWS.md`
- `docs/design/00-vision.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-phylogenetic-gllvm.md`
- `docs/design/04-random-effects.md`
- `docs/design/14-known-relatedness-keywords.md`
- `docs/design/2026-06-21-source-specific-latent-psi-fold.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`

Articles:

- `vignettes/articles/animal-model.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/cross-lineage-coevolution.Rmd`
- `vignettes/articles/data-shape-flowchart.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/gllvm-vocabulary.Rmd`
- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `vignettes/articles/pitfalls.Rmd`

Generated Rd:

- `man/animal_latent.Rd`
- `man/animal_unique.Rd`
- `man/diag_re.Rd`
- `man/kernel_latent.Rd`
- `man/phylo.Rd`
- `man/phylo_indep.Rd`
- `man/phylo_latent.Rd`
- `man/phylo_unique.Rd`
- `man/spatial.Rd`
- `man/spatial_latent.Rd`
- `man/spatial_unique.Rd`

## 3a. Decisions And Rejected Alternatives

**Decision**: source-specific and kernel latent terms default to
`unique = FALSE`.

**Rationale**: this preserves the pre-existing low-rank-only path and avoids a
silent likelihood change in old scripts.

**Rejected alternative**: switch all source-specific latent terms to include Psi
by default, matching ordinary `latent()`. That was rejected because the source
paths already had a different historical contract and because spatial needed a
real additive SPDE engine change, not a parser-only fold.

**Confidence**: high for the Gaussian/parser/SPDE report contract covered here;
moderate for broader inference claims until heavy profile/bootstrap and
non-Gaussian recovery gates run.

## 4. Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,isDraft,url,mergeStateStatus`
  -> PASS; no open PRs.
- `git log --all --oneline --since="6 hours ago" -- AGENTS.md CLAUDE.md NEWS.md docs/design R src tests/testthat vignettes/articles man docs/dev-log/check-log.md docs/dev-log/after-task`
  -> REVIEWED; recent commits were unrelated live bridge drift gates; no open
  PR collision.
- `pkgbuild::compile_dll()`
  -> PASS.
- `devtools::document(quiet = TRUE)`
  -> PASS; regenerated Rd files listed above. Roxygen emitted pre-existing
  unresolved-link warnings for helper topics such as `load_mixed_family_fixture`,
  `fit_mixed_family_fixture`, `parse_multi_formula`, and `"0, 1"`.
- `Rscript --vanilla -e 'devtools::test(filter = "phylo-latent-unique-fold|animal-latent-unique-fold|kernel-latent-unique-fold|spatial-latent-unique-fold", reporter = "summary")'`
  -> PASS; all four fold test files passed. One expected deprecation message
  appeared for legacy global `phylo_vcv =`.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|keyword-grid|extract-sigma|profile-targets|confint-derived|profile-derived", reporter = "summary")'`
  -> PASS. Skips were pre-existing: 3 INLA-missing spatial dep checks and
  heavy profile/extractor gates requiring `GLLVMTMB_HEAVY_TESTS=1`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; `No problems found`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual")'`
  -> PASS with `0 errors`, `0 warnings`, `1 note`. The note is the existing
  `NEWS.md` version-title parsing note for older dated sections.
- `git diff --check`
  -> PASS.

## 5. Tests Of The Tests

- Parser tests distinguish bare source-specific latent calls from
  `unique = TRUE`; they would fail if the default silently changed to
  source-Psi.
- Malformed `unique` tests reject non-literal, `NA`, and vector values.
- Duplicate-Psi tests fail if `*_latent(unique = TRUE) + *_unique()` silently
  deduplicates or double-counts.
- Dense relatedness equivalence tests check that folded
  `phylo/animal/kernel_latent(unique = TRUE)` matches the compatibility pair.
- Spatial tests inspect both random-effect blocks, TMB reports, total
  covariance, and the rank-1 correlation degeneracy: total correlations are not
  mechanically forced to `+/-1` when Psi is active.

## 6. Consistency Audit

- ``rg -n 'folds.*by default|by default.*phylo_latent|phylo_latent\(\).*default|animal_latent\(\).*default|kernel_latent\(\).*default|spatial latent-Psi fold remains blocked|fold remains blocked|auto-companion.*dedup|explicit-companion dedup|default-vs-explicit|default phylo-structured|default diagonal.*phylo|default diagonal.*animal|source-specific.*by default|broader `\*_unique\(\)` surface should become' AGENTS.md CLAUDE.md NEWS.md R docs/design vignettes/articles README.md man``
  -> REVIEWED. Remaining hits are intentional: ordinary `latent()` default Psi,
  the new explicit source contract, historical superseding notes, or the updated
  Design 65 multi-kernel Psi boundary.
- `rg -n 'unique = TRUE\) \+|unique = TRUE.*\+ .*_unique|spatial_latent\([^\n]*unique = TRUE' AGENTS.md CLAUDE.md NEWS.md R docs/design vignettes/articles tests/testthat man`
  -> REVIEWED. Hits are intentional examples, duplicate-Psi guards, tests, or
  valid article examples.
- `rg -n 'pass_through_extras\(e, c\("tree", "vcv"\)' R/brms-sugar.R`
  -> PASS; no stale phylo pass-through path omits `A` / `Ainv`.
- `grep -c '^\\keyword' man/phylo_latent.Rd man/spatial_latent.Rd man/animal_latent.Rd man/kernel_latent.Rd`
  -> PASS when spot-checked after documentation; no keyword pollution in the
  changed latent Rd topics.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row was changed in this slice. The status movement is
recorded in `NEWS.md` and `docs/design/35-validation-debt-register.md`.

## 7a. GitHub Issue Ledger

- Inspected [#526](https://github.com/itchyshin/gllvmTMB/issues/526),
  `spatial_latent unique= fold blocked by additive SPDE companion engine`.
  It was already closed from the earlier spatial branch on 2026-07-02. This
  branch strengthens and cleans that arc by integrating the spatial fold with
  phylo, animal, and kernel `*_latent(unique = TRUE)` surfaces. No new issue
  was created.
- Did not close any issue from this branch. The remaining closeout gate is a
  PR/CI decision, not a local-file edit.

## 8. What Did Not Go Smoothly

- The earlier spatial-only branch had enough evidence to close the blocker, but
  it left a broader source/kernel API story unfinished. This branch had to
  reconcile that history instead of pretending the first pass was complete.
- The parser path for `phylo(..., mode = "latent", A = ...)` initially exposed
  an argument-forwarding gap. The regression now checks both direct
  `phylo_latent(..., A = A0, unique = TRUE)` and wrapper
  `phylo(..., mode = "latent", A = A0, unique = TRUE)` forms.
- Design 65 still contained one future-facing sentence about the broader
  `*_unique()` arc. It now states the single-tier `kernel_latent(unique = TRUE)`
  result and keeps multi-kernel Psi partial.

## 9. Team Learning

**Ada** kept the work on the capability-first target. Ayumi's reanalysis should
wait until this branch is integrated because otherwise the between-site
correlation figures can still inherit the old low-rank-only spatial covariance.

**Boole** owned the API shape. The important choice was appending `unique` while
preserving existing arguments, validating literal logical values, and keeping
ordinary `latent()` separate from source/kernel `*_latent()`.

**Gauss** owned the TMB/SPDE alignment. The key numerical point is that
`spatial_latent(unique = TRUE)` must keep both `omega_spde_lv` and `omega_spde`;
it cannot be a parser-only alias.

**Noether** checked the equation-to-code contract:
`Sigma_spde = Lambda_spde Lambda_spde^T + diag(Psi_spde)` is now the report and
extractor target for the total spatial covariance.

**Fisher** kept inference language bounded. Local tests cover parser behavior,
Gaussian equivalence, and covariance extraction, but broad profile/bootstrap and
non-Gaussian interval calibration remain partial.

**Curie** drove the regression tests. The rank-1 total-correlation check is the
most important guard for the Ayumi figures because it catches the old
`+/-1` artifact directly.

**Emmy** focused on extractor contracts. `extract_Sigma(part = "total")` and
correlation summaries now use total fitted covariance by default when Psi is
active, while shared and unique pieces remain separately extractable.

**Grace** covered package hygiene. `pkgdown::check_pkgdown()` and
`devtools::check(args = "--no-manual")` pass locally; 3-OS CI is still needed
before calling the arc release-complete.

**Rose** caught stale wording around default source-Psi claims and the old
Design 65 future-arc sentence. The validation-debt register is deliberately
mixed: covered for the tested Gaussian/parser/equivalence cells, partial for
the broader inference cells.

**Shannon** checked coordination state. There were no open PRs at closeout, and
this work stayed in the clean branch rather than the dirty mission-control
checkout.

## 10. Known Limitations And Next Actions

- 3-OS GitHub CI has not run for this branch yet.
- `GLLVMTMB_HEAVY_TESTS=1` profile/bootstrap and broader recovery gates were not
  run in this local slice.
- Broad non-Gaussian recovery for folded source/kernel Psi remains partial.
- `spatial_latent(..., unique = TRUE)` is implemented for the intercept-only
  spatial latent path; augmented spatial latent random-regression LHS still
  fails loudly for explicit `unique = TRUE`.
- Multi-kernel explicit Psi is still deferred; single named kernel
  `kernel_latent(unique = TRUE)` is covered.
- Julia parity is not implemented in this branch.
- `unique()` and source-specific `*_unique()` compatibility syntax remain live
  and documented as compatibility syntax; removal/deprecation hardening is a
  later lifecycle PR.
