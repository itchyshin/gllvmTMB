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
with an unobserved ancestor, and ill-conditioned dense covariance; it also
tests invalid tip map, determinant/tree corruption, and continued generic
public-route refusal. A mocked transport test checks the flat call contract.

## 6. Live runtime check

With `GLLVM_S3B_LIVE_ADAPTER_TESTS=1`, the same suite starts the ARM-native
Julia 1.10 runtime in the isolated GLLVM project with callbacks disabled and
executes the private adapter. Result: **34 expectations passed**.

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

The native-source fixtures validate transport and a minimal closed consumer
handoff. They do not yet provide an independently fitted-R-versus-Julia
optimizer comparison, public workflow/S4 evidence, profile intervals,
recovery, coverage, or a general `engine = "julia"` route.

## 10. Review

Independent Astra review required the three source forms and corruption tests;
those gates are present. Its Julia consumer findings were repaired separately
in GLLVM.jl before the live handoff.

## 11. Evidence command

```sh
GLLVM_S3B_LIVE_ADAPTER_TESTS=1 \\
GLLVM_DESTINATION_B_PROJECT=/absolute/path/to/GLLVM.jl \\
GLLVM_S3B_JULIA_HOME=/absolute/path/to/julia/bin \\
Rscript --vanilla -e 'devtools::test(filter = "julia-phylo-rr-bridge")'
```

## 12. Next action

Create a predeclared genuine native-fit paired fixture and compare the named
admitted quantities against the closed consumer before claiming S3b qualified;
then S4 may begin.
