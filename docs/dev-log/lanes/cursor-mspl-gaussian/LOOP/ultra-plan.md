# Ultra Plan — Gaussian LA-MSPL (Heywood / pick C) — G0

**Status:** G0 APPROVED 2026-08-15 (Q1 merge CI+Rose · Q2 admitted/oracle_local · Q3 this LOOP kit). Binding copy for `/goal` closeout of #967.

**Lane claimed:** Cursor MSPL Gaussian Heywood (closeout of mid-flight implement)  
**Worktree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`  
**Branch:** `cursor/mspl-gaussian-heywood-atom` @ `813da14a` (3 ahead / **0 behind** `origin/main`)  
**In-flight PR:** [#967](https://github.com/itchyshin/gllvmTMB/pull/967) **OPEN · MERGEABLE · CI in progress** (ubuntu-latest pending as of plan write)  
**Stack base:** uniqueness [#966](https://github.com/itchyshin/gllvmTMB/pull/966) **MERGED** to `main` (`d8fe6764`)  
**Authoritative programme:** `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md` §Phase 3  
**Prep / uniqueness:**  
`docs/dev-log/research/2026-08-15-mspl-phase3-gaussian-heywood-prep.md` ·  
`docs/dev-log/research/2026-08-15-mspl-gaussian-psi-uniqueness-map.md` (pick **C**)  
**Design 88:** controlling *binary* contract only — does **not** authorise Gaussian atoms or SE  
**Protected foreign lane:** `codex/lane-b-mspl-interval-feasibility` (binary MSPL SE / sandwich / profile / coverage)

This is **LA-MSPL** (Laplace + soft *outer* criterion), **not EVA/VA**, **not** the binary interval lane.

---

```text
🎯 GOAL
Solo platform: Cursor
Deliverable: matched Gaussian ordinary LA-MSPL (Hirose, uniqueness pick C) landed as an experimental opt-in point estimator on main — registry admitted / oracle_local only — with Rose claim-boundary PASS and Melissa plan-actual
HEADLINE: land matched Gaussian Heywood LA-MSPL under uniqueness pick C
IN PARALLEL: S0 recon of #967 vs main; S1 LOOP uniqueness contract pin; S4 Rose claim fence (after S0 map); Bernoulli point regression smoke if cheap
DEFER: Totoro/DRAC campaign; Gaussian or binary SE/intervals; Poisson/NB; free-ε / pick-B cell; Phase 1B API; NEWS/public covered claim; EVA/VA; Design 117 / iSDM / G3P / #872 / #855 / AA-03
DISCIPLINE: verify=#967 CI green + healthy/near-Heywood se=FALSE smoke + Bernoulli point still finite + Rose boundary PASS · compute=local targeted only (OMP_NUM_THREADS=1; any fit >30 min STOP) · closure=merge #967 (if approved) + after-task already drafted + Melissa plan-actual + LOOP GOAL frozen
```

**ARC PROGRAM:** N/A — no Arc Card. Programme Phase 3 is the parent; this ultra-plan is the **Cursor closeout / verification** of the mid-flight implement PR.

**PREFLIGHT (Phase 0.2):** `~/shinichi-brain/tools/lane_preflight.sh` → **FOREIGN LANE ACTIVE (codex + claude + direct-to-main)** · ~15 live lanes · duplicate design slots (next free **118**).  
**LANE TAKEN:** `cursor/mspl-gaussian-heywood-atom` / PR **#967** (this worktree).  
**NOT TAKEN:** `codex/lane-b-mspl-interval-feasibility`; Codex #960/#958/#957; Claude #955; other cursor MSPL siblings except as read-only.

**STATE THIS LINE:** `PLATFORM: cursor | ON BRANCH: cursor/mspl-gaussian-heywood-atom | LANE: Cursor MSPL Gaussian Heywood (#967) | OTHER LANES: codex interval PROTECTED; ~14 others live`

---

## Current truth (read before approving)

| Fact | Evidence |
|---|---|
| Uniqueness **pick C** closed | #966 merged; research note pins `ψ ≡ sd_B²` under Q7-mapped `σ_ε` |
| Hirose tape + R fence **already on #967** | `gll_mspl_hirose_atom`; family-aware MSPL; Jeffreys/`V_loading` remain Bernoulli-only |
| Local smoke **PASS** | `test-mspl-gaussian-fit-smoke.R` 19; registry `gaussian:identity:ordinary:q{1,2}` → `admitted` / `oracle_local` |
| After-task draft exists | `docs/dev-log/after-task/2026-08-15-mspl-gaussian-hirose-implement.md` |
| Catch-up LOOP GOAL is **stale** for this arc | Still says “do not admit Gaussian” — historical Phase-2 fence |
| Catch-up checkpoint already points at #967 | `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/checkpoint.md` |
| **#967 mid-merge** | OPEN, MERGEABLE, CI pending — **plan from verify/closeout, not greenfield rebuild** |

If CI fails or the atom is wrong under Rose/Gauss, S2–S3 reopen as **fix**, not as a second implement PR.

---

## WHAT THE BRAIN ALREADY KNOWS

- **Sterzinger, Kosmidis & Moustaki (2026)** *Maximum softly penalized likelihood in factor analysis* (*Psychometrika*, doi:10.1017/psy.2026.10092) is the primary theory bridge for a **matched Gaussian FA / Heywood** route — not for Bernoulli GLLVM, not for EVA.
- Soft atoms: **Hirose** \(c_N \sum_j S_{jj}/\psi_j\) preferred (E3 immediate when \(S_{jj}>0\)); **Akaike** sibling on \(\|\lambda_j\|^2/\psi_j\); rate \(c_N=\sqrt{2/N}\), \(N=\) units — **not** Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\).
- **Bernoulli \(V_{\mathrm{loading}}\)** (pseudo-Huber on loading rows) is the **wrong object** for Heywood (\(\psi\to 0\)); it is not FA scale-equivariant. Forbidden transplant.
- **Uniqueness pick C** (pinned FA): Q7 maps `log_sigma_eps` off on ordinary `latent(..., unique = TRUE)` complete cells → paper \(\Psi \equiv \mathrm{diag}(sd_B^2)\). Pick A with free \(\sigma_\varepsilon\) fails the flat ridge; pick B (\(\psi^{\mathrm{total}}\)) deferred for free-ε / repeated measures.
- **#856** (shared `log_sigma_eps` across gaussian *and* lognormal) is **out of scope** for this cell — pin is cell-local; do not redesign shared observation noise.
- Programme Phase 3 exit gate is interiority + covariance recovery + healthy no-harm; **Gaussian success earns only the Gaussian route**. Finiteness alone is not admission for a *covered* claim — current PR correctly stays `oracle_local`.
- Design 88 = binary LA-MSPL surface. Interval/SE work stays on Codex Lane B.
- Grep receipt: `DECISIONS.md` / `AGENT_LOG.md` MSPL lines confirm Arc 1A / catch-up G0 approvals; no decision reverses pick C or authorises SE in this lane.

