# Codex stop checkpoint: binary X_lv bridge pause

Date: 2026-06-26 05:54:06 local

Maintainer request: stop where possible so the app can be updated; resume tomorrow from the current facts.

## Hard guards

- Do not use `/Users/z3437171/Dropbox/Github Local/gllvmTMB` for package PR work.
- Continue from `/private/tmp/gllvmtmb-lv-binary-julia-bridge-20260626` for the R bridge slice.
- Continue from `/private/tmp/gllvmjl-binomial-xlv-20260625` for the Julia endpoint slice.
- Keep one active PR at a time.
- No GPU work, no login-node fitting, no production DRAC/Totoro launch.
- Keep CI-08 and CI-10 partial.
- Keep REML / AI-REML language Gaussian-only.

## R worktree state

Path:

```sh
/private/tmp/gllvmtmb-lv-binary-julia-bridge-20260626
```

Branch:

```sh
## codex/lv-binary-julia-bridge-20260626...origin/main
 M R/julia-bridge.R
 M tests/testthat/test-julia-bridge.R
```

Diff stat:

```sh
R/julia-bridge.R                   |  95 ++++++++++++++++++++++++--------
tests/testthat/test-julia-bridge.R | 108 ++++++++++++++++++++++++++++++++++---
2 files changed, 176 insertions(+), 27 deletions(-)
```

Open PR check:

```sh
gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt
[]
```

## R changes already made

- Added binomial bridge family aliases for `binomial`, `binomial_probit`, and `binomial_cloglog`.
- Kept fixed-effect `X` support narrower than `X_lv`: ordinary `X` remains the existing logit-only binary route; `X_lv` admits Gaussian plus binary logit/probit/cloglog point routes.
- Updated bridge capability logic for `predictor_informed_lv` and `cbind_binomial`.
- Added family scalar mapping for `binomial(link = "logit")`, `binomial(link = "probit")`, and `binomial(link = "cloglog")`, plus string aliases.
- Added cloglog response predictor handling.
- Updated mask placeholder, default-link, residual-variance, simulation-draw, observed-response, trials, and direct-wrapper gates to treat the three binary aliases consistently.
- Added pure-R mocked tests that verify `gllvmTMB(..., engine = "julia")` routes binary latent-score predictors for logit, probit, and cloglog without fixed `X`, masks, or CI requests.

## R commands already run

Parse check:

```sh
Rscript --vanilla -e 'parse("R/julia-bridge.R"); parse("tests/testthat/test-julia-bridge.R"); cat("parse-ok\n")'
```

Outcome: passed and printed `parse-ok`; the command also printed parsed expressions because `parse()` was not wrapped in `invisible()`.

Initial `devtools::test(filter = "julia-bridge")` attempt:

Outcome: not run because the fresh R 4.6 library does not currently have `devtools`.

Targeted test with explicit library paths:

```sh
R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library \
Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); res <- testthat::test_file("tests/testthat/test-julia-bridge.R"); if (any(vapply(res, function(x) any(x$results$failed), logical(1)))) quit(status = 1)'
```

Outcome: passed with `FAIL 0 | WARN 1 | SKIP 17 | PASS 480`. The warning was the existing one-time auto-Psi drop warning. The skips were from unavailable JuliaCall/live Julia bridge pieces.

## Julia worktree state

Path:

```sh
/private/tmp/gllvmjl-binomial-xlv-20260625
```

Branch:

```sh
## codex/binomial-xlv-20260625...origin/codex/binomial-xlv-20260625
```

Diff stat:

```sh
```

The Julia branch is clean and pushed.

Open PR check:

```sh
gh pr list --repo itchyshin/GLLVM.jl --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt
[{"headRefName":"claude/studentt-105-20260620","isDraft":true,"mergeStateStatus":"DIRTY","number":113,"title":"feat(families): fixed-nu Student-t family (#105)","updatedAt":"2026-06-24T15:55:34Z","url":"https://github.com/itchyshin/GLLVM.jl/pull/113"}]
```

Because #113 is still open, no new GLLVM.jl PR was opened.

## Julia commands already run before stop

Targeted Julia checks already passed on branch `codex/binomial-xlv-20260625`:

```sh
julia --project=. --startup-file=no test/test_bridge_missing_mask.jl
julia --project=. --startup-file=no test/test_bridge_lv_predictor.jl
julia --project=. --startup-file=no test/test_binomial_fit.jl
julia --project=. --startup-file=no test/test_bridge_ci.jl
```

Known outcomes:

- `test_bridge_missing_mask.jl`: `83/83`
- `test_bridge_lv_predictor.jl`: `94/94`
- `test_binomial_fit.jl`: `8/8`
- `test_bridge_ci.jl`: `64/64`

Full Julia package test:

```sh
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
```

Outcome: started and progressed through sparse/phylo gradient checks without visible failure output, but was interrupted after the maintainer asked to stop. The test was not completed and must be rerun before any Julia PR work.

No leftover Julia process was present after interruption; the only `julia|Pkg.test|GLLVM` process in the shutdown check was the `ps | rg` command itself.

## Still needed tomorrow

1. Resume from the R worktree:

   ```sh
   cd /private/tmp/gllvmtmb-lv-binary-julia-bridge-20260626
   git status --short --branch
   git diff --stat
   git diff
   ```

2. Patch stale R-side docs for the expanded binary `X_lv` point route:

   - `NEWS.md`
   - `R/extractors.R` and regenerated `man/*.Rd` if roxygen2 is available
   - `docs/design/06-extractors-contract.md`
   - `docs/design/35-validation-debt-register.md`
   - `docs/design/61-capability-status.md`
   - `docs/design/73-predictor-informed-latent-scores.md`

3. Re-run stale wording scan, at minimum:

   ```sh
   rg -n "Gaussian Julia bridge|complete-response Gaussian|Gaussian .*X_lv|non-Gaussian/binary|binary/non-Gaussian|unsupported Julia bridge `X_lv`" R docs NEWS.md tests
   ```

4. Re-run R syntax and targeted bridge tests with the explicit `R_LIBS` path above.

5. Run `git diff --check`.

6. If roxygen is available, run roxygen and make sure `man/*.Rd` agrees with `R/extractors.R`.

7. Resume Julia validation:

   ```sh
   cd /private/tmp/gllvmjl-binomial-xlv-20260625
   julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
   ```

8. If full Julia tests pass, run Documenter if needed:

   ```sh
   julia --project=docs --startup-file=no docs/make.jl
   ```

9. Do not open a GLLVM.jl PR while #113 remains the only open PR unless the maintainer explicitly parks or merges #113 first.

10. After docs/tests are clean, update `docs/dev-log/check-log.md`, create an after-task report, run after-task audit, commit, push, and open one focused gllvmTMB PR if the tree is clean.

## Blocking question

None. The immediate stop was user-directed. The next safe action is to resume validation and documentation from the two `/private/tmp` worktrees above.
