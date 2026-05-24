# Pitfalls Final Prose Review

**Date**: 2026-05-24
**Article**: `vignettes/articles/pitfalls.Rmd`
**Review lenses**: Ada, Pat, Rose, Grace
**Outcome**: PASS

## Scope

This review closes the public `pitfalls` article's final prose gate.
The article is a Tier-1 troubleshooting reference for applied users
who see a multivariate fit behaving unexpectedly and need to decide
whether the issue is data coding, estimand mismatch, formula mismatch,
identifiability, grouping, or matrix meaning.

No formula grammar, likelihood, exported function, generated Rd file,
NEWS entry, README section, or validation-debt status changed.

## Findings

Pat: the article now teaches the mistake class first. The opening says
each section states a general diagnostic principle and uses one
`gllvmTMB()` example only as an example. Sections 3, 5, and 7 were the
remaining places where the prose could read as a specific internal or
phylogenetic story; the final pass reframed them as general checks.

Rose: the scope-boundary block remains explicit. It cites the relevant
validation-debt rows (`FG-02`, `FG-03`, `FAM-01`, `FG-04`, `FG-05`,
`FG-06`, `EXT-01`, `EXT-14`, `EXT-15`, `LAM-04`, `PHY-02`, `PHY-03`,
`PHY-04`, `PHY-07`, `ANI-01`, `ANI-07`, `ANI-08`, `MET-01`,
`MET-03`) and does not advertise hidden articles as ready next steps.

Grace: the article renders locally through pkgdown. `pkgdown::check_pkgdown()`
returns no problems after rendering `articles/pitfalls` and `articles/roadmap`.

## Article-Tier Judgment

Keep `pitfalls` public as Tier 1. It answers a first-time user's
question: "What mistakes look like package bugs, and how do I fix
them?" The article uses short reproducible diagnostics rather than a
full worked biological example, but each section has a symptom,
diagnosis, runnable or inspectable example, and rule of thumb.

## What Changed In The Closeout Pass

- Section 3 no longer says the example was merely a real simulation
  harness bug. It now names the general failure mode: a fitted model
  can answer a different question from the data-generating story even
  when the optimizer behaved correctly.
- Section 5 now gives a general decomposition checklist before the
  phylogenetic example: name the covariance tier, decide whether the
  diagonal variance is identifiable, and use scalar shortcuts only when
  a shared variance is the estimand.
- Section 7 now starts by asking what the known matrix indexes and
  which variance term it represents before introducing the `A` versus
  `V` example.

## Residual Risk

The article intentionally uses long-format examples only and points to
Get Started for long/wide equivalence. Re-run this prose gate if the
article adds wide companion chunks, new capability claims, hidden-page
links, or additional covariance examples.
