# 2026-06-26 06:15 MDT Codex Stop Checkpoint

## Stop Reason

Shinichi asked Codex to stop where possible and resume tomorrow. I interrupted the
long GLLVM.jl full-suite test rather than leaving a background process running.

## Active Worktrees

### gllvmTMB

- Path: `/private/tmp/gllvmtmb-lv-binary-julia-bridge-20260626`
- Branch: `codex/lv-binary-julia-bridge-20260626`
- Upstream/status line:

```text
## codex/lv-binary-julia-bridge-20260626...origin/main
 M NEWS.md
 M R/extractors.R
 M R/julia-bridge.R
 M docs/design/06-extractors-contract.md
 M docs/design/35-validation-debt-register.md
 M docs/design/61-capability-status.md
 M docs/design/73-predictor-informed-latent-scores.md
 M man/extract_lv_effects.Rd
 M man/gllvm_julia_fit.Rd
 M tests/testthat/test-julia-bridge.R
?? docs/dev-log/recovery-checkpoints/2026-06-26-055406-codex-stop-checkpoint.md
```

- Diff stat before this checkpoint:

```text
 NEWS.md                                            |   2 +-
 R/extractors.R                                     |   6 +-
 R/julia-bridge.R                                   | 114 ++++++++++----
 docs/design/06-extractors-contract.md              |  10 +-
 docs/design/35-validation-debt-register.md         |  11 +-
 docs/design/61-capability-status.md                |   2 +-
 docs/design/73-predictor-informed-latent-scores.md |  25 +--
 man/extract_lv_effects.Rd                          |   6 +-
 man/gllvm_julia_fit.Rd                             |  11 +-
 tests/testthat/test-julia-bridge.R                 | 170 ++++++++++++++++++++-
 10 files changed, 292 insertions(+), 65 deletions(-)
```

### GLLVM.jl

- Path: `/private/tmp/gllvmjl-binomial-xlv-20260625`
- Branch: `codex/binomial-xlv-20260625`
- State:

```text
## codex/binomial-xlv-20260625...origin/codex/binomial-xlv-20260625
```

- Diff stat: clean.
- Branch was already pushed earlier.
- Do not open a new GLLVM.jl PR while draft PR #113 remains open unless Shinichi
  explicitly parks or merges that lane.

## Implemented In gllvmTMB Worktree

- R bridge family mapping now recognizes `binomial(link = "logit")`,
  `binomial(link = "probit")`, and `binomial(link = "cloglog")` for the
  narrow Julia bridge routes.
- Predictor-informed latent-score covariates, `X_lv`, are admitted for
  complete-response Gaussian and binomial logit/probit/cloglog point-estimate
  bridge rows.
- Fixed-effect `X` support remains narrower and intentionally does not claim
  probit/cloglog fixed-effect parity.
- Existing gates remain for mixed families, masks with `X_lv`, fixed `X` plus
  `X_lv`, and CI/profile/bootstrap uncertainty on `X_lv` effects.
- `extract_lv_effects()` documentation now says these binary bridge rows return
  point estimates only, with `std.error = NA`.
- Validation and capability docs were updated without promoting CI-08/CI-10 or
  any validation-debt row beyond the named point routes.

## Commands Already Run

Local R setup used:

```sh
R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library
GLLVM_JL_PATH=/private/tmp/gllvmjl-binomial-xlv-20260625
```

Successful checks:

