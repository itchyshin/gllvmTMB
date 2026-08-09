# CRAN 0.7 v3 pilot receipt

## Verdict

**PASS for production admission.** The corrected v3 pilot completed all 680
predeclared attempts (34 cells x 20) on Totoro. The global detector gate passed
with sensitivity 0.95 and specificity 0.9409. Thirty-one cells were admitted
to the 400-attempt production campaign.

The three held cells are deliberately difficult Gaussian latent challenge
cells: correlation 0.98, `Psi = 0.01`, and `Psi = 100`. They are not averaged
into the ordinary-core result and do not enter production. Every ordinary
small/large family pair, every silent-failure cell, and every robustness cell
was admitted.

## Immutable identity

- Campaign IDs: `cran07-core-recovery-v3`,
  `cran07-silent-failure-v3`, and `cran07-robustness-v3`.
- Source archive SHA-256:
  `c0372f037738a902c0c6d7ecd60f4170fcfc9d1d163709456eb0cd9f91615996`.
- Pilot-gate RDS SHA-256:
  `350de2efe1304102f18fd184e4156508ca3b61c3418beda8669af8109fba3f2b`.
- Raw immutable attempts remain on Totoro under
  `/home/snakagaw/gllvmtmb_cran07_pilot_v3_20260808/pilot/final`.
- Compact summaries and full manifests were transferred to
  `/tmp/gllvmtmb-cran07-pilot-v3-results-20260808` and independently verified
  against Totoro's SHA-256 ledger.

## Execution

- Host: Totoro, R 4.5.3.
- Workers: 32; OMP/BLAS backends pinned to one thread per worker.
- Start: 2026-08-08 22:12:06 UTC.
- Finish: 2026-08-08 22:13:53 UTC.
- Attempt accounting: 680 expected, 680 terminal, zero unclassified, zero
  nonfinite core estimands.

Two packaging-only launch attempts stopped before any fit because transferred
helper filenames did not match their launcher aliases. Both showed exactly zero
attempt files. The corrected launch above is the only v3 pilot with scientific
output.

## Gate correction provenance

Production was not launched under v2. Independent review first found that v2
could not certify per-cell sensitivity with zero positive denominators and did
not execute all preregistered covariance/Psi/correlation/RMSE gates. Two rounds
of adversarial v3 review then closed missing-manifest, unknown-status,
missing-component, and missing-campaign fail-open paths. The final pure suite
and frozen SHA ledger passed before this pilot launched.

