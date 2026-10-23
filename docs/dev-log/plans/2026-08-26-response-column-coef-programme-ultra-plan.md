# Ultra Plan — response-column coefficient programme

```text
GOAL
Deliver a fitted, recovered, and documented response-column coefficient family
without changing or deprecating the released warning-free *_slope() APIs.

IN SCOPE
1. Merge and verify the inert Arc 1 foundation.
2. Admit an IID column_coef() engine by reusing the existing matrix-normal
   response-column slope likelihood.
3. Admit phylo_coef() with the locked raw-scale-preserving K_rho mixture,
   first for fixed rho and then for estimated rho.
4. Export only replacements that pass exact fit-equivalence, recovery,
   extractor, documentation, and three-OS gates.
5. Update where-does-the-tree-go.html only after the taught *_coef() call is
   runnable and validated.

OUT OF SCOPE
animal_coef(), kernel_coef(), spatial_coef(), broad non-Gaussian admission,
interval machinery, article repair before earned capability, and any
deprecation or warning for *_slope().

ACCEPTANCE
Each sequential slice has symbolic alignment, red-green TDD, focused package
checks, independent review, exact-head CI, a narrow PR, and durable closeout.
The final article renders from source and the live pkgdown deployment is checked.
```

## Prior-work sweep receipt

- Arc 1 merged through PR #1214 at `5a202fc8154a8e0c50c41ebb76932b0d805bdee8`.
- Exact reviewed head `1cefce04e6256392390e4e3dc3e9fec18d623bf1` passed routine Ubuntu run
  `32994788670` and manual macOS/Windows/Ubuntu run `32994709650`.
- Design 130 and the live `b_phy_aug` / `theta_dep_chol` matrix-normal route are
  the implementation base. IID needs routing and an optional intercept design,
  not a new TMB likelihood.
- `gllvm::colMat` is a conceptual comparator for source mixing only. GLLVM.jl
  grouped slopes use the wrong grouping axis; DRM.jl contributes only generic
  Cholesky-oracle patterns.
- Active LV and random-slope lanes are protected. The IID slice deliberately
  avoids the LV-owned `R/brms-sugar.R`, `docs/design/03-likelihoods.md`, and
  `docs/design/05-testing-strategy.md` paths.

## Sequential slices

### Slice A — IID engine

Route `column_coef()` after wide-to-long preprocessing into the established
response-column matrix-normal block with `K = I`. Preserve basis order as
`(Intercept)`, then named numeric predictors. A single bar frees the complete
Cholesky covariance; a double bar maps every strict-lower entry to zero.

Gates: red engine-fence tests; intercept, slope, and intercept+slope design
oracles; `|`/`||`; long/wide parity; exact no-intercept equivalence to `slope()`;
known-DGP Gaussian recovery; finite gradients; unchanged slope regressions.
This slice remains internal until its public extractor and documentation gate.

### Slice B — fixed-rho phylogenetic engine

Use `K_rho = rho K + (1-rho) diag(K)`. Precompute fixed mixtures in R. Route
`rho = 1` through the exact released tree/dense resolver so augmented nodes and
the protected dense ridge remain fit-identical to `phylo_slope()`.

Gates: exact equality at `rho = 1` for both bars, one and two predictors, tree
and dense VCV; IID equivalence at `rho = 0`; independent likelihood oracle,
label permutation, malformed source, and recovery at an interior fixed rho.

### Slice C — estimated rho

Add one logit-scale TMB parameter only after Slice B passes. Use the source
eigendecomposition so `d_j(rho) = 1 + rho(lambda_j - 1)` supplies the precision
and log determinant without repeatedly differentiating a dense inverse.

Gates: reject identity/uninformative sources, finite truth and optimum
gradients, fixed-versus-estimated objective agreement, interior recovery with
`P >= 2`, profile shape, honest boundary diagnostics, and retained failures.
Any campaign estimated above 30 minutes stops after a correctness pre-run for
explicit Totoro approval.

### Slice D — public API and article

Freeze `extract_Sigma(level = "column_coef")`, `screen_gllvmTMB()` behaviour,
exports, help, NEWS, pkgdown navigation, long/wide examples, and plain-language
scope. Then replace the article's released-slope teaching with the earned
`phylo_coef()` workflow and render/inspect the real HTML. Coefficient helpers
remain a separate family, never a fourth covariance mode.

### Slice E — closure

Run D-43 two-pass verification, Rose and Grace review, exact-head three-OS CI,
post-merge verification, Melissa plan-versus-actual, after-task, handover, and
lease release. The future animal/kernel/spatial programme starts as a new plan.

## Approval and pacing

Shinichi authorized steps 1–5 to proceed autonomously on 2026-08-26. Routine
reversible implementation, tests, commits, PRs, and prepared green merges are
pre-authorized. Stop only for a genuine ownership refusal, protection bypass,
release action, or a compute run estimated above 30 minutes.
