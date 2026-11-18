# Gate-A information review: two-field private spatial iSDM

**Reviewer:** Curie (independent design-only review)
**Verdict:** `ADEMP_CONTRACT_READY_PENDING_SHARED_RANGE_CHOICE`

## Required design correction

The information design must not describe a larger number of observations as a
single sample-size axis.  It separately varies cells, geometry (infill versus
increasing domain), range-to-spacing ratio, PA coverage, and source overlap.
Paper 1 (`S=3`) and Paper 2 (`S=6`) remain separate simulation families; their
species coordinates are not independent replicate units.

## Proposed ordinary panel

For each family, use a resolution-V half fraction of five factors after Gate A
freezes physical values: cells, geometry route, shared range/spacing, PA
coverage, and source-support overlap.  The 16 ordinary cells use `R=20`
seed-pinned replicates only after a separately approved timing receipt.  The
current `C=360` then `C=1,000` progression is a practical campaign staging
rule, not a causal contrast across every spatial-design factor.

## Required attacks and reporting

Retain disconnected support, weak overlap with ecological/bias covariate
correlation, near-aliasing of the two fields, near-zero field-variance cases,
and an edge-range case.  Score shared trait covariance and diagonal Psi
separately; score ecological and GBIF-bias field maps separately and include a
field-swap diagnostic.  Every started replicate remains in the all-attempt
denominator; numerical-admission-by-spatial-recovery and
numerical-admission-by-Psi-recovery tables are required.

## Values deliberately not invented

The programme cannot responsibly freeze absolute domain size, physical spacing,
mesh cutoff, range, field standard deviations, PA footprint, or support
geometry until Gate A selects the shared-range architecture and the literature
source map is reviewed.  The retained `r=3` repeated PA design and the G2
fixed-effect truth remain reusable inputs, not spatial evidence.

## Evidence inspected

- `docs/design/111-isdm-nonspatial-recovery-protocol.md`
- `dev/isdm-package-recovery/2026-08-12-paper2-psi-information-design.md`
- `docs/design/64-spatial-dep-latent-derivation.md`

No DGP, threshold, code, simulation, fit, profile, or compute job was changed
or run by this review.
