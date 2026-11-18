# BBS plus GBIF empirical-case screening dossier

**Status:** private, metadata-only screening. No BBS or GBIF record has been
downloaded, queried, aggregated, mapped, fitted, or used to change a synthetic
DGP, threshold, transform, or admission outcome.

## Decision

BBS plus GBIF birds remains a potentially useful **descriptive global-analysis
context** for a future Paper 1 application. It is **not admitted as an
observation-law match** for the current three-visit PA-cloglog synthetic
estimand. The data system can support a route/stop-scale provenance and
observed-sampling-pattern dossier only after the separate empirical Gate A
passes. It cannot be silently substituted for the frozen repeated-PA branch.

## What the official metadata establishes

| Component | Official evidence | Consequence for a future descriptive dossier |
| --- | --- | --- |
| Structured source | BBS covers more than 700 bird taxa, with annual breeding-season surveys on thousands of roadside routes; routes contain 50 three-minute point-count stops and the 2018 release records dates, times, weather, observer, route information, start coordinates and quality indicators. [USGS data release](https://www.usgs.gov/data/north-american-breeding-bird-survey-dataset-1966-2018-version-20180) | A named BBS release could support survey-provenance tables and source-specific count summaries, subject to version, taxon, time, quality, scale, and licence receipt. |
| Repeat structure | A BBS route is sampled once per year. The 50 stops are spatial locations along the route, not repeated visits to one location within the same observation occasion. [USGS data release](https://www.usgs.gov/data/north-american-breeding-bird-survey-dataset-1966-2018-version-20180) | Neither route-year nor stop-year data automatically provide the three within-cell PA visits in the frozen model. Stops must not be relabelled as detection replicates. Multi-year rows would require a separately declared dynamic/temporal estimand. |
| Spatial coordinates | The 2018 data-release metadata names route-start coordinates; USGS additionally notes that precise stop locations are not typically recorded. [USGS release note](https://www.usgs.gov/software/north-american-breeding-bird-survey-bbs-uncertainty-simulation-code) | A route-start map cannot be presented as a map of exact stop-level survey support. A future analysis must declare its spatial unit and support/masking rule before extracting any covariate. |
| Opportunistic source | GBIF bulk occurrence downloads require a registered user, authenticated predicate request, asynchronous processing, a download key, and an eventual DOI/citation. [GBIF API-download guide](https://techdocs.gbif.org/en/data-use/api-downloads) | No GBIF file may be treated as a reproducible input without the predicate, key/DOI, dataset list, date, licence audit, taxonomic reconciliation and immutable raw receipt. |

## Admission consequences

1. **No observation-law equivalence.** BBS is a structured count programme, not
   the Paper 1 synthetic PA-cloglog design. Any BBS model would need a separately
   approved likelihood and estimand; the existing synthetic likelihood is not
   changed to accommodate it.
2. **No ecological or prediction map.** Until the synthetic spatial estimator
   earns its own numerical/recovery evidence and a later empirical
   observation/prediction gate passes, any permitted empirical figure is only
   an observed source-pattern, coverage, season, effort, taxonomy, or support
   diagnostic.
3. **No route-to-grid fiction.** The future dossier must show the route/stop
   support actually available and mask unsupported regions. It cannot infer
   cell-level sampling effort from route-start coordinates alone.
4. **No cross-paper use.** Paper 2 remains nonspatial and synthetic; this
   screening result cannot populate it, relax its STOP/HOLD, or be used as
   evidence about diagonal-Psi recovery.

## What an empirical Gate A must still lock

- exact BBS release/version and scope;
- GBIF query predicate, accepted download key/DOI, source datasets, licences
  and access date;
- focal taxon crosswalk and exclusion rules;
- common breeding-season window and temporal matching rule;
- declared spatial unit, CRS, aggregation, support and extrapolation mask;
- BBS quality/observer/weather rule and whether count rather than
  detection/non-detection is the response;
- source-specific covariates and the ecological-versus-sampling-bias
  confounding assessment;
- privacy/sensitive-species review; and
- a statement that the selected empirical model is a newly approved model or
  only a descriptive QA workflow.

## Screening conclusion

The BBS–GBIF pair is credible as a named, open **case-study lead**. It is not
a shortcut around the repeated-visit, spatial-identifiability, numerical
admission, or known-truth recovery gates. The next viable empirical action is
not a download: it is a maintainer-approved choice between (a) a
source-only/descriptive BBS–GBIF QA case at its honest route/stop scale, or
(b) screening a different open survey system whose event/revisit structure
actually matches the frozen observation law.
