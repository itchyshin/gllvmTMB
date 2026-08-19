# Ultra-plan — Design 125 fork B, Totoro T1 (RECORD only)

Frozen at G0 approval (Shinichi 2026-08-18, unattended): **Totoro T1**.
Binding detail for `/goal`. Locked grid:
`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`.
Do **not** reopen `docs/dev-log/lanes/cursor-mspl-fork-B-L2/` (L2
**GOAL_MET**) or `docs/dev-log/lanes/cursor-mspl-fork-B/` (g0_unlock
**GOAL_MET**) or repo-root `LOOP/` (Poisson \(W_*\) REPLACE **GOAL_MET**).

## 🎯 GOAL

```
🎯 GOAL
Solo platform: Cursor (this session; read, not inferred)
Deliverable: T1 recorded on DRAC job arrays (Fir/Nibi/Rorqual ± Narval) — locked 4-cell × 200 = 800 hold-out; dual coverage + refusal pricing; official receipt. Kit on docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/
HEADLINE: Inherit L1 0.880 and L2 0.900 / 0.780; run locked 800-fit RECORD-only grid on the DRAC fleet; Totoro = smoke only; T* stays NOT-FROZEN
IN PARALLEL: kit docs · later /goal: local 1-rep × 4 → smoke → sbatch arrays across GP clusters
DEFER: T* freeze · undraft #1077 · public se/vcov/confint · MSPL-04→covered · NEWS covered · reopen L2/g0_unlock · E2 · any family beyond binomial logit · optional confirm 20260834 · AI GPU clusters
DISCIPLINE: verify=read LOG + object, never exit code · compute=DRAC arrays (Totoro smoke/fallback) · closure=T1 receipt recorded, not calibrated
```

LANE TAKEN: **`cursor-mspl-fork-B-totoro`** — new kit only. Foreign
Claude/Codex lanes and other Cursor MSPL lanes are live; this session
does not claim their files. Closed L2 kit is **not** reopened.

ARC PROGRAM: N/A (no Arc Card; `/goal` executes this plan)

---

## Phase 0.2 — Shannon pre-flight

```
VERDICT: FOREIGN LANE ACTIVE (claude codex direct-to-main)
PLATFORM: cursor | ON BRANCH (Dropbox checkout): cursor/cloud-agent-1786753856541-jx2lb (748 behind origin/main — NOT used)
LANE TAKEN: cursor-mspl-fork-B-totoro
WORKTREE: ~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro @ origin/main (437032ed after ff)
OTHER LANES: many Claude/Codex + Cursor MSPL lanes (including closed L2 + g0_unlock)
COORD BOARD: committed to origin/main
DESIGN NUMBERS: NEXT FREE = 129 (do not allocate a new Design; T1 uses Design 125)
```

"No foreign lane" would have been weak evidence anyway. We took a **new
path** the live lanes do not own.

---

## Phase 0.25 — Sweep receipt (gate: required before Phase 1)

