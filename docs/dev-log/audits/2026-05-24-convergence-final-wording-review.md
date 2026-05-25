# Convergence / Start Values Final Wording Review

**Date**: 2026-05-24
**Article**: `vignettes/articles/convergence-start-values.Rmd`
**Review lenses**: Ada, Fisher, Rose, Grace
**Outcome**: PASS

## Scope

This review closes the public `convergence-start-values` article's
final wording gate. The article is a Tier-1 methods guide for applied
users who have a hard multivariate fit and need to decide what changed:
the optimizer, the Hessian, `sdreport()`, start stability, or the
uncertainty workflow.

No formula grammar, likelihood, exported function, generated Rd file,
NEWS entry, README section, `_pkgdown.yml`, or validation-debt status
changed.

## Findings

Fisher: the article now treats `pdHess = FALSE` as an inference and
identifiability warning, not automatic model failure. It preserves the
point-estimate-first hard-fit path while telling readers not to make
naive Wald claims from weak Hessian curvature.

Rose: bootstrap and profile language is bounded. Bootstrap is described
as refit-based uncertainty whose failure count must be reported; profile
likelihood is restricted to supported scalar targets with stable
profiles and is not presented as a substitute for every derived table
entry.

Rose: the scope boundary now cites the `extract_Sigma_table()` display
as `EXT-18`, matching the article gate matrix.

Grace: the article renders locally through pkgdown, and the roadmap page
reflects the updated status. `pkgdown::check_pkgdown()` returns no
problems after rendering `articles/convergence-start-values` and
`articles/roadmap`.

## What Changed In The Closeout Pass

- The scope boundary now says bootstrap/profile are follow-up paths with
  limits: bootstrap depends on successful refits, and profile intervals
  apply only to supported scalar targets with stable profiles.
- The lead `pdHess = FALSE` rule now says to route uncertainty to
  bootstrap or supported profile workflows and report failed refits or
  fallback methods honestly.
- The bootstrap section now says bootstrap is not a cure for an
  unstable fitted surface and that many failed refits are a diagnostic
  result.
- The profile section now says profile likelihood is not a general
  substitute for bootstrap across every derived table entry.

## Article-Tier Judgment

Keep `convergence-start-values` public as Tier 1. It answers a
first-time user's operational question: "What should I do when fitting
is hard?" The article gives a runnable fit, a fit-health table, start
strategy guidance, and a troubleshooting ladder.

## Residual Risk

The article remains a wording and workflow guide, not new validation
evidence. Re-run this gate if start-method defaults, profile target
coverage, bootstrap family coverage, or public diagnostic APIs change.
