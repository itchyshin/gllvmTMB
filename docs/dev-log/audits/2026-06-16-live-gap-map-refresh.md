# Live Gap Map Refresh: Twin Finish Programme

**Date**: 2026-06-16 17:18 MDT
**Branch**: `codex/r-bridge-grouped-dispersion`
**Scope**: read-only issue / PR / CI / lane refresh plus local coordination
state update.
**Roles**: Ada, Shannon, Rose, Grace, Hopper, Karpinski, Fisher, Curie,
Boole, Emmy, Pat, Darwin, Florence, Jason.

## 1. Live State

This card refreshes the operating map after the MultiTraits scout commit
`49b5474` and before the next implementation push.

| Surface | Current evidence | Interpretation |
| --- | --- | --- |
| `gllvmTMB` branch | `codex/r-bridge-grouped-dispersion`, clean, tracking origin | Active R bridge evidence branch. |
| `gllvmTMB` PR | Draft PR `#489`, base `main`, head `codex/r-bridge-grouped-dispersion` | Bridge admission PR is live, still draft. |
| `gllvmTMB` PR checks | `coevolution-two-kernel-recovery` and `R-CMD-check / ubuntu-latest (release)` passed on `49b5474` | The docs-only MultiTraits follow-up is green; this gap-map commit will start a fresh PR check cycle when pushed. |
| Main scheduled checks | Latest `full-check` on `main` is green; latest scheduled power-pilot sweep is in progress | Package-health and simulation-sweep status remain separate. |
| `GLLVM.jl-integration` branch | `codex/julia-per-trait-dispersion`, clean, latest `f7be594` | Paired Julia bridge runtime branch. |
| `GLLVM.jl` PR | Draft PR `#101`, base `integration`, merge state clean, Documenter green | Stacked Julia PR remains draft until landing decision. |
| Local widget | Existing Chrome tabs refreshed to `http://127.0.0.1:8770/?v=ci-pending-49b5474-20260616-1703` during the run | After this commit is pushed, refresh the widget again to the new commit and fresh-check state. |

Shannon verdict: `WARN`, not `FAIL`. The tree is clean and there is one open
`gllvmTMB` PR. CI pacing was satisfied by waiting for PR #489's active
R-CMD-check run to pass before pushing this follow-up commit.

## 2. Current Bridge Capability Boundary

`gllvmTMB` PR #489 has moved the Julia bridge beyond a pure governance PR, but
it is still not a release claim. The safe boundary is:

| Lane | IN on PR #489 | Still gated |
| --- | --- | --- |
| Nuisance parameters | R decodes grouped Julia dispersion for NB2, NB1, Beta, and current shared-Gamma parity; R decodes trait-labelled ordinal cutpoints | Native per-trait Gamma expansion remains a later spec / implementation lane. |
| Point fits | No-X Gaussian, Poisson, Bernoulli binomial, NB2, NB1, Beta, Gamma; selected complete-response fixed-effect-X rows; complete balanced no-X/no-mask/no-CI mixed-family point rows | NB1-X, ordinal-X, mixed-family-X, non-canonical X designs. |
| Masks | One-part no-X response masks for supported non-Gaussian rows | Gaussian masks, mixed-family masks, masks combined with fixed-effect X. |
| CIs / status | No-X Wald/profile/bootstrap payloads; complete-response fixed-effect-X CIs for Gaussian, Poisson, Bernoulli, NB2, Beta, Gamma; masked no-X CIs for admitted non-Gaussian rows | Per-trait ordinal CIs, NB1-X CIs, ordinal-X CIs, mixed-family CIs, non-Gaussian REML CIs. |
| Post-fit methods | `coef()`, `summary()`, scoped `confint()`, retained-payload `predict()`, `fitted()`, response/Pearson `residuals()`, conditional in-sample `simulate()`, raw unit-tier covariance / ordination accessors | `newdata`, unconditional redraws, ordinal residuals/simulation, link-residual augmentation, rotations, structured-tier extractors, richer extractor parity. |
| Public wording | `engine = "julia"` means the default `GLLVM.jl` fitting path | No user-facing `engine_control` claim yet; no algorithm-choice claims. |

Rose boundary: do not say "full bridge", "complete parity", "CRAN ready", or
"speed claim" from this PR. A row is promoted only where tests, validation
register rows, CI/status behavior, docs, and issue comments agree.

## 3. Issue-to-Lane Map

### `gllvmTMB`

