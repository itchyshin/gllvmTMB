# After Task: Destination B S3b closed R adapter

## 1. Goal

Add the authorised private R adapter/test line from an already-fitted native
Gaussian `phylo_rr` object to the closed Julia multivariate precision consumer.

## 2. Scope

Only `R/julia-bridge.R` and a focused test file changed. Ordinary `engine =
"julia"` still rejects structured/phylogenetic terms. No R/C++ likelihood
code, FRK, release, push, merge, registry action, or 0.7.1 expansion changed.

## 3. Model and transport contract

The adapter reconstructs the complete trait-by-site-species response and its
one-based observation-to-tip IDs. It transports the native `Ainv_phy_rr`
triplets, all labelled factor-level tips (including unused-level validation),
augmented-node labels, `n_aug_phy`, and `-log_det_A_phy_rr` exactly once.
The native precision remains canonical; no covariance is rebuilt or inverted.

## 4. Dense covariance and tree rules

For dense `phylo_vcv`, R's existing single ridge/inversion is accepted as the
canonical precision. The original covariance condition number is retained and
warns above `1e8`. For trees, retained metadata verifies the native scale and
determinant convention; it does not create a second precision source.

## 5. Tests

The focused file exercises a non-unit-height tree, sparse augmented pedigree
with two unobserved founders, and ill-conditioned dense covariance; it also
tests invalid tip map, determinant/tree corruption, and continued generic
public-route refusal. A mocked transport test checks the flat call contract.

## 6. Live runtime check and retained evidence

`tests/testthat/run-destination-b-s3b-native-pairs-isolated.R` ran exactly the
three predeclared native R-to-Julia pairs under the ARM-native Julia 1.10
runtime, with callbacks disabled. The source-aligned receipt records **38 passed,
zero failed/skipped/errors/warnings**. It asserts frozen gllvmTMB source commit
`b4d5fee64def88bc768dda1f1f77c29b295edd86` is an ancestor and that every
post-freeze change is confined to the authorised adapter/test/evidence files;
it records the R 4.6.0 ARM build, native shared-object SHA-256, adapter commit,
fixture hashes/seeds/specifications, and hardened GLLVM.jl consumer `fb2c4666`.

| Source form | Structural evidence | Largest endpoint deltas (R vs Julia) |
| --- | --- | --- |
| Height-two tree | Scale `2`; log determinant `4.15888308335967`; all four tips mapped | log likelihood `1.54e-12`; fixed effects `6.88e-8`; phylogenetic covariance `1.26e-7`; residual variance `4.72e-10` |
| Sparse pedigree | Four precision nodes; unobserved founders retained; descendants map to zero-based nodes `2,3`; log determinant `1.38629436111989` | `6.79e-13`; `1.70e-7`; `5.32e-8`; `4.24e-9` |
| Dense `vcv` | Original condition number about `1e9`; R adds `1e-8 I` once; transported precision has three nodes and log determinant `19.018517714708` | `4.13e-13`; `1.81e-8`; `8.55e-8`; `7.58e-9` |

The receipt is
`docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt.json`.
All native fits report convergence code `0`; all closed Julia fits report
`converged = TRUE`.

## 7. Reference boundary

The R source tree is the frozen 0.7.0 reference for model semantics. This
adapter is the approved bridge exception, not a modification to its native
model engine or a claim that every fitted native `phylo_rr` quantity matches
Julia.

## 8. What did not go smoothly

JuliaCall initially searched a missing/incompatible Intel Julia 1.6 through
`PATH`. Passing the ARM Julia 1.10 `bin` directory and starting with the
isolated GLLVM project fixed discovery and avoided the default-environment
extension conflict. The live test records these inputs through environment
variables rather than silently relying on local discovery.

## 9. Known limitations

These are three controlled Gaussian source forms through a private adapter.
The adapter does not yet expose a public fitted-object interface or supported
intervals; therefore this does not meet the separate S4 public-workflow or
interval-feasibility gate. It also does not establish recovery, coverage,
non-Gaussian phylogeny, ordinary `engine = "julia"` admission, 0.7 parity,
0.7.1 parity, FRK, release, or registry eligibility.

## 10. Review

Independent Astra review required the three source forms and corruption tests;
those gates are present. Its Julia consumer findings were repaired separately
in GLLVM.jl before the live handoff. The review then identified missing
provenance and fit-health fields in the first receipt; those are now enforced
by the runner and recorded above. A subsequent independent S4 receipt review
identified a shared P1: this runner proves that `pkgload` used the recorded
local shared-object bytes, but the ignored local `src/gllvmTMB.so` is not yet
checked against a predeclared frozen-source build manifest. Thus its native
values are frozen-source-aligned, not authenticated frozen-source binary
provenance; they cannot advance S3b/S4 qualification until that binding is
retained and machine-checked.

## 11. Evidence command

```sh
GLLVM_S3B_LIVE_ADAPTER_TESTS=1 \\
GLLVM_DESTINATION_B_PROJECT=/absolute/path/to/GLLVM.jl \\
GLLVM_S3B_JULIA_HOME=/absolute/path/to/julia/bin \\
Rscript --vanilla tests/testthat/run-destination-b-s3b-native-pairs-isolated.R
```

## 12. Next action

Perform a fresh independent review of this receipt and the two adapter/consumer
commits. Keep S4 as a separate public-workflow gate; do not reopen generic
engine admission from these private-pair results.
