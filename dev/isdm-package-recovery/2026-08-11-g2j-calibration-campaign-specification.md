# Proposed G2k calibration campaign specification — not authorized to launch

This specification is the only campaign recommendation produced by G2j.  It
is immutable once approved; this document does not authorize execution.

## Purpose

Estimate the all-attempt frequency with which the unchanged, six-species G2i
estimator satisfies its frozen numerical admission and known-truth recovery
criteria.  It tests component allocation under the exact G2h 360-cell,
three-visit, GBIF-Poisson + PA-cloglog DGP.  It does not test a redesigned
model, alternative threshold, or public workflow.

## Frozen arms and denominator

- `R = 150` independent seeds: `86201L` through `86350L`; none reuses G2h or
  G2i seed `86121L`/`86122L`.
- One attempt per seed; no retry or replacement.  Every started seed remains
  in the denominator, including fit errors, invalid profiles, or numerical
  admission failures.
- The estimator is the exact G2i final-polish route: rank-one `Lambda`, six
  free diagonal `Psi`, `n_init = 3`, and no AGHQ/ridge/change of source gate.
- Record separately: structural diagnostics, final gradient, each of the five
  recovery metrics, per-species Psi error, profile ledger, restart ledger,
  error class, elapsed fit/profile time, and SHA/file hashes.

The primary denominator is 150.  Report the proportion passing each criterion
and the joint criterion with binomial Monte Carlo SE
\(\sqrt{\hat p(1-\hat p)/150}\) (at most `0.0408`).  Never condition the
primary recovery proportion on optimiser success; conditional summaries may be
secondary only and must retain their denominator explicitly.

## Resources and estimate

The retained G2i pre-run measured `428.360` seconds per seed (fit plus six
profiles).  At 150 single-threaded workers the campaign is about `17.85`
core-hours and uses **150 total Totoro cores maximum**.  Request a conservative
20-minute wall allocation, with BLAS/OpenMP threads pinned to one.  No GitHub
Actions artifacts; retain private manifests and failures locally.

## Gates before launch

1. A fresh private G2k runner must pass a no-fit contract test that proves the
   exact seed grid, no-retry rule, all-attempt ledger, SHA binding, and output
   closure.
2. One new representative local pre-run must produce a non-empty result root
   from that exact campaign runner.  It is a launch-validation artifact, not a
   replacement of G2i seed 86122 or a criterion relabel.
3. Explicit user approval is required after the fresh runner/pre-run receipt.

The campaign is **not authorized** until all three gates are satisfied.
