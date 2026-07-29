# VGH Phase 2 wiring vs. PR #818 — collision map (read-only recon)

Date: 2026-07-29 · Branch: `claude/vgh-phase2-20260730` (worktree
`/private/tmp/gllvmtmb-vgh-p2`) · Base of both PR #818 and this worktree's
`R/fit-multi.R`: `origin/main` @ `01ad94ba` (`git merge-base HEAD origin/main`
== `01ad94ba`; `git diff origin/main...HEAD -- R/fit-multi.R` is empty, so
this worktree has not touched the file at all yet and PR #818's diff line
numbers apply verbatim to the current `R/fit-multi.R`).

## 1. PR #818's diff, restricted to `R/fit-multi.R`

Command used: `gh pr diff 818 --repo itchyshin/gllvmTMB > diff.txt`, then
extracted the first hunk (the `--repo` flag does not accept a path argument
in the installed `gh` version, so the file-scoped diff was pulled out of the
full diff by inspection).

PR #818 touches **exactly one hunk** in `R/fit-multi.R`:

- **Diff hunk header:** `@@ -2495,12 +2495,22 @@ gllvmTMB_multi_fit <- function(parsed, data, trait, site, species,`
- **Current (pre-#818) file lines:** `R/fit-multi.R:2495-2516` — this is the
  REML input-validation block inside `gllvmTMB_multi_fit()` (function starts
  at `R/fit-multi.R:329`). The specific statement PR #818 replaces is the
  `if (any(masked_response)) cli::cli_abort(...)` guard at
  `R/fit-multi.R:2496-2501`, which currently forbids `REML = TRUE` together
  with `miss_control(response = "include")`.
- **What #818 does:** deletes that abort and replaces it with an explanatory
  comment block (no abort, no behavioural branch) arguing that masked rows
  already contribute zero to the joint likelihood via `is_y_observed`, so
  REML's Laplace-integrated `b_fix` step is still exact over observed rows.
  It also touches two roxygen blocks in `R/gllvmTMB.R` (the `REML` parameter
  doc and the `miss_control()` details) to match. No other files, and no
  other part of `R/fit-multi.R`, are touched.
- **Enclosing function for the sole `fit-multi.R` hunk:** `gllvmTMB_multi_fit`
  (same function that Phase 2 warm-start wiring will need, since it is the
  only top-level function spanning that whole range — the next top-level
  function definition is `.gllvmTMB_build_missing_data` at line 5955).

## 2. Phase 2 warm-start insertion points in the current `R/fit-multi.R`

All locations below are inside `gllvmTMB_multi_fit()` (`R/fit-multi.R:329`):

- **`tmb_params` initial construction:** `R/fit-multi.R:3739-3748`. The list
  literal that first sets `theta_rr_B` (`:3742`) and `z_B`
  (`R/fit-multi.R:3743`, `matrix(0, nrow = max(d_B, 1L), ncol = n_sites)`),
  plus `theta_rr_B_slope` (`:3745-3748`).
- **`control$start_from` honoured / `.gllvmTMB_apply_start_from()` called:**
  `R/fit-multi.R:3966` (`start_from_fit <- control$start_from %||% NULL`)
  through the actual call site at `R/fit-multi.R:4075-4082`:
  ```
  if (!is.null(start_from_fit)) {
    warm <- .gllvmTMB_apply_start_from(
      tmb_params = tmb_params,
      start_from = start_from_fit,
      verbose = isTRUE(control$verbose)
    )
    tmb_params <- warm$params
    start_provenance$start_from <- TRUE
    start_provenance$start_from_copied <- warm$copied
  }
  ```
  `.gllvmTMB_apply_start_from()` itself is defined at
  `R/init-warmstart.R:367`. Between `:3966` and `:4082` there is also the
  `start_method = "indep"` block (`:3975-4032`, calls itself recursively for
  an auto independent-model warm start) and the `start_method = "res"` block
  (`:4033-4074`, residual-factor start for `theta_rr_B`/`z_B` and
  `theta_rr_W`/`z_W`) — both mutate `tmb_params` before the `start_from_fit`
  block runs, so `start_from_fit` (and, later, VGH) is the last-applied /
  highest-priority start source in the existing precedence order.
- **Last point `tmb_params` can still be mutated before `TMB::MakeADFun()`:**
  `R/fit-multi.R:4852-4863`, the `control$init_strategy ==
  "single_trait_warmup"` block, which ends with
  `for (nm in names(warm)) tmb_params[[nm]] <- warm[[nm]]` at
  `R/fit-multi.R:4863`. `TMB::MakeADFun()` is called immediately after, at
  `R/fit-multi.R:4866`. Note this later `warm` is a *different* object
  (return of `.gllvmTMB_single_trait_warmup()`, phi-parameter seeding only)
  from the `warm` used at `:4076` for `start_from_fit` — same local variable
  name reused in a different, later scope, not the same warm-start
  mechanism. Any VGH-derived values placed into `tmb_params` before
  `:3739`'s construction are irrelevant (overwritten); values placed after
  `:4082` and before `:4863` would survive unless `single_trait_warmup`
  happens to touch the same names (it only ever sets `log_phi_*` fields per
  the comment at `:4849-4851`, so `theta_rr_*`/`z_*` fields are safe past
  that point too).

## 3. Overlap verdict and recommended insertion point

**Verdict: the edits sit far apart, not ambiguous.** PR #818's sole
`fit-multi.R` hunk (`R/fit-multi.R:2495-2516`, the REML/`masked_response`
input-validation guard) is roughly 1,200–2,300 lines upstream of every
candidate Phase 2 insertion point (`:3739`, `:3966-4082`, `:4852-4866`).
Both live inside the same enclosing function (`gllvmTMB_multi_fit`), but
they are disjoint code regions performing unrelated jobs — #818 loosens an
early argument-validation abort; Phase 2 warm-start wiring touches
`tmb_params` construction and the `start_from`/`init_strategy` machinery much
further down, after all of #818's validation has already run and returned
(or not aborted). No line ranges overlap and no shared local variables are
implicated (#818's hunk references `masked_response`, `X_fix`,
`family_id_vec`; Phase 2 wiring references `tmb_params`, `start_from_fit`,
`warm`, `d_B`/`d_W`).

**Recommended insertion point:** immediately after the existing
`start_from_fit` block, i.e. right after `R/fit-multi.R:4082` (still inside
`gllvmTMB_multi_fit`), guarded by a new `control$vgh_warm_start` (or
equivalent) flag, calling `.vgh_to_laplace_start()`
(`R/vgh-warmstart.R`) and folding its returned `theta_rr_*`/`z_*` entries
into `tmb_params` the same way `.gllvmTMB_apply_start_from()`'s `warm$params`
is folded in at `:4081`. This slots into the existing precedence chain
(`start_method="indep"` → `start_method="res"` → `start_from` → **VGH**) as
the last/highest-priority start source, before the unrelated
`single_trait_warmup` phi-seeding step at `:4852-4863` and well before
`MakeADFun()` at `:4866`.

**What to re-check if #818 merges first:** re-run
`git merge-base HEAD origin/main` and `git diff origin/main...HEAD --
R/fit-multi.R` to confirm the file is still otherwise untouched here; re-read
`R/fit-multi.R:2495-2516`-equivalent region for its new line numbers (#818
adds ~10 net lines, so everything at `:3739` and below shifts down by
roughly that amount) and re-locate `tmb_params` construction (`:3739`),
the `start_from_fit` block (`:3966-4082`), and the
`single_trait_warmup`/`MakeADFun()` pair (`:4852-4866`) by grep rather than
by the line numbers recorded in this doc. No functional re-check is needed
against #818's *content* — it only relaxes an early `masked_response` abort
and does not touch `tmb_params`, `start_from`, `random`, or `MakeADFun`.
