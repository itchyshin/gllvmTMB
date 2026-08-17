# Codex to Claude handover — finish issue #1092 only

Meta: 2026-08-17 MDT · from Codex · to Claude · repository `itchyshin/gllvmTMB`

This is the current execution handover. It supersedes the immediate scope in
`2026-08-17-claude-handover-ayumi-bugfix.md`, which remains background for the
deferred Ayumi #25 and #23 work. Do not infer authority to begin those later slices.

## Goals / mission

Finish the already-implemented loading-ridge gradient repair for package issue
[#1092](https://github.com/itchyshin/gllvmTMB/issues/1092) from its two local commits
through verification, closure records, a focused pull request, and CI. Then stop and
hand the lane back to Shinichi/Codex.

The owned outcome is narrow:

1. independently verify the #1092 implementation and regression test;
2. add the required check-log and after-task records, and audit whether NEWS or other
   user-facing documentation is needed for the changed diagnostic semantics;
3. run proportionate package checks;
4. finish and monitor the already-open PR #1106 through a green review handoff;
5. do not merge automatically, start Ayumi #25/#23, or reply to Ayumi.

## Critical context

1. The active implementation worktree is
   `/private/tmp/gllvmtmb-1092-grad` on
   `claude/fix-1092-penalised-gradient`. At the latest inspection its two commits
   matched the pushed remote branch, with only an untracked active-run `.check.log`:
   - `e51738c9` — `fix(#1092): gradient reporting judges the objective the fit actually optimised`
   - `bb6d1bdc` — `docs(register): restore the DIA-11/DIA-12 rows that b4c9109e silently reverted`
2. Both commits are now pushed and PR
   [#1106](https://github.com/itchyshin/gllvmTMB/pull/1106) is open. Its
   `R-CMD-check` run
   [32067467202](https://github.com/itchyshin/gllvmTMB/actions/runs/32067467202)
   was in progress at the latest refresh. This is still **CARRIED-OVER**, not landed
   work.
3. The code commit reports that the focused regression test passes 11/11 after the
   repair and that 3/11 assertions fail before it. Codex inspected the commit but did
   **not** independently rerun the test. Claude must verify it rather than repeating
   the claim as new evidence.
4. The worktree now has an untracked `.check.log`, and the PR says the local
   `devtools::check(args = "--no-manual")` is running. Treat the lane as actively
   owned by Claude; do not touch or remove that file. The branch still lacks the
   required issue-specific entry in
   `docs/dev-log/check-log.md` and lacks an after-task report under
   `docs/dev-log/after-task/`.
5. The repository is highly concurrent. Lane preflight saw 28 live lanes. In
   particular, `claude/1080-dispersion-naming` and
   `claude/1082-one-worked-example` are separate active work and are **PROTECTED**.
   Re-run preflight before touching the #1092 worktree and obey its verdict.
6. `origin/main` was `40a41e32` at the latest reconciliation. Fetch and reconcile
   before claiming that remains current.
7. There must be no reply on Ayumi #24 yet. Shinichi asked that the package repair be
   established first.

## What has been accomplished

### Implementation commit `e51738c9`

The commit adds `.gllvmTMB_penalised_gradient(obj, par, ridge_tau)` beside the
objective-component logic and routes the following diagnostics through the gradient
of the objective actually optimised:

- `fit_health$max_gradient` and its convergence/stationarity judgement;
- `sanity_multi()`;
- the AGHQ loop's `g_cur` and `g_last` calculations.

It deliberately leaves warm-restart/ISDM raw-gradient logic unchanged because ridged
fits are explicitly ineligible there. It also records whether the reported gradient
is penalised, while the unpenalised diagnostic remains available directly from
`tmb_obj$gr()`.

The motivating Bernoulli toy fit recorded in the commit has raw maximum gradient
`0.4362628`, expected ridge pressure `max(abs(Lambda)) / tau^2 = 0.4362503`, and
penalised maximum gradient approximately `1.9e-05`. The regression test also includes
the `tau = Inf` identity case. Treat these as commit-recorded results until rerun.

### Register-restoration commit `bb6d1bdc`

The second commit restores the DIA-11 and DIA-12 validation-debt rows that an earlier
commit silently reverted. Review that restoration as part of this PR; do not drop it
merely because it is documentation rather than #1092 implementation.

### Design 122 retrospective

`docs/dev-log/2026-08-17-design122-k1-reread-infeasible.md` records that a
retrospective corrected K1 re-read is impossible from the retained 21,600 scalar rows:
the correction requires full per-fit parameter and gradient vectors.

- L2's 100% breach is an instrument mismatch; TEST A already passed 7,200/7,200 and
  supports stationarity.
- L0 is not changed by #1092. Its 35.96% breach reflects a stricter unscaled `1e-3`
  criterion; 0.89% exceed the package's `1e-2` criterion.
- The safe default is to retain the existing adjudication with a permanent caveat.
  A small sentinel rerun may strengthen it, but is a separate maintainer choice.

Do not start a rerun in this lane. A full rerun is a compute campaign and would require
the D-139 estimate, pre-run test, and Shinichi's approval; it must run on Totoro/DRAC,
never GitHub Actions.

## Current state

### Working

- The implementation and focused regression test are committed and pushed; the only
  observed untracked worktree item is Claude's active-run `.check.log`.
- The fix keeps the ridge in R and centralises the penalised-gradient calculation;
  it does not widen the repair into TMB parameterisation or retaping.
- The validation-register restoration is a separate, explicit commit.

### In progress / not yet proven

- No independent post-commit test run is recorded by Codex.
- A local R CMD check is reportedly running, but its completed result is not yet
  recorded. No full package test, documentation check, or pkgdown result is recorded
  for the two-commit branch.
- No issue-specific check-log or after-task report exists.
- The branch is pushed and PR #1106 is open; its first GitHub CI run is in progress,
  not yet evidence of a green package gate.

### Blocked decisions

- Design 122: choose later between (a) permanent caveat, (b) full rerun, or (c) small
  sentinel rerun. Fisher's recommendation and the safe default are (a), optionally
  strengthened by (c). This does not block landing the #1092 code fix.
- During review, confirm that the disclosure field plus direct `tmb_obj$gr()` access
  are sufficient for compatibility. Do not invent a larger public diagnostic API in
  this PR unless the current implementation is demonstrably inadequate.

## Key decisions already made

1. Keep the loading ridge in the R optimisation wrapper for this fix.
2. Use one internal penalised-gradient helper rather than duplicate arithmetic at
   every diagnostic call site.
3. `fit_health$max_gradient` means the gradient of the objective actually optimised.
   Do not weaken the convergence tolerance to hide the mismatch.
4. Preserve access to the raw likelihood gradient via `tmb_obj$gr()` and disclose
   when the reported health gradient includes the penalty.
5. Treat the register restoration as owned branch state and review it explicitly.
6. Finish #1092 only. Ayumi #25, Ayumi #23, and collaborator replies are deferred to
   a fresh lane after maintainer review.

## Files created or modified in the carried implementation

Codex did not edit these implementation files; it inspected the two Claude commits.

| File | State / purpose |
| --- | --- |
| `R/diagnose.R` | penalised-gradient helper and diagnostic routing |
| `R/fit-multi.R` | fit-health and AGHQ stationarity use the optimised objective |
| `R/methods-gllvmTMB.R` | `sanity_multi()` uses the same gradient contract |
| `tests/testthat/test-penalised-gradient-1092.R` | focused regression coverage |
| `docs/design/122-va-vs-laplace-recovery.md` | Design 122 interpretation update |
| `docs/design/35-validation-debt-register.md` | #1092 evidence plus restored DIA rows |
| `docs/dev-log/2026-08-17-design122-k1-reread-infeasible.md` | limits of retrospective K1 correction |

This handover lane additionally updates:

- `docs/dev-log/handover/2026-08-17-claude-handover-1092-finish.md`;
- `docs/dev-log/handover/2026-07-25-active-lane-split.md`.

## Landing-state ledger

| Branch / item | Commit | Committed? | Pushed? | PR / CI | Status and action |
| --- | --- | --- | --- | --- | --- |
| `origin/main` | `40a41e32` at last fetch | yes | yes | main CI was still running at snapshot | LANDED baseline; fetch again |
| `claude/fix-1092-penalised-gradient` | `e51738c9`, `bb6d1bdc` | yes | yes | PR #1106; CI run 32067467202 in progress | **CARRIED-OVER**; Claude owns finishing only |
| `codex/handover-ayumi-bugfix-20260817` | PR #1105 plus this refinement | yes | handover update pending | #1105 previously green | handover-only lane; no implementation |
| primary Dropbox checkout | unrelated accumulated work | mixed | mixed | multiple lanes | **PROTECTED**; do not clean, stage, or switch it |
| all other live Claude/Cursor/Codex branches | varied | varied | varied | varied | **PROTECTED**; never absorb or revert |

Exact resume command for the carried implementation:

```sh
cd /private/tmp/gllvmtmb-1092-grad
bash ~/shinichi-brain/tools/lane_preflight.sh .
git fetch origin main
git status --short --branch
git log --oneline --decorate origin/main..HEAD
```

If preflight reports ownership by another surface, or the worktree contains changes
beyond Claude's expected `.check.log`, stop and reconcile with Shinichi rather than
editing through the collision.

## Next immediate steps — OWED, in order

1. Run the resume commands above and inspect both commits against the newly fetched
   `origin/main`. Preserve unrelated lane state.
2. Review the full diff, including every reader of `fit_health$max_gradient` and both
   penalised loading blocks. Confirm the helper matches the penalty used by the
   optimiser and that non-ridged behaviour is unchanged.
3. Rerun the focused regression test:

   ```sh
   Rscript --vanilla -e 'devtools::test(filter = "penalised-gradient-1092")'
   ```

   Record the exact command, counts, warnings, and failures. If the filter does not
   select the intended file, correct the invocation and document both attempts.
4. Add the required #1092 entry to `docs/dev-log/check-log.md` and create a compliant
   after-task report under `docs/dev-log/after-task/`. Explicitly audit whether NEWS,
   roxygen, or other user-facing documentation is required because
   `fit_health$max_gradient` semantics changed; do not silently skip that decision.
5. Run, at minimum, documentation generation/check, the full test suite, and
   `pkgdown::check_pkgdown()`. Run the proportionate local R CMD check required by the
   package contract. Record exact outcomes and anything deliberately not run.
6. Let the currently running local check and PR CI finish before deciding on changes.
   Record their exact results; a cancelled run is a pacing result, not a test failure.
7. Inspect `git status` and the final diff. Stage explicit owned paths only; never use
   `git add -A` and do not stage `.check.log`. Commit the closure records, then wait for
   any active PR run to finish before one deliberate push to PR #1106.
8. Monitor the resulting package CI. Do not push fix-up commits while an earlier run is
   active. Do not auto-merge; hand the green PR back to Shinichi for review.
9. Stop. Report the Design 122 choice as a follow-up decision with safe default (a).
   Do not launch compute, start Ayumi #25/#23, or post any Ayumi reply.

## Blockers and questions for the maintainer

1. After #1092 is review-ready, should Design 122 retain the existing adjudication
   with a permanent caveat (recommended), or should a separately approved sentinel
   rerun be planned?
2. After #1092 is landed, who owns the next fresh lane: Claude, Codex, or the main
   gllvmTMB lane? Do not assume the answer by continuing into Ayumi #25.

Neither question blocks completing and opening the #1092 PR.

## Risks and gotchas

- Do not reinterpret a nonzero raw loading gradient as optimiser failure when the
  R-side ridge is active; at the penalised optimum it balances `Lambda / tau^2`.
- Do not fix the problem by weakening `.gllvmTMB_converged_gtol`.
- Do not move the ridge into C++ in this bounded repair.
- Do not let the corrected stationarity signal suppress Hessian or inference warnings.
- Do not describe the 21,600 retained scalar rows as sufficient for corrected K1
  reconstruction; the necessary vectors were not retained.
- Do not start a full or sentinel campaign without a fresh, approved compute plan.
- Do not reply to Ayumi or close her issues from this lane.
- Do not edit, clean, rebase, or stage another live worktree's files.

## Mission-control handoff

| Lane | State | Owner | Next action |
| --- | --- | --- | --- |
| gllvmTMB #1092 loading-ridge gradient | active; PR #1106 open, checks running | Claude | verify, close records, CI, then stop |
| Design 122 K1 retrospective | decision pending; no compute authorised | Shinichi | accept caveat by default or commission sentinel later |
| Ayumi #25 | deferred | unassigned after #1092 | fresh-lane decision |
| Ayumi #23 | deferred | unassigned after #25 | fresh-lane decision |
| Ayumi collaborator replies | explicitly held | Shinichi | approve only after package dispositions are established |
| all other gllvmTMB lanes | protected | their current owners | no action from this handover |

## How to resume safely

1. Read the repository `AGENTS.md` and this handover in full.
2. Run the exact resume block under **Landing-state ledger**.
3. Reconcile branch, worktree, issue, PR, and CI state against the live repository.
4. Execute only the numbered **Next immediate steps — OWED**.
5. At the end, run the repository handoff/after-task gates and leave a durable return
   handover. Stop before Ayumi #25 even if #1092 is green.

Read AGENTS.md and docs/dev-log/handover/2026-08-17-claude-handover-1092-finish.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
