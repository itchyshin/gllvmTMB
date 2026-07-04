# Recovery checkpoint -- Codex augmented latent-Psi slice

Date: 2026-06-18 20:01 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Current git state

`git status --short --branch`:

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
M  NEWS.md
M  R/fit-multi.R
M  R/unique-keyword.R
M  data-raw/examples/make-behavioural-reaction-norm-example.R
M  docs/design/01-formula-grammar.md
M  docs/dev-log/check-log.md
M  docs/dev-log/dashboard/status.json
M  docs/dev-log/dashboard/sweep.json
M  inst/extdata/examples/behavioural-reaction-norm-example.rds
M  man/diag_re.Rd
M  tests/testthat/test-example-behavioural-reaction-norm.R
M  tests/testthat/test-ordinary-latent-random-regression.R
M  vignettes/articles/random-regression-reaction-norms.Rmd
?? docs/dev-log/after-task/2026-06-18-article-unique-cleanup.md
```

The full worktree remains broad from the inherited coevolution / unique
deprecation stack. This list names the files touched by this checkpoint's
latest slice; `git status --short --branch` still shows many earlier modified
and untracked files from the same branch stack.

`git diff --stat` for the full tree reports 86 changed tracked files with
2931 insertions and 811 deletions, plus existing untracked after-task,
audit, recovery-checkpoint, Rd, and test files.

## What changed in this slice

- `R/fit-multi.R` now turns on the existing augmented ordinary diagonal
  B-slope block by default for Gaussian `latent(1 + x | unit, d = K)` fits.
- `fit$use$diag_B_slope_default` records when that default path is active.
- Explicit augmented `unique(1 + x | unit)` remains compatibility syntax and
  remains Gaussian-only.
- Non-Gaussian augmented `latent()` remains low-rank-only.
- The behavioural reaction-norm fixture and
  `vignettes/articles/random-regression-reaction-norms.Rmd` now use the
  default augmented `latent()` spelling in long and wide formulas.
- `docs/design/01-formula-grammar.md`, `R/unique-keyword.R`,
  `man/diag_re.Rd`, `NEWS.md`, the after-task report, the check log, and the
  dashboard JSON were updated to match the same boundary.

## Commands run and outcomes

- `gh pr list --state open`
  -> only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current coevolution stack headed by `5346391`.
- `Rscript --vanilla data-raw/examples/make-behavioural-reaction-norm-example.R`
  -> regenerated `inst/extdata/examples/behavioural-reaction-norm-example.rds`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/diag_re.Rd`.
- `air format ...`
  -> completed, but it caused broad `R/fit-multi.R` formatting churn.
     `R/fit-multi.R` was rebuilt manually back to a focused 24-line diff and
     the tests below were rerun after that cleanup.
- `Rscript --vanilla -e 'devtools::test(filter = "ordinary-latent-random-regression|example-behavioural-reaction-norm", reporter = "summary")'`
  -> passed before and after the `R/fit-multi.R` de-churn.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> failed in a default new process because local pkgdown picked up an older
     installed namespace that still required explicit augmented `unique()`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> rendered successfully and wrote
     `pkgdown-site/articles/random-regression-reaction-norms.html`.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|extract-sigma|ordinary-latent-random-regression|example-behavioural-reaction-norm", reporter = "summary")'`
  -> passed before and after the `R/fit-multi.R` de-churn; twelve expected
     heavy tests were skipped.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `Rscript --vanilla -e 'jsonlite::validate(readLines("docs/dev-log/dashboard/status.json", warn = FALSE)); jsonlite::validate(readLines("docs/dev-log/dashboard/sweep.json", warn = FALSE))'`
  -> both dashboard JSON files valid.
- `git diff --check`
  -> no whitespace errors.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  -> synced the gllvm dashboard served at `http://127.0.0.1:8770/`.
- `curl -I --max-time 2 http://127.0.0.1:8765/` and
  `curl -I --max-time 2 http://127.0.0.1:8770/`
  -> both endpoints returned HTTP 200. Port 8765 serves `/tmp/drm-dashboard`
     and was left untouched; port 8770 serves `/tmp/gllvm-dashboard`.

## Next safest action

Continue the `unique()` deprecation plan by auditing the remaining planned
items after this Gaussian augmented ordinary latent-Psi fold:

1. Re-scan for residual ordinary-user examples that still recommend explicit
   ordinary `unique()` outside compatibility/boundary contexts.
2. Decide the next narrow `unique()` deprecation gate: likely `part = "unique"`
   naming / `common = TRUE` re-homing design, not removal.
3. Keep `kernel_unique()` / `*_unique()` as compatibility syntax only; do not
   expand Paper 2 multi-kernel explicit-Psi support.

## Still not claimed

- No `unique()` / `*_unique()` removal.
- No `part = "unique"` rename.
- No `common = TRUE` re-homing.
- No source-specific or `kernel_*()` latent-Psi fold.
- No Paper 2 multi-kernel explicit-Psi implementation.
- No non-Gaussian augmented diagonal-Psi support.
- No bridge completion, release readiness, or scientific coverage completion.
