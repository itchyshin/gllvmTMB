# Plan vs actual — interval-computability lane (Melissa, light)

**Date:** 2026-08-17 · **Lane:** `claude/mspl-interval-computable-pin` · **Plan:**
`~/.claude/plans/read-agents-md-and-docs-dev-log-handover-noble-reddy.md`

## Planned

Two deliverables: (1) the KF2021 profile verdict shipped as its own docs artefact for the Cursor
SE/CI lane; (2) a narrow R-only re-port of `.gllvmTMB_mspl_profile_feasibility()` +
`.gllvmTMB_mspl_profile_threshold_diagnostic()` onto current `main` as an internal,
no-coverage-claim interval-computability instrument. Ten slices, ~4–5 h, 6 sub-agents.

## Actual

Deliverable (1) landed in full: [#1090](https://github.com/itchyshin/gllvmTMB/pull/1090).

Deliverable (2) **stood down, then reversed, then written and put to PR unmerged** — the honest
sequence, recorded because the intermediate state was published:

1. Stood down mid-execution on D-88 grounds when the Design 125 lane surfaced (see below).
2. **Reversed** after re-reading D-88: *concurrency is allowed, bleed-through is not.* Design 125's
   kit is docs-only with zero R code, its G4c blocks live profile work "until fork G0", and there is
   no file overlap. Shinichi had also answered the pin-vs-construction question directly in chat.
3. Re-ported, reviewed adversarially (Opus), and **left unmerged pending a recorded G0** — because
   the review found that chat authority does not discharge three *written* fences (below).

**This section previously read "stood down before any code was written" and "no code changed".
That became false at commit `6e8bb37e` and is corrected here rather than left standing.**

## Material deviations

| Axis | Deviation | Tag | Owner |
|---|---|---|---|
| Scope | The re-port (S5/S6) was not executed | **adaptive** | Ada |
| Evidence | Adversarial fence review (S7) + `--as-cran` (S8) not run | **adaptive** — nothing was implemented to review; scoped to the re-port | Ada |
| Safety gates | Phase 0.25 sweep receipt present and evidence-cited; a *second* sweep during execution found the collision the first missed | **adaptive**, but see Lesson | Rose |
| Public claims | None made; `MSPL-04` `blocked`, `Q_0` unchanged, no public `se`/`vcov`/`confint` | no deviation | — |
| Model routing | S2 Sonnet-high, S3 Sonnet-high, 0 ceiling children used (the planned Opus reviewer was for the re-port) | **adaptive** — under budget, not over | Ada |
| Handoff state | Re-port findings handed to the Design 125 lane via directed check-log note instead of being consumed here | **adaptive** | Shannon |

**Why the re-port stood down (the justification that makes it adaptive, not drift):** a lane check
run immediately before editing `docs/dev-log/check-log.md` surfaced
`claude/lane-mspl-profile-led-ci` — 11 commits carrying **Design 125**, a **SIGNED** ADEMP
pre-registration whose Aim 1 is a *profile-primary* interval construction for binary LA-MSPL. That
is D-157's "new construction," it already exists, and it owns the profile surface. Proceeding
would have been two lanes building profile machinery for the same family — the bleed-through D-88
forbids. Per D-87 the ownership call is Shinichi's, so it was surfaced, not resolved.

## Lesson (for [[PLAN-DRIFT-LEDGER]] if it recurs)

**The Phase 0.25 sweep found the stranded instrument but missed the competing lane.** It swept
`git log --all` for the *capability* (`profile_feasibility`) and found it; it did not sweep for
*other lanes' pre-registrations by topic*, and Design 125's kit is docs-only — no matching symbol
to grep. The collision surfaced only because the `--file` lane check fired on a shared file later
in execution.

Generalisable: **a capability sweep and a lane sweep are different queries.** Grepping for the
function name cannot find a lane that has approval to build the same thing but has not written the
code yet. When a plan's deliverable is "build capability X", also sweep `docs/dev-log/research/`
and `docs/design/` on *all refs* for X's topic words, not just the code for X.

Also recorded, minor: an Explore-type scout was given a `Write` output contract it had no tool
grant for (AGENTS.md — audit the tool grant, not just the model tier). Its inventory survived in
the return message; briefs for later slices used a general-purpose agent.

## Verification actually run

Direct read of arXiv:1812.01938 pp. 4–6 confirming the §2.2 sentence verbatim, after a sub-agent's
first pass was independently re-read (the finding redirects other lanes). No test or `--as-cran`
run, correctly, because no code changed: `git diff --stat` for this lane touches only
`docs/dev-log/`.

## Carried over

The re-port remains **available and measured, not done**: the two functions plus helper
`.gllvmTMB_mspl_nlminb` lift cleanly onto `main` (purely additive; all four internal symbols
unchanged) and need **no** `src/` `mspl_c_n_multiplier` hook. Offered to the Design 125 lane in the
check-log. Resume only on Shinichi's ownership call.
