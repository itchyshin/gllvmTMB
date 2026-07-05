# Codex Handover Checkpoint: kernel_latent() default Psi fold

**Date:** 2026-06-22 04:48:15 America/Edmonton  
**Author:** Codex / Ada  
**Worktree:** `/private/tmp/gllvmtmb-kernel-latent-psi-fold`  
**Branch:** `codex/kernel-latent-psi-fold-20260621`  
**HEAD:** `51c91be2a04a6ff498e902407b5b2a328f74ec69`  
**Base state:** stacked on PR #527 (`codex/animal-latent-psi-fold-20260621`);
`origin/main` is `90a0762` after #525.

## Start Packet For The Next Codex Session

Start here:

```sh
cd /private/tmp/gllvmtmb-kernel-latent-psi-fold
git status --short --branch
git diff --stat
git diff
```

Read these files first:

1. `AGENTS.md` and `CLAUDE.md`
2. `docs/dev-log/codex-handover-2026-06-21-latent-migration.md`
3. `docs/dev-log/codex-kickoff-2026-06-21.md`
4. `docs/design/2026-06-21-source-specific-latent-psi-fold.md`
5. `docs/dev-log/check-log.md` newest entry:
   `2026-06-21 -- kernel_latent default Psi fold`
6. `docs/dev-log/after-task/2026-06-21-kernel-latent-psi-fold.md`
7. This checkpoint.

Do **not** continue from `/Users/z3437171/Dropbox/Github Local/gllvmTMB` unless
the maintainer explicitly asks. That root checkout is the dirty mission-control
checkout on `codex/r-bridge-grouped-dispersion`; it is unrelated to this
kernel slice and must not be cleaned or reverted.

## Current Git State

`git fetch --all --prune` was run. Only unrelated
`origin/power-pilot-results` moved (`4614d99..2e6e225`). The kernel worktree
is not pushed and not committed.

`git status --short --branch`:

```text
## codex/kernel-latent-psi-fold-20260621
 M NEWS.md
 M R/brms-sugar.R
 M R/extract-sigma.R
 M R/fit-multi.R
 M R/kernel-keywords.R
 M R/unique-keyword.R
 M docs/design/01-formula-grammar.md
 M docs/design/2026-06-21-source-specific-latent-psi-fold.md
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/check-log.md
 M man/diag_re.Rd
 M man/kernel_latent.Rd
 M tests/testthat/test-coevolution-two-kernel.R
 M tests/testthat/test-kernel-equivalence.R
?? docs/dev-log/after-task/2026-06-21-kernel-latent-psi-fold.md
?? tests/testthat/test-kernel-latent-unique-fold.R
```

After this checkpoint is written, this additional untracked file is expected:

```text
docs/dev-log/recovery-checkpoints/2026-06-22-044815-codex-kernel-latent-handover.md
```

`git diff --stat` before this checkpoint:

```text
 NEWS.md                                            |  9 +-
 R/brms-sugar.R                                     | 30 ++++++-
 R/extract-sigma.R                                  |  5 +-
 R/fit-multi.R                                      | 48 +++++++++++
 R/kernel-keywords.R                                | 39 +++++----
 R/unique-keyword.R                                 | 10 +--
 docs/design/01-formula-grammar.md                  | 30 +++----
 .../2026-06-21-source-specific-latent-psi-fold.md  | 14 ++--
 docs/design/35-validation-debt-register.md         |  4 +-
 docs/dev-log/check-log.md                          | 98 ++++++++++++++++++++++
 man/diag_re.Rd                                     | 10 +--
 man/kernel_latent.Rd                               | 38 +++++----
 tests/testthat/test-coevolution-two-kernel.R       | 32 +++----
 tests/testthat/test-kernel-equivalence.R           |  4 +-
 14 files changed, 280 insertions(+), 91 deletions(-)
```

Untracked implementation/report files before this checkpoint:

```text
docs/dev-log/after-task/2026-06-21-kernel-latent-psi-fold.md
tests/testthat/test-kernel-latent-unique-fold.R
```

## Implemented Work

`kernel_latent(unit, K = A, d = q, name = "known")` now folds the
dense-kernel diagonal `Psi_kernel` companion by default for one named kernel
tier:

```text
Sigma_kernel = (Lambda Lambda^T) \otimes K + Psi_kernel \otimes K
```

`kernel_latent(..., unique = FALSE)` keeps the old loadings-only route.

`kernel_latent(..., unique = FALSE) + kernel_unique(...)` remains accepted as
compatibility syntax and is byte-equivalent to the folded default for one named
dense-kernel tier.

For two or more named `kernel_latent()` tiers, `R/fit-multi.R` prunes the
auto-generated kernel Psi companions before the existing multi-kernel guard.
That preserves the first multi-kernel engine wave as latent-only. User-written
`kernel_unique()` terms remain visible to the explicit-Psi guard.

No `src/gllvmTMB.cpp` or SPDE engine code changed.

## Validation Already Run

Focused gates:

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-latent-unique-fold.R", reporter = "summary")'
```

PASS: `kernel-latent-unique-fold: .......................`

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-equivalence.R", reporter = "summary")'
```

PASS: `kernel-equivalence: ......................................`

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'
```

PASS under normal env; expected heavy gates skipped.

Heavy two-kernel gate:

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'
```

