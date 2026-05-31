# 2026-05-31 11:43:32 -- Codex C1 kernel equivalence checkpoint

## Branch And Status

Branch: `codex/kernel-c1-equivalence`

`git status --short --branch`:

```text
## codex/kernel-c1-equivalence
 M AGENTS.md
 M CLAUDE.md
 M NAMESPACE
 M NEWS.md
 M R/brms-sugar.R
 M R/extract-sigma.R
 M R/fit-multi.R
 M R/traits-keyword.R
 M _pkgdown.yml
 M docs/design/01-formula-grammar.md
?? R/kernel-keywords.R
?? man/kernel_latent.Rd
?? tests/testthat/test-kernel-equivalence.R
```

## Diff Stat

`git diff --stat` tracked files:

```text
 AGENTS.md                         | 14 +++++++---
 CLAUDE.md                         |  4 +++
 NAMESPACE                         |  4 +++
 NEWS.md                           |  4 +++
 R/brms-sugar.R                    | 54 +++++++++++++++++++++++++++++++++++++++
 R/extract-sigma.R                 | 37 +++++++++++++++++++++++++--
 R/fit-multi.R                     | 27 ++++++++++++++++++++
 R/traits-keyword.R                |  4 +++
 _pkgdown.yml                      |  1 +
 docs/design/01-formula-grammar.md | 34 +++++++++++++++++++-----
 10 files changed, 170 insertions(+), 13 deletions(-)
```

Untracked files: `R/kernel-keywords.R`, `man/kernel_latent.Rd`,
`tests/testthat/test-kernel-equivalence.R`.

## Commands Run

- `git switch main && git pull --ff-only origin main && git switch -c codex/kernel-c1-equivalence`
  -> branch created from main containing #367 and C0 #368.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> completed; wrote `NAMESPACE` and `kernel_latent.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 20`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,files,updatedAt,statusCheckRollup`
  -> #370 touches `docs/design/35-validation-debt-register.md`; #369
  touches Design 66 docs only.
- Coordination comment for #370:
  `https://github.com/itchyshin/gllvmTMB/pull/370#issuecomment-4587527672`.

## Next Safest Action

Wait for review-gated #370 to merge or otherwise clear
`docs/design/35-validation-debt-register.md`. Then rebase this C1
branch on `origin/main`, update the register rows, rerun
`devtools::document()`, `devtools::test(filter = "kernel-equivalence")`,
`pkgdown::check_pkgdown()`, and the Rose pre-publish scans, then commit
and open the C1 PR.

## Blocking Question

None for the C1 code path. The only current blocker is external:
#370's own PR body says `Do not merge -- review-gated`, so Codex should
not merge it just to unblock the validation-register edit.

## 2026-05-31 11:50 MDT Update

#370 has since merged into `origin/main`; this branch was rebased onto
that main commit and the C1 WIP was restored without conflicts. Focused
C1 checks still pass:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> complete.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 20`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> no problems.
- `git diff --check` -> clean.

The test file now also contains the explicit bare-latent gate named in
the maintainer handoff:

- `kernel_latent(unit, K = A, d = 2, name = "known")`
  vs `phylo_latent(unit, vcv = A, d = 2)`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 26`.
- Companion modes now have fit-equivalence evidence too:
  `kernel_unique()`, `kernel_indep()`, and `kernel_dep()` are checked
  against the corresponding dense `phylo_*()` `vcv = A` paths.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 38`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> no problems.
- `git diff --check` -> clean.

Integration preflight against the pending overlap branches:

- Temporary worktree from `origin/main`.
- Temporary octopus merge of #371 and #372 succeeded.
- Current C1 tracked patch applied cleanly on top of that merged tree.
- After copying the new C1 files into the throwaway tree,
  `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 26`.

New open overlap exists:

- #371 touches `R/brms-sugar.R`.
- #372 touches `R/fit-multi.R`, `R/extract-sigma.R`, and
  `docs/design/35-validation-debt-register.md`.

Coordination comments were posted on #371 and #372. The next safest
action is to hold the C1 PR/register edit until #371/#372 resolve or the
maintainer gives an explicit merge order.

## 2026-05-31 15:10 MDT Update

#371, #372, #396, and #398 have since merged. The branch was rebased
through `origin/main` at `0792aa0` and the C1 worktree restored cleanly.
The Design 35 row now marks `KER-02` covered and keeps `COE-02`
blocked for C2.

Current focused checks:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` ->
  complete; regenerated `man/kernel_latent.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 38`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> no problems.
- `git diff --check` -> clean.

Current caveat: full local `devtools::check(args = "--no-manual")`
still exits non-zero with unrelated missing-data Rd warnings
(`impute_model.Rd` link to `mi`, `gllvmTMB.Rd` undocumented `impute`)
plus existing package-level notes. C1 itself has no focused test or
pkgdown failure.

Next safest action: commit, push, open the C1 PR, and watch CI. Do not
start C2 or publish the coevolution article from this branch.
