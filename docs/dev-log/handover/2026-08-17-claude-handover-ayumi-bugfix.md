# Codex to Claude handover — Ayumi bug-fix programme

Meta: 2026-08-17 MDT · from Codex · to Claude · repository `itchyshin/gllvmTMB`

You are Claude, taking ownership of the bounded package repair programme exposed by
Ayumi's three newest `Ayumi-495/urbanisation_map` issues. This document is the durable
record; do not rely on the authoring chat.

## Goals / mission

Repair the package behaviours that Ayumi reproduced in real 44-, 67-, and 71-trait
binary GLLVMs, then give her three self-contained replies. Work sequentially, with one
open implementation PR at a time:

1. make ridge convergence diagnostics evaluate the objective actually optimised;
2. fix the three diagnostic/API inconsistencies in Ayumi issue #25;
3. improve the screening and teaching path exposed by issue #23;
4. only then draft replies to Ayumi — do not post without Shinichi's approval.

This is package correctness and usability work for development version 0.7.0. It does
not widen the experimental LA-MSPL evidence claim, make MSPL inference calibrated, or
start a CRAN submission.

## Critical context

1. **Claude has already claimed the first fix lane.** Local branch
   `claude/fix-1092-penalised-gradient` exists at worktree
   `/private/tmp/gllvmtmb-1092-grad`. At this handover it is clean, contains no unique
   commit, and points at `origin/main` commit `40a41e32`. Reuse this lane after running
   preflight; do not open a duplicate #1092 branch.