---

## WHAT SHINICHI TOLD US

- Catch-up GOAL closed; **KEEP GOING** into Gaussian LA-MSPL **point** implement (checkpoint 2026-08-15).
- This planning task: write G0 ultra-plan; **STOP at G0**; note #967 if mid-merge; plan from current truth.
- Cursor Ultra pace: Ask → Manual → Agent; after G0, `/goal` in a fresh chat — do not leave a long planning thread executing.

---

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Gauss  — Hirose must hit θ_diag_B / sd_B under mapped σ_ε only; Jeffreys and V_loading must stay Bernoulli · wrong Ψ or free-ε ridge = prior on unidentified split · recommendation: verify tape against pick-C contract, do not rebuild · question: none if #967 matches prep §1 · default: verify-then-merge
  Fisher — oracle_local + se=FALSE smoke is not multi-seed recovery · recommendation: keep evidence status honest; no covered/NEWS · question: Q2 (admit now vs after multi-seed) · default: keep admitted/oracle_local as on #967
  Rose   — catch-up GOAL still forbids admission while checkpoint admits · claim bleed into binary SE or NEWS is the failure mode · recommendation: new Gaussian LOOP GOAL; Rose boundary before merge · question: Q1 / Q3 · default: Rose then merge when CI green
  Curie  — healthy + near-Heywood pair vs LA-ML (point) already in smoke · campaign is HARD STOP · default: no Totoro
  Ada    — treat #967 as the implement vehicle; S0–S3 are VERIFY; S4 Rose; S5 merge+Melissa; Sol/Opus only if tape disputed