```sh
air format R/julia-bridge.R R/extractors.R tests/testthat/test-julia-bridge.R
Rscript --vanilla -e 'roxygen2::roxygenise()'
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); invisible(parse("R/extractors.R")); invisible(parse("tests/testthat/test-julia-bridge.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); Sys.unsetenv("GLLVM_JL_PATH"); res <- testthat::test_file("tests/testthat/test-julia-bridge.R"); failed <- vapply(res, function(x) any(x$results$failed), logical(1)); if (any(failed)) quit(status = 1)'
Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); res <- testthat::test_file("tests/testthat/test-lv-parser-guard.R"); failed <- vapply(res, function(x) any(x$results$failed), logical(1)); if (any(failed)) quit(status = 1)'
Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); res <- testthat::test_file("tests/testthat/test-extractors.R"); failed <- vapply(res, function(x) any(x$results$failed), logical(1)); if (any(failed)) quit(status = 1)'
git diff --check
rg -n 'Gaussian Julia bridge|complete-response Gaussian|Gaussian .*X_lv|non-Gaussian/binary|binary/non-Gaussian|unsupported Julia bridge `X_lv`' NEWS.md R docs/design man tests/testthat/test-julia-bridge.R
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
```

Observed outcomes:

- Normal `test-julia-bridge.R` without `GLLVM_JL_PATH`: `FAIL 0 | WARN 1 |
  SKIP 18 | PASS 480`.
- `test-lv-parser-guard.R`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 199`.
- `test-extractors.R`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 17`.
- `pkgdown::check_pkgdown()`: `✔ No problems found.`
- `git diff --check`: clean.
- Roxygen completed. It repeated existing unresolved-link warnings, and only
  `man/extract_lv_effects.Rd` plus `man/gllvm_julia_fit.Rd` changed.

Live bridge evidence:

- A standalone live R-to-Julia binary `X_lv` smoke using
  `/private/tmp/gllvmjl-binomial-xlv-20260625` passed for logit, probit, and
  cloglog and printed `live-binary-xlv-ok`.
- Full live `tests/testthat/test-julia-bridge.R` against the same Julia branch
  reached `FAIL 10 | WARN 1 | SKIP 0 | PASS 1351`. The failures were from older
  grouped-dispersion/Gaussian parity rows; the new binary `X_lv` live test did
  not fail.

GLLVM.jl checks already known green before this stop:

```sh
julia --project=. --startup-file=no test/test_bridge_missing_mask.jl
julia --project=. --startup-file=no test/test_bridge_lv_predictor.jl
julia --project=. --startup-file=no test/test_binomial_fit.jl
julia --project=. --startup-file=no test/test_bridge_ci.jl
```

The interrupted command:

```sh
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
```

It had progressed through many long numerical tests with no failure output before
the manual interrupt. Because the stop was requested by Shinichi, this should be
rerun from scratch before any Julia-side closeout claim.

## Commands Still Needed

1. Rehydrate from current repository state:

```sh
cd /private/tmp/gllvmtmb-lv-binary-julia-bridge-20260626
git status --short --branch
git diff --stat
git diff
```

2. Check active PR state before touching shared docs:

```sh
gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt
gh pr list --repo itchyshin/GLLVM.jl --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt
```

3. Rerun or finish validation:

```sh
cd /private/tmp/gllvmjl-binomial-xlv-20260625
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
julia --project=docs --startup-file=no docs/make.jl
```

4. In the R worktree, run at least:

```sh
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

5. Read and apply `prose-style-review` before final prose closeout.
6. Update `docs/dev-log/check-log.md`.
7. Create an after-task report under `docs/dev-log/after-task/`.
8. Run the after-task audit checklist.
9. Commit and push the R branch only after the tree is coherent.
10. Open a focused gllvmTMB PR only if no other gllvmTMB PR is open. Mark any
    dependency on the GLLVM.jl binary `X_lv` branch clearly.

## Next Safest Action

Start tomorrow by rerunning the interrupted GLLVM.jl full suite and Documenter
from the clean Julia worktree. Then finish the gllvmTMB dev-log/after-task
closeout and decide whether the R PR should be draft until the Julia binary
`X_lv` branch is merged.

## Blocking Question

Should the gllvmTMB PR be opened as a draft dependency PR while GLLVM.jl PR #113
is still open, or should it wait until the Julia-side queue is clear?
