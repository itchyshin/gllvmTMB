# Paper 2 coevolution estimand gate

Date: 2026-06-18 17:55 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Sources read

- Maintainer Paper 2 note:
  `/Users/z3437171/.codex/attachments/93d6ad50-4129-4147-938c-6b1dd92c7be9/pasted-text.txt`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/dev-log/audits/2026-06-18-coevolution-work-inventory.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Verdict

The local coevolution engine stop point is real, but the full Paper 2
coevolution model is not done.

The current checkout supports the fixed named multi-kernel latent-only path
needed to fit two dense kernel tiers and extract component-specific point
`Gamma` blocks. The validation ledger correctly keeps `KER-03` covered,
`COE-03` partial, and `COE-04` partial. That is package-engine evidence. It is
not the same as a finished biological estimand, a finished Paper 2 model, or
scientific coverage for the phylogenetic-versus-tip interpretation.

## Frozen working estimand

For Paper 2, the model should be presented as a biological framework for
network-mediated covariance across two interacting phylogenies, not as a
software extension. The central estimands are the host-partner cross-trait
covariance blocks:

- `Gamma_phy`: the cross-lineage trait covariance associated with
  phylogenetically structured interaction neighbourhoods.
- `Gamma_tip`: the cross-lineage trait covariance associated with tip-level or
  current network association beyond the conserved phylogenetic structure.

The key covariance statement is:

```text
Cov(eta_H,ia, eta_P,jb) =
  C_phy[i, j] * Gamma_phy[a, b] +
  C_tip[i, j] * Gamma_tip[a, b].
```

The full latent covariance is:

```text
Var(vec(eta - M)) =
  Sigma_phy %x% K_phy +
  Sigma_tip %x% K_tip,

Sigma_l = Lambda_l Lambda_l^T + Psi_l,
Gamma_l = Lambda_H,l Lambda_P,l^T.
```

Use `phylogenetically structured` and `tip-level` as the formal labels.
`Historical` and `contemporary` are interpretations, not exact timescale
estimates.

Raw loadings are not the main biological output because they are
rotation-dependent. The Paper 2 derived result should be based on standardized
cross-lineage correlation matrices:

```text
R_l = Sigma_H,l^(-1/2) Gamma_l Sigma_P,l^(-1/2).
```

An SVD of `R_l` gives coevolutionary modules: coupled host-trait and
partner-trait axes plus singular values that measure module strength. That
module layer is not implemented as a first-class extractor yet.

## Current implementation mapping

| Layer | Current state | Evidence |
| --- | --- | --- |
| One dense cross kernel | Covered | `make_cross_kernel()`, KER-01/COE-01/KER-02/COE-02 rows |
| Fixed named multi-kernel engine | Covered for latent-only point fits | `KER-03`, `test-coevolution-two-kernel.R` |
| Two-kernel point extraction | Partial | `extract_Gamma(level = ...)`, `predict_cross_covariance()` |
| Fixed-rho sensitivity | Partial | `profile_cross_rho()` grid; detects signal versus rho = 0 but does not estimate rho |
| Component recovery | Partial | near-orthogonal, selected moderate, high-overlap failure/collapse, null diagnostics, narrow Poisson cells |
| Intervals and uncertainty | Missing for Paper 2 claims | no `Gamma` interval coverage, no rho profile intervals |
| Kernel separability rule | Missing | no raw-W versus residualized-W decision rule |
| Coevolutionary module extractor | Missing | no standardized `R_l` + SVD API |
| Mechanistic biological validation | Missing | no interacting-lineage mechanism simulation tier yet |
| Empirical trait/data audit | Missing | DoPI and any other data system remain candidates only |

## Stage gates from the Paper 2 note

| Stage | Status | Required next evidence |
| --- | --- | --- |
| 1. Freeze estimand | Partial here | Promote a one-page conceptual estimand into Design 65 or a dedicated Paper 2 design note after maintainer review. |
| 2. Finalize kernels | Partial | Prove/record PSD construction, normalization, and whether `K_tip` uses raw `W` or residualized `W_tip = W - W_hat_phy`. |
| 3. Establish identifiability | Partial | Run kernel-collinearity simulations before the full simulation campaign; define when the model reports one network-conditioned covariance instead of split `Gamma_phy`/`Gamma_tip`. |
| 4. Mechanistic validation | Missing | Simulate regimes such as no cross-lineage process, persistent reciprocal adaptation, rapid turnover, assortative linking, and shared environmental filtering. |
| 5. Trait/data audit | Missing | Audit candidate empirical systems for enough species, traits, replication, interaction uncertainty, and phylogenetic coverage. |
| 6. Empirical analysis | Missing | Fit the predeclared model sequence after the data audit. |
| 7. Write from figures | Missing | Build the manuscript around decomposition, simulation regimes, empirical covariance heatmaps, and coevolutionary modules. |

## Next narrow coevolution gate

The next coevolution gate should not expand `kernel_unique()` or any
`*_unique()` syntax. Those remain compatibility syntax only.

The next useful Paper 2 gate is a kernel-separability design and test slice:

1. Define `K_phy` and two candidate `K_tip` choices: raw network `W` and a
   residualized network `W_tip`.
2. Add a small diagnostic helper or internal test fixture that reports
   vectorized-kernel similarity, eigen-spectrum overlap, and the existing
   fitted-object kernel diagnostic class.
3. Add a simulation gate that shows when `Gamma_phy` and `Gamma_tip` can be
   separated under empirically plausible kernel similarity.
4. Add the stop rule: if kernels are too similar, report one
   network-conditioned covariance rather than forcing the
   phylogenetically-structured versus tip-level interpretation.

Only after that gate should the work move to module extraction
(`R_l` plus SVD) or broader non-Gaussian/mixed-family simulations.

## Claims allowed now

- The package has a fixed named multi-kernel latent-only engine path for dense
  kernels.
- The current tests provide partial COE-04 evidence for point recovery and
  failure calibration across selected Gaussian and narrow Poisson fixtures.
- Fixed-rho profiles are sensitivity analyses, not rho estimation.
- Component-specific `Gamma` blocks are point estimates, not interval-supported
  scientific claims.

## Claims still forbidden

- Do not say the coevolution model is finished.
- Do not claim Paper 2 can separate historical and contemporary covariance in
  empirical networks without the kernel-separability gate.
- Do not claim in-engine rho estimation or rho intervals.
- Do not claim interval-calibrated `Gamma` inference.
- Do not claim mechanism, directionality, reciprocal adaptation, or ancestral
  interaction reconstruction from the current covariance model alone.
- Do not widen `kernel_unique()` / `*_unique()` into Paper 2 multi-kernel
  explicit-Psi support in this lane.
