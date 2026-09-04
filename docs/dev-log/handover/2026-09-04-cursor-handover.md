# Session Handoff: gllvmTMB → the combined Cursor lane

Meta: 2026-09-04 · from Claude Code · to **Cursor** · `main` @ `72ed68b57` (plus PR #1260, merging).

You are **Cursor**, picking up gllvmTMB as one half of a single lane that also holds **GLLVM.jl**.
This document covers the gllvmTMB half only. **The Julia half is
`GLLVM.jl/docs/dev-log/handover/2026-09-04-cursor-handover.md`, on that repo's `main` @ `5518d98d`**
(verified present, and it cross-links this repo's handovers). Neither document is the lane's entry
point. **The entry point is the start prompt Shinichi pastes**, whose reusable form the brain holds at
`shinichi-brain/docs/dev-log/handover/2026-09-02-h2-twin-one-lane-start-prompt` — the H² twin pattern
the maintainer chose for the sibling pair two days ago.

**Division of the two halves**, agreed between the outgoing lanes: GLLVM.jl owns engine truth, the
parity harness and the frozen oracle; gllvmTMB owns the public R API, its claims and its docs. Where
they meet — the capability ledgers and `tools/parity_ledger.R` — changes are a **joint-contract
decision for Shinichi**, not something either half changes alone. Both handovers say so, in the same
words, on purpose.

## Critical Context — read these four things or you will go wrong

**1. Nothing of the previous lane is unfinished.** Do not resume anything from it. `main` is green,
every PR is merged, no branch holds unlanded work. What remains is listed under Next Immediate Steps
and was deliberately *not started*, on Shinichi's instruction to stop at parity. Those are new work
needing his go-ahead, not carried-over work needing rescue.

**2. Four verification traps, each of which cost the previous lane real time. They are properties of
this repository, not of the model that hits them, so you will meet them fresh.**

- `testthat::test_file(...)` on its own runs the **installed** package, not your checkout. Use
  `devtools::load_all(".")` first, or you will test code you did not write.
- `skip_on_cran()` makes an entire file skip while testthat still prints `DONE`. Set `NOT_CRAN=true`
  and **read the pass/fail counts, never the word**.
- A conflict marker makes an R file unparseable, and `count_bare_aborts()` silently skips files it
  cannot parse — so the count comes out *below* its ceiling and reads as a pass. Verify every R file
  parses before trusting any count. **A number that improves for no reason is a bug, not a result.**
- Since the CI sharding change, a green check may mean the package check was **skipped** via a
  fast-pass path for changes touching no source. Correct for a docs-only PR; worthless as evidence for
  a source change. Read the step conclusions
  (`gh api repos/itchyshin/gllvmTMB/actions/runs/<id>/jobs`) before trusting a green.

**3. Your first arc is a capability proof, not a feature.** Cursor is a lane, not a capability tier.
Nobody has demonstrated that a Cursor lane can build this package and run a real fit. Before any
campaign is committed to this lane: make a clean worktree, run `devtools::load_all(".")` to compile
the TMB library (several minutes, and it is the step most likely to surprise you), and complete one
real fit. Only then take on work that depends on fitting.

**4. One invariant loses its enforcement the moment you hold both repos.** GLLVM.jl's `AGENTS.md`
says gllvmTMB is a *read-only reference* — no engine surgery from that side. That has held
structurally because that lane never had this repo checked out. **You will have both.** Related and
concrete: `tools/parity_ledger.R` resolves the **Julia** ledger through `git show <ref>:` but the
**R** ledger from the working tree (`R_LEDGER_PATH`, lines 36 and 81). One lane can therefore move one
side of the comparison with an uncommitted edit while `CLOSURE: PASS` still prints. The fix is small
— a `--r-ref` defaulting to `origin/main` so neither side can be moved — but it is a **joint-contract
decision for Shinichi**, not a change to make unilaterally. The same reasoning protects GLLVM.jl's
frozen oracle `b4d5fee6`: a check that reads a pinned ref beats an invariant written in prose.

## What Was Accomplished (the lane that just closed)

Reverse parity — the capabilities the Julia twin had that R lacked — is closed as buildable work.
Thirteen PRs merged: #1239 (refusals that name a working route, plain-language front page, the R
capability ledger and parity tool), #1240 (zero-inflated `zi_poisson`/`zi_nbinom2`/`zi_binomial`,
family ids 17–19), #1248 (their 450-fit recovery campaign), #1251 (171 refusals given a next step;
bare-abort count 999 → 828 behind a ratchet that only falls), #1250 (`ordinal_logit()`, id 20), #1249
(`select_lv()` + `anova()` with chi-bar-square boundary p-values), #1253 (`ordination_uncertainty()`,
`ordiplot(ellipse = TRUE)`), #1254 (`censored_poisson()` engine, id 21), #1258 (50-seed recovery
campaign for the two new families), #1255/#1259 (handovers), #1256/#1257 (board).

