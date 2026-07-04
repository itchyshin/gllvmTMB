# Bridge Split Manifest

**Date:** 2026-06-19 06:47 MDT  
**Branch:** `codex/r-bridge-grouped-dispersion`  
**Status:** non-destructive preservation and split manifest. No push, no
staging, no branch switch.

## Claim Boundary

`PR green != bridge complete != release ready != scientific coverage passed`.

The local tree has strong R, Julia, and Julia-via-R evidence, but that evidence
belongs to the current mixed local tree. It does not make pushed PR #489
current, release-ready, CRAN-ready, or scientifically complete.

## Preservation Done

Created a local branch pointer:

```text
codex/preserve-bridge-split-20260619-0644
```

It points at:

```text
5346391cc60da7af6d98a4ed05e1495f66430a54
```

Created an external `/tmp` preservation snapshot:

```text
/tmp/gllvmtmb-bridge-split-preserve-20260619-0647/
```

Contents:

```text
tracked-dirty.diff          binary git diff for tracked dirty files
tracked-dirty.name-status   name/status list for tracked dirty files
untracked-files.txt         newline list of untracked paths
untracked-files.zlist       nul-delimited list of untracked paths
untracked-files.tgz         tarball of untracked paths
untracked-tar.stderr        empty
```

Observed snapshot facts:

- `tracked-dirty.diff`: 3.9M
- `tracked-dirty.name-status`: 5.9K
- `untracked-files.tgz`: 145K
- `untracked-files.txt`: 149 paths
- `untracked-tar.stderr`: empty

This preservation step does not replace a real branch split. It is a safeguard
against accidental loss while planning the split.

## Current State

Pushed PR #489:

- open and draft;
- mergeable/clean;
- head SHA `03fdda1cedd325188448ffe58b42f09acbf69e61`;
- visible checks: `ubuntu-latest (release)` and
  `coevolution-two-kernel-recovery`, both green.

Local branch:

- local HEAD `5346391cc60da7af6d98a4ed05e1495f66430a54`;
- 56 commits ahead of origin;
- dirty working tree remains present;
- `git diff --check` is clean.

Committed-ahead layer relative to pushed PR head:

```text
69 files changed, 11405 insertions(+), 309 deletions(-)
```

Dirty tracked layer:

```text
171 files changed, 32480 insertions(+), 21489 deletions(-)
```

Untracked layer:

```text
149 paths captured in /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/untracked-files.txt
```

## Split Lanes

### Lane 1: Bridge Admission

Purpose:

- Keep PR #489 as the Julia bridge admission vehicle only.

Scope:

- `R/julia-bridge.R` when present in the lane.
- `tests/testthat/test-julia-bridge.R`.
- Bridge capability rows / bridge docs directly needed by the bridge PR.
- Minimal lane-specific check-log, dashboard, and after-task evidence.

Evidence already refreshed locally:

- R-only bridge guard suite with expected live-Julia skips.
- Detached GLLVM.jl #101 Julia bridge tests:
  `121/121`, `40/40`, `64/64`.
- Live Julia-via-R suite:
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 1188`.

Do not include:

- coevolution engine/TMB work;
- ordinary-latent/Psi API migration;
- article council estate;
- broad dashboard/dev-log dumps;
- scientific-coverage wording.

### Lane 2: Fixed Multi-Kernel / Coevolution Engine

Purpose:

- Review the fixed-rho, latent-only, named multi-kernel engine and associated
  COE-04 evidence independently from the bridge PR.

Likely scope:

- `src/gllvmTMB.cpp`
- `R/kernel-helpers.R`
- `R/kernel-keywords.R`
- `R/fit-multi.R`
- `R/extract-sigma.R`
- `NAMESPACE`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `tests/testthat/test-coevolution-prototype.R`
- `tests/testthat/test-coevolution-recovery.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- coevolution-specific Rd files and article snippets
- lane-specific after-task reports for COE-04 only

Required reviewers:

- Gauss / TMB-likelihood review before merge.
- Noether for mathematical contract and fixed-rho covariance interpretation.
- Fisher / Curie for recovery/null/interval boundaries.

