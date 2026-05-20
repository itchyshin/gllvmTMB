# After-Task Report: M3.3a `nbinom2` Known-Phi Point Diagnostic

Date: 2026-05-20  
Branch: `codex/m3-3a-nbinom2-known-phi-diagnostic-2026-05-20`  
Lead: Ada  
Active perspectives: Ada, Curie, Fisher, Grace, Rose, Shannon  
Spawned subagents: none

## Scope

This slice added a development-only M3 diagnostic mode for `nbinom2`
fits: compare the ordinary estimated-dispersion fit against a refit
where `log_phi_nbinom2` is fixed at the known DGP value. The goal was to
diagnose whether dispersion estimation is driving the low
`Sigma_unit_diag` point estimates seen in the corrected M3.3a stress
grid.

The slice did not change the public `gllvmTMB()` API, the TMB
likelihood, exported documentation, or advertised capability status.

## Files Changed

- `dev/m3-grid.R`
- `tests/testthat/test-m3-grid-summary.R`
- `docs/design/42-m3-dgp-grid.md`
- `docs/dev-log/audits/2026-05-20-m3-3a-nbinom2-known-phi-point-r10.md`
- `docs/dev-log/after-task/2026-05-20-m3-3a-nbinom2-known-phi-point.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## Evidence

- `gh pr list --state open --repo itchyshin/gllvmTMB`
  - no open PRs at lane start.
- `git log --all --oneline --since="6 hours ago"`
  - reviewed recent M3.3a commits through board closeout `354e995`.
- `Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); cat("parse ok\n")'`
  - passed.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  - `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 18 ]`.
- `Rscript --vanilla - <<'EOF' ... EOF`
  - tiny known-phi point-only smoke passed; fitted `phi_nbinom2`
    equaled truth and `n_boot = 0` was preserved.
- `Rscript --vanilla - <<'EOF' ... EOF`
  - created
    `/tmp/gllvmtmb-m3-3a-known-phi-point-r10/nbinom2-known-phi-point-r10.rds`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - `No problems found.`
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  - 0 errors, 1 warning, 5 notes; nonzero exit because R CMD check
    found a package-installation warning. Notes were future timestamp
    verification, top-level `air.toml` / `Rplots.pdf`, NEWS heading
    extraction, unused `nlme`, and base namespace notes for `setNames` /
    `modifyList`.
- `git diff --check`
  - clean.

## Pilot Result

The r10 point-only pilot found that known-phi refits improved median
`Sigma_unit_diag` estimate/truth ratios from 0.557 to 0.697 in the
baseline scenario, from 0.649 to 0.856 in the low-dispersion scenario,
and from 0.701 to 0.942 in the weak latent+unique variance scenario.

The result supports Fisher's diagnosis that NB2 dispersion estimation is
a major contributor to the underestimation pattern, but Rose's scope
boundary remains unchanged: EXT-13 / CI-08 / CI-10 stay partial because
this is point-estimate evidence, not coverage evidence.

## Definition of Done Check

1. Implementation: development-grid diagnostic added; not yet merged.
2. Simulation recovery test: not applicable as a new advertised feature;
   this is a diagnostic pilot over a known DGP. Curie checked the DGP and
   target alignment.
3. Documentation: Design 42 and this audit record the diagnostic scope.
   No roxygen/Rd updates were needed because no exported API changed.
4. Runnable user-facing example: not applicable; dev-grid diagnostic
   only.
5. Dev-log entry: added in `docs/dev-log/check-log.md`.
6. Review pass: Fisher and Curie own the statistical/simulation reading;
   Rose owns the scope-boundary reading; Grace owns CI/pkgdown once the
   PR opens.

## Next Safest Step

Open the PR after local checks. If PR CI passes, merge this diagnostic
slice and then decide whether the next modeling slice should improve NB2
dispersion estimation directly or add a fixed-phi bootstrap path for
coverage diagnostics.
