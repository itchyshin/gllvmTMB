# Arc Card — gllvmTMB CRAN Path A (cleanup → freeze → submit-ready)

**Date:** 2026-08-07  
**Author:** Cursor (Arc Creation / planning only)  
**Package truth:** `origin/main` @ `5bf18ab3` (Version `0.6.0` in DESCRIPTION)  
**Worktree:** `/private/tmp/gllvmtmb-va-arc1-merge-fence` (writable; VA-merge lane — orthogonal)  
**Status:** **PLANNING ONLY.** No DESCRIPTION bump, no freeze, no tag, no CRAN upload in this slice.  
**Orthogonal:** PR [#949](https://github.com/itchyshin/gllvmTMB/pull/949) (VA Arc-1) is OPEN — do **not** block this Arc Card on it; do **not** merge VA work into the CRAN candidate without a separate merge G0.

---

## Orient receipt (evidence used)

| Surface | Finding |
| --- | --- |
| Vault D-49 | Exact-artifact CRAN gate + runged status mandatory; default **NOT READY** |
| Vault D-66 | First CRAN number historically **`0.6.0`** (supersedes D-42's `0.5.0` *number* only) |
| Vault D-89 | **CRAN FAR AWAY by choice** (2026-07-26) — no clock; still live until amended |
| Vault D-112 | 0.6 ships **recovery-only** intervals; post-0.6 = capabilities not coverage chase |
| 2026-08-02 chat / handover | Shinichi: *"do not worry about CRAN submission — I am not intending to do so"* — CRAN-shaped work descoped that day |
| 2026-08-07 chat | Comfortable sending to CRAN **after cleanup**, with **Laplace defaults figured out**; agents offered Path A; he said *"cool - let's plan new arc"* → **plan** Path A; **G0 mechanism lock still required** for submit/upload |
| `origin/main` DESCRIPTION | `Version: 0.6.0`; lifecycle **experimental** |
| Git tags | `v0.6.0` / `v0.6.0-rc.2` @ `c0af58d3` (2026-07-23); GitHub-only release; CRAN **withheld** |
| Distance | **~618 commits** `v0.6.0..origin/main`; large `R/` + `src/` delta — prior exact-tag receipts are **predecessor evidence only** (M4→M5 trap) |
| `cran-comments.md` on main | Draft for 0.6.0; 0E/0W/1N New submission; explicitly says submission withheld; SHA `c0af58d3` — **stale vs current main** |
| PR #908 | **MERGED** 2026-08-02 (`lanes/` → `.Rbuildignore`); clears prior actionable as-cran NOTE at that SHA — does **not** certify current main |
| NEWS | Laplace is the fitted engine story; VA/AGHQ remain opt-in / fenced; "Laplace remains the package default" |
| Runbook | `docs/dev-log/2026-07-22-m4-to-m5-runbook.md` — freeze → RC tag → exact-tag checks → final tag → tarball → **Shinichi submits** |
| PR #949 | OPEN; VA Arc-1 merge fence — orthogonal lane |
| Issue #345 | Still OPEN ("CRAN readiness + paper") |

---

## ARC CARD — gllvmTMB CRAN Path A

**Mode:** size  
**Requested outcome:** Path A programme planned: reverse CRAN-off policy → cleanup → candidate freeze → D-49 ceremony → **submit-ready** (or submitted). Not quantified as cell counts. **Not** the D-113 / 0.7 capability programme.  
**Mechanism authority (this Arc Creation slice):** planning artefacts only — this Arc Card; G0 question set; handoff line to Ultra Plan.  
**Explicit exclusions (until G0 + later per-rung approvals):** DESCRIPTION/NEWS version bumps; candidate freeze; RC/final tags; `R CMD check` campaigns treated as release evidence; win-builder/macbuilder as submission evidence; tarball upload to CRAN; vault D-89 amendment written as accepted; merging #949 into the CRAN candidate.  
**Mechanism authority (post-G0, if Path A locked):** cleanup edits on a dedicated release lane; honesty/reader fences; freeze; exact-tag D-49 ladder; rewrite `cran-comments.md` at the frozen identity. **CRAN upload remains Shinichi-only** (D-49 / runbook M5-g) even after submit-ready.  
**Recommended arc:** **~8–12 hours** agent capacity programme to **submit-ready** after G0 (range); wall-clock longer for 3-OS / win-builder waits. Shinichi page-by-page reader hours are **external**, not in the agent budget.  
**Time contract:** ceiling ~1–2 focused sessions post-G0 for cleanup+freeze+ceremony prep; outcome-first for the freeze identity; **no time box on CRAN acceptance**.  
**Estimate confidence:** **inferred** — M1/M4/M5 analogues and runbook exist; current main forfeited the July exact-tag chain; cleanup surface size unknown until inventory; G0 version choice changes the bump slice.  
**Arc 0 outcome:** G0 locked in chat (Path A policy reverse + CRAN version number + Laplace-default freeze) **or** explicit reject/park; decision recorded for Ultra Plan.  
**State transition:**  
- **Current:** not on CRAN; policy **ambiguous** (D-89 FAR AWAY + 2026-08-02 off vs 2026-08-07 Path A planning intent). Highest historical rung for a *different* SHA: GitHub `v0.6.0` non-CRAN; D-49 for *current* main ≈ **below source-clean for submission** (no frozen candidate at tip).  
- **Intended:** Path A active → cleanup complete → **candidate freeze** → exact-tag platform evidence → **submission-ready** (upload still gated) → optionally **submitted**.  
**Executable rung and evidence:** **blocked on G0** for policy reverse + version. After G0: intervention = release-lane cleanup + freeze + exact-tag `--as-cran` / 3-OS / heavy + refreshed `cran-comments.md` + D-49 ledger; retained evidence = one immutable tarball (commit + SHA-256 + size + inventory) with rung named. **Upload blocked until separate explicit submit approval.**

### Capacity ladder (post-G0 — do not start until G0)

| Order | Budget | Outcome | Trigger / definition of done |
| --- | ---: | --- | --- |
| Arc 0 | 15–30 m | G0 lock (or park) | **Start now (questions).** Done when Path A / version / Laplace-default answers are explicit in chat (+ vault amend D-89 when he says lock). |
| Rung 1 | 90–150 m | Cleanup inventory + release lane | After G0. Done when: dedicated branch/worktree from `origin/main`; checklist of honesty/DESCRIPTION/URL/NEWS/claim fences vs D-112; VA/#949 kept out unless merge G0; no version bump yet unless G0 chose bump-now. |
| Rung 2 | 120–180 m | Cleanup implementation | After inventory. Done when: approved fences landed; `document()` + `check_pkgdown()`; focused tests for touched surfaces; Rose claim-string scan clean on touched reader surfaces. |
| Rung 3 | 60–90 m | Candidate freeze packet | After cleanup. Done when: Shinichi **🛑 freeze**; SHA frozen; no further source edits; identity matches chosen `0.6.0` vs `0.6.1`. |
| Rung 4 | 120–180 m agent + CI wait | Exact-tag ceremony (D-49 / M5-a..e) | After freeze. Done when: RC (if used) + final tag at frozen SHA; 3-OS + heavy + local `--as-cran` at **exact tag**; win-builder/macbuilder budgeted; rung named (never unqualified "ready"). |
| Rung 5 | 45–75 m | Submit-ready artefact | After green exact-tag evidence. Done when: tarball built; `cran-comments.md` rewritten for **this** identity; D-49 ledger filled; upload checklist for Shinichi — **no upload**. |
| Integrate/close | 30–45 m | After-task + plan-vs-actual + vault | Always for completed rungs. |
| **Total capacity** | **~8–12 h** agent | submit-ready (not accepted) | |

### Budget (this planning slice only)

| Segment | Minutes | Output / stop point |
| --- | ---: | --- |
| Orient | 25 | Skill + runbook + D-49/66/89/112 + main Version/tags/cran-comments + #908/#949 |
| Core | 35 | This Arc Card + Path A sizing + G0 menu |
| Verify | 5 | Paths/SHAs resolve; planning-only (no bump/upload) |
| Repair reserve | 5 | Amend if tip/`gh` facts drift |
| Closeout | 5 | File path + HAND TO ULTRA PLAN + G0 asks in chat |
| **Total** | **~75** | |

**In scope:** Path A Arc Card; shortest credible cleanup→freeze→submit-ready programme; G0 locks; Ada recommendation on version.  
**Not in this arc:** D-113 / 0.7 capabilities (EVA, Ayumi missing-data programme, AGHQ advertising, SEPARABLE, full slope-per-family); coverage re-measure (D-112); flipping default engine Laplace→AGHQ/VA; merging #949; CRAN upload; rewriting vault D-89 as accepted without G0; paper/capstone campaigns.  
**Evidence used:** vault DECISIONS D-49/D-66/D-89/D-112; `2026-07-22-m4-to-m5-runbook.md`; `origin/main` DESCRIPTION + `cran-comments.md`; tags `v0.6.0*`; PR #908 merged / #949 open; NEWS Laplace-default language; ~618-commit forfeiture of July exact-tag chain.  
**Risk branch:** If G0 chooses **keep D-89 / no CRAN**, stop after Arc 0; return unused capacity; do not invent cleanup theatre. If cleanup inventory finds a **default-engine or public-claim contradiction** (e.g. reader surfaces imply AGHQ/VA default), **stop freeze**, return a claim ledger + one-line fix list — do not tag. If exact-tag `--as-cran` grows actionable NOTE/WARN after freeze, **do not patch inside M5** — return to cleanup lane and re-freeze (runbook trap).

**Done when (this planning slice):** this file exists; chat returns Arc Card summary + ≤3 G0 questions + Ada pick; no release mutation.  
**Done when (post-G0 Path A):** frozen identity has D-49 evidence through **submission-ready**; `cran-comments.md` matches that tarball; Shinichi holds upload button.  
**First action:** ask the G0 trio below; **do not** open a release branch until answers land.

### Actuals (complete at close of planning slice)

**Recommended / actual:** ~75 / ~75 · **Requested / used:** plan-only / plan-only  
**Rungs/cohorts completed:** planning Arc Card only  
**Under-run event:** none  
**Calibration:** n/a until post-G0 execute  
**Metric movement:** none — preparation only (policy still ambiguous until G0)  
**Result:** blocked on G0 · **Next arc:** Ultra Plan for Rungs 1–5 **iff** G0 locks Path A; else park

---

## Ada recommendation (pre-G0, non-binding)

1. **Policy:** Lock Path A = **amend D-89 for gllvmTMB** (CRAN on the table after cleanup), without inventing a calendar clock. Keep D-49 fail-closed. Keep D-112 (recovery-only; no coverage campaign as blocker).  
2. **Version:** Prefer **`0.6.1`** as the first *CRAN* upload identity if the candidate is current `main` (or a cleanup branch tip). Rationale: `v0.6.0` @ `c0af58d3` already names a different GitHub-only artefact; ~618 commits forfeit that exact-tag chain; shipping a new tree as CRAN `0.6.0` muddies evidence lineage even though CRAN has never seen the package. Path A's "`0.6.x`" wording allows this; D-66's "`0.6.0`" number can be amended or read as the 0.6 series. Choose **`0.6.0`** only if Shinichi explicitly wants the CRAN first version string to match the historical D-66 label *and* accepts re-ceremony under that number.  
3. **Laplace:** Freeze **defaults unchanged** — Laplace remains the package default; AGHQ/VA stay opt-in and fenced; no engine flip inside the CRAN arc. "Figured out" = document that decision in the freeze packet / NEWS scope boundary, not re-open Design 108 stages.  
4. **VA #949:** Keep orthogonal; CRAN candidate must not absorb unmerged VA fence work unless a separate merge G0 says so.  
5. **Shortest credible arc:** cleanup inventory → honesty fences → freeze → exact-tag D-49 → submit-ready (~8–12 h agent). **Not** D-113.

---

## G0 questions (max 3) — stop here

Copy-ready for chat:

1. **Policy lock — Path A?** Confirm: amend D-89 for gllvmTMB — CRAN submission is back on the table after cleanup + freeze + D-49 evidence; still **no clock**; upload remains your act. (Yes Path A / No keep CRAN-off / Park.)  
2. **CRAN version string?** `0.6.1` (Ada default for current-main candidate) vs `0.6.0` (D-66 literal; re-ceremony under same number).  
3. **Laplace defaults for the freeze?** Confirm: leave Laplace as default; AGHQ/VA remain opt-in/fenced; no default-engine change in this arc. (Yes freeze defaults / No — specify flip.)

---

**HAND TO ULTRA PLAN:** Path A post-G0 = dedicated release lane from `origin/main`; cleanup inventory + honesty fences (D-112 recovery-only); candidate freeze; exact-tag D-49 ceremony; refresh `cran-comments.md`; stop at **submission-ready**. Duration **~8–12 h** agent (+ CI waits). Version per G0 (`0.6.1` recommended). **No CRAN upload** without separate explicit Shinichi submit approval. **Out:** D-113/0.7, coverage re-measure, Laplace→VA/AGHQ default flip, blocking on PR #949.

---

## G0 LOCKED (2026-08-07) — stamped after Ultra-Plan Phase 0.4

Shinichi locked Path A in chat. Ultra-plan artifact:
`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-ultra-plan.md`.

### DECISIONS LOCKED

| Lock | Value |
| --- | --- |
| Path A | **ON** — amend D-89 for gllvmTMB; CRAN after cleanup/freeze/D-49; **no clock** |
| Version | **`0.6.1`** (first CRAN upload identity) |
| Laplace defaults | **Unchanged** — AGHQ/VA stay opt-in/fenced |
| Upload | **Shinichi only** (agents stop at submission-ready) |
| VA #949 | Orthogonal — do not couple into CRAN freeze |
| D-112 / D-113 | D-112 holds; D-113 out of this arc |

### Durable vault follow-on

Amend `~/shinichi-brain/memory/DECISIONS.md` **D-89** (gllvmTMB Path A exception; drmTMB remains FAR AWAY unless separate G0) + clarifying note under **D-66** that the first *CRAN upload* string is `0.6.1` while GitHub-only `v0.6.0` @ `c0af58d3` remains historical. **Not yet written** at Arc Card stamp time — first post-`/goal` / plan S0 action.

### State transition (updated)

- **Current:** G0 closed; Path A active for planning→execution handoff; vault D-89 still unamended until S0.
- **Next:** `/goal` on fresh CRAN lane `cursor/cran-path-a-0.6.1-20260807` from `origin/main`.
