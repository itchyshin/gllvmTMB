# Plan vs Actual — Checkpoint 2, ARC D1 (zero-inflated families)

**Reconciler:** Melissa (ultra-plan Phase 4.5), read-only except this file.
**Plan:** `/Users/z3437171/.claude/plans/read-agents-md-and-docs-dev-log-handover-lovely-grove.md`,
"CHECKPOINT 2 — ARC D1" section and its execution-log lines.
**Worktree:** `/Users/z3437171/local-scratch/lanes/gllvmTMB-arcD-zi-20260902`,
branch `claude/gapclose-arcD-zi-20260902` (stacked on `claude/gapclose-20260902`, PR #1239).
**Sources read:** `dev/gapclose/arcD/{recon-zi.md,alignment-zi.md,D1-report.md}`,
`docs/dev-log/after-task/2026-09-02-gapclose-arcD-zero-inflated.md`,
`.../scratchpad/verify-arcD.md`, `git log`/`git show` on commits
`7e043040a`, `52043b3db`, `f90fd4fd4`, `542dc59a1`, and draft PR #1240.

**Note on drift-in-flight:** the task brief said the branch carried two commits
(`7e043040a`, `52043b3db`). By the time this reconciliation read the tree, two more
commits had landed (`f90fd4fd4` after-task, `542dc59a1` check-log/board refresh) and
draft PR #1240 was open — the checkpoint closed out live during this reconciliation.
This is reported as state, not treated as a deviation.

## Six-axis table

| Axis | Planned | Actual | Tag | Owner | Note |
|---|---|---|---|---|---|
| Scope | Brief's explicit file list only (Design Rule 1 sequence: alignment → TMB → constructors → admission → 14-slot rows → recovery → register → NEWS → roxygen) | Builder also fixed `tools/parity_ledger.R`'s HTML-comment table-parsing bug (dropped 7 Julia rows silently) — one file beyond the brief's list, disclosed and justified as the only way to satisfy the brief's own acceptance line | adaptive | — | Necessary, disclosed, tested (32/32 unchanged on the parser's own suite); not scope creep |
| Scope | One lane (ARC D) touches `tools/parity_ledger.R` | A second, independent lane (`b1-b2-ledger-parity`) fixed the **same parser bug** in the A–C worktree, discovered only when ARC D's Opus reviewer diffed against a moved base; B1's copy stashed, ARC D's version kept canonical | drift | Ada (scope/routing) | Mitigated with no lasting harm (Opus verify confirmed a clean merge, 32/32), but signals a lane-boundary miss on a shared file worth a note for future dispatch |
| Evidence/verification | Orchestrator re-run via the dev tree | First re-run used `testthat::test_file()` against the **installed** 0.7.1 package and reported all ZI tests skipped; corrected to `devtools::test(filter=)` | adaptive | — | Caught and fixed within the same checkpoint; recorded as a named lesson in D1-report §9 and after-task §9/§10 |
| Evidence/verification | Brief: known-DGP recovery at `n_sites = 150` for all three families | zi_nbinom2 shipped at n=400 from the start (phi hard to recover at 150); after Opus review, zi_poisson raised 150→200 and zi_binomial 150→250 so bars hold across 4 seeds, with the sweep of alternative n shown and the choice justified (200/250 chosen over 350 on runtime, not accuracy) | adaptive | — | Deviation from the brief's stated n, made deliberately, evidenced with a multi-n sweep, not a bar-loosening shortcut |
| Evidence/verification | Compute line: "local for the test-sized recovery; multi-seed recovery = Totoro pre-run (D-139 estimate) then DRAC job array if > 30 min" | No Totoro/DRAC run executed. Evidence is local: single-seed recovery per family (per the original brief) plus, after review, a heavier local 5-seed block (`GLLVMTMB_HEAVY_TESTS=1`, seeds 101–105, 36.5 s) — still local, no D-139 estimate produced, no cluster job submitted | drift | domain reviewer (method evidence) | Disclosed, not hidden (after-task §11, PR "Not in this PR"); register rows FAM-21/22/23 stay `partial` specifically because of this gap — but the plan named this compute step as part of the checkpoint, and it did not run |
| Model routing | Fresh child budget: RECON-D (haiku) · D1 build (sonnet-high) · D-VERIFY (opus) · MECH (haiku) · Melissa (sonnet); Producers ≤ 2 | First (Haiku) recon scout stalled 2 h with no output; replaced by a Sonnet recon that finished in 5 min. Producer count stayed at 2 (recon retry counted once + D1 builder), matching the budget | adaptive | — | Disclosed in the plan log, D1-report, and after-task §9/§10 ("give scouts a tool budget and an incremental-write rule") |
| Model routing | — | The same Sonnet D1 builder was reused (not a fresh child) for the Opus-review fix round | adaptive | — | Consistent with the "Producers ≤ 2" cap; a fresh child was not spawned for the fix pass |
| Safety gates | Design constraint drawn into the brief from Designs 105/106/108: "the VA/ELBO route breaks on zero-inflated mixtures → `integration = "va"` must refuse `zi_*`... AGHQ/MSPL not admitted" | VA and MSPL **refuse** as planned (verified: hard error on all three families). AGHQ does **not** refuse — it **declines** to a plain Laplace fit with a reason-specific warning, the same treatment every other AGHQ-ineligible model class gets (multinomial rows, `k=1`, etc.). The builder's R3 fix corrected four reader-facing documents to say "declines," rather than making AGHQ hard-error to match the plan's original wording | drift | domain reviewer (method evidence) | This is a real behavioural gap against the plan's own design-constraint line, self-resolved by the builder toward architectural consistency rather than by asking first; it is one of four explicit points the draft PR asks the maintainer to sign off on, so it is surfaced, not buried |
| Safety gates | New-family TMB likelihood is HIGH-RISK; MUST STOP before merge | PR #1240 is DRAFT, explicitly titled "maintainer sign-off required," with a named 4-point decision list (zero-part richness, `zi_binomial` trials≥2, AGHQ decline-vs-refuse, FAM-22 `partial` status); nothing merged | compliant | — | No deviation; recorded for completeness, not counted in the adaptive/drift/unclear tally |
| Public claims | NEWS/Design 02/03/register describe only what was tested and verified | Opus adversarial review found the rootogram falsely claimed extended to zi families (R1), the 14-slot `link_residual_rule` silently unimplemented and unmentioned (R2), AGHQ described as "refuses" in four places when it declines (R3), FAM-22's caveat understating a 2/6-trait phi runaway as "one trait" (R4), and a shipped `\donttest{}` example that does not converge (R5) — all stated as fact on reader- or near-reader-facing surfaces before the fix round | drift | Rose (closeout/claims) | **Resolved**: all five corrected in `52043b3db` with new regression tests (rootogram, link-residual, AGHQ wording, FAM-22 numbers, converging example); no known false claim remains as of `f90fd4fd4` |
| Handoff state | Checkpoint close: after-task §4 filled by orchestrator, Melissa dispatched, stacked draft PR, lease release | After-task committed (`f90fd4fd4`) with the Opus review fully recorded (§4 is not "pending" in the committed version); draft PR #1240 open, stacked on #1239; check-log + coordination-board updated (`542dc59a1`); this reconcile running now | adaptive | — | Matches the plan's closeout sequence; the "pending" phrasing in the task brief describes an earlier in-flight state, already overtaken |
| Handoff state | "Lease release" named as a checkpoint-close action | Not observed in any artifact read (D1-report, after-task, check-log, coordination-board, PR body) | unclear | Ada (scope/routing) | Absence of evidence, not evidence of absence — confirm whether the ARC D lease was actually released before the next checkpoint claims the paths |

## Items promised but without evidence in the tree

- **Multi-seed Totoro pre-run + DRAC job array recovery evidence** for FAM-21/22/23, named in
  the plan's checkpoint-2 compute line — not run; no D-139 time estimate produced either.
- **Numeric cross-check against GLLVM.jl's ADEMP campaign** (6,000 fits) as the named oracle for
  a later multi-seed comparison — not attempted (D1-report §"What was NOT finished," recon §G item 5).
- **Lease release** for the ARC D worktree/paths — asserted as an action in the plan log's last
  line but not corroborated by any artifact this reconciliation read.

## Counts

adaptive: 6 · drift: 4 · unclear: 1

## Verdict

The likelihood build matched its symbolic contract exactly and the checkpoint's own adversarial
review loop caught and closed every surface-level false claim before merge was even requested, so
the process worked as designed. The two deviations that matter for the next checkpoint are that
AGHQ's decline-vs-refuse behavior diverges from the plan's own Design-105/106/108-derived line
without a prior owner check-in (flagged for maintainer sign-off, not yet resolved), and that the
named Totoro/DRAC multi-seed compute step never ran, leaving FAM-21/22/23 evidenced only by local
single- and five-seed recovery.