| Surface | Evidence ran | Finding | Call |
|---|---|---|---|
| **repo git state** | `git status -sb` on Dropbox baton; `branch_drift_check.sh`; `git worktree list`; `git fetch origin main`; existing WT `gllvmTMB-mspl-fork-B-totoro` ff to `437032ed` | Dropbox baton **4 ahead / 748 behind**, dirty (`dev/isdm-package-recovery/`). Closed L2 **is on `origin/main`**. No T1 kit on main. | **build-the-gap** on this worktree from `origin/main` — do not use the Dropbox baton |
| **closed L2 kit** | `docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/{GOAL,checkpoint,arcs}.md` | STATE **GOAL_MET**. Seed B/C 0.900; near-tail 0.780. NEXT = Totoro blocked. Explicit: *new kit, do not reopen*. | **resume construction, new kit** — do not reopen |
| **L1 / L2 numbers** | official L1 `2026-08-18-mspl-forkB-l1-smoke.md`; official L2 `2026-08-18-mspl-forkB-l2-smoke.md` | L1 cov_eff **0.880** Wilson [0.7620, 0.9438]. L2 B/C **0.900**, near-tail **0.780**. Companion 0.935 is a different harness. | **inherit**; do not mix 0.935 |
| **locked grid** | `docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md` on this branch | Sibling **LOCKED** 4 cells × 200 = 800; seeds `20260830`–`20260833`; RECORD only; no T\* freeze; `far_tail` \(\beta_0=-2.4\) | **absorb as frozen WHAT** |
| **ADEMP T1** | `2026-08-17-mspl-profile-led-prereg-ademp.md` §P5 + §D | T1 = hold-outs declared in advance; Wilson / PASS-FAIL **must be filled before launch** and were **not** filled by the ADEMP sign. G4d froze L\* only. | **declare cells; do not invent a T\* FAIL band** |
| **PRs** | `gh pr view 1162` / `1168` / `1077` | L2 **MERGED**. #1077 still open **draft** (HARD OUT). | cite; do not undraft |
| **twin / sister** | drmTMB / GLLVM.jl not a source for this ADEMP gate | n/a | n/a |
| **brain** | MCP `search_notes` `search_all_projects=true` q=`MSPL-04 coverage L1 0.880 L2 seeds B C 0.900 near-tail 0.780 GOAL_MET` and `MSPL SE CI Totoro 1077 1162 1168` | Semantic hits were stale/unrelated or D-157 fences. Repo docs on `origin/main` are the load-bearing record. | **reuse repo kit + ADEMP + locked grid** |
| **deterministic greps** | `rg -in "MSPL\|fork.?B\|T1\|1162\|1168" ~/shinichi-brain/memory/AGENT_LOG.md` → D-157/D-158/D-159 mentions; `memory/DECISIONS.md` → **D-149 / D-157 / D-159** (MSPL-04 blocked; no Totoro relaunch of Design 118); `memory/OPEN_QUESTIONS.md` → empty; `journal/2026-08-18.md` → Totoro idle note only; `projects/deep-research/README.md` → dr34 LA-MSPL, not Design 125 T1 | Vault holds fences, not T1 numbers | **do not invent a new D-**; fences already signed; this G0 is a *new* Totoro measurement rung, not a B1 relaunch |
| **Verdict** | — | G0 for Totoro T1 is **new**. Construction, L0, L1, L2, and the locked grid **already exist**. | **reuse / inherit / build-the-gap = T1 runner + 800-fit panel + new kit** |

---

## WHAT THE BRAIN ALREADY KNOWS

- **D-157:** B1 PARK; no Totoro *relaunch of Design 118*; later intervals =
  new construction + new pre-reg; MSPL-04 blocked. This sitting is Design
  125 T1 measurement, not a B1 reopen.
- **D-149:** public calibrated intervals stay binary-fenced; SE pins ≠
  public intervals.
- **D-159:** MSPL-interval withhold; fork B is the named construction to
  *measure*, not a coverage claim.
- **G4c SIGNED B:** unpenalized Laplace at fixed MSPL nuisance.
- Closed L2 already told the next session: **new kit, do not reopen**.

## WHAT SHINICHI TOLD US (G0, this sitting)