```

---

## ADA'S RECOMMENDATION

Approve this plan as a **verify-and-close** arc on **#967**, not a greenfield rebuild.

1. **Do not open a second implement PR** while #967 is MERGEABLE and 0 behind main.
2. Keep registry **`admitted` / `oracle_local`** as already on the PR (point estimates only; `claim_guard` OUT of SE / campaign / NEWS).
3. Stand up a **new** LOOP kit at `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/` (catch-up GOAL stays historical CLOSED — do not rewrite its immutable “do not admit” mission).
4. After G0: `/goal` → S0 map → S1 pin LOOP → S2/S3 verify (skip rebuild if green) → S4 Rose → S5 merge when CI green + Melissa.
5. Call **Sol/Opus on the atom only if** Rose/Gauss flags a tape mismatch or CI exposes a numerical defect.

---

## DECISIONS LOCKED (for this plan; G0 can revise)

1. PLATFORM = **Cursor**. Solo. Worktree only: `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
2. Estimand = **LA-MSPL** on ordinary Gaussian identity `latent(..., unique = TRUE)`, q ∈ {1,2}. **Not EVA. Not AGHQ-MSPL.**
3. Uniqueness = **pick C** (Q7-pinned `σ_ε`; `ψ ≡ sd_B²`). Soft atom = **Hirose** \(c_N\sum S_{jj}/\psi_j\), \(c_N=\sqrt{2/N}\).
4. **Bernoulli \(V_{\mathrm{loading}}\) / Jeffreys transplant forbidden** on the Gaussian cell.
5. Evidence ceiling this arc: **`oracle_local` + se=FALSE** point smoke. No covered claim. No NEWS overclaim.
6. **HARD STOP:** Totoro/DRAC campaign; Gaussian or binary SE/intervals; Poisson/NB; free-ε (pick B); Phase 1B; Design 117 / foreign lanes; `#856` redesign.
7. No new design number (duplicate slots; next free 118 unused here).
8. Binary Codex interval lane remains **PROTECTED** — zero path edits.

---

## QUESTIONS STILL OPEN (G0 — answer these)

**Q1 — Merge #967 when CI is green?**  
**WHY NOW:** PR is OPEN / MERGEABLE / mid-CI; after-task and smoke already claim PASS.  
**TEAM VIEW:** Rose wants claim-boundary PASS before merge; Ada defaults to Rose-then-merge.  
**RECOMMENDATION:** Yes — merge after **CI green + S4 Rose PASS** (same sitting if Rose is clean). Do not wait on multi-seed or Sol unless Q2/Q_atom fires.  
**IF YOU DO NOT MIND:** merge on CI green + Rose.  
**WHAT CONTINUES:** S0–S3 verify work is reversible documentation / checks.

**Q2 — Keep registry `admitted` / `oracle_local` now, or revert to `planned` until multi-seed smoke?**  
**WHY NOW:** #967 already flipped admit after local smoke; Fisher flags that this is not recovery.  
**TEAM VIEW:** Fisher cautious; Ada keeps admit at `oracle_local` with hard claim_guard (matches programme “finite fits alone do not pass” for *covered*).  
**RECOMMENDATION:** **Keep admitted / oracle_local** as on #967. Multi-seed / interiority campaign is a **later gated** arc, not a reason to undo the fence.  
**IF YOU DO NOT MIND:** keep admitted.  
**WHAT CONTINUES:** smoke + Rose proceed either way.

**Q3 — LOOP home: new `cursor-mspl-gaussian/LOOP/` vs extend catch-up LOOP?**  
**WHY NOW:** Catch-up `GOAL.md` is immutable and still forbids Gaussian admission; checkpoint already narrates #967.  
**TEAM VIEW:** Rose — new GOAL avoids rewriting history; Ada agrees.  
**RECOMMENDATION:** **New kit** `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/` (draft GOAL below). Leave catch-up LOOP as CLOSED historical; one-line pointer in catch-up checkpoint after merge.  
**IF YOU DO NOT MIND:** new Gaussian LOOP.  
**WHAT CONTINUES:** draft GOAL can land in the same closeout PR or a tiny docs follow-up.

---

## Sweep receipt (Phase 0.25)

