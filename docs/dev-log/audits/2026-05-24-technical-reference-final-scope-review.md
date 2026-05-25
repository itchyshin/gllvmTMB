# Technical Reference Final Scope Review

**Date**: 2026-05-24
**Articles**:
`vignettes/articles/api-keyword-grid.Rmd`,
`vignettes/articles/response-families.Rmd`
**Review lenses**: Ada, Boole, Fisher, Rose, Grace
**Outcome**: PASS

## Scope

This review closes the visible Tier-2 technical references in the
reset article surface. These pages are lookup tables for users who
already know they need `gllvmTMB()` and want to choose a formula
keyword or response family. They are not worked examples and do not
restore hidden article pathways.

No formula grammar, likelihood, exported function, generated Rd file,
NEWS entry, README section, `_pkgdown.yml`, or validation-debt status
changed.

## Findings

Boole: `api-keyword-grid` now has an explicit scope boundary. The page
states what is IN, PARTIAL, and PLANNED or blocked with validation row
IDs, and it keeps the hidden phylogenetic, spatial, animal, and
meta-analysis worked examples hidden until their article-specific
return conditions pass.

Fisher: `response-families` now labels the quick-lookup rows with
covered, partial, or blocked interpretation status. Delta/hurdle rows
remain listed because `family_to_id()` maps the standard
`delta_lognormal()` and `delta_gamma()` forms, but the table names the
response-scale and mixed-family interpretation boundary under FAM-17
and MIX-10.

Rose: the exported-but-not-engine-mapped table now includes register
status for each constructor family group. This prevents exported helper
presence from reading as current multivariate-engine support.

Grace: the touched articles and roadmap wrapper render locally, and
`pkgdown::check_pkgdown()` reports no problems.

## Article-Tier Judgment

Keep both pages public as Tier 2 technical references:

- `api-keyword-grid` answers "Which formula keyword names which
  covariance mode and correlation row?"
- `response-families` answers "Which family can I fit, and what is
  its validation or interpretation status?"

Neither article is trying to teach a full analysis. The worked-example
gate remains on the hidden article rows in the article gate matrix.

## Evidence

- `api-keyword-grid` scope rows cite FG-01--FG-09, FG-12--FG-15,
  PHY-01--PHY-10, SPA-01--SPA-07, MET-01--MET-04, ANI-01--ANI-10,
  MIS-02, and MIS-11 where relevant.
- `response-families` scope rows cite FAM-01--FAM-19 and MIX-10 where
  relevant; its quick-lookup table names covered / partial / blocked
  boundaries directly.
- Hidden article `.html` link scan on the touched articles returned no
  output.
- Stale notation and deprecated keyword-alias scans returned no output
  on the touched article and ledger files.
- The broad stale phrase scan returned only expected false positives
  from the phrase "marginal-only diagonal" in `api-keyword-grid`.

## Residual Risk

This closeout checks wording, scope labels, rendered article pages, and
navigation discipline. It does not add new statistical validation. Re-run
this gate if `family_to_id()`, exported family constructors, covariance
keyword status, validation-debt row status, or hidden worked-example
routing changes.
