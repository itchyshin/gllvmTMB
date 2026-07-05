# Structural Random-Slope Guard Audit (Day 3 of the completion arc)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `4d8f7589`
Agent: Claude (read-only audit; one Explore sub-agent gathered evidence)

## Goal

Day-3 completion-arc audit: map the structural random-slope grammar and
extractor shape-safety guards, to find any silent-drop or misinterpretation
risk before designing a Codex hardening slice. Against the hard guard
"source-specific `lv = ~ env` must stay fail-loud." No code changed.

## Outcome

**All five named risk classes are solid: (A) works correctly or (B) fails loud
with a clear message. No (C) silent-drop / misinterpret and no (D) unhandled
cases were found.** The grammar/extractor guard surface has no holes to plug;
any Codex work in this lane is capability expansion, not bug-fixing.

Epistemic scope: this audits the specifically-named risk classes with
test-backed evidence. It is not an exhaustive fuzz of every possible malformed
input; it confirms the guards that the completion plan flagged are present and
tested.

## Findings (each with the guard and its test)

1. **Duplicate slope covariates -- (B) fail-loud.**
   `.assert_distinct_slope_cols()` in `R/brms-sugar.R:1667-1679` aborts at parse
   time ("Duplicate slope covariates are not allowed in augmented LHS terms ...
   rank deficient"), invoked from both wide and long intercept-slope matchers.
   Test: `tests/testthat/test-phylo-dep-slope-s2-gaussian.R:32-50`.

2. **Malformed / parenthesized augmented LHS -- (A) correct.**
   `.strip_lhs_parens()` (`R/brms-sugar.R:1643-1661`) normalises redundant parens
   so `(0 + trait)` is classified intercept-only, not augmented; malformed forms
   (`spatial_latent(foo + x | coords)`) abort in `normalise_spatial_orientation()`.
   Tests: `test-augmented-lhs-guard.R:42-58`,
   `test-spatial-latent-slope-gaussian.R:263-268`.

3. **Source-specific `lv = ~ env` -- (B) fail-loud, comprehensive.**
   `.abort_source_specific_lv()` (`R/brms-sugar.R:2044-2064`) blocks `lv = ~ ...`
   on all ~20 source keywords (`phylo_*`, `spatial_*`/`spde`, `animal_*`,
   `kernel_*`): "`lv` is reserved for ordinary `latent` only ... silently
   dropping `lv` is not allowed." Test: `test-canonical-keywords.R:235-266`
   (20 formulas).

4. **Spatial malformed LHS / orientation -- (B) fail-loud.**
   `normalise_spatial_orientation()` (`R/brms-sugar.R:1829-1954`) accepts
   canonical `0 + trait | coords` and the supported augmented subset, flips the
   deprecated `coords | trait` orientation with a warning (never silently), and
   aborts non-canonical forms. Test: `test-spatial-orientation-parser.R`.

5. **Extractor shape-safety -- (A/B) solid.**
   `extract_Sigma()` validates augmented block dimensions (e.g.
   `phy_unique/indep` requires `length(sd_b) == 2`, aborting otherwise;
   `phy_dep` recovers `s` from `nrow(Sigma)/T - 1`); rotation checks dimensions
   (`R/rotate-loadings.R:431`); ordination extractors return `NULL` when the tier
   is absent rather than emitting a malformed matrix. Test:
   `test-phylo-dep-slope-s2-gaussian.R:279-311`.

## Checks Run

Read-only audit; no test, `devtools::check()`, or `pkgdown::check_pkgdown()`
run because no code changed. Evidence via one Explore sub-agent over
`R/brms-sugar.R`, `R/extract-sigma.R`, `R/extractors.R`, `R/output-methods.R`,
`R/rotate-loadings.R`, and the named `test-*.R` files.

## Files Created / Modified

- Created this after-task report.
- Appended a check-log entry to `docs/dev-log/check-log.md`.

No R, C++, Rd, NEWS, README, vignette, design doc, or validation-register file
changed by this audit.

## Team Notes

Boole: the parser guard surface for the named risk classes is fail-loud and
test-backed; no grammar hole to close.

Rose: no overclaim; the "source-specific `lv` fail-loud" guard is intact and
matches the hard-guard requirement.

Noether/Fisher: no symbolic, likelihood, or inference surface touched.

Shannon: no push or PR; branch remains local, ahead 201.

## Known Limitations And Next Actions

- Any structural-slope Codex slice is capability expansion (new admitted forms,
  engine routing), not guard repair; it should still ship with its own
  fail-loud tests per new form.
- A future exhaustive parser fuzz (Curie lane) could complement this named-class
  audit, but no evidence suggests a hidden hole.
- No push/PR/merge without Shinichi's authorization.
