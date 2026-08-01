# Plan vs actual — #851 scale-aware start (ultra-plan, 2026-07-31)

Light reconciliation (Phase 4.5). Material deviations only, six axes.
Plan: `~/.claude/plans/recursive-popping-sedgewick.md`.

## Scope

| planned | actual | tag |
|---|---|---|
| S1 tier-restriction repair | done, `0c52362f` | — |
| S2 convergence-7 characterisation | done (Fisher, Sonnet), verdict MERELY FLAGGED ×3 | — |
| S3 test-defect write-up | done, `dev/851-dep-vs-latent-ridge-tolerance.R` | — |
| S4 Totoro re-sync + full suite | done, three suite runs not one | **adaptive** — the extra runs bought the failure-count decomposition (25 → 22 → 21 → 18), which is what makes the result readable |
| S5 mechanical verify | done inline | **adaptive** (see routing) |
| S6 D-43 completion panel | **not fired** | **adaptive** — gated on "only if a public claim moves". No claim moved: the NEWS entry was already on the branch and this arc **narrowed** it (added the tier-scope limitation). Narrowing does not need a promotion panel |
| S7 reconcile | this document | — |
| — | **`lv`-gate fix, `f31935e5`** | **adaptive** — a second root cause the plan did not anticipate, found while characterising the gradient gap |
| DEFER #872 | held; the two-tier k=5000 remainder (0.0204) confirmed unchanged | — |

## Evidence / verification

Stronger than planned. The plan asked for one branch-vs-baseline suite pair; the actual run
produced a verified `main` baseline plus three branch states, so every failure is attributed
rather than counted. Verification step 4 (`R CMD check --as-cran`) was completed only in
**restricted** form and is labelled as partial in the after-task report — recorded here as a
**known gap**, not a pass.

## Model routing

| planned | actual | tag |
|---|---|---|
| S1 Gauss/Sonnet, S3–S5 Luna/Haiku, 4 children | 1 child (Fisher, Sonnet, high) | **adaptive** |

Fan-out was 1 of a budgeted 6. S1 was kept inline because it is a subtle engine change and
the deciding context — the six call sites, the rejected-variant comment, the equivariance
evidence — was already held; briefing it out would have cost more transfer than it saved.
S3–S5 collapsed to minutes of inline work once S1 landed. **Direction of the deviation
matters: this is under-spend on fan-out, not unrecorded escalation.** No ceiling/Opus child
was created.

## Safety gates

No convergence check relaxed and no tolerance widened to accommodate the branch. The one
tolerance that moved (`test-canonical-keywords.R:556`, 1e-10 → testthat default) is backed
by a 12-seed measurement showing `main` breaches it 6/12 — i.e. a correction to a knife-edge
assertion, landed with its reproducer. The two `convergence == 0` assertions were **kept**
and re-based on an identified fixture rather than widened; accepting code 1 was explicitly
offered to Shinichi and explicitly rejected.

Prior-work sweep receipt: present and evidence-cited (four surfaces). It caught a stale
Totoro tree that would otherwise have supplied a wrong baseline.

## Public claims

None moved. The NEWS claim is narrowed, not extended. No capability promoted, no register
row changed.

## Handoff state

Branch `claude/851-scale-aware-start-20260731` pushed through `c3210ede`; PR #873 open and
**not merged** — merging is engine-adjacent and therefore the maintainer's call under
`CLAUDE.md`'s high-risk list. Nothing carried over uncommitted.

## Drift

**None material.** Every deviation above is adaptive and recorded. One process note for the
ledger rather than a defect: the plan's slice table assumed fan-out that the work did not
need once the root cause was isolated, which is a mild pattern of over-planning parallelism
for diagnosis-shaped arcs — diagnosis narrows, and narrow work is cheaper inline.
