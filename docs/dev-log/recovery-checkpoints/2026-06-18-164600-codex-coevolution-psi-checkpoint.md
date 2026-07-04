# Codex Recovery Checkpoint: Coevolution + Psi Sweep

**Date:** 2026-06-18 16:46 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Git Status

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
 M NEWS.md
 M docs/design/35-validation-debt-register.md
 M docs/design/65-cross-lineage-coevolution-kernel.md
 M docs/dev-log/check-log.md
 M docs/dev-log/dashboard/status.json
 M docs/dev-log/dashboard/sweep.json
 M tests/testthat/test-coevolution-two-kernel.R
 M vignettes/articles/animal-model.Rmd
 M vignettes/articles/functional-biogeography.Rmd
 M vignettes/articles/phylogenetic-gllvm.Rmd
 M vignettes/articles/response-families.Rmd
?? docs/dev-log/after-task/2026-06-18-coe04-high-overlap-failure-calibration.md
?? docs/dev-log/after-task/2026-06-18-psi-unique-second-sweep.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-050000-codex-handover-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-151509-codex-stop-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-160541-codex-progress-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-180500-codex-restart-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-181500-codex-new-session-handover.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-191525-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-192858-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-195142-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-200837-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-205909-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-214510-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-221512-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-223101-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-225916-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-231819-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-001043-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-020230-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-023910-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-034323-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-040200-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-051512-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-052348-codex-new-session-handover.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-161255-codex-new-session-handover.md
```

## Diff Stat

```text
 NEWS.md                                            |  31 ++++-
 docs/design/35-validation-debt-register.md         |   2 +-
 docs/design/65-cross-lineage-coevolution-kernel.md |   4 +-
 docs/dev-log/check-log.md                          | 146 +++++++++++++++++++++
 docs/dev-log/dashboard/status.json                 |  36 +++--
 docs/dev-log/dashboard/sweep.json                  |  20 ++-
 tests/testthat/test-coevolution-two-kernel.R       |  70 ++++++++++
 vignettes/articles/animal-model.Rmd                |  34 ++---
 vignettes/articles/functional-biogeography.Rmd     |  10 +-
 vignettes/articles/phylogenetic-gllvm.Rmd          |  10 +-
 vignettes/articles/response-families.Rmd           |  17 ++-
 11 files changed, 330 insertions(+), 50 deletions(-)
```

## Completed This Sitting

- Added COE-04 non-identical high-overlap failure-calibration gate.
- Updated coevolution design/register/NEWS/dashboard/check-log and after-task
  report.
- Completed the second Psi / `unique()` public-story sweep:
  `response-families`, `animal-model`, `phylogenetic-gllvm`, and
  `functional-biogeography`.
- Synced the live dashboard at `http://127.0.0.1:8770/` to the
  `2026-06-18 16:42 MDT` state.
- Refreshed #489/#101 read-only evidence:
  - #489 is draft/open/clean/green at pushed head `03fdda1`.
  - Local coevolution/Psi changes are not pushed and therefore are not covered
    by PR green.
  - GLLVM.jl #101 is draft/open/clean at `f7be594`, with fresh CI and
    Documenter green. No GLLVM.jl mutation was made.

## Commands Run

- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 270`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 67`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 14 | PASS 171`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 399`.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/response-families", "articles/animal-model", "articles/phylogenetic-gllvm", "articles/functional-biogeography")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  -> all four touched articles rendered.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> JSON valid.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/ && curl -s --max-time 2 http://127.0.0.1:8770/status.json | python3 -m json.tool | rg -n "16:42|sweep 2|source-specific \\*_indep|parser-wide deprecation"`
  -> live dashboard synced.
- `git diff --check`
  -> clean.

## Next Safest Action

Stop for the #489 landing/split decision unless the maintainer explicitly
authorizes a push. The next grand-plan gate is not more local code: #489 is
green only at the old pushed head `03fdda1`, while the local coevolution/Psi
changes are unpushed. Keep #101 untouched.

## Blocking Question

Should the local coevolution + Psi sweep be bundled into #489 as a follow-up
push, split into a separate PR, or held locally while the bridge landing path is
decided?
