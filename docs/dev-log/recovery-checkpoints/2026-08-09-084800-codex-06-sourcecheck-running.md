# Recovery checkpoint — integrated 0.6 source check running

**Date:** 2026-08-09  
**Repository / lane:** `/private/tmp/gllvmtmb-cran-0.7-20260807`,
`cursor/cran-0.7-20260807`  
**HEAD:** `ae340bdd50c5eee5cbe0b093b5ebf14930bf855f`  
**PR:** [#951](https://github.com/itchyshin/gllvmTMB/pull/951), draft; its
Ubuntu release check is green.

## Purpose

After the NB2 confirmation HOLD was closed on its separate diagnostic branch,
start a fresh local source-clean measurement for the integrated 0.6 hardening
lane. This is not a release or a 0.7 identity action.

## Running command and state

```sh
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
R CMD build . --no-build-vignettes
R CMD check --as-cran --run-donttest \
  /private/tmp/gllvmtmb-06-sourcecheck.hc2B3f/gllvmTMB_0.6.0.tar.gz \
  --no-manual --output=/private/tmp/gllvmtmb-06-sourcecheck.hc2B3f
```

The check process remains live (parent R PID 86818 at checkpoint). It has passed
source/package metadata, installation, load/unload, C++ compilation, static R
checks, Rd checks, and examples. It is currently executing the installed
`testthat` suite under `NOT_CRAN=true`; do not restart it.

The intentionally diagnostic `--no-build-vignettes` build generated two
expected, non-source-clean warnings: no prebuilt vignette index and no
`inst/doc` copy of `vignettes/gllvmTMB.Rmd`. The incoming checker also correctly
reports the currently undeployed Current limitations URL as 404. This run cannot
be promoted to tarball-clean; after it finishes, rerun a normal `R CMD build .`
with vignettes, then assess the final check log separately.

## Completed diagnostic result

The diagnostic completed successfully at the installed-package test stage:

```text
* checking tests ... [13m/14m] OK
* DONE
Status: 2 WARNINGs, 1 NOTE
```

Those two warnings were intentionally induced by `--no-build-vignettes`; the
single NOTE included the still-undeployed current-limits URL. Neither is a
package-source defect.

## Normal-vignette artifact result

A separate normal source build created:

```text
/tmp/gllvmtmb-06-vignette-artifact.QFyQOK/gllvmTMB_0.6.0.tar.gz
SHA-256: 5a2008cc586f1c9c778ce6329687a1fee00587ccce7c521b05ffab6f027f6c9a
```

The archive includes `inst/doc/gllvmTMB.html`, `inst/doc/gllvmTMB.R`, and
`inst/doc/gllvmTMB.Rmd`. Its exact installed-package check passed tests,
installed-document checks, vignette checks, and vignette rebuilding:

```text
* checking tests ... [245s/264s] OK
* checking installed files from 'inst/doc' ... OK
* checking files in 'vignettes' ... OK
* checking package vignettes ... OK
* checking re-building of vignette outputs ... OK
* DONE
Status: 1 NOTE
```

The remaining NOTE is only the live `https://itchyshin.github.io/gllvmTMB/articles/current-limits.html`
404. The source page and its package links are correct, but the draft PR has
not been merged and pkgdown has not deployed it. This is an external
deployment prerequisite for a future artifact-clean claim, not permission to
merge, publish, change the version, or submit to CRAN.

## Current evidence and next action

- Live issue #345 and the branch ledger retain 0.6.0 and explicitly prohibit a
  version change, publication, GitHub release, CRAN upload, or submission.
- PR #951 is merge-clean but draft. Do not merge without Shinichi's explicit
  instruction; merge is required before the current-limits URL can become an
  online-0.6 evidence surface.
- The local normal-vignette tarball is mechanically clean except for the
  undeployed page URL. Do not conceal that URL or downgrade the reader path to
  make a transient pre-merge check look cleaner.
- Before a future 0.7 exact-artifact claim, the limits page must be deployed
  from an authorized merge and the check repeated against the future frozen
  0.7 source; this 0.6 artifact is evidence for hardening only.
