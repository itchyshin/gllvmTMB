# After Task: Integrated-SDM Phase C misspecification campaign (#943)

Lane: `claude/experiment-integrated-sdm`. Developer-only evidence: no package API, likelihood, formula grammar, public docs, PR, merge, or issue-state change.

## 1. Goal

Complete the preregistered Phase C campaign after repairing its pilot and instrument, preserving paired common-random-number inference.

## 2. Implemented

Frozen source `7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b` produced corrected `pilot_v2`, 19,800 G1--G6 fits, immutable receipts, independent audit, official analysis, and supplement. A1 shared-bias `dD_bias=0.45218` (MCSE `0.00220`; 100/100 complete/both-pdHess pairs); A5--A6 attribution is `0.31360` (MCSE `0.00230`).

The D-43 addendum hashes and copies the immutable R1--R5 table, retaining every negative R5 cell, and records only a post-analysis interpretation: control-only R5 triggers imply `H_SINK_UNRESOLVED_PREREGISTRATION_SCOPE_CONFLICT`, not a global refutation of the shared-bias mechanism.

## 3a. Decisions and Rejected Alternatives

- **Decision:** preserve v1 official analysis and add a separately labelled D-43 interpretation. **Rationale:** v1 authenticates its frozen eight-file instrument and correctly rejects post-hoc reruns. **Rejected alternative:** changing the original global verdict and presenting it as preregistered. **Confidence:** high.
- **Decision:** state a narrow shared-bias conclusion. **Rationale:** C1/C2/C3 and rereview support it, while R5 control cells, R3/R4, and G6 limit it. **Rejected alternative:** a universal mechanism claim. **Confidence:** high.

## 4. Files Touched

- `dev/isdm-phase-c-d43-interpretation.R`: fail-closed addendum writer and control/shared/malformed/overwrite self-tests.
- `dev/isdm-phase-c-findings.md`: qualified result and evidence path.
- This report, the check-log entry, and the Phase C handover.

No README, NEWS, ROADMAP, vignette, roxygen, Rd, source likelihood, or validation-debt register changed. The convention-change cascade is inapplicable.

## 5. Checks Run

```sh
NOT_CRAN=true Rscript --vanilla dev/isdm-bias-campaign.R ...
# Totoro campaign PASS: 19,800 scheduled fits; never GitHub Actions.

Rscript --vanilla dev/isdm-phase-c-verify-campaign.R ...
# Original independent campaign audit PASS; receipt SHA-256
# 4a1df5570a4231366c6ec9a7925a7d97fc1f81363c2d0a0c5ce865d60e268f91.

Rscript --vanilla dev/isdm-phase-c-d43-interpretation.R --self-test
# PASS: omega=0 scope conflict, omega>0 refutation, malformed-schema reject, and overwrite refusal.

git diff --check
# PASS.
```

`devtools::test()`, `devtools::check()`, `devtools::document()`, and pkgdown checks were not run because this lane changes only dev scripts and internal evidence records.

## 6. Tests of the Tests

The addendum tests boundary/negative paths: omega=0 vs omega>0, missing `omega`, and output overwrite. They are prophylactic for a post-analysis interpretation guard, not a new estimator or recovery test.

## 7a. Issue Ledger

#943 remains open because this developer-only campaign is not merged or public. #944--#946 remain open and out of scope; no issue state was changed.

## 8. Consistency Audit

```sh
rg -n -i 'isdm|integrated[ -]sdm|H_sink|phase c|#943' README.md NEWS.md ROADMAP.md docs/design docs/dev-log vignettes R
rg -n 'gllvmTMB\\(' R vignettes README.md NEWS.md docs/design
rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S|meta_known_V|gllvmTMB_wide|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(' README.md NEWS.md docs/design vignettes
```

The first scan found expected historical/dev-lane records; no reader-facing integrated-SDM claim exists. The latter two are status checks only; this lane changes none of their surfaces or conventions.

## 9. What Did Not Go Smoothly

D-43 found that the global R5 rule promoted predicted omega=0 control behaviour into an overbroad global conclusion. An attempted v1 rerun was correctly rejected by frozen-instrument authentication and was reverted. A local repeat of the independent audit cannot bind Totoro absolute paths from the mirror; the original remote audit receipt remains authoritative.

## 10. Known Residuals

No public capability was promoted and #943 remains open. This is not real-data validation, a detection model, disjoint-unit analysis, a spatial-ecology fit, or an API claim. G5/A6 has 14% exclusions; R3/R4 are unresolved; G6 is unsupported.

## 11. Team Learning

Curie verified provenance/pairing/retained failures. Fisher caught the scope overreach and confirmed no result or threshold changed. Noether set the causal boundary. Shannon found one unrelated Cursor PR (#951), with no overlap.

## 12. Cross-Product Coverage

The campaign covers its frozen shared-bias grid, exact pairing, all-completed and both-pdHess summaries, and the stated G1--G6 sensitivities. It does NOT cover real data, detection-process estimation, disjoint sampling units, spatial ecological random effects, `d` selection, package API behaviour, or a universal recording-bias mechanism. Preserve the artifact root, leave #943--#946 open, and require a newly scoped campaign for any broader hypothesis.
