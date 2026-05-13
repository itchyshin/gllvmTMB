# After-Task: Remove misleading "When unique() is not the right term" section in covariance-correlation.Rmd

## Goal

Maintainer flagged 2026-05-13 ~10:55 MT on the live pkgdown page
<https://itchyshin.github.io/gllvmTMB/articles/covariance-correlation.html>:
the section "When `unique()` is not the right term" with its
"Phylogenetic tiers" subsection is misleading. The header
implies `unique()` is wrong for phylogenetic data, but per the
canonical paired 4-component decomposition (PR #53), `unique()`
IS the right term -- it pairs with `phylo_latent + phylo_unique
+ latent` as the non-phy companion. Phylo HAS a unique term
(`phylo_unique`); the section's framing contradicts the
canonical recommendation.

Maintainer's broader point (2026-05-13 ~11:00 MT): "you always
need to think - you cannot just use the old stuff - things do
change and this is why we are rebuilding gllvmTMB". The
covariance-correlation article inherited this section from
pre-PR-#53 framing; PR #69 (Codex's post-#61 re-read) carried it
forward; my spot-check on PR #69 didn't read each subsection's
logic against the new canonical model.

After-task report at branch start per `CONTRIBUTING.md`.

## Process lesson (codify this)

When a Tier-1 article inherits prose from pre-rebuild content,
spot-checks for surface drift (S/s notation, legacy aliases,
single-entry point) are NOT enough. Every section header and
every prescriptive claim must be re-read against the current
canonical model. This is exactly the recurring "theory/fit
gap" pattern the check-log 2026-05-12 entry warned about,
applied at the article-section level.

Will add to the check-log on the next coordination cycle.

## Implemented

- **`vignettes/articles/covariance-correlation.Rmd`** (M, ~50 lines net):
  - **Removed** the section header `## When unique() is not the
    right term` and its three subsections:
    - `### 1. Binary responses (binomial family)` -- promoted to
      a top-level section `## Binomial responses: the link's
      implicit residual` since the binomial-link-residual content
      is real pedagogy worth keeping.
    - `### 2. Phylogenetic tiers` -- removed entirely. The
      content was technically correct (phy uses `phylo_unique`
      as its diagonal companion; ordinary `unique()` is the
      non-phy diagonal companion), but the framing under "when
      `unique()` is not the right term" contradicted PR #53's
      canonical 4-component paired decomposition. The
      pedagogical content is covered in detail in the
      [Phylogenetic GLLVM article](phylogenetic-gllvm.html);
      replaced with a one-paragraph pointer.
    - `### 3. Confirmatory factor models` -- removed entirely.
      The claim "if domain knowledge tells you S = 0, then
      latent-only is the correct specification" contradicts the
      package's canonical recommendation: always fit paired
      `latent() + unique()` unless data force otherwise. The
      rare "S = 0" case can be handled via
      `suggest_lambda_constraint()` and the lambda-constraint
      article (when Codex's Tier-2 lane lands it).
  - The downstream section `## Two-level (between + within)
    models: two unique() terms` (the canonical recommendation)
    is unchanged. The upstream reference "see the recommended
    **two-`unique()`** pattern below" still resolves to the
    same target.
- **`docs/dev-log/after-task/2026-05-13-cov-corr-remove-misleading-unique-section.md`**
  (new, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, or pkgdown navigation change. Single article
prose change: removed 67 lines (three subsections), added 26
lines (one consolidated binomial section + one paragraph
pointer).

The retained binomial section preserves the technical claim:

```text
P(y_it = 1 | latent) = inv_link(...)
latent-scale variance = (LL^T)_tt + implicit residual
                      = (LL^T)_tt + pi^2/3   (logit)
                      = (LL^T)_tt + 1         (probit)
                      = (LL^T)_tt + pi^2/6   (cloglog)
```

For non-binomial families the canonical paired
`latent() + unique()` decomposition (and the four-component
extension for phylogenetic models) is the recommendation, per
the rebuilt-from-scratch gllvmTMB canon.

## Files Changed

- `vignettes/articles/covariance-correlation.Rmd` (M, -67 / +26 lines)
- `docs/dev-log/after-task/2026-05-13-cov-corr-remove-misleading-unique-section.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open Claude PRs (#74 article cleanup,
  #75 choose-your-model rewrite). Neither touches
  `covariance-correlation.Rmd`. Codex paused (per PR #70).
  Safe.
- `pkgdown::build_article("articles/covariance-correlation",
  new_process = FALSE)`: rendered cleanly.
- Cross-doc consistency: the removed phylogenetic-tier
  paragraph's content is covered in the
  [Phylogenetic GLLVM article](phylogenetic-gllvm.html)
  (PR #53 rewrite + PR #69 post-#61 re-read). The replacement
  pointer says so.

## Tests Of The Tests

The "test" is whether the article's recommendations align with
the rebuilt-from-scratch canonical model:

1. Read each `##` and `###` header. Does any contradict the
   "always pair `latent() + unique()`" / "paired four-component
   phylogenetic decomposition" canonical line?
2. After this PR, the answer is "no" -- the article now opens
   with the canonical `latent + unique` recommendation in the
   communality section, presents the binomial special case as
   its own labelled exception, and points readers at the
   phylogenetic article for the paired-decomposition case.
3. The "two-`unique()` pattern" section title is no longer
   contradicted by an upstream "when unique() is not the right
   term" header.

## Consistency Audit

```sh
rg -ne 'When .*unique.*not the right term' vignettes/articles/
```

verdict: zero hits.

```sh
rg -ne 'phylo_unique.*not the ordinary.*unique' vignettes/articles/
```

verdict: zero hits. The misleading phylo vs unique framing is
gone.

```sh
rg -ne 'S = 0|latent-only is the correct' vignettes/articles/
```

verdict: zero hits. The contradictory "latent-only is correct
when S = 0" claim is gone.

```sh
rg -ne 'two-`unique\(\)`|two `unique\(\)`' vignettes/articles/covariance-correlation.Rmd
```

verdict: 2 hits, both pointing at the same downstream section
"Two-level (between + within) models: two `unique()` terms"
which is the canonical recommendation.

## What Did Not Go Smoothly

This whole edit is what didn't go smoothly upstream.

The misleading section originated in pre-rebuild content. It
survived:

1. The original article authoring (before PR #53).
2. PR #61 (Codex's narrow correctness fix).
3. PR #69 (Codex's post-#61 Pat/Rose re-read).
4. My spot-check on PR #69 -- I scanned for surface drift
   (S/s notation, legacy aliases, `gllvmTMB_wide` calls,
   `traits()` sugar usage) but did NOT read each subsection's
   logic against PR #53's canonical model.
5. PR #74's broken-link sweep -- I deliberately deferred
   `covariance-correlation.Rmd` because Codex had owned it.

Process failure: spot-checking for SURFACE drift is not
enough. Each prescriptive claim in an article must be
re-read against the current canonical model. The maintainer's
2026-05-13 ~11:00 MT reminder ("you always need to think -
you cannot just use the old stuff - things do change and
this is why we are rebuilding gllvmTMB") names this exactly.

Adding to my own Rose-style audit checklist:
- For every `##` or `###` section header, ask "does the title
  imply a claim that contradicts the canonical model?"
- For every "When X is not Y" framing, verify that the
  contrast is genuinely a contrast (not an alternative
  formulation of Y).
- For every "if S = 0" / "in special case Z" framing, verify
  the special case is still considered special in the
  current canon.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- a Pat reader hitting this section
  would conclude `unique()` is generally wrong for phy data,
  contradicting the `phylogenetic-gllvm` article's
  recommendation. After this PR, the front article speaks the
  same canonical line.
- **Rose (cross-file consistency)** -- this is the Rose lane:
  one article's section header contradicting another's
  canonical recommendation. The cross-doc consistency check
  should have flagged it; my Rose audit (PR #64) covered
  README and the cross-doc opener inventory but did not read
  every article's section structure against PR #53.
- **Noether (math consistency)** -- the math content in the
  removed phylogenetic-tier subsection was actually correct
  (the `Sigma_phy = Lambda_phy Lambda_phy^T + S_phy`
  decomposition is real). The issue was framing, not math.
  Math content covered in the phylogenetic article.
- **Ada (orchestrator)** -- bounded fix in one article;
  surface-spot-check process is now updated to read for
  framing drift, not just notation drift.

## Known Limitations

- This PR is a deletion + small consolidation. If a future
  reader of the rebuilt article wants the binomial detail or
  the phylogenetic detail in one place, they can click the
  pointer to the phylogenetic article. The covariance-
  correlation article is now leaner.
- The "Confirmatory factor models" subsection's removal
  drops the discussion of `S = 0` as a valid model. If
  domain knowledge ever supports `S = 0` (e.g. tightly
  controlled experimental traits), the user can still
  set `lambda_constraint` to constrain the unique-variance
  estimates to be small or zero. The article doesn't need
  to advertise this as a regular pattern.
- I am leaving choose-your-model.Rmd (currently in PR #75)
  untouched here, even though it also discusses `unique()`
  patterns. PR #75 already aligns with PR #53; I will
  spot-check it after that PR lands.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible:
   single-article prose deletion, no source / API / NAMESPACE
   change.
2. After merge, the live covariance-correlation article no
   longer carries the misleading "when `unique()` is not the
   right term" framing.
3. Codify the framing-drift audit checklist into the next
   `docs/dev-log/check-log.md` entry on the next coordination
   cycle.
