# Audit: Pat applied-user pre-publish sweep (Tier-1 + Tier-2 articles)

**Trigger**: maintainer dispatched a Pat (applied-user) audit
2026-05-13 03:30 MT, pointing at the live pkgdown URL
<https://itchyshin.github.io/gllvmTMB/articles/choose-your-model.html>
as a starting point. Pat's lane is "would a new applied user be
able to follow this article on day 1, or would they hit
friction?"

**Audience**: maintainer for scope/sequencing decisions; Codex
for any article-rewrite implementation PRs.

**Method**: read each Tier-1 and Tier-2 article on `origin/main`
HEAD `18a54d6` (post-PR #58); cross-check inter-article links
against `vignettes/articles/` ; spot-check the canonical
recommendations against the implementations now on main
(post-PR #53 phylogenetic-gllvm rewrite, post-PR #39 sugar
pivot, post-PR #56 @examples audit refinement).

**Articles in scope** (11 total, 10 on main, 1 about to land):

- Tier-1 (8): morphometrics, phylogenetic-gllvm, joint-sdm,
  behavioural-syndromes, choose-your-model, covariance-correlation,
  functional-biogeography, pitfalls.
- Tier-2 (3): api-keyword-grid, response-families, ordinal-probit.

Codex is currently revising **covariance-correlation.Rmd** for
substantive mistakes (maintainer dispatch 2026-05-13 03:30 MT);
that article's content is not audited here pending Codex's PR.

## Headline finding: 6 broken inter-article links across 7 articles

`grep -rEoh '\]\(([a-z][a-z0-9-]+)\.html\)' vignettes/articles/`
shows 15 distinct inter-article link targets. 6 of them resolve
to articles that **do not exist** in `vignettes/articles/`:

| Missing target | Referenced from | Frequency |
|---|---|---|
| `corvidae-two-stage.html` | choose-your-model, functional-biogeography, morphometrics | 3 articles |
| `cross-package-validation.html` | joint-sdm, morphometrics | 2 articles |
| `lambda-constraint.html` | choose-your-model, covariance-correlation, morphometrics, pitfalls | 4 articles |
| `profile-likelihood-ci.html` | functional-biogeography | 1 article |
| `simulation-recovery.html` | choose-your-model, functional-biogeography, morphometrics, pitfalls | 4 articles |
| `spde-vs-glmmTMB.html` | choose-your-model, morphometrics | 2 articles |

Some of these are in the Tier-2 queue (per PR #41 dispatch);
others (`corvidae-two-stage`, `simulation-recovery`,
`cross-package-validation`, `spde-vs-glmmTMB`) are not.

Pat reads `choose-your-model.html`, clicks "see also: Simulation-
based recovery" or "see also: Two-stage workflow", and gets a 404.
This is friction the live pkgdown site exposes today.

### Fix shape options (per missing article, maintainer to choose)

1. **Write the missing article**. If the cross-references make the
   article a needed pedagogical bridge, it should be authored.
   Codex's Tier-2 queue (per PR #41) covers some of these:
   `profile-likelihood-ci` and `lambda-constraint` are already
   on that queue.
2. **Remove the broken reference**. If the cross-reference is
   aspirational rather than necessary, the link should be
   removed from each referring article.
3. **Replace with `(article in preparation)` note**. Keeps the
   topic visible to readers without claiming the article exists.

Without maintainer direction, this audit defers the per-link
choice. Concrete proposal at end of this doc.

## Choose-your-model.html (live pkgdown URL the maintainer flagged)

Beyond the broken-link issue above, three substantive friction
points:

### F1. Wide-format framing is missing

Section 1 ("What does each row represent?") opens:

> `gllvmTMB` is long-format: every fit takes a data frame in
> which each row is one (unit, trait) observation, with a
> `value` column for the response and a `trait` column naming
> which trait it is.

This is stale relative to the post-PR #39 surface. The package
accepts **three** data shapes:
- Long: `gllvmTMB(value ~ ..., data = df_long, unit = "...")`
- Wide data frame via `traits(...)` LHS marker:
  `gllvmTMB(traits(t1, t2, ...) ~ <compact RHS>, data = df_wide)`
- Wide matrix: `gllvmTMB_wide(Y, ...)`

A new applied user with wide data who lands on this article
sees "long-format only" and either pivots their data unnecessarily
or bounces to a different package. Pat's friction: 5-10 minutes
of unnecessary `tidyr::pivot_longer()` work that the package
would have done for them.

**Fix**: Section 1 should open with the two-shape framing (long
+ wide; `gllvmTMB_wide()` as a matrix shortcut) and pick one
canonical pattern for the rest of the article.

### F2. Phylogeny advice in Section 3 undersells the canonical decomposition

Section 3 ("Are rows phylogenetically related?") recommends
`phylo_scalar(species, vcv = Cphy)` (single shared phylogenetic
variance per trait) or `phylo_latent(species, d = K, ...)`
(reduced-rank). Section 6c then fits:

```r
fit_phy <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | site, d = 2) + unique(0 + trait | site) +
          phylo_scalar(species, vcv = Cphy),
  data = df_p
)
```

But PR #53 (`phylogenetic-gllvm` article rewrite) demonstrated
that the canonical paired decomposition is **four-component**:

```r
fit_phy <- gllvmTMB(
  value ~ 0 + trait +
          phylo_latent(species, d = K_phy, tree = tree) +
          phylo_unique(species, tree = tree) +
          latent(0 + trait | species, d = K_non) +
          unique(0 + trait | species),
  data = df, unit = "species"
)
```

And it's not just cosmetic — the four-component fit is what
makes `extract_communality()` and `extract_phylo_signal()` return
meaningful values (per the maintainer's "the decomposition of
phylogenetic heritability does not really make sense" framing
that motivated PR #53).

A new applied user follows section 3 + section 6c, fits the
three-component model, runs `extract_phylo_signal(fit)`, and
gets a degenerate two-way decomposition. Same recurring pattern
the check-log 2026-05-12 entry warned about.

**Fix**: Section 3 should recommend the four-component canonical
form (`phylo_latent + phylo_unique` on the phy side paired with
`latent + unique` on the non-phy side), with `phylo_scalar` as a
shortcut for the special case "one shared phy variance".

### F3. Ladder figure has heuristic recovery values + dead reference

Lines 79: `recovery_quality = c(0.98, 0.95, 0.85, 0.85, 0.92, 0.85)  # heuristic — bar height`

The figure's bar heights are admitted-heuristic and the
underlying study (`simulation-recovery.html`) does not exist.
A reader sees a polished bar chart, looks at the caption for
the methodology citation, and finds it points to a 404. Pat's
friction: trust in the figure drops because the methodology can
not be verified.

**Fix**: either ship `simulation-recovery.html` with real
numbers, or drop the figure / replace it with a non-quantitative
visual.

## Other articles: smaller friction points

### morphometrics.Rmd

Three of the 6 broken links are referenced here (`simulation-recovery`,
`corvidae-two-stage`, `cross-package-validation`,
`lambda-constraint`, `spde-vs-glmmTMB`). The article itself
follows the canonical long/wide three-shapes pattern post-PR #39,
so no F1-style friction. Phylogeny is out of scope for this
article (rung 0), so no F2-style friction either.

Pat friction: clicking "see also" leads to 404s.

### joint-sdm.Rmd

References `cross-package-validation.html` (does not exist).
Uses canonical extractors (`extract_correlations(fit_jsdm, tier = "unit")`
on line 284, `extract_ordination(fit_jsdm, level = "unit")` on
line 313). Long+wide pair shown. No F1 friction.

### functional-biogeography.Rmd

References 3 broken articles (`corvidae-two-stage`,
`profile-likelihood-ci`, `simulation-recovery`). Uses
"between-site" / "within-site" domain language (correct in
context). The four-component decomposition is mentioned implicitly
through M2 (controls for space and phylogeny); no F2-style
friction.

### behavioural-syndromes.Rmd

PR #55 (in flight) canonicalises 3 legacy `"B"` / `"W"` alias
call sites in this article (deprecation-warning silencing). No
additional Pat friction at the API-call surface.

### phylogenetic-gllvm.Rmd

Fixed in PR #53 (theory ↔ fit alignment, communality and
heritability sections added, indep / dep comparison
evaluated). No remaining Pat friction.

### pitfalls.Rmd

References 2 broken articles (`lambda-constraint`,
`simulation-recovery`). The pitfall walkthroughs themselves
are self-contained.

### covariance-correlation.Rmd

**Codex is doing a substantive revision** (maintainer dispatch
2026-05-13 03:30 MT). Audit deferred pending Codex's PR. PR #55
(Rose sweep) was reduced to drop this article from its scope to
avoid collision.

### api-keyword-grid.Rmd (Tier-2)

PR #55 fixes the `+ S` -> `+ diag(s)` cosmetic drift. Otherwise
the keyword-grid table reads cleanly. No additional Pat friction.

### response-families.Rmd (Tier-2)

Long+wide pair shown. `extract_correlations()` two-part-family
caveat present. No Pat friction at the API-call surface.

### ordinal-probit.Rmd (Tier-2)

Codex's recent port (PR #51 merged 19:35 MT 2026-05-12).
Long+wide pair shown; `tier: 2` frontmatter; no legacy alias
drift. No Pat friction.

## Recommended remediation (per finding)

In rough priority order:

1. **F1 (choose-your-model wide-format framing)**: small edit to
   Section 1; reframe to two-shape (long + wide) opener.
   Bundle with F2.
2. **F2 (choose-your-model phylogeny advice)**: rewrite Section
   3 to recommend the four-component canonical form. Update
   Section 6c example.
3. **F3 (choose-your-model ladder figure)**: either ship
   `simulation-recovery.html` with real numbers (Codex's lane)
   or drop the figure. Quick interim fix: change figure
   caption to say "illustrative ordering" and drop the
   "recovery quality (simulation-based)" y-axis label.
4. **Broken inter-article links**: 6 dead targets across 7
   articles. Per-target decision:
   - `lambda-constraint`: WRITE (Codex Tier-2 queue per PR #41)
   - `profile-likelihood-ci`: WRITE (Codex Tier-2 queue)
   - `simulation-recovery`: SCOPE DECISION (substantial new
     article; may want to defer until methods paper era)
   - `corvidae-two-stage`: SCOPE DECISION (two-stage workflow;
     may overlap with functional-biogeography's M1 / M2
     framing)
   - `cross-package-validation`: SCOPE DECISION (Phase 5 prep;
     could be a small audit doc rather than an article)
   - `spde-vs-glmmTMB`: SCOPE DECISION (benchmark; may belong
     in methods paper rather than as user-facing article)

Removing the references for "SCOPE DECISION" items is a
mechanical Claude-lane fix once the maintainer rules.

## Confidence level

High on F1 / F2 / broken-link counts (read directly from
articles). Medium on the per-target write-vs-remove decision
(needs maintainer judgement). Did not check rendered pkgdown
output (live HTML); only on-disk Rmd source.

## What this audit does not cover

- Codex's in-flight covariance-correlation.Rmd revision.
- Vignette runtime budget on CRAN's check machine (Phase 5
  pre-audit handles that).
- URL checks (PR #57 handled redirect canonicalisation; PR #60
  removed the legacy-repo 404).
- Spelling / WORDLIST (Phase 5 prep, dictionary scope decision
  per overnight report).
- Vignette / R code consistency for every chunk (focused on
  Pat-level framing and inter-article navigation).
