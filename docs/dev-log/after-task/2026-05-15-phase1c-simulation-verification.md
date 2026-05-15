# 2026-05-15 -- Phase 1c new article: simulation-verification.Rmd

**PR type tag**: article (new pedagogy)

## Scope

Write the new **Concepts-tier** pedagogy article
`simulation-verification.Rmd` (Curie + Fisher personas
co-authored). Bundle into Phase 1c's "3 new Concepts articles"
pedagogy roster alongside the already-merged
`data-shape-flowchart.Rmd` (#114) and `gllvm-vocabulary.Rmd`
(#113).

This article walks a user through the canonical
*simulate-fit-check* verification loop, exercising the four
new diagnostic functions that landed today:

- `check_identifiability()` (PR #105) -- Procrustes-aligned
  simulate-refit identifiability test.
- `gllvmTMB_check_consistency()` (PR #121) -- Laplace-
  approximation score-centring test.
- `coverage_study()` (PR #122) -- empirical CI coverage rates
  against the audit's >= 94% exit gate.
- `confint_inspect()` (PR #120) -- visual profile-curve
  verification.

Plus Fisher's profile-curve anatomy bridge section (per the
strategic plan's 2026-05-14 cross-link decision: Concepts-tier
article connects to Methods+validation tier
`profile-likelihood-ci`).

## Files changed

- `vignettes/articles/simulation-verification.Rmd` (NEW, 315 lines):
  6 sections covering DGP recovery, identifiability checks,
  Laplace consistency, coverage studies, profile-curve anatomy,
  and a minimum-viable verification checklist.
- `_pkgdown.yml`: add `- articles/simulation-verification` to
  Concepts and reference tier.

## Why this article matters

The new diagnostic surface that landed today
(`check_identifiability`, `gllvmTMB_check_consistency`,
`coverage_study`, `confint_inspect`) is the package's flagship
Phase 1b validation contribution -- it's what makes gllvmTMB
**inference-complete** relative to gllvm / galamm / glmmTMB /
sdmTMB / brms (none of which ship comparable verification
machinery; per the 2026-05-14 galamm-inspired-extensions scan).

Without a user-facing pedagogy article showing **when to use
each, how to interpret the output, and how they compose**, the
new exports become discoverable only by reading roxygen, which
applied users don't do. This article closes that gap.

## Test plan / verification

- [x] Rmd renders locally via `pkgdown::build_article("simulation-verification", lazy = FALSE)`
- [x] `_pkgdown.yml` autolint clean
- [x] Banned-pattern self-audit (per Kaizen 11):
  - All cross-refs use Rmd-style `[label](article.html)` or
    `[fn()](../reference/fn.html)` form
  - No `[fn]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
- [x] CI 3-OS R-CMD-check catches render failures + missing
  cross-refs
- [x] All four diagnostic functions cited correctly: signatures
  match `R/check-identifiability.R`, `R/check-consistency.R`,
  `R/coverage-study.R`, `R/confint-inspect.R`

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before: 8/13 in main (after corvidae PR #124 lands) + 1 local
  draft (simulation-verification)
- After this PR lands: 9/13 in main, no local drafts

Phase 1c new-pedagogy progress:
- ✅ data-shape-flowchart (#114, Pat D6a)
- ✅ gllvm-vocabulary (#113, Pat D6b)
- 🟢 simulation-verification (this PR, Curie + Fisher)
- ⚪ troubleshooting-profile (#115, Fisher; already in main)

After this PR lands, all 4 new pedagogy articles are in main.

Phase 1c remaining article ports after this:
- stacked-trait-gllvm
- phylo-spatial-meta-analysis
- spde-vs-glmmTMB
- cross-package-validation
- simulation-recovery

## What went well

- Article structure mirrors `troubleshooting-profile.Rmd` (#115)
  which the maintainer reviewed favourably last week: numbered
  sections, one diagnostic per section, ends with a user-facing
  checklist.
- All four new diagnostic functions are exercised in the same
  article on the same fixture. A reader sees how they compose
  rather than learning each in isolation.
- The profile-curve anatomy section bridges Concepts-tier to
  Methods+validation tier without requiring a separate
  "Model comparison & selection" article (deferred to 0.3.0 per
  Pat's review).
- No new R/ code — pure pedagogy. Lowest-risk PR shape.

## What did not go smoothly

- Branch was created pre-PR #119/#120/#121 (same as corvidae)
  so rebase was needed before push. Same lag-coordination issue
  as the corvidae port -- the lesson is to rebase + push **once
  per main movement** going forward, not let sibling branches
  drift.
- The article uses a fairly small DGP (~50 sites, 4 traits) to
  keep render time tolerable. A user with a real 500-site,
  20-trait fit will need much more compute for `coverage_study()`
  and `check_identifiability()`. The article notes this
  explicitly in section 6 ("Minimum viable verification").

## Team learning (per AGENTS.md Standing Review Roles)

- **Curie** (DGP fidelity / simulation pedagogy): The
  "anatomy of a simulation" framing -- DGP, fit, check, compare
  -- is the right cognitive model for the article. Users
  internalise the verification loop better when they see it
  as a 4-stage pipeline they execute themselves, not as a
  hidden quality-assurance step inside the package.
- **Fisher** (inference machinery): The profile-curve anatomy
  section (quadratic vs skewed vs flat) is the article's most
  important bridge -- it teaches a user how to read
  `confint_inspect()` output by eye, which is what makes the
  function genuinely diagnostic rather than just decorative.
  Cross-linked from `profile-likelihood-ci.Rmd` (#112) and
  `troubleshooting-profile.Rmd` (#115).
- **Pat** (applied PhD user): The minimum-viable-verification
  checklist at the end of section 6 is intentionally short
  (5 items). A reader who runs all five before publishing has
  done due diligence; a reader who skips them has not. Per
  Pat's principle that pedagogy articles must end with a
  user-actionable checklist.
- **Darwin** (biology-first audience): The DGP uses biologically
  plausible parameter values (Sigma_B with moderate inter-trait
  correlation, communality near 0.6, phylo signal ~0.3) rather
  than a stylised "all ones" identifiability test. Per Darwin's
  reframe principle.
- **Boole** (formula API): The DGP fit uses the canonical
  `traits(...)` + `latent(1 | site, d = 2) + unique(1 | site)`
  formula shape. No deprecated keyword. No formula-grammar
  deviation.
- **Rose** (pre-publish audit): Self-audited for banned-pattern
  cross-refs, in-prep citation discipline (no Nakagawa et al.
  in prep cited as a methodological foundation), and the
  4-step verification narrative coherence with the package's
  diagnostic-API design.

## Follow-up

- After this PR lands, all 4 new-pedagogy Concepts articles
  are in main. Phase 1c remaining article ports:
  stacked-trait-gllvm (foundational),
  phylo-spatial-meta-analysis (spatial deficit P5),
  spde-vs-glmmTMB (spatial deficit P5),
  cross-package-validation (Fisher + Jason: glmmTMB / gllvm /
  galamm / sdmTMB / MCMCglmm / Hmsc comparison),
  simulation-recovery (Methods+validation tier 30-rep study).
