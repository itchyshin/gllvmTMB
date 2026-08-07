# Ultra Plan — gllvmTMB CRAN Path A → submit-ready `0.6.1`

**Date:** 2026-08-07  
**Author:** Cursor (Ultra-Plan Phases 0–2 only; **no Phase 3 in this chat**)  
**Platform (this session):** Cursor  
**Status:** G0 **LOCKED** in chat 2026-08-07. Plan approved for `/goal` execution.  
**Plan mode note:** client Plan mode was **not** toggled; Phases 0–2 stayed read-only except this plan file (+ optional Arc Card G0 stamp).

---

```
🎯 GOAL
Solo platform: Cursor
Deliverable: gllvmTMB submit-ready at frozen identity Version 0.6.1 — exact-tag D-49 evidence,
  refreshed cran-comments.md, upload checklist for Shinichi; no CRAN upload by agents
HEADLINE: Amend D-89 for gllvmTMB + cleanup/honesty fence + freeze + exact-tag ceremony → submission-ready
IN PARALLEL: cleanup inventory (RECON); claim-string scout; vault D-89 amendment draft; #949 status watch (read-only)
DEFER: CRAN upload (Shinichi-only); D-113 / 0.7 capabilities; coverage re-measure (D-112);
  Laplace→AGHQ/VA default flip; merging PR #949 into CRAN candidate; paper/capstone campaigns
DISCIPLINE: verify=exact-tag --as-cran + 3-OS + heavy at frozen SHA (D-49; never inherit July v0.6.0 receipts)
  · compute=local + GHA for checks (no Totoro/DRAC campaign) · closure=submission-ready rung named + Shinichi holds upload
```

**ARC PROGRAM:** Arc Card `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-arc.md` — mode size · ~8–12 h agent to submit-ready · Arc 0 (G0) **closed 2026-08-07**.

---

## Phase 0.25 — Sweep receipt (gate for Phase 1)

| Surface | Evidence ran | Finding | Call |
| --- | --- | --- | --- |
| **repo git** | `git status -sb`; `git log --oneline -20`; `git worktree list`; `bash ~/shinichi-brain/tools/branch_drift_check.sh` | Worktree `/private/tmp/gllvmtmb-va-arc1-merge-fence` on `cursor/va-arc1-merge-fence-20260807` = **2 ahead / 0 behind** `origin/main` @ `5bf18ab3`; HEAD `67f38910` (VA Arc-1); untracked Arc Card only. `DESCRIPTION` still `Version: 0.6.0`. Tags: `v0.6.0` / `v0.6.0-rc.2` @ `c0af58d3` (~620 commits behind tip). `cran-comments.md` stale for `c0af58d3` / 0.6.0 withheld. | **Do not resume VA branch for CRAN.** Fresh lane `cursor/cran-path-a-0.6.1-20260807` from `origin/main`. |
| **sister** | drmTMB `DESCRIPTION` `Version: 0.6.0.9000`; D-86/D-89/D-125 skim | drmTMB CRAN still far / first CRAN target **0.7.0** (D-86); not a twin engine to co-opt. Sister note only: same D-49 gate + Shinichi-only upload habit. | **n/a co-opt** — reuse process (runbook + D-49), not drmTMB code. |
| **brain** | MCP `search_notes` q=`gllvmTMB CRAN Path A D-89 0.6.1` `search_all_projects:true`; greps: `grep -in 'CRAN\\|D-89\\|0\\.6\\.1' memory/DECISIONS.md`; `AGENT_LOG.md` CRAN/D-89; `OPEN_QUESTIONS.md`; `journal/` | **D-49** live (exact-artifact, NOT READY default). **D-66** first CRAN number historically `0.6.0`. **D-89** still **FAR AWAY** for drmTMB **and** gllvmTMB — **not yet amended in vault**. **D-112** recovery-only; no coverage chase. No prior Path A ultra-plan. Arc Card on disk (this worktree). | **Reuse** M4→M5 runbook + Arc Card capacity ladder; **build-the-gap** = Path A execute + vault D-89 amend + `0.6.1` identity. |
| **external prior art** | — | No novelty claim ("first GLLVM on CRAN" etc.). | **SKIP** NotebookLM (not load-bearing). |
| **Verdict** | — | Genuinely new: policy reverse (D-89 amend for gllvmTMB), cleanup→freeze→D-49 at **current tip**, version **`0.6.1`**, submit-ready stop. Reuse July ceremony mechanics; **do not** reuse July exact-tag receipts (~618–620 commits forfeit). | **reuse runbook / build Path A gap** |

