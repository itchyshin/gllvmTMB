# After Task: private VA/EVA approximation-engine spine

## Goal

Make the existing VA-R3 and sealed EVA Gate-1 prototypes usable together for
private research comparison without exposing an approximation API or claiming
general marginal likelihoods.

## Implemented

`R/approximation-engine.R` supplies an unexported common result contract and
strict dispatcher.  `dev/va-eva-comparator.R` produces separate VA and EVA
records, retains failures, and labels exact calculations as oracle/reference
only.  `dev/va-eva-comparison-runner.R` then executes private multi-trial VA
and sealed Bernoulli EVA comparison tracks against `gllvmTMB()` Laplace and
the matching `gllvm::gllvm(method = "VA"/"EVA")` route.  EVA's four sealed
files are restored byte-identically and checked by the provenance gate.

## Mathematical Contract

VA records only `negative_elbo_gh`; EVA records only
`negative_ell_eva_taylor2`.  Both are minimisation quantities with
`model_selection_comparable = FALSE`.  VA admits complete multi-trial
binomial-logit loadings-only data before constructing its objective.  EVA
admits only its complete sealed Bernoulli fixture and evaluates fixed
coordinates; it has no fitted quantities.  Exact truth is a supplied
oracle/reference, never an estimator or model-selection target.

## Files Changed

New private code: `R/approximation-engine.R`, `R/eva-proto.R`,
`inst/tmb/gllvmTMB_eva.cpp`, `tests/testthat/test-approximation-engine.R`, and
`tests/testthat/test-eva-gate1.R`.  Private support: `dev/va-eva-comparator.R`
and `dev/va-eva-engine-spine/` (manifest, sealed-source gate, smoke receipt).
`DESCRIPTION` adds `jsonlite` to `Suggests`, matching the sealed evaluator's
existing `jsonlite::fromJSON()` dependency. No example, roxygen, Rd, public
API, or user-facing documentation file changed.

## Checks Run

- `Rscript --vanilla dev/va-eva-engine-spine/check-sealed-sources.R .` — PASS;
  all four EVA blobs match `3b479354`, VA sources match HEAD, forbidden inputs
  are absent, and adapter/comparator imports are scanned.
- `Rscript --vanilla -e 'devtools::test(filter = "va-r3-prototype")'` —
  133 pass, 0 fail.
- `Rscript --vanilla -e 'devtools::test(filter = "(va-r3-prototype|eva-gate1)")'`
  — EVA Gate-1 23 pass, 0 fail; the separately rerun VA result above is the
  complete retained VA receipt.
- `Rscript --vanilla -e 'devtools::test(filter = "approximation-engine")'` —
  34 pass, 0 fail, 1 expected skip (the absence-helper branch is inapplicable
  when sealed helpers are present).
- `VA_EVA_COMPARATOR_SMOKE=true Rscript --vanilla dev/va-eva-comparator.R` —
  `VA_EVA_COMPARATOR_CONTRACT_SMOKE_PASS`.
- `sh dev/va-eva-executable-comparisons.sh {multitrial|bernoulli|va_exact|eva_exact}`
  followed by `sh dev/va-eva-executable-comparisons.sh assemble` — PASS.  The
  retained manifest records six actual engine/comparator calls: internal VA,
  gllvmTMB Laplace, gllvm VA; fixed EVA evaluation, gllvmTMB Laplace, gllvm
  EVA.  The VA H15/H25/H61 fixed-coordinate ladder spread is `2.842e-13`.
  The VA independent-integral gap is `8.882e-15`; the EVA R-versus-C++ parity
  gap is `4.441e-16`.
- `Rscript --vanilla dev/va-eva-engine-spine/check-executable-comparison.R .`
  — PASS.
- `git diff --check` — PASS.

Deliberately not run: `devtools::check()`, pkgdown checks, article rendering,
remote compute, Gate-2R, or broad recovery.  This Arc touches no public prose,
roxygen, parser, or exported interface; a package check is also not a clean
graduation gate until the dependency decision below is made.

## Tests Of The Tests

The adapter tests pair valid strict regimes with invalid family/link/unique
inputs before objective construction; EVA's missing-helper, fixed-evaluation,
and no-source-injection boundaries are exercised.  The comparator smoke asserts
non-comparability, retained VA failure records, uncalled LA/gllvm hooks,
reference-only exact inputs, and EVA's unavailable fitted fields.

## Consistency Audit

The following scans were run verbatim:

```sh
rg -n "approximation_engine|VA-R3|EVA Gate-1|EVA_TAYLOR2|ELBO_GH" README.md ROADMAP.md NEWS.md vignettes man NAMESPACE DESCRIPTION || true
rg -n "approximation_engine|VA-R3|EVA Gate-1|EVA_TAYLOR2|ELBO_GH" R tests dev
```

The public-surface scan returned no matches.  The private scan found only the
new private spine and pre-existing VA prototype/test labels. `NAMESPACE`, NEWS,
README, Rd, vignettes, and `src/gllvmTMB.cpp` remain unchanged. `DESCRIPTION`
now declares the sealed evaluator's `jsonlite` dependency. No validation-debt row was changed because no capability is
advertised.

## What Did Not Go Smoothly

The worktree did not contain the sealed EVA files despite the planning receipt;
they were restored from the pinned commit rather than assumed present.  Noether
rejected the first score/fitted-result contract; its three P1 findings were
repaired and must remain regression-fenced. Rose identified the sealed
evaluator's undeclared `jsonlite` dependency; the maintainer's later merge
instruction authorized adding it to `Suggests`.

## Team Learning

Gauss implemented and then repaired the adapter; Curie built the comparator;
Emmy sealed provenance; Rose performed the mechanical audit; Noether performed
the mathematical review.  The key lesson is that a common diagnostic schema
must not imply a common inferential score or turn a fixed evaluation into a
fit.  A second lesson is operational: run the VA and EVA TMB templates in
separate R processes, then assemble their retained raw records without loading
either template.  Their continuation reviews passed after requiring the H61
ladder, provenance-bound manifest, parity-only EVA wording, and explicit
separation statuses.

## Known Limitations

This is private development code, not an experimental public API.  EVA is
sealed Gate-1 fixture-only and has no optimizer.  VA remains limited to its
existing complete multi-trial binomial-logit loadings-only regime and current
variance gate. Exact-truth hooks are small-fixture references only. The
`jsonlite` dependency is now declared in `Suggests`; package checking must
still confirm its availability in the target installation.

The newer upstream variance-gate handover (`origin/main:docs/dev-log/handover/
2026-07-26-codex-handover-va-variance-gate.md`) also shows that its brute-force
truth ladder fails to converge in the high-variance/sparse regime.  This Arc's
two scalar oracle receipts therefore prove only their fixed small-coordinate
calculations; they do not validate any high-variance fit-level comparison.

The sealed two-by-two Bernoulli fixture is completely separated in one trait.
The external gllvmTMB-Laplace and gllvm-EVA calls are consequently retained as
`boundary_or_invalid_for_comparison`, despite optimizer termination codes;
they are failure-retention evidence, not external-fit agreement.

## Next Actions

Before an API-exposure Arc, decide whether the sealed evaluator remains the
right dev-only containment. Only after that decision should a new, separately
approved Arc assess a constrained experimental approximation selector and its
validation evidence.

At continuation closeout the isolated branch has local commits and remains
behind moving `origin/main`.  Do not automatically rebase it; rerun lane
preflight before any integration.
