# After Task: Public loading-ridge study supplement

**Branch**: `docs/public-study-supplement-20261019`
**Date**: 2026-10-19
**Roles (engaged)**: Ada (scope and implementation boundary), Rose (independent artifact and public-surface review)

## 1. Goal

Let readers reach the loading-ridge study evidence from the diagnostics article without publishing the internal research folder that caused the pkgdown public-surface check to fail.

## 2. Implemented

The article links to a portable ZIP copied by pkgdown from `pkgdown/assets/`. The archive contains five unchanged aggregate CSVs, the unchanged fixed-truth generator, reader guidance, provenance pins and SHA-256 checksums. The results remain aggregate-only; the archive does not include raw fits, the compiled binary or the source tarball. The source public-surface checker was left unchanged; its existing fixture now accepts the public relative download link and rejects the former development-log URL.

No public R API, likelihood, formula grammar or family change; this is a documentation and download-surface edit. No design document, README, NEWS, ROADMAP, reference help, package API or pkgdown navigation change was required.

## 3a. Decisions and Rejected Alternatives

Keep the original study record intact and publish only the named scientific payloads. A checker exception or publishing the whole study folder would expose unrelated internal metadata. Preserve every CSV byte and the generator byte; add only the reader guide, provenance and checksum manifest. Pin the study source at `161abe09a417cad88b51c018a09a930d964ee3de`, the exported study record at `609fe5685c4825c26337d4392052b2fe0a4d29ff`, and retain the recorded R 4.6.1 / TMB 1.9.25 versions and source/binary hashes. These hashes document identity; their corresponding source tarball and binary are not included.

## 4. Files Touched

- `vignettes/articles/fit-diagnostics.Rmd`
- `pkgdown/assets/loading-ridge-study-2026-10-18.zip`
- `tools/test-check-pkgdown-public-surface.R`
- `docs/dev-log/check-log.d/2026-10-19-public-study-supplement.md`
- `docs/dev-log/after-task/2026-10-19-public-study-supplement.md`

The original `docs/dev-log/research/2026-10-18-loading-ridge-comparison/` contents, public-surface checker, package source and workflows remain unchanged.

## 5. Checks Run

`Rscript tools/test-check-pkgdown-public-surface.R` passed after confirming that the actual article names the relative ZIP and the asset exists; its synthetic positive download fixture passed and its negative old development-log link fixture was rejected by the unchanged checker. The ZIP audit passed exact member inventory, relative-path safety, all listed SHA-256 checks, equality of all six copied scientific payloads with their source bytes, provenance values, and absence of private paths or raw objects. The ZIP is 79,181 bytes with SHA-256 `a2d66869ba025ab8131830b2be1b88e0c7b8e6f12fc54392c22be7909670bffb`.

Calling pkgdown's installed `copy_asset_dir()` copied the ZIP to the site root with a matching digest. `pkgdown::check_pkgdown()` reported `No problems found`; existing Pandoc `--mathml` deprecation warnings appeared. `git diff --check` passed. Exact commands and scoped outcomes are in `docs/dev-log/check-log.d/2026-10-19-public-study-supplement.md`.

## 6. Tests of the Tests

The added positive fixture succeeds with `../loading-ridge-study-2026-10-18.zip`. The paired negative fixture uses the former GitHub development-log URL and asserts that the unchanged checker returns non-zero. This pins the failure boundary without relaxing the public-surface rule.

## 7. Roadmap Tick

N/A; this publication-surface repair changes no roadmap capability or status.

## 7a. Issue Ledger

Targeted open-issue searches for `pkgdown public surface`, `loading-ridge`, and `website refresh` found no issue about this failed site build or public supplement. No issue was commented on, closed, or created; no relevant open issue applies to this bounded publication repair.

## 8. Consistency Audit

`rg -n 'loading-ridge-comparison|loading-ridge-study-2026-10-18.zip|dev-log/research' vignettes/articles/fit-diagnostics.Rmd pkgdown/assets tools/test-check-pkgdown-public-surface.R` found the expected new ZIP reference and negative fixture; no article link to the internal record remains. Archive inventory and checksums confirmed no internal study metadata, private paths, raw fits or unlisted files were copied. No model result or aggregate CSV was edited.

## 9. What Did Not Go Smoothly

The previous site build rejected the article's link into `docs/dev-log/research/2026-10-18-loading-ridge-comparison`. The public-surface checker correctly treats development-log paths as internal; the resolution was to publish a purpose-built archive instead of broadening that rule. Local prose and package checks emitted the existing Pandoc `--mathml` deprecation warnings.

## 10. Known Residuals

The local package and asset-copy checks passed, but the site has not been rebuilt from merged `main` or checked live. The archive contains aggregate tables and a data generator, not raw fit objects or the materials needed to rerun the full fitting study. Root owns independent review, the commit/PR/main gate, and deployed-site verification.

## 11. Team Learning

Ada set the five-file boundary and required a portable artifact with exact provenance. Rose independently audited the ZIP hashes, safe paths, exact source bytes, scientific article wording and unchanged surface guard; the review passed. The requested reader descriptions and actual-article link/asset assertion were added and retested. The archive audit should stay coupled to the public-link fixture so later edits cannot silently add internal files or bypass the surface rule.

## 12. Cross-Product Coverage

Covers the published article download path, a filtered scientific-only archive, exact aggregate payload identity, provenance, and regression coverage for the public-surface boundary.

does NOT cover a full fitting rerun, raw model objects, a compiled binary, publication of internal research metadata, changes to the public-surface checker, model/API changes, a full local site build, merge, main-branch pkgdown execution, or live-site deployment verification.
