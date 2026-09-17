# After Task: Temporal reader decision figure

## Goal

Give the standalone temporal AR1/OU article one compact, reader-first visual
and correct the teaching defects found by Pat, Darwin, Rose, Fisher, Florence,
and Tufte, without changing the model or reviving temporal source pairs.

## Implemented

- Added an executable two-panel figure: fixed illustrative AR1/OU correlation
  values and the data hierarchy from `series` to occasions, trait panels, and
  optional replicate panels.
- Clarified that a series is an animal, plot, or transect trajectory; `time`
  selects temporal states, while `unit` and `unit_obs` are ordinary grouping
  tiers.
- Changed teaching occasions to `1, 2, 4` so the AR1 example includes both odd
  and even lags; synchronised the OU lookup.
- Repaired the sign-orientation guidance by pairing scores and loadings from
  `extract_ordination()`, not a normalized score with raw temporal loadings.
- Corrected elapsed-time, automatic-model-search, and unsupported
  extractor-diagnostic wording.

## Mathematical Contract

No public R API, likelihood, formula grammar, response family, NAMESPACE,
generated Rd, or pkgdown-navigation change. The figure shows fixed illustrative
values only: AR1 \(K(t,s)=\phi^{|t-s|}\) with \(\phi=0.7\), and OU
\(K(t,s)=\exp(-\kappa|t-s|)\) with \(\kappa=-\log(0.7)\). It reports neither
fitted estimates nor uncertainty. The standalone temporal source remains
separate from the 5 x 3 stable-unit grid; temporal combinations with
phylogenetic, animal, spatial, or kernel sources remain refused.

## Files Changed

- `vignettes/articles/temporal-ar1.Rmd` — text, executable conceptual figure,
  and retained long/wide examples.
- `docs/dev-log/check-log.md` — evidence record.
- `docs/dev-log/after-task/2026-09-15-temporal-reader-visual.md` — this report.

No convention changed. `R/`, generated `man/`, `README.md`, `NEWS.md`,
`ROADMAP.md`, design documents, and `_pkgdown.yml` were deliberately unchanged.

## Checks Run

- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/temporal-ar1.Rmd", output_dir = "/private/tmp/gllvmTMB-temporal-final-verify", quiet = TRUE)'` — passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — passed: `No problems found.`
- `git diff --check` — passed.
- Florence/Tufte figure review — source-level PASS after darkening small orange
  text, adding direct time-scale labels, wrapping hierarchy labels, and
  shortening arrow endpoints.

## Tests Of The Tests

No package test was added because this is a prose-and-figure-only change. The
render executes all existing long and wide temporal examples and the new figure
chunk. It would catch an R API mismatch, formula failure, missing `ggplot2`, or
figure-construction error in the reader workflow.

## Consistency Audit

- `rg -n "temporal.*(phylo|animal|spatial|kernel)|(phylo|animal|spatial|kernel).*temporal" vignettes/articles/temporal-ar1.Rmd` — the only match is the final refusal boundary; no source-pair example or claim was added.
- `rg -n "recovery|coverage|calibration|interval|forecast|selection" vignettes/articles/temporal-ar1.Rmd` — all matches state bounded helper contracts or unavailable general inference; no recovery, coverage, calibration, or interval claim was added.
- `git diff --check` — no whitespace error.

**Astra/Rose/Fisher scope verdict: PASS.** The corrected post-fit guidance uses
paired sign-normalized scores and loadings. The article remains aligned with
`TEMP-06-01` (`partial`) and leaves `TEMP-06-02` through `TEMP-06-14`
(`blocked`) as developer history rather than public options.

## What Did Not Go Smoothly

The host Mac was locked, so browser screenshot inspection of the rendered local
HTML was unavailable. The article rendered successfully, and Florence/Tufte
performed a source-level visual review, but final pixel-level label clearance
and arrowhead visibility at displayed vignette width remain unverified.

## Team Learning

**Pat:** put the applied choice—scientific clock and data hierarchy—before
syntax, and show what a reader should inspect after fitting.

**Darwin:** define `series` as the real biological trajectory rather than an
internal data index.

**Rose and Fisher:** a teaching fixture must identify the stated parameter; all
even AR1 lags conceal the sign of persistence. Paired extractors must share the
same orientation convention.

**Florence and Tufte:** a conceptual figure needs the same accessibility
discipline as a results figure: direct time-scale labels, dark readable text,
and geometry that does not hide arrows behind labels.

## Known Limitations

This figure is a fixed conceptual illustration, not evidence about a fitted
data set. It does not broaden `TEMP-06-01`: general recovery, precision,
calibration, interval coverage, generic forecasts, automatic model search, and
temporal source pairs remain outside the illustrated route. Screenshot-level
inspection remains outstanding while the host is locked.

## Next Actions

**Roadmap tick:** N/A — no roadmap row changed.

**GitHub issue ledger:** no new issue. The earlier temporal tracker search
found no relevant open issue; #1280 concerns `*_slope()` to `*_coef()` and is
unrelated.

The owned documentation diff is ready for maintainer review. Do not infer a
merge, release, new package check, or new cross-platform claim from this work.