Boundaries:

- fixed-rho point-estimate evidence only;
- no in-engine `rho` estimation;
- no rho intervals;
- no formal reusable Type-I/null calibration;
- no interval calibration;
- no scientific coverage completion.

### Lane 3: `unique()` / Ordinary `latent()` Psi Migration

Purpose:

- Review the API/convention migration separately because it changes default
  teaching syntax and touches many examples and generated docs.

Likely scope:

- `R/unique-keyword.R`
- `R/fit-multi.R`
- `R/gllvmTMB.R`
- `R/gllvmTMB-wide.R`
- extractor/helper files touched by default Psi handling
- `tests/testthat/test-unique-family-deprecation.R`
- parser/current-behaviour tests that changed from `latent() + unique()` to
  ordinary `latent()`
- `AGENTS.md`, `CLAUDE.md`, `README.md`, `NEWS.md`
- `docs/design/00-vision.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/04-random-effects.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- generated Rd files for affected exported functions
- lane-specific after-task reports for the convention-change cascade

Required reviewers:

- Boole for formula/API syntax.
- Rose for convention-change cascade.
- Grace for generated docs/pkgdown.

Boundaries:

- `unique()` / source-specific `*_unique()` / `kernel_unique()` remain
  compatibility syntax;
- no keyword removal;
- no `deprecate_warn()` escalation beyond current lifecycle policy;
- source-specific and kernel latent-Psi folds remain future slices unless
  explicitly proven in this lane.

### Lane 4: Article / Example / Public Placement

Purpose:

- Review article council and public-surface work after the API lane is stable.

Likely scope:

- `vignettes/articles/*`
- `vignettes/gllvmTMB.Rmd`
- `README.md`
- `_pkgdown.yml`
- `data-raw/examples/*`
- `inst/extdata/examples/*`
- article-council ledger and article-specific after-task reports

Required reviewers:

- Pat / Darwin for reader path and applied biological story.
- Florence for figures.
- Rose / Grace for stale claims, links, renders, and pkgdown.

Boundaries:

- browser review does not equal public placement;
- public placement does not equal release readiness;
- article examples do not create scientific coverage without row-level
  validation evidence.

### Lane 5: Evidence / Dev-Log / Dashboard

Purpose:

- Keep process evidence lane-specific rather than making every feature PR carry
  every dashboard/check-log/recovery artifact.

Scope:

- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/*`
- `docs/dev-log/after-task/*`
- `docs/dev-log/recovery-checkpoints/*`
- `docs/dev-log/audits/*`

Rule:

- Include only the reports that prove the lane under review.
- Do not dump unrelated historical process evidence into the bridge PR.

## Suggested Non-Destructive Split Sequence

1. Keep the current working tree in place until a lane split is deliberately
   chosen.
2. Use the preservation branch and `/tmp` snapshot above as fallback evidence.
3. For each split lane, create a clean local worktree from the intended base.
4. Bring in only the lane's commits/files with explicit pathspecs or selected
   cherry-picks.
5. Never use `git add -A`.
6. Run lane-specific validation before any push.
7. If pushing later, wait for fresh CI on that exact pushed head before widening
   any claim.

## Commands Used For This Manifest

```sh
gh pr list --state open
git log --all --oneline --since="6 hours ago"
git status --short --branch
git diff --check
git branch codex/preserve-bridge-split-20260619-0644 HEAD
mkdir -p /tmp/gllvmtmb-bridge-split-preserve-20260619-0647
git diff --binary > /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/tracked-dirty.diff
git diff --name-status > /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/tracked-dirty.name-status
git ls-files --others --exclude-standard > /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/untracked-files.txt
git ls-files --others --exclude-standard -z > /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/untracked-files.zlist
tar --null -T /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/untracked-files.zlist -czf /tmp/gllvmtmb-bridge-split-preserve-20260619-0647/untracked-files.tgz
```

## Shannon Verdict

`WARN`: work can continue, but branch splitting should happen before any push.
The current branch is preserved locally and the dirty tree has an external
snapshot. The next action is to create lane-specific worktrees/branches and
move one lane at a time.
