# After-Task: Article cleanup + long+wide pair sweep

## Goal

Two related sweeps in one PR:

1. **Broken-link cleanup** (per PR #62 Pat audit + PR #71 Section H
   verdicts): remove or redirect 4 broken-target links across 5
   articles. Maintainer ratified the per-link verdicts 2026-05-13
   ~08:45 MT.
2. **Long+wide pair sweep** (per maintainer 2026-05-13 ~09:10 MT
   reminder): articles missing the wide-form companion get one
   added or a clear pointer to the long/wide equivalence check.

Both sweeps land in one PR because they touch the same articles.

This is part of the Codex pause window queue (Codex paused
~May 13 -> ~May 17 per PR #70).

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

### Broken-link removals

Per the PR #71 Section H verdicts (maintainer ratified):

- **`corvidae-two-stage.html`** -> **redirect** to in-article
  reference (M2 of functional-biogeography) or remove pointer.
  Touched 2 of 3 referring articles:
  - `vignettes/articles/morphometrics.Rmd` (L532): table row
    "Two-stage workflow" -> point at
    [Behavioural syndromes](behavioural-syndromes.html) (the
    canonical two-level example in the package).
  - `vignettes/articles/functional-biogeography.Rmd` (L56 + L267 +
    L561): table row -> "Two-stage site-summary model (M2 in
    this article)"; inline `[two-stage workflow]` mention
    removed; see-also entry removed.
  - `vignettes/articles/choose-your-model.Rmd` (L110, L367):
    NOT touched in this PR; lands with the
    `choose-your-model` rewrite PR.
- **`cross-package-validation.html`** -> **remove**. Maintainer's
  verdict: Phase 5 deliverable, not user-facing pedagogy.
  Touched 2 articles:
  - `vignettes/articles/joint-sdm.Rmd` (L396): see-also entry
    removed.
  - `vignettes/articles/morphometrics.Rmd` (L543): see-also
    entry removed.
- **`simulation-recovery.html`** -> **remove**. Maintainer's
  verdict: methods-paper deliverable (Phase 6).
  Touched 4 articles:
  - `vignettes/articles/pitfalls.Rmd` (L111 + L239): inline
    mention pruned to plain prose; see-also entry removed.
  - `vignettes/articles/functional-biogeography.Rmd` (L569):
    see-also entry removed.
  - `vignettes/articles/morphometrics.Rmd` (L540): see-also
    entry removed.
  - `vignettes/articles/choose-your-model.Rmd` (L59, L372):
    NOT touched in this PR; lands with the
    `choose-your-model` rewrite PR.
- **`spde-vs-glmmTMB.html`** -> **remove**. Maintainer's
  verdict: methods-paper benchmark.
  Touched 1 article:
  - `vignettes/articles/morphometrics.Rmd` (L531): table row
    "SPDE benchmark" -> point at `spatial_*()` keywords with
    note "article in preparation".
  - `vignettes/articles/choose-your-model.Rmd` (L181, L301,
    L366): NOT touched in this PR; lands with the
    `choose-your-model` rewrite PR.

`lambda-constraint.html` and `profile-likelihood-ci.html` are
on Codex's Tier-2 queue (per PR #41) and stay as live link
targets to be filled when Codex returns.

### Long+wide pair sweep

Per the PR #62 Pat audit + maintainer 2026-05-13 ~09:10 MT
broader request:

- **`vignettes/gllvmTMB.Rmd`** (Get Started vignette, Tier-0):
  added "Same model, wide data frame" subsection. Pivots the
  long simulated data to wide with `reshape()`, fits via
  `traits(t1, t2, t3, t4, t5) ~ 1 + latent(1 | individual,
  d = 2) + unique(1 | individual)`, asserts
  `all.equal(logLik(fit_long), logLik(fit_wide))`. Local
  render verified `#> [1] TRUE` in the output.
