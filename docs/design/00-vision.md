# Vision

**Maintained by:** Ada (orchestrator) and Pat (applied-user lens).
**Reviewers:** Darwin (biology-first framing) and Rose (consistency
audit).

`gllvmTMB` is the fast, user-first R package for **multivariate
latent-variable models** in ecology, evolution, and environmental
science. The unit × trait framework -- one model that handles many
response traits per observational unit -- is the organising idea.

The package identity is:

> Multivariate GLMMs by reduced-rank regression, with phylogenetic
> and spatial extensions, **all in one engine, all in one formula
> grammar**. Built on TMB for speed; designed for biology-first
> reading.

`gllvm` (Niku et al.), `glmmTMB`'s `rr()` machinery (McGillycuddy
et al.), `galamm` (Sørensen et al.), and `Hmsc` are important
conceptual references, but `gllvmTMB` should not copy any of their
grammars wholesale. The public grammar should be easy to remember
for applied biologists and strict enough to keep the TMB
implementation identifiable.

Every implemented model class should have two parallel
representations:

1. symbolic equations that define the likelihood and parameter
   meanings;
2. matching R syntax that maps each equation term to a formula
   component.

This is both a development discipline and a teaching principle.
Equations prevent API drift; syntax makes those equations usable.
The 5-row alignment table convention (see
`.agents/skills/add-simulation-test/SKILL.md`) is the canonical
form.

## What makes `gllvmTMB` different

`gllvmTMB` is the first R package to combine, in one engine and one
formula grammar, the following five capabilities:

1. **Multivariate GLMMs by reduced-rank regression** -- the
   `latent() + unique()` decomposition of trait covariance,
   exposed via a clean 3 × 5 covariance keyword grid (see
   `docs/design/01-formula-grammar.md`).
2. **Phylogenetic GLLVMs** via sparse `A^{-1}` representation
   (Hadfield & Nakagawa 2010 trick). Not just single-trait
   phylogenetic mixed model -- reduced-rank latent factors *with*
   phylogenetic structure.
3. **Spatial GLLVMs** via fast SPDE / GMRF precision matrices
   (inherited from `sdmTMB`; Lindgren et al. 2011). Multi-trait
   spatial fields, not just one trait at a time.
4. **Meta-analytic GLLVMs** via `meta_known_V(value, V = V)`,
   including block-diagonal within-study correlation through
   `block_V()`. Treats meta-analysis as multi-trait GLLVM with
   known sampling covariance.
5. **Latent-scale correlations on mixed-family fits.** Different
   families per trait (or per row); the engine applies the
   appropriate per-family link residual (π²/3 for binomial-logit,
   1 for probit, trigamma terms for Gamma / NB2 / Beta / etc.) on
   the latent liability and reports correlations on that scale.

Item 5 is the **unparalleled capability**: no current package
offers mixed-family latent-scale correlations cleanly. `gllvm` is
single-family per fit. `galamm` is SEM-style without
phylogenetic or spatial machinery. `Hmsc` is Bayesian (slow).
`brms` has known identifiability pathologies on GLLVM-style
models.

## Core Idea

A model is defined by:

1. one long-format response column (`value`) or wide-format data
   marked with the `traits(...)` LHS helper;
2. trait-level fixed effects on the RHS (e.g.
   `value ~ 0 + trait + (0 + trait):env`);
3. one or more covariance-structure keywords drawn from the
   3 × 5 grid:

| correlation \ mode | scalar | unique | indep | dep | latent |
|---|---|---|---|---|---|
| none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

4. a per-trait response family from `R/families.R` (single family
   or `family = list(...)` for mixed-family);
5. optional `meta_known_V(value, V = V)` for known-sampling-
   covariance meta-analysis.

The decomposition mode is the `latent + unique` pair:
**Σ = ΛΛᵀ + Ψ**, where `Λ` is a low-rank loading matrix and `Ψ`
is the diagonal trait-unique-variance matrix (factor-analysis /
SEM convention; Bollen 1989, Mulaik 2010, lavaan). See the
`decisions.md` 2026-05-14 notation entry for the historical
reasoning.

## Signature Feature

The signature syntax reads like the model's biological story --
each line names a covariance source. The default `unit = "site"`
is used here because the canonical example is site × species.
For other data shapes (`individual`, `species`, `study`), pass the
appropriate column name.

```r
gllvmTMB(
  value ~ 0 + trait
        + latent(0 + trait | site, d = 2)         # B-tier shared
        + unique(0 + trait | site)                # B-tier diagonal
        + latent(0 + trait | site_species, d = 1) # W-tier shared
        + unique(0 + trait | site_species)        # W-tier diagonal
        + phylo_latent(species, d = 1)            # phylogenetic LV
        + phylo_unique(species),                  # phylogenetic diagonal
  data = df,
  family = gaussian()
)
```

