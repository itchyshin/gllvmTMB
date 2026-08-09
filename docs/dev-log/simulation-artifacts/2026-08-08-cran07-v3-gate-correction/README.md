# CRAN 0.7 v3 gate correction freeze

**Frozen:** 2026-08-08, before any v3 fit.  
**Status:** specification and pure tests only; zero model fits and no compute
launched.  
**Owner:** Curie bounded gate-repair lane.

## Why v3 exists

The v2 pilot completed all 680 planned fits and was useful discovery evidence.
Its executable `gate_summary`, however, required detector sensitivity within
each cell even when that cell contained no planted catastrophic positives. It
also did not execute the preregistered Sigma, Psi, correlation, or sample-size
RMSE gates. This made the v2 aggregate verdict invalid for promotion.

V2 is therefore discovery-only. No v2 production run is authorised. V3 changes
campaign IDs, seed offsets, and gate aggregation before any new fit; it does not
change the DGP, model, estimator, attempt schema, canonical registries, registry
hashes, or scientific thresholds.

## Immutable inheritance

The v3 code sources the v2 files under `inst/sim/cran07-core/` for fixture
generation, fitting, extraction, health classification, and atomic attempt
persistence. The three v2 registry files are reused by their exact canonical
paths and compiled SHA-256 values. `campaigns.csv` freezes the new IDs and
disjoint seed offsets. A v2 ID, unknown ID, copied registry, altered registry,
partial pilot manifest, arbitrary replicate count, or seed mismatch fails
before fitting.

The symbolic-to-implementation alignment is unchanged from the three v2
registry READMEs: v3 introduces no model term or estimand. The correction is
only the mapping from complete attempt/estimand ledgers to release gates.

## Corrected decision structure

Pilot cell admission and global detector qualification are separate. Every one
of the 34 cells receives exactly 20 attempts and must satisfy the cell rules in
`gates.csv`. Detector sensitivity and specificity are then evaluated once over
the complete 680-attempt ledger. Both detector denominators must be nonzero.
Every non-`usable` status, including an unclassified status, counts as unusable;
the unclassified limit is separate. The receipt lists admitted and held cells.
A detector-qualified nonempty subset may proceed without all 34 cells passing;
held cells remain excluded from production.

Production uses exactly 400 attempts for each explicitly admitted cell. It does
not require per-cell sensitivity in a healthy cell with zero planted positives.
It does require specificity when negatives exist, the exact false-negative
upper bound, health rates, beta bias, full applicable Sigma/Psi/correlation
gates, and the six frozen sample-size RMSE comparisons. All missing components
and denominators fail closed. Every production component and RMSE side requires
exactly 400 finite applicable rows with replicates `1:400`. Missing Psi is N/A
only for `dep()` and fails for `indep()` or `latent()`. Expected beta names come
from a base-R model matrix built from the frozen registry contract; all other
component identities come from the algebraic trait grid. They are not learned
from observed output or an installed package. Missing or unexpected applicable
keys fail. `gates.csv` is the concise threshold ledger;
`inst/sim/cran07-v3/README.md` records the operational definitions.

The RMSE comparison independently resamples the small- and large-sample error
vectors within each of 2,000 bootstrap draws. The deterministic base seed is
370830001; the pair and sorted estimand-component index create a distinct
derived seed. The gate is

`RMSE_large <= RMSE_small + SE_boot(RMSE_large - RMSE_small)`.

## Manifest-aware evidence

`run-batch.R` writes the entire frozen stage manifest before attempts execute.
`summarize-batch.R` requires that manifest and stores its SHA-256, registry hash,
campaign ID, stage, expected cell set, expected attempt count, and observed
attempt count in the saved summary. It rejects missing and extra attempt keys.
The bijection covers campaign ID, registry SHA-256, canonical cell number, cell
ID, replicate, and seed. Completeness is never inferred from present files.

After the three pilot summaries exist, `pilot-global-gate.R` requires all three
distinct v3 IDs, verifies complete pilot identities, reconstructs the exact
34-cell expectation from the canonical registries, evaluates the 680-attempt
detector gate, and saves the combined admission receipt.

`production-closeout.R` requires core, silent-failure, and robustness production
summaries plus the pilot receipt. It verifies every explicit admitted subset,
reports held pilot cells, and runs an RMSE pair only when both core cells were
admitted. Either side absent produces `HOLD` for that family claim. The broad
verdict is `PASS` only if every admitted cell across all three campaigns and all
six family pairs pass. An absent silent-failure or robustness summary is `HOLD`.

## Verification at freeze

Commands run from the repository root:

```sh
Rscript --vanilla inst/sim/cran07-v3/self-test.R
Rscript --vanilla -e 'fs <- Sys.glob("inst/sim/cran07-v3/*.R"); for (f in fs) parse(file = f)'
sha256sum -c docs/dev-log/simulation-artifacts/2026-08-08-cran07-v3-gate-correction/SHA256SUMS
```

The self-test exercises both sides of every new guard: exact 3/20 versus 4/20
unusable attempts; complete versus incomplete manifests; globally defined
detector denominators versus zero/missing denominators; passing versus failing
matrix, Psi, and correlation thresholds; improving versus worsening RMSE; and
present versus missing RMSE components. Adversarial fixtures also cover unknown
status as unusable, a qualified subset with held cells, two-row production
components, mode-specific missing Psi, two-row RMSE inputs, an absent pair side,
the same missing beta on both RMSE sides, missing silent-failure/robustness
summaries, and all full-identity coordinates. It also exercises zero per-cell
sensitivity. No model is fitted.

## Boundary

This freeze does not adjudicate any scientific cell, authorise compute, promote
the dependable-core claim, change package code, or authorise CRAN submission.
V3 fitting remains Totoro/DRAC work and never GitHub Actions.