- **`vignettes/articles/joint-sdm.Rmd`**: added a short
  "Long or wide data shape" subsection. Joint-SDM data is
  genuinely 3-way (site x species x trait), so the wide pivot
  is unusual; the note points readers at the Get Started
  vignette and `morphometrics` for the long/wide equivalence
  check on a simpler shape.
- **`vignettes/articles/pitfalls.Rmd`**: added a single
  top-of-article paragraph noting that every pitfall has an
  equivalent wide-data-frame form via `traits(...)`. Each
  pitfall keeps its long-form example for readability (a
  per-pitfall wide pair would balloon a six-pitfall article).
- **`vignettes/articles/functional-biogeography.Rmd`**: added
  a paragraph at the end of the ladder summary noting the
  long/wide equivalence with a pointer; the article's
  five-component fits keep their long form for readability.

Articles **not touched** in the long+wide sweep:

- `morphometrics`, `phylogenetic-gllvm`, `response-families`,
  `api-keyword-grid`: already have long+wide pairs (audit
  baseline).
- `behavioural-syndromes`, `covariance-correlation`,
  `ordinal-probit`: already have at least one long+wide pair
  per the audit's heuristic count; not flagged.
- `choose-your-model`: dedicated rewrite PR (next in the
  queue) handles F1 wide-format framing as part of its full
  F1+F2+F3 rewrite.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, or pkgdown navigation change. Five article /
vignette files updated.

## Files Changed

- `vignettes/gllvmTMB.Rmd` (M, +30 lines)
- `vignettes/articles/joint-sdm.Rmd` (M, broken-link + long-wide note)
- `vignettes/articles/pitfalls.Rmd` (M, broken-link + long-wide note)
- `vignettes/articles/functional-biogeography.Rmd` (M, broken-link + long-wide note)
- `vignettes/articles/morphometrics.Rmd` (M, broken-link cleanup)
- `docs/dev-log/after-task/2026-05-13-article-cleanup-long-wide-sweep.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: PR #72 (two-U prose fix) open; touches R/
  + man/, no collision with this PR. Codex paused (per PR #70).
- Broken-link verification:
  - `rg -nE 'corvidae-two-stage|cross-package-validation|simulation-recovery|spde-vs-glmmTMB' vignettes/articles/ vignettes/gllvmTMB.Rmd`
    after the edits: remaining hits only in `choose-your-model.Rmd`
    (not in scope of this PR; handled in the next rewrite PR).
- Article-render verification (local):
  - `pkgdown::build_article("articles/joint-sdm", new_process = FALSE)`: rendered cleanly.
  - `pkgdown::build_article("articles/pitfalls", new_process = FALSE)`: rendered cleanly.
  - `pkgdown::build_article("articles/functional-biogeography", new_process = FALSE)`: rendered cleanly.
  - `pkgdown::build_article("articles/morphometrics", new_process = FALSE)`: rendered cleanly.
  - `rmarkdown::render("vignettes/gllvmTMB.Rmd")`: rendered cleanly; long/wide equivalence check returns `#> [1] TRUE` in the output.
