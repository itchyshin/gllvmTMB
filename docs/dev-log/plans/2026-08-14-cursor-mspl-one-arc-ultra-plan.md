# Ultra Plan — Cursor MSPL Arc 1A (internal provenance parity)

**Status:** Phase 2 written 2026-08-14 · **G0 APPROVED 2026-08-14** (Shinichi: approve · stacked Cursor branch + new PR · do not wait on #961). Execute via `/goal` in a **fresh** chat. Do not start Phase 3 in the planning thread.

**Lane claimed:** Cursor MSPL estimator-programme lane  
**Worktree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`  
**Branch now:** `codex/mspl-estimator-programme-roadmap` @ `829a6832` (2 ahead / 0 behind `origin/main` `882a6acb`)  
**Programme PR:** [#961](https://github.com/itchyshin/gllvmTMB/pull/961) OPEN draft, MERGEABLE, docs-only  
**Authoritative programme:** `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`  
**Handover:** `docs/dev-log/handover/2026-08-14-cursor-handover.md`

This file is the Cursor-platform plan for **one** hours-scale arc. It does not replace the programme document. After G0, execution is `/goal` + LOOP/, not Phase 3 in the planning chat.

---

```text
🎯 GOAL
Solo platform: Cursor (this session; PLATFORM read from session_ownership.sh — not inferred from the leftover codex/ branch name)
Deliverable: internal estimator provenance on every current admitted route, with exact numerical and accepted-call parity, plus targeted tests and an after-task closeout
HEADLINE: separate integration, outer criterion, numerical kernel, and penalty-eval internally without changing any result or accepted call
IN PARALLEL: recon of current estimator_id 0/1/2 call sites; compatibility-table draft; parity-fixture inventory from test-mspl-api.R
DEFER: Arc 1B public policy; Arc 2 Bernoulli registry/B2; Arc 3 Gaussian Heywood; Arcs 4–8; inference/intervals; Design 117; Codex iSDM / G3P / #872 / #855 / AA-03; LOOP/ until G0
DISCIPLINE: verify=objective/gradient/report/warning/error/routing parity + Rose/Gauss/Noether PASS · compute=local targeted tests only (no campaign; no Totoro/DRAC) · closure=parity receipt + after-task + stacked Cursor PR, then handback before Arc 2
```

**ARC PROGRAM:** N/A — no Arc Card from `/arc-creation`. This ultra-plan *is* the decomposition of handover Arc 1A.

**PREFLIGHT (Phase 0.2):** `~/shinichi-brain/tools/lane_preflight.sh` on the Dropbox checkout → **FOREIGN LANE ACTIVE (codex + claude)** · ~15 live lanes · duplicate design slots (59, 2, 3; next free 118).  
**LANE TAKEN:** Cursor MSPL estimator-programme lane (handover + PR #961 + this worktree).  
**NOT TAKEN:** `claude/design-117-separation-programme` (dirty `docs/design/117-…`); `codex/lane-b-mspl-interval-feasibility` (14 ahead); Codex iSDM / G3P / #872 / #855 / AA-03.

**STATE THIS LINE:** `PLATFORM: cursor | ON BRANCH (Dropbox checkout): claude/design-117-separation-programme | LANE: Cursor MSPL estimator-programme (worktree /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap) | OTHER LANES: ~15 live (codex+claude)`

---

## WHAT THE BRAIN ALREADY KNOWS

- Laplace approximates the latent integral; LA-ML and LA-MSPL are different *outer* criteria on that shared approximation (`ell_LA` ≠ exact `ell_marg`). Locked in the programme and in [[dr34-la-mspl-parallel-estimator-distilled]].
- LA-MSPL is a research programme, not a default, fallback, general-family, inference, or model-comparison claim.
- Unit of admission is `family/link × boundary × covariance × parameterization`. Success in one cell does not promote another.
- Current TMB contract overloads one integer: `estimator_id` 0 = public ML, 1 = LA-MSPL, 2 = internal penalty-off stable kernel at the MSPL point. `2` is not ordinary public ML.
- Design 88 remains the controlling *binary* contract. This programme does not supersede it.
- drmTMB already has a substantial MSPL (GLMM) programme and non-logit findings (PR #955 / sister notes). Co-opt the *warning* (do not inherit the logit theorem). Do not port drmTMB code into this GLLVM slice.
- Duplicate design IDs exist across refs. **Do not allocate a new numbered design.**
- Shared `2026-07-25-active-lane-split.md` is divergent. **Do not edit it from this lane.**

## WHAT SHINICHI TOLD US

- Resume the named Cursor handover; continue only OWED Next Immediate Steps.
- Once `/arc-loop` is understood: write **one** ultra-plan for **one** big arc that fits **this** Cursor lane.
- Stay read-only through Phase 2; stop at G0; after approval, Cursor finishes via `/goal` + LOOP/, not Phase 3 in the planning chat.
- Do not touch foreign-lane files. Do not stage Dropbox untracked files.

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Gauss  — estimator_id overloads criterion, kernel, and provenance evaluation · a silent TMB DATA-slot rewrite can change the tape · recommendation: keep integers 0/1/2; add an R adapter that *derives* them · question: none if the adapter rule holds · default: R-only adapter
  Rose   — combining 1A with a new typed error for estimator="ml"+VA would violate accepted-call parity · that is 1B · recommendation: record the combination, do not reject it · question: see Q1 (PR vehicle) · default: stacked Cursor PR, leave #961 as docs vehicle
  Fisher — finiteness is not a pass; this slice has no scientific estimand · its only load-bearing test is exact parity and the ability of those tests to FAIL · recommendation: snapshot current objectives before editing · default: fail-closed on any numeric drift
  Ada    — one Cursor hours-scale arc; R-side resolver + fit$estimator_provenance; TMB integers unchanged; VA+ml recorded not rejected; no LOOP/ until G0
```

## ADA'S RECOMMENDATION

Implement **Arc 1A only** on a **stacked Cursor branch** from `829a6832` in this worktree. Keep TMB `estimator_id` as the on-tape encoding. Add an R resolver and an inspectable-but-unadvertised `fit$estimator_provenance` on every fit that already goes through the current estimator surface. Extend `tests/testthat/test-mspl-api.R` (plus a thin new parity file if the existing file would become unreadable). Do not change print/summary/NEWS/Design 88/register/defaults.

## DECISIONS LOCKED (for this plan; G0 can revise)

1. PLATFORM = Cursor. After G0, execute via `/goal` in a fresh chat. Do not start Phase 3 here.
2. One arc: **Arc 1A — internal provenance parity.**
3. TMB `DATA_INTEGER(estimator_id)` stays 0/1/2. No new TMB DATA slots in 1A.
4. No accepted-call change: `estimator="ml"` + `integration="va"` remains accepted; 1A only *records* it.
5. No new design number. No active-lane-split edit. No foreign-lane files.
6. Compute = local targeted tests. Any fit >30 min stops (D-139). No campaign.
7. `estimator_id = 2` remains internal penalty-off provenance, never public ML.

## QUESTIONS STILL OPEN

**Closed at G0 (2026-08-14):**
1. PR vehicle = stacked `cursor/mspl-arc-1a-provenance` from `829a6832` + new PR. Leave #961 as the docs vehicle.
2. Do not wait to merge #961. Rebase later if the programme lands on `main` mid-arc.

NotebookLM remains default **no** unless Shinichi asks. Glance Settings → Usage before `/goal` launch.

---

## Phase 0.25 — Sweep receipt (gate for Phase 1)

| Surface | Evidence ran | Finding | Call |
|---|---|---|---|
| **repo git state** | `git -C /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap status -sb`; `git log -8 --oneline`; `git worktree list`; `git stash list`; `bash ~/shinichi-brain/tools/branch_drift_check.sh`; `git diff origin/main...HEAD --stat`; `gh pr view 961`; protected `git status -sb` on Dropbox + `~/.codex/worktrees/8e9d/gllvmTMB` | MSPL worktree **clean**, 2 ahead / 0 behind `origin/main`; files = programme + handover only. PR #961 OPEN draft MERGEABLE. Dropbox = Design 117 dirty (PROTECTED). Interval lane **ahead 14** (PROTECTED). ~30 worktrees live. | **resume this worktree**; do not start from Dropbox; do not merge siblings |
| **twin / sister** | drmTMB glob `*mspl*` (324 hits across worktrees); brain + programme cite PR #955 drmTMB non-logit findings; `projects/deep-research/README.md` DR34 | Sister has GLMM MSPL + “TMB MSPL is logit-only” blocker notes. Useful as a *non-transfer* warning, not as code to port. | **co-opt the warning**; do not port drmTMB estimator files |
| **brain** | MCP `search_notes` `search_all_projects: true` queries: `LA-MSPL Laplace estimator programme Arc 1A provenance gllvmTMB`; `MSPL estimator ml vs mspl provenance parity Design 88`; `read_note` DR34 | DR34 + programme lock the two-axis architecture and the 1A/1B split. No prior 1A implementation. | **reuse programme + DR34**; **build the 1A gap** |
| **deterministic grep** | `grep -in MSPL\|mspl\|LA-MSPL memory/AGENT_LOG.md` (1 recent backup note); `memory/DECISIONS.md` (D-118-era untracked MSPL; Design 252 “MSPL stays logit-only” on an unlanded drmTMB branch; LA-MSPL Fir B2 PROTECTED); `memory/OPEN_QUESTIONS.md`; `journal/` 2026-08-09/10/13; `projects/deep-research/README.md` DR34 line | No decision that 1A is already done. B2/interval remain protected/incomplete. | **do not reopen B2 or intervals** |
| **Verdict** | | Genuinely new = R/TMB-internal provenance adapter + parity tests. Programme, handover, and #961 already exist. Arc 1A is **not implemented**. | **resume programme branch / build-the-1A-gap** |

---

## Phase 0.3 / 0.3b — Live roster + two-bar

- **PLATFORM:** Cursor (`session_ownership.sh`).
- **Cursor roster used:** `memory/MODEL-ROUTING.md` Cursor side, refreshed **2026-08-01** (Composer 2.5 + Grok 4.5 on Cursor Models; Auto Cost / Claude / GPT on Other Models; on-demand off).
- **Phase 0.3b Usage meters:** **not readable from this Ada subagent.** Do not invent percentages. Standing rule: on-demand stays disabled; glance Settings → Usage before `/goal` launch.
- **This planning session:** recon on **Cursor Models** (Grok); judgment/synthesis in this Ada report (Other Models / parent). Slice table uses **both bars on purpose**.

---

## Phase 0.4 — Questions for Shinichi (answered 2026-08-14)

**G0 answers:** approve · stacked Cursor branch + new PR · do not wait on #961.

### Q1 — Branch / PR vehicle

**QUESTION:** Should Arc 1A land as a **stacked Cursor branch + new PR**, or as implementation commits on draft **#961**?  
**WHY NOW:** Handover allows either; #961 is explicitly “do not auto-merge; this draft is the review and handover vehicle”; programme text also said “implement Phase 1A from current `origin/main`.”  
**TEAM VIEW:** Rose — keep the docs vehicle clean. Ada — stacking preserves the programme commits without converting a docs PR into an R/TMB PR.  
**RECOMMENDATION:** Create `cursor/mspl-arc-1a-provenance` from `829a6832` in this worktree; open a **new** PR. Leave #961 draft until you choose to merge the programme onto `main`.  
**IF YOU DO NOT MIND:** stacked Cursor branch + new PR.  
**WHAT CONTINUES:** nothing until G0.

### Q2 — Merge #961 first?

**QUESTION:** Do you want #961 merged onto `main` *before* 1A starts, so implementation branches from updated `origin/main`?  
**WHY NOW:** Programme’s original “from current `origin/main`” line vs live fact that the programme is only on this branch.  
**TEAM VIEW:** Ada — optional hygiene, not a scientific gate. Stacking is safe either way.  
**RECOMMENDATION:** **Do not wait.** Stack now. Merge #961 when you want the programme on `main`; rebase the Cursor branch if that happens mid-arc.  
**IF YOU DO NOT MIND:** do not wait; stack.  
**WHAT CONTINUES:** nothing until G0.

### Phase 0.5 — NotebookLM (offered, not run)

A full skeptical Notebook/Ranga pass already landed as DR34 (notebook `10f82316-…`; companion briefing/audio/video were pending at programme close). **Want a fresh NotebookLM pass before `/goal`?** Default **no** — 1A is an internal parity refactor, not a novelty claim.

---

## The one big arc

**Name:** Arc 1A — Internal provenance parity  

**Fence (definition of the lane):**

- IN: R-side resolver + compatibility table; adapter that still sends `estimator_id` 0/1/2; `fit$estimator_provenance` on current admitted routes; parity tests; after-task; stacked Cursor PR.
- OUT: Arc 1B typed errors / deprecation / criterion API; Arc 2 registry/B2; Arc 3 Gaussian Heywood; Arcs 4–8; inference, intervals, AIC/LRT, fallback, defaults; NEWS/user-facing print changes; Design 88 rewrite; validation-register status change; new design number; active-lane-split; Design 117 files; interval-lane files; Codex iSDM / G3P / #872 / #855 / AA-03; campaigns; LOOP/ until G0.

**Adapter contract (locked unless G0 revises):**

```text
R resolver
  → criterion_id      = la_ml | la_mspl | reml | va_elbo   (descriptive)
  → numeric_kernel_id = legacy_ml | audited_stable_mspl | va
  → penalty_eval_id   = off | on | provenance_off
  → integration       = laplace | va | aghq   (resolved, not wished)
  → estimator_id      = 0 | 1 | 2             (EXISTING TMB integer; derived)
  → public_estimator  = ML | MSPL | REML      (current labels; may be coarse)

TMB tape unchanged: DATA_INTEGER(estimator_id) only.
estimator_id = 2 remains the penalty-off stable kernel at the MSPL point.
```

**Current encoding this adapter must preserve** (measured in this worktree):

| Call | Today | 1A must still do |
|---|---|---|
| implicit `gllvmTMB(...)` | `estimator_id = 0`, `fit$estimator = "ML"` | same numbers, same acceptance; provenance records Laplace + LA-ML + penalty off |
| explicit `estimator = "ml"` + Laplace | identical to implicit (existing test) | same |
| `estimator = "ml"` + `integration = "va"` | **accepted** (falls through; no typed error) | **still accepted**; provenance records `integration=va` and that public label `ML` is coarse |
| `estimator = "mspl"` + Laplace binary | `estimator_id = 1`; class `gllvmTMB_mspl`; second tape `estimator_id = 2` | same objectives, gradients, reports, warnings, errors |
| `estimator = "mspl"` + VA / AGHQ / REML / julia / ridge | abort (existing classes) | same abort, same class |
| explicit `estimator` + `REML = TRUE` | `gllvmTMB_estimator_reml_conflict` | same |

**Primary files (expected):**

- NEW `R/estimator-provenance.R` — resolver + descriptive compatibility table (internal, unexported).
- `R/fit-multi.R` — call resolver; set `estimator_id` *only* via adapter; attach `fit$estimator_provenance`; keep `estimator_id <- 2L` path as adapter output `penalty_eval = provenance_off`.
- `R/gllvmTMB.R` — attach the same object on the VA dispatch path (record, do not reject).
- `R/mspl.R` — only if the prepare helper should return resolved IDs; do not change atoms.
- `tests/testthat/test-mspl-api.R` and/or NEW `tests/testthat/test-estimator-provenance.R`.
- `docs/dev-log/after-task/2026-08-14-mspl-arc-1a-provenance-parity.md` (new closeout; do not rewrite the programme).
- `docs/dev-log/check-log.md` (append only, after implementation).

**Do not touch:** `src/gllvmTMB.cpp` unless a comment-only clarification is required to name the three IDs. Prefer **zero C++ edits**. A C++ edit that changes the tape is a HOLD.

**Definition of done:**

1. Implicit ML, explicit Laplace ML, current MSPL (logit/probit/cloglog; ordinary + existing spatial cells already in `test-mspl-api.R`), and currently accepted VA+ml all keep **exact** `opt$par`, `opt$objective`, report fields used today, warning/error **classes**, and acceptance.
2. Every such fit carries `estimator_provenance` whose fields match the adapter contract and the compatibility table.
3. `estimator_id` on the live tape remains 0/1/2 with the same meaning.
4. Gauss/Noether/Rose PASS (or HOLD with a named defect). No P0/P1 “and also do 1B.”
5. After-task + check-log written. Stacked PR open. No NEWS, no register promotion, no default change.
6. Handback before Arc 2.

---

## SLICE TABLE

| ID | Slice | Member | model+effort | Bar | time | files | dep |
|---|---|---|---|---|---|---|---|
| S0 | Recon: freeze baseline hashes of current `estimator_id` sites + existing MSPL tests | Curie (scout) | Grok/Composer · low | **Cursor Models** | 0.5 h | `R/fit-multi.R`, `R/gllvmTMB.R`, `R/mspl.R`, `src/gllvmTMB.cpp` (read), `tests/testthat/test-mspl-api.R` | — |
| S1 | Write internal compatibility table + resolver contract (no behavior yet) | Boole + Ada | Auto Cost · med | **Other Models** | 1.5 h | NEW `R/estimator-provenance.R` (table + function stubs + roxygen internal) | S0 |
| S2 | Wire adapter in `fit-multi.R` / VA path; attach `fit$estimator_provenance` | Emmy (build) | Composer 2.5 · med | **Cursor Models** | 2.5 h | `R/estimator-provenance.R`, `R/fit-multi.R`, `R/gllvmTMB.R` | S1 |
| S3 | Parity tests: implicit/explicit ML, MSPL, accepted VA+ml, existing aborts | Curie | Composer 2.5 · med | **Cursor Models** | 2.5 h | `tests/testthat/test-mspl-api.R` and/or `test-estimator-provenance.R` | S2 |
| S4 | Targeted test run + no-change receipt (OMP=1); stop if any numeric drift | Grace + Curie | Grok · low (run) / Auto Cost · med (read logs) | **Cursor Models** then **Other Models** | 1.5 h | test logs only | S3 |
| S5 | Gauss/Noether/Rose plan-and-diff review | Gauss + Noether + Rose | pinned Claude · high | **hand off** (Claude Opus) | 1.0 h | diff vs `829a6832` / `origin/main` | S4 |
| S6 | After-task + check-log + stacked PR | Rose + Ada | Auto Cost · med | **Other Models** | 0.5 h | after-task, check-log, PR body | S5 |
| V | Mechanical verify: files exist, tests named, no foreign-lane paths, no NEWS/register | Melissa-prep / scout | Grok · low | **Cursor Models** | 0.3 h | receipt | S6 |
| R | Melissa reconcile plan vs actual | Melissa | Auto Cost · low–med | **Other Models** | 0.3 h | `docs/dev-log/plan-actual/2026-08-14-mspl-arc-1a.md` | V |

**SEARCH:** none new. NotebookLM offered (Phase 0.5); default no.  
**SLICES:** S0 → S1 → S2 → S3 → S4 → S5 → S6 → V → R  
**PARALLEL after G0:** S0 can start immediately; S1 waits on S0 contract notes; no other true fan-out (shared `fit-multi.R`).  
**FAN-OUT:** 0 in this planning chat. After `/goal`, at most 2 Cursor children at a time (S0; then S1).  
**FAN-OUT BUDGET:** checkpoint=`mspl-arc-1a-g0` · new children=0/6 this chat · scout=S0 · build=S2/S3 · ceiling=S5 (hand off, not a Cursor child) · reuse=n/a  
**LUNA SUITABILITY:** n/a — PLATFORM is Cursor, not Codex. Cursor equivalent: S0/V on Cursor Models.  
**ULTRA EFFORT:** no.  
**CONTEXT BRAKE:** parent input=unknown · fresh-task trigger=**after G0, start `/goal` in a new chat**  
**COMPACTIONS:** this Ada turn is a planning close · boundary=`START A FRESH TASK` for execution  
**LANE RECEIPT:** `START A FRESH TASK` · reason=G0 is the plan gate; `/goal` must not inherit this planning thread · next-task prompt=below  
**AUTO-REVIEW:** guardian calls unknown · action=none  
**D-43 PANEL:** milestone=`mspl-arc-1a-parity` · status=not fired · fire once after S4 evidence exists · composition=2 build + 1 ceiling on Claude/Codex, not in the planning chat  
**MODELS:** see table. Scout=Grok/Composer; judgment=Auto Cost / Claude; verify/HPC=hand off.  
**ESTIMATE:** ~8–12 h wall-clock (matches programme §15) · 1 `/goal` session with one fresh-chat barrier after S4 · fits one Cursor lane  
**REVIEW (plan, before run):** Rose + Gauss — this file. Rose confirms the sweep receipt is non-vacuous (it is).  
**VERIFY:** targeted `test-mspl-api.R` (+ new provenance file); exact parity; no `R CMD check` required unless S2 touches NAMESPACE unexpectedly.  
**CONSOLIDATE:** after-task + stacked PR + Melissa plan-actual.  
**RECONCILE:** Melissa required (meaningful close).

---

## `/arc-loop` / `/goal` understanding (for the parent report)

On Cursor, `/arc-loop` is the Claude name; the adapter is **`/goal`**. After G0:

1. Scaffold LOOP/ (`GOAL.md` immutable, `arcs.md`, `checkpoint.md`, `ultra-plan.md` copy of this file).
2. Re-read `LOOP/GOAL.md` every arc.
3. Run reversible slices unattended; **pause at irreversible gates** (merge to main, NEWS/public claim, any C++ tape change, any accepted-call change).
4. Do **not** execute Phase 3 in the planning chat.
5. Do **not** run `lane_launch.sh` until G0. This worktree already exists and is the claimed lane; a second `claude/lane-*` worktree would collide.

Irreversible gates inside this arc: merge; any decision to edit `src/gllvmTMB.cpp` beyond comments; any new error for a currently accepted call (that is 1B — STOP).

---

## Paste-ready `/goal` prompt (do not launch)

```text
/goal

Ultra-plan G0 approved. Run this plan to completion via LOOP/.

LANE: cursor-mspl-arc-1a-provenance
REPO: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
PLAN: docs/dev-log/plans/2026-08-14-cursor-mspl-one-arc-ultra-plan.md

READ FIRST: the approved plan → repo AGENTS.md → docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md → docs/dev-log/handover/2026-08-14-cursor-handover.md.

WORKSPACE: this MSPL worktree only. Create stacked branch cursor/mspl-arc-1a-provenance from 829a6832 unless G0 said otherwise. Do NOT use the Dropbox Design 117 checkout. Do NOT touch Design 117, interval-feasibility, iSDM, G3P, #872, #855, or AA-03 files.

SCAFFOLD: write LOOP/GOAL.md, LOOP/arcs.md, LOOP/checkpoint.md, LOOP/ultra-plan.md from the plan; commit in this worktree.

RUN: goal skill — re-read GOAL each arc; verify by LOG not exit code; pause at OPEN GATE; overwrite checkpoint each arc; fresh chat at batch barriers.

START ARC: S0 recon / baseline freeze.
NEXT GATE: any C++ tape change, any accepted-call change, merge to main, NEWS/public claim (all STOP).
INVARIANTS: TMB estimator_id stays 0/1/2; no Arc 1B; no campaign; OMP_NUM_THREADS=1 for tests.
```

---

## Explicitly NOT started

- Phase 3 implementation
- LOOP/ scaffold and `lane_launch.sh`
- Any R/TMB/test edit
- Commit, push, merge
- Arc 1B and Arcs 2–8
- NotebookLM
- Foreign-lane files, Dropbox untracked staging, new design numbers
