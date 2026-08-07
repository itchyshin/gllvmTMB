# Ultra-plan + Melissa reconcile — VA series synthesis (G0=1)

**Date:** 2026-08-07  
**Lane:** `codex/va-gh-all-families` · `/private/tmp/gllvmtmb-va-gh-all-families`  
**G0:** Shinichi approved **G0=1** — docs-only series synthesis (no fence / merge / Totoro)

---

## Phase 0.25 — Prior-work sweep receipt

| Surface | Evidence ran | Finding | Call |
| --- | --- | --- | --- |
| **repo git state** | `git status -sb`; `git log --oneline -20`; `branch_drift_check.sh`; `git worktree list` | `codex/va-gh-all-families` @ `4847785f`, **ahead 13** of `origin/codex/va-gh-all-families`, **169 ahead / 0 behind** `origin/main`; dirty leftovers (probes/results) **out of this arc** | **resume this lane**; docs-only commit surface |
| **twin / sister** | Design 110; drmTMB D-127 brain hit | Sister drmTMB VA revival is separate; no twin synthesis to co-opt | **n/a** — build gllvmTMB series lock only |
| **brain** (`search_all_projects: true`) | MCP hybrid “VA validation series synthesis…” + “working position Laplace…”; vault AGENT_LOG #947/#948; DR31 multinomial | MC already lists G0 menu item (1)=synthesis; #947/#948 parked; DR31 says multinomial VA later; no prior series-synthesis audit | **reuse** banked audits + MC position; **build** synthesis writeup gap |
| **log/history grep** | `grep -in 'va.*series\|G0=1\|series.synthesis' memory/AGENT_LOG.md`; `DECISIONS.md` AGHQ/VA; `OPEN_QUESTIONS.md`; `journal/`; `projects/deep-research/README.md` VA/AGHQ | AGENT_LOG holds #947/#948 park lines; DR21/DR25/DR31 exist; **no** prior `va-series-synthesis.md` | **build-the-gap** = durable synthesis audit |
| **Mission Control** | `live/status/gllvmTMB.json` | `next_safe_action` = STOP for G0 with option (1) docs synthesis | **execute G0=1**; then update `next_safe_action` |
| **Verdict** | — | Measurement ladder banked; genuinely new = one durable working-position doc + MC/check-log closeout | **reuse evidence / resume lane / build synthesis** |

---

## ARC CARD — VA series synthesis (docs-only)

**Mode:** size  
**Requested outcome:** one durable docs-only synthesis locking the 2026-08-07 VA validation working position (G0=1).  
**Mechanism authority:** docs/audits/ultraplan/check-log/Mission Control only — **no** R/src, no fence, no Totoro, no PR/merge unless docs-only commit on this branch.  
**Recommended arc:** **~75–100 minutes** (range 60–120).  
**Time contract:** ceiling ~2 h.  
**Estimate confidence:** **inferred** (similar docs locks ~30–90 min; inventory is large but verdicts already written).  
**Arc 0 outcome:** `docs/dev-log/audits/2026-08-07-va-series-synthesis.md` + MC/`check-log`/after-task updated.  
**State transition:** MC “awaiting G0” → **G0=1 done**; working position locked in-repo; **no metric/fence change**.  
**Executable rung and evidence:** write synthesis from banked audits; verify citations resolve; commit docs.

### Budget

| Segment | Minutes | Output / stop point |
| --- | ---: | --- |
| Orient | 15 | Sweep receipt + audit inventory |
| Core | 45 | Arc Card + ultra-plan + synthesis audit + MC/check-log/after-task |
| Verify | 15 | Path cite check; no R/src in commit; claim fence scan |
| Repair reserve | 10 | Missing cite / MC JSON hygiene |
| Closeout | 10 | Melissa reconcile + commit (+ push if tracking) |
| **Total** | **~95** | |

**In scope:** synthesis audit; ultraplan G0=1 close note; MC `next_safe_action`; check-log; after-task; docs commit.  
**Not in this arc:** fence/`auto`; Arc-1 merge; Totoro; #947/#948 builds; truncnb2/delta_ln campaign; R/src.  
**Evidence used:** banked 2026-08-07 audits (S0–S4); MC status; AGENT_LOG #947/#948; ultraplan success-bar lock.  
**Risk branch:** If a verdict conflict appears across audits, **record both + prefer the later Totoro ladder audit**; do not invent a third number.

**Done when:** synthesis path exists; MC points past G0=1; check-log + after-task landed; docs commit SHA recorded.  
**First action:** write sweep receipt + synthesis draft from audit verdicts.

### Actuals (complete at close)

**Recommended / actual:** 95 / ~70 · **Requested / used:** N/A / docs-only  
**Rungs completed:** Arc 0 (G0=1 synthesis)  
**Under-run event:** Arc 0 predicted 95, actual ~70; banked audit verdicts made core writeup faster than inventory feared  
**Calibration:** Orient bucket was right; Core overestimated — next docs-lock from banked audits ≈60–75 min  
**Metric movement:** none — preparation/position lock only  
**Result:** capacity used · **Next arc:** park (default) or new G0 for truncnb2/delta_ln / Arc-1 merge

