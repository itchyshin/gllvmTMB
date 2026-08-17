# Plan-vs-Actual Reconciliation: multinomial() structured-dependency arc

**Reconciler**: Melissa (plan-vs-actual, receipt-based, material deviations only)
**Date**: 2026-08-16
**Arc**: gllvmTMB multinomial (fid 16) structured-dependency admission + fence
  soundness (Design 122)
**Plan**: `/Users/z3437171/.claude/plans/for-ordered-cateogrical-structure-noble-parasol.md`
**Branch / worktree**: `claude/multinomial-structured-20260816` @
  `/private/tmp/gllvmtmb-multinomial-structured`
**PR**: [#1057](https://github.com/itchyshin/gllvmTMB/pull/1057) — **OPEN, not
  merged** as of this reconciliation (`mergedAt: null`); all six slices
  (0–5) plus the D-43 repair round are landed on the branch per
  `git log origin/main..HEAD` (39 commits, `9467e4e8`..`0ead9fab`).

## Six-axes table

| Axis | Planned | Actual | Classification |
|---|---|---|---|
| **Scope** | Slices 0→1→2→{3∥4}→5; deliverable = admitted grid (animal/phylo/kernel × latent/dep/indep; spatial × latent/indep/dep; `(1\|g)`+cluster; `*_scalar` refused), each recovery-gated. | All slices delivered as scoped. S3∥S4 ran **serially, and out of number order** (S4 landed first: `848fbb28`..`b7b94750`; S3 landed after: `d0846dea`..`8c4771ab`) — after-task states this explicitly ("landed after Slice 4 in this worktree despite its number"). One supplementary cell (s1b, n_sp=300×n_rep=5 replication rescue) added mid-arc, approved in-session (DECISIONS LOCKED #5, "Yes go ahead"). Sub-agent dispatch detail (S3 reused the s2-builder child rather than spawning new, within the plan's ≤6-child budget) is orchestration metadata not visible in committed git artifacts — asserted, not independently git-verifiable here. | **Adaptive** — serial execution and the s1b addition are both disclosed and plan-consistent (FAN-OUT BUDGET allows reuse; s1b required and received explicit maintainer sign-off). |
| **Evidence/verification** | 20-seed recovery campaigns, local-timing-fit-then-Totoro, D-139 estimate before every campaign, pre-registered frozen bands, honest-SKIP on non-PD, rail rate reported separately. | Measured 65.6 s/fit (`dev/multinomial-structured/README.md:87`) put full 40-fit campaigns at ~2.2–8 min — under the 30-min D-139 line — so **every campaign ran locally**, never Totoro; this is the plan's own D-139 branch, not a bypass. s2 `phylo_indep` was as-run with a DGP mismatch (correlated truth fed to a diagonal-truth cell); caught, disclosed openly rather than silently absorbed, corrected rerun executed, and the generating script (`rerun-s2-indep-corrected.R`) was committed (`899dc9c7`) only after a D-43 panel provenance finding flagged its absence. s1b's own pre-registration (criteria + results) landed in a single commit (`438a156f`), so git cannot independently verify criteria predated results — self-disclosed as "not git-verifiable" (D-43 R6, `0e2ea92f`). 3 pre-existing full-suite test failures (`test-control-field-surface.R`, 2×`test-mspl-poisson-phase4-oracles.R`) left unfixed and named individually in the after-task (§6), consistent with the out-of-lane scope discipline. | **Adaptive** for the local/Totoro branch and the caught-and-corrected DGP mismatch (both match plan discipline in spirit and letter). **Drift (disclosed, low-severity)** for s1b's provenance gap — the plan's "signed off by Shinichi before the register row ships" requirement is met on substance but not on git-verifiable sequencing; already self-flagged in the artifact, no further action taken or apparently possible after the fact. |
| **Model routing** | Slice table: builders Sonnet·med, S0-verify Rose Opus·high, RECON/MECH-VERIFY Haiku, D-43 PANEL 2×Sonnet+1×Opus, orchestrator Fable. | After-task roles match: "Claude Fable 5 (implementation)"; S0-verify was Opus adversarial ×2 rounds; D-43 panel returned 2×NOT-DONE+1×DONE (matching the 2 Sonnet + 1 Opus composition). No routing deviation found. | **No material deviation** — routing as planned. |
| **Safety gates** | D-43 panel fires ONCE at arc close, before promoting any register claim; high-risk fence change → maintainer sign-off before merge. | Panel fired once (`f3a1506c`), found 10 findings (R1–R10: 2 code, 8 docs), one consolidated repair loop, bounded re-checks CLEAR — except one factual-precision finding (spatial_indep collapse sub-count) fixed directly by the orchestrator using the reviewer's own recount (`0ead9fab`) rather than convening a third panel round. Slice 0's fence itself was adversarially reviewed **twice** before the D-43 panel (8 findings → repair → CLEAR ×8), an extra verification layer the plan's slice table did not explicitly call for beyond one S0-verify pass. Maintainer merge sign-off was **granted** (DECISIONS LOCKED #1) but **not yet exercised** — PR #1057 remains open/unmerged. | **Adaptive** for the extra Slice-0 review pass and the single-finding direct-fix (bounded, reviewer's own numbers, no new judgment call). **Handoff-state item, not drift**: merge sign-off is granted-but-pending, consistent with the plan's own condition ("exercised at arc completion, after S3+campaigns+S5 land") now that those have landed — the merge itself is the one action still outstanding. |
| **Public claims** | `*_scalar` refused (stats-review blocking finding); no calibrated-interval claim on any cell; FAILs reported without softening, PASSes without strengthening. | Register FAM-20/20C–F rows confirm `*_scalar`/`common=TRUE` at cluster tiers stay REFUSED as a named carve-out with null-DGP evidence, matching the plan exactly. FAM-20C/D FAIL verdicts (rail rates, small-variance collapse) and FAM-20E/F PASS verdicts are both stated with disclosed caveats (both readings of ambiguous criteria, per-seed dispersion, unfiltered vs filtered medians). No interval claim anywhere, consistent with plan. | **No material deviation** — public claims track the plan's honesty discipline; this is the one axis with the cleanest match. |
| **Handoff state** | Per-slice after-task reports; arc close = full test + `--as-cran` + design/register/board consistency + after-task + handover. | Arc after-task (`docs/dev-log/after-task/2026-08-16-multinomial-structured-arc.md`) and Slice-0 after-task both present and complete (§1–10 each, Known Limitations sections filed). Full `devtools::test()` run (36.77 min, 3 pre-existing unrelated failures) recorded; no `--as-cran` run recorded in either after-task. PR #1057 open, unmerged, `mergeable: UNKNOWN` (GitHub has not computed the merge status at time of this check). | **Unclear** — no local `--as-cran` check is recorded for arc close, though CLAUDE.md's "local checks over CI" convention calls for one; may have been run and not logged, or may be an outstanding step before merge. Flagged, not escalated. |

## Drift items routed to owner

- **s1b provenance not git-verifiable** (evidence/verification axis): low-severity, self-disclosed, no corrective action possible after the fact (the commit history is what it is). No owner routing needed — recorded here as the durable note for any future reviewer citing s1b.
- **No `--as-cran` check recorded at arc close** (handoff-state axis): routed to **the maintainer / next session picking up PR #1057** — run `devtools::check()`/`rcmdcheck::rcmdcheck(args = "--as-cran")` locally before merge, per CLAUDE.md's standing local-checks-over-CI rule, and record it in a merge-readiness note if not already done outside this worktree.

No other genuine drift found; the remaining eight items in the brief are adaptive, plan-consistent, or non-material.

## Verdict

The arc executed close to its ultra-plan: all six slices landed with the scoped
admitted grid, the fence-soundness repair, and honest FAIL/PASS campaign
verdicts exactly as the plan's discipline required, and the one scope addition
(s1b) and the one execution-order change (S3/S4 serial, out of number order)
were both maintainer-approved or plan-anticipated rather than silent drift.
The two items worth carrying forward are process hygiene, not substance: s1b's
pre-registration timing cannot be independently verified from git (already
self-disclosed), and no `--as-cran` run is recorded before the still-open
PR #1057 is merged. Nothing found here should block the merge sign-off already
granted; the reconciliation surfaces the `--as-cran` gap as the one concrete
pre-merge action.