**#949 (orthogonal):** `gh pr view 949` → **OPEN**, MERGEABLE, title Arc-1 scalar VA fence — **do not couple** into CRAN lane; freeze SHA must exclude unmerged VA tip unless separate merge G0.

**Phase 0.3 / 0.3b — model roster + two-bar:** Live Usage UI **not readable** this session → Bar column = **AGENT-INFERRED** from `MODEL-ROUTING.md` Cursor two-bar doctrine (Composer/Grok vs Other Models ≥$400; on-demand off). Scout/recon → Cursor Models; claim/judgment/prose → Other Models (Auto Cost / Claude); live `R CMD check` / win-builder → **hand off Codex** when heavy.

---

## WHAT THE BRAIN ALREADY KNOWS

- D-49: fail-closed exact-artifact CRAN gate; runged status mandatory; upload ≠ acceptance.
- D-66: series decision — first CRAN *was* labelled `0.6.0`; GitHub-only `v0.6.0` @ `c0af58d3` already used that string outside CRAN.
- D-89: CRAN FAR AWAY by choice for **both** drmTMB and gllvmTMB (2026-07-26) — **still live in vault** until amended.
- D-112: 0.6 ships recovery-only intervals; no coverage re-measure as blocker; no unearned AGHQ/VA advertising.
- M4→M5 runbook: freeze → RC → exact-tag checks → final tag → tarball → **Shinichi submits**; any source edit after freeze voids receipts.
- 2026-08-02: CRAN descoped that day; 2026-08-07 Path A reopened via Arc Card + this ultra-plan.

## WHAT SHINICHI TOLD US (G0 LOCKED 2026-08-07)

1. **Path A ON** — amend D-89 for gllvmTMB; CRAN after cleanup / freeze / D-49; **no clock**; **upload still Shinichi only**.
2. **Version `0.6.1`** LOCKED (Ada default accepted).
3. **Laplace defaults unchanged** — AGHQ/VA stay opt-in/fenced for this arc.

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Rose   — July cran-comments + v0.6.0 receipts must not be cited as current-main evidence ·
           claim fence must keep recovery-only / experimental · recommendation: rewrite cran-comments
           only at frozen 0.6.1 identity · default if "use judgment": treat all pre-freeze checks as smoke
  Fisher — D-66 said first CRAN = 0.6.0; shipping 0.6.1 is coherent if framed as first *upload*
           identity after GitHub-only 0.6.0 · recommendation: vault note under D-66 or D-89 amend
           that CRAN upload number is 0.6.1 · default: amend D-89 + add D-66 follow-on sentence
  Grace  — exact-tag 3-OS + heavy + local --as-cran; win-builder/macbuilder before upload ·
           #908 merged does not certify tip · recommendation: re-ceremony from freeze SHA ·
           default: follow M5-a..f literally
  Ada    — fresh CRAN lane from origin/main; VA #949 orthogonal; stop at submission-ready
