# Session Handoff: gllvmTMB reverse-parity gap closure — COMPLETE

Meta: 2026-09-03, Claude Code (single continuous lane, 2026-09-02 → 09-03). `main` @ `073d197e8`.

## Critical Context

**This lane is CLOSED and its work is fully landed. Do not re-open it, and do not rebuild any of
it.** Nine pull requests merged. Reverse parity — the capabilities GLLVM.jl had that gllvmTMB lacked
— is closed as buildable work. Everything still owed is listed under Next Immediate Steps and was
deliberately not started, on the maintainer's instruction *"we can stop at the parity"*.

**The one thing that will mislead you if you skip it:** three separate green-looking signals lied
during this lane, and two of them nearly shipped wrong work. They are written up under Gotchas.
Read that section before you trust any test summary, merge log, or count in this repository.

## What Was Accomplished

| PR | What |
|---|---|
| [#1239](https://github.com/itchyshin/gllvmTMB/pull/1239) | Gap closure: refusals that name a working route, plain-language front page, the R capability ledger and the parity tool |
| [#1240](https://github.com/itchyshin/gllvmTMB/pull/1240) | Zero-inflated families `zi_poisson()`, `zi_nbinom2()`, `zi_binomial()` (ids 17–19) |
| [#1248](https://github.com/itchyshin/gllvmTMB/pull/1248) | 450-fit Totoro recovery campaign for those families |
| [#1251](https://github.com/itchyshin/gllvmTMB/pull/1251) | 171 refusals given a next step; bare-abort count 999 → 828, ratchet lowered |
| [#1250](https://github.com/itchyshin/gllvmTMB/pull/1250) | `ordinal_logit()` cumulative-logit response family (id 20) |
| [#1249](https://github.com/itchyshin/gllvmTMB/pull/1249) | `select_lv()` and `anova()` with chi-bar-square boundary p-values |
| [#1253](https://github.com/itchyshin/gllvmTMB/pull/1253) | `ordination_uncertainty()` and `ordiplot(ellipse = TRUE)` |
| [#1254](https://github.com/itchyshin/gllvmTMB/pull/1254) | `censored_poisson()` engine (id 21) behind its long-exported constructor |

Issues [#1241–#1247](https://github.com/itchyshin/gllvmTMB/issues/1247) carry the remaining backlog.
Mission control's twin-parity page now reads the new R ledger, so it shows real Julia-only rows
instead of zero by construction.

## Current Working State

- **Working:** `main` @ `073d197e8`, CI green on the preceding commit. Runtime family ids 17–21 are
  all live and distinct. Full local suite on the last branch before merge: 27,480 passing.
- **In progress:** nothing. No branch of this lane holds unlanded work.
- **Not working / blocked:** nothing blocked. What remains is unstarted, not stuck.

## Key Decisions & Rationale

- **D-216** — the maintainer signed off #1249 and #1250, with their specific decision points named.
- **D-217** — the maintainer approved #1253 and #1254 and set the merge order (#1249 first).
- **D-204** (standing) — parity runs both ways for user-facing capabilities; engine-internal
  Julia-only features are accounted for in writing rather than ported.
- **The distinction that must survive this lane:** tests are regression guards; the
  validation-debt register is where a certified claim lives. A 450-fit campaign showed the shipped
  zero-inflated bars holding in only 82% / 82% / 92% of fifty seeds. The test sizes were deliberately
  **not** raised; the register rows now quote the measured fractions and stay `partial`. Do not
  collapse those two things into one.

## Landing State

`handoff_gate.sh` reports the shared Dropbox checkout as unlanded. **None of that is this lane's** —
it is pre-existing state belonging to other lanes (three untracked directories that were present at
session start, and ~630 unpushed commits on old `agent/*` and `tmp/*` branches). Left untouched per
D-88. This lane's own ledger:

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `claude/overnight-aborts-1` | y | y | #1251 merged | LANDED |
| `claude/overnight-ordinal-logit` | y | y | #1250 merged | LANDED |
| `claude/overnight-select-lv` | y | y | #1249 merged | LANDED |
| `claude/overnight-ordination-uncertainty` | y | y | #1253 merged | LANDED |
| `claude/overnight-censored-poisson` | y | y | #1254 merged | LANDED |
| `claude/lane-gapclose-overnight-20260902` (LOOP kit, brief, after-task, this handover) | y | y | this PR | LANDED |
| `dev/gapclose/arcD/recovery/` campaign outputs | y | y | #1248 merged | LANDED |
| Stashes `stash@{0}`/`stash@{1}` in worktree `gllvmTMB-gapclose-20260902` | n | n | none | CARRIED-OVER |

**CARRIED-OVER row.** Two stashes hold an earlier, superseded fix to `tools/parity_ledger.R`'s
HTML-comment parser. The canonical fix landed with ARC D (`7e043040a`) and is on `main`. They are
kept only as a record that two agents fixed the same bug independently. **Do not apply them** — the
current parser is correct. Resume/inspect: `cd /Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902 && git stash show -p stash@{1}`. Safe to drop.

FINDINGS-OF-RECORD: none. Every finding of this lane is on `main` — in the validation-debt register,
`docs/dev-log/after-task/2026-09-03-gapclose-overnight-arcs.md`, and vault entries D-216/D-217 —
not on any branch.

## Next Immediate Steps

Ordered. All were deliberately left unstarted under the maintainer's "stop at the parity" fence, so
each needs his go-ahead, not just an owner.

1. **Multi-seed recovery for `ordinal_logit()` and `censored_poisson()`.** Both ship on few-seed
   regression guards (three and four seeds). Their register rows say `partial` and say why. The
   #1248 campaign is the template: Totoro, a D-139 estimate first, then re-quote the measured
   fractions in the rows rather than raising the test sizes.
2. **Coverage for `ordination_uncertainty()`.** It returns Wald quantities with no measured
   coverage at all, and `level = "unit_obs"` runs the same code path with no dedicated hand-check.
3. **The remaining 828 refusals without a next step** ([#1247](https://github.com/itchyshin/gllvmTMB/issues/1247)),
   behind a ratchet that can only fall. #1251 is the worked pattern.
4. **The rest of the B3 backlog**, issues #1241–#1246.

## Blockers / Open Questions

None blocking. One question worth putting to the maintainer at some point: the chi-bar boundary test
shipped in #1249 measures an empirical size of 0.095 (MCSE 0.021) against a nominal 0.05 at q = 3.
That was reported rather than buried, and he approved shipping it, but it is a real calibration gap
and a candidate for the next inference arc.

## Gotchas & Failed Approaches

**Three green signals meant nothing this lane. Each cost real time; each will recur.**

1. **testthat prints `DONE` over a file in which every assertion skipped.** The suite is gated behind
   `skip_on_cran()`. A builder's "231 passing" claim re-ran as 231 *skips* with a cheerful summary.
   Always `NOT_CRAN=true`, and read the counts, never the word. Related and equally silent: plain
   `testthat::test_file()` runs against the **installed** package, not your checkout — use
   `devtools::load_all()` first or you will test code you did not write.
2. **A merge watcher logged `#1249 MERGED` when no merge had occurred.** It checked that CI was green
   but never checked the merge command's own exit. The PR was still open and conflicting. Any
   automation that merges must read the PR state back and refuse to report what it cannot confirm.
3. **A conflict marker makes an R file unparseable, and `count_bare_aborts()` silently skips files it
   cannot parse.** The count then comes out *below* the ceiling and reads as a pass. This fired three
   times on three different branches. **Check that all R files parse before trusting any count** — a
   count that improves for no reason is a bug, not a result.

**Two more worth keeping:**

- **A narrow search returning nothing is not evidence of absence.** An agent reported that GLLVM.jl
  had run no comparable campaign, having read dated August status notes as current. The campaign
  exists, on an unmerged branch, invisible to a search of their `main`. Corrected in place in
  `dev/gapclose/arcD/recovery/RESULTS.md`.
- **A wrong runtime family id dispatches the wrong likelihood while everything still appears to run.**
  `censored_poisson()` and `ordinal_logit()` independently claimed id 20; its builder disclosed the
  clash rather than hiding it. After renumbering to 21, every verification number was re-measured
  rather than assumed unaffected. Treat an id change as a behaviour change.

**One correction of record:** a brief from this lane's orchestrator stated that the naive full-degrees-
of-freedom chi-square is *anticonservative* for a boundary test. It is **conservative** — the mixture
sits below the full-df tail, so naive p-values are too large. The builder caught it, proved it, and
corrected the comments it had already written from the wrong premise.

## How to Resume

There is nothing to resume in this lane. To start the follow-on work:

```sh
~/shinichi-brain/tools/lane_preflight.sh gllvmTMB
```

Then read, in order: `docs/dev-log/handover/2026-07-25-active-lane-split.md` (the lane map is
authoritative for ownership), this file, then
`docs/dev-log/after-task/2026-09-03-gapclose-overnight-arcs.md` for the evidence behind every claim
above, and `docs/design/35-validation-debt-register.md` rows FAM-21 … FAM-25 and EXT-38 for exactly
what is and is not certified.
