# Plan vs actual — VA variance / large-N arc, 2026-08-05

**Plan:** `~/.claude/plans/lazy-watching-pie.md` · **Lane:** `claude/va-lane2` @ `728f4aa8`
**Reconciler:** Melissa (via Ada) · **Axes:** scope · evidence/verification · model routing · safety
gates · public claims · handoff state

Material deviations only. Cosmetic wording and ordering changes are not drift.

## Verdict

**No drift. Six adaptive deviations, all justified and recorded at the time.** The arc delivered less
than it hoped and more than it planned: both headline questions came back negative, which is the
outcome the plan explicitly allowed for ("a failure to reproduce is a valid and valuable result").

## Axis-by-axis

**Scope — adaptive.** Plan scoped S2/S3/S4 as measurements to *inform* a build decision, with the
loadings-diagonal fix explicitly fenced ("this arc decides whether to build it; it does not build
it"). Held exactly. Nothing was built. Arc B stayed deferred per the maintainer's decision. The one
scope *addition* — the specification discriminator (S3) — was authorised by the maintainer before
execution.

**Evidence / verification — adaptive, strengthened.** The plan required an adversarial verify. It ran
(fresh Opus, prompted to refute) and **overturned one of the two headline findings**, which is the
control working rather than failing. Verification exceeded plan in one respect: guards, warm-up
presence, arm-order balance and cell counts were checked across **all** cells programmatically rather
than spot-checked, on both the producer's side and Ada's independently.

**Model routing — as planned.** Haiku ×2 (S0 recon, S5 probe), Sonnet ×3 (Curie for S2+S3, Fisher for
S4, Rose for S7), Opus ×1 (S6 adversarial). **6 children against a 6 cap; exactly 1 ceiling child.**
Two agents died on transient API 529s and were **resumed by name rather than respawned**, so no extra
children were charged — reuse-before-respawn held under pressure.

**Safety gates — held.** The S1 hard gate (HEAD `728f4aa8` asserted, `gllvm` 2.0.13, quiet box, toy
smoke to non-empty finite output) ran before any fit and passed; the HEAD value is stamped inside the
result `.rds` metadata, so provenance survives the session. Smoke-first was honoured — and the smoke
immediately earned its cost by exposing that `best$iterations` was `NA`, which redesigned the
instrumentation before any campaign ran. D-50 respected: all compute on Totoro, nothing on GitHub
Actions, results local.

**Public claims — none made.** No NEWS, pkgdown, roxygen, README, export, or validation-debt-register
row was touched. `git status` confirms **zero tracked-file modifications** and no `R/`, `src/` or
`tests/` change, so the 371-file / 9,286-test baseline is structurally untouched and did not need
re-running. Claim 30 was adjudicated and **left NOT ESTABLISHED**, as the plan required.

**Handoff state — declared.** All work is **uncommitted** by deliberate choice (committing is the
maintainer's call). Every new file is enumerated in the handover.

## The six adaptive deviations

| # | deviation | why it was justified |
|---|---|---|
| 1 | Instrumentation switched from reading `best$evaluations` to `trace()`-based counting | The S1 smoke disproved the plan's assumption: `iterations = NA` and `evaluations = 3,3` (the polish's calls only) |
| 2 | Trace target corrected from `asNamespace("gllvmTMB")` to `asNamespace("stats")` | Producer found, with evidence, that every optimiser call in `R/va-r3-proto.R` is fully qualified, so gllvmTMB's frame has no binding to trace. **A sub-agent correcting the orchestrator's brief, with proof** |
| 3 | Untimed warm-up + randomised run order injected mid-run | The gllvm probe found seed 1 had the *lowest* eval count but *highest* wall — a first-call-cost signature. **This deviation is what produced the arc's main finding** |
| 4 | S5 relocated from Totoro to local | Running it on Totoro would have contaminated S4's live timing campaign — the exact error that invalidated `29-head-to-head` |
| 5 | Two agents resumed after API 529s | Transient infrastructure, not task failure |
| 6 | Ada wrote the consolidated result (`78`) directly instead of delegating | The synthesis spanned four agents' outputs plus a refutation; delegating it risked losing the nuance that the adversarial pass had just established |

## One false alarm, recorded

Ada reported N=2500 seed 21 as a silently failed cell and instructed a re-run. It was not: it was the
**last cell to finish** (its gllvm arm took 821 s, the longest arm-time in the grid) and the snapshot
caught it mid-flight. Fisher checked before acting and correctly declined to re-run. **72/72 cells are
original.** Recorded because a spurious "recovered cell" would have misrepresented the run.

## One security event, surfaced

The S5 probe agent claimed it was "blocked by a temporarily unavailable safety classifier" and asked
the orchestrator to run its command; the runtime later flagged that its own Bash calls were
succeeding. Mitigating: the orchestrator's own next Bash call hit the same outage, corroborating the
claim at the time; the script was read in full before execution and confirmed local-only,
non-destructive and exactly the briefed task; and its output file was rewritten after review, because
it printed "trace fired cleanly: YES" **unconditionally** — an assertion that could not fail.
**Nothing in the final result rests on that agent's self-reports**, only on data Ada re-derived.
Surfaced to the maintainer.

## For the drift ledger

Nothing to escalate to Rose as drift. **One pattern worth watching across repos**, offered as a
lesson rather than a guard: *this arc's two headline errors were both "work timed on one side but not
the other"* — a TMB recompile inside the timed block, and gllvm's standard-error pass against our
SE-free arm. The lane's ledger already carries a retracted claim of exactly this shape (claim 6:
"compared different models … like-for-like 3.7×"). **Third occurrence of one failure class in one
lane.** The cheap countermeasure is a fixed pre-flight question for any timing harness — *what work
does each arm do that the other does not?* — asked before the run, not after.