```

## ADA'S RECOMMENDATION

Execute Path A on a **dedicated worktree/branch from `origin/main`**, not the VA merge-fence tree. First durable act: **write D-89 amendment** (gllvmTMB Path A; drmTMB remains FAR AWAY unless separately decided). Bump to **0.6.1** only on the release lane after cleanup inventory (or as the freeze packet's version slice — never on VA tip). Keep Laplace default language explicit in NEWS scope boundary. Hand heavy check campaigns to Codex if Cursor bar pressure rises.

## DECISIONS LOCKED

| ID | Lock |
| --- | --- |
| Path A | ON — cleanup → freeze → D-49 → submit-ready |
| D-89 | **To amend** (gllvmTMB exception / Path A); drmTMB unchanged FAR AWAY unless separate G0 |
| Version | **`0.6.1`** first CRAN upload identity |
| Engine defaults | Laplace remains default; AGHQ/VA opt-in/fenced |
| Upload | Shinichi only (M5-g); agents stop at submission-ready |
| VA #949 | Orthogonal; not in freeze SHA |
| D-112 | Holds — recovery-only; no coverage campaign |
| D-113 / 0.7 | Out of this arc |

## QUESTIONS STILL OPEN

*(none load-bearing — G0 closed.)*

Optional non-blocking: whether vault amendment is filed as **D-89 amend** alone or **D-89 + one-line D-66 clarifying note** that the first *CRAN upload* string is `0.6.1` while the GitHub-only `0.6.0` tag remains historical. Ada default: **D-89 amend + clarifying sentence under D-66** in the same vault slice (S0).

---

## SLICE TABLE

| ID | Slice | Member | Model+effort | Dispatch | Bar | Time | Detail / files | Dep |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **S0** | Vault: amend D-89 (+ D-66 clarifying note for 0.6.1 upload identity) | Ada / Ebbinghaus | Claude Opus or Other Models Auto · med | hand off / native | **Other Models** | 20–30 m | `~/shinichi-brain/memory/DECISIONS.md`; AGENT_LOG one line; **do not invent as done until written** | — |
| **S1** | **RECON** — cleanup inventory from `origin/main` | Scout | Composer/Grok · low **or** Luna tiered-cli | Cursor Agent / tiered-cli | **Cursor Models** | 45–75 m | Inventory: DESCRIPTION/URL/lifecycle; NEWS Laplace/VA/AGHQ claims; README/pkgdown honesty; `cran-comments.md` stale bits; claim strings vs D-112; list files needing fence; confirm #949 not merged; record freeze-base SHA | S0 optional parallel |
| **S2** | Honesty / reader fences (D-112) | Builder + Rose skim | Composer · med | Cursor Agent | **Cursor Models** | 90–150 m | Touched reader surfaces only; no engine flip; `document()` if roxygen touched | S1 |
| **S3** | Version bump → **0.6.1** | Builder | Composer · med | Cursor Agent | **Cursor Models** | 30–45 m | `DESCRIPTION`, `NEWS.md` (0.6.1 section + Laplace-default scope boundary); cascade only where Version string is reader-facing | S1 (after inventory); may land with S2 |
| **S4** | `cran-comments.md` draft skeleton for 0.6.1 | Grace/Builder | Auto Cost · low–med | Cursor / Claude | **Other Models** | 30–45 m | Rewrite identity to 0.6.1; mark platform rows **TBD until exact-tag**; keep Shinichi-upload sentence; `.Rbuildignore`d | S3 |
| **S5** | pkgdown prep | Builder | Composer · med | Cursor Agent | **Cursor Models** | 45–60 m | `pkgdown::check_pkgdown()`; fix broken refs from fence/bump; no broad article rewrite | S2–S3 |
| **S6** | Candidate freeze packet | Ada | Other Models / Claude · med | hand off | **Other Models** | 30–45 m | 🛑 Shinichi freeze; SHA; Version 0.6.1; no further source edits; identity checklist | S2–S5 |
| **S7** | Exact-tag D-49 ceremony (M5-a..e) | Grace + Codex toolchain | Terra/Sol · high for checks | **hand off Codex** | hand off | 120–180 m + CI wait | RC tag on approval; 3-OS + heavy + local `--as-cran` **at tag**; win-builder/macbuilder budgeted; rung named | S6 🛑 |
| **S8** | Submit-ready artefact (M5-f) | Grace | Terra · med | Codex/Cursor | hand off / Cursor | 45–75 m | Tarball; finalize `cran-comments.md` from **exact-tag** receipts; D-49 ledger; upload checklist — **no upload** | S7 |
| **S9** | **MECHANICAL-VERIFY** | Scout | Luna/Composer · low | tiered-cli / Cursor | **Cursor Models** | 30–45 m | Version=0.6.1 everywhere intended; VA fat tip not in freeze; cran-comments SHA matches tag; tarball inventory; no upload artifacts claimed | S8 |
| **S10** | Rose claim-fence closeout | Rose | Other Models / Claude · high | hand off | **Other Models** | 45–60 m | Reader surfaces: recovery-only; experimental; Laplace default; no AGHQ/VA advertise; no "CRAN ready" without rung | S8–S9 |
| **S11** | **RECONCILE** (Melissa) | Melissa | Sonnet/Terra · med | hand off | **Other Models** | 30–45 m | plan-vs-actual → `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-actuals.md`; drift to Rose | S9–S10 |
| **S12** | After-task + check-log | Rose/Ada | Auto · low–med | Cursor | **Other Models** | 20–30 m | `docs/dev-log/after-task/YYYY-MM-DD-gllvmtmb-cran-path-a.md`; check-log entry | S11 |

**LUNA SUITABILITY:** **yes** — S1 RECON + S9 MECHANICAL-VERIFY are bounded read-only/mechanical; on Codex use `--require-scout`; on Cursor route those rows to **Cursor Models** (Composer/Grok).

**SEARCH:** none (tier-b NotebookLM offered? **n** — process arc, not novelty).

**SLICES deps:** PARALLEL `{S0, S1}` early; then `S2∥S3` after S1; `S4←S3`; `S5←S2,S3`; `S6←S2–S5` + 🛑; `S7←S6`; `S8←S7`; `{S9,S10}←S8`; `S11←S9,S10`; `S12←S11`.

---

## FAN-OUT

- **Batches:** (B0) S0 vault ∥ S1 RECON → (B1) S2 fences + S3 bump → (B2) S4 cran-comments + S5 pkgdown → **STOP freeze G0** → (B3) S7 ceremony (Codex) → (B4) S8 submit-ready → (B5) S9 mechanical ∥ S10 Rose → (B6) S11 Melissa + S12 closeout.
- **FAN-OUT BUDGET:** checkpoint=`cran-path-a-0.6.1` · new children ≤6 per checkpoint · scout=1 (S1) · build=2–4 · ceiling=0–1 (Rose S10 only if claim gate load-bearing) · reuse producers for repair.
- **ULTRA EFFORT:** no.
- **CONTEXT BRAKE:** parent unknown · `/goal` fresh chat after this plan.
- **COMPACTIONS:** parent=0 · boundary=open → **LANE: START A FRESH TASK** for execution.
- **D-43 PANEL:** milestone=`submission-ready-0.6.1` · fire **once** after S8 candidate exists · composition 2 build + 1 ceiling (Codex) if claiming the rung publicly in-repo; else Rose S10 may substitute for a lighter close — Ada default: **fire D-43 once** before calling the package submission-ready in any reader-facing sentence.

**LANE RECEIPT:** **START A FRESH TASK** — Phases 0–2 complete; execution belongs in `/goal`, not this planning chat.

---

## ESTIMATE

| Item | Value |
| --- | ---: |
| Wall-clock agent | **~8–12 h** to submit-ready (matches Arc Card) |
| + CI / builder waits | +hours–days (not agent-burn) |
| Sub-agents / batches | ~6 batches; 1–4 children per batch |
| Fits one Cursor planning session? | **No** — this chat stops; `/goal` runs arcs |
| ARC ACTUALS | fill at close beside Arc Card |

---

## REVIEW (plan critique — before execute)

**Rose (plan):** Sweep receipt cites commands ✓; DEFER fence includes upload + D-113 + #949 ✓; risk = bumping DESCRIPTION before freeze inventory or citing July receipts — both fenced in S1/S7.  
**Grace (plan):** Ceremony must be exact-tag; S4 must not pretend TBD rows are evidence.  
**Verdict:** Plan may proceed to `/goal` under locked G0.

---

## VERIFY

1. Mechanical (S9): Version `0.6.1`; freeze SHA ≠ VA tip; `cran-comments` identity match; tarball SHA-256 logged; rung named.
2. Judgment (S10 Rose): no overclaim; D-112 language; Laplace default explicit.
3. D-49 ledger: highest proven rung + next unproven; default NOT READY until S8 complete.
4. Negative: agents must **not** have uploaded to CRAN.

## CONSOLIDATE

- Submit-ready packet (tarball path + SHA-256 + `cran-comments.md` + D-49 ledger + upload checklist).
- Vault D-89 (and D-66 note) amended.
- After-task + plan-actuals + check-log.
- Optional: issue #345 status note (still open until accepted — do not auto-close).

## RECONCILE

Melissa (Sonnet/Terra, med) — required. Compare this plan + Arc Card budget to actual → `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-actuals.md` → drift/unclear to Rose → monthly [[PLAN-DRIFT-LEDGER]].

---

## Do-not-redo fence (for `/goal`)

- No D-113 / 0.7 capability work.
- No VA fat-tip merge (#949) into CRAN candidate.
- No CRAN upload / win-builder "submit" by agents.
- No DESCRIPTION bump on the VA worktree; no treating July `v0.6.0` receipts as tip evidence.
- No Laplace→AGHQ/VA default flip.
- No coverage re-measure (D-112).

---

## Branch / worktree recommendation

```
Branch:   cursor/cran-path-a-0.6.1-20260807
Base:     origin/main (@ 5bf18ab3 or newer tip at start)
Worktree: NEW (e.g. /private/tmp/gllvmtmb-cran-path-a-0.6.1) — NOT the VA merge-fence tree
First durable mutate: S0 vault D-89 amend (brain) and/or S1 inventory commit on the CRAN branch
```

---

*End of Phases 0–2. Do not start Phase 3 in the planning chat — paste `/goal` below.*
