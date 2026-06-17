# After Task: R Bridge Link-Residual Delta Guards

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Emmy, Fisher, Rose, Shannon, Grace

## 1. Goal

Make the Julia bridge `extract_Sigma()` residual-scale boundary testable after
the scale-semantics fix. The question was not whether full native
`link_residual = "auto"` parity is complete. It is not. The goal was to prevent
silent drift by checking the diagonal difference between default `auto` and
`link_residual = "none"` for representative admitted rows.

## 2. Implemented

- `tests/testthat/test-julia-bridge.R` now checks a fake mixed-family retained
  payload with an explicit residual diagonal. `link_residual = "none"` returns
  `Lambda Lambda^T`; default `auto` keeps the non-Gaussian residual diagonal
  and applies the Gaussian/lognormal no-op rule.
- Live grouped NB2/NB1/Beta/Gamma bridge rows now assert that `auto - none` is
  currently zero. This records that grouped rows still expose the raw
  latent-scale payload rather than full native family residual diagonals.
- Live complete balanced mixed-family rows now assert zero off-diagonal residual
  leakage, zero Gaussian residual delta, and positive Poisson/Bernoulli
  residual diagonals.
- Live ordinal-probit rows now assert zero off-diagonal residual leakage and a
  probit residual diagonal of one.
- `JUL-01A`, the richer extractor spec, coordination board, and check-log now
  describe this as partial residual-delta evidence rather than a full
  all-family native `auto` parity claim.

## 3. Files Changed

- Tests: `tests/testthat/test-julia-bridge.R`
- Validation/spec ledgers: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/check-log.md`
- After-task report: this file

No R implementation, roxygen, generated Rd, NEWS, vignette, pkgdown, TMB
likelihood, formula grammar, or Julia engine code changed.

## 4. Checks Run

- `gh pr list --state open --json number,title,headRefName,isDraft,updatedAt,url`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent commits were the current Codex bridge stack only.
- `gh pr view 489 --json number,title,headRefName,headRefOid,mergeStateStatus,statusCheckRollup,url,isDraft,updatedAt`
  -> PR #489 at `72b1d68`; R-CMD-check ubuntu-latest and coevolution recovery
  both passed; merge state clean.
- Live grouped residual-delta scout:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla - <<'RS' ... RS`
  -> grouped NB2/NB1/Beta/Gamma rows had `auto - none = 0`; native TMB rows
  can add family-specific diagonal residuals, especially NB1.
- Live mixed-family / ordinal residual-delta scout:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla - <<'RS' ... RS`
  -> mixed-family residual deltas were zero for Gaussian and positive for
  Poisson/Bernoulli; ordinal-probit residual diagonal was one.
- `air format tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures, `13` expected live-Julia skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.

## 5. Tests of the Tests

The live scouts showed all three expected regimes before the assertions were
added:

- grouped NB2/NB1/Beta/Gamma: current Julia bridge payload has no residual
  diagonal, so `auto == none`;
- mixed-family Gaussian/Poisson/Bernoulli: Gaussian follows native no-op
  residual semantics, while Poisson and Bernoulli keep positive retained
  residual diagonals;
- ordinal-probit: default `auto` adds the probit latent residual diagonal of
  one.

These checks would fail if a future Julia payload starts adding grouped-family
residual diagonals without updating the R bridge scale contract and validation
row.

## 6. Consistency Audit

- `JUL-01A` remains `partial`.
- `EXT-JL-LINK-RESIDUAL` remains partial: residual-delta guards exist, but
  broad native `link_residual = "auto"` parity across all admitted families is
  still gated.
- No public README, vignette, NEWS, or Rd capability wording was promoted.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. This is evidence for the richer extractor lane
under `JUL-01A` and PR #489.

## 7a. GitHub Issue Ledger

No issue was closed or commented. The evidence belongs under the bridge gate
and capability-ledger issues during the next live issue-ledger pass.

## 8. What Did Not Go Smoothly

The grouped-family scout was deliberately humbling: native TMB can add a
family residual diagonal, but the paired grouped Julia payload currently does
not. That is a boundary to preserve in tests and prose, not a failure to hide.

## 9. Team Learning

- Ada: Promote residual behavior row by row, not by family-name optimism.
- Hopper: Payload scale must be tested by differences, not only by matrix
  equality.
- Emmy: Public extractors need diagonal and off-diagonal invariants, not just
  shape checks.
- Fisher: Grouped-family `auto` parity needs family-specific residual evidence
  before it becomes a public claim.
- Rose: "Where available" wording must be backed by examples of where it is
  and is not available.
- Shannon: The slice stayed within the open PR and did not touch release hot
  files outside the intended ledgers.
- Grace: Targeted no-Julia and live Julia bridge tests passed; full package
  checks remain release-gate work.

## 10. Known Limitations And Next Actions

- Native `link_residual = "auto"` parity is not complete for grouped
  NB2/NB1/Beta/Gamma rows.
- Residual-split reporting is still absent for Julia bridge extractors.
- Next safe extractor slice is either native `auto` parity probes for ordinary
  one-family non-grouped rows or interval-bearing extractor table design.
