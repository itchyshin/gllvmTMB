# CRAN 0.7 v3 production campaign

**Host:** Totoro, Linux, R 4.5.3  
**Start:** 2026-08-08 22:18:41 UTC  
**Finish:** 2026-08-08 22:51:12 UTC  
**Workers:** 31, with BLAS and OpenMP fixed to one thread per worker  
**Frozen source archive SHA-256:**
`c0372f037738a902c0c6d7ecd60f4170fcfc9d1d163709456eb0cd9f91615996`  
**Frozen pilot-gate SHA-256:**
`350de2efe1304102f18fd184e4156508ca3b61c3418beda8669af8109fba3f2b`

Totoro completed 12,400 of 12,400 production attempts: 6,000 core, 3,200
silent-failure, and 3,200 robustness attempts. Every attempt matched its
immutable manifest key; no attempt was missing, extra, duplicated, or
unclassified. The remote `sha256sum -c SHA256SUMS` check passed for all 15
compact results and full manifests. The compact files were copied to
`/tmp/gllvmtmb-cran07-production-v3-results-20260808`; every copied SHA-256
matched the remote ledger. Raw per-attempt RDS files remain on Totoro under
`/home/snakagaw/gllvmtmb_cran07_production_v3_20260808` and are not committed.

The frozen v3 closeout returned `HOLD`. It contained a fail-closed component
schema defect and machine-roundoff RMSE failures, so its broad label is not the
scientific adjudication. The separately frozen
`cran07-v3-production-psi-schema-adjudication-v1` overlay:

- verifies the exact production and pilot input hashes;
- normalizes only exact structural-zero off-diagonal Psi ledger rows;
- applies a numerical-zero rule only to rank-one shared correlations whose
  absolute errors are at most `64 * .Machine$double.eps`;
- retains every substantive beta, stationarity, Hessian, boundary, covariance,
  Psi, correlation, and robustness failure;
- holds NB2 because its preregistered dispersion estimand was not extracted.

That adjudication leaves the broad result at **HOLD**. Poisson-log ordinary
latent is the only complete small/large family pair that passes. No G3 core
freeze, version bump, candidate freeze, or upload is authorized by this
campaign.

`production-files.csv` records the exact compact-file hashes and sizes.
The executable adjudication, cell verdicts, independent-reader boundary, and
its own SHA ledger are in the sibling
`2026-08-08-cran07-v3-production-adjudication-psi-v1` directory.