- Coordination board: Claude has the article cleanup lane
  active (per PR #70 reassignment during Codex pause).

## Tests Of The Tests

After this PR:

1. `rg -nE '<missing-link-target>.html' vignettes/articles/ vignettes/gllvmTMB.Rmd`
   for the 4 removed targets: zero hits outside
   `choose-your-model.Rmd`.
2. `pkgdown::build_articles()` builds every article without
   broken-link warnings.
3. The Get Started vignette's long/wide equivalence check
   outputs `[1] TRUE` deterministically.

If a future article adds a link to one of the 4 removed targets,
this audit's grep catches it.

## Consistency Audit

```sh
rg -nE 'corvidae-two-stage|cross-package-validation|simulation-recovery|spde-vs-glmmTMB' vignettes/articles/ vignettes/gllvmTMB.Rmd
```

verdict: remaining hits are confined to
`vignettes/articles/choose-your-model.Rmd` (6 hits). Those are
handled in the next PR (the `choose-your-model` rewrite, which
removes the broken-link references AND addresses the Pat audit
F1/F2/F3 findings).

```sh
rg -nE '^\s*(fit_wide|fit_jsdm_wide|fit_phylo_wide)\s*<-' vignettes/
```

verdict: confirmation that wide-form fit calls exist where
deliberately added (Get Started vignette).

```sh
rg -nE 'traits\(' vignettes/articles/joint-sdm.Rmd vignettes/articles/pitfalls.Rmd vignettes/articles/functional-biogeography.Rmd
```

verdict: each of the three articles now references `traits(...)`
explicitly in its long/wide note, even where the per-fit wide
form is deferred to a simpler article.

## What Did Not Go Smoothly

The original plan was to add a runnable wide-form fit pair to
`joint-sdm.Rmd`. After a first draft (with `reshape()` and a
`reformulate()`-style formula constructor), the fit failed at
the wide-pivot step because joint-SDM data is genuinely 3-way
(`site x species x trait`) and the natural wide pivot is over
the `trait` axis with `(site, species)` as ID columns -- which
collapses each (site, species) cell to T columns but leaves
multiple wide rows per site. The runnable example would have
needed a bigger restructure (dropping the `(site, species)`
factor and treating species directly as the response axis),
which is beyond the scope of a simple long+wide pair addition.

Resolution: replaced the runnable wide example with a clear
pointer note that the same model is fittable via `traits(...)`
on the right pivot, and points readers at the simpler
Get Started + `morphometrics` long/wide equivalence check.
The article's primary lesson (binary JSDM + Fisher-z
correlation Cis) is unaffected.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- the Get Started vignette is the
  first thing Pat reads. Adding the long/wide equivalence
  check there means Pat sees both shapes in the first
  session. The simpler shape (1 fit per observation, 1 column
  per trait) demos cleanly with `reshape()`.
- **Rose (cross-file consistency)** -- 4 broken-link targets
  cleaned out of 5 articles in one pass; the remaining
  references are confined to `choose-your-model` for the
  dedicated rewrite PR. No drift.
- **Shannon (coordination)** -- Codex paused (per PR #70);
  Claude has this lane reassigned per the board. The article
  cleanup is a Claude lane during the pause window.
- **Grace (release readiness)** -- the rendered pkgdown
  articles no longer have broken-link warnings on the
  affected pages. CRAN reviewer friction reduced.

## Known Limitations

- The `choose-your-model.Rmd` rewrite (next in the queue)
  will pick up the remaining 6 broken-link hits in that
  article + the F1+F2+F3 findings from the Pat audit.
- `joint-sdm.Rmd` does not have a runnable wide-form pair;
  the article uses the long form (which is the natural shape
  for 3-way site x species x trait data) and points readers
  at the simpler Get Started / morphometrics equivalence
  check. If a future "wide-form joint SDM" article is needed
  (e.g. for users with one row per site and species as
  columns), it would be a separate Codex-lane article.
- The Get Started vignette's wide pivot uses `reshape()` from
  base R. If `tidyr::pivot_wider()` is preferred for
  pedagogical reasons (matching modern R conventions), the
  wide example can be rewritten in a follow-up.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible:
   documentation prose updates, no source / API / NAMESPACE
   change.
2. Next Claude lane (per the Codex pause queue):
   `choose-your-model.Rmd` rewrite -- handles F1 (wide-
   format framing missing), F2 (phylogeny advice undersells
   the canonical 4-component decomposition), F3 (heuristic
   ladder figure cites nonexistent article) per PR #62 Pat
   audit + PR #64 Section J. Bundled with the remaining
   broken-link references in that article.
3. After `choose-your-model` lands, Codex's queued lanes
   wait for Codex's return (~May 17).
