# 2026-05-25 day retrospective — Shannon

**Date:** 2026-05-25
**Author:** Shannon (cross-team coordination), with Rose
(scope honesty) reviewing.
**Status:** Reflective audit only. No engine code, no design
docs, no validation-debt register row was changed by this
memo. Captures lessons from a non-trivial coordination day so
future agents do not re-derive them.

## 1. Why this memo

The 2026-05-25 work surface had three things happening in
parallel: (a) a non-trivial M3 simulation lane (Claude),
(b) a Codex four-lane background dispatch (Codex/Ada), and
(c) a stack of three open Codex PRs with file overlap. The
day ended with five merged PRs, three open PRs, and one new
draft integration PR. The lessons below should not have to
be re-derived. Per the drmTMB-team discipline gap that
AGENTS.md captures — *"we write code faster than we write
about what we do"* — this memo closes that gap for the day.

## 2. Timeline (key events, chronological)

| Time (UTC, approx) | Event | Reference |
|---|---|---|
| Earlier 2026-05-25 | M3 binomial Scenario A signal flagged on PR #262 (post-dispatch results memo): ratios 0.24/0.32/0.42 across binomial × d ∈ {1,2,3}, far below the pre-registered band [0.80, 1.15] | [PR #262](https://github.com/itchyshin/gllvmTMB/pull/262) |
| ~midday | Jason cross-package scout (Round 1) reproduces the signal in `gllvm` and `glmmTMB` — falsifies "engine-specific bug" framing | [PR #263](https://github.com/itchyshin/gllvmTMB/pull/263), audit `2026-05-25-jason-cross-package-binomial-sigma-scout.md` |
| ~midday | Round 2 (galamm) confirms the signal in a third independent implementation | same scout audit |
| ~midday | Round 3 N-sweep (N=120/240/480) shows ratios increasing monotonically with N → "DGP contains an unidentified component that washes out asymptotically" | same scout audit |
| ~midday | Round 4: maintainer ratifies *"simulations cannot have psi bit — as psi for binary emerges from binomial error"* — DGP-bug attribution | maintainer message |
| Afternoon | PR #263 (scout + DGP patch) + PR #264 (regression guard + Design 42 rule) merged to `main` | squashes [`19c079b`](https://github.com/itchyshin/gllvmTMB/commit/19c079b), [`9c3a150`](https://github.com/itchyshin/gllvmTMB/commit/9c3a150) |
| Afternoon | M3 production-grid re-dispatch under patched DGP at r10; binomial × d=2 and mixed × d=2 hit `PASS_TO_SCALE`; PR #266 records post-patch results | [`108fdda`](https://github.com/itchyshin/gllvmTMB/commit/108fdda) |
| ~17:00 UTC | PR #267 (Set C joint-SDM gate matrix + r200 dispatch plan + Design 54 scout protocol) opened; Codex review folded as Design 54 §3.5 anti-patterns; merged | squash [`4cf59c0`](https://github.com/itchyshin/gllvmTMB/commit/4cf59c0) |
| ~19:00 UTC | Codex dispatches four parallel background lanes (Curie parity test, Rose+Shannon validation map, Boole+Grace+Pat figure QA, Grace+Curie+Fisher r200 readiness); all four return + Codex bundles into draft PR #268 | [PR #268](https://github.com/itchyshin/gllvmTMB/pull/268) |
| ~21:00 UTC | PR #269 (coord-board sync recording the Validation Factory plan) merged | squash [`397cc9e`](https://github.com/itchyshin/gllvmTMB/commit/397cc9e) |
| ~21:30 UTC | Shannon+Rose read-only review of PR #268 (this lane's prior work) posted as single PR comment | [#268 comment 4537584485](https://github.com/itchyshin/gllvmTMB/pull/268#issuecomment-4537584485) |

## 3. What landed on `main`

Five squash commits in chronological order:

1. [`19c079b`](https://github.com/itchyshin/gllvmTMB/commit/19c079b) — PR #263: Jason cross-package binomial scout + m3-grid DGP patch.
2. [`9c3a150`](https://github.com/itchyshin/gllvmTMB/commit/9c3a150) — PR #264: M3 binomial-psi guard + Design 42 rule.
3. [`108fdda`](https://github.com/itchyshin/gllvmTMB/commit/108fdda) — PR #266: M3 production-grid rerun under patched DGP.
4. [`4cf59c0`](https://github.com/itchyshin/gllvmTMB/commit/4cf59c0) — PR #267: Set C gate matrix + r200 plan + scout protocol (docs-only).
5. [`397cc9e`](https://github.com/itchyshin/gllvmTMB/commit/397cc9e) — PR #269: Coord-board sync (docs-only).

No validation-debt register row moved. CI-08 and CI-10 stay
`partial` per Design 50 §9 because the post-patch evidence is
r10 (below the r200 promotion floor).

## 4. Lessons by topic

### 4.1 Cross-package scout protocol (Design 54)

The four-round template is the durable artefact of the day.
The 36 hours of investigation that the signal initially
triggered would have been days more if cross-package had not
been the first move. Codified in
[`docs/design/54-cross-package-scout-protocol.md`](../../design/54-cross-package-scout-protocol.md).

Reusable round structure:

1. **Round 1**: one sister package, same N, same statistic.
   Either falsifies the engine-bug hypothesis or proceeds.
2. **Round 2**: second sister package. Confirms the signal in
   three implementations or surfaces an API translation issue.
3. **Round 3**: N-sweep. Bias-vs-N behaviour discriminates
   DGP misspecification (washes out asymptotically) from
   engine bug (constant or growing bias).
4. **Round 4**: domain-knowledge ratification. The
   maintainer's one-line ruling (or the relevant lead
   persona's) collapses the diagnostic.

Design 54 §3.5 (added per Codex review) names three
anti-patterns: DGP-scout vs internal-scout, family-design
rulings vs diagnostic-API work, "not implicated" vs "not yet
checked." These were the three conflations that the day's
work could have easily slipped into.

### 4.2 Worktree collision discipline

Earlier in the session, working in the maintainer's main
worktree caused two avoidable side-effects: edits getting
dropped when the maintainer checked out a different branch,
and a `git pull --ff-only origin main` accidentally
fast-forwarding the maintainer's working branch to current
main. Switching to a per-agent worktree pattern eliminated
both.

The discipline that emerged:

- Each active agent has its own worktree at a distinct
  filesystem path.
- Each worktree is on its own branch.
- No agent runs `git pull` on a worktree it does not own.
- The main worktree (where the maintainer works) is
  off-limits to any non-maintainer agent.

Captured in `docs/dev-log/coordination-board.md` via PR #269.

### 4.3 Design 50 §9 status-change discipline

The post-patch r10 rerun showed two cells (`binomial × d=2`
and `mixed × d=2`) at `PASS_TO_SCALE`. The temptation to
promote CI-08 / CI-10 to `covered` on partial evidence was
real. Design 50 §9 — *"no status change without sufficient
evidence"* — was the brake. The post-patch memo (PR #266 §6)
explicitly records the deliberate non-update. The r200
dispatch plan (PR #267, audit `2026-05-25-m3-r200-dispatch-plan.md`)
codifies the next-step requirement before any register edit:
**r200 with empirical coverage ≥ 0.94 on `Sigma_unit[tt]`**.

### 4.4 The success-complacency anti-pattern (ci-pacing-discipline skill)

Five successful self-merges in one day (PR #263 / #264 / #266
/ #267 / #269). Per the skill's anti-pattern note, "a streak
of successes is the most dangerous moment to skip the
pre-mortem." The discipline held — every merge was preceded
by an explicit failure-modes check, every CI cycle was
allowed to complete on the actual head SHA, no "I'll just
push this one fix-up" appeared. The discipline cost ~30
seconds per merge; the savings were one not-shipped red.

### 4.5 Persona-active-naming pattern

Every memo this day named the lead + reviewer personas
explicitly: Curie / Fisher / Rose / Shannon / Jason / Grace
/ Boole / Pat / Darwin / Florence. AGENTS.md's
2026-05-16 directive ("personas are named ACTIVELY") held
up: the audit trail is readable, the review surface is
explicit, and handoff between PRs is cheap. The maintainer's
original framing — *"I like drmTMB team actually saying the
name of who's doing what"* — has stabilised into project
practice.

### 4.6 In-job CI classifier fast-path

Five docs-only PRs all ran in 7-14 seconds on each OS via the
fast-path classifier (PR #187 / #203 lineage). The
classifier is doing real work: full R CMD check would have
been ~5-25 minutes per OS. The cost saving is real but the
trust requires the classifier to be conservative — any
non-docs change should fall through to full check.

### 4.7 The PR #261 CI-not-firing observation

PR #261 (Codex's diagnostic-teaching reset) had **zero** CI
runs on its branch at first observation. The maintainer
chose to re-trigger via an explicit `ci: retrigger
diagnostic teaching reset checks` commit rather than skip-CI
merge. The classifier had not fired because the workflow
needed an explicit re-trigger. Worth investigating
post-stack whether this is a recurring pattern that warrants
a workflow tweak.

## 5. Personas activated this day

| Persona | Lane | Files / artefacts |
|---|---|---|
| **Curie** | Simulation fidelity — DGP audit + N-sweep | `dev/jason-binomial-scout.R`, scout audit, parity test in #268 |
| **Jason** | Cross-package scout — 4 rounds | scout audit, Design 54 |
| **Fisher** | Inference policy — Design 50 §9, r200 readiness | r200 readiness review (#268), r200 dispatch plan (#267) |
| **Rose** | Scope honesty — status non-update + audit reviews | post-patch memo §6, gate matrix, #268 review |
| **Shannon** | Cross-team coordination — coord-board, merge stack, Codex relay | coord-board, Codex messages, #269 |
| **Grace** | CI / workflow / timing — r200 plumbing review, fast-path classifier observation | r200 readiness review |
| **Boole** | Formula grammar / API — gate-matrix verdicts on `latent / unique / dep / indep` | gate matrix verdicts |
| **Pat** | Applied-user clarity — figure QA, joint-sdm prose | figure QA audit |
| **Darwin** | Biology-first framing — joint-sdm scope-rewrite framing | joint-sdm.Rmd diff in #268 |
| **Florence** | Figure / visualisation — explicit **FAIL** on joint-sdm Tier-1 publication readiness | figure QA audit |
| **Noether** | Math-vs-implementation alignment — Bernoulli identifiability | Round 4 maintainer ratification (mechanism), Design 42 rule |
| **Ada** | Orchestration — Validation Factory plan, merge-order decisions | coord-board, four-lane delegation, day's directive flow |

## 6. What was deliberately NOT done

- **No r200 dispatch.** Both maintainer-gated and workflow-plumbing-gated.
- **No CI-08 / CI-10 register promotion.** Stayed `partial` per Design 50 §9.
- **No joint-sdm public restoration.** Article stays in the `internal` pkgdown tier; figure QA returned FAIL; restoration awaits figure-repair PR.
- **No engine debugging.** The signal was DGP-attributed; no R/ or src/ touched.
- **No `diagnostic_table()` cross-link in joint-sdm.** Per Codex confirmation, scoped to single-fit posterior-predictive only.
- **No edits to `R/diagnose.R`, `tests/testthat/test-sanity-multi.R`, `ROADMAP.md`, or `docs/dev-log/check-log.md`** (Codex stack files).

## 7. Open questions handed forward

1. **Maintainer decision on #261 CI.** Re-trigger (which Codex did via commit `f3cdc17`) vs explicit skip-CI merge. The day ended with the re-trigger in progress.
2. **#268 bundle vs split.** The Shannon+Rose review (#268 comment 4537584485) returned WARN — internally consistent, but a 3-way split would buy flexibility (test+design/04 → audits → joint-sdm prose).
3. **r200 dispatch scope.** Design 50 §5 / r200 plan §2 lists three options; Codex queue item 4 recommended Option B (binomial-focused 4-cell: binomial d=1/2/3 + mixed d=2). The plumbing PR is a prerequisite (workflow timeout fix per Audit 3); the dispatch itself is maintainer-gated.
4. **Codex queue items 3 and 5.** Figure repair (joint-sdm biplot chunk) and Restoration Queue sprint (behavioural-syndromes → animal-model → psychometrics-irt → mixed-family-extractors → lambda-constraint) are Codex's next slices after #268 settles.

## 8. Cross-references

- [Design 42](../../design/42-m3-dgp-grid.md) — M3 DGP grid + binomial-`psi` rule (added 2026-05-25 per PR #264).
- [Design 50](../../design/50-m3-3b-surface-admission.md) — M3.3b surface admission; §5 thresholds, §9 status-change rule.
- [Design 54](../../design/54-cross-package-scout-protocol.md) — Cross-package scout protocol; §3.5 anti-patterns.
- [`2026-05-25-jason-cross-package-binomial-sigma-scout.md`](2026-05-25-jason-cross-package-binomial-sigma-scout.md) — 4-round scout walk-through.
- [`2026-05-25-m3-postpatch-rerun.md`](2026-05-25-m3-postpatch-rerun.md) — post-patch grid results.
- [`2026-05-25-m3-r200-dispatch-plan.md`](2026-05-25-m3-r200-dispatch-plan.md) — r200 plan + Design 50 §5 promotion rule.
- [`2026-05-25-set-c-joint-sdm-gate-matrix.md`](2026-05-25-set-c-joint-sdm-gate-matrix.md) — Set C joint-SDM gate matrix.
- PR #268 (draft) — Codex's bundled integration PR with the four background-lane outputs.

— Shannon (drafter), with Rose lens on scope honesty.
