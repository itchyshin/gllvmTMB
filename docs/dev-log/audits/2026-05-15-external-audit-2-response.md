# External audit response (audit #2) -- 2026-05-15

The maintainer shared a second external audit of gllvmTMB on
2026-05-15 evening, titled *"Architectural Review and Strategic
Evaluation of the drmTMB and gllvmTMB Statistical Computing
Frameworks"*. This document records the triage and the resulting
action items.

The audit's full text lives in this repository's conversation
log (2026-05-15). The headlines and triage below distil it into
actionable items.

## Important framing: this audit didn't read the code

The audit states explicitly in its opening section:

> "the explicit source code repositories, underlying .R scripts,
> and DESCRIPTION metadata files for both drmTMB and gllvmTMB
> remain in restricted, private, or temporarily inaccessible
> development states on GitHub."

Consequently, the audit's "strategic recommendations" are
back-inferred from the lab's published track record (the
glmmTMB meta-analysis paper, the `phylo_location_scale` tutorial,
`pigauto`, the `Meta-analysis_tutorial` repo, the fast-phylo-GLMM
bioRxiv) plus general TMB / GLLVM theory -- not from the package
as built. This contrasts with the **first external audit** (filed
in `2026-05-15-external-audit-response.md`) which clearly had
read `R/fit-multi.R:1700-1702` and surfaced the multi-start
`obj$report()` bug specifically. That audit was *substance*; this
audit is closer to a *literature-position synthesis*.

The triage below reflects this. The audit raises real concerns,
but ~9 of its headline recommendations describe things already
in main.

## Already shipped (audit recommends what we already do)

| Audit prescription | Already in main | Reference |
|---|---|---|
| "Hard-code upper-triangular zero constraints + positive diagonals on loading matrices" | Inherited from `glmmTMB::rr()` reparameterisation since 0.2.0 | McGillycuddy et al. 2025 (JSS 112(1)); `R/fit-multi.R` |
| "Treat known variance matrices as fixed (`equalto` paradigm)" | `meta_known_V(value, V = V)` + `block_V()` helper. `phylo_scalar()` maps to `propto`. | `R/meta-known-v.R`, `R/block-v.R`, `R/phylo-keywords.R` |
| "Build CV / model selection for `d` (number of latent factors)" | `check_identifiability(fit, sim_reps = 100L)` -- Procrustes-aligned simulate-refit + Hessian eigenvalue rank check. Catches spurious extra factors directly. | PR #105 |
| "Bias-correction / coverage module for variance components" | `coverage_study(fit, ...)` -- empirical CI coverage with audit-1's `>= 94%` exit gate | PR #122 |
| "Diagnose Hessian / Laplace breakdown" | `gllvmTMB_check_consistency(fit, n_sim, estimate)` wraps `TMB::checkConsistency()`; `sanity_multi(fit)` does structural checks | PR #121, PR #104 |
| "Visual interpretation aids akin to `orchard_plot`" | `confint_inspect(fit, parm)` -- profile-curve visualisation with quadratic / asymmetric / flat / boundary diagnostic flags | PR #120 |
| "Robust multi-start / deterministic starting values" | Multi-start (`n_init`) + the P0 audit fix from earlier today (`obj$fn(opt$par)` + `last.par.best` state-pinch) closed the `obj$report()` / `fit$opt$par` consistency bug | PR #122 (P0 fix bundled), `R/fit-multi.R:1700-1702` |
| "Pedagogical GitHub Pages walk-throughs" | 13 Phase 1c articles in main once #126-#129 land. Concepts tier ships `gllvm-vocabulary`, `data-shape-flowchart`, `troubleshooting-profile`, `simulation-verification`. Methods+validation tier ships `profile-likelihood-ci`, `cross-package-validation`, `simulation-recovery` | `vignettes/articles/`, `_pkgdown.yml` |
| "Continuous integration across R versions" | 3-OS R-CMD-check on every push + PR. ~24 PRs through that gate today | `.github/workflows/R-CMD-check.yaml` |

Net: of the audit's ~10 "strategic recommendations" the surface
of the package already addresses 9. The fact that an outside
reader who **only sees the published outputs of the lab** ends
up predicting roughly the right feature set is a positive
signal that our roadmap tracks the right concerns. It is not
news.

## Genuinely new and useful (2 items)

### A1. Adaptive Gauss-Hermite quadrature for sparse Bernoulli (post-CRAN)

The audit's argument is correct: the Laplace approximation's
Gaussian assumption can degrade on highly sparse binary
matrices where each observation carries very little information
about the latent variable's posterior. Our current path is
Laplace-only.

We currently handle this by **diagnosis**: `gllvmTMB_check_consistency()`
(PR #121) tests whether the marginal score is centred at zero
on simulated replicates. A non-centred score is exactly the
signal that the Laplace approximation is unreliable for the
fit. The diagnostic flags this; it doesn't switch methods.

The audit's prescription (offer adaptive Gauss-Hermite as an
alternative integrator for binary fits) is a defensible **post-
CRAN extension**. Adding a method-switch path to the engine
would be a substantial change to `src/gllvmTMB.cpp` and is
not scoped to Phase 1 or Phase 5.

