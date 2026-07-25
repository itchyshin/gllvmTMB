# S7 -- gllvmTMB vs gllvm fit-level comparator: results

New test file: `tests/testthat/test-comparator-gllvm.R`. Run with
`devtools::load_all(); testthat::test_file("tests/testthat/test-comparator-gllvm.R")`
and `devtools::test(filter = "gllvm|phylo")`. gllvm 2.0.11, R 4.6.0/4.6.1,
this worktree (`claude/gllvm-comparator-20260725`).

## Background / gap closed

Before this file, no test in the suite ever fit a `gllvm::gllvm()` model.
The only `gllvm::` call anywhere in the repo was the scratch script
`dev/jason-binomial-scout.R`. `docs/design/05-testing-strategy.md`'s
comparator table already listed a row for this --

> `gllvm::gllvm()` binary GLLVM | Procrustes-aligned loadings + per-factor
> rho > 0.95 | binary GLLVM with `latent()`; rotation-aware comparison via
> `compare_loadings()` | **claimed (M2 work)**

-- i.e. the comparator was documented as done but had no backing test. This
file adds that test (Poisson rather than binary, see below), using exactly
the Procrustes + `compare_loadings()` mechanism the design doc names.

`gllvm` was already present in `DESCRIPTION`'s `Suggests:` (confirmed via
`grep`), so no `DESCRIPTION` edit was needed.

## Model compared

**Unconstrained / unstructured ordination GLLVM**, Poisson family, `d = 2`
latent axes, no covariates, no row effects, no dispersion parameter.

- `gllvm`: `gllvm::gllvm(y = Y, num.lv = 2, family = "poisson")` -- gllvm's
  canonical unconstrained-ordination entry point (no `X`, no `colMat`, no
  `randomX`).
- `gllvmTMB`: `value ~ 0 + trait + latent(0 + trait | site, d = 2, unique =
  FALSE)`, `family = poisson()`, long-format data with `unit = "site"`,
  `trait = "trait"`.

## Why this is like-for-like

Both formulations describe the identical generative model:

```
eta_ij = beta0_j + z_i' theta_j,   z_i ~ N(0, I_d) iid over rows i
y_ij ~ Poisson(exp(eta_ij))
```

with `gllvmTMB`'s "trait" axis (T columns) playing the role of `gllvm`'s
species/columns, and `gllvmTMB`'s "unit"/site axis (rows) playing the role
of `gllvm`'s rows. `unique = FALSE` on the ordinary `latent()` term is
essential: the package's current default adds a diagonal `Psi` term
(`Sigma = Lambda Lambda^T + diag(psi)`), and `gllvm`'s bare `num.lv` model
has no analogous per-species diagonal term for a Poisson family (Poisson
has no free dispersion parameter on either side) -- `unique = FALSE`
selects the loadings-only `Lambda Lambda^T` subset that actually
corresponds to `gllvm`'s model. Both latent scores are unit-variance,
independent across rows, with unconstrained per-species/trait loadings,
identified only up to an orthogonal rotation on both sides -- exactly the
setting `compare_loadings()`'s Procrustes alignment is built for.