## Current Working State

- **Working:** `main` @ `72ed68b57`; family ids 17–21 live and distinct; last full local suite 27,020
  passing with `R CMD check` at 0/0/0.
- **In progress:** PR #1260 (the arcG coverage design, docs only) merging on green.
- **Blocked:** nothing.

## Key Decisions & Rationale

- **D-220** — this move: one Cursor lane over both repos; campaigns still run on **Totoro**, not in
  the lane, because they never ran "in" the agent anyway (the session writes the script, dispatches
  over SSH, reads results back). Reach Totoro through the **existing ControlMaster socket** — a fresh
  login triggers a two-factor prompt. Core cap 150. GitHub Actions is barred for campaigns.
- **D-217 / D-216** — maintainer sign-off on the four public-API PRs.
- **D-204** — parity runs both ways for user-facing capabilities.
- **D-139** — estimate before any run; above 30 minutes, pre-run and get approval.
- **The distinction that must survive this handover:** *tests are regression guards; the
  validation-debt register is where a certified claim lives.* A 450-fit campaign found the shipped
  zero-inflated bars holding in only 82% / 82% / 92% of fifty seeds; the test sizes were deliberately
  **not** raised and the register rows quote the measured fractions instead. Do not collapse the two.

## Landing State

The landing gate reports the shared Dropbox checkout as unlanded: 3 untracked paths
(`.codex/worktrees/`, `.worktrees/`, a stray `docs/dev-log/lanes/cursor-mspl-arc-1a/LOOP/README.md`)
and ~633 unpushed commits on old `agent/*` and `tmp/*` branches. **None of it is this lane's.** The
untracked paths are worktree metadata and one stray README, present before the session began. The
unpushed commits are local-only branches from a May effort whose named artifacts no longer exist on
`main` — established by audit, not assumed from age. Left untouched.

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| all `claude/overnight-*`, `claude/board-refresh-*`, `claude/handover-update-*`, `claude/arcF-*` | y | y | merged | LANDED |
| `claude/arcG-coverage-design` | y | y | #1260 open, merging on green | LANDED-PENDING-CI |
| `claude/cursor-handover-20260904` | y | y | this PR | LANDED |
| Stashes in worktree `gllvmTMB-gapclose-20260902` | n | n | none | CARRIED-OVER |

**CARRIED-OVER:** two stashes holding a superseded fix to the parity tool's parser. The canonical fix
is on `main`. **Do not apply them.** Inspect with
`cd /Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902 && git stash show -p stash@{1}`.
Safe to drop.

FINDINGS-OF-RECORD: none — every finding is on `main` or in the vault (D-216, D-217, D-220), not on a
branch.

## Environment Cursor needs

- **Repo:** `/Users/z3437171/Dropbox/Github Local/gllvmTMB`. That checkout sits on **another lane's
  branch** (`claude/codex-handover-20260820-randslope-terrapin`, 633 behind) — **do not work in it.**
  Make a worktree: `git worktree add -b <branch> ~/local-scratch/lanes/<name> origin/main`.
