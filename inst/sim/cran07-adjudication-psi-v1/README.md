# Frozen post-production Psi-schema adjudication v1

This overlay reads the three exact v3 production summaries and exact v3 pilot
receipt by compiled SHA-256. It performs no fit and does not modify v2, v3,
registries, manifests, attempt files, estimands, or raw summaries.

The sole schema correction is a derived-ledger normalization. The frozen
extractor passes the diagonal Psi matrix to `cran07_matrix_rows()`, which marks
all lower-triangle entries applicable, including structural zero
off-diagonals. The overlay first asserts that every such row has exactly
`truth = estimate = 0`, then marks it non-applicable in memory. The frozen
scientific schema remains diagonal Psi only. Raw summaries are untouched.

All v3 production health, beta, Sigma, Psi, correlation, catastrophic-error,
RMSE, family-pair, and three-campaign closeout gates are rerun unchanged. The
broad verdict is whatever those gates return after this schema-only correction.
For structurally fixed rank-one shared correlations only, errors no larger than
`64 * .Machine$double.eps` are classified as numerical zero before the RMSE
direction verdict. This is not applied to any substantive RMSE. NB2 is
explicitly held because its preregistered primary dispersion estimand was not
extracted into the frozen summaries.
