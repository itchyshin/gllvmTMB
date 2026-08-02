# Ultra Plan — Missing-data ledger closure (#336/#337/#338)

**Status:** G0 approved 2026-08-01; `/goal` executed. See after-task
`docs/dev-log/after-task/2026-08-01-missing-data-ledger-closure.md`.

---

```text
🎯 GOAL
PLATFORM: Cursor (this session plans; execute via /goal after G0 — live R checks may hand to Codex if needed)
DELIVERABLE: Close (or honestly hold) GitHub issues #336/#337/#338 against already-shipped MIS rows + Phase 2b/2c tests; leave a truthful next-capability pointer (VA Design 107, not greenfield 2b).
HEADLINE: Retire stale "implement #336 Phase 2b" programme debt — MIS-27 is already `covered` on origin/main @ 6a5bc352.
IN PARALLEL: (cheap) evidence map of MIS-27/28 + Phase 2c tests vs issue gates; (cheap) MC/handover wording audit.
DEFER / FENCED: greenfield Phase 2b engine; MIS-32 / correlate_with="response"; coverage campaigns (D-112); VA template edits (Design 107); tweedie slope campaign; protected Dropbox checkout claude/profile-coverage-remeasure-20260718; deleted slope lane.
DISCIPLINE: verify by citing register rows + named test_that blocks + narrow test run; compute = local laptop only (no Totoro/DRAC); closure = after-task + issue comments/closes + check-log line. Keep 0.6 recovery-only framing.
```

**ARC PROGRAM:** size mode · recommended **1–2 h** (ceiling ~120 min) · Arc 0 = ledger closure packet + issue disposition · Rung 1 (only if Fisher gate unmet) = shared-group independence pin · integrate/closeout always · under-run → name next capability pick (Design 107 vs tweedie) without padding.

---

## WHAT THE BRAIN / REPO ALREADY KNOWS

- D-112: 0.6 ships recovery-only interval framing; no coverage re-measure owed.
- D-113: post-0.6 capability programme; Mission Control names missing-data #332 as primary slice — but #336's *engine* already landed (PR era #391 / MIS-27 `covered`).
- Design 107: VA hard-errors on incomplete unit×trait grids; Ayumi response-`include` blocked on VA path. Real capability gap after ledger hygiene.
- Tweedie slope remains gated in the gap ledger.

## Phase 0.25 — Sweep receipt (gate for Phase 1)

| Surface | Evidence ran | Finding | Call |
| --- | --- | --- | --- |
| repo git state | `git -C "$REPO" fetch origin main`; `git worktree list`; worktree `@ 6a5bc352` on `cursor/missing-data-ledger-336-20260801`; `branch_drift_check` 0/0 vs origin/main; `gh pr list` open = none | Tip is handover merge #889; no open competing PR; primary Dropbox tree still dirty D-112 | **resume nothing for 2b** — new ledger branch only |
| twin / sister | Design 59 / drmTMB MD3b contract cited in #336; gllvmTMB tests port MD3b blocks in `test-missing-predictor-gaussian.R` | Sister contract already ported | **reuse** evidence; do not re-port |
| brain | prior Arc Card + MC `gllvmTMB.json` next_safe_action; search notes for MIS-27 / Design 107 | MC thinks "pick #336 or tweedie"; register says MIS-27 covered | **build-the-gap** = issue ledger + pointer honesty only |
| **Verdict** | | Genuinely new = Rose/Fisher closure of open #336/#337/#338 + stop agents rebuilding 2b. Optional thin independence pin if shared-group gate lacks a test. | **reuse shipped code / build ledger gap** |

### First-action failure (corrected)

Running from `~` failed with `fatal: not a git repository` because `git fetch` / `git worktree add` need a repo cwd (or `git -C`). The follow-on preflight then saw no directory. Secondary note: branch `main` is already checked out at `…/gllvmtmb-pkgdown-abi`; prefer `-b <new-branch> origin/main` (detached `origin/main` also works but is worse for a write lane).

**Corrected copy-paste (any cwd):**

```sh
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"
WT="/private/tmp/gllvmtmb-missing-data-336-20260801"

git -C "$REPO" fetch origin main
# If WT already exists (detached or named), skip add and just use it:
#   git -C "$WT" status -sb
# Else create named branch worktree (do NOT omit -b when claiming a write lane):
git -C "$REPO" worktree add -b cursor/missing-data-ledger-336-20260801 "$WT" origin/main

bash ~/shinichi-brain/tools/lane_preflight.sh "$WT"
cd "$WT"
```

**Current worktree state (2026-08-01):** `$WT` EXISTS · branch `cursor/missing-data-ledger-336-20260801` · `6a5bc352` · tracking `origin/main` · clean relative to tip.

Lane preflight reported recent Codex *merges* (no open PRs). Declare: `PLATFORM: cursor | LANE: missing-data-ledger-336 | FOREIGN LANE: none live (recent Codex merges on main only)`. Do not touch Codex-owned EVA/spatial historical lanes.

