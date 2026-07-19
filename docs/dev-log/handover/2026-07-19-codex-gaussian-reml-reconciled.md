# Handover — reconciled Gaussian REML contract

Resume in `/private/tmp/gllvmtmb-gaussian-reml-06-reconciled` on branch
`codex/gaussian-reml-certificate-reconciled-20260719` (PR #768).

The branch is a clean-base replacement for closed PR #767. It deliberately
contains only the Gaussian REML contract, oracle tests, dependent ML fixture,
and wording corrections. It must not be rebased through or combined with
`check-log.md`, Bartlett, CI-11, multinomial/tier-2a, or Ayumi history.

Current facts:

- The profile certificate is withheld; do not launch 15,000 replicates or make
  a public small-sample REML-improvement claim.
- `pkgdown::check_pkgdown()` and the focused tests pass.
- Final local `R CMD check --as-cran` reports exactly two visual snapshot
  failures (`test-plot-visual-snapshots.R`) plus the normal new-submission
  NOTE; the prior four predictor-informed-lv fixture failures are fixed.
- PR #768 CI must finish before a final Rose/release-gate readout. Even if it
  passes, the snapshot mismatch and withheld certificate keep the release rung
  at **NOT READY**.

The next mathematically distinct work is the separately authorized 1.0
research-only AGHQ/O3 spike, not an extension of this branch.
