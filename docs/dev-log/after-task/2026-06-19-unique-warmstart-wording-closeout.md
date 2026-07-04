# After-task report: unique warm-start wording closeout

Date: 2026-06-19 03:39 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice continued the unique-deprecation closeout after the COE-04 module
gate. It did not change parser behavior. It only removed live wording that
still taught independent warm-starts as `unique()`-only models.

## Files touched

- `R/gllvmTMB.R`
- `R/init-warmstart.R`
- `R/phylo-signal-ci.R`
- `man/gllvmTMBcontrol.Rd`
- `tests/testthat/test-canonical-keywords.R`
- `docs/design/48-m3-4-boundary-regimes.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Passed; regenerated `man/gllvmTMBcontrol.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|gllvmTMBcontrol")'`
  - Passed with `FAIL 0 | WARN 0 | SKIP 3 | PASS 114`.
- `rg -n 'unique-only|unique only|independent \`unique\\(\\)\`|New canonical syntax \\(latent \\+ unique\\)' R man tests/testthat/test-canonical-keywords.R docs/design docs/dev-log/check-log.md`
  - Live hits were removed; remaining hits are historical check-log records.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed with `No problems found.`
- `rg -n 'latent\(\.\.\.\) \+ unique|M3\.3 grid uses \`latent\(\) \+ unique\(\)\`|For \`latent\(\) \+ unique\(\)\` fits|unique-only|unique only|independent \`unique\\(\\)\`|New canonical syntax \\(latent \\+ unique\\)' docs/design/44-m3-3-inference-replacement.md docs/design/48-m3-4-boundary-regimes.md R man tests/testthat/test-canonical-keywords.R`
  - No hits after the M3 design-roadmap follow-up.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Re-run after the M3 design-roadmap follow-up; passed with
    `No problems found.`

## Definition-of-done notes

- Implementation: local wording/reference cleanup only; not merged to `main`.
- Simulation recovery: not applicable; no likelihood, family, keyword, or
  estimator behavior changed.
- Documentation: `gllvmTMBcontrol()` roxygen and Rd were regenerated.
- Runnable example: the warm-start and M3 boundary design recipes now use
  `indep()` and ordinary `latent()` rather than `unique()`-only /
  latent+unique teaching syntax.
- Check-log: this task has a dated entry with exact commands.
- Review/scope: Boole/Rose-style consistency cleanup only; no TMB likelihood or
  formula-grammar behavior changed.

## Not claimed

- No `deprecate_warn()` escalation.
- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No expansion of `kernel_unique()` for Paper 2 multi-kernel coevolution.
- No bridge completion, release readiness, or scientific coverage completion.
