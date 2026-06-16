# After-task report: richer extractor parity spec

Date: 2026-06-16

Branch: `codex/r-bridge-grouped-dispersion`

## Scope

Added a spec/audit card that splits the Julia bridge "richer extractor parity"
gate into concrete rows: raw payload coverage, native point parity,
`link_residual = "auto"`, rotations, structured tiers, interval-bearing
extractors, and mixed-family richer extractors.

No R code, generated Rd, NAMESPACE, tests, validation-register status, vignette,
pkgdown navigation, TMB likelihood, formula grammar, or public article changed.

## Mathematical contract

No likelihood or parameterisation changed. The spec preserves the current
admitted Julia bridge covariance identity:

```text
Sigma_unit = Lambda Lambda^T
```

and keeps the stronger native extractor-parity claim gated until tests cover
family residual augmentation, rotation invariants, structured levels, and
interval/status payloads.

## Files touched

- `docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md`
- `docs/dev-log/after-task/2026-06-16-richer-extractor-parity-spec.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## Definition-of-done review

1. Implementation: no code implementation; this is an ordering/specification
   slice before the next extractor PR.
2. Simulation recovery test: not applicable. No new likelihood, family,
   keyword, or estimator was added.
3. Documentation: developer-facing audit and coordination surfaces updated.
   No roxygen/Rd change was needed.
4. Runnable user-facing example: not applicable; no public learning-path claim
   was added.
5. Check-log entry: added with exact read-only scout commands, post-edit scans,
   and skipped checks.
6. Review pass: Ada scoped the next lane; Emmy split the extractor surface;
   Hopper separated R payloads from Julia engine payloads; Rose kept "full
   parity" wording gated; Fisher kept CI/status and weak-inference behavior out
   of the raw-payload row; Florence kept rotated ordination figures behind the
   rotation/status row.

## Checks

- `git status --short --branch`
  -> clean `codex/r-bridge-grouped-dispersion` tracking origin before edits.
- `git log --oneline -5`
  -> latest pushed commit was `6120bdb docs: refresh live twin gap map`.
- `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20 --json number,title,headRefName,isDraft,mergeStateStatus,statusCheckRollup,updatedAt`
  -> one open draft PR #489, merge state `CLEAN`, both R-CMD-check and
  coevolution recovery checks passed on `6120bdb`.
- `curl -I --max-time 3 http://127.0.0.1:8770/`
  -> HTTP 200; widget server reachable.
- `rg -n "extract_Sigma|extract_correlations|extract_ordination|getLoadings|getLV|getResidualCov|getResidualCor|julia|bridge|gllvmTMB_julia" R tests/testthat docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/dev-log/coordination-board.md`
  -> current R extractor, test, register, and coordination-board evidence
  inspected.
- `rg -n "extract_|getLV|getLoadings|getResidual|ordination|Sigma|correlation" ../GLLVM.jl-integration/src ../GLLVM.jl-integration/test`
  -> paired Julia post-fit and bridge-payload evidence inspected.
- `rg -n "extractor parity|richer extractor|structured-tier extractors|link-residual augmentation|rotations|getLoadings|getLV" docs/dev-log docs/design NEWS.md`
  -> historical gates and current wording inspected.
- `sed -n '1,220p' docs/dev-log/after-task/2026-06-16-r-bridge-extractor-admission.md`
  -> prior raw unit-tier admission scope inspected.
- `sed -n '480,510p' docs/design/35-validation-debt-register.md`
  -> `JUL-01A` / `JUL-01` status confirmed as `partial`.

Post-edit checks are recorded in `docs/dev-log/check-log.md`.

## Deliberately not run

- `devtools::document()`
- `devtools::test()`
- `devtools::check()`
- `pkgdown::check_pkgdown()`
- article renders
- `Pkg.test()`

This slice changes developer-facing planning documents only. The next
implementation slice will need targeted R bridge tests and live JuliaCall
coverage.

## Consistency audit

The spec keeps these boundaries explicit:

- raw retained payloads are not full native extractor parity;
- native TMB is the R-facing shape/status oracle;
- GLLVM.jl is the engine payload oracle;
- `link_residual = "auto"` is a family-specific statistical contract, not a
  display toggle;
- rotated loadings and scores are gated until invariants and conventions are
  tested;
- `MultiTraits` is a visualization-learning source, not a likelihood
  comparator.

## GitHub issue ledger

No issue was closed or commented. The relevant live issues remain broader than
this spec slice: `gllvmTMB#488`, `gllvmTMB#340`, and `GLLVM.jl#10`.

## Next action

Implement `EXT-JL-RAW` first: a pure-R and live-JuliaCall test matrix for raw
payload shape, labels, finite values, and gate messages. Then promote only the
rows with invariant native parity evidence.

