# Phase 0C — Nakagawa et al. *in prep* paper-findings notes (2026-05-16 reading)

**Maintained by:** Jason (literature scout) and Rose (consistency
audit).
**Reviewers:** Pat (applied-user lens), Darwin (biology-first
framing), Boole (formula-grammar correctness), Ada (orchestrator
ratifies).
**Status:** Reference notes for Phase 0C execution PRs. Captures
findings from a focused 2026-05-16 reading of:

> Nakagawa S et al. (in prep). *Functional biogeography using
> generalised linear latent variable modelling: a framework for
> quantifying trait–environment relationships and local and global
> trait integration*. PDF read 2026-05-16
> (`~/Desktop/GLLVMs_for_functional_biogeograhy.pdf`, 23 pages).

## Purpose

The paper is the canonical reference for the
`functional-biogeography.Rmd` capstone article and (via Section
3.12) for the `corvidae-two-stage.Rmd` workflow. The maintainer
shared the PDF mid-Phase-0C review with the prompt *"#5 is an
alternative analysis of #6 — do you understand this?"* This
document captures the findings that affect Phase 0C execution
without amending the parent triage doc retroactively.

## Paper structure (sections relevant to gllvmTMB articles)

| Section | Content | Phase 0C relevance |
|---|---|---|
| **1** Introduction | Functional biogeography framing; trait-environment relationships; CWM limitations | Background for `functional-biogeography.Rmd` |
| **2.1–2.3** Overview + replicated site–species–trait model + conceptual Gaussian model | Eq. 2: `y_sit = μ_st + r_st + u_st + e_sit + p_it + q_it` | Canonical equation for `functional-biogeography.Rmd` |
| **2.4** Spatial and phylogenetic dependence | Dependence-control framing | **Affects `functional-biogeography.Rmd` revision** |
| **2.5** From covariances to correlations, ordinations, ICCs, communalities | `c²_B,t = (Λ_B Λ_B^⊤)_tt / (Σ_B)_tt` | Communality is rank-conditional |
| **2.6** Total vs partial integration | Mean structure choice determines what residual covariance means | Article framing |
| **2.9** Identifiability and practical data requirements | Species recurrence required for p/q/e split | **Affects `functional-biogeography.Rmd` + `corvidae-two-stage.Rmd`** |
| **2.10** Site-level summaries as pragmatic special case | One value per (site, trait) → Σ_W drops out | Cross-reference for #5 ↔ #6 |
| **3.1** Implementation overview | `glmmTMB` as practical starting point | gllvmTMB scope alignment |
| **3.7** Combined model | `rr + diag + propto + diag + diag + exp` capstone | The model `functional-biogeography.Rmd` describes |
| **3.9** Rank selection and fitting strategy | **Stage-wise fitting** recommendation | **Affects `functional-biogeography.Rmd` revision** |
| **3.10** Model checking and sensitivity | Sensitivity to weighting, predictor set, omitted spatial / species terms | Diagnostic discipline |
| **3.12** Site-level summaries as a practical fallback | **Two-stage workflow** description | **Defines #5's positioning** |
| **3.12.1–3.12.2** Stage 1 + Stage 2 | Concrete glmmTMB calls for the two-stage path | Directly describes `corvidae-two-stage.Rmd` |
| **3.13** Extensions beyond the Gaussian case | Bayesian alternatives for ambitious aims | **Affects `cross-package-validation.Rmd` framing** |
| **4** Worked examples (pending) | Plant functional biogeography; island morphology; binary trait states | None of these is corvidae |

## Key findings affecting Phase 0C execution

### Finding 1 — #5 IS the Section-3.12 fallback for #6

**Paper Section 3.12** (page 15):

> *"When the full replicated site–species–trait model is unavailable
> or too difficult to fit, a practical fallback is to use a
> two-stage analysis. ... This route is easier to implement than the
> full replicated model, but it necessarily collapses the within-site
> replicated species structure and therefore cannot estimate local
> integration in the same sense as the replicated approach.
> **We therefore present it as a pragmatic reduced analysis rather
> than the main conceptual target when richer raw data are
> available.**"*

**Paper Section 3.12.2 closing** (page 19):

> *"We therefore view this route as an **intermediate option: more
> defensible than analysing CWMs as if they were error-free data,
> but still secondary to the full replicated site–species–trait
> model when that fuller analysis is possible.**"*

