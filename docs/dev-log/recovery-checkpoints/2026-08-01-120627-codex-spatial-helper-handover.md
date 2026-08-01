# Recovery checkpoint and handoff -- independent spatial helpers

Date: 2026-08-01 12:06:27 MDT

## Goal and lane

Deliver independently authored gllvmTMB R-side mesh, CRS, and isotropic-range
helpers without changing the native TMB spatial likelihood or carrying sdmTMB
code-provenance/citation debt.

Worktree: `/private/tmp/gllvmtmb-spatial-independent`

Branch: `codex/spatial-independent-helpers`

Base integration: `origin/main` at `cee55a07`, merged as `8980ae4b`.

The user's original checkout was not modified.

## State at checkpoint creation

The implementation checkpoint commit is `93a71380`; merge commit is
`8980ae4b`. Final D-43 repairs and closeout documents were modified after that
merge and are intended to land in the next explicit closeout commit.

Changed after `8980ae4b`:

- `R/crs.R`, `R/mesh.R`, `R/plot.R`;
- `tests/testthat/test-anisotropy.R`, `test-mesh.R`, and
  `test-utm-conversions.R`;
- `docs/design/00-vision.md`;
- independent-helper research, plan-actual, check-log, and after-task records;
- this checkpoint.

Run `git status --short --branch` and `git diff --stat` before any continuation;
the final closeout commit should leave the branch clean.

## Completed evidence

- Curated NotebookLM notebook
  `c0994d01-a66e-4530-96c1-934aaac0fd82`: six ready literature/API sources;
  report, audio, and video artefacts completed.
- Native mesh modes, supplied fmesher mesh, CRS, legacy bridge, isotropic
  plotting, and real R-to-TMB fit tests: 122 assertions passed with zero
  failures, warnings, or skips.
- Isolated sdmTMB 1.1.0 black-box oracle: passed `A_st`, `c0`, `g1`, `g2`, and
  CRS fixtures at `1e-10`.
- `pkgdown::check_pkgdown()`: no problems.
- Expanded current-provenance scan: no false inheritance or required-citation
  claim.
- D-43 final panel: Curie/test fidelity DONE; Rose/provenance DONE;
  Gauss-Noether/mathematics and interface DONE, with no P0--P3 finding.
- drmTMB future mesh/SPDE issue: #881.

## Global blocker

The branch is not globally merge-ready because the current-main full suite is
red outside this lane:

1. `vignettes/articles/lambda-constraint-suggest.Rmd` uses
   `profile_retention`, which `test-article-prescribed-calls.R` does not admit;
2. `test-funcphylo-spatial-recovery.R` failed its fixed-fixture convergence
   assertion;
3. the dispatcher correlation-ellipse vdiffr snapshot differs on this machine.

The full suite otherwise reported 785 intentional skips and two unrelated
gllvm-comparator warnings. The no-manual package check returned one error, one
warning, and two notes; the error is the global test phase. No generated
`.new.svg` was retained.

These files and failures are outside the spatial-helper ownership boundary.
Do not repair or accept their baselines from this lane without a separate
maintainer decision.

## Exact continuation

After the current-main failures are resolved or formally adjudicated:

```sh
cd /private/tmp/gllvmtmb-spatial-independent
git status --short --branch
git fetch origin
git merge --no-edit origin/main
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-mesh.R"); testthat::test_file("tests/testthat/test-utm-conversions.R"); testthat::test_file("tests/testthat/test-anisotropy.R"); testthat::test_file("tests/testthat/test-stage4-spde.R"); testthat::test_file("tests/testthat/test-spatial-mode-dispatch.R"); testthat::test_file("tests/testthat/test-spatial-orientation.R")'
SDMTMB_ORACLE_LIB=/private/tmp/gllvmtmb-sdmtmb-oracle Rscript --vanilla dev/verify-sdmtmb-spatial-oracle.R
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

If the package check is green, push the branch and open the focused PR. If it
remains red, update this checkpoint with the exact remaining failure and do not
claim merge readiness.

## Blocking question

No spatial-method decision remains. The only maintainer-level question is
whether the three current-main failures should block every unrelated PR or be
formally waived after their owning lanes record separate receipts. Until that
decision, the safe default is to withhold merge.
