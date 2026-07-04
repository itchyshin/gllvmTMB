# Behavioural Syndromes Rendered-Asset Review

Date: 2026-06-19 00:53 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice checked the generated `behavioural-syndromes` HTML and figure assets
after the Pat/Darwin cleanup. It is a partial rendered review, not a public
promotion.

## Evidence

- `pkgdown::build_article("articles/behavioural-syndromes", ...)` passed.
- The generated HTML contains the internal gate, diagnostic PASS rows, and the
  expected ordination/loading-recovery figure text.
- Stale text checks found no `Dingemanse et al. 2002`, `library(dplyr)`,
  `genuine behavioural syndrome`, or old Pat/Darwin-plus-Final blocker wording.
- All five rendered PNG assets exist with nonzero dimensions:
  `inspect-1.png`, `inspect-w-1.png`, `ord-1.png`, `recovery-1.png`, and
  `recovery-sigma-1.png`.
- Quick Look produced a top-page thumbnail showing readable nav, H1, internal
  gate, and opening biological prose.

## Blocker

The in-app browser was unavailable and local Playwright lacked its Chromium
binary, so a full browser scroll-through could not be completed. Public
promotion remains blocked on that browser review.

## Still Not Claimed

- No public article promotion.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
