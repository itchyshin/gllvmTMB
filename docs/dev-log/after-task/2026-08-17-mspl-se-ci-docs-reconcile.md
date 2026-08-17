# After-task — MSPL triad KF2021 footnote + #1077 wording

**Date:** 2026-08-17
**Lane:** `cursor/mspl-se-ci-docs-reconcile` (docs) + wording-only on draft `#1077`
**Tip:** `origin/main` `a555e921`
**Scope:** OWED (b) `#1077` stale bounds wording + (d) `#1075` MSPL/KF2021 footnote only.

## Goal

- Add MSPL footnote to triad “profile = signature” (D-12 stands; profiling does **not** rescue coverage under a finiteness penalty; KF2021 VERIFIED; binomial-only).
- Reconcile `#1077` wording: binomial bounds *are* computable on main via `#1090`; this scaffold still leaves `profile$status = "not_constructed"` (no calibrated/public CI). Stay draft.
- Align triad Poisson line to **SIGNED — REPLACE** (Shinichi *"as you recommended"*). Prior PARK wording in this PR is **superseded**; card + Codex baton land on `cursor/mspl-poisson-W-REPLACE-signed`.

## Explicitly not in this PR

- No `src/` tape edit. REPLACE signature / Codex handover are on the REPLACE-signed PR (not inventing KEEP; PARK superseded).
- No rebuild of profile probe; no public `se`/`confint`; no Lane B absorb.

## Mathematical contract

No public API / likelihood / formula-grammar / family change.

## Files

### Docs PR

- `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md`
- `docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md` (footnote cross-ref → landed)
- `docs/dev-log/after-task/2026-08-17-mspl-se-ci-docs-reconcile.md` (this file)
- `docs/dev-log/check-log.md`

### Draft `#1077` (existing PR; wording only)

- `R/mspl-profile-ci-stub.R`
- `docs/dev-log/research/2026-08-17-mspl-profile-ci-scaffold.md`
- `docs/dev-log/after-task/2026-08-17-mspl-profile-ci-scaffold.md`

## Checks

```sh
Rscript --vanilla -e 'devtools::load_all("."); testthat::test_local(filter="mspl-api")'
# on #1077 worktree:
Rscript --vanilla -e 'devtools::load_all("."); testthat::test_local(filter="zz-mspl-profile-ci-stub")'
```

## Needs you

1. Merge REPLACE-signed PR for the Poisson card (authoritative Status).
2. Merge this docs PR (KF2021 footnote + triad align to REPLACE).
3. Optional glance at `#1077` wording push — keep draft.
4. Close or supersede `#1096` once provenance RESOLVED lands with REPLACE.