First run failed because one-kernel comparators inherited the new default Psi.
After retargeting those comparators to `unique = FALSE`, the same command
passed. This is recorded in the check log and after-task report.

Package gates:

```sh
Rscript --vanilla -e 'devtools::test()'
```

PASS: `[ FAIL 0 | WARN 10 | SKIP 745 | PASS 3445 ]`

```sh
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
```

PASS: `No problems found`.

```sh
Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'
```

FAILS in known existing article-render debt:
`vignettes/articles/lambda-constraint-suggest.Rmd`, chunk
`profile-confidence-eye`, where
`loading_ci(fit_pr, level = "unit", method = "wald")` correctly rejects an
unconstrained loading fit. This is not a kernel regression.

```sh
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

COMPLETED: `0 errors, 1 warning, 0 notes`. The warning is the known local
Apple-clang/R-header warning:

```text
R_ext/Boolean.h:62:36: warning: unknown warning group
'-Wfixed-enum-extension', ignored [-Wunknown-warning-option]
```

Persistent `rcmdcheck::rcmdcheck(args = "--no-manual")` without forcing
Suggests errored because local Suggests `mirt` and `nadiv` are not installed.
The rerun with `_R_CHECK_FORCE_SUGGESTS_=false` completed with the same single
local clang warning.

```sh
git diff --check
```

PASS before this checkpoint.

## Stale-Scan Evidence

The check-log entry records the exact patterns. Key result:

- no live source says `kernel_latent()` is still pending or requires paired
  `kernel_unique()` as the primary spelling;
- no new `S_B` / `S_W` notation;
- new roxygen example is wide `traits(...)` and correctly omits `trait =`;
- `meta_known_V`, `gllvmTMB_wide`, and internal-route matches are expected
  historical/deprecated-alias references, not new kernel primary examples.

## GitHub / Shannon Coordination State

Shannon verdict: **WARN**.

Reason: the work is coherent and logged, but it is uncommitted/unpushed and
stacked on #527. Do not publish it as an ordinary PR until #527 merges or the
maintainer explicitly asks for a stacked PR.

Open PR census:

- #527, `Fold animal_latent diagonal Psi by default`
  - branch: `codex/animal-latent-psi-fold-20260621`
  - base: `main`
  - merge state: `CLEAN`
  - checks: `R-CMD-check / ubuntu-latest (release)` success;
    `coevolution-two-kernel-recovery / recovery` success
  - URL: `https://github.com/itchyshin/gllvmTMB/pull/527`

Recent Actions runs:

- #527 R-CMD-check success at `51c91be`
- #527 coevolution-two-kernel recovery success at `51c91be`
- main pkgdown and R-CMD-check green at `90a0762`
- unrelated `Power pilot sweep` has mixed success/failure; not part of this
  lane.

File overlap:

- #527 and this kernel work both touch `NEWS.md`, `R/brms-sugar.R`,
  `R/unique-keyword.R`, `docs/design/01-formula-grammar.md`,
  `docs/design/2026-06-21-source-specific-latent-psi-fold.md`,
  `docs/design/35-validation-debt-register.md`, `docs/dev-log/check-log.md`,
  and `man/diag_re.Rd`.
- This is intentional because the kernel branch is stacked directly on #527.
  Rebase after #527 merges rather than trying to retarget from current
  `origin/main`.

Mission-control checkout:

```text
/Users/z3437171/Dropbox/Github Local/gllvmTMB
```

is on `codex/r-bridge-grouped-dispersion`, ahead of origin with many dirty
files and many untracked reports/checkpoints. Do not clean, reset, or stage
that checkout for this task.

## What Still Needs To Run

After #527 merges and this branch is rebased onto the new `origin/main`, rerun:

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-latent-unique-fold.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-kernel-equivalence.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::test()'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
git diff --check
```

If pushing, obey the hard guard from the handover: run the package check before
push, stage files by name only, and wait for GitHub Actions rather than
rapid-fire fixup pushes.

`pkgdown::build_articles(lazy = FALSE)` is currently known to fail in
`lambda-constraint-suggest.Rmd`; do not claim a fully green article-render gate
until that separate docs hardening slice lands.

## Next Safest Action

1. Get explicit maintainer direction on PR #527. Because #527 is a grammar /
   default change, do not self-merge without a clear "yes merge #527".
2. Once #527 is merged, return to this worktree and rebase onto `origin/main`.
3. Resolve any expected overlap in shared docs/Rd/check-log files.
4. Rerun the focused and package gates listed above.
5. Stage by name only. Do **not** use `git add -A`.
6. Commit with a message like:

   ```text
   feat(grammar): fold kernel_latent diagonal Psi by default
   ```

7. Push/open the kernel PR. The PR body should mention:
   - one named `kernel_latent()` now folds `Psi_kernel`;
   - `unique = FALSE` is the canonical loadings-only switch;
   - explicit `kernel_unique()` remains compatibility syntax;
   - multi-kernel remains latent-only and auto companions are pruned;
   - no TMB/SPDE code changed;
   - validation evidence from the check-log.

## Blocking Question

No code blocker remains for the kernel slice. The only decision blocker is
merge sequencing: publish only after #527 merges, unless the maintainer
explicitly requests a stacked kernel PR.

