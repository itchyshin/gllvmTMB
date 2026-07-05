# After-Task Report: Julia Bridge Dispersion Payload Shape Guard

Date: 2026-07-04

Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Close issue #696 by failing loudly when a retained Julia-bridge dispersion
payload has length neither 1 nor the number of traits.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-julia-bridge-dispersion-shape-guard.md`

## What Changed

- `.gllvm_julia_dispersion_vector()` now reports an explicit length mismatch
  instead of replacing malformed payloads with `NA`.
- The regression test checks the `p + 1` malformed payload and preserves scalar
  recycling for valid shared dispersion payloads.
- The validation register records this under `JUL-01` as a malformed-payload
  guard, not a new parity or interval claim.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
```

Result: parse passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Result: focused bridge tests passed. The only skips were expected live-Julia
rows because `GLLVM_JL_PATH` is not configured in this R worktree.

```sh
git diff --check
```

Result: passed.

## Rose Verdict

OK. This closes a misleading failure mode without widening Julia bridge family,
CI, mask, mixed-family, or structured-term support.
