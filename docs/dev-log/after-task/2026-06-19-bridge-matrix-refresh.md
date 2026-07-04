# After Task: R / Julia / Julia-via-R Bridge Matrix Refresh

## Goal

Refresh bridge evidence across three layers: R-only bridge guards and payloads,
Julia-only PR #101 bridge tests, and live Julia-via-R bridge execution from
gllvmTMB into the paired GLLVM.jl checkout.

## Implemented

- Verified the R-only bridge suite with `GLLVM_JL_PATH` unset.
- Created a detached temporary GLLVM.jl worktree at PR #101 head
  `f7be594e72486ef1bb2f2bde1875e1e6e903b5f9` and ran focused Julia bridge
  tests there.
- Ran the live gllvmTMB Julia bridge suite against the clean
  `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` checkout at the
  same PR #101 SHA.
- Updated dashboard status/sweep with the paired bridge evidence.

## Mathematical Contract

No likelihood, estimator, formula grammar, or bridge payload changed in this
matrix refresh. The evidence confirms the current R-side bridge guards/payload
tests, Julia grouped-dispersion/capability/CI bridge tests, and live JuliaCall
transport against the default GLLVM.jl fitting path.

## Files Changed

- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-bridge-matrix-refresh.md`

The earlier R-only warning cleanup in this sitting changed:

- `tests/testthat/test-julia-bridge.R`

## Checks Run

- `gh pr list --state open`
- `git log --all --oneline --since="6 hours ago"`
- `git diff --check`
- `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL); devtools::test(filter = "julia-bridge")'`
  - Result: `FAIL 0 | WARN 0 | SKIP 14 | PASS 357`.
- `git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" worktree add --detach /tmp/gllvmjl-pr101.0Er7Dp f7be594e72486ef1bb2f2bde1875e1e6e903b5f9`
- `julia --project=. --startup-file=no -e 'import Pkg; Pkg.instantiate()'`
  in `/tmp/gllvmjl-pr101.0Er7Dp`
- `julia --project=. --startup-file=no test/test_bridge_grouped_dispersion.jl`
  in `/tmp/gllvmjl-pr101.0Er7Dp`
  - Result: `Pass 121 | Total 121`.
- `julia --project=. --startup-file=no test/test_bridge_capabilities.jl`
  in `/tmp/gllvmjl-pr101.0Er7Dp`
  - Result: `Pass 40 | Total 40`.
- `julia --project=. --startup-file=no test/test_bridge_ci.jl`
  in `/tmp/gllvmjl-pr101.0Er7Dp`
  - Result: `Pass 64 | Total 64`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  - Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 1188`.

## Tests Of The Tests

The bridge matrix includes both acceptance and rejection evidence:

- R-only rows exercise family mapping, capability ledgers, grouped-dispersion
  normalization, extractor routing, post-fit methods, and explicit gate/error
  paths before JuliaCall is reached.
- Julia-only rows exercise grouped nuisance payloads, capability ledger rows,
  and CI routing in the PR #101 implementation.
- Live Julia-via-R rows prove the R bridge can load the paired GLLVM.jl project
  and execute the full bridge suite without skips.

## Consistency Audit

The local `GLLVM.jl` working checkout remains on
`codex/non-gaussian-fitter-gradients` at `1b42e35`, not PR #101. The paired
bridge evidence therefore uses either a detached temp worktree at the PR #101
head or the clean `GLLVM.jl-integration` checkout at the same SHA. Dashboard
wording keeps this as paired local bridge evidence, not release readiness or
scientific coverage completion.

## What Did Not Go Smoothly

The first Julia-only command failed because the detached temp project needed
`Pkg.instantiate()` for `Distributions` and related dependencies. After
instantiation and precompilation, the focused Julia tests passed.

## Team Learning

For twin R/Julia bridge work, do not rely on whatever `GLLVM.jl` branch happens
to be checked out. Always pin the paired SHA and run live R bridge tests through
an explicit `GLLVM_JL_PATH`.

## Known Limitations

- No full gllvmTMB `devtools::test()` ran in this slice.
- No `pkgdown::check_pkgdown()` ran in this slice.
- No `devtools::check()` ran in this slice.
- The bridge remains row-specific and partial where validation rows say partial
  or blocked.
- PR green is not bridge completion, release readiness, or scientific coverage.

## Next Actions

Use this bridge matrix as the admission evidence for the next landing/split
decision, then run pkgdown/full-package checks before any release or public-doc
claim changes.
