# Codex Recovery Checkpoint: coevolution + Psi closeout

Date: 2026-06-18 16:52 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Git State

`git status --short --branch`:

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
?? docs/dev-log/recovery-checkpoints/2026-06-18-165200-codex-coevolution-unique-closeout.md
```

`git diff --stat`:

```text
 NEWS.md                                            |  36 +++-
 docs/design/35-validation-debt-register.md         |   2 +-
 docs/design/65-cross-lineage-coevolution-kernel.md |   4 +-
 docs/dev-log/check-log.md                          | 200 +++++++++++++++++++++
 docs/dev-log/dashboard/status.json                 |  36 ++--
 docs/dev-log/dashboard/sweep.json                  |  20 ++-
 tests/testthat/test-coevolution-two-kernel.R       |  70 ++++++++
 vignettes/articles/animal-model.Rmd                |  34 ++--
 vignettes/articles/functional-biogeography.Rmd     |  10 +-
 vignettes/articles/phylogenetic-gllvm.Rmd          |  10 +-
 vignettes/articles/response-families.Rmd           |  25 ++-
 11 files changed, 394 insertions(+), 53 deletions(-)
```

## Commands Run

- Pre-edit lane checks:
  - `gh pr list --state open` -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"` -> current mission-control /
    coevolution stack only.
- Coevolution tests:
  - `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
    -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 270`.
  - `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
    -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 67`.
  - `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
    -> `FAIL 0 | WARN 0 | SKIP 14 | PASS 171`.
  - `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
    -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 399`.
- Article and public-story checks:
  - `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/response-families", "articles/animal-model", "articles/phylogenetic-gllvm", "articles/functional-biogeography")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
    -> all four touched articles rendered successfully after the Rose row-anchor
    patch.
  - `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
    -> `No problems found.`
  - Rose scans confirmed the new row anchors in source, rendered HTML, and NEWS;
    stale-term scan found only existing NEWS compatibility references
    (`block_V()`, `meta_known_V()`), not the edited articles.
  - `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null &&
    python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null &&
    git diff --check`
    -> clean.
  - `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/` plus live curl of
    `http://127.0.0.1:8770/status.json` and `/sweep.json`
    -> dashboard served the 16:50 Rose row-anchor state.

## Current Closeout

- COE-04 is locally expanded with the non-identical high-overlap
  failure-calibration gate. It remains `partial`, not covered.
- The second Psi / `unique()` cleanup sweep is locally rendered and audited.
  `unique()` / `*_unique()` remain compatibility and explicit-Psi syntax only;
  no parser-wide lifecycle/deprecation warning or API removal was added.
- The local dashboard is alive at `http://127.0.0.1:8770/` and synced from
  `docs/dev-log/dashboard/`.
- Draft PR #489 is still green only at the older pushed head `03fdda1`; the
  current local work is not pushed.
- GLLVM.jl #101 was not mutated.

## Next Safest Action

Stop here for the maintainer's landing/split decision on #489 and the post-arc
`unique()` lifecycle/deprecation plan. Do not push, do not mutate GLLVM.jl #101,
and do not widen claims beyond the validation rows.
