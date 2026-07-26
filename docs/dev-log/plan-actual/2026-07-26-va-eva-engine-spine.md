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
  and deliberately uncalled Laplace/gllvm hooks.
- A byte-level sealed-source checker and source manifest.

## Deliberate deviations

1. The planned EVA “import” was necessary because current `origin/main` did not
   contain the four sealed Gate-1 files.  Only those four files were restored
   byte-identically from `3b479354`.
2. The initial common score field was rejected in Noether review.  It was
   replaced with engine-specific negative quantities and an executable
   `model_selection_comparable = FALSE` fence.
3. EVA produces no fitted quantities.  The fixed Gate-1 evaluation is carried
   under `fixed` and `evaluation`; its fitted block is explicitly unavailable.

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
