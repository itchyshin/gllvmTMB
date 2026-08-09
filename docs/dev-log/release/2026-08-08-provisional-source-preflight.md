# Provisional source-tarball preflight

Date: 2026-08-08  
Rung: diagnostic only; **not** the exact 0.7.0 candidate  
Platform: macOS Tahoe 26.6, R 4.6.0, Apple Silicon

## Result

The third source build and `R CMD check --as-cran` completed with:

```text
Status: 1 NOTE
```

There were zero errors and zero warnings. Installation, code checks, Rd,
examples, `--run-donttest` examples, installed tests, vignettes, vignette
rebuild, PDF manual, and HTML manual passed. The single incoming-feasibility
NOTE records both the expected `New submission` status and one invalid URL:

```text
https://itchyshin.github.io/gllvmTMB/articles/current-limits.html
```

That page is deliberately present in the source and pkgdown navigation but is
not yet deployed from `main`. It must return 200 before the exact-candidate URL
gate; the link is not removed to conceal the release boundary.

## Artifact identity

- Path: `/tmp/gllvmtmb-cran-preflight3.PfO019/gllvmTMB_0.6.0.tar.gz`
- SHA-256: `e096f07e05cf79a8151da728dfec2afa75c9ebcc756a08d39e071666144f85f3`
- Size: 3,780,031 bytes
- Entries: 696
- Check log:
  `/tmp/gllvmtmb-cran-preflight3.PfO019/gllvmTMB.Rcheck/00check.log`

The inventory contains no `inst/sim`, dev-log, ROADMAP/AGENTS/CLAUDE, CSL or
BibTeX input, m3 campaign files, generated root-vignette PNGs, or compiled
objects. The lifecycle SVGs and package logo remain intentionally shipped.

## Defects found and repaired during the preflight ladder

1. The always-on release-core sentinel sourced its schema from build-excluded
   `inst/sim`. A shipped pure test helper now mirrors the classifier, while a
   repository-only exhaustive sync test proves agreement when the campaign
   source is present.
2. The loading-unpack contract read repository source paths unconditionally.
   Its mathematical and compiled checks remain always on; only the explicit
   source-provenance scan now skips when those repository-only files are absent.

Both focused files passed before the third build, and the installed source
suite then passed inside `R CMD check`.

## Boundary

This artifact is version 0.6.0 and was built from a dirty integration lane. It
is evidence that the current source can produce a mechanically clean tarball;
it is not submission evidence, does not authorize a version bump, and cannot be
reused after the optimizer repair, scientific adjudication, 0.7.0 identity
reconciliation, or any installed-byte change.