| Surface | Evidence ran | Finding | Call |
|---|---|---|---|
| **repo git** | `git status -sb`; `branch_drift_check.sh`; `gh pr view 967` | branch 3 ahead / 0 behind main; #967 OPEN MERGEABLE CI pending; #966 on main | **resume #967** — do not rebuild |
| **twin/sister** | programme + drmTMB #955 awareness | drmTMB non-logit = warning only | **n/a** co-opt warning; no code port |
| **brain** | `search_notes` hybrid “LA-MSPL Gaussian Heywood…” + grep `DECISIONS.md`/`AGENT_LOG.md` “MSPL\|Heywood\|Hirose” | programme Phase 3 + Arc 1A/catch-up G0 history; Sterzinger FA as theory bridge in prep docs | **reuse** pick C + Hirose; **build gap** = closeout only |
| **log/journal grep** | `grep -in MSPL\|Heywood` on DECISIONS + AGENT_LOG | no decision reverses pick C or authorises SE here | proceed |
| **Verdict** | — | Genuine gap = **CI + Rose + merge + LOOP/Melissa**; implement already on #967 | **verify / close the gap** |

---

## Slice table

| ID | Slice | Member | Model · effort | Bar | Dispatch | Dep | In → Out | Done bar |
|---|---|---|---|---|---|---|---|---|
| **S0** | Recon #967 / `origin/main` (CI, file map, claim_guard paths) | Scout | Grok · low | Cursor Models | native | — | PR+diff → short recon note in LOOP/checkpoint | CI status named; no foreign-lane files in diff |
| **S1** | Uniqueness pick C locked in **Gaussian** LOOP (`GOAL.md` + arcs pointer) | Build | Composer · med | Cursor Models | native | S0 | draft GOAL → `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/*` | GOAL matches pick C + HARD STOPs; catch-up not rewritten |
| **S2** | C++ Hirose atom + R fence — **VERIFY** (rebuild only if missing/wrong) | Gauss+Build | Composer · med; **Sol/Opus · high only if tape open** | Cursor Models → hand off if needed | native / hand off | S0 | `src/gllvmTMB.cpp` + `R/mspl*.R` → PASS/FAIL tape receipt | Hirose on `sd_B`; no Jeffreys/`V_loading` on gaussian; prepare fence correct |
| **S3** | Local healthy + near-Heywood pair vs LA-ML (**point only**, `se=FALSE`) | Curie | Composer · med | Cursor Models | native | S2 | re-run `test-mspl-gaussian-fit-smoke.R` (+ Bernoulli logit finite check) → receipt | tests PASS; no SE paths touched |
| **S4** | Rose claim boundary (NEWS/register/SE bleed) | Rose | Claude Opus · high **or** Auto Cost | Other Models | native | S1+S3 | claim_guard audit → PASS/FAIL note | no NEWS overclaim; binary SE untouched; `oracle_local` honest |
| **S5** | After-task (exists) + merge #967 (if Q1) + Melissa plan-actual | Ada+Melissa | Composer · med / Auto · med | both bars | native | S4 + CI green | merge + `docs/dev-log/plan-actual/2026-08-15-mspl-gaussian-heywood.md` | PR merged or explicitly parked; Melissa filed |
| **V** | Mechanical verify (diff still MSPL-only; drift vs main) | Scout | Grok · low | Cursor Models | native | S5 | status receipt | 0 behind after merge; no Dropbox bleed |
| **R** | Melissa reconcile | Melissa | Auto · low–med | Other Models | native | V | plan-actual | plan vs actual recorded |

**PARALLEL after G0:** `{S0}` then `{S1 ‖ S2-verify}` then `S3` → `S4` → `S5`.  
**SEQUENTIAL:** merge ← Rose ← smoke ← tape verify ← recon.

**Sol/Opus atom gate:** skip unless S2 FAIL or Shinichi answers Q2 with “revert admit / re-derive”.

---

## HARD STOP (do not do in this arc)

- Totoro / DRAC / multi-seed **campaign**
- Gaussian or binary **SE / sandwich / profile / intervals / coverage**
- **Poisson / NB** (programme Phase 4)
- **NEWS** or validation-register **covered** promotion
- Binary interval lane files (`codex/lane-b-mspl-interval-feasibility`)
- Free-ε / pick **B** cell; `#856` redesign
- EVA/VA / AGHQ-MSPL wording or routing
- Phase **1B** accepted-call policy
- Editing Dropbox checkout or foreign-lane design docs

---

## Paste-ready `/goal` prompt (after G0 approval)