**Action**: queued as a **Phase 6 / 0.3.0 candidate** in
`docs/dev-log/decisions.md`. Not blocking CRAN. The Phase 1b
validation `check_consistency()` diagnostic plus the
`troubleshooting-profile.Rmd` article cover the present-day
user need (know when to distrust the fit).

### A2. Measurement-error vs biological-variance conflation callout

The audit raises this as a critical caution for drmTMB but the
underlying concern applies equally to gllvmTMB: an inflated
$\boldsymbol{\Psi}$ diagonal is not automatically biological
heterogeneity -- it can be unmodelled measurement error, design
imbalance, or systematically-varying instrument precision.

`meta_known_V()` is precisely the path that lets a user
*separate* known sampling variance from estimated trait
variance, but the current pedagogy doesn't explicitly say "use
this to protect against the conflation."

**Action**: single-paragraph addition to `pitfalls.Rmd` (or
the Caveats section of `simulation-recovery.Rmd`) during the
**Phase 1e Rose + Darwin reframe sweep**:

> *"An inflated $\boldsymbol{\Psi}$ diagonal is not automatically
> biological heterogeneity -- it can be unmodelled measurement
> error. If you have known per-observation sampling variances
> (e.g. trait-aggregation pipelines like AVONET; meta-analytic
> effect-size SEs), supply them via `meta_known_V(value, V = V)`
> so the model can attribute that variance to the known-error
> path rather than absorbing it into $\boldsymbol{\Psi}$."*

Not blocking CRAN. Bundled into Phase 1e.

## Hallucinated / confused (caveats for the record)

- **"Williams, Nakagawa, and colleagues" introducing
  `equalto`** -- the JSS paper that introduced `rr()` and
  `equalto` in `glmmTMB` is **McGillycuddy, Popovic, Bolker,
  Warton 2025** (J. Stat. Softw. 112(1)). The audit conflated
  the McGillycuddy paper with the Williams meta-analysis paper.
- **`pigauto` cross-pollination as a major opportunity** --
  speculative. `pigauto` exists (Nakagawa lab) but the audit's
  proposal to pipe `pigauto`-imputed trait data + uncertainty
  matrices through `meta_known_V()` is a long-horizon Phase 6
  idea, not a near-term action.
- **"drmTMB and gllvmTMB are coordinated outputs of one
  pipeline"** -- the audit blurs the two packages. Per
  `CLAUDE.md`: drmTMB is univariate / bivariate distributional
  regression; gllvmTMB is multivariate stacked-trait GLLVMs.
  They share an author and a substrate, but they have
  deliberately separate scopes. The audit's `equalto`
  paragraph is reasonable for both; its specific
  drmTMB-as-location-scale paragraphs aren't gllvmTMB's lane.
- **Reference [1]** is described as "Williams-McGillycuddy" --
  the actual semantic-scholar / arXiv-2604.04084 paper is the
  McGillycuddy et al. paper. Minor citation confusion.

## Comparison with audit #1

| Dimension | Audit #1 (morning) | Audit #2 (evening) |
|---|---|---|
| Code access | Yes; cited `R/fit-multi.R:1700-1702` | No; explicitly inferred from public outputs |
| Concrete bug? | Yes: P0 multi-start `obj$report()` consistency | No |
| New action items | 4+ (P0 + P1a/b/c sub-PRs) | 2 (Gauss-Hermite post-CRAN; pitfalls callout) |
| New information density | High | Low |
| Mechanism | Substance: read the code | Synthesis: pattern-match from track record |

Audit #1 produced a CRAN-blocking fix that landed today (PR
#122). Audit #2 produces two queued items, neither blocking.

## Action items (queued)

| # | Item | Phase | PR target |
|---|---|---|---|
| A1 | Adaptive Gauss-Hermite quadrature for sparse Bernoulli | Phase 6 / 0.3.0 | Post-CRAN |
| A2 | "Measurement error vs biological heterogeneity" callout in `pitfalls.Rmd` (or `simulation-recovery.Rmd` Caveats) | Phase 1e | Phase 1e Rose+Darwin reframe sweep PR |

Both items also logged in `docs/dev-log/decisions.md` so they
don't dissolve into chat.

## Going-forward discipline

This file plus `2026-05-15-external-audit-response.md` together
form the canonical record of how external audits are triaged.
When the next audit arrives, the same procedure applies:

1. Read it once. Tag each finding {already-shipped, new-action,
   hallucinated/confused}.
2. For "already-shipped": link to the PR or commit that
   addressed it.
3. For "new-action": queue with a phase + PR target.
4. For "hallucinated/confused": record so the same false claim
   doesn't get re-introduced by a later inferred-from-track-
   record audit.
5. File the triage as `docs/dev-log/audits/YYYY-MM-DD-external-audit-N-response.md`.
6. After-task report bundled in the same commit.

Audit content that is **synthesised from public outputs** but
not from reading the source has a predictable pattern: it
prescribes what already exists, raises real-but-textbook
concerns, and occasionally proposes speculative integrations.
That's not useless -- it's a positive signal that the published
record aligns with the actual package state. But it should be
weighed appropriately against audits that *did* read the code.
