# Validation Row Explicit-Psi Wording Cleanup

Date: 2026-06-18 23:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Tighten the remaining validation-row prose so historical evidence rows keep
their exact compatibility formulas while the explanatory text no longer teaches
`latent+unique` or `unique()` as ordinary vocabulary.

## Files Touched

- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What Changed

- NEWS now says explicit-Psi compatibility partitioning examples and names
  FG-06 as the explicit-Psi compatibility pair.
- FG-06 and RE-09 row labels now name explicit-Psi compatibility.
- FAM-07 explanatory prose now says its matrix fixture covers ordinary latent,
  explicit compatibility diagonal, and the explicit-Psi compatibility pair.
- RE-09 explanatory prose now says unit_obs explicit-Psi compatibility pair and
  diagonal-plus-diagonal / single-OLRE prior coverage, while preserving the
  exact legacy formula that identifies the recovery cell.
- KER-02 now describes kernel equivalence coverage as bare latent, explicit-Psi
  compatibility pair, compatibility diagonal, `indep`, and `dep`.

## Checks

- Exact stale-phrase scans over `NEWS.md` and the validation-debt register
  returned no hits for the replaced shorthand.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Dashboard JSON validation and `git diff --check` passed.

## Still Not Claimed

- No behavior change.
- No keyword removal.
- No source-specific or `kernel_*()` latent-Psi fold.
- No bridge completion, release readiness, or scientific coverage completion.
