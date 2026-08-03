# Ultra Plan — issue #921 standardized-loading inference

```text
GOAL
Fix gllvmTMB's standardized-loading inference so every public route uses
rho[t,k] = lambda[t,k] / sqrt(Sigma_total[t,t]), propagates the full joint
fixed-parameter covariance, labels the returned loading scale, and preserves
the existing raw Wald contract. Validate the deterministic algebra and public
routing without making a coverage claim, then prepare (but do not post) the
reply to Ayumi.
```

## Phase 0 sweep receipt

- Base: fresh `origin/main` at `dbd0b2d5` in branch
  `codex/fix-loading-scale-inference`.
- The original checkout is 689 commits behind `origin/main` and has five
  unrelated uncommitted paths; it is not used for this implementation.
- Open PR #922 touches only a handover file. Open PR #917 overlaps only
  `NEWS.md`; a coordination note was posted and `NEWS.md` remains fenced until
  that PR lands.
- Repository search found the correct standardized point-estimate contract in
  `R/rotate-loadings.R`, and the inconsistent entrywise transforms in
  `R/loading-uncertainty-helpers.R` and `R/suggest-lambda-constraint.R`.
- The Shinichi brain and `GLLVM.jl` twin contained no prior implementation of
  this exact repair. Durable prior guidance agrees that Ayumi's analytic and
  bootstrap tables must use the same scale and that loading inference remains
  rotation-frame dependent.
- No external literature search is needed: this is a deterministic
  package-contract repair, not a novelty or empirical-evidence claim.

## Symbolic alignment contract

| Meaning | Symbol / R surface | Implementation target | Verification |
|---|---|---|---|
| Raw loading | $\lambda_{tk}$ / `loading_scale = "raw"` | `report$Lambda_<level>` | Existing raw Wald tests remain byte-for-byte equivalent apart from the new scale column |
| Total trait variance | $V_t = \Sigma_{\mathrm{total},tt}$ | `extract_Sigma(..., part = "total", link_residual = "auto")` evaluated at each fixed-parameter perturbation | Point estimates match `extract_rotated_loadings_table(..., loading_scale = "standardized")` |
| Standardized loading | $\rho_{tk}=\lambda_{tk}/\sqrt{V_t}$ | One canonical report-aware delta helper | `d=1`, `d=2`, cross-axis covariance, fitted-denominator, zero, and invalid-variance tests |
| Joint uncertainty | $J_\rho\,\operatorname{Cov}(\hat\theta)J_\rho^\top$ | Numerical Jacobian against `sd_report$cov.fixed` | A non-diagonal covariance fixture differs from marginal-SE rescaling |
| Bounded interval | $z_{tk}=\operatorname{atanh}(\rho_{tk})$ | `wald_asym` on standardized scale only | Bounds stay in `[-1,1]`; no raw/standardized silent mixing |
| Salience decision | $P(|\rho_{tk}|>c)$ | `wald_retention` and `varimax_threshold` consume canonical standardized values | Deterministic routing fixtures |

For a raw loading pinned by `lambda_constraint`, `pinned = TRUE` remains
provenance. Its standardized derivative need not be zero because $V_t$ can
vary through other axes, $\Psi_t$, or a parameter-dependent link residual.
Only raw pinned intervals are forced to collapse; reliability calls remain
`NA` for all pinned rows.

## Bounded work plan

| Slice | Owner / review lens | Files | Verification |
|---|---|---|---|
| Canonical delta helper | Codex; Noether mathematical review completed | `R/loading-uncertainty-helpers.R` | Pure algebra plus report-aware integration tests |
| Public CI and decision routes | Codex | `R/loading-ci.R`, `R/suggest-lambda-constraint.R`, `R/plot-loadings-confidence-eye.R`, `R/z-confint-gllvmTMB.R` | Focused testthat files |
| Regression matrix | Codex; Curie test-plan review completed | loading, constraint, plot, and confint tests | Fast tests first, then heavy focused tests |
| Contract/docs | Codex; Rose-style neighbour sweep | roxygen/Rd, extractor contract, validation register, check log, after-task report | `devtools::document()`, stale-term scans, pkgdown/check gates proportional to changed surface |

Scope is deterministic algebra, API labels, routing, tests, and documentation.
There is no TMB likelihood change and no empirical coverage promotion. A
coverage campaign, if later desired, belongs on Totoro or DRAC as a separate
lane.
