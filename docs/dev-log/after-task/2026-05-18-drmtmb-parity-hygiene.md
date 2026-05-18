# After Task: drmTMB-parity hygiene and source-of-truth cascade

**Branch**: `codex/drmtmb-parity-hygiene`
**Date**: 2026-05-18
**Scope**: process / docs / roxygen consistency. No likelihood,
engine, test, or merge work on PR #181 / #182.
**Lead personas**: Ada (coordination), Rose (cross-file consistency),
Boole (formula/API language), Pat (reader path), Grace (verification),
Shannon (cross-team lane boundary).

## 1. Goal

The maintainer asked Codex to learn from the local `drmTMB` team's
careful workflow and to stop before the fourth step so the team can
revisit whether more can be learned from `drmTMB`. This branch turns
that into a small hygiene lane:

- update the live coordination board now that Codex is back;
- add a compact team-improvement log for reusable process lessons;
- repair high-risk contradictions across source-of-truth docs,
  roxygen, generated Rd, and project-local skills;
- stop before reviewing or merging Claude's held engine PRs #181 and
  #182.

## 2. What changed

### Coordination and process

- `docs/dev-log/coordination-board.md`: replaced the stale
  Codex-absent assumption with the current bounded hygiene lane,
  recorded open Claude PRs #181 / #182 as held and green, and named
  the stop point before engine PR review.
- `docs/dev-log/team-improvements.md`: new process log capturing
  lessons from `drmTMB`: closure discipline, live lane ownership,
  source-of-truth cascades, exact completed checks, and reader-path
  separation.

### Source-of-truth cascade

Updated `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`,
`NEWS.md`, `DESCRIPTION`, `_pkgdown.yml`, selected design docs,
`docs/dev-log/known-limitations.md`, and project-local skills so they
agree on four current contracts:

1. the covariance keyword grid is **4 x 5** (`none / animal / phylo /
   spatial` by `scalar / unique / indep / dep / latent`);
2. `meta_V(value, V = V)` is canonical and `meta_known_V()` is the
   deprecated alias;
3. `gllvmTMB_wide(Y, ...)` remains exported but is **soft-deprecated**;
   new examples teach `gllvmTMB(traits(...) ~ ..., data = df_wide)`;
4. `indep()` is the explicit marginal / diagonal model equivalent to
   standalone `unique()`, not a compound-symmetric off-diagonal model.

### Roxygen / Rd consistency

Touched only wording/comment surfaces in R files:

- `R/gllvmTMB.R`: top-level help now lists the 4 x 5 grid, includes
  `animal_*`, and points known-V users to `meta_V()`.
- `R/traits-keyword.R`: help now teaches long + `traits(...)` wide
  data-frame paths first, with `gllvmTMB_wide()` as soft-deprecated
  migration support.
- `R/brms-sugar.R`, `R/two-stage.R`, `R/animal-keyword.R`: comments,
  warnings, examples, and see-also links now prefer `meta_V()`.
- Regenerated matching Rd pages: `man/gllvmTMB.Rd`,
  `man/gllvmTMB-package.Rd`, `man/traits.Rd`, `man/meta.Rd`,
  `man/block_V.Rd`, and `man/animal_scalar.Rd`.

## 3. Checks run

- `gh pr list --repo itchyshin/gllvmTMB --state open` before edits:
  open PRs #181 and #182; both green / held for Codex review.
- `git log --all --oneline --since="6 hours ago"` before shared-file
  edits: confirmed recent Claude merges and no active local edit lock
  on this branch.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: clean.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-traits-keyword.R")'`:
  41 pass, 2 skip, 0 fail.
- `Rscript --vanilla -e 'devtools::test(filter = "brms-sugar", reporter = "summary")'`:
  pass. A first naked `testthat::test_file("tests/testthat/test-brms-sugar.R")`
  run failed because the shared package helper `simulate_site_trait()`
  was not loaded; the `devtools::test()` rerun is the meaningful result.
- `git diff --check`: clean.
- Stale-wording scan:
  `rg -n '3 x 5|3 × 5|removed in 0\\.2\\.0|REMOVED in 0\\.2\\.0|compound-symmetric \`indep|Compound-symmetric \`indep|indep.*compound-symmetric|off-diagonals equal|single trait-by-trait correlation|meta_known_V\\(V|reserved for \`meta_known_V|gllvmTMB_wide\\(Y, \\.\\.\\.\\) was removed' AGENTS.md CLAUDE.md CONTRIBUTING.md DESCRIPTION README.md NEWS.md _pkgdown.yml docs/design docs/dev-log/known-limitations.md .agents/skills R man`
  returned only two expected non-action hits: NEWS historical
  "3 x 5 to 4 x 5" wording and a `R/gllvmTMB.R` comment about the
  removed no-covstruct fallback, not `gllvmTMB_wide()`.

## 4. What did not run

- No full `devtools::test()`, `devtools::check()`, or
  `pkgdown::check_pkgdown()`; this is a hygiene branch and the agreed
  stop point is before the engine PR review sequence.
- No review, merge, or code change for PR #181 or #182.
- No article rewrite or navbar redesign.

## 5. Cross-team notes

- The two untracked Shannon handoff files present at branch start
  remain untracked and untouched:
  `docs/dev-log/shannon-audits/2026-05-18-codex-kickoff-brief.md`
  and
  `docs/dev-log/shannon-audits/2026-05-18-handover-to-codex-team.md`.
- This branch makes narrow wording-only edits in `R/brms-sugar.R`,
  `R/animal-keyword.R`, and `R/gllvmTMB.R`, which are also near open
  Claude engine PR territory. No engine logic changed, but merge order
  should be checked before combining with #181 / #182.

## 6. Next safest action

Stop here and let the maintainer decide whether to:

1. commit/open this hygiene PR first, then review #182 / #181; or
2. hold this branch while the team revisits more `drmTMB` process
   lessons before any PR movement.

Recommended sequence if continuing later: review #182 first
(M3.4 warm-start + phi-clamp), then #181 (sparse Ainv), because #182
has the higher model-behaviour risk even though both are green.
