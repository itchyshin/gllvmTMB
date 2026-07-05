# After-task: validation ledger EXT-10 / LAM-02 cleanup

## Task goal

Move two stale validation-register rows from old smoke/partial wording to their
current evidence level:

- `EXT-10`: `extract_cutpoints()` for ordinal-probit fits.
- `LAM-02`: Gaussian `lambda_constraint` fits.

This is a narrow documentation/register cleanup after PR #533 merged.

## Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change. The PR only aligns design/register
wording with existing tests.

## Files created or changed

- `docs/design/35-validation-debt-register.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/01-formula-grammar.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-validation-ledger-ext10-lam02.md`

## Checks run

- `Rscript --vanilla -e 'devtools::test(filter = "ordinal-probit|ordinal-recovery-depth|lambda-constraint", stop_on_failure = TRUE)'`
  -> PASS: `[ FAIL 0 | WARN 0 | SKIP 8 | PASS 96 ]`. The skips are the
  expected heavy binary/lambda and ordinal-depth cells.
- `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "ordinal-recovery-depth", stop_on_failure = TRUE)'`
  -> PASS: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 12 ]`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS: `No problems found.`
- `rg -n "LAM-03 stays partial|LAM-04.*stays partial|M2 verifies on binary|EXT-10.*partial|LAM-02.*partial|ordinal cutpoint smoke EXT-10|lambda_constraint.*smoke LAM-02|extract_cutpoints.*smoke|lambda_constraint.*smoke only|ordinal-probit thresholds only \\(single-family ordinal\\)|Reserved for non-Gaussian and mixed-family|167/20/0/7|194 capability rows" docs/design docs/dev-log/after-task tests/testthat -g '*.md' -g '*.R'`
  -> PASS for live files; the only remaining hit is a historical
  2026-05-16 after-task preview noting that LAM-03 was partial before M2.3.
- `rg -n "EXT-10|LAM-02|LAM-03|LAM-04|171/23/0/7|201 capability rows|covered \\(Gaussian and binary IRT\\)|mixed-family fits" docs/design/35-validation-debt-register.md docs/design/06-extractors-contract.md docs/design/01-formula-grammar.md docs/dev-log/after-task/2026-06-22-validation-ledger-ext10-lam02.md`
  -> PASS; live register, extractor contract, and formula grammar agree.
- `git diff --check`
  -> PASS.

## Consistency audit

`EXT-10` now matches `test-ordinal-probit.R` and
`test-ordinal-recovery-depth.R`: planted cutpoints are recovered across
`K = 2, 3, 4`, mixed-family ordinal cutpoints are returned only for the
ordinal trait, and the heavy depth test covers cutpoints with intercepts and
full between-unit `Sigma_B`.

`LAM-02` now matches `test-lambda-constraint.R` and the already-covered
grammar note in `docs/design/01-formula-grammar.md`: Gaussian
`lambda_constraint` is not merely a smoke path; it exact-pins B/W loading
entries and checks dimension errors.

While auditing the lambda row, the grammar table also had stale LAM-03/LAM-04
future wording. It now matches the register: binary IRT
`lambda_constraint`, `suggest_lambda_constraint()`, and
`suggest_lambda_constraints()` are covered by the M2.3/M2.4 tests and
cross-checks.

## Tests of the tests

The change relies on existing deterministic tests rather than adding new
assertions. The tests are direct enough for this cleanup: they assert planted
numeric cutpoint recovery and exact fixed loading values, not only object
construction.

## What did not go smoothly

The first attempt to switch the PR #533 worktree to `main` failed because
`main` was already checked out in another temp worktree. I created a fresh
worktree from `origin/main` instead:
`/private/tmp/gllvmtmb-validation-ledger-20260622`.

## Team learning and process notes

Ada kept the slice register-only and resisted broadening into new validation
claims. Rose caught that `EXT-10` had stale extractor-contract wording as well
as the register row. Curie/Fisher evidence is existing tests: no new simulation
or inference machinery moved in this PR. Grace scope is low-risk docs: no
dependency, pkgdown navigation, or generated Rd change.

## Design-doc updates

The validation-debt register now marks `EXT-10` and `LAM-02` as `covered`,
updates the honest-scope tally to `171/23/0/7` over 201 rows, and removes the
old smoke wording. The extractor contract now says `extract_cutpoints()` is
covered for ordinal-probit traits in mixed-family fits, and non-ordinal fits
fail loudly. The formula grammar table now records Gaussian and binary IRT
coverage for the lambda-constraint and lambda-suggester surfaces.

## pkgdown/documentation updates

No pkgdown navigation or article changes. `pkgdown::check_pkgdown()` should
remain sufficient because these are design docs rather than rendered article or
reference-topic edits.

## Roadmap tick

N/A. This PR changes evidence status in the validation register only; no
`ROADMAP.md` row or progress bar changes.

## GitHub issue ledger

No GitHub issue inspected or closed for this cleanup. The work follows the
maintainer's broad request to turn stale `partial` / planned rows into covered
where evidence already exists.

## Known limitations and next actions

This does not move `EXT-04`, `EXT-13`, `DIA-11`, `DIA-12`, `CI-08`,
`CI-10`, `MIS-03`, `MIS-07`, `MIS-09`, or other leading-`partial` rows.
Those rows need their own evidence checks and should not be promoted by
analogy.
