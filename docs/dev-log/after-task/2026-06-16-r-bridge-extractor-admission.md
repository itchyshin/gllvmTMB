# After-task report: R bridge unit-tier covariance and raw ordination admission

Date: 2026-06-16

Branch: `codex/r-bridge-grouped-dispersion`

## Scope

Admitted a narrow extractor row for `gllvmTMB_julia` objects. The R bridge now
routes:

- `extract_Sigma()`, `extract_Sigma_B()`, `getResidualCov()`, and
  `getResidualCor()` for the retained ordinary unit-tier covariance /
  correlation on the GLLVM.jl engine scale;
- `extract_ordination()`, `getLoadings()`, and `getLV()` for raw unit-tier
  loadings and scores.

Still gated: `unit_obs`, structured tiers, augmented slopes, cluster tiers,
mixed-family extractors, link-residual augmentation, rotated ordinations,
interval-bearing extractors, `newdata` prediction/simulation, unconditional
random-effect redraws, ordinal residuals/simulation, and broad/native extractor
parity.

## Mathematical contract

No likelihood, formula grammar, family, or parameterisation changed. The new
extractor branch exposes the covariance already retained in the Julia bridge
payload:

```text
Sigma_unit = Lambda Lambda^T
```

on the engine scale. The Julia bridge row currently has no `unique()` /
`unit_obs` decomposition and does not add the family-aware `link_residual =
"auto"` diagonal augmentation used by native TMB extractors.

## Files touched

- `R/julia-bridge.R`
- `R/extract-sigma.R`
- `R/extractors.R`
- `R/output-methods.R`
- `tests/testthat/test-julia-bridge.R`
- `man/extract_Sigma.Rd`
- `man/extract_ordination.Rd`
- `man/gllvmTMB_julia-methods.Rd`
- `man/getLoadings.Rd`
- `man/getLV.Rd`
- `man/getResidualCov.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-extractor-admission.md`

## Definition-of-done review

1. Implementation: added `.GLLVM_JULIA_ORDINATION_FAMILIES`, capability-ledger
   flags, internal Julia bridge extractor helpers, class-aware branches in
   `extract_Sigma()` / `extract_ordination()`, and clear rotation gates in
   `getLoadings()` / `getLV()`.
2. Simulation recovery test: not a new likelihood, family, keyword, or
   estimator. Covered by bridge method tests and live JuliaCall route tests; no
   new recovery claim is made.
3. Documentation: roxygen and generated Rd updated for `extract_Sigma()`,
   `extract_ordination()`, gllvm-style accessors, and Julia bridge method
   wording.
4. Runnable user-facing example: not added in this slice because the bridge
   remains a draft / next-release route and no public article was touched.
5. Check-log entry: added `2026-06-16 -- R bridge unit-tier covariance and raw
   ordination admission` with exact commands and skipped checks.
6. Review pass: Ada kept the lane scoped to raw unit-tier accessors; Rose
   wording separates admitted accessors from richer extractor parity; Shannon
   pre-edit census found no open `gllvmTMB` PR collision.

## Checks

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,updatedAt,mergeStateStatus`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" -- R/julia-bridge.R R/extract-sigma.R R/extractors.R R/output-methods.R tests/testthat/test-julia-bridge.R docs/dev-log/check-log.md docs/design docs/dev-log/after-task NEWS.md man`
  -> current local Codex programme commits only.
- `gh issue view 488 --repo itchyshin/gllvmTMB --json number,title,state,updatedAt,url,labels`
  -> open bridge-gate drift audit.
- `gh issue view 340 --repo itchyshin/gllvmTMB --json number,title,state,updatedAt,url,labels`
  -> open capability-matrix board.
- `gh issue view 10 --repo itchyshin/GLLVM.jl --json number,title,state,updatedAt,url,labels`
  -> open R-bridge umbrella.