---

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Fisher — Issue #336 gate 2 asks β_x unbiased when response and covariate SHARE the grouping factor. Grouped recovery tests exist (b_x + group SD) but an explicit shared-group independence pin was not found in a quick scan. · Matters for honest close vs hold. · Recommend: close #336 citing MIS-27 + Phase 2b tests IF shared-group pin is present on re-read; else hold open for Rung 1 only. · Q for Shinichi: none if default holds. · Default: hold-or-close from evidence, no MIS-32 scope.
  Rose   — Open issues + MC "implement #336" pointer will cause silent rebuilds. · Scope/claim risk. · Recommend docs/issue closure packet + MC/handover one-liner. · Default: ledger-only, no public capability claim change.
  Ada    — Recommended decision: execute Arc 0 ledger closure from existing WT; Rung 1 only if Fisher gate unmet; next capability = Design 107 (Ayumi) unless Shinichi picks tweedie.
```

## ADA'S RECOMMENDATION

Approve this plan. Do **not** re-implement Phase 2b. Use the existing worktree. After G0, run via `/goal` (not this chat).

## DECISIONS LOCKED

1. Arc = ledger closure, not greenfield 2b.
2. Worktree path + branch names as above (already created).
3. No coverage campaign; D-112 framing stands.
4. Protected Dropbox coverage checkout stays untouched.
5. Post-arc default next capability pointer = **Design 107 VA missing-data** (Ayumi unblock), with tweedie as explicit alternate only if Shinichi overrides.

## QUESTIONS STILL OPEN (Phase 0.4 — at most these)

1. After ledger close, confirm next capability = Design 107 (default) vs tweedie?
2. Want NotebookLM prior-art search? **Recommended: no** for ledger hygiene.

---

## SLICE TABLE

| ID | Member | Model+effort | Bar | Dispatch | Time | Detail | Dep |
| --- | --- | --- | ---: | --- | ---: | --- | --- |
| S0 RECON | Scout | Composer/Grok low | Cursor Models | native | 15m | Map #336/#337/#338 gates ↔ MIS-27/28 ↔ `test-missing-predictor-gaussian.R` Phase 2b/2c `test_that` names; flag shared-group pin present/absent | — |
| S1 CLOSE | Rose+Fisher | Auto Cost / Sonnet med | Other Models | native | 40m | Write closure packet under `docs/dev-log/after-task/`; comment+close or hold issues with cited evidence | S0 |
| S2 RUNG1 | Curie | Composer med | Cursor Models | native | 0–45m | **Only if S0 says independence gate unmet:** thin shared-group pin test in `test-missing-predictor-gaussian.R` | S0 |
| S3 VERIFY | Scout | Composer low | Cursor Models | native | 15m | Narrow: `testthat::test_file("tests/testthat/test-missing-predictor-gaussian.R")` under heavy if Rung1; else re-read citations | S1/S2 |
| S4 POINTERS | Rose | Auto Cost med | Other Models | native | 15m | Fix MC/handover/CLAUDE pointer so "next" ≠ rebuild 2b; check-log line | S1 |
| S5 RECONCILE | Melissa | Auto Cost low | Other Models | native | 10m | `docs/dev-log/plan-actual/2026-08-01-missing-data-ledger.md` | S3–S4 |

**LUNA SUITABILITY:** yes — S0/S3 mechanical (Cursor Composer as scout bar).  
**FAN-OUT BUDGET:** checkpoint=`missing-data-ledger-336` · children ≤4 · ceiling 0 · no Sol/Opus required.  
**ULTRA EFFORT:** no.  
**SEARCH:** none (NotebookLM offered; default skip).  
**ESTIMATE:** ~90–120 min wall · fits one `/goal` session.  
**REVIEW (plan):** Rose confirms sweep receipt non-vacuous — **pass** (commands cited above).  
**VERIFY:** cited MIS rows + issue disposition + optional narrow test.  
**RECONCILE:** Melissa required (meaningful close).  
**COMPUTE:** local only — ask Totoro/DRAC? **N/A** (no heavy campaign).

### Parallel / sequential

- PARALLEL after S0: none heavy; S1 then optional S2.
- SEQUENTIAL: S0 → S1 → (S2?) → S3 → S4 → S5.

---

## Out of scope (hard fence)

- Editing protected D-112 Dropbox dirty files / staging `.claude/` `.uinit/`
- Reopening deleted slope branch
- Coverage re-measure
- Implementing Design 107 or tweedie in this arc
- `correlate_with="response"` / MIS-32

---

## G0 — paste-ready `/goal` prompt (after approval)

```text
/goal Missing-data ledger closure for gllvmTMB #336/#337/#338

PLATFORM: Cursor
WORKTREE: /private/tmp/gllvmtmb-missing-data-336-20260801
BRANCH: cursor/missing-data-ledger-336-20260801 @ origin/main (6a5bc352+)
PLAN: docs/dev-log/plans/2026-08-01-ultra-plan-missing-data-ledger-closure.md

DO:
1. Re-read MIS-27/28 and Phase 2b/2c tests; decide close vs hold for #336/#337/#338 (Fisher shared-group independence gate).
2. Write after-task closure packet; comment/close issues with evidence paths; optional thin independence pin ONLY if gate unmet.
3. Update Mission Control / handover pointer: 2b shipped; next capability = Design 107 (unless Shinichi said tweedie).
4. Narrow test if code changed; check-log + Melissa plan-actual.
5. Keep D-112 recovery-only; no coverage; do not touch Dropbox claude/profile-coverage-remeasure-20260718.

DONE WHEN: issues closed or held with one named pin; after-task landed; next pick named; no greenfield 2b work.
```

**LANE RECEIPT:** `START A FRESH TASK` after G0 — do not grow the planning chat into Phase 3.
```
