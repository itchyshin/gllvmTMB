# After-task — fix failing pkgdown CI (reference-index gap)

**Date:** 2026-06-21 · **Author:** Claude (Ada) · **Branch:**
`claude/pkgdown-refindex-20260621` (PR # to follow) · **Scope:** docs-only — restore
the pkgdown site build by completing `_pkgdown.yml`'s reference index. No code /
NAMESPACE / man changes.

## Why this work exists

The pkgdown GitHub Actions workflow had failed on every recent run (6/6 red over
~a day) while R-CMD-check stayed green, so the docs site was not redeploying. Root
cause, from the failed build log (run 27904513029):

```
Error in build_reference_index():
! In _pkgdown.yml, 3 topics missing from index:
  "diagnose_kernel_separability", "extract_coevolution_modules", and "profile_cross_rho_ci".
```

Three functions were exported + documented by recently-merged coevolution PRs —
`extract_coevolution_modules` and `diagnose_kernel_separability` (#500),
`profile_cross_rho_ci` (#506) — but were never added to `_pkgdown.yml`'s reference
index. pkgdown hard-errors when an exported, documented topic is absent from the
index, and `build_reference_index()` runs early, so the failure killed the build
before any article rendered.

## Fix

Added the 3 topics to `_pkgdown.yml` next to their existing siblings:

- **"Relatedness and spatial helpers"** (with `make_cross_kernel`,
  `profile_cross_rho`): `profile_cross_rho_ci`, `diagnose_kernel_separability`.
- **"Report-ready extractors"** (with `extract_Gamma`,
  `predict_cross_covariance`): `extract_coevolution_modules`.

(Codex's dirty `codex/r-bridge-grouped-dispersion` branch already carries an
equivalent reference-index expansion; this applies the same fix minimally to
`origin/main` so the public site builds now rather than waiting on that branch.)

## Verification

- `pkgdown::check_pkgdown(".")` → **"✔ No problems found"** (runs the same
  `check_missing_topics` that was failing CI).
- Post-merge confirmation: the `workflow_run`-triggered pkgdown run on the merge
  commit should go green. If a deeper article-render error surfaces after the index
  passes, it is a separate follow-up — but pkgdown built fine before these exports
  landed, so the index gap is the expected sole cause.

## Notes

- Independent of the article content strategy. This unblocks the article/navigation
  reorganization, whose verification (rendered-HTML review, `check_pkgdown()`)
  requires a green pkgdown build.
- DoD items 2/3/4/6 (simulation recovery, roxygen, runnable example, likelihood
  review) are N/A — config-only docs fix.
