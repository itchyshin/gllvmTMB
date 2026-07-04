# Augmented Diagonal-Compatibility Wording Cleanup

Date: 2026-06-18 23:16 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Continue the post-coevolution `unique()` deprecation cleanup by removing
internal labels that still used "ordinary unique random regression" as the noun
for the augmented ordinary diagonal compatibility path.

## Changed

- Updated `R/fit-multi.R` so internal augmented reaction-norm diagnostics and
  comments say "ordinary diagonal-compatibility random-regression" instead of
  "ordinary unique random-regression".
- Preserved explicit `unique(1 + x | unit)` examples only where they describe
  compatibility syntax.

## Verification

- `Rscript --vanilla -e 'parse("R/fit-multi.R"); devtools::test(filter = "ordinary-latent|canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")'`
  -> passed with 3 expected INLA skips. The parse expression printed because
  it was not wrapped in `invisible()`.
- `rg -n "ordinary unique|augmented ordinary unique|ordinary unique random-regression|Unsupported augmented ordinary unique|Internal: augmented ordinary unique|common = TRUE.*ordinary.*unique|new code.*unique|recommended.*unique" R/fit-multi.R R/extract-sigma.R R man vignettes README.md NEWS.md docs/design/00-vision.md docs/design/01-formula-grammar.md docs/design/61-capability-status.md tests/testthat/test-unique-family-deprecation.R`
  -> remaining hits were design rows documenting replacement syntax,
  compatibility suggestions, or source-specific `phylo_unique()` wording.
- `git diff --check`
  -> clean.

## Definition-Of-Done Notes

- Implementation: internal wording changed locally; no behavior changed.
- Simulation recovery: not applicable.
- Documentation: not user-facing; no roxygen/Rd regeneration needed.
- Runnable example: not applicable.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: lifecycle cleanup discipline applied. No formula grammar,
  likelihood, or TMB parameterization changed.

Still not claimed: keyword removal, source-specific/kernel latent-Psi folding,
Paper 2 multi-kernel explicit-Psi support, bridge completion, release
readiness, or scientific coverage completion.
