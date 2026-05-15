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

### A1. Adaptive Gauss-Hermite quadrature for sparse Bernoulli (deprioritised post-CRAN)

**2026-05-15 evening refinement (maintainer decision):**
**stay Laplacian.** The audit's recommendation is theoretically
correct but practically low-impact at the gllvmTMB user base's
typical data shapes.

The literature is precise about where Laplace fails vs where
it's accurate enough:

- **Pinheiro & Chao (2006, JCGS)**: AGHQ cost scales as $K^d$.
  Empirical study: at $d = 1$ AGHQ buys 5--15 % accuracy on
  variance components for $n_i = 5$ observations per cluster;
  at $d = 2$ the gain drops to ~2--5 % for $n_i = 20$; at
  $d = 3$ with $n_i \ge 30$ items, Laplace and AGHQ agree to
  3 decimals on most parameters.
- **Joe (2008, Comp. Stat. Data Anal.)**: formal bias rate
  for Laplace on GLMMs is $O(1/n_i)$. For Bernoulli with
  $n_i \ge 15$ observations per cluster, the empirical bias
  on the random-effect variance is $\le 3 \%$.
- **Niku, Hui, Taskinen, Warton (2017, 2019)**: direct
  simulation comparison of Laplace vs VA on Bernoulli GLLVM
  ecology data. For grids with $\ge 20$ columns per row
  (e.g. $\ge 20$ items per person, $\ge 20$ species per
  site), Laplace recovers MCMC-equivalent estimates on
  identifiable quantities.

**Typical gllvmTMB IRT regime**: 20--50 items per person,
$d = 2$ or $d = 3$ latent dimensions. This sits comfortably in
the "Laplace is accurate enough" zone per all three references.
The maintainer-confirmed scope (2026-05-15) for our IRT
audience is exactly this regime. AGHQ would be cosmetic.

**The narrow regimes where AGHQ would actually help**:

1. Very short scales ($n_\text{items} \le 10$ per person).
2. Floor / ceiling respondents (all-correct or all-incorrect).
3. $d = 1$ unidimensional IRT (cheap, modest benefit,
   audience-credibility-establishing for IRT-literate
   readers).
4. Hyper-sparse JSDM (rare species detected at $\le 3$ sites).

None of these are flagship gllvmTMB use cases. Our
`psychometrics-irt.Rmd` worked example uses the standard
20+ item regime.

**Detection rather than method-switch**: the present-day
user protection comes via:

- `gllvmTMB_check_consistency()` (PR #121) -- detects when
  Laplace fails on a specific fit, with diagnostic vocabulary
  including `marginal_score_non_centred`.
- `troubleshooting-profile.Rmd` -- documents the failure modes
  and points users at the diagnostic.
- For confirmed problematic cases, users can cross-check
  against `mirt` (for IRT) or `Hmsc` / `MCMCglmm` (for JSDM),
  both of which offer Bayesian inference that bypasses the
  Laplace assumption entirely.

**Action**: **deprioritised from "Phase 6 candidate" to
"post-CRAN only-if-needed"**. Implement only if Phase 5.5
external validation surfaces a real user case where Laplace
clearly fails on typical-shaped data. The literature predicts
this will be rare. A single-paragraph pedagogy note in
`psychometrics-irt.Rmd` (Phase 1e Rose+Darwin sweep) suffices:

> *"`gllvmTMB` uses the Laplace approximation for the
> random-effect integral. For typical IRT data (≥ 15 items
> per person, $d \le 3$), this is accurate to within
> sampling noise on identifiable parameters (Pinheiro & Chao
> 2006; Joe 2008; Niku et al. 2019). For very short scales
> (≤ 10 items) or fits flagged by
> `gllvmTMB_check_consistency()`, consider cross-checking
> against `mirt` (with AGHQ enabled) or a Bayesian fit."*

This is a **scope-clarification**, not a feature backlog
item. The original audit-2 framing of "queue AGHQ as a
Phase 6 candidate" was correct in shape but overestimated
the priority. The maintainer's 2026-05-15 evening decision
("stay Laplacian") resolves this cleanly.

The companion idea (variational approximation, VA, for
**high-$d$ JSDM** where Laplace genuinely degrades and AGHQ
is infeasible anyway) remains the **higher-priority Phase 6
candidate** if any post-CRAN integrator work is undertaken.
See decisions.md 2026-05-15 evening entry.

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
| A1 | **Deprioritised** -- single-paragraph "Laplace is accurate enough for typical IRT" note in `psychometrics-irt.Rmd`; route confirmed problematic cases to `mirt` (AGHQ) or Bayesian alternatives. No engine implementation. | Phase 1e | Phase 1e Rose+Darwin reframe sweep PR |
| A2 | "Measurement error vs biological heterogeneity" callout in `pitfalls.Rmd` (or `simulation-recovery.Rmd` Caveats) | Phase 1e | Phase 1e Rose+Darwin reframe sweep PR |
| A3 (new) | **Higher-priority post-CRAN integrator candidate**: variational approximation (VA) for high-$d$ binary JSDM (5+ latent factors, hyper-sparse rare-species detections). Where Laplace genuinely degrades and AGHQ is infeasible anyway. | Phase 6 / 0.3.0 | Post-CRAN, only if external validation flags it |

Items logged in `docs/dev-log/decisions.md` so they don't
dissolve into chat.

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