**Implication for triage**:
- `corvidae-two-stage.Rmd` (#5) and `functional-biogeography.Rmd`
  (#6) are paired analyses of the same scientific framework.
- The two articles must cross-reference each other.
- Both must cite Nakagawa et al. (in prep) as the canonical
  reference.

### Finding 2 — corvidae's low within-site recurrence justifies two-stage

**Paper Section 2.9** (page 8):

> *"Separating species effects (p_it, q_it) from within-site
> deviations e_sit is facilitated when species recur across sites.
> **When many species occur only once, the data contain little
> information to distinguish a repeatable species effect from a
> site-specific deviation, and the p/q/e decomposition can become
> weakly identified.** In such cases, it can be more defensible to
> omit one or both species-level terms, or to treat them as
> adjustment terms rather than as central biological targets."*

**Paper Section 3.6** (page 12):

> *"If most species occur only once or only a few times, the model
> will have limited information with which to distinguish species
> effects from within-site deviations, and one may reasonably omit
> the species-level terms or treat them mainly as adjustment
> terms."*

**Implication for triage**:
- The corvidae meta-analysis (outcomes per study; outcomes don't
  recur across studies the way species recur across sites) is the
  Section-2.9 sparse-data scenario.
- `corvidae-two-stage.Rmd` is the **right disposition** for this
  data, not a stylistic choice.
- Maintainer's 2026-05-16 note (*"corvidae dataset is a good one
  as they do not have much variations"*) is exactly this point.

### Finding 3 — Spatial / phylogenetic terms are dependence-control, NOT primary summaries

**Paper Section 2.4** (page 6):

> *"The crucial practical point is that the current Gaussian
> stacked-trait implementation in `glmmTMB` does not naturally
> provide a fully trait-specific spatial and phylogenetic variance
> decomposition alongside the reduced-rank u/e structure. Instead,
> in that implementation the spatial and phylogenetic terms are
> best viewed as **dependence-control terms**. They help prevent
> the non-spatial between-site term from absorbing geographic
> autocorrelation and help prevent repeated species structure from
> being attributed too strongly to the u/e decomposition. **This
> is still statistically and biologically useful, but it means
> that trait-specific spatial ICCs or phylogenetic ICCs are not
> the most natural primary summaries of the simplest `glmmTMB`
> workflow.**"*

**Paper Section 2.5** (page 7):

> *"We do **not** recommend emphasising trait-specific spatial or
> phylogenetic ICCs as primary summaries in the current `glmmTMB`
> workflow, because those terms are more naturally treated there
> as adjustment terms rather than as a clean trait-wise variance
> partition. Their inclusion is still valuable because it sharpens
> interpretation of Σ_B and Σ_W, but the main biological summaries
> should come from the between-site and within-site reduced-rank
> decomposition itself."*

**Implication for `functional-biogeography.Rmd`**:
- If the article emphasises trait-specific spatial / phylogenetic
  ICCs as primary outputs, that is misaligned with the canonical
  paper.
- PR-0C.PREVIEW should add Section-2.4 / Section-2.5 framing in
  the preview banner: spatial + phylogenetic terms are
  dependence-control; primary summaries come from Σ_B and Σ_W
  reduced-rank decomposition.

### Finding 4 — Stage-wise fitting, not kitchen-sink

**Paper Section 3.9** (page 14):

> *"A practical fitting order is often helpful. One can begin with
> a low-rank between-site model only, then add the within-site
> component, then environmental predictors, then the spatial term,
> and finally the species-level terms. Among species-level terms,
> it is often useful to add the non-phylogenetic component first
> and then the phylogenetic component. **If the species-level
> terms contribute little, are weakly identified, or destabilise
> the fit, that itself is informative and may indicate that the
> data contain insufficient cross-site species recurrence to
> support that decomposition.**"*

**Implication for `functional-biogeography.Rmd`**:
- The capstone-as-one-fit pattern (if present) is misaligned with
  the paper's recommendation.
- Article should demonstrate stage-wise model building, with
  diagnostic stops at each stage.

### Finding 5 — Communalities are rank-conditional

**Paper Section 2.5** (page 7):

> *"Because communalities depend on the retained rank, they should
> be interpreted conditionally on `d_B` and `d_W`, which should be
> chosen using model selection, diagnostics, and biological
> interpretability."*

**Implication**:
- Any communality numbers reported in `functional-biogeography.Rmd`
  must state `d_B` and `d_W` explicitly.

### Finding 6 — Bayesian alternatives positioning

**Paper Section 3.13** (page 19):

> *"When more ambitious aims are central—for example, mixed trait
> families, fully trait-specific spatial or phylogenetic variance
> partitioning, or stronger identifiability constraints across
> multiple dependence structures—**a more flexible Bayesian
> implementation may be preferable.** In our view, `glmmTMB` is
> best regarded as the **practical starting point**: it captures
> the main between-site/within-site decomposition directly and
> allows spatial and phylogenetic dependence to be controlled,
> even if the full conceptual model lies beyond its current most
> straightforward implementation."*

**Implication for `cross-package-validation.Rmd`**:
- The right Bayesian comparators for the full framework are
  **Hmsc** (most direct JSDM-trait match) and **MCMCglmm** (most
  direct multivariate-mixed match).
- These are deferred to Phase 5.5 (per the existing audit's row
  #18 TRIM-SECTION); the deferral is consistent with the paper's
  framing (glmmTMB is the practical starting point; fuller
  Bayesian implementations are post-CRAN).
- For the two-stage workflow (corvidae), the right classical
  comparator is **`metafor::rma.mv`** (Viechtbauer 2010);
  `corvidae-two-stage.Rmd` should add a cross-reference paragraph.

## Per-article implications (companion to the parent triage)

### `functional-biogeography.Rmd` (triage row #6, currently PREVIEW-BANNER)

The preview banner needs to include four paper-grounded points:

1. **Capstone validation is M3+ work** (already in triage rationale).
2. **Spatial + phylogenetic terms are dependence-control, not
   trait-wise primary summaries** (paper Section 2.4 + 2.5;
   Finding 3 above).
3. **Communalities are rank-conditional** — report `d_B` and
   `d_W` explicitly (paper Section 2.5; Finding 5).
4. **Identifiability requires within-site species recurrence**
   (paper Section 2.9; Finding 2). When data are sparse, the
   `corvidae-two-stage.Rmd` two-stage workflow is the appropriate
   fallback.

Cross-link to `corvidae-two-stage.Rmd` as the Section-3.12 fallback
for sparse-data scenarios.

### `corvidae-two-stage.Rmd` (triage row #5, currently KEEP)

Add a framing paragraph at the top:

> *"This article demonstrates the Section-3.12 site-level-summary
> fallback from Nakagawa et al. (in prep), appropriate when
> within-site species (or outcome) recurrence is sparse — e.g.
> meta-analyses where each study contributes a unique set of
> outcomes. For datasets with replicated species-in-site
> observations, prefer the full replicated model demonstrated in
> [`functional-biogeography.Rmd`](functional-biogeography.html)."*

Add a one-paragraph cross-reference to `metafor::rma.mv` as the
established multivariate meta-analytic standard the two-stage
workflow matches.

### `cross-package-validation.Rmd` (triage row #18, currently TRIM-SECTION)

The trim removes queued Bayesian comparators (Hmsc, MCMCglmm,
galamm, brms, sdmTMB beyond single-trait). Paper Section 3.13
confirms this is the right scope decision: glmmTMB is the
practical starting point; Bayesian alternatives are post-CRAN
Phase 5.5 work.

The trim should keep:
- Live `glmmTMB::glmmTMB()` agreement runs (covered)
- Live `gllvm::gllvm()` agreement runs (covered)
- A short forward-looking note: *"Hmsc + MCMCglmm cross-package
  agreement runs are Phase 5.5 work per `decisions.md`
  2026-05-14 evening; see Nakagawa et al. (in prep) Section
  3.13."*

## Out of scope for these notes

- Empirical findings from the paper's worked examples (Section 4)
  — pending in the paper draft (titles only on page 20).
- The paper's simulation study (Section 5) — pending in the paper.
- Specific dataset references (the paper does not use corvidae).

## Cross-references

- `docs/dev-log/audits/2026-05-16-phase0c-article-triage.md` —
  parent triage doc (PR #140, commit `42fdc3d`).
- `docs/design/00-vision.md` — vision item 4 (`meta_V`) and item
  6 (sibling-package boundaries).
- `docs/dev-log/decisions.md` 2026-05-16 entry — Phase 0A / 0B /
  0C sequencing.

## Persona engagement

- **Jason** (lead, literature scout): owns the paper reading +
  per-finding implications. Filed under audit conventions for
  per-phase-boundary landscape scans.
- **Rose** (lead, consistency audit): cross-checks the
  per-article implications against the parent triage.
- **Pat** (review): applied-user clarity of the four preview-
  banner points for `functional-biogeography.Rmd`.
- **Darwin** (review): biology-first framing of the dependence-
  control vs primary-summary distinction.
- **Boole** (review): formula-grammar correctness of any
  example calls cited in the preview banner.
- **Ada** (orchestrator): ratifies and routes the findings into
  the PR-0C.PREVIEW execution PR.