- `air format R/julia-bridge.R R/extract-sigma.R R/extractors.R R/output-methods.R tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/extract_Sigma.Rd`, `man/extract_ordination.Rd`,
  `man/gllvmTMB_julia-methods.Rd`, `man/getLoadings.Rd`, `man/getLV.Rd`, and
  `man/getResidualCov.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures with `11` expected Julia-runtime skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); expected <- gllvmTMB:::.GLLVM_JULIA_ORDINATION_FAMILIES; stopifnot(identical(caps$family[caps$postfit_ordination], expected)); stopifnot(!caps$postfit_ordination[caps$family == gllvmTMB:::.GLLVM_JULIA_MIXED_FAMILY]); stopifnot(any(grepl("unit-tier covariance and raw ordination accessors", caps$notes, fixed = TRUE))); stopifnot(any(grepl("richer extractor parity remains gated", caps$notes, fixed = TRUE))); print(caps[, c("family", "postfit_predict", "postfit_residuals", "postfit_simulate", "postfit_ordination", "status")], row.names = FALSE)'`
  -> scalar and ordinal bridge families true; mixed-family false.
- `rg -n 'extractor parity|richer extractor parity|raw ordination|unit-tier covariance|postfit_ordination|link_residual = .auto.|rotated loadings|mixed-family .*extractors' R tests/testthat NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-16-r-bridge-extractor-admission.md man`
  -> expected implementation, tests, docs, and explicit richer-parity gates only.
- `git diff --check`
  -> clean.

## Consistency audit

The stale-wording scan intentionally still finds:

- mixed-family extractor gates;
- structured-tier / `unit_obs` gates;
- `link_residual = "auto"` not-yet-applied messaging for Julia bridge
  covariance extractors;
- “richer extractor parity remains gated” language in the capability ledger.

No current source now says all Julia bridge extractors remain gated without the
narrow unit-tier covariance / raw ordination exception.

## Tests of the tests

The pure-R fake-payload test exercises the class-aware branches without Julia:
capability flags, `extract_Sigma()` default/default-forced arguments,
`extract_Sigma_B()` / `extract_Sigma_W()`, residual covariance wrappers,
raw ordination accessors, rotation gates, structured-level gates, and
mixed-family extractor gates. The live grouped-dispersion and ordinal-probit
loops exercise the same accessors through `GLLVM.jl-integration`.

## What did not go smoothly

The first pure-R pass caught an R `match.arg()` promise issue: the Julia branch
forwarded default `part` / `link_residual` promises before forcing them. The fix
forces `match.arg()` at the public branch boundary and uses explicit choices
inside internal helpers.

## Team learning

Ada: The smallest honest row was not “extractor parity”; it was raw unit-tier
covariance plus raw ordination. That let the bridge become more useful without
weakening the bigger parity gate.

Rose: The wording needed three buckets: admitted raw accessors, engine-scale
limitations, and richer parity still gated. The public ledger now carries that
split.

Shannon: The pre-edit audit found no open PR collision and only current local
programme commits on hot files. The after-task/report/check-log pairing is
present for the slice.

Hopper: The class-aware branches preserve the public extractor names while
avoiding TMB internals for Julia objects.

Fisher: `link_residual = "auto"` is not silently treated as native parity; the
returned note and message state that Julia covariance extractors are on the
retained engine scale.

## Design-doc updates

`JUL-01` remains `partial`. The validation register now points at this report
and records the admitted raw unit-tier covariance / ordination row separately
from richer extractor parity.

## Pkgdown/documentation updates

Generated Rd files were refreshed. No `_pkgdown.yml`, vignette, README, or
article change was required because this is still a draft bridge row rather than
a public learning-path expansion.

## Roadmap tick

N/A. No `ROADMAP.md` row changed in this slice.

## GitHub issue ledger

- `gllvmTMB#488` inspected live; still open. This slice reduces gate-vs-engine
  drift for post-fit accessors but does not close the audit.
- `gllvmTMB#340` inspected live; still open. The capability ledger and local
  status board were updated, but the public capability-matrix issue remains
  broader than this row.
- `GLLVM.jl#10` inspected live; still open. This slice advances the R-side
  bridge surface but does not close the Julia umbrella.
- No issue was closed or commented from this local-only slice.

## Known limitations and next actions

Next safe rows are grouped-dispersion CI/status, masked CI/status, main-dispatch
CI control, or a separate richer-extractor parity row. Do not advertise
structured-tier, rotated, mixed-family, interval, or link-residual covariance
extractors for `engine = "julia"` until their tests and ledgers exist.