Unattended G0: next MSPL SE/CI rung after local L2 GOAL_MET (#1162/#1168).
Inherit L1 0.880, L2 seeds B/C 0.900, near-tail 0.780.
HARD OUT: undraft #1077, public se/vcov/confint, MSPL-04→covered, NEWS
covered. ALLOWED: Totoro compute.
Sibling lock: T1 hold-out grid = 800 fits, 4 cells × 200, seeds
`20260830`–`33`, RECORD only, **no T\* freeze**.
Kit-docs PR merge when CI green is **preapproved**. T1 **compute** is for
`/goal`, not this planning sitting.

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Fisher — ADEMP T1 still requires Wilson/PASS-FAIL filled before launch, but G4d froze L* only. Inventing a T* FAIL band from L1's 0.80-upper rule would be too weak at n=200 (still PASSes around p≈0.75). · Recommendation: RECORD only; report unfrozen candidates C-L1 / C-lo80 / C-avail / C-ref. · Default: no FAIL band.
  Rose   — Two L1 numbers exist (official 0.880 vs companion 0.935). Mixing them is the cheapest future lie. Closed L2 kit must not be edited. · Recommendation: headline inherit 0.880 / 0.900 / 0.780; name the companion as out-of-band. · Default: inherit #1128/#1162.
  Gauss  — far_tail is new. Silent reuse of near_tail would rewrite the hold-out. · Recommendation: extend mspl_forkB_l1_dgp() with (−2.4, −2.2, −2.6, −2.3); smoke far_tail first (R-SAT expected to rise). · Default: declare, do not reuse.
  Curie  — 800 fits at 16 cores is ~2–5 min after deploy; deploy dominates (5–15 min). Smoke-first is the real gate. · Recommendation: local 1-rep × 4 then Totoro 1-rep × 4 before the 800. · Default: that order.
  Ada    — New kit under cursor-mspl-fork-B-totoro; this sitting = plan + kit PR only; /goal runs K1–K5 on Totoro.
```

## ADA'S RECOMMENDATION

Ship the kit now with the sibling-locked 800-fit grid absorbed. Execute T1
in a fresh `/goal` on the scratch worktree. Treat T1 as **recorded**, not
branded. Do not freeze T\*.

## DECISIONS LOCKED

- Fork B; Totoro T1; inherit official L1 0.880 and L2 0.900 / 0.780;
  locked 4×200 grid seeds `20260830`–`20260833`; RECORD only; T\*
  NOT-FROZEN; reuse L1 harness + `far_tail` extension; new kit path;
  worktree from `origin/main`; hard OUTs as signed.

## QUESTIONS STILL OPEN

None that block T1 recording. T\* freeze is **not** asked here.

---

## Phase 0.3 / 0.3b — roster + two bars

- **PLATFORM:** Cursor (`session_ownership.sh`).
- **Roster used:** Cursor Models = Grok 4.6 (this sitting) for scout/kit
  write; Other Models = judgment if a later `/goal` needs a coverage-call
  review.
- **Bars:** Settings → Usage **unread this sitting** (no UI access from
  the agent). Route by skill default, do not burn a bar to even meters.
- **Phase 0.5 NotebookLM:** offered, **not run** — no novelty/priority
  claim; ADEMP + L1/L2 receipts + locked grid are the prior art.

---

## SLICE TABLE

| ID | Slice | Member | Model+effort | Bar | Dispatch | Time | Detail | Dep |
|---|---|---|---|---|---|---|---|---|
| R0 | RECON closed L2 + ADEMP T1 + locked grid | Shannon/scout | Grok low | Cursor Models | this sitting | 15m | closed L2 LOOP/; ADEMP §P5; #1128/#1162; grid proposal | — |
| K0 | Write NEW LOOP kit + after-task + check-log prepend + PR | Ada | Grok med | Cursor Models | this sitting | 40m | `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/**` + grid proposal | R0 |
| K1 | Thin T1 runner: four cells + `far_tail` | Curie | Grok med | Cursor Models | `/goal` | 40m | `dev/mspl-forkB-t1-smoke.R`; no L1/L2 rewrite | K0 |
| K2a | Smoke-first local 1-rep × 4 | Curie | Grok low | Cursor Models | `/goal` | 10m | inspect objects past guards | K1 |
| K2b | Totoro BatchMode + deploy + 1-rep × 4 | Curie | Grok med | Hand off | `/goal` | 15m | inspect again on Totoro SHA | K2a |
| K3 | Totoro 800-fit panel, 16 cores | Curie | Grok med | Hand off | `/goal` | 5–25m | seeds 20260830–33; abort if first cell empty | K2b |
| K4 | Official T1 receipt (dual cov + refusal + Wilson + MCSE; candidates unfrozen) | Fisher | Other Models med | Other Models | `/goal` | 20m | `docs/dev-log/research/2026-08-18-mspl-forkB-t1-smoke.md`; `tstar_status: NOT-FROZEN` | K3 |
| K5 | After-task + check-log + receipt PR | Rose | Grok med | Cursor Models | `/goal` | 20m | explicit paths; no `git add -A` | K4 |
| V1 | MECHANICAL-VERIFY fences | Rose/scout | Grok low | Cursor Models | `/goal` | 10m | #1077 draft; MSPL-04 blocked; closed kits untouched; T\* not frozen | K5 |
| Rec | Melissa plan-vs-actual | Melissa | Other Models low | Other Models | `/goal` | 15m | `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-T1.md` | V1 |

SLICES: R0 → K0 (this sitting). `/goal`: K1 → K2a → K2b → K3 → K4 → K5 → V1 → Rec.
PARALLEL: none after K0 (smoke is sequential by design).
FAN-OUT: this sitting = 0 children (kit write).
FAN-OUT BUDGET: checkpoint=`mspl-forkB-T1-kit` · new children=0/6 · scout=R0 inline · build=K0 · ceiling=0
SCOUT SUITABILITY: yes — R0 + V1 are mechanical.
ULTRA EFFORT: no
CONTEXT BRAKE: parent input=unknown · fresh-task trigger=after K0 (hand to `/goal`)
COMPACTIONS: parent=0 · boundary=open for kit; `/goal` starts fresh
LANE RECEIPT: **START A FRESH TASK** after this kit lands · reason=ultra-plan skill: do not execute Totoro smoke in the planning sitting
AUTO-REVIEW: guardian=unknown · action=batch git/gh
D-43 PANEL: milestone=not a public-claim milestone · status=not fired
MODELS: Grok / Cursor Models for scout+kit; Other Models for K4/Rec judgment
ESTIMATE: kit sitting ~1 h; `/goal` T1 ~20–40 min wall including deploy · fits 1 `/goal` session · Totoro
PREFLIGHT: pasted above
REVIEW: Rose (receipt non-vacuous; fences) + Fisher (do not invent T\*) — this sitting
VERIFY: V1 mechanical fences + read T1 receipt object
CONSOLIDATE: kit on `origin/main` via docs PR; `/goal` adds receipt
RECONCILE: Melissa after K5 — required (meaningful close of T1 recording)

---

## Frozen T1 grid (do not renegotiate mid-loop)

| Role | Cell | seed_base | n_rep | Status |
|---|---|---|---|---|
| unused (n,T) in G4d rectangle | `T1-anchor-n40-T8` | `20260830` | 200 | `/goal`; RECORD |
| first n-expansion | `T1-anchor-n160-T8` | `20260831` | 200 | `/goal`; RECORD |
| prevalence × n | `T1-neartail-n80-T8` | `20260832` | 200 | `/goal`; RECORD |
| far-tail hold-out | `T1-fartail-n40-T4` | `20260833` | 200 | `/goal`; RECORD-ONLY |

Estimand: **E1 only**. Tape: **Q_0 / fork B**. Family: Bernoulli logit.
`calibrated = FALSE`. Public doors refused. `tstar_status = NOT-FROZEN`.

T1 verdict language: **RECORDED**. Do not apply L1's 0.80 Wilson rule as a
new freeze. Report candidate rules C-L1 / C-lo80 / C-avail / C-ref as
unfrozen annotations only.

---

## File-ownership fence

| Path | Owner |
|---|---|
| `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/**` | **this kit** |
| `docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md` | **this kit** (locked grid) |
| `dev/mspl-forkB-t1-smoke.R` | `/goal` (K1) |
| `docs/dev-log/research/2026-08-18-mspl-forkB-t1-smoke.md` | `/goal` (K4) |
| `docs/dev-log/after-task/2026-08-18-mspl-forkB-T1*.md` | this kit + `/goal` |
| `docs/dev-log/check-log.md` prepend | this kit + `/goal` (explicit path) |
| `docs/dev-log/lanes/cursor-mspl-fork-B-L2/**` | **frozen GOAL_MET** — nobody |
| `docs/dev-log/lanes/cursor-mspl-fork-B/**` | **frozen GOAL_MET** — nobody |
| repo-root `LOOP/**` | **frozen REPLACE GOAL_MET** — nobody |
| `docs/design/125-*.md` · ADEMP · `decisions.md` | read-only |
| `R/` · `src/` · NEWS · register MSPL-04 · #1077 | **never** |
| `dev/isdm-package-recovery/**` | **never** |

---

## Hard OUT (repeat)

T\* freeze · undraft #1077 · public se/vcov/confint · MSPL-04→covered ·
NEWS covered · reopen L2 / g0_unlock · reopen Design 118/B1 · rebuild
#1090 as a claim · KF2021 beyond binomial · `git add -A` ·
isdm-package-recovery · overwrite root `LOOP/` · Dropbox cloud-agent
baton.
