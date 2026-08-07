# Ultra-plan + Arc Card — VA Arc-1 merge/fence (C) · G0 STOP

**Date:** 2026-08-07  
**Evidence lane (read-only for this plan):** `codex/va-gh-all-families` @ `98839853`  
**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families` (~173 ahead of `origin/main`)  
**Status:** **G0 APPROVED 2026-08-07** (Shinichi). Execute on new lane per handover  
`docs/dev-log/handover/2026-08-07-cursor-handover-va-arc1-merge-fence.md`.  
Still **no merge to main** until a further merge G0. Scaffold + Arc 0 inventory + code PR prep authorised.

---

## Phase 0.25 — Prior-work sweep receipt

| Surface | Evidence ran | Finding | Call |
| --- | --- | --- | --- |
| **repo git** | `git status -sb`; `git log origin/main..HEAD`; `git diff --stat origin/main...HEAD -- R/ src/ tests/ docs/`; `git worktree list` | Tip `98839853` (B truncnb2/delta_ln). **173** commits ahead of `origin/main`; **0** `src/` delta; **~21 R files / +3.8k/−0.4k**, **23 tests**, **~125 docs files**. Dirty leftovers (probes / ladder CSVs) **out of C**. | **do not merge this tip as one PR** |
| **Arc-1 product** | Gate E stop `ead23293` + public closeout `537e6da4`; after-task `2026-08-06-va-gh-h7-arc1-public-closeout.md` | H=7 + `auto→gh` for **18** scalar cells already implemented **on this branch**; fence admits 18 `(family,link)`; `calibrated=FALSE` retained | **reuse** Arc-1 closeout; **ship via new lane**, not fat tip |
| **series lock** | `docs/dev-log/audits/2026-08-07-va-series-synthesis.md` (G0=1); B audit truncnb2/delta_ln | LA everyday default; binary probit; NB2 VA-GH large-n; PoisG not Σ; parked #947/#948 | **cite in NEWS scope boundary**; does **not** licence `calibrated=TRUE` or Laplace→VA default flip |
| **Arc-2** | Totoro adjudication + NEWS on tip | 1/36 overall point PASS; 24 FAIL / 11 INCONCLUSIVE — mixed; already stated that fence does not auto-narrow | **keep Arc-2 labels frozen**; no soft-PASS |
| **brain** | MCP hybrid Arc-1/Gate E/fence | No prior merge-recipe note for this tip; lane-split map still multi-owner | **build** merge-split plan; **new lane** |
| **Verdict** | — | Genuinely new = clean merge path + PR split + G0 authority; product already exists on fat branch | **plan → G0 → (if approved) scaffold new lane** |

---

## ARC CARD — VA Arc-1 merge/fence (C)

**Mode:** size (outcome-first state transition, approval-gated)  
**Requested outcome:** Arc-1 scalar VA (H=7 GH / 18-cell fence / `calibrated=FALSE`) landable on `main` via a **reviewable** PR path — not a 173-commit evidence dump.  
**Mechanism authority (this session / until G0):** docs + planning only — Arc Card, ultra-plan sketch, lane recommendation, optional check-log. **Explicit exclusions:** no `git merge`, no `gh pr create`, no `R/integration-fence.R` / NEWS / register edits, no Totoro, no worktree scaffold.  
**Mechanism authority (post-G0, if approved):** new worktree/branch from `origin/main`; path-scoped (or curated) import of Arc-1 code/tests/man/NEWS honesty; optional separate docs-evidence PR; local `devtools::test` filters + `--as-cran` light; open PR(s) — **still no merge to main without a further merge G0** unless Shinichi says merge-on-green.  
**Recommended arc (post-G0 executable):** **~3–5 hours** capacity programme (Arc 0 inventory → Rung 1 code PR surface → Rung 2 optional docs PR → verify/close).  
**Time contract:** ceiling ~1 session post-G0; this planning slice ~30–45 min.  
**Estimate confidence:** **inferred** (closeout + branch topology known; cherry-pick graph messy → prefer path transplant; verify cost unknown until filter green).  
**Arc 0 outcome (post-G0):** new lane exists; commit-split inventory table (code vs docs vs leave-behind) checked into the new lane; first file list frozen.  
**State transition:**  
- **Now (planning):** evidence tip has Arc-1 + series banked → **G0 packet ready** (no metric/fence change).  
- **Intended after full C:** `main` (or open PR targeting `main`) carries Arc-1 public VA route with honest scope boundary; fat evidence branch remains archive / optional docs PR.  
**Executable rung and evidence:** **blocked until G0** — intervention = new-lane scaffold + path import + PR(s); retained evidence = green focused tests + NEWS/register Rose scan + PR URL(s).

### Capacity ladder (post-G0 only — do not start)

| Order | Budget | Outcome | Trigger / definition of done |
| --- | ---: | --- | --- |
| Arc 0 | 45–60 m | New worktree + split inventory (code/docs/leave) | G0 approve. Done when file/commit table + branch tip recorded. |
| Rung 1 | 90–120 m | Code/fence PR surface on new lane (Arc-1 product + tests + man + NEWS honesty) | After inventory. Done when focused VA/fence tests green locally. |
| Rung 2 | 45–75 m | Optional docs-evidence PR from fat branch (or defer) | If Shinichi wants series audits on `main`. Else **SKIP**. |
| Verify/close | 30–45 m | Rose claim-fence; check-log; after-task; PR open (not merge) | Always. |
| **Total capacity** | **~3.5–5 h** | | |

### Budget (this planning slice — Actuals below)

| Segment | Minutes | Output / stop point |
| --- | ---: | --- |
| Orient | 15 | Sweep receipt (above) |
| Core | 25 | This Arc Card + GOAL + lane recommendation |
| Verify | 5 | Paths/SHAs cited resolve; no R/src touched |
| Repair reserve | 5 | Amend inventory if tip moved |
| Closeout | 5 | check-log one-liner; G0 ask |
| **Total** | **~55** | |

**In scope (planning):** Arc Card; ultra-plan GOAL; recommended branch/base/worktree; split policy; G0 menu.  
**Not in this arc:** merge; PR; fence/`auto`/`calibrated` edits; Totoro; #947/#948; multinomial VA; PoisG promotion; absorbing dirty probe/result trees.  
**Evidence used:** Gate E / Arc-1 public closeout; series synthesis G0=1; tip `98839853`; `git diff --stat` R vs docs; NEWS Arc-2 honesty paragraph already on tip.  
**Risk branch:** If Arc 0 inventory shows Arc-1 cannot be separated from unretracted lane-2 research claims without rewriting history, **stop coding**, return a **file-list transplant recipe** (checkout paths from tip onto `main`) and ask Shinichi whether to (a) transplant, (b) ship a larger curated squash, or (c) park merge.

**Done when (planning):** this file exists; chat surfaces Arc Card + G0 ask; no merge/PR/fence edit.  
**Done when (post-G0 C):** new lane has Arc-1 code PR open (and optional docs PR); tests recorded; `calibrated=FALSE` + LA default still true; fat branch not force-pushed.  
**First action (now):** STOP — await G0.  
**First action (after G0 approve):** scaffold worktree at recommended path; write split inventory.

### Actuals (planning slice)

**Recommended / actual:** 55 / ~55 · **Requested / used:** plan-only / plan-only  
**Rungs completed:** planning Arc Card only (no post-G0 ladder)  
**Under-run event:** none  
**Calibration:** n/a until post-G0 execute  
**Metric movement:** none — preparation only  
**Result:** blocked on G0 · **Next arc:** post-G0 Arc 0 scaffold **or** park if G0 rejects

**HAND TO ULTRA PLAN:** Post-G0 C = new lane from `main`, path-scoped Arc-1 merge prep + optional docs PR; ~3.5–5 h; **no merge / no fence flip in the planning packet**; keep `calibrated=FALSE` and Laplace default.

---

## Ultra-plan GOAL (paste-ready — execute only after G0)

```
🎯 GOAL
PLATFORM: Cursor (or Claude/Codex as assigned) on NEW worktree (see lane recommendation) — NOT the fat evidence tip as merge vehicle.
DELIVERABLE: Reviewable Arc-1 ship path — (1) code/fence/tests/man/NEWS-honesty PR from origin/main; (2) optional separate docs-evidence PR; both keep calibrated=FALSE and Laplace default.
HEADLINE: Split the ~173-commit codex/va-gh-all-families tip so Arc-1 can land without drowning review in Totoro ledgers.
IN PARALLEL: (i) freeze file inventory code vs docs vs leave-behind, (ii) path transplant or curated import onto new branch, (iii) focused test filters for fence + VA routing/light.
DEFER: merge to main (needs explicit merge G0 unless green-to-merge authorised); calibrated=TRUE; Laplace→VA default; PoisG as Σ story; #947/#948; multinomial VA; dirty lanes/*/results and probe scripts.
DISCIPLINE: verify = focused testthat filters green + Rose claim-fence (no soft-PASS Arc-2) · compute = local only · closure = PR URL(s) + after-task + Melissa Actuals — STOP before merge unless told.
```

**ARC PROGRAM:** size; post-G0 ladder Arc0→Rung1→(optional Rung2)→close; ~3.5–5 h.

### SLICE TABLE (post-G0)

| Slice | Member | Model+effort | Bar | Detail | Dep |
| --- | --- | --- | --- | --- | --- |
| RECON | Ada/scout | inherit / low | Cursor Models | Worktree scaffold + split inventory table | G0 |
| S1 code surface | Ada+Gauss | inherit | Other Models / Cursor | Import Arc-1 R/tests/man + NEWS honesty onto `main`-based branch | RECON |
| S2 test gate | Curie/Grace | inherit | Cursor Models | `test-integration-fence`, `va-routing-oracle`, `va-all-family-*`, control exposure | S1 |
| S3 docs PR (optional) | Ada | inherit / low | Cursor Models | Orphan/docs-only PR from evidence tip **or** defer | G0 choice |
| Rose | Rose | inherit | Other Models | No soft-PASS; scope boundary; register IDs internal-only | S1–S3 |
| RECONCILE | Melissa | inherit / low | Cursor Models | Update this plan-actual Actuals | all |

**FAN-OUT:** 0–1 scout; no Totoro.  
**LUNA SUITABILITY:** yes for RECON inventory.  
**ULTRA EFFORT:** no.  
**SEARCH:** none required.  
**ESTIMATE:** one session after G0.  
**REVIEW:** Rose claim-fence mandatory before PR.  
**VERIFY:** focused tests + `git diff --stat` shows no `lanes/*/results` blobs.  
**CONSOLIDATE:** PR URL(s) + after-task + check-log.

### WHAT THE BRAIN / REPO ALREADY KNOWS

- Arc-1 Gate E **PASS** 18/18; public closeout commit `537e6da4`.
- Arc-2 Totoro mixed; fence does not auto-change.
- Series synthesis G0=1: LA default; VA remains research/opt-in; `calibrated=FALSE`.
- Tip mixes lane-2 speed/SE/interval research + Arc-1 + series docs (~91 `docs*` commits).
- No `src/` delta vs `origin/main` on tip — TMB template unchanged for this tip's Arc-1 surface.

### WHAT SHINICHI TOLD US

- **B done** → proceed to **C** as **plan** (arc + new-lane recommendation).
- **Do NOT** merge, open PR, or flip fence yet — STOP at G0.

### DECISIONS LOCKED (planning assumptions — amend at G0)

1. Merge vehicle = **new lane from `origin/main`**, not a fat-tip PR.
2. Prefer **split**: code/fence PR first; docs-evidence optional/second.
3. Ship Arc-1 product as already closed: 18-cell fence, H=7, `auto→gh`, JJ explicit logit-only, multinomial out.
4. **Keep** `calibrated=FALSE` and **Laplace** package default; series synthesis is NEWS/scope text, not a promotion.
5. Leave PoisG cloglog closed-form (`b53be434`) **out** of first code PR unless G0 adds it (auto already GH; Σ collapse documented).
6. Dirty/untracked probes and `lanes/*/results` stay **local / out of PR**.

### QUESTIONS STILL OPEN (G0 — max 3)

**QUESTION 1** · Approve C programme: new lane from `main` + code/fence PR prep (no merge yet)?  
**QUESTION 2** · Docs-evidence: (a) separate PR later, (b) include thin NEWS/register cite only in code PR, or (c) park docs on fat branch? **Recommend (b)+(a deferred).**  
**QUESTION 3** · After code PR green: stop for merge G0, or merge-on-green? **Recommend stop for merge G0.**

---

## Recommended new lane

| Item | Recommendation |
| --- | --- |
| **Branch name** | `cursor/va-arc1-merge-fence-20260807` |
| **Base** | **`origin/main`** (fresh). **Do not** branch from `codex/va-gh-all-families` tip as the PR head. |
| **Import method** | **Path-scoped transplant** from evidence tip `98839853` (or pinned Arc-1 closeout `537e6da4` + later honesty fixes), **not** blind cherry-pick of 119+ commits. Arc 0 freezes the file list. |
| **Worktree path** | `/private/tmp/gllvmtmb-va-arc1-merge-fence` |
| **Owner / platform** | Cursor (this programme) unless Shinichi reassigns; high-risk R/API → ask before merge |
| **Tracking** | push `-u` only after G0 + local green; PR against `main` |

### What to leave on `codex/va-gh-all-families`

| Keep on fat evidence lane | Why |
| --- | --- |
| Totoro / ladder results under `lanes/*/results/`, `/private/tmp/va-*` | D-50; not GitHub artifacts; bloat |
| Series audits, plan-actuals, LOOP kits, handovers (unless docs PR) | Evidence archive; optional later docs PR |
| Untracked probes (`dev/va-gh-h7-campaign/probe-*.R`, JJ match scripts) | Dirty research; not ship surface |
| Campaign / DRAC / heartbeat scaffolding commits | Not needed for Arc-1 product |
| PoisG cloglog feat + Σ-collapse audits | Separate opt-in story; do not couple to Arc-1 merge |
| Tip as **read-only donor** | File source for transplant; do not force-push or delete |

### Suggested code-PR file families (Arc 0 must confirm)

- **Routing / fence:** `R/integration-fence.R`, `R/va-routing.R`, `R/approximation-engine.R`, `R/fit-multi.R`, `R/gllvmTMB.R` (control defaults + roxygen)
- **Honesty / methods:** `R/output-methods.R`, `R/va-methods.R` as required by closeout; man pages for `gllvmTMBcontrol`, `gllvmTMB_va-methods`, `getLV`
- **Tests:** `tests/testthat/test-integration-fence.R`, `test-va-routing-oracle.R`, `test-va-all-family-*`, `test-va-control-exposure.R`, related oracle/light/compiled
- **Docs surface (thin):** `NEWS.md` Arc-1 paragraph with series/Arc-2 honesty; register rows VA-* as already in closeout; **no** bulk `docs/dev-log/audits` dump in code PR
- **Out of code PR:** `lanes/`, most `docs/dev-log/audits/2026-08-07-va-*` n-ladders, `dev/va-*` campaign trees, unretracted MEASURE/ledger noise

### Why not cherry-pick the tip onto main

`origin/main..ead23293` is **~117 commits**, including VA lane-2 speed/SE/interval research interleaved with docs. Cherry-pick conflicts and review noise are expected. Path transplant (or one curated squash of the Arc-1 surface) is the honest merge vehicle.

---

## Risk / kill rules

1. **No fat-tip PR** — if someone opens PR from `codex/va-gh-all-families` → close/repoint.
2. **No `calibrated=TRUE`** without separate promotion G0 + coverage evidence.
3. **No soft-PASS** of Arc-2 FAIL/INCONCLUSIVE cells in NEWS/README/articles.
4. **No fence narrowing/widening** beyond Arc-1's 18-cell table without explicit G0 (series does not revoke Gate E admission).
5. If focused tests fail after transplant → repair in new lane only; do not "fix forward" on the fat tip for merge.

---

## G0 decision (locked)

**Approved** — scaffold `/private/tmp/gllvmtmb-va-arc1-merge-fence` · `cursor/va-arc1-merge-fence-20260807` from `origin/main`; Arc 0 inventory; path transplant; focused tests; open code PR; **stop before merge**. Docs = thin NEWS in code PR; fat-branch series audits deferred. PoisG out of first PR. Merge-on-green **not** authorised.

**Handover for fresh Cursor:** `docs/dev-log/handover/2026-08-07-cursor-handover-va-arc1-merge-fence.md`