The equivalent wide-format call with the same model:

```r
gllvmTMB(
  traits(trait_1, trait_2, trait_3) ~ 1
        + latent(1 | site, d = 2) + unique(1 | site)
        + latent(1 | site_species, d = 1) + unique(1 | site_species)
        + phylo_latent(species, d = 1) + phylo_unique(species),
  data = df_wide,
  family = gaussian()
)
```

Both reach the same long-format engine and produce a byte-identical
log-likelihood (see `docs/design/01-formula-grammar.md` for the
`traits()` LHS expansion rules). User-facing examples in README,
vignettes, and Tier-1 articles should pair both forms side-by-side
with a `logLik` agreement check, following the morphometrics article
pattern.

## Audience And Examples

Primary audience: applied ecologists, evolutionary biologists,
behavioural ecologists, environmental scientists doing comparative
or community-level statistics. Secondary audience: statisticians
and method developers in adjacent fields (quantitative genetics,
psychometrics, multivariate statistics).

Worked examples should answer real biological questions, not
illustrate machinery. The current Tier-1 worked examples (when
their backing machinery validates per the validation-debt register
in `docs/design/35-validation-debt-register.md`) include:

- morphometric trait covariance (single-level individual × trait);
- joint species distribution modelling (site × species);
- behavioural syndromes (two-level individual × session × trait);
- functional biogeography (capstone: site × species × trait + phylo + spatial);
- phylogenetic comparative methods (species × trait + phylogeny);
- meta-analysis with within-study sampling correlation;
- IRT-style psychometrics (person × item) -- a cross-domain
  validation case that the engine handles natively.

**In-prep citations**: only acceptable for engine-specific
validation claims (e.g. the Nakagawa et al. in-prep functional-
biogeography methods paper, as a citation for the *specific
six-piece model*). Foundational claims (reduced-rank GLLVM,
phylogenetic mixed model, SPDE spatial) cite the published
literature (Hui 2017, Niku 2017, 2019, Hadfield & Nakagawa 2010,
Lindgren et al. 2011, Anderson et al. 2025, Mizuno et al. 2026).

## Sibling Boundary

`gllvmTMB` is the **multivariate stacked-trait** package. Its
sister packages have separate scopes:

- **`drmTMB`** (sister) -- univariate and bivariate distributional
  regression. Location-scale models, GAMLSS-style parameter
  modelling, bivariate residual correlation `rho12`. Anything
  with three or more responses belongs in `gllvmTMB`.
- **`sdmTMB`** (sister) -- single-response spatial / spatiotemporal
  models with SPDE random fields. We inherit the SPDE / mesh /
  anisotropy R helpers from `sdmTMB` (with provenance in
  `inst/COPYRIGHTS`).
- **`glmmTMB`** -- single-response mixed models. `gllvmTMB`'s
  reduced-rank `latent()` and diagonal `unique()` keywords share
  the `glmmTMB::rr()` / `diag()` machinery (McGillycuddy et al.
  2025); we extend it to the multi-trait stacked-trait grammar.
- **`gllvm`** -- peer GLLVM package, ecology-focused, with
  variational-approximation default for binary high-dimensional
  fits. `gllvmTMB` differs by offering phylogenetic + spatial in
  the same engine, mixed-family fits with latent-scale
  correlations, and a stacked-trait long-format grammar that maps
  to `glmmTMB`-style formula syntax.
- **`galamm`** -- generalised additive latent and mixed models;
  SEM-style. No phylogenetic or spatial keywords. Wald-only
  inference. `gllvmTMB` differs by offering profile-likelihood and
  bootstrap CIs on derived quantities.

All four TMB-based siblings share a common discipline: canonical
keywords; simulation recovery on every likelihood change;
after-task reports; design-doc updates before architecture change.

## What we will NOT do

The discipline that makes `gllvmTMB` reliable is what we choose
*not* to support without proper validation. Per maintainer
ratification 2026-05-16:

1. **No advertised capability without end-to-end validation.**
   Every claim in README / NEWS / vignettes / pkgdown is backed
   by a row in `docs/design/35-validation-debt-register.md` with
   test evidence, diagnostic status, and interval status. If a
   capability is "covered" we ship it; if it is "partial" we say
   so explicitly; if it is "blocked" we do not advertise it.
2. **No /loop autopilot for article ports** or any other
   multi-step batch. Each article PR gets Pat + Rose review
   *before* edits, not retrospectively. (The 2026-05-15
   article-port crisis is the reason for this rule.)