2. **Ayumi #24 is a confirmed package bug, not user error.** It is identical to package
   issue [#1092](https://github.com/itchyshin/gllvmTMB/issues/1092). No implementation
   PR exists at handover.
3. **Ayumi #25 contains two direct gaps and one dangerously ambiguous contract.** The
   mapped-off-Psi warning is half-fixed on `main`; `fitted.gllvmTMB_multi()` is absent;
   `joint_nll_penalized` names a TMB-side conditional quantity and cannot see the
   R-side loading ridge.
4. **Ayumi #23 changes the analysis, not just the package docs.** Low loading alone is
   not a response-selection criterion. Exact one-hot and nested indicator blocks are
   deterministic response structures and should not be made acceptable by a ridge.
5. **Do not reply yet.** All three Ayumi issues had zero comments at handover. First
   establish the fix/disposition and the analysis recommendation; Shinichi explicitly
   asked for the replies to wait.
6. **`main` is high-churn and multi-lane.** It received 85 commits in the preceding
   12 hours and lane preflight counted 26 live lanes. Re-fetch and reclassify every
   item before editing. The active-lane map, not a single snapshot bullet, owns routing.
7. Previous handover item #1094 is **DONE**: the lognormal saturation-warning fix was
   merged to `main` as `40a41e32` before this handover.

## Source issues

| Source | Status at handover | Package meaning |
| --- | --- | --- |
| [Ayumi #23](https://github.com/Ayumi-495/urbanisation_map/issues/23) | open, 0 replies | higher-order deterministic responses, ridge-path interpretation, MSPL-vs-loading distinction, and low-loading selection correction |
| [Ayumi #24](https://github.com/Ayumi-495/urbanisation_map/issues/24) | open, 0 replies | confirmed unpenalised-gradient convergence bug |
| [Ayumi #25](https://github.com/Ayumi-495/urbanisation_map/issues/25) | open, 0 replies | mapped-off boundary warning, absent native `fitted()` method, joint-vs-marginal objective ambiguity |
| [gllvmTMB #1092](https://github.com/itchyshin/gllvmTMB/issues/1092) | open, bug label, 0 comments | package tracker for the #24 defect |

## What Codex established

### A. Ridge-gradient defect — exact cause

`R/fit-multi.R:5657-5669` wraps the native TMB objective during optimisation:

```r
fn = function(p) base_fn(p) + 0.5 * sum(p[lam_idx]^2) / tau^2
gr = function(p) {
  g <- base_gr(p)
  g[lam_idx] <- g[lam_idx] + p[lam_idx] / tau^2
  g
}
```

The returned fit retains the original unpenalised `tmb_obj`. Consequently:

- `R/diagnose.R:20` calls `object$tmb_obj$gr(object$opt$par)`;
- `R/methods-gllvmTMB.R:2033-2034` does the same in `sanity_multi()`;
- `fit_health$converged` compares that gradient with the ordinary ML tolerance;
- warm-restart and downstream health decisions consume the resulting
  `fit_health$max_gradient`.

At a penalised optimum,

\[
\nabla \ell(\widehat\theta) = -\widehat\Lambda / \tau^2,
\]

which is why Ayumi measured
`reported max_gradient ~= max(abs(Lambda)) / tau^2` across every ridge fit.
The optimiser is not failing; the diagnostic reads the wrong objective.

The code already knows the correct operation in the AGHQ convergence loop at
`R/fit-multi.R:6264-6283`, where the penalty gradient is added explicitly. Do not
create a second ad hoc version of that logic.

### B. Mapped-off Psi warning — half-fixed

`check_gllvmTMB()` now removes unit-tier values with
`object$tmb_data$diag_B_skip == 1` before its `near_zero_psi_unit` calculation
(`R/diagnose.R:1760-1786`). However `.gllvmTMB_boundary_flags()` still loops over raw
`report$sd_B` (`R/diagnose.R:124-176`). The pinned `1e-6` plumbing value therefore
still produces `near_zero_sd_B` although that parameter is not estimated.

The default auto-Psi skip and explicit `latent(..., unique = FALSE)` describe the same
fitted model in Ayumi's Bernoulli case. They must have identical boundary diagnostics.

### C. Native `fitted()` is absent

`NAMESPACE` registers `fitted` methods only for `gllvmTMB_julia` and `gllvmTMB_va`.
It registers `predict.gllvmTMB_multi`, but no `fitted.gllvmTMB_multi`, so the generic
falls through to a nonexistent fitted-values slot and returns `NULL`.

### D. `joint_nll_penalized` is not the loading-ridge objective

`src/gllvmTMB.cpp:3327` snapshots `joint_nll_unpenalized`; line 3460 snapshots
`joint_nll_penalized` after TMB-side penalty additions. The loading ridge is added in R,
outside that tape, so both fields can legitimately be identical on a ridge fit.

`fit$objective_components` is the existing R-side decomposition:

- `likelihood_nll`: marginal unpenalised objective;
- `ridge_penalty`: R-side loading penalty;
- `optimization_nll`: their sum.

Do not equate the C++ **conditional joint NLL** with the Laplace/AGHQ **marginal
optimisation NLL**. Ayumi's numbers differ for that reason. The defect is the ambiguous
surface and missing scope documentation, not merely a missing arithmetic addition.

### E. Higher-order response dependencies

`screen_gllvmTMB()` catches sparse traits and pairwise duplicates/complements, but not
affine dependencies such as `A + B + C = 1` or nested indicator systems. Ayumi has
one-hot review-type, geographic-scope, and temporal-scope blocks plus nested realm
indicators. A pairwise screen cannot detect these.

## Key decisions and recommended implementation

### Slice 1 — P0: objective-consistent ridge diagnostics

Preferred bounded repair: keep the ridge R-side for now, but establish one internal
definition of the objective and gradient actually optimised. Moving the penalty into C++
would widen this correctness repair into TMB parameterisation and retaping work.

1. Add one helper, for example
   `.gllvmTMB_objective_gradient(object, objective = c("optimization", "likelihood"))`.
2. Centralise the exact penalised indices used by `run_one()`; audit both
   `theta_rr_B` and `theta_rr_spde_lv`, not only Ayumi's ordinary B tier.
3. Preserve two signals:
   - `max_gradient_optimization`: authoritative stationarity;
   - `max_gradient_likelihood`: unpenalised pressure, useful for diagnosing how much the
     penalty determines the solution.
4. Keep `max_gradient` as a compatibility alias for the optimisation gradient in 0.7.0;
   document the change rather than silently changing downstream meaning.
5. Route `fit_health$converged`, `check_gllvmTMB()`, `sanity_multi()`, warm-restart
   eligibility, profile/certificate guards, and campaign health scoring through the
   optimisation gradient. Use `rg`, not assumptions, to inventory every reader.
6. Do not weaken `.gllvmTMB_converged_gtol`; this is an objective mismatch, not a
   tolerance problem.

Required regression tests:

- construct a small ridged fit whose raw gradient fails the old tolerance;
- show penalised gradient is near zero;
- show raw loading-gradient entries equal `-Lambda / tau^2` within tolerance;
- verify `fit_health$converged` follows the penalised gradient;
- verify both gradients are retained and labelled;
- cover Laplace ridge and AGHQ ridge;
- cover no-ridge identity/backward compatibility;
- ensure a strong-ridge fit with non-positive-definite Hessian still reports that
  inference warning rather than becoming universally healthy;
- guard every penalised loading block accepted by `run_one()`.

After the fix, re-adjudicate Design 122 K1 from retained data if the saved rows contain
the required parameter values. Do not rerun 21,600 fits merely to repair an instrument.
If a rerun becomes necessary and is estimated above 30 minutes, stop after a pre-run
test and ask Shinichi for approval.

### Slice 2 — Ayumi #25 API and diagnostic repair

Land only after Slice 1, in a separate PR.

1. **Mapped-off components:** add one internal accessor for estimable/effective variance
   components using `tmb_map` and the skip masks. Use it in both generic boundary flags
   and component-specific check rows. Test default auto-skip versus explicit
   `unique = FALSE`, plus a mixed-family case where only selected traits are skipped.
2. **Native fitted values:** add and register `fitted.gllvmTMB_multi()`. Make it a thin,
   documented in-sample response-scale route through `predict.gllvmTMB_multi()`, while
   preserving model-row/trait identity. Decide and test the contract explicitly for
   long and wide inputs, missing cells, mixed families, and multinomial models; never
   return silent `NULL`.
3. **Objective provenance:** keep the existing C++ report fields for compatibility, but
   document that they are TMB-tape conditional quantities. Expand the official R-side
   decomposition with unmistakable conditional-joint versus marginal-optimisation
   names. Test no penalty, loading ridge, AGHQ ridge, and MSPL; the refused
   MSPL-plus-loading-ridge hybrid must remain refused.

### Slice 3 — screening and teaching response to Ayumi #23

This is important but follows correctness work.

1. Add a bounded exact affine-rank check on the augmented response matrix `[1, Y]`,
   using base-R QR/null-space logic and a documented numerical tolerance.
2. Report human-readable dependency certificates where possible, especially constant-sum
   groups such as `A + B + C = 1`. Do not promise exhaustive minimal-subset discovery;
   arbitrary subset enumeration is combinatorial. A user-supplied known-group check is a
   safer companion for questionnaire/item-bank data.
3. Add a tested ridge-strength path workflow. Label it sensitivity evidence: an interior
   plateau supports data-determined estimation, continued boundary movement shows that
   the penalty is determining the estimate. It is not an identification certificate.
4. Strengthen prose that `suggest_lambda_constraint()` supplies an identification
   convention; it does not discover biological factor structure or justify deleting
   low-loading responses.
5. Add one explicit intercept-only contrast: MSPL targets fixed-effect separation;
   loading ridge targets latent-loading runaway; neither makes an exactly deterministic
   response block valid.

Analysis consequence to carry into the later reply:

- restore or re-evaluate the seven indicators excluded only for low loadings;
- treat the former 44-indicator, loading-selected set as sensitivity evidence unless a
  substantive inclusion rule independently supports it;
- do not restore one-hot blocks as independent Bernoulli traits merely because ridge
  makes estimates finite — use a single multinomial response or a deliberate reference
  representation, according to the scientific estimand;
- keep the two runaway indicators excluded/restructured unless the ridge path reaches an
  interior, data-determined solution.

## Expected implementation touchpoints

Re-measure each file before editing; these are expected touchpoints, not permission to
change them all in one PR.

- `R/diagnose.R`
- `R/fit-multi.R`
- `R/methods-gllvmTMB.R`
- `R/screen-gllvmTMB.R`
- `NAMESPACE` and the appropriate roxygen source / generated `man/*.Rd`
- `tests/testthat/test-loading-ridge-disclosure.R`
- `tests/testthat/test-screen-gllvmTMB.R`
- new focused tests for ridge health, native `fitted()`, mapped-off components, and
  objective provenance
- `vignettes/articles/mspl-binary-jsdm.Rmd`
- `vignettes/articles/pre-fit-response-screening.Rmd`
- `vignettes/articles/lambda-constraint-suggest.Rmd`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- one after-task report per completed PR/phase

Because `R/`, `NAMESPACE`, vignettes, the validation register, check-log, design docs and
after-task directories are shared surfaces, run both the repo-level lane preflight and
`--file` checks immediately before editing them.

## What was accomplished in the Codex handover session

- read all 39 open gllvmTMB issues and grouped the immediate versus programme debt;
- read Ayumi issues #23, #24 and #25 in full;
- independently traced all four package behaviours through current `origin/main`;
- established that #24 is exactly package #1092;
- found and protected the already-created Claude #1092 branch;
- refreshed `origin/main` and verified #1094 is merged;
- created this docs-only handover and added its lane to the multi-lane split;
- made no package-code, test, vignette, issue-comment, or Ayumi-repository change.

## Current working state

- **Working:** current `origin/main` at handover is `40a41e32`; the latest relevant
  package check before this handover was green, but recheck live CI because main moves.
- **In progress:** no implementation diff exists yet on
  `claude/fix-1092-penalised-gradient`.
- **Blocked:** none technically. The only coordination constraint is to reuse the claimed
  Claude lane and avoid the many foreign lanes.
- **Replies:** deliberately not written or posted.

## Landing State

The handoff gate was run before this document was written. It returned non-zero because
the repository contains roughly 450 historical/unpushed commits on other branches. The
new handover worktree itself was clean and exactly `0 0` relative to `origin/main`.
Those foreign branches are declared **PROTECTED** and are not part of this handover.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `origin/main` `40a41e32` | yes | yes | #1094 merged | LANDED — starting point at handover |
| `claude/fix-1092-penalised-gradient` at `/private/tmp/gllvmtmb-1092-grad` | no unique commit | no remote branch | none | CARRIED-OVER — Claude-owned empty implementation lane; recheck before reuse |
| `claude/handover-20260817` `b65192f3` | yes | yes | #1103 open at handover | PROTECTED — evidence/diagnostics handover; read, do not rewrite from this lane |
| `codex/handover-ayumi-bugfix-20260817` | pending at document authoring | pending | pending | this docs-only handover branch; final state must be read from git/PR |
| primary Dropbox checkout `cursor/cloud-agent-1786753856541-jx2lb` | no | no | none | PROTECTED — dirty `.gitignore`, `.worktrees/`, `dev/isdm-package-recovery/`; never stage or clean |
| all other branches reported by `handoff_gate.sh` | mixed | mixed | mixed | PROTECTED foreign state; not owned by this programme |

For the #1092 carried-over lane, the exact resume command is:

```bash
cd /private/tmp/gllvmtmb-1092-grad
bash ~/shinichi-brain/tools/lane_preflight.sh .
git fetch origin main
git status --short --branch
git log --oneline --decorate -8
```

If another session has added work there, classify it before touching anything. If it
remains clean at `origin/main`, continue Slice 1 on that branch.

## Files created / modified by this handover session

- `docs/dev-log/handover/2026-08-17-claude-handover-ayumi-bugfix.md` — this
  authoritative handover.
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` — prepended one bounded
  Ayumi bug-fix lane entry; existing sibling lanes retained unchanged.

No package source, test, generated documentation, vignette, issue, PR, or external
repository was modified.

## Next Immediate Steps

On receipt, classify these against live git as `OWED`, `DONE`, `RETRACTED`, or
`PROTECTED`, and execute only `OWED`.

1. Run lane preflight from the real repository and from
   `/private/tmp/gllvmtmb-1092-grad`; fetch `origin/main`; inspect any new diff and PR.
2. Read `AGENTS.md`, the active-lane split, this handover, package issue #1092, and
   Ayumi #24. Mark #1094 `DONE` and the unrelated MSPL/diagnostics lanes `PROTECTED`.
3. Implement Slice 1 on `claude/fix-1092-penalised-gradient`, starting with a regression
   test that fails on the current unpenalised-gradient behaviour.
4. Run focused tests, `devtools::document()`, full tests, `pkgdown::check_pkgdown()`, and
   affected article rendering as required. Claude may use CI for compiled checks if its
   environment lacks the live R/TMB toolchain; record that boundary honestly.
5. Commit, push and open one focused PR for #1092. Do not merge automatically. Wait for
   CI and review before opening Slice 2.
6. Re-adjudicate Design 122 K1 from retained rows if possible; do not launch a campaign
   without the >30-minute estimate/pre-run/approval gate.
7. After Slice 1 lands, create a fresh branch for Slice 2 and address Ayumi #25.
8. After Slice 2 lands, create a fresh branch for Slice 3 and address Ayumi #23.
9. Draft three separate replies only after their corresponding package/analysis
   disposition is stable. Present drafts to Shinichi; do not post until asked.

## Blockers / open questions

- Decide the exact return shape of `fitted.gllvmTMB_multi()` from existing prediction
  contracts before exporting the method. Do not infer it only from Ayumi's wide case.
- Decide whether R-side objective provenance is best expressed by expanding
  `objective_components` or by an additional clearly named conditional-joint component.
  Backward compatibility rules out silently changing the existing C++ field meaning.
- Decide whether higher-order dependency reporting begins with rank-deficiency plus a
  certificate, or also accepts user-supplied indicator groups in the first slice. Avoid
  an exhaustive subset-search API.
- Shinichi should decide the final primary indicator set for the urbanisation analysis;
  the package cannot convert loading magnitude into a biological inclusion rule.

## Gotchas / failed approaches

- Do not "fix" #1092 by loosening the gradient tolerance. The wrong objective is being
  differentiated.
- Do not simply overwrite `report$joint_nll_penalized` with
  `likelihood_nll + ridge_penalty`; one is conditional joint, the other marginal.
- Do not let mapped-off placeholder values enter either absolute or relative-collapse
  comparisons.
- Do not return a bare prediction vector from `fitted()` without resolving long/wide row
  identity and missing-cell behaviour.
- Do not use low loadings as automated variable selection or describe a varimax threshold
  as a biological cutoff.
- Do not treat finite ridge estimates as evidence that deterministic one-hot responses
  are valid independent Bernoulli traits.
- Do not edit the dirty primary Dropbox checkout or foreign MSPL/iSDM lanes.
- Do not push several fix-up commits while auto-cancel CI is active; wait for the current
  run before pushing the next correction.

## Mission-control summary

| Repository | Branch / main | CI and live state | What this handover ships | Plan by leverage |
| --- | --- | --- | --- | --- |
| `itchyshin/gllvmTMB` | `origin/main` `40a41e32`; empty claimed implementation lane `claude/fix-1092-penalised-gradient`; docs handover lane `codex/handover-ayumi-bugfix-20260817` | 26 live lanes at preflight; handoff gate non-zero only because of declared foreign branches; recheck current CI | no code; durable diagnosis, ownership, tests and three-slice repair programme | #1092 objective gradient -> Ayumi #25 API/diagnostics -> Ayumi #23 screen/docs/analysis -> reply drafts |

## How to Resume

Start a fresh Claude session from the existing #1092 worktree. Claude does not inherit
this chat, so paste the prompt below after ensuring this handover branch/PR is fetchable:

```bash
cd /private/tmp/gllvmtmb-1092-grad
claude "Read AGENTS.md and docs/dev-log/handover/2026-08-17-claude-handover-ayumi-bugfix.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps."
```

Read AGENTS.md and docs/dev-log/handover/2026-08-17-claude-handover-ayumi-bugfix.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
