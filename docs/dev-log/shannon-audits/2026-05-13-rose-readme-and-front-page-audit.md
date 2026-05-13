# Audit: Rose README + pkgdown front-page sweep

**Trigger**: maintainer flagged 2026-05-13 ~04:25 MT that the live
pkgdown index page is hard for a new user to read. Specifically:
abbreviations dumped without unpacking, no clear differentiation
of long vs wide, and the page does not communicate why a user
would reach for `gllvmTMB`. The Pat audit (PR #62) covered
articles but skipped the front page; this Rose audit fills that
gap and chases the drift across the cross-doc surface.

**Audience**: maintainer for scope/rewrite decisions; Codex or
Claude for any rewrite implementation PRs.

**Method**: read `README.md` as a fresh applied user, then walk
the cross-doc surface for terminology / claim drift. Rose's
classic lane: one mistake exposed, many more in the same class.

## Section A: README.md friction (top-down)

### A1. Opening paragraph is unreadable

Lines 3-7:

> `gllvmTMB` fits stacked-trait multivariate generalised linear
> latent variable models (GLLVMs) with Template Model Builder.
> Use it when the same units have several responses, traits,
> species, behaviours, or items, and the scientific question is
> about their shared covariance, ordination, communality,
> phylogenetic signal, or spatial structure.

Specific problems:

- **Sentence 1** stacks 4 jargon terms without unpacking:
  "stacked-trait", "multivariate generalised linear latent
  variable models", "GLLVMs", "Template Model Builder". A new
  applied user does not know which of these to ignore and which
  to look up.
- **"Stacked-trait" is undefined.** It is THE key term that
  distinguishes `gllvmTMB` from `glmmTMB` / `sdmTMB`, but the
  README never says what it means. Pat asks: "Do my data
  qualify?"
- **"Template Model Builder" is opaque.** A user does not need to
  know about TMB to use the package; mentioning it in sentence 1
  is leakage of internal detail.
- **Sentence 2** lists 5 concepts ("shared covariance,
  ordination, communality, phylogenetic signal, or spatial
  structure") in one breath. None is signposted. A reader who
  cares about communality has to read all five before knowing
  this package handles it.
- **"the same units have several responses, traits, species,
  behaviours, or items"** lists 5 different kinds of column, but
  the relationship between them is unclear (synonyms? options?
  union?).

### A2. Long-vs-wide section: shown as three blocks under "two paths"

Lines 9-28:

> The package accepts data in either **long** or **wide** shape;
> the two paths reach the same engine

then three code blocks: Long, Wide data frame, Wide matrix.

- The reader sees three options labelled "two paths". Contradiction
  on first scan.
- The wide-matrix path (`gllvmTMB_wide(Y, ...)`) is shown with
  three dots; Pat does not know what shape `Y` should be or how
  trait names are inferred.
- The wide-data-frame example uses
  `traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2)`. The reader
  does not yet know what `latent`, `unit`, or `d = 2` mean. The
  example is opaque without the article walk-through that comes
  later.
- No guidance on **which shape to pick**. Pat with a wide CSV
  asks: "Should I pivot to long?" The answer is no, but the
  README does not say so.

### A3. "Data shape is general" paragraph (L30-33)

> The first examples are motivated by ecology, evolution, and
> environmental science, but the data shape is general: site x
> species, individual x trait, species x trait, paper x outcome,
> or any similar unit x response layout.

- Lists 4 layouts in a row without an example of each. A
  meta-analyst with `paper x outcome` data wonders: "Which is the
  unit -- paper or outcome?"
- Implicit assumption that the reader has already understood the
  abstract `unit x response` framing from the earlier paragraph.
  But the earlier paragraph did not actually define it.

### A4. The "Start here" link list has redirection drift

Lines 35-48 link to 6 articles with helpful "If you ..." prompts.
Good in principle, but:

- The prompts are in absolute URL form
  (`https://itchyshin.github.io/...`), which is correct for the
  README rendered on GitHub but redundant when rendered into
  pkgdown's own `index.html` (the very page we are looking at).
  The duplication is harmless but reads like the README forgot
  it was being re-rendered as pkgdown content.
- "Choose your model" is named here but the Pat audit (PR #62
  F1, F2, F3) showed that article has its own friction. The
  README sends users into the friction.

### A5. "Preview status" before "Install"

Lines 50-55 then 57-65. A reader's first practical question is
"how do I install this?", which is answered after the preview-
status caveat. Conventional ordering: install first, then status
caveats.

### A6. Smoke test (L67-93) uses concepts not yet explained

The smoke test calls `simulate_site_trait` (what does this
return?), constructs a fit with `latent + unique` (the keywords
are not yet introduced), and calls `extract_communality` /
`extract_correlations` (returns named numerics the reader has
no way to interpret).

### A7. Math block (L101-126) is for an audience that does not need the README

Lines 105-110:

```text
y_it = alpha_t + z_i lambda_t + epsilon_it
z_i ~ Normal(0, 1)
epsilon_it ~ Normal(0, s_t)
Sigma = Lambda Lambda^T + diag(s)
```

- Standard GLLVM notation but no glossary. `alpha_t` (trait
  intercept), `z_i` (latent score), `lambda_t` (loading),
  `epsilon_it` (residual), `s_t` (per-trait variance) are not
  defined.
- A reader who reads notation well already knows GLLVMs; a
  reader who does not is lost.
- The model description belongs in the dedicated
  `covariance-correlation` article (which Codex is currently
  revising in PR #61). The README should briefly motivate it,
  not derive it.

### A8. "What can I model now?" (L128-155) is the most useful section but buried

Reading order on the front page: jargon-stack opener → long/wide
shapes → general layouts → start-here links → preview status →
install → smoke test → math → "What can I model now?". The
section a new user wants first ("does the package handle MY
problem?") is item 8 in the read order.

### A9. Three-shapes / two-shapes contradiction recurs (L178-189)

Lines 185-189 repeat the long-vs-wide framing from the top:

> The package accepts data in either **long** or **wide** shape.
> `gllvmTMB(value ~ ..., data = df_long)` is the long-format path;
> `gllvmTMB(traits(...) ~ ..., data = df_wide)` is the wide
> data-frame formula path; `gllvmTMB_wide(Y, ...)` is the wide
> matrix path.

Same contradiction as A2: "two shapes" → three named paths.

### A10. Tiny smoke test repeats earlier fit

Lines 112-126 fit essentially the same model as L82-93 with
slightly different settings. Two near-duplicate fits within
the same page.

## Section B: cross-doc terminology drift Rose surfaces

### B1. "stacked-trait" appears 4 times in README but is never defined

```sh
$ rg -n 'stacked-trait' README.md
3:`gllvmTMB` fits stacked-trait multivariate generalised linear
54:  stacked-trait workflows listed below, and treat unsupported model
180:`gllvmTMB` is for stacked-trait multivariate models. Single-response
204:- **gllvmTMB**: Nakagawa S (in prep). *gllvmTMB: stacked-trait,
```

Used as a defining property, but no sentence says what it means.
The Pat audit's F1 ("wide-format framing missing" in
`choose-your-model`) is the same class: a defining concept treated
as if the reader already knows it.

### B2. "communality" appears in README + 3 articles, definition deferred

```sh
$ rg -n 'communality' README.md vignettes/articles/
README.md:7:... ordination, communality, phylogenetic signal ...
README.md:45:- Interpreting Sigma, correlations, and communality? Read
README.md:91:extract_communality(fit, level = "unit")
README.md:126:... Sigma, pairwise correlations, and per-trait communality.
covariance-correlation.Rmd:* (Codex revising; check coverage on landing)
choose-your-model.Rmd:352:`extract_communality(fit, "B")`, `extract_communality(fit, "W")`
behavioural-syndromes.Rmd:425:Between-individual communalities
```

The term appears 4 times in README without definition. Defined
in `covariance-correlation.Rmd` (under Codex revision) and used
in `behavioural-syndromes.Rmd`. A reader who lands on README
"communality" link needs to click out to learn what it is.

### B3. "phylogenetic signal" appears in README + phylo article, definitions inconsistent

The README sentence (L7) treats it as a 1-of-5 scientific
target. The post-PR #53 `phylogenetic-gllvm.Rmd`'s
`extract_phylo_signal()` decomposes phylogenetic signal into
`H^2 + C^2_non + Psi = 1`. A user reading the README expects
"phylogenetic signal" to mean one thing; the article delivers a
three-component decomposition.

### B4. "ordination" appears 3 times in README, but the demo fit uses `d = 1`

L7 "ordination", L125 "report ordination scores, loadings,...".
But the README's tiny example (L82-93) and smoke test (L82-89)
both use `d = 1` (one-axis model). A one-axis model gives
ordination scores on a line, which is not what "ordination"
usually means to ecology users (2D scatter).

### B5. `simulate_site_trait` smoke test uses `site` as unit but data has `species`

L72-89 smoke test:

```r
sim <- simulate_site_trait(
  n_sites = 12,
  n_species = 5,
  n_traits = 3,
  mean_species_per_site = 3,
  ...
)

fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(...),
  data = sim$data,
  unit = "site"
)
```

The data has 12 sites × ~3 species per site (~36 (site,species)
combinations) × 3 traits = ~108 rows. The fit uses `site` as the
unit. But the README opener (L4-5) lists "species" among the
"several responses, traits, species, behaviours, or items".
A new user wonders: "Are species the unit, or one of the
responses?"

### B6. `extract_correlations(fit, tier = "unit")` — `tier` vs `level`

L92 uses `tier =`. Other extractors (`extract_communality`,
`extract_Sigma`, `extract_ordination`) use `level =`. The user
sees inconsistency on the same line:

```r
extract_communality(fit, level = "unit")
extract_correlations(fit, tier = "unit")
```

This is intentional (per the function signatures) but reads as
drift. The README's tiny example exposes the inconsistency.
Either:
- Add a sentence saying "(`tier` is the documented name for
  `extract_correlations`)".
- Harmonise the function signatures in a future Codex PR (more
  invasive).

### B7. "Sigma" / "Σ" / `Sigma` notation mixes ASCII and Unicode

README L7 says "shared covariance", L91 mentions "Sigma" in the
extract call's caption, L109 uses ASCII `Sigma = Lambda Lambda^T +
diag(s)`. Other articles use Unicode `Σ` in LaTeX. Cross-doc
notation drift Rose would flag.

### B8. "communality" vs "communalities"

README uses "communality" (singular). Some articles use
"communalities" (plural). Both are correct English; for
cross-doc consistency, pick one. Suggestion: singular
"communality" when referring to the concept, "communalities"
when listing per-trait values.

## Section C: cross-doc inventory of opening paragraphs

For Pat, the most decisive consistency check is: do the opening
paragraphs of README, `gllvmTMB.Rmd` (Get Started vignette),
`choose-your-model`, and each Tier-1 article frame the package
similarly?

| Source | First-sentence claim |
|---|---|
| README L3-4 | "stacked-trait multivariate generalised linear latent variable models (GLLVMs) with Template Model Builder" |
| Get Started vignette (`vignettes/gllvmTMB.Rmd`) | Not audited here; needs separate read |
| `choose-your-model.Rmd` L26-29 | "covers a large model space — one or two observational levels, optional phylogenetic structure, optional spatial structure, Gaussian / binary / Poisson / mixed responses, reduced-rank or full-rank trait covariance" |
| `morphometrics.Rmd` L26-31 | "the simplest case the package handles, and it is the foundation for everything else on the complexity ladder. One observational level (individuals), several continuous traits per individual, and shared low-rank covariance between traits." |
| `phylogenetic-gllvm.Rmd` L26-30 (post-PR #53) | "for a comparative-methods reader with several traits measured once per species. The working question is: can we separate phylogenetically conserved trait covariance from non-phylogenetic species-level covariance, while still keeping trait-specific variation on the diagonal?" |

Rose finding: the opening paragraphs do **not** share a
unifying framing. README opens with abstract terminology;
`choose-your-model` opens with "covers a large model space" (a
selling sentence); `morphometrics` opens with a concrete
biological setting; `phylogenetic-gllvm` opens with a question.
The reader sees four different "what is gllvmTMB for" framings
depending on the entry article.

A unifying lead sentence (suggested below) would harmonise this.

## Section D: recommended remediations

### D1. README opener rewrite (highest priority)

Replace the L3-7 opener. Suggested skeleton (maintainer-ratify
before applying):

> `gllvmTMB` fits **multivariate models** for data where the same
> rows carry several measurements at once — five body traits per
> bird, twenty species occurrences per site, three behaviours per
> session, several outcomes per study. The scientific target is
> the **trait covariance**: which measurements co-vary, what
> drives that covariance (a shared latent axis? a phylogenetic
> signal? a spatial pattern?), and how much variance is
> trait-specific.
>
> Three things distinguish `gllvmTMB`:
> - **Stacked-trait long format.** Internally the engine works
>   on `(unit, trait)` observations stacked into a long data
>   frame, so one fit can handle T traits with different
>   distributions, missing cells, and per-row predictors. Wide
>   data frames and matrices are accepted; the package pivots
>   for you.
> - **One formula grammar** for trait covariance.
>   `latent()` adds a low-rank shared axis; `unique()` adds a
>   trait-specific diagonal; the phylogenetic and spatial
>   variants (`phylo_latent`, `spatial_unique`, ...) extend the
>   same grammar to species relatedness and spatial fields.
> - **TMB engine, ML / REML estimates.** Fits take seconds to
>   minutes; profile-likelihood and bootstrap intervals are
>   first-class.

This opener:
- Defines "stacked-trait" by example before naming it.
- Names the three distinguishing features as a triad, not a
  five-item list.
- Tells the reader what to look at next (the formula grammar,
  the engine).
- Avoids "GLLVMs" / "Template Model Builder" until they earn
  their keep.

### D2. Reorder the README sections

Current order: opener → long/wide → general data shapes →
start-here links → preview status → install → smoke test →
tiny example → what-can-I-model → covariance grid → current
boundaries → citation → sister packages.

Suggested order:
1. Opener (D1 rewrite).
2. **What can I model now?** (currently buried at L128).
3. Install + smoke test (combined; preview status note at the
   bottom of this section).
4. Long / wide / matrix data shapes (with a one-sentence "pick
   the shape that matches your data on disk; the engine does
   the rest").
5. Tiny example (one fit, with the math model in a footnote-
   style aside, not a leading derivation).
6. Covariance keyword grid.
7. Current boundaries.
8. Citation and acknowledgements.
9. Sister packages.

This puts the "does the package handle my problem?" question
right after the opener, before the user has to slog through
syntax detail.

### D3. Resolve the two-shapes / three-paths contradiction

Pick one framing and use it consistently:

- **Three paths** (long, wide-data-frame, wide-matrix). Honest
  about the surface. The "two-shapes" framing is leftover from
  the pre-PR #39 era.
- Or: **two user-facing call patterns** (`gllvmTMB(...)` for
  long + wide-data-frame; `gllvmTMB_wide(Y, ...)` for matrix).
  The wide-data-frame form is a sugar inside `gllvmTMB`, not a
  separate path.

The audit recommends the **second** framing because that is
literally how the parser is structured (the `traits()` LHS
marker is sugar inside `gllvmTMB`; `gllvmTMB_wide()` is the
separate matrix entry point).

### D4. Define "stacked-trait" once, prominently

Either inside the D1 opener rewrite or as a short paragraph
right after. Suggestion:

> **What "stacked-trait" means.** Internally, every fit sees
> one row per `(unit, trait)` observation. Five traits on 100
> individuals become 500 rows, each with the trait identity in
> a `trait` column. Different traits can use different response
> distributions; missing cells drop out automatically. You can
> hand the engine a long data frame, a wide data frame, or a
> matrix — it pivots for you.

### D5. Standardise opening framings across articles

Each Tier-1 article opens with a different framing
(complexity-ladder vs concrete-biology vs question-driven).
Rose suggests picking one framing pattern and applying it:

Suggested pattern: each Tier-1 article opens with
(1) one-sentence concrete biological setting,
(2) one-sentence scientific question,
(3) one-sentence what this article delivers.

Apply this pattern to `morphometrics`, `joint-sdm`,
`behavioural-syndromes`, `phylogenetic-gllvm` (already mostly
follows; PR #53), `functional-biogeography`,
`covariance-correlation` (deferred pending Codex PR #61),
`choose-your-model`, `pitfalls`. Tier-2 articles
(`api-keyword-grid`, `response-families`, `ordinal-probit`)
have a different shape (reference) and can keep their current
openers.

### D6. Make `tier` vs `level` parameter inconsistency visible to the reader

Either add an inline note in the README smoke test:

```r
extract_communality(fit, level = "unit")   # 'level' for communality
extract_correlations(fit, tier = "unit")   # 'tier' for correlations -- historical
```

Or harmonise the signatures in a future Codex PR.

### D7. "Choose your model" should reach `latent + unique` as the canonical fit early

Pat audit F2 already covers this. Rose finding: the README's
boundary section (L191-196) lists random slopes / ZINB / barrier
meshes / two-U API as "planned work" — but the article that the
README sends users to (`choose-your-model`) does not lead them to
the canonical four-component fit. The boundary list and the
recommended-fit list need to agree.

## Section E: confidence and scope

High confidence on README-level findings (read directly).
Medium confidence on cross-article framing inconsistencies
(read the openers, not the full articles).

Did not cover:
- `vignettes/gllvmTMB.Rmd` (Get Started vignette). Should be
  read for the same opener-framing audit.
- pkgdown's rendered HTML output (audit reads on-disk Rmd
  source).
- `covariance-correlation.Rmd` (Codex PR #61 in flight).

## Section F: recommended action items (priority order)

1. **README opener rewrite** (D1) -- highest-impact, smallest
   change. Single-paragraph swap.
2. **Section reordering** (D2) -- one PR that moves blocks but
   does not rewrite their content.
3. **"Stacked-trait" definition paragraph** (D4) -- one
   paragraph; can land with D1.
4. **Two-shapes / three-paths resolution** (D3) -- requires
   maintainer to pick the framing. Once picked, mechanical.
5. **Opening-framing consistency across articles** (D5) -- bigger
   sweep; one PR per article ideally. Codex's lane for any
   article currently being revised.
6. **`tier` vs `level` clarification** (D6) -- one-line inline
   note in README + the relevant articles; or a future signature
   harmonisation.
7. **Get-started vignette audit** (deferred) -- audit
   `vignettes/gllvmTMB.Rmd` with the same lens.

Each recommendation can be one focused PR; no scope decision
needed beyond D3 (pick a framing). D3 was answered 2026-05-13
~04:30 MT: **one entry point** (`gllvmTMB()`), two data shapes;
`gllvmTMB_wide()` soft-deprecated in PR #65.

## Section G: proposed reader path (added after Codex coordination)

Codex relayed via maintainer 2026-05-13 ~04:45 MT that PR #61 is
narrow correctness for `covariance-correlation.Rmd`, not the
final documentation answer; the bigger ask is a Pat/Rose pkgdown
coherence pass that gives users a fast reader path like
drmTMB's. This Section G + H + I extends the audit with Codex's
five-item request to make this doc the joint plan.

### drmTMB's reader path (inspirational reference)

The drmTMB README opens with one sentence ("`drmTMB` fits fast
distributional regression models for one or two responses using
TMB") and one concrete sentence about when to use it. Then a
six-bullet "Start here" list with concrete user prompts ("New to
the package? ... Not sure which response family fits your data?
... Fitting a bivariate Gaussian model?"). drmTMB has 25 exports
and zero matrix wrappers; its first article is `drmTMB.html`
(Get Started), then specific-task guides, then a workflow guide,
then references / boundaries.

### Proposed `gllvmTMB` reader path

```
1. README index page (the pkgdown front page)
   - One-paragraph opener defining "stacked-trait" by example
     (per D1 / D4 -- already proposed)
   - Three-bullet "What gllvmTMB distinguishes" (stacked-trait
     long format; one formula grammar; TMB engine)
   - One-screen "Start here" list with prompts (currently L35-48
     of README; refine wording)
   - One-screen "What can I model now?" (currently L128-155 of
     README, but buried; move up per D2)
   - "Install" + smoke test
   - Boundaries

2. First article: Get Started vignette (`vignettes/gllvmTMB.Rmd`)
   - The one CRAN-built vignette; deliberately the shortest path
     to a working fit.
   - Audience: someone who just installed the package and wants
     to fit ONE model.

3. Tier-1 "model guide" articles (worked examples, in
   complexity order):
   - morphometrics (rung 0: one observational level, continuous)
   - joint-sdm (rung 1: binary multivariate)
   - behavioural-syndromes (rung 2: two observational levels)
   - phylogenetic-gllvm (rung 3: phylogenetic dependence)
   - functional-biogeography (rung 4: capstone, site x species
     x trait with optional phylogeny and space)

4. Tier-1 "concept" articles (read alongside the model guides):
   - choose-your-model (decision tree; fixes from PR #62 F1-F3
     before promoting)
   - covariance-correlation (covered by Codex PR #61 substantive
     fix; will need a Pat/Rose re-read after #61 lands)
   - pitfalls (common gotchas)

5. Tier-2 reference articles (lookup, not pedagogy):
   - api-keyword-grid (3 x 5 covariance grid)
   - response-families (the family map)
   - ordinal-probit (the family with the most subtle semantics)
   - (queued per PR #41) lambda-constraint, profile-likelihood-ci

6. Developer / contributor notes (out of navbar; for the
   contributor lane):
   - `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`
   - `docs/design/*` and `docs/dev-log/*`
```

Reading this top-to-bottom, Pat answers in order:
"what does the package do?" (1)
-> "can I get a fit running?" (2)
-> "is my problem covered?" (3 + 4)
-> "what should my formula look like?" (4 choose-your-model + 5 api-keyword-grid)
-> "what could go wrong?" (4 pitfalls)
-> "what's the technical detail?" (5 reference + 6 developer)

## Section H: articles to keep / rewrite / demote

Per-article verdict for the 11 articles on `origin/main`
(post-PR #51 Codex ordinal-probit + post-PR #53 Claude
phylogenetic-gllvm rewrite):

| Article | Tier | Verdict | Reason |
|---|---|---|---|
| `morphometrics.Rmd` | 1 | **keep**; light fix | rung-0 worked example; only friction is 5 dead-link references (Pat audit). |
| `joint-sdm.Rmd` | 1 | **keep**; light fix | rung-1 binary multivariate; uses canonical `level = "unit"`; only friction is 1 dead-link reference. |
| `behavioural-syndromes.Rmd` | 1 | **keep**; PR #55 fixed legacy aliases | rung-2 two-level. |
| `phylogenetic-gllvm.Rmd` | 1 | **keep**; PR #53 rewrote | rung-3 phylogenetic dependence; 4-component decomposition now canonical. |
| `functional-biogeography.Rmd` | 1 | **keep**; light fix | capstone rung-4/5; 3 dead-link references. |
| `choose-your-model.Rmd` | 1 | **rewrite** | Pat audit F1/F2/F3: wide-format framing missing; phylogeny advice undersells the 4-component decomposition; heuristic ladder figure cites nonexistent article. Highest-friction Tier-1 article. |
| `covariance-correlation.Rmd` | 1 | **rewrite** | Codex PR #61 lands the narrow correctness fix; a Pat/Rose pre-publish re-read after #61 lands. |
| `pitfalls.Rmd` | 1 | **keep**; light fix | only friction is 2 dead-link references. |
| `api-keyword-grid.Rmd` | 2 | **keep**; PR #55 fixed `+ S` -> `+ diag(s)` | reference. |
| `response-families.Rmd` | 2 | **keep** | reference; clean. |
| `ordinal-probit.Rmd` | 2 | **keep** | Codex's recent port (PR #51); clean. |

**Demote**: none. All 11 articles serve a distinct purpose and
keep their Tier assignment.

**Missing articles** (Pat audit broken-link findings) that need
decisions:

| Missing target | Recommended verdict |
|---|---|
| `corvidae-two-stage.html` | **demote to redirect**: `functional-biogeography.html` covers the two-stage workflow. Update articles referencing it. |
| `cross-package-validation.html` | **write later** (Phase 5 cross-package validation deliverable; not user-facing pedagogy). Remove from article see-also lists. |
| `lambda-constraint.html` | **write** (already on Codex Tier-2 queue per PR #41). |
| `profile-likelihood-ci.html` | **write** (already on Codex Tier-2 queue per PR #41). |
| `simulation-recovery.html` | **write later** (methods-paper-adjacent; defer to Phase 6). Remove from article see-also lists. |
| `spde-vs-glmmTMB.html` | **write later** (benchmark; may belong in methods paper). Remove from article see-also lists. |

## Section I: navbar / `_pkgdown.yml` structure

Current `_pkgdown.yml` structure (from a quick read of the file):
exists, defines reference index and articles index. Has not been
audited in detail for navbar structure.

**Proposed navbar structure** (mirroring drmTMB's clean pattern):

```yaml
navbar:
  structure:
    left:  [intro, models, articles, reference, news]
    right: [search, github]
  components:
    intro:
      text: Get started
      href: articles/gllvmTMB.html
    models:
      text: Model guides
      menu:
      - text: Morphometrics (continuous traits)
        href: articles/morphometrics.html
      - text: Joint SDM (binary)
        href: articles/joint-sdm.html
      - text: Behavioural syndromes (two-level)
        href: articles/behavioural-syndromes.html
      - text: Phylogenetic GLLVM
        href: articles/phylogenetic-gllvm.html
      - text: Functional biogeography (capstone)
        href: articles/functional-biogeography.html
    articles:
      text: Concepts and reference
      menu:
      - text: Choose your model
        href: articles/choose-your-model.html
      - text: Covariance and correlation
        href: articles/covariance-correlation.html
      - text: Common pitfalls
        href: articles/pitfalls.html
      - text: '---'
      - text: 'API reference'
      - text: API keyword grid
        href: articles/api-keyword-grid.html
      - text: Response families
        href: articles/response-families.html
      - text: Ordinal-probit
        href: articles/ordinal-probit.html
```

This splits the current flat "Articles" navbar entry into
**Model guides** (worked examples in complexity order) and
**Concepts and reference** (decision-tree + concept articles +
API reference). It separates "I want to fit X" from "I want to
look up Y".

**Not in this proposal**:

- Reference index (function-by-function) stays as pkgdown's
  default `articles/reference/`. No restructure.
- News / changelog stays as default pkgdown `news/`.
- Dev-log / design docs do NOT appear in the navbar
  (intentional: contributor lane, not user lane).

This navbar restructure is a `_pkgdown.yml` PR; coordination
handoff to Codex per the maintainer's "coordinate before
editing _pkgdown.yml" rule. Claude does not touch
`_pkgdown.yml` in this PR.

## Section J: first small PR to implement

Codex's item 5: pick the smallest, highest-leverage PR to
implement first.

**Recommendation: README opener + section reordering** (D1 +
D2 + D4 combined, one PR). Reasons:

- Smallest diff: one file (`README.md`), three sub-changes.
- Highest leverage: the README is the front-page Pat lands on
  (the maintainer's original flag). Every other consistency
  problem propagates from here.
- Self-contained: does not block any in-flight work
  (PR #61, #63, #64, #65 do not touch README structure
  beyond the small data-shape edit in #65).
- Mechanical: D1's opener wording is in this audit
  (Section D1); D2's section reorder is in this audit
  (Section D2); D4's "stacked-trait" definition is in
  Section D4.

**Out of scope for the first PR**:

- Article rewrites (choose-your-model, covariance-correlation)
  -- separate PRs after this one lands.
- Navbar restructure (`_pkgdown.yml`) -- separate Codex PR.
- Broken-link fixes -- mechanical follow-up PR after the
  per-link WRITE/REMOVE/DEFER decisions (Section H, maintainer
  rules).

**Owner**: Claude can do the README PR (single file, prose;
within Claude's lane). Coordination with Codex:

- Codex's PR #61 covers `covariance-correlation.Rmd` and the
  `extract_Sigma` advisory; does not touch README.
- Codex's covariance-correlation re-read (post-#61) and the
  navbar restructure are Codex's natural next bites.
- The 6 missing-article decisions (Section H) are scope
  decisions for the maintainer; mechanical follow-up either
  way.

## Section K: file-ownership coordination (Claude vs Codex)

Per Codex's coordination request 2026-05-13 ~04:45 MT, the
files that need explicit ownership before editing:

| File | Owner (this docs/navigation pass) |
|---|---|
| `vignettes/articles/covariance-correlation.Rmd` | **Codex** (PR #61 + post-#61 re-read) |
| `_pkgdown.yml` | **Codex** (navbar restructure) |
| `vignettes/articles/choose-your-model.Rmd` | open; either agent. Claude has the audit context (PR #62 F1/F2/F3). |
| Other Tier-1 article rewrites | open; one agent per article ideally |
| `README.md` | **Claude** (PR #60 removed legacy-repo pointer; PR #65 dropped wide-matrix code block; the D1+D2+D4 opener rewrite is next) |
| `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` | **Claude** (rule files; PR #59 added see-also doc 04; PR #65 added deprecation note) |
| `docs/dev-log/*` | each agent writes their own `after-task/*.md` |
| `docs/design/*` | open; coordinate per file |
| `inst/CITATION`, `inst/COPYRIGHTS` | open; mechanical edits |
| `R/*` | **Codex** by default; Claude only for rule-file-driven changes (e.g. PR #65 deprecation) |

If either agent needs to edit a "Codex"-owned file, leave a
coordination comment first. If either agent needs to edit a
"Claude"-owned file, same.

## Section L: cross-references

- PR #62 (merged): Pat applied-user audit
  (`docs/dev-log/shannon-audits/2026-05-13-pat-applied-user-audit.md`).
- PR #63 (CI): `Language: en-GB` + curated `inst/WORDLIST`
  (Phase 5 prep).
- PR #64 (this audit, in CI): Rose README + pkgdown front-page
  audit.
- PR #65 (CI): `gllvmTMB_wide()` soft-deprecation, single-entry
  cleanup.
- PR #61 (CI, Codex): `covariance-correlation.Rmd` substantive
  fix.

After all 5 PRs land, the article surface, the README, and the
single-entry-point story all converge.
