# Audit: Pat/Rose reference-index (pkgdown) sweep

**Trigger**: maintainer flagged 2026-05-13 ~08:15 MT (via the live
pkgdown URL <https://itchyshin.github.io/gllvmTMB/reference/index.html>)
four issues on the reference index:

1. `compare_indep_vs_two_U` description says "two-U
   decomposition" -- legacy U notation drift relative to PR #40
   (math should be `S` / `s`, function names stay as legacy
   labels).
2. `suggest_lambda_constraint()` and related functions (from the
   galamm tradition) are very useful -- can we revisit?
3. We did an item-response-theory article -- can we revisit; if
   IRT fits species distribution modelling, can we build on it?
4. Reference section needs cleaning up.

**Audience**: maintainer for scope decisions; Claude during the
Codex pause window (2026-05-13 -> ~2026-05-17) for any
implementation PRs in Claude's lane.

**Method**: read `_pkgdown.yml` reference structure, walk each
section, grep for the specific drift patterns the maintainer
flagged, and cross-reference with the existing R/ source and
articles.

## Section A: "two-U decomposition" wording drift

Per PR #40 (`docs/dev-log/decisions.md` 2026-05-12):

- **Function names** with `two_U` / `two-U` are OK as legacy
  task labels (matches existing `R/extract-two-U-cross-check.R`,
  `R/extract-two-U-via-PIC.R`, `tests/testthat/test-phylo-two-U-recovery.R`).
- **Public math and prose** use `S` (matrix) / `s` (vector) for
  the unique-variance diagonal. `Sigma = Lambda Lambda^T + diag(s)`.

The drift: 7 user-facing prose hits where "two-U decomposition"
appears as a NOUN PHRASE describing the decomposition itself
(not as a function-name reference). Locations:

| File | Line | Context | Fix |
|---|---|---|---|
| `R/extract-two-U-cross-check.R` | 316 | `\title{Canonical likelihood-based cross-check for the two-U decomposition}` | "for the paired phylogenetic decomposition" |
| `R/extract-two-U-cross-check.R` | 486 | `\title{Cheap diagonal cross-check for the two-U decomposition (large T)}` | "for the paired phylogenetic decomposition (diagonal-only, large T)" |
| `R/extract-two-U-via-PIC.R` | 304 | "the two-U decomposition:" (in a `@details` list) | "the paired phylogenetic decomposition:" |
| `R/brms-sugar.R` | 1012 | "paired with `phylo_unique()` for the two-U decomposition" | "paired with `phylo_unique()` for the canonical phylogenetic two-component decomposition (Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy))" |
| `R/brms-sugar.R` | 1206 | "rank-reduced two-U decomposition" | "rank-reduced paired phylogenetic decomposition" |
| `R/fit-multi.R` | 373 | error: `"Use [...] for the two-U decomposition. They cannot coexist."` | "for the paired phylogenetic decomposition (phylo_latent + phylo_unique)" |
| `R/fit-multi.R` | 408 | error: same wording | same fix |

Plus three Rd files autogen-aligned with R/ source:

- `man/compare_dep_vs_two_U.Rd:5` (autogen from R/extract-two-U-cross-check.R:316)
- `man/compare_indep_vs_two_U.Rd:5` (autogen from R/extract-two-U-cross-check.R:486)
- `man/extract_two_U_via_PIC.Rd:47` (autogen from R/extract-two-U-via-PIC.R:304)

`devtools::document()` regenerates these after the R/ roxygen
edits.

**Proposed canonical phrasing**: "the paired phylogenetic
decomposition" (covers `phylo_latent + phylo_unique` pair)
or "the canonical phylogenetic two-component decomposition" when
the rank-reduced + diagonal split needs to be explicit. NOT
"two-S decomposition" -- though technically correct under PR #40,
it reads as a direct rename and obscures the meaning. The
"paired phylogenetic" framing matches the post-PR #53
`phylogenetic-gllvm.Rmd` rewrite + the PR #69 covariance-
correlation re-read framing.

Functions and tests keep their `two_U` names. The legacy task
label is preserved per PR #40.

## Section B: reference index grouping issues

Current `_pkgdown.yml` reference structure (8 groups):

1. **Top-level entry points** -- `gllvmTMB`, `traits`,
   `gllvmTMB_wide`, `gllvmTMBcontrol`, `simulate_site_trait`.
2. **Covariance keywords** -- the 3 x 5 grid + `spde`,
   `spatial`, `meta_known_V`.
3. **Deprecated keyword aliases** -- `phylo`, `phylo_rr`, `gr`,
   `meta`, `block_V`.
4. **Response families** -- `has_keyword("families")` +
   `ordinal_probit`.
5. **Extractors** -- `extract_Sigma`, `extract_Omega`,
   `extract_communality`, ... `extract_cutpoints`.
6. **S3 methods on `gllvmTMB_multi` fits** -- includes
   `sanity_multi`.
7. **Diagnostics and loading-tools** -- `gllvmTMB_diagnose`,
   `rotate_loadings`, `compare_loadings`,
   `suggest_lambda_constraint`, `compare_dep_vs_two_U`,
   `compare_indep_vs_two_U`, `bootstrap_Sigma`,
   `tmbprofile_wrapper`.
8. **Spatial mesh helpers** -- `make_mesh`, `add_utm_columns`,
   `plot_anisotropy`.

### B1. `sanity_multi` is in "S3 methods" but is not an S3 method

Per the screenshot's rendered output, the section header reads
"S3 methods on `gllvmTMB_multi` fits". The first nine entries
(print / summary / print.summary / logLik / confint / tidy /
simulate / predict / plot) are S3 methods. The tenth,
`sanity_multi()`, is a regular function that takes a fit, not
an S3 method. It currently appears alongside the methods, which
reads as a grouping mistake.

**Fix**: move `sanity_multi` to the "Diagnostics and
loading-tools" group, where it already sits conceptually with
`gllvmTMB_diagnose`.

### B2. "Diagnostics and loading-tools" mixes two different concerns

The current group has 8 entries that belong to two sub-themes:

- **Diagnostics** (used to evaluate a fit): `gllvmTMB_diagnose`,
  `compare_dep_vs_two_U`, `compare_indep_vs_two_U`,
  `bootstrap_Sigma`, `tmbprofile_wrapper`.
- **Loading-tools** (used to extract or manipulate Lambda):
  `rotate_loadings`, `compare_loadings`,
  `suggest_lambda_constraint`.

The two sub-themes serve different reader questions:
"is my fit converged / identifiable / robust?" vs "what does
my Lambda look like and can I constrain it for a confirmatory
fit?".

**Fix proposal**: split into two reference groups:

```yaml
- title: Diagnostics
  desc: Evaluate a fitted gllvmTMB_multi model
  contents:
  - sanity_multi          # moved from S3 methods
  - gllvmTMB_diagnose
  - compare_dep_vs_two_U
  - compare_indep_vs_two_U
  - bootstrap_Sigma
  - tmbprofile_wrapper

- title: Loadings (Lambda) and confirmatory factor analysis
  desc: Extract, rotate, and constrain the loading matrix
  contents:
  - rotate_loadings
  - compare_loadings
  - suggest_lambda_constraint
```

The "Loadings" framing names the substantive task (CFA-style
confirmatory pinning) and matches the maintainer's note that
these galamm-derived helpers are "very useful" and could
support a more visible loading-constraint workflow.

### B3. `gllvmTMB_wide` still in "Top-level entry points"

PR #65 soft-deprecated `gllvmTMB_wide()`. Per the
post-deprecation reference-index convention (single canonical
entry point, legacy wrapper hidden), `gllvmTMB_wide` should
move out of "Top-level entry points" into either:

- A "Deprecated" group (parallel to "Deprecated keyword
  aliases"), OR
- Omitted from the reference index entirely (the function is
  callable via `?gllvmTMB_wide` but does not appear in the
  rendered reference index).

The function already has `@keywords internal` in its roxygen
(per PR #65), so a default `_pkgdown.yml` rebuild may already
hide it. Verify after the navbar / reference-index PR.

**Fix**: drop `gllvmTMB_wide` from `_pkgdown.yml` reference
contents (or move it to a "Legacy / deprecated" group with the
keyword aliases).

### B4. "Deprecated keyword aliases" section has stale entries

Entries: `phylo`, `phylo_rr`, `gr`, `meta`, `block_V`. The
maintainer or Codex can decide if any of these should be:

- Folded together with `gllvmTMB_wide` into a single
  "Legacy / deprecated" group, OR
- Verified that each is still soft-deprecated rather than
  hard-removed.

Not a Pat-level friction; flagged for review.

## Section C: galamm-derived loading-tools (the maintainer's question 2)

Three functions in this family, all in `R/rotate-loadings.R`
and `R/suggest-lambda-constraint.R`:

### C1. `rotate_loadings(fit, level, method = "varimax")`

Returns a rotated `Lambda` for a fitted `gllvmTMB_multi`.
Methods supported: `"varimax"`, `"promax"`, `"none"`. Per the
roxygen and the examples, this is the canonical "post-hoc
rotation for interpretability" tool.

Galamm-tradition: galamm and `psych::fa` both expose `rotate`
arguments; gllvmTMB's `rotate_loadings()` is the analogous
function for a fitted gllvmTMB object.

### C2. `compare_loadings(Lambda_a, Lambda_b)`

Procrustes alignment between two loading matrices. Useful for:
comparing a `gllvmTMB` fit's Lambda against a galamm or
`glmmTMB`-via-`ranef()` Lambda (the example in the roxygen
shows exactly this).

### C3. `suggest_lambda_constraint(fit_or_formula, ...)`

The most pedagogically useful of the three. Proposes a
`lambda_constraint` matrix from a fitted unconstrained
`gllvmTMB`, for refitting as a confirmatory factor analysis
(CFA). The maintainer notes this is "very useful" and could
underpin a dedicated CFA workflow.

### C4. Cross-references to articles

- `vignettes/articles/morphometrics.Rmd`: uses
  `extract_ordination` and mentions varimax rotation by name
  (L500 area per Pat audit). The morphometrics walkthrough is
  the natural home for showcasing `rotate_loadings()`.
- `vignettes/articles/joint-sdm.Rmd`: uses `extract_ordination`;
  could leverage `rotate_loadings()` for species-loading
  interpretation.
- **Lambda-constraint article** (per PR #41 Tier-2 queue:
  `lambda-constraint`): **missing**. This is one of the 6
  broken inter-article links the Pat audit (PR #62) flagged.
  The dedicated CFA article would showcase `suggest_lambda_constraint()`
  and `lambda_constraint = list(B = M)` together.
- **Psychometrics-IRT article** (per PR #41 Tier-2 queue:
  `psychometrics-irt`): **missing**. The maintainer's question
  3 directly: can we revisit this article. See Section D.

**Recommendation**: schedule `lambda-constraint.html` as a
high-priority Tier-2 article after the navbar PR + broken-link
cleanup. It is referenced from 4 other articles
(choose-your-model, covariance-correlation, morphometrics,
pitfalls) and would showcase the galamm-derived loading-tools
the maintainer flagged as "very useful".

## Section D: item-response-theory article + joint-SDM connection

### D1. IRT article status

Per PR #41 Tier-2 dispatch queue, `psychometrics-irt.Rmd` was
listed but **never ported**. Of the 10 Tier-2 articles on that
queue, 3 are done (`api-keyword-grid`, `response-families`,
`ordinal-probit`); 7 remain, including `psychometrics-irt`.

The legacy article (pre-bootstrap; in
`gllvmTMB-legacy/vignettes/articles/`) presumably exists and
needs porting / rewriting. (Audit defers checking the legacy
repo content because the maintainer's question is about
substance, not file existence.)

### D2. IRT for joint species distribution modelling

The mathematical bridge:

- **IRT (psychometrics)**: items i, persons j;
  `P(item_i correct | person_j) = inv_logit(theta_j - b_i)`
  where `theta_j` is the person's latent ability,
  `b_i` is the item difficulty.
- **Joint SDM (ecology)**: sites s, species k;
  `P(species_k present | site_s) = inv_logit(alpha_k + lambda_k z_s)`
  where `z_s` is the site's latent score, `lambda_k` is the
  species loading, `alpha_k` is the species intercept.

The structural isomorphism is direct: IRT's
`theta_j - b_i` model is exactly a one-factor binomial GLLVM
with item-specific intercepts and unit-loading constraint
(`lambda_i = 1` for all items, varying `b_i`). Multi-parameter
IRT (2PL, with discrimination `a_i`) maps to a one-factor
binomial GLLVM with free loadings. 3PL (with guessing) is
beyond the current family list.

**Article opportunity**: a single Tier-2 article that opens
with the IRT formulation (psychometrics audience), then
re-frames the same model as a joint-SDM (ecology audience),
showing that the formula

```r
gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1),
         family = binomial(),
         data = df)
```

fits both, depending on what `unit` and `trait` mean in the
domain. This article would:

- Live as one Tier-2 article (`psychometrics-irt.html`).
- Reference both `joint-sdm.html` (for the ecology audience)
  and the planned `lambda-constraint.html` (for the
  confirmatory-IRT case with fixed item loadings).
- Demonstrate `suggest_lambda_constraint()` for the 2PL ->
  Rasch (1PL) transition.

### D3. Cross-article opportunity: joint-SDM mentions IRT

The current `joint-sdm.Rmd` does not mention the IRT
isomorphism. A one-paragraph note ("the same fit reads as a
binary-IRT model if you swap 'site' and 'species' for 'person'
and 'item'") would tie the two audiences together. Maintainer's
call whether to add this now or wait for the dedicated IRT
article.

## Section E: summary of recommendations (priority order)

For Claude during the Codex pause window (2026-05-13 ->
~2026-05-17):

1. **Reference-index grouping fix** (Section B1, B2, B3) --
   `_pkgdown.yml` edit + a single `devtools::document()` rerun.
   Mechanical. Self-merge eligible. Bundle with the navbar
   restructure PR if both land together.
2. **Two-U description fix** (Section A) -- 7 R/ roxygen edits
   in 4 files + `devtools::document()` to regenerate 3 Rd
   files. Touches R/ source but only the roxygen prose. Single
   focused PR. Self-merge eligible.

For maintainer scope decisions:

3. **Lambda-constraint article** (Section C4) -- write a new
   Tier-2 article `lambda-constraint.html`. Resolves 4 broken
   inter-article links. Probably Codex's lane post-pause; can
   wait.
4. **IRT article + joint-SDM cross-ref** (Section D) --
   write `psychometrics-irt.html`; add a one-paragraph IRT
   note to `joint-sdm.Rmd`. Maintainer's call on scope.
   Probably Codex's lane post-pause.

## Section F: scope boundaries

- This audit reads the on-disk `_pkgdown.yml` + R/ source +
  rendered reference index (via the maintainer's screenshot).
- This audit does NOT propose changes to function signatures,
  family list, NAMESPACE, or any source code beyond roxygen
  prose.
- This audit does NOT propose article rewrites beyond the two
  new articles (`lambda-constraint`, `psychometrics-irt`)
  flagged for the Codex post-pause queue.
- Maintainer rules on whether Claude implements (1) and (2)
  during the pause window or defers to Codex.
