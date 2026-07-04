# Codex recovery checkpoint: behavioural article slices 5D/5E

Date: 2026-06-19 00:29 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Current branch/status

- Branch is `codex/r-bridge-grouped-dispersion`, ahead of origin by 56 commits.
- Worktree remains broadly dirty from the long coevolution / `unique()`
  deprecation / article-council mission. Do not revert unrelated changes.
- Latest shared-file lane check for this sitting:
  - `gh pr list --state open` -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"` -> no commits returned.

## Completed in this sitting

- `behavioural-syndromes` wide-form fit gate:
  - added `df_wide`;
  - added wide `traits(...)` fit;
  - rendered long/wide logLik comparison.
- `behavioural-syndromes` diagnostic-table gate:
  - added `diagnostic_table(..., table = "check_gllvmTMB")` evidence;
  - exposed the default long-layout optimizer convergence failure.
- `behavioural-syndromes` diagnostic repair:
  - added shared `fit_control <- gllvmTMBcontrol(start_method = list(method = "indep"))`;
  - passed it to both long and wide fits;
  - rendered long/wide logLik difference `-2.590241e-09`;
  - rendered optimizer convergence, maximum gradient, `sdreport`, and
    `pd_hessian` as `PASS` for both layouts.
- `behavioural-syndromes` reader-path bridge:
  - added a `Reader path` table mapping biological questions to model objects,
    code sections, and readouts.
- Updated:
  - `docs/dev-log/audits/2026-06-18-article-council-ledger.md`;
  - `docs/dev-log/check-log.md`;
  - `docs/dev-log/dashboard/status.json`;
  - `docs/dev-log/dashboard/sweep.json`;
  - after-task reports for wide fit, diagnostic table, diagnostic repair, and
    reader path.

## Commands run with outcomes

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed after the diagnostic repair and reader-path bridge.
- `Rscript --vanilla -e 'devtools::test(filter = "example-behavioural|ordinary-latent|unique-family-deprecation|predictive-diagnostics", reporter = "summary")'`
  - Passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - No problems found.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null`
  - Passed.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  - Passed.
- `git diff --check`
  - Clean.
- Stale behavioural blocker scan:
  - no matches for current unresolved-diagnostic or reader-path-cleanup blocker
    phrases.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  - Passed.
- `curl` checks:
  - `http://127.0.0.1:8765/` -> `200`;
  - `http://127.0.0.1:8770/` -> `200`.

## Current honest state

- Coevolution local engine/extractor stop point is real, but full Paper 2
  scientific coverage is not done.
- `unique()` deprecation is at soft-deprecation / compatibility syntax stage,
  not removal.
- `behavioural-syndromes` remains Tier 3/internal.
- Current behavioural blockers:
  - Pat/Darwin reader review;
  - Florence figure review;
  - final rendered HTML review before any public promotion.

## Next safest action

Continue the article-council plan one gate at a time. Either:

1. start Florence review for `behavioural-syndromes` figures, or
2. start Pat/Darwin reader review of the new reader-path bridge, or
3. move to the next biological worked-example candidate (`phylogenetic-gllvm`
   or `animal-model`) if the goal is to keep sweeping planned article gates.

Do not claim bridge completion, release readiness, or scientific coverage
completion from these article slices.
