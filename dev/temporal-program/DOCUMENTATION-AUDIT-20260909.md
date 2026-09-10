# Temporal documentation audit — 2026-09-09

## Question

Which current reader-facing or canonical documents still describe the
pre-temporal five-source covariance grid after temporal became the sixth source
row?

## Method

The audit searched `README.md`, `NEWS.md`, `R/`, `man/`, `vignettes/`,
`docs/design/`, and `docs/dev-log/` for `5 x 3`, `5 × 3`, and `five
correlation sources`, then read the surrounding context.

## Current six-source surfaces

These current surfaces already use the six-source contract and need no
temporal-grid wording change:

- `README.md` describes the experimental temporal row and its local boundary.
- `docs/design/01-formula-grammar.md` defines the 6 x 3 grammar, temporal
  semantics, source-pair admission, and the six-row grid.
- `vignettes/articles/api-keyword-grid.Rmd` renders the temporal row and calls
  the surface a 6 x 3 grid.
- `R/temporal.R`, `man/temporal_latent.Rd`, and `man/gllvmTMB.Rd` describe the
  temporal keywords and their bounded source-pair scope.

## Required integration edits

The following live internal surfaces still state the old grid and must be
updated when their shared-file owners release their leases:

| File | Current wording | Required correction |
|---|---|---|
| `docs/dev-log/known-limitations.md` | “The 5 x 3 covariance keyword grid…” | Say “6 x 3”, list temporal, and retain the current local-only temporal boundary. |
| `docs/design/35-validation-debt-register.md` | “Formula grammar (5x3 keyword grid plus modifiers)” | Say “6x3”; add or reconcile the temporal grammar/evidence rows with their executable gates. |

`NEWS.md` contains a five-source statement in a historical release entry. It
records the state at that release and must not be retrospectively rewritten.

## Coordination boundary

Preflight found both required shared files divergent in active lanes. This
audit intentionally does not edit them. The receiving integration writer should
apply the two corrections together and rerun the documentation check.
