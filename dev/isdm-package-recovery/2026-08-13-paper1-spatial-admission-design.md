# Paper 1 spatial Gate C1 — numerical-admission design

**Status:** design only.  It does not modify the estimator, likelihood, DGP,
maps, thresholds or the one consumed B2 root; it authorises no fit, profile,
simulation, retry, campaign or empirical analysis.

## Question

The retained B2 fit is fully observable but was classified Case D / non-admitted
with `unsupported_raw_gradient_state` at maximum raw gradient 0.003392914.
Gate C1 asks whether the named maximum-gradient coordinate is a correctly
mapped identifiable component of the frozen two-field likelihood, and whether
the nonspatial classifier intentionally excludes it or has a precisely defined
classifier-domain gap. It does not treat code 0, a PD Hessian, or a raw gradient
below `1e-2` as admission.

## Immutable inputs

- The B2 source/receipt and fit at commit `d5c1481c`; its `FIT_RETURNED` state
  and `PRIVATE_NUMERICAL_ADMISSION_HOLD` remain historical evidence.
- The shared-range two-field DGP: ecological intercept and GBIF-indicator slope
  of one `spatial_latent(1 + isdm_gbif | cell_id, d = 1)` term, independent
  true fields, and PA structural exclusion of the GBIF field.
- Exact production objective, derivatives, data, mesh, maps, bounds, parameter
  order, `nlminb` controls and one-start B2 record.  No alternative objective,
  rescaling, tolerance, restart, AGHQ, ridge, map or field architecture may be
  described as a repair of B2.

## Required no-fit Gate C1 record

1. **Gradient-topology receipt:** from the retained B2 ledger/fit only, bind
   all maximum-gradient indices, names, values, ties, boundaries, fixed-Hessian
   state and classifier branch. Statically trace its ordered coordinate through
   R packing into the TMB block/report and fail closed on an ambiguous, reordered
   or duplicated mapping. It must explain why the state is Case D rather than
   silently infer a Case B/C route.
2. **Classifier-envelope test:** enumerate adversarial static inputs around the
   B2 topology and prove that raw pass, named boundary, Case C, a spatial-only
   maximum, tied maxima, unknown blocks and invalid prerequisites remain mutually
   exclusive. B2's actual topology must remain Case D and no fixture may call an
   optimizer or model constructor.
3. **Candidate-decision memo:** choose exactly one of `NO_CANDIDATE` or a
   separately named future-estimator proposal.  A proposal must declare its
   objective identity, parameter coordinates, input/output state, acceptance
   predicate, failure ledger and why it is scientifically admissible.  It may
   not borrow the boundary-only Case-B polish by analogy.
4. **Spatial source-purity regression:** retain no-fit evidence that a GBIF
   field perturbation cannot change PA eta/NLL and that a one-field fit cannot
   be presented as two fields.  This protects the Paper 1 figure claim even if
   the numerical question is later resolved.

## Later approval criterion

Only an independently reviewed Gate C1 packet with a complete topology receipt
and either a reasoned `NO_CANDIDATE` HOLD or one exact new-estimator design may
request implementation.  Any unresolved maximum/tie, a changed invariant, or
an attempt to call the old returned fit a recovered spatial result terminates
the branch at HOLD.  Even a later numerical pass must still earn all-attempt
known-truth field recovery and uncertainty evidence before Paper 1 maps can be
used as results.