3. **No new family without simulation tests** (AGENTS.md Design
   Rule #1). Families are added one at a time, validated, then
   ship.
4. **No formula-grammar change without updating
   `docs/design/01-formula-grammar.md`** (AGENTS.md Design Rule
   #3). The grammar is a public-API contract.
5. **No likelihood parameterization change without applying the
   `tmb-likelihood-review` skill** (AGENTS.md Design Rule #4).
   Numerical stability is non-negotiable.
6. **No single-response distributional regression** -- that's
   `drmTMB`'s lane. Mixed responses across traits is in scope;
   distributional regression for one or two responses is not.
7. **No fork of `gllvmTMB-legacy`'s 133-export surface.** We
   ship a focused, tested API. Legacy articles are *ports* under
   the validation-debt discipline, not unconditional restorations.
8. **No `Imports: sdmTMB` or other heavyweight dependencies.** We
   vendor the R-side helpers we reuse (`R/mesh.R`, `R/crs.R`,
   parts of `R/plot.R`) with provenance in `inst/COPYRIGHTS`.

## Function-first development discipline

`gllvmTMB` builds **machinery first, examples second**. This is
the drmTMB-team discipline ratified by maintainer 2026-05-16
after the 2026-05-15 article-port crisis showed the cost of the
opposite order.

The development sequence to CRAN:

- **Phase 0A** (this doc + sibling design docs) -- ratify the
  infrastructure: vision, formula grammar, family registry,
  likelihoods, random effects, testing strategy, extractors
  contract, validation-debt register. **No R/ code changes.**
- **Phase 0B** -- transition cleanup: remove articles that
  overpromise; close the Phase 1e audit-sweep; rewrite ROADMAP
  to milestone format; run the Phase 1b empirical coverage
  artefact.
- **Phase 1 -- M1 Gaussian completeness.** Random intercepts +
  **random slopes** + all CI methods + all extractors + ≥ 94 %
  empirical coverage. Validation-debt register Gaussian row
  goes "covered". `morphometrics.Rmd`, `behavioural-syndromes.Rmd`,
  `phylogenetic-gllvm.Rmd` keep their Gaussian sections; any
  non-Gaussian content is moved out until its machinery validates.
- **Phase 1 -- M2 Binary completeness.** Same machinery for
  `family = binomial()`. Includes `lambda_constraint` and
  `suggest_lambda_constraint()` validation -- the confirmatory-
  loadings tooling needed for honest binary IRT and binary
  JSDM. Validation-debt register binomial row goes "covered".
  `psychometrics-irt.Rmd` and `joint-sdm.Rmd` (binary section
  only) get re-written using validated machinery.
- **Phase 2+ -- other families and machinery extensions.** Each
  family validated one at a time, with its own slice; article
  ships only after its slice closes. Mixed-family latent-scale
  correlations -- the unparalleled-capability claim of this
  package -- come after at least Gaussian + binomial + one count
  family + one continuous-positive family are individually
  validated.

Articles that describe machinery beyond what is currently
validated are either pulled (per the validation-debt register)
or marked "Preview" with a clear pointer to the relevant phase.

## Team

`gllvmTMB` is built by a named team with standing review roles
(see `AGENTS.md`). When a design doc, after-task report, or
article PR references a persona's contribution, that persona's
lens has been *actively applied* -- not retrospectively listed.
Ada orchestrates.

| Persona | Owns | Primary question |
|---------|------|------------------|
| **Ada** | Orchestration; integration; merge authority | What should happen next, and is everything consistent? |
| **Boole** | Formula grammar (3 × 5 keyword grid + `traits()` LHS) | Is the syntax memorable, parseable, internally consistent? |
| **Gauss** | TMB likelihoods + numerical stability | Is the likelihood correct and numerically stable? |
| **Noether** | Math-vs-implementation alignment | Do equations, R syntax, and TMB implementation match? |
| **Fisher** | Statistical inference (CIs, coverage, profile) | Do simulations, comparators, profiles support the claim? |
| **Curie** | Simulation + testing + recovery studies | Do tests cover ordinary, edge, malformed cases without becoming too slow? |
| **Emmy** | R package architecture + S3 + extractors | Are S3 methods, object structures, extractors coherent? |
| **Pat** | Applied PhD user readability | Can a new applied user follow the tutorial, interpret output, recover from errors? |
| **Darwin** | Ecology / evolution audience framing | Does the example answer a real biological question? |
| **Jason** | Literature scout | What do related packages and papers already do? |
| **Grace** | CI + pkgdown + CRAN mechanics | Will this pass on all platforms and deploy cleanly? |
| **Rose** | Pre-publish systems audit | What discrepancies, repeated mistakes, stale wording are accumulating? |
| **Shannon** | Cross-team coordination audit | Are branches, PRs, file overlap, and message-bus coverage consistent? |

When you read "Ada decides", "Pat reviews", "Rose audits", "Boole
authors" in this repo, those names mean the specified review lens
has been actively engaged with the work at hand. They are not
ornamental.
