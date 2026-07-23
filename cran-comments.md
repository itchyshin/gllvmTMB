# cran-comments

> **DRAFT for the maintainer's final review — gllvmTMB 0.6.0.** First CRAN
> submission of `gllvmTMB`. This file is `.Rbuildignore`d, so it is not part of
> the built package. **Submission is Shinichi's act;** this draft states the
> honest check result and must be re-read before upload. It replaces a stale
> 0.5.0 draft that claimed "0 errors | 0 warnings | 0 notes" from a
> `--no-tests --no-build-vignettes` run — i.e. **not** the real CRAN lane. The
> honest result is **0 errors | 0 warnings | 1 NOTE** (the expected "New
> submission").

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

`gllvmTMB` is released as **experimental** (lifecycle: experimental). This is a
deliberate honesty label, not a defect report: the package is early, point
estimates are the supported inferential claim, and interval calibration is
established only for the Gaussian cases that cleared its coverage gate. The
label appears on the startup message, the README/pkgdown, and this DESCRIPTION.

## Test environments

* local: macOS (Apple silicon), R 4.6.0 (2026-04-24) — `R CMD check` on the
  built tarball with `--as-cran` and CRAN incoming feasibility enabled
* GitHub Actions three-OS matrix — ubuntu-latest, macos-latest, windows-latest,
  R release — full suite and vignettes (run 29969703136)
* GitHub Actions heavy regression suite — ubuntu-latest (run 29969704205)

## R CMD check results

`R CMD check --as-cran` on the built `gllvmTMB_0.6.0.tar.gz` tarball reports:

```
Status: 1 NOTE

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Shinichi Nakagawa <itchyshin@gmail.com>'
  New submission
```

**0 errors | 0 warnings | 1 NOTE.** The single NOTE is the standard "New
submission" and is expected for a first submission. The three-OS matrix returned
`Status: OK` on all three operating systems with zero errors, warnings, or notes
across the full test suite and vignette rebuild; the heavy regression suite
returned 0 failures.

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
