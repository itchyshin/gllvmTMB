# Missing / Mixed-Family Claim-Boundary Audit (Day 2 of the completion arc)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `4d8f7589`
Agent: Claude (read-only audit; two Explore sub-agents gathered evidence)

## Goal

Day-2 slice of the completion arc: audit the missing-data and mixed-family
correctness surface for claim-boundary integrity, against the hard guards
"do not claim mixed-family CIs" and "response/predictor missingness must state
v1 versus planned v2 honestly." Confirm the `na_mask` retention correctness
claim from the completion plan's Phase 2. No code, likelihood, grammar, or
register status changed.

## Outcome

Both audits are **confirmatory**: the surface is honestly bounded and no
overclaim was found. This is reported as a clean result, not a manufactured
finding. Two small hardening opportunities are noted below; neither is a defect.

## Audit 1 -- Mixed-family CI boundary (guard: no mixed-family CI claims)

Question: do the interval-bearing mixed-family rows marked `covered`
(MIX-04, MIX-08) contradict the guard?

Answer: **No. `covered` is consistent with the guard** -- these rows claim
route/infrastructure existence, not calibrated coverage.

Evidence:

- `docs/design/57-mixed-family-link-residual.md` is a route-and-scale memo with
  zero calibration language. It defines `extract_correlations()` scales
  (per-pair latent, `Sigma_shared`, `Sigma_total`) and explicitly leaves the
  delta/hurdle two-scales case undefined (Section 5).
- `tests/testthat/test-m1-4-extract-correlations-mixed-family.R` asserts only
  shape, `[-1, 1]` range, and bracket ordering; its header defers empirical
  coverage to "M3.3 work" (`R = 200`).
- `tests/testthat/test-m1-8-bootstrap-mixed-family.R` asserts refit convergence
  and finite `Sigma_B` bounds only. The shipped `R/bootstrap-sigma.R` docstring
  labels non-Gaussian / mixed-family bootstrap calibration `PARTIAL` /
  `PLANNED` (future M3 work) in-code.
- MIX-10 correctly stays `blocked` (delta/hurdle two-scales-undefined; runtime
  guard errors with class `gllvmTMB_auto_residual_delta_undefined`).
- No `coverage` / `calibrat` / `nominal` wording exists for any mixed-family
  interval in docs, code, or register.

Conclusion: the guard is intact. A "95% coverage for mixed-family correlations"
claim does not exist anywhere. This matches Design 75, which keeps mixed-family
CIs blocked on every method, and Design 61, which cautions against mixed-family
CI calibration overclaims.

Hardening opportunity (optional, not a defect): MIX-04/MIX-08 correctness rests
on the reader parsing the note text. An explicit interval-status field on those
rows (`route-only; calibration = CI-08/CI-10`) would make the boundary
reader-proof without changing any behaviour. This is a Rose/register-wording
slice, not a code change.

## Audit 2 -- Missing-data v1/v2 boundary and `na_mask` retention

Question: what missing-data surface is genuinely v1-covered vs planned-v2, and
is the `na_mask` retained under `missing = "include"`?

Missing-data register map (33 `MIS-*` rows):

- **Covered (v1 implemented + tested):** response missingness (MCAR/MAR cells
  under `missing = miss_control(response = "include")`) with per-cell weights;
  single-term predictor missingness for Gaussian continuous (fixed-effect
  Phase 2a, grouped Phase 2b, species-level Phase 2c, phylo-structured Phase 3)
  and discrete (binary 5a, ordered 5b, unordered 5c via exact K-state sum);
  Laplace integration for Gaussian `x_mis`; `predict_missing()` and `imputed()`
  extractors; Gaussian-only REML pilot (MIS-33, explicitly guarded).
- **Partial:** legacy `gllvmTMB_wide()` (MIS-03), `predict(..., newdata)`
  fixed-effect only (MIS-07), plot dispatcher visual QA (MIS-09).
- **Blocked / deferred v2 (MIS-32):** multiple `mi()` terms, EM/profile/REML
  missing-data engines, MI pooling, structured discrete predictors, joint
  response-covariate phylo/spatial fields, count/bounded continuous predictors,
  dense known-V under partial missingness, MNAR sensitivity, bootstrap SE.

Design boundary (design-only, simulation deferred): Design 70 scopes v1 to one
`mi()` term, no MNAR; Design 69 scopes Phase 3 to an independent phylo covariate
field (joint field is v2); Design 68 scopes Phase 5 to fixed-effect discrete
predictors with `K <= 12` (grouped/structured discrete and count predictors are
v2).

`na_mask` retention (Phase 2 correctness claim): **confirmed implemented and
tested.** `R/weights-shape.R` `normalise_weights(..., drop_masked = FALSE)`
retains every row and sets masked-cell weights to a finite `0` sentinel;
callers invert `missing = "include"` to `drop_masked = FALSE`
(`R/traits-keyword.R`, `R/gllvmTMB-wide.R`).
`tests/testthat/test-missing-data-robustfix.R:376-378` asserts the full weight
vector length, that masked cells are exactly the zeroed cells, and that
`is_y_observed` propagates the mask.

No missing-data `covered` row advertises interval/coverage calibration; every
named test file exists; Design 70 simulation grids are explicitly design-only.

Minor enumeration note (not a defect): the sub-agent mapped 32 of 33 `MIS-*`
IDs cleanly; a later register pass should confirm the `MIS-01..MIS-33` sequence
has no gap or duplicate. This does not affect any capability conclusion.

## Checks Run

Read-only audit; no test, `devtools::check()`, or `pkgdown::check_pkgdown()`
run because no code changed. Evidence via two Explore sub-agents over
`docs/design/57`, `68`, `69`, `70`, `35-validation-debt-register.md`,
`R/weights-shape.R`, `R/bootstrap-sigma.R`, `R/extract-correlations.R`, and the
named `test-*.R` files. Lane check earlier this session: no open PRs, no
collision.

## Files Created / Modified

- Created this after-task report.
- Appended a check-log entry to `docs/dev-log/check-log.md`.

No R, C++, Rd, NEWS, README, vignette, design doc, or validation-register file
changed by this audit.

## Team Notes

Rose: no overclaim found on the missing/mixed surface; two optional
register-wording hardening items recorded, neither a defect.

Fisher: mixed-family intervals remain route-existence only; calibration gates
CI-08/CI-10 are open and unclaimed.

Noether/Boole: no symbolic or grammar surface touched.

Shannon: no push or PR; branch remains local, ahead 201.

## Known Limitations And Next Actions

- Optional hardening (register wording, Rose/Claude lane): add an explicit
  interval-status field to MIX-04/MIX-08 reading `route-only; calibration =
  CI-08/CI-10`; confirm the `MIS-*` ID sequence is gap-free.
- Live-code follow-ons remain Codex lane (not started here): the Design 75
  ledger-reality sync, and any missing-data v2 engine slice.
- Before any wording lands in README/NEWS/vignette/roxygen, Rose + Fisher review
  the affected rows.
- No push/PR/merge without Shinichi's authorization.