| Issue | Live status | Owner lens | Next evidence needed |
| --- | --- | --- | --- |
| `#488` bridge gate drift | Open, commented for PR #489 before the docs-only follow-up push | Hopper / Rose / Shannon | Re-check after the gap-map commit starts a fresh PR run; comment only if the boundary changes. |
| `#483`, `#485`, `#486` bridge release hygiene | Open, commented for PR #489 | Grace / Rose / Emmy | Keep draft until branch, generated docs, checks, and CRAN timing agree. |
| `#340` capability matrix | Open, commented for PR #489 | Rose / Ada | Ensure every admitted bridge row has validation-register status and every gate remains visible. |
| `#344`, `#345` release gates | Open | Grace / Ada / Rose | No release action until PR #489, pkgdown, issue ledger, and validation rows agree. |
| `#346`, `#349` simulation / power | Open | Curie / Fisher / Grace | ADEMP schemas, MCSE, usable-fit denominators, runtime metadata, and failure taxonomy. |
| `#347`, `#230` public learning path | Open | Pat / Darwin / Florence / Jason | Convert the MultiTraits scout into model-based examples only after bridge state settles. |
| `#361` kernel / coevolution | Open | Karpinski / Noether / Fisher | Dense `kernel_*()` equals dense `phylo_*()` to `<1e-6` before C2+ claims. |
| `#332`-`#338` missing data | Open | Fisher / Curie / Emmy | Keep response masks, predictor `mi()`, and bridge masks separate in wording and tests. |

### `GLLVM.jl`

| Issue | Live status | Owner lens | Next evidence needed |
| --- | --- | --- | --- |
| `#10` R bridge umbrella | Open, commented for PR #101 | Hopper / Karpinski | Split remaining bridge work into narrow successors after PR #101 landing decision. |
| `#98` per-response family dispatch | Open, commented for PR #101 | Karpinski / Boole | Keep mixed-family support limited to rows tested by the R bridge and Julia capability ledger. |
| `#91`, `#96` Laplace robustness | Open, commented for PR #101 | Gauss / Karpinski / Fisher | Mode-finder and high-rate Poisson robustness remain separate from bridge admission rows. |
| `#92` phylo-signal CI | Open | Noether / Fisher / Hopper | Bridge exposure waits for structured Julia fits, not just derived-CI fixes. |
| `#65` gradients / speed | Open | Karpinski / Grace | No speed claim without parity, inference/status, runtime metadata, and failure taxonomy. |
| `#61`, `#62` sparse phylo / spatial | Open | Karpinski / Noether | Structured substrate before public structured bridge rows. |
| `#27` missing data | Open | Fisher / Curie | Align FIML/mask semantics with `gllvmTMB` missing-data lanes. |

## 4. Next Slices

1. **Settle the fresh PR #489 checks after this commit.** If R-CMD-check passes
   again, refresh the widget to green at the new commit. If it fails, inspect
   logs before any new lane.
2. **Richer extractor parity scout.** Define the exact native-vs-Julia parity
   targets for `extract_Sigma()`, `extract_correlations()`,
   `extract_ordination()`, `getLoadings()`, `getLV()`,
   `getResidualCov()`, and `getResidualCor()`. Do not widen public claims
   until shape, labels, scales, and status columns match.
3. **Ordinal CI endpoint spec.** Write the admissible endpoint contract for
   per-trait ordinal cutpoints and ordinal probability summaries before
   implementing CIs. Keep ordinal-X and ordinal residuals separate.
4. **NB1 / ordinal fixed-effect-X design.** Decide whether the R gate is blocked
   by engine support, bridge payload shape, or statistical design; then add
   representative fail-loud or parity tests.
5. **Public-learning visualization lane.** Use the MultiTraits card only as a
   teaching-pattern reference. Any visual must be computed from model-estimated
   `Sigma`, `Lambda`, `psi`, fitted values, residuals, and CI/status payloads.

## 5. Cross-Twin Consistency Checks

Keep these meanings aligned across `gllvmTMB`, `GLLVM.jl`, `drmTMB`, and
`DRM.jl`:

- `engine = "julia"` means the default Julia twin fitting path, not a
  user-selectable algorithm menu.
- `engine_control` is future control-surface wording only.
- REML / AI-REML language stays Gaussian-only unless a future derivation and
  validation proves otherwise.
- `pdHess = FALSE` is an inference / identifiability warning, not automatic
  point-fit failure.
- Response masks, structural-zero fixed-effect coefficient masks, and
  observation-by-response covariates are different concepts and should not
  share argument names casually.
- MultiTraits is a visualization and teaching-pattern source, not a likelihood
  comparator for `gllvmTMB` or `GLLVM.jl`.

## 6. Explicit Non-Actions

- No issue was closed.
- No new public capability was advertised.
- No R code, Julia code, likelihood, formula grammar, NAMESPACE, generated Rd,
  vignette, README, pkgdown navigation, or validation-register row was changed
  by this audit card.
- The active PR #489 R-CMD-check run completed green on `49b5474` before this
  follow-up commit was pushed.
