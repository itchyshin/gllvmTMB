# Plan vs actual — VA/EVA engines and the Totoro wide grid (2026-07-26)

Reconciler: Melissa. Plan: `~/.claude/plans/crystalline-whistling-quasar.md`
(12-hour arc, approved). Lane: `claude/va-wiring-20260726`, HEAD `c5af7068`.
Material deviations only; cosmetic reordering is not drift.

## Axis 1 — Scope

| planned | actual | tag |
|---|---|---|
| Arc 0: templates + driver + first gllvm match | done; Poisson matched `gllvm` at 0.000000% | — |
| R1 Totoro provisioning (gated) | done; `gllvm` 2.0.13, `mirai`, gllvmTMB 0.6.0 installed | — |
| R2 harden driver for grid corners | **partial** — family gates relaxed and Poisson starts fixed, but the cold-start defect found mid-session was **not** fixed | **drift** |
| R3 grid harness + local smoke | done, and the smoke caught 3 grid-corrupting defects | — |
| R4 Totoro grid | done: 640/640 cells, 2880 rows, 5419 s, 64 workers | — |
| R5 analysis (agreement/divergence + runtime) | done, `dev/totoro-grid/results/RESULTS.md` | — |
| R6 failure-cell study | done, folded into the silent-failure table | — |
| R7 adversarial review | done (Noether, 4 separate passes) | — |
| — | **JJ evaluation tier added** (not planned) | **adaptive** |
| — | **Designs 104-108 written** (not planned) | **adaptive** |
| — | **binary/OLRE logLik defect found, fixed, spun to its own lane** | **adaptive** |

*Adaptive rationale.* The JJ tier was added because the GH-vs-JJ comparison was
confounded (it varied bound *and* implementation); adding JJ to our own engine
was the only way to isolate the variable. Designs 104-108 answered Shinichi's
explicit mid-session ask for full family/structural coverage. The defect lane
was spun out precisely to keep this lane's "no package source touched" property.

*Drift rationale.* The cold-start defect (loadings initialise at an arbitrary
±0.1 while `gllvm` warm-starts factor-analytically; a 3-line SVD beats our
converged fit on 6/6 seeds) was identified but **left unfixed** because the
controlled A-vs-B run was live and changing starts mid-run would have corrupted
it. It is the highest-value outstanding item and is recorded as such.

## Axis 2 — Evidence and verification

Planned verification was met and exceeded: gllvm agreement (Procrustes >0.95,
objective <1%) **and** the ELBO sign check, plus a bound-ordering check
(320/320) that was not in the plan.

**Four claims were asserted and retracted**, three of them the same timing
artefact. Recorded in the after-task report and in Design 104. This is not
scored as drift — the plan required verification, and verification is what
caught them — but the *rate* is the notable figure: three of four came from
single-pass wall-clock timing, a mistake with a known, cheap fix that was
repeated after being documented.

One **stated prediction failed** (`gtmb_laplace` predicted highest degenerate
rate; actual 12%, second to `gllvm_eva`'s 68%). Recorded, not buried.

## Axis 3 — Model routing

| planned | actual |
|---|---|
| 6 new children per checkpoint, ≤1 ceiling | **5 workflows, ~17 agents** across the session |
| scout 1-2 (Haiku), build 3-4 (Sonnet), ceiling 1 (Opus) | roughly held per workflow; Opus used for each adversarial pass |

**Tag: adaptive, but under-recorded.** Each individual workflow respected the
composition gate, and Shinichi re-authorised expansion repeatedly ("ultracode"
×4). But no routing receipt was maintained across checkpoints, so the
cumulative count was never visible in-flight. A cross-workflow tally should be
kept next time.

## Axis 4 — Safety gates

All held:

- `NAMESPACE` byte-identical; no `@export`; no `method=` argument.
- `src/gllvmTMB.cpp` untouched **by this lane** (the defect fix went to a
  separate lane and merged independently as `c3d11667`).
- D-50 honoured: grid results rsync'd local, never a GitHub artifact.
- Totoro use stayed at 64 workers against the 150-core shared ceiling, with
  `OPENBLAS_NUM_THREADS=1` pinned per worker.
- Smoke-first honoured: a 2-cell smoke ran before the 640-cell grid, and the
  analysis script was itself validated on smoke output before the grid landed.

No gate skipped.

## Axis 5 — Public claims

**None made.** The headline claim the session set out to establish — that our
tighter bound is better — was **refuted** by its own controlled evidence and
withdrawn. The prior-art sweep independently established the general result was
published from 2011, so the surviving contribution is narrower: quadrature is
practical inside a GLLVM where both GLLVM papers call it impractical, and our
engine is the most *reliable* arm rather than the most accurate or fastest.

## Axis 6 — Handoff state

- Lane committed at `c5af7068`, **not pushed, not merged**.
- Based on `dc79753a`; `main` has moved to `c3d11667`. **Rebase required.**
- Two maintainer calls open on the merged defect: NEWS entry, public issue.
- Nothing left uncommitted that carries evidence.

## Drift routed to owners

| item | owner |
|---|---|
| Cold-start warm-start defect unfixed (R2 partial) | Ada — next slice |
| Cumulative routing receipt not kept across checkpoints | Ada — process |
| Repeated single-pass timing error (3 instances) | Rose — do-not-repeat ledger |
| Lane behind `main`, rebase required | Ada — before any merge |

## Verdict

Plan substantially delivered, including the headline Totoro grid. Two genuine
drifts, both recorded with reasons. The most valuable outputs — the silent-
failure table, Proposition 2, and the defect fix — were **not** in the plan;
the planned headline was refuted. That asymmetry is the honest summary.
