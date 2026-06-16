# After-Task Report: Xcoef Structural-Zero Plan Addendum

Date: 2026-06-16

Branch: `codex/engine-julia-draft-landing`

## Task

Add the maintainer-supplied GLLVM team note on fixing selected
fixed-effect coefficients to zero into the twin finish programme, but
only if it was not already represented.

## Files Changed

- `docs/dev-log/2026-06-16-xcoef-structural-zero-plan-addendum.md`
- `docs/dev-log/after-task/2026-06-16-xcoef-structural-zero-plan-addendum.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## Definition-Of-Done Check

1. Implementation: not applicable. This is a planning addendum, not an
   implementation slice.
2. Simulation recovery test: not applicable. No feature was implemented or
   advertised.
3. Documentation: complete for the addendum. The note names scope,
   non-scope, candidate APIs, implementation questions, minimum evidence,
   and claim boundary.
4. Runnable user-facing example: not applicable yet. The feature remains
   planned design work.
5. Check-log entry: added with the exact duplicate-topic scan command.
6. Review pass: Rose claim boundary applied; Boole/Gauss/Noether/Fisher/
   Curie are named as future lane reviewers, not active signoffs.

## Commands Run

```sh
rg -n "Xcoef_mask|Xcoef_fixed|fixed-effect.*zero|structural zero|coefficient mask|fixed coefficients|mask.*Xcoef|species-specific fixed|trait-specific fixed|observation-by-column|observation.*response.*covariate" ROADMAP.md docs README.md NEWS.md R tests vignettes || true
rg -n "Xcoef_mask|Xcoef_fixed|fixed-effect.*zero|structural zero|coefficient mask|fixed coefficients|species-specific fixed|observation-by-column|observation.*response.*covariate" "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" 2>/dev/null || true
git diff --check
rg -n "implemented|supported|covered|complete|done|CRAN-ready|full parity|Xcoef_mask|Xcoef_fixed|observation-by-response|z\\[i, j, k\\]|structural-zero" docs/dev-log/2026-06-16-xcoef-structural-zero-plan-addendum.md docs/dev-log/after-task/2026-06-16-xcoef-structural-zero-plan-addendum.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md
```

## Results

- No existing `Xcoef_mask`, `Xcoef_fixed`, coefficient-mask, or
  fixed-effect structural-zero lane was found in `gllvmTMB`, `GLLVM.jl`,
  or `GLLVM.jl-integration`.
- Existing `structural zero` hits refer to latent loading constraints,
  covariance-table zeros, or zero-inflated families, not fixed-effect
  coefficient masks.
- `git diff --check`: clean.
- Stale-claim scan: new hits are planned-lane, non-scope, or negative
  claim-boundary language; old `check-log.md` and coordination-board hits
  are historical context.

## Deliberately Not Run

- No package tests, document generation, or pkgdown checks were run for this
  plan-only addendum.
- No GitHub issue was opened from the note. Issue creation should happen
  after Ada chooses whether this belongs in the R-first design queue,
  Julia engine queue, or both.

## Follow-Up

Add `codex/xcoef-structural-zero-spec` after the bridge landing / per-trait
nuisance-parameter specs, unless the maintainer promotes it earlier. The
first spec should keep coefficient masking separate from the harder
observation-by-response covariate design.
