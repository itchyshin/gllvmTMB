# Public Surface Wave 1 Render Review

**Date:** 2026-05-24
**Branch:** `codex/autonomous-surface-wave1-2026-05-24`
**Issue ledger:** #230
**Roles:** Ada, Grace, Rose, Pat, Florence

## Scope

This review covers the first autonomous public-surface wave after the
transparent larger-logo deployment. It checks whether the roadmap and article
gate matrix now match the extractor/plot helper evidence already merged, and
whether the rendered public surface still builds cleanly.

This is not a final publication-grade figure review for the visible articles.
Wave 2 owns the article-by-article prose and figure closeout.

## Rendered Pages Checked

Local server:

```sh
python3 -m http.server 8767 --bind 127.0.0.1 --directory pkgdown-site
```

Screenshots inspected:

- `/tmp/gllvmTMB-wave1-home.png`
- `/tmp/gllvmTMB-wave1-roadmap.png`
- `/tmp/gllvmTMB-wave1-morphometrics.png`
- `/tmp/gllvmTMB-wave1-covariance.png`
- `/tmp/gllvmTMB-wave1-pitfalls.png`
- `/tmp/gllvmTMB-wave1-home-stacked.png`
- `/tmp/gllvmTMB-wave1-mobile-home-widthfix.png`

## Findings

- Desktop home, roadmap, morphometrics, covariance/correlation, and pitfalls
  render with the corrected transparent logo and no visible header collision.
- The roadmap page shows the updated public-surface statuses and the
  2026-05-24 surface-reconciliation checkpoint.
- The roadmap no longer says the first tidy table helper is pending. It now
  points to the covered extractor and plotting helper rows already present in
  the validation-debt register.
- The article gate matrix now names the helper rows used by the visible
  morphometrics and covariance/correlation pages, while keeping final
  figure/prose review pending.
- A narrow homepage screenshot exposed that the homepage summary tables can be
  awkward at phone widths. `pkgdown/extra.css` now stacks homepage tables and
  constrains the homepage main column under 576 px. The Chrome command-line
  screenshot behaves like a cropped narrow desktop viewport rather than a true
  device emulation, so the exact mobile visual should be rechecked with a
  proper browser/Playwright viewport in the next visual QA wave.

## Checks

- `Rscript --vanilla -e 'pkgdown::build_site(new_process = FALSE, install = FALSE)'`
  - Result: completed; sitrep showed URLs, favicons, Open Graph metadata,
    article metadata, and reference metadata ok.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Result: `No problems found.`
- `cmp -s pkgdown/extra.css pkgdown-site/extra.css; printf 'css cmp=%s\n' $?`
  - Result: `css cmp=0`.
- `rg -n "first tidy table helper still pending|Visible, under HTML review|Visible, wording review|visible, under HTML review|under wording review|functional but still basic" ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  - Result: no matches.

## Next Slice

Wave 2 should start with the visible article closeout pass:

1. morphometrics figure/prose closeout;
2. covariance/correlation figure/prose closeout;
3. pitfalls prose closeout;
4. response-families and keyword-grid consistency checks;
5. convergence-start-values diagnostic wording pass.