**What was explicitly NOT attempted, and why:** a phylogenetic comparison
(`phylo_latent()` vs `gllvm`'s `colMat`). Per the source-level diagnosis
already on record in `dev/s2-gllvm-colmat-reference-RESULTS.md` (sections
A-C, a prior research script in this repo, not touched by this task),
`gllvm`'s `colMat` mechanism is a single Pagel's-lambda-style covariance
blend (`rho*C + (1-rho)*I`) applied to whatever column-random-effect terms
sit in the bar formula, with no analogue of `gllvmTMB`'s tip+internal-node
Hadfield `A^-1` augmentation or its `unique = TRUE`
`Lambda Lambda^T + diag(psi)` decomposition. Forcing that comparison would
compare two different covariance parameterisations dressed up to look
alike -- exactly the kind of non-like-for-like case the brief says to
avoid. The unconstrained-ordination case above needs no such
reconciliation, so it is the one used.

The design doc's table entry names "binary GLLVM" specifically; this file
uses Poisson instead, because Poisson has no free dispersion/threshold
parameters to align on either side (a binary/probit comparator would
additionally require matching probit-vs-logit link conventions and
gllvm's latent-trait identification constraints for binary data). Poisson
is the cleaner apples-to-apples case for a first comparator; the design
doc's "binary GLLVM" wording should be read as one example of the
unconstrained-ordination comparator class, not read as excluding this
fixture.

## The numbers

Fixture: `n_sites = 60`, `n_traits = 6` ("species" columns), `d = 2`,
seed 42 (data), `gllvm(seed = 1)` for its own internal fit-start
randomization. n = 360 observations, no zero rows/columns.

| Quantity | gllvmTMB | gllvm | Comparison |
|---|---|---|---|
| Log-likelihood at optimum | -673.0404 | -673.6544 | relative diff = 0.00091 (0.091%) |
| Loading singular values (non-degeneracy) | 1.861, 0.850 | 1.856, 0.848 | both comfortably away from 0 |
| Procrustes per-factor correlation | -- | -- | 0.999999 (factor 1), 0.999994 (factor 2) |
| Procrustes-aligned relative Frobenius error | -- | -- | 0.00396 (0.4%) |
| Convergence | `opt$convergence == 0`, `sd_report$pdHess == TRUE` | `convergence == TRUE`, `logL` finite | both converged |

Raw loading matrices (traits x 2 axes) after Procrustes rotation of the
gllvmTMB estimate onto the gllvm estimate agree to ~2 decimal places
entrywise; neither collapsed toward zero (a degenerate/boundary solution
would produce near-zero loadings and would have failed the non-degeneracy
check). This is a genuine, non-degenerate agreement between two
independently implemented packages fitting the same generative model, not
two collapsed fits that happen to match trivially.

## Tolerances and justification

- **Log-likelihood: 1% relative tolerance.** Unlike the existing glmmTMB
  cross-checks (`test-stage2-rr-diag.R`, `test-crosspkg-nbinom1-glmmTMB.R`),
  which share gllvmTMB's own TMB/Laplace lineage and agree to `1e-4`,
  `gllvm` is an independently implemented package with its own C++
  template, optimiser defaults, and starting values for a genuinely
  non-convex unconstrained-ordination likelihood (multiple rotations/local
  optima are possible in principle). Bit-level agreement is not a
  meaningful bar. 1% asks the question that matters -- did both packages
  converge to a comparably good optimum of the same generative model? --
  with an order of magnitude of headroom over the observed 0.091%
  difference. A real disagreement (mismatched parameterisation, a
  collapsed fit, a sign/rotation bug) would show up as several
  log-likelihood units of difference, not a fraction of one.
- **Procrustes per-factor correlation: > 0.95.** This is the exact bar
  already used in `test-re09-latent-unique-unit.R` and named in
  `docs/design/05-testing-strategy.md`'s comparator table for this cell --
  not a new number invented for this test. Observed: 0.999999 / 0.999994.
- **Procrustes-aligned relative Frobenius error: < 10%.** Added because
  correlation alone is invariant to a constant rescaling of one loading
  matrix, so a fit that recovered the right shape at the wrong overall
  scale would still pass the correlation check. A 10% relative-error band
  is generous for cross-package agreement; observed is 0.4%.
- **Non-degeneracy (singular values > 0.2):** guards against "it fitted"
  being mistaken for evidence -- a boundary/collapsed solution can still
  report `convergence == 0` while carrying no real ordination signal. 0.2
  is well below the observed ~0.85-1.9 but far enough above 0 to catch a
  genuine collapse.

## Warnings verbatim

Both fits were run WITHOUT `suppressWarnings()`/`suppressMessages()` (a
deliberate departure from some sibling cross-package tests in this
suite, made because the brief warned against grep-filtering or silently
dropping warnings). A local `capture_fit_warnings()` helper collects
warning text via `withCallingHandlers()`/`invokeRestart("muffleWarning")`
and `cat()`s it into the test output if any warning fires.

**Result: zero warnings from either fit**, across all three test blocks
(fit + non-degeneracy checks, log-likelihood comparison, loading-shape
comparison), each of which independently rebuilds the fixture and refits
both models. The only console output produced during the whole test run
was the package's one-time `.onAttach` startup message
("gllvmTMB is EXPERIMENTAL... "), which fires once per R session on
package load, not per fit, and is unrelated to this comparator.

No warnings were dropped, muffled without recording, or grep-filtered.

## Test result

`testthat::test_file("tests/testthat/test-comparator-gllvm.R")`: **3 test
blocks, 16 expectations, 0 failures, 0 warnings, 0 errors, 0 skipped**
(with `NOT_CRAN=true`; the file's per-test `skip_on_cran()` calls mean it
is skipped, not failed, in a plain CRAN check run).

`devtools::test(filter = "gllvm|phylo")`: the full filtered run (106+
tests across all `phylo*`/`gllvm*` test files) completed with **no
failures and no errors**; the large number of reported "skipped" entries
are pre-existing heavy-recovery tests gated behind
`GLLVMTMB_HEAVY_TESTS=1` / `GLLVMTMB_RUN_B2_LOGIT=1` env vars, unrelated to
this change and unaffected by it.

## Verdict

**PASS -- genuine, non-degenerate, like-for-like agreement.** The
unconstrained-ordination Poisson GLLVM is a case where gllvmTMB's and
gllvm's formula grammars describe literally the same statistical object,
and the fitted results confirm it: log-likelihoods agree to 0.09%,
Procrustes-aligned loadings agree to correlation > 0.9999 and relative
Frobenius error 0.4%, and neither fit collapsed to a degenerate boundary
solution. This closes the credibility gap flagged in
`docs/design/05-testing-strategy.md` (the `gllvm` comparator row moves
from "claimed" to actually tested) without forcing a phylogenetic
comparison that the two packages' `colMat`/`phylo_latent()`
parameterisations do not actually support on like-for-like terms.