- **Toolchain:** R with TMB. `Rscript -e 'devtools::load_all(".")'` compiles the DLL (minutes, once
  per worktree). Tests: `NOT_CRAN=true Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/<f>.R")'`.
  Full check: `Rscript -e 'devtools::check(args = "--no-manual")'` (~25 min).
- **Env vars:** `NOT_CRAN=true` for tests; `OPENBLAS_NUM_THREADS=1` and `OMP_NUM_THREADS=1` for any
  fitting or campaign work — fits are single-threaded and oversubscribing slows everything.
- **Safe verification command** (fast, proves the build works):
  `NOT_CRAN=true Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-gapclose-next-steps.R")'` → expect 7 pass, 0 fail.
- **Compute:** Totoro `snakagaw@totoro.biology.ualberta.ca`, via the existing socket at
  `~/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22`. 384 cores; cap yourself at 150.
- **Never stage:** the three untracked paths above; anything under another lane's worktree.
- **Push policy:** the H² pattern binds this lane to **local commits only by default** — ask Shinichi
  once at G0 whether this run may push named branches.

## Next Immediate Steps

Ordered. All need Shinichi's go-ahead — they were left unstarted by his "stop at the parity" fence.

1. **Prove the lane can build and fit** (Critical Context 3). Not optional, and not a formality.
2. **`ordination_uncertainty()` coverage.** The design is landed at
   `dev/gapclose/arcG/coverage-design.md` (PR #1260). It is design-only and **not approved to run** —
   4,500 fits, estimated 3.75–12 core-hours. The next step is the **pre-run** it specifies, timing the
   fit, the `sdreport` call and the sparse solve separately; the campaign is decided on those numbers.
3. **The parity-tool `--r-ref` fix** (Critical Context 4) — put it to Shinichi as a joint decision.
4. **The 828 refusals still lacking a next step** ([#1247](https://github.com/itchyshin/gllvmTMB/issues/1247)); #1251 is the worked pattern.
5. **The rest of the backlog**, issues #1241–#1246.

## Blockers / Open Questions

Nothing blocking. One open question worth raising eventually: the chi-bar boundary test shipped in
#1249 measures an empirical size of 0.095 (Monte Carlo standard error 0.021) against a nominal 0.05
at q = 3. It was reported rather than buried and Shinichi approved shipping it, but it is a real
calibration gap.

## Gotchas & Failed Approaches

The four traps are in Critical Context 2 — they are the highest-value part of this document. Three
more:

- **A narrow search returning nothing is not evidence of absence.** A previous agent reported that
  GLLVM.jl had run no comparable campaign, having read dated status notes as current; it existed, on
  an unmerged branch.
- **A wrong runtime family id dispatches the wrong likelihood while everything still appears to run.**
  Two families independently claimed id 20; after renumbering, every verification number was
  re-measured rather than assumed unaffected.
- **The validation-debt register is under heavy multi-lane contention.** Expect to rebase edits to
  `docs/design/35-validation-debt-register.md`; that is normal for that file.

## How to Resume

Run lane preflight first, then compare this document against the current git state and classify every
item **OWED · DONE · RETRACTED · PROTECTED** — execute only OWED.

```sh
~/shinichi-brain/tools/lane_preflight.sh gllvmTMB
```

Read in order: `AGENTS.md` / `CLAUDE.md` · this file ·
`docs/dev-log/handover/2026-09-03-claude-handover.md` (the outgoing lane's own handover, still
accurate, and the source of the gotchas) · `docs/dev-log/after-task/2026-09-03-gapclose-overnight-arcs.md`
(evidence behind every claim) · `docs/design/35-validation-debt-register.md` rows FAM-21…FAM-25 and
EXT-38 (what is and is not certified) · `dev/gapclose/arcG/coverage-design.md` (the next real arc).

```text
Read AGENTS.md and docs/dev-log/handover/2026-09-04-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
