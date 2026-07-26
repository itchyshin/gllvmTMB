# VA/EVA engine spine — plan versus actual

## Locked goal

Create a private shared foundation for the existing VA-R3 and sealed EVA
Gate-1 research prototypes.  Do not expose a `gllvmTMB()` selector, alter
public documentation or package metadata, run Gate-2R, or make a capability
claim.

## Delivered

- A private `gllvmTMB_approximation_result` contract and
  `.approximation_engine_fit()` dispatcher.
- VA-R3 remains complete multi-trial binomial-logit, loadings-only; it delegates
  to the existing fitter.
- EVA remains sealed Bernoulli Gate-1, fixture-only and fixed-coordinate
  evaluation-only.  It is not an optimiser or a general Bernoulli engine.
- A private comparator script with retained failures, oracle-reference fields,
  and executable gllvmTMB-Laplace, gllvm-VA, and gllvm-EVA tracks.
- A byte-level sealed-source checker and source manifest.

## Executable comparison receipt

The completed private receipt runs the multi-trial VA track through internal
VA-R3, `gllvmTMB()` Laplace, and `gllvm::gllvm(method = "VA")`; it runs the
sealed Bernoulli EVA track through fixed Gate-1 EVA evaluation, `gllvmTMB()`
Laplace, and `gllvm::gllvm(method = "EVA")`.  Every call is retained in the
raw RDS manifest.  Fixed-coordinate scalar-oracle gaps are `8.882e-15` (VA)
and `4.441e-16` (EVA).  These are oracle checks, not cross-engine rankings.
The VA comparison fit is H61, with a fixed-coordinate H15/H25/H61 ladder
spread of `2.842e-13`.  The sealed Bernoulli fixture is separated in one trait,
so its external Laplace/EVA calls are retained as
`boundary_or_invalid_for_comparison`, not healthy comparators.

## Deliberate deviations

1. The planned EVA “import” was necessary because current `origin/main` did not
   contain the four sealed Gate-1 files.  Only those four files were restored
   byte-identically from `3b479354`.
2. The initial common score field was rejected in Noether review.  It was
   replaced with engine-specific negative quantities and an executable
   `model_selection_comparable = FALSE` fence.
3. EVA produces no fitted quantities.  The fixed Gate-1 evaluation is carried
   under `fixed` and `evaluation`; its fitted block is explicitly unavailable.
4. The EVA R scalar calculation is a sealed R-versus-C++ parity reference, not
   an independently sourced truth instrument.

## Non-graduation constraint

The sealed `R/eva-proto.R` calls `jsonlite::fromJSON()`, while this Arc's locked
public-surface boundary forbids a `DESCRIPTION` change.  Therefore this branch
is a private development foundation only, not a merge/release recommendation.
The next Arc must explicitly choose either an approved dependency declaration
or a different dev-only containment strategy; it must not silently change the
sealed blob.

## Boundaries retained

- No `NAMESPACE`, `DESCRIPTION`, NEWS, Rd, vignette, README, pkgdown, or
  `src/gllvmTMB.cpp` change.
- No VA Bernoulli widening, separation guard, Gate-2/Gate-2R runner, fixture,
  or historical smoke artifact.
- No Laplace/gllvm output called truth and no VA/EVA objective comparison.
