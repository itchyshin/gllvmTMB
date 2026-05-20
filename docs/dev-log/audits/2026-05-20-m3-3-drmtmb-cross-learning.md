# M3.3 drmTMB Cross-Learning Audit

Date: 2026-05-20
Branch: `codex/m3-3-drmtmb-cross-learning-2026-05-20`
Lead: Ada
Active perspectives: Ada, Jason, Fisher, Curie, Grace, Pat, Florence,
Rose, Shannon
Spawned subagents: none

## Purpose

This maintainer checkpoint asked whether it is time to check what the
drmTMB team is doing and learn from them before continuing the M3.3
sequence. The answer is yes. The M3.3 NB2 diagnostics have reached the
same kind of roadmap boundary drmTMB hit before Phase 18: broad
simulation is less useful than a surface-by-surface admission gate until
the estimand, interval method, fit failure mode, and reporting surface
are clear.

This is a read-only cross-learning audit. It does not change code,
formula grammar, likelihoods, tests, or advertised capability status.

## Source State Read

gllvmTMB:

- PR #213 merged the fitted `phi_nbinom2` and link-residual diagnostic
  columns.
- PR #214 merged the development-only known-phi point diagnostic.
- Design 42 now records `fit_phi_mode` and `n_boot = 0` for point-only
  diagnostics.
- Design 49 already states the hard-fit policy: `pdHess = FALSE` is an
  inference and identifiability warning, not automatic proof that point
  estimates are useless.

drmTMB:

- The local sister repo was on
  `codex/slices-363-full-ayumi-starts` with uncommitted changes, so the
  audit treated it as read-only evidence.
- The drmTMB roadmap keeps broad Phase 18 closed until surface-specific
  evidence exists. After Slice 202, it permits only narrow Poisson/NB2
  `mu` random-effect pilots before returning to Phase 17 hardening.
- Recent drmTMB after-task reports show small real staging grids,
  method-labelled Wald/profile/bootstrap rows, failure ledgers,
  rendered report audits, and Florence figure checks before scaling.
- The Ayumi bootstrap positive-control report keeps hard-fit semantics
  separate: a boundary q4 fallback stays in the diagnostic ledger, while
  the cleaner location-only model becomes the example path.

## Lessons To Import

1. **Rename the next M3 step.** The next work is not "rerun M3." It is
   an M3.3b surface-admission programme. The previous wording could
   steer work toward spending compute before the statistical target is
   stable.
2. **Admit surfaces one at a time.** A family/rank/target surface
   should enter a larger grid only after it has a fitted likelihood,
   target-specific estimand, interval method, diagnostics, failure
   ledger, and small-run evidence.
3. **Keep method labels visible.** Wald, profile, bootstrap, and
   known-phi point diagnostics answer different questions. They should
   never share a coverage column unless the refit path preserves the
   same estimand.
4. **Treat hard fits as evidence, not as a binary pass/fail.** NB2
   dispersion underestimation, weak variance, boundary Hessians, and
   bootstrap failures are signals to classify. They are not reasons to
   flatten the whole model class into "failed."
5. **Render tiny reports before scaling.** drmTMB's first-wave reports
   exposed plot-label and warning-ledger problems while the runs were
   still small. gllvmTMB needs the same Florence gate for M3 diagnostic
   figures.
6. **Treat visualization as inference infrastructure.** This matters
   more for gllvmTMB than for drmTMB. A weak plot can hide rank,
   trait-level bias, fitted-dispersion drift, rotation-sensitive
   summaries, and bootstrap failure structure. Florence should enter
   the M3 diagnostic lane before the later Phase 1c-viz layer.
7. **Close with an honest ledger.** If a surface remains partial, the
   validation-debt register and roadmap should say so in the same
   language as the audit and article.

## Proposed M3.3b Slice Map

| Slice | Lane | Done When |
|---|---|---|
| 1 | Surface-admission spec | A short design/audit file names the allowed estimands, fit modes, interval methods, and failure-ledger columns for M3.3b. |
| 2 | NB2 variance-dispersion stress map | A small point-only grid varies `phi`, `Sigma_unit_diag`, sample size, and rank under estimated versus known phi. |
| 3 | Fixed-phi bootstrap design | Gauss/Noether/Fisher decide whether to add mapped-parameter bootstrap refits or keep known-phi as point evidence only. |
| 4 | Diagnostic report scaffold | A tiny rendered report shows estimate/truth, fitted phi/truth, link residuals, failures, and method labels. |
| 5 | Florence figure gate | The report plot style passes a visual audit before any r50 or r200 run; tables are not enough for M3 latent/covariance diagnostics. |
| 6 | NB2 r50 go/no-go | Only if the first five slices pass, run a moderate NB2 operating-characteristics grid. |
| 7 | Validation-debt update | EXT-13 / CI-08 / CI-10 stay partial unless target-explicit coverage clears the gate. |

## Roadmap Call

M3.3 remains red. M3.4 remains partial. The known-phi evidence is useful
because it identifies dispersion estimation as a major contributor, but
it is point-estimate evidence only. The next broad compute action should
wait until M3.3b defines the surface-admission gate.

## Shannon Coordination Note

At the start of this lane:

- `gh pr list --repo itchyshin/gllvmTMB --state open` returned no open
  PRs.
- `git log --all --oneline --since="6 hours ago"` showed the recent
  M3.3a merge chain through PR #214.
- The main branch R-CMD-check for PR #214 passed before this branch
  was pushed. The pkgdown deploy from the same merge was still running,
  so this docs branch stayed limited to ignored-source roadmap and
  dev-log files.
