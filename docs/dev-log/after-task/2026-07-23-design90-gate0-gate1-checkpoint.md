# After Task: Design 90 Gates 0--1 checkpoint

## 1. Goal

Establish a released ordinary q=2 `gllvm(method = "EVA")` target and freeze a
private 72-cell health-atlas contract before any fixture generation or Totoro
compute.

## 2. Implemented

Gate 0 passed for `num.lv = 2, num.lv.c = 0`, Bernoulli-logit EVA.  Gate 1
created a fresh CRAN 2.0.13 source/binary lock, a 72-cell/16-seed configuration,
an empty result root, and the nonseparation/telemetry/claim contract.  No fit,
fixture, smoke, or campaign was run.

## 3a. Decisions and Rejected Alternatives

**Decision:** target ordinary q=2 EVA only.  
**Rationale:** the source passes EVA method code 2 with `num.lv = 2`, while the
only direct upstream constrained-EVA regression has `num.lv.c = 1`.  
**Rejected alternative:** include constrained q=2; its released source path is
not direct regression coverage.  
**Confidence:** high.

## 4. Files Touched

- `docs/design/90-upstream-eva-reliability-atlas.md`
- `dev/design90-eva-atlas/source-lock.json`
- `dev/design90-eva-atlas/atlas-config.json`
- `dev/design90-eva-atlas/results/.gitkeep`
- this report and `docs/dev-log/check-log.md`

No package, public, C++, API, Rd, vignette, README, NEWS, or validation-debt
file changed.

## 5. Checks Run

- Fresh CRAN 2.0.13 tarball SHA-256 and source/binary hashes -> PASS.
- Fresh private `R CMD INSTALL` -> PASS.
- `jq -e` source-lock and 72-cell configuration predicates -> PASS.
- `git diff --check` -> PASS.
- `git diff --exit-code HEAD -- R src NAMESPACE DESCRIPTION NEWS.md README.md` -> empty.

## 6. Tests of the Tests

No fit test is permitted before the maintainer checkpoint.  The source-map
review distinguishes a source-supported ordinary q=2 path from the untested
constrained q=2 alternative; the configuration predicate catches accidental
grid-size drift before a smoke is authorised.

## 7a. Issue Ledger

No relevant open issue; no new issue created. `gh pr list --state open --limit
20` could not resolve the GitHub API, so no remote state was inferred.

## 8. Consistency Audit

`git diff --exit-code HEAD -- R src NAMESPACE DESCRIPTION NEWS.md README.md`
found no shipped-surface change.  `rg -n 'Design 90|EVA' README.md ROADMAP.md
NEWS.md docs/dev-log/known-limitations.md _pkgdown.yml` found no new public
Design-90 claim.

## 9. What Did Not Go Smoothly

The sandbox could not resolve CRAN or the GitHub API.  The fresh CRAN source
download succeeded only through the approved external connection; no package
or remote-tracker inference was made from the initial failures.

## 10. Known Residuals

The producer has not generated an input, and no gllvm call has been made.
Maintainer approval is required before the four-cell Totoro smoke.

## 11. Team Learning

Jason established the ordinary/constrained q=2 distinction. Gauss/Noether
required marginal-prevalence calibration and per-matrix nonseparation checks.
Rose required fresh Design-90 locks and raw convergence semantics.

## 12. Cross-Product Coverage

Gates 0--1 cover ordinary q=2 upstream EVA source/binary identity and a
prospective health-atlas contract. This checkpoint does NOT cover a realised fixture,
upstream numerical health, gllvmTMB parity, recovery, calibration, structured
priors, public integration, or any prior Design-86--89 claim.
