# Plan vs actual — VA ordination usability arc (2026-08-05)

**Reconciler:** Melissa (run by the orchestrator; context budget precluded a separate agent).
**Plan:** `~/.claude/plans/nifty-snacking-storm.md` · **Close:** after-task
`docs/dev-log/after-task/2026-08-05-va-ordination-usability.md`.
Material deviations only, six axes. Cosmetic ordering/wording differences are not drift.

| # | axis | planned | actual | tag |
|---|---|---|---|---|
| 1 | scope | 6 slices A0–A6 | A0–A6 all delivered | — |
| 2 | scope | A2 = attenuation vs truth | **grew to 5 campaigns**: A2 + GH probe + Laplace control + p-ladder + n-ladder + AC ladder + gllvm ×2 | **adaptive** — each was forced by a maintainer question that invalidated the prior reading; all recorded |
| 3 | evidence | internal Laplace control | **external CRAN `gllvm` comparator added** | **adaptive** — maintainer direction ("compare against CRAN"); closed a gap the plan did not see |
| 4 | model routing | A3 Rose · Sonnet | **A3 run by orchestrator** after the agent stalled | **adaptive** — recorded; work verified |
| 5 | model routing | 6 children, 1 ceiling | A0, Emmy, Curie, Fisher(Opus), Rose = 5 + 1 ceiling | — within budget |
| 6 | verification | A4 mechanical + A5 adversarial | both ran; A5 found **3 real defects** | — worked as designed |
| 7 | safety gates | fence untouched, no default change, D-50 local | all held; `git diff R/integration-fence.R` empty | — |
| 8 | public claims | — | **2 claims retracted** (ledger 52, 56) | **adaptive** — self-corrected before landing |
| 9 | handoff | handover written | **NOT written** — superseded by the probit arc continuing in-session | **drift (minor)** — see below |
| 10 | DoD item 4 | runnable example | **not met, deliberately** — maintainer scoped the vignette out | — declared, not silent |

## Drift requiring an owner

- **(9) No handover written.** The plan's A6 included one. The arc did not end at a session
  boundary — it rolled directly into the probit Stage-8 arc — so a handover was never the right
  artifact. **Owner: Rose.** If this session ends before the probit campaign is read, a handover
  IS owed and must name: HEAD `bf483ce4`, ~15 uncommitted files, the running campaign
  (`dev/va-usability/100-probit-stage8.R`), and the two open maintainer decisions (expose
  `eval_method`; probit fence admission).

## Recurring class worth aggregating

**Hand-derived numbers published without verification against the harness's own saved aggregate —
FIVE instances in one session** (three caught by Fisher, one by Rose, one self-caught):
`sigma_ratio` read as a scalar (ledger 52); "4/50 seeds >100×"; "max 4134×"; the unpaired
"marginally ahead" (ledger 56); the AC/GH cost multiple quoted as ~17× where the per-seed median is
**21.8×**. Every one arose the same way: an ad-hoc orchestrator-side recomputation set beside a
correct machine-generated summary. **Feed to Rose for [[PLAN-DRIFT-LEDGER]]** — this is a process
class, not five accidents. Mitigation already filed:
[[LESSONS]] Delta 3, "distrust the HAND-derived number sitting beside a machine-derived one."

## Note on the plan artifact itself

The plan's own RESULTS block was updated mid-arc with findings that were **later retracted**
(the "bounded max 1.8 / Laplace unstable" framing). It is left as written, with the retraction
recorded in the after-task §8 and ledger 52 — the plan is a dated record of what was believed at
the time, not a document to retro-fit.