```text
/goal

Worktree ONLY: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
Branch: cursor/mspl-gaussian-heywood-atom
Authoritative plan: docs/dev-log/plans/2026-08-15-cursor-mspl-gaussian-heywood-ultra-plan.md
LOOP: docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/GOAL.md  (create from plan draft if missing)

This is LA-MSPL, not EVA. PLATFORM=Cursor.

G0 answers: <paste Shinichi answers to Q1–Q3>

Mission: VERIFY and CLOSE mid-flight PR #967 (Gaussian ordinary Hirose LA-MSPL, uniqueness pick C, point estimates only). Do NOT rebuild if recon shows tape+smoke already green.

Slices in order:
S0 recon #967 vs main + CI
S1 lock pick-C contract into cursor-mspl-gaussian LOOP (do not rewrite catch-up GOAL)
S2 verify Hirose atom + R fence (Sol/Opus only if tape FAIL)
S3 re-run healthy+near-Heywood se=FALSE smoke; Bernoulli logit still finite
S4 Rose claim boundary
S5 Melissa plan-actual; merge #967 only if Q1 yes AND CI green AND Rose PASS

HARD STOP: campaign, SE/intervals, Poisson, NEWS overclaim, binary interval lane, free-ε, #856 redesign.
claim_guard: oracle_local point only. Codex lane-b PROTECTED.
OMP_NUM_THREADS=1. Any fit >30 min STOP.
When done: freeze LOOP checkpoint; surface PR URL + after-task + Needs you only if blocked.
```

---

## Draft LOOP/GOAL.md (recommended new kit)

**Recommendation:** create `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/` — do **not** mutate catch-up’s immutable GOAL.  
Draft text (land in S1 after G0):

```markdown
# GOAL — cursor-mspl-gaussian (IMMUTABLE — re-read every cycle)

Read this first. Auto-compact eats messages, not this file.

Kit: `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/`.
Do **not** write repo-root `LOOP/` (0.6 EVA/VA kit).

This is **LA-MSPL**, not EVA.

## Mission

Solo platform: Cursor.

Verify and land PR **#967**: Gaussian ordinary `estimator = "mspl"` under
uniqueness **pick C** (Q7-pinned σ_ε; ψ ≡ sd_B²), Hirose soft atom
`c_N ∑ S_jj/ψ_j` with `c_N = √(2/N)`, point estimates only
(`admitted` / `oracle_local`).

Finish line: #967 merged (or explicitly parked per G0), Rose boundary PASS,
Melissa plan-actual filed, LOOP checkpoint frozen.

## Headline

Land matched Gaussian Heywood LA-MSPL under uniqueness pick C.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
- Branch `cursor/mspl-gaussian-heywood-atom` until merge.
- Do NOT edit Dropbox checkout or foreign lanes (esp. Codex interval-feasibility).
- Do NOT transplant Bernoulli V_loading / Jeffreys onto Gaussian.
- Do NOT touch SE / sandwich / profile / coverage paths.
- No NEWS covered claim. No campaign. No Poisson/NB. No free-ε (pick B).
- No #856 redesign. Local tests only. `OMP_NUM_THREADS=1`. Fit >30 min STOP.

## Authoritative WHAT

`docs/dev-log/plans/2026-08-15-cursor-mspl-gaussian-heywood-ultra-plan.md`
Programme Phase 3: `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
Uniqueness: `docs/dev-log/research/2026-08-15-mspl-gaussian-psi-uniqueness-map.md`

## Definition of done

1. Recon confirms #967 vs main (0 behind at merge).
2. Hirose + pick-C fence verified (or fixed if FAIL).
3. Healthy + near-Heywood se=FALSE smoke green; Bernoulli point still finite.
4. Rose claim boundary PASS.
5. After-task + Melissa plan-actual present.
6. #967 merged per G0 Q1 (or parked with reason).

## OPEN GATES (do not execute)

- Totoro/DRAC campaign / multi-seed recovery for covered
- Gaussian or binary SE/intervals
- Poisson/NB; ordinal; structures
- NEWS / register covered promotion
- free-ε / pick B; #856
- Phase 1B
```

---

## Closure checklist (post-G0)

- [ ] Shinichi answers **Q1–Q3**
- [ ] Fresh `/goal` chat in the worktree (not this planning thread)
- [ ] S0–S5 per table
- [ ] Surface: PR URL, after-task path, Melissa path, any 🔴 Needs you
