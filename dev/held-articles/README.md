# Held draft articles

Draft articles moved out of the pkgdown build path because they currently break
or dominate the site build. They are preserved here intact and are **not** part
of the R package or the rendered site.

## lambda-constraint.Rmd -- RESOLVED 2026-05-31 (split + restored)

Originally moved 2026-05-31: the pkgdown "Build site" step spent ~34 min
knitting this article and then failed pandoc conversion with `error 5` on the
very large rendered document, blocking the **entire** site deploy.

**Resolution.** The article was split into two knittable children and restored to
`vignettes/articles/` (both registered under the `internal` group in
`_pkgdown.yml`):

1. `lambda-constraint.Rmd` -- the confirmatory walkthrough (kept the original
   slug, so the inbound cross-links from psychometrics-irt, data-shape-flowchart,
   choose-your-model, animal-model, and gllvm-vocabulary resolve unchanged).
2. `lambda-constraint-suggest.Rmd` -- the `suggest_lambda_constraint()` fallback
   (the data-driven conventions and the non-PD vs PD identifiability lesson).

Two root causes were fixed:

- **Pandoc template failure.** The YAML title carried inline LaTeX
  (`$\boldsymbol{\Lambda}$`); the `{` broke pkgdown's HTML template compile
  ("unexpected `{`"). Both children now use a plain-text title (`Lambda`).
- **Cold-cache refit blow-up.** The dominant cost was the
  `varimax-confidence-eye` chunk, which profiled *every* free loading entry of a
  non-PD refit (~250 partial refits). In the suggest child it now profiles a
  restricted set of 4 representative entries at a coarse grid (20 refits) and
  inverts the curve inline, preserving the teaching point.

Per-child cold `pkgdown::build_article()` wall-times verified locally: confirmatory
~505 s (6 figures), suggest ~62 s. No OOM. The `lambda-constraint*` article
files themselves live under `vignettes/articles/`; only this note remains here
for that entry.

## random-slopes-nongaussian.Rmd -- RECOVERED 2026-08-16 (parked, NOT in the build)

**Provenance.** Deleted at commit `eacbd0f6` ("docs: finalize public article
estate for 0.5.0", 2026-07-12) as part of a 15-article pkgdown estate cut; not
carried into this `dev/held-articles/` directory at the time. Recovered
2026-08-16 via `git show eacbd0f6^:vignettes/articles/random-slopes-nongaussian.Rmd`
in response to the maintainer's standing 2026-08-01 directive ("at least one
random slope for each distribution"). A sibling slope/reaction-norm article was
searched for in the same deletion commit (`git show eacbd0f6 --stat`) and none
was found -- the only slope-shaped casualty of that commit is this file; the
"behavioural reaction-norm example fixture" the commit message also refreshes
is an existing `dev/examples/` script and RDS fixture, not a deleted article.

**Why parked, not restored to the build.** The article's capability and
evidence claims were written against an earlier state of the validation-debt
register and have NOT been re-audited against the current rows -- RE-14 (C1
runtime admission only, for lognormal/betabinomial/Student-t, not recovery),
PHY-16 (ordinal_probit `phylo_indep` slope: 3/6 converged vs `min_good = 4`,
recovery deliberately skipped), PHY-11 (binomial `phylo_indep` slope:
structural contract only), and CI-08/CI-10 (interval calibration open). A
first-pass audit (see
`docs/dev-log/2026-08-16-slope-article-reader-path-staging.md`) found the
article's "full grid ... is now validated" framing overclaims the `indep`
correlation mode for binomial and ordinal_probit (register says `partial`,
not validated), and one sentence describing a Poisson `spatial_indep`
validation cell (300 sites, PD Hessian, BLUP correlation above 0.8) has no
support in the cited test file, which only asserts structural wiring and says
in its own header that non-Gaussian recovery is "a follow-up."

**Unhide gate.** Do not move this file back into `vignettes/articles/` or
register it in `_pkgdown.yml` without a joint reader-path review with
Shinichi, using the staging checklist above as the starting point. That
review decides, per flagged claim: unhide as-is, unhide with the given
rewording, or keep parked.