**HAND TO ULTRA PLAN:** Arc 0 = docs-only VA series working-position synthesis; ~1–1.5 h; G0=1 already approved — execute without further G0; no fence/Totoro/merge.

---

## Ultra-plan GOAL (paste-ready)

```
🎯 GOAL
PLATFORM: Cursor (this session / parent lane) on worktree /private/tmp/gllvmtmb-va-gh-all-families · branch codex/va-gh-all-families
DELIVERABLE: Durable docs-only series synthesis locking the 2026-08-07 VA validation working position (LA default; binary/NB2/AGHQ/PoisG/parked rules).
HEADLINE: One synthesis audit that a future session can treat as the series lock — no fence flip, no Totoro, no Arc-1 merge.
IN PARALLEL: (i) audit digest cites, (ii) MC next_safe_action update, (iii) check-log + after-task — all docs.
DEFER: truncnb2/delta_ln campaigns; #947/#948 implementation; multinomial VA; fence/NEWS/register promotion; Arc-1 merge G0.
DISCIPLINE: verify by resolving cited audit paths + confirming no R/src in the commit · compute = none · closure = Melissa plan-actual + docs commit (+ push OK on tracking branch).
```

**ARC PROGRAM:** size; Arc 0 ≈ 95 min docs synthesis (G0=1); no capacity ladder — stop when synthesis + closeout land.

### SLICE TABLE

| Slice | Member | Model+effort | Bar | Detail | Dep |
| --- | --- | --- | --- | --- | --- |
| RECON | Ada/scout | inherit / low | Cursor Models | Sweep receipt (done above) | — |
| S1 Arc Card + plan | Ada | inherit | Other Models / Cursor | This file + ultraplan append | RECON |
| S2 Synthesis audit | Ada | inherit | Other Models / Cursor | `docs/dev-log/audits/2026-08-07-va-series-synthesis.md` | S1 |
| S3 MC + check-log + after-task | Ada | inherit | Cursor Models | `gllvmTMB.json`; check-log; after-task | S2 |
| MECHANICAL-VERIFY | Ada | inherit / low | Cursor Models | Cite paths exist; commit is docs-only | S3 |
| RECONCILE | Melissa | inherit / low | Cursor Models | This plan-actual Actuals | VERIFY |

**FAN-OUT:** 0 sub-agents (subagent constraint + docs-only; orchestrator executes).  
**LUNA SUITABILITY:** no — Cursor parent; mechanical inventory already inline.  
**ULTRA EFFORT:** no.  
**SEARCH:** none (repo+brain only; NotebookLM not required for a banked-evidence lock).  
**ESTIMATE:** ~1 session, <2 h wall.  
**REVIEW:** Rose claim-fence — synthesis must say scientific-only / no soft-PASS.  
**VERIFY:** path existence + `git diff --stat` docs-only.  
**CONSOLIDATE:** synthesis + MC + check-log + after-task + commit.

### WHAT THE BRAIN ALREADY KNOWS

- MC: measurement banked; G0 menu item (1) = docs synthesis.
- #947 WAIC/CV remember-only; select on unpenalised LA.
- #948 Hui closed-form NB2 VA parked do-not-build.
- DR31: multinomial VA later / not first.
- Success bar LOCKED; HMSC deferred; always 2×2.

### WHAT SHINICHI TOLD US

- G0=1 approved; run arc-creation then ultra-plan; **execute** docs work; stay docs-only; commit OK; push OK for docs.

### DECISIONS LOCKED

1. Working position text matches G0=1 outcome list in the user brief.
2. No fence / Totoro / Arc-1 merge from this arc.
3. Next safe action after close = wait for a **new** G0 (stop vs optional truncnb2/delta_ln vs Arc-1 merge).

### QUESTIONS STILL OPEN

None blocking execution — G0=1 already chosen. Optional later: truncnb2/delta_ln go; Arc-1 merge G0.

---

## Melissa reconcile (Phase 4.5)

| Axis | Planned | Actual | Tag |
| --- | --- | --- | --- |
| Scope | Docs-only synthesis | Docs-only synthesis (+ MC/check-log/after-task/commit) | match |
| Evidence | Banked audits only | Same | match |
| Model routing | No fan-out | No fan-out | match |
| Safety gates | No R/src/fence/Totoro | Enforced | match |
| Public claims | Scientific lock only | Synthesis states non-claims | match |
| Handoff | Update MC next_safe_action | Updated past G0=1 | match |

**Material deviations:** none expected.  
**Sweep receipt:** present (table above) — non-vacuous.

---

## Approval (formal close)

**Shinichi approved 2026-08-07** — formal sign-off on the completed G0=1
ultra-plan / working-position lock (viewing this plan-actual; also `/goal`
invocation). Treat G0=1 as **approved and closed**.

- Execution commit: `13fc9fd1` (synthesis + plan-actual + after-task + check-log).
- LOOP kit: `lanes/va-series-synthesis/LOOP/` (scaffold + verify; no rebuild).
- **Next:** park / wait for a **new** G0. “Approve” is **not** licence for
  truncnb2/delta_ln, Arc-1 merge, fence, or Totoro.
