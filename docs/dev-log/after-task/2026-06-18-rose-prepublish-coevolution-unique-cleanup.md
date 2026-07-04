# After-task report: Rose pre-publish audit for coevolution / unique cleanup

Date: 2026-06-18 22:10 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice ran the narrow Rose pre-publish gate over the public surface touched
by the coevolution model work and ordinary `unique()` deprecation cleanup. It
also fixed the coevolution-relevant reference-index gap by listing
`kernel_unique()`, `kernel_indep()`, and `kernel_dep()` beside
`kernel_latent()` in `_pkgdown.yml`.

Rose verdict: `WARN`.

The touched coevolution/unique public surface is clean, and the new
coevolution-relevant exports are indexed. The whole-package strict
export/reference parity check still reports broader release-hygiene debt
outside this slice, so the release gate remains open.

## Files touched

- `_pkgdown.yml`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-rose-prepublish-coevolution-unique-cleanup.md`

## Validation

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  passed with `No problems found.`
- Focused coevolution export parity returned
  `MISSING_COEVOLUTION_EXPORTS 0` for `kernel_unique`,
  `kernel_indep`, `kernel_dep`, `extract_coevolution_modules`, and
  `diagnose_kernel_separability`.
- Focused stale `latent()+unique()` headline scan over the touched public and
  test surface returned no hits.
- Preview-banner scan confirmed row IDs plus milestones remain present.
- `gllvmTMB_wide()` hits remain soft-deprecated/migration language, not primary
  new-user or removed-API claims.
- `meta_known_V()` hits remain deprecated-alias language, not primary syntax.
- Stale notation/default scan found no hits for profile-default,
  already-removed, primary-new-user API, unsupported-implemented, `diag(U)`,
  `U_phy`, `U_non`, `\bf S`, `S_B`, or `S_W`.
- `git diff --check` passed.

## Remaining debt

Strict whole-package export/reference parity still reports broader
release-hygiene gaps including deprecated aliases, family constructors, selected
S3 methods, and a few helpers. This report does not close that work.

## Not claimed

- No keyword removal.
- No source-specific or kernel latent-Psi fold beyond ordinary latent.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
