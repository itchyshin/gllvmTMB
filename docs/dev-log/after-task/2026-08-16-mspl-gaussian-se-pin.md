# After Task: Gaussian-identity LA-MSPL SE feasibility pin

**Branch**: `cursor/mspl-se-gaussian-pin-rebased` (successor of #996)
**Worktree**: `/tmp/gllvmtmb-mspl-se-996-rebased`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / Curie / Fisher / Rose

```text
🎯 GOAL
Solo: Cursor
Deliverable: internal Q_P / Q_0 availability pin for Gaussian identity
HEADLINE: form both numerical Hessians on ordinary Gaussian LA-MSPL; public SE stays withheld
DEFER: Poisson next-step · nbinom · Tweedie/Beta · remaining families · public vcov/confint · NEWS covered · admit
```

## 1. Goal

Let the existing unexported curvature pin form \(Q_P\) and \(Q_0\) on
Gaussian identity, so a sibling Gaussian test lane can go green.
This is availability only. It is not calibrated inference.

## 2. Implemented

- Extended `R/mspl-curvature-pin.R` family fence:
  Bernoulli logit + Poisson log **+ Gaussian identity**.
- New `tests/testthat/test-zz-mspl-gaussian-se-feasibility.R`:
  public `se=TRUE` still withholds `sdreport()` / `vcov()` /
  `confint()` / `standard_errors()`; pin names both tapes;
  unexported; non-PD retained unrepaired.
- No `R/fit-multi.R` edit. No registry flip. No NEWS.

RED then GREEN: the pin first aborted
`gllvmTMB_mspl_curvature_family` on `family="gaussian"`,
`link="identity"`. After the fence extension the file is
`PASS 35`.

## 3. Files Changed

- `R/mspl-curvature-pin.R`
- `tests/testthat/test-zz-mspl-gaussian-se-feasibility.R`
- `docs/dev-log/check-log.md`
- this after-task

No `src/`. No `R/mspl.R`. No `R/mspl-registry.R`. No Bernoulli
test rewrite. No Codex helper copy.

## 3a. Decisions and Rejected Alternatives

- **Decision:** extend the shared pin rather than a second helper.
- **Rejected:** public `vcov()` / `confint()`; flipping Gaussian
  (already admitted for *point*) into a covered SE claim; rebuilding
  the Bernoulli pin; closing Codex Lane B.
- **Confidence:** high that the construction can be *named and
  formed* on this tiny cell. Zero confidence that the numbers are
  calibrated.

## 4. Ownership (do not invert)

- Codex `codex/lane-b-mspl-interval-feasibility` remains the
  **binary / Bernoulli** SE owner.
- This lane owns the **other-family** availability series.
  Next after a Poisson admit-packet PR exists: Poisson SE
  next-step (not a redo of the #979 first cell). Then
  nbinom1/2 → Tweedie/Beta → remaining families.

## 5. Checks

See the dated check-log entry. Targeted Gaussian SE file only.
Not run: full `devtools::test()`, `R CMD check`, pkgdown, Totoro.

## 6. What Shinichi should do

Nothing required. Do not merge as a covered-SE claim. Do not
admit anyone. Draft PR is the implementation slice for the
Gaussian test sibling.
