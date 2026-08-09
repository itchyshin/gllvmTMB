# CRAN 0.7 v3 production Psi-schema adjudication v1

**Adjudication ID:** `cran07-v3-production-psi-schema-adjudication-v1`  
**Frozen source tarball SHA-256:** `c0372f037738a902c0c6d7ecd60f4170fcfc9d1d163709456eb0cd9f91615996`  
**Input:** 12,400 of 12,400 completed production attempts plus the frozen v3
pilot receipt.  
**Compute:** zero fits; saved ledgers only.  
**Final broad verdict:** **HOLD**.

## Defect and correction

The v3 closeout mechanically held every cell that emitted Psi. The frozen
extractor passes the diagonal Psi matrix to `cran07_matrix_rows()`, which marks
the full lower triangle applicable: three diagonal components and three
structural-zero off-diagonals for three traits. The scientific schema correctly
listed only diagonal Psi.

This overlay asserts that every applicable off-diagonal Psi row has exactly
`truth = estimate = 0`, then marks those rows non-applicable in a derived
in-memory ledger. It normalized 15,600 core, 9,600 silent-failure, and 9,600
robustness rows. It does not change the raw summaries, estimates, attempts,
manifests, registries, seeds, DGPs, substantive thresholds, cell rules, family
rules, or bootstrap rules. V2 and v3 bytes remain frozen.

Three RMSE direction comparisons involved structurally fixed rank-one shared
correlations and errors of about `1e-16`. The overlay applies an explicit
numerical-zero rule only when the frozen truth has absolute value one and every
absolute error is at most `64 * .Machine$double.eps`. All three qualify. No
substantive RMSE threshold changes.

The NB2 registry names dispersion as a primary estimand, but the frozen
production summaries contain no dispersion rows. The overlay therefore marks
all four admitted NB2 cells `dispersion_evidence_pass = FALSE`; NB2 cannot pass
on covariance evidence alone.

## Exact inputs

`input-hashes.csv` freezes the three production summaries and pilot receipt.
The adjudicator rejects any hash mismatch and verifies the three v3 campaign
identities before producing a verdict.

## Result

All four exact input hashes and campaign identities pass independently of the
scientific verdict; see `identity-gate.csv`. After normalization,
`component_schema_pass` is true for all 31 admitted production cells. The broad
verdict remains **HOLD** on the preregistered scientific gates:

- core: 7 of 15 admitted cells pass all cell gates;
- silent-failure: 4 of 8 pass;
- robustness: 3 of 8 pass;
- Poisson is the only family pair that passes; the other five hold because at
  least one production cell fails;
- NB2 explicitly holds because dispersion evidence is absent, in addition to
  any covariance-component failures;
- three core challenge cells remained held at the pilot gate:
  `g_latent_rho_boundary98`, `g_latent_psi_small`, and
  `g_latent_psi_large`.

The failed cell rows are frozen in `failed-cell-gates.csv`.
`rmse-failures.csv` contains only its header because the three narrowly
qualified numerical-zero comparisons pass; the full derived RMSE gate is
hash-frozen as an external adjudication output.

## Verification

```sh
Rscript --vanilla inst/sim/cran07-adjudication-psi-v1/self-test.R
Rscript --vanilla inst/sim/cran07-adjudication-psi-v1/run-adjudication.R \
  CORE.rds SILENT.rds ROBUSTNESS.rds PILOT.rds OUTPUT_DIR
sha256sum -c docs/dev-log/simulation-artifacts/2026-08-08-cran07-v3-production-adjudication-psi-v1/SHA256SUMS
```

The executable reruns all production cell gates, all eligible RMSE component
gates, all six family-pair gates, and the three-campaign broad closeout.
