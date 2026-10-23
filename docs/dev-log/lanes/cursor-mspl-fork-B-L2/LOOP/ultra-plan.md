# Ultra-plan — Design 125 fork B, local L2 only

Frozen at G0 approval (Shinichi AskQuestion, 2026-08-18): **local L2 only**.
Binding detail for `/goal`. Do **not** reopen
`docs/dev-log/lanes/cursor-mspl-fork-B/` (g0_unlock **GOAL_MET**) or repo-root
`LOOP/` (Poisson \(W_*\) REPLACE **GOAL_MET**).

## 🎯 GOAL

```
🎯 GOAL
Solo platform: Cursor (this session; read, not inferred)
Deliverable: L2 recorded locally — multi-seed interior + one near-tail cell; dual coverage + refusal pricing; official receipt. Kit on docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/
HEADLINE: Inherit official L1 cov_eff 0.880; add two new interior seeds + L1-neartail-n40-T4; stop before Totoro
IN PARALLEL: kit docs (this sitting) · later /goal: smoke-first near-tail ∥ smoke-first new interior (then sequential 50-rep panel)
DEFER: Totoro/DRAC · T* freeze · undraft #1077 · public se/vcov/confint · MSPL-04→covered · NEWS covered · reopen g0_unlock · E2 · any family beyond binomial
DISCIPLINE: verify=read LOG + object, never exit code · compute=LOCAL only · closure=L2 receipt recorded, not calibrated
```

LANE TAKEN: **`cursor-mspl-fork-B-L2`** — new kit only. Foreign Claude/Codex lanes
and 11 other Cursor MSPL lanes are live; this session does not claim their files.

ARC PROGRAM: N/A (no Arc Card; `/goal` executes this plan)

---

## Phase 0.2 — Shannon pre-flight

```
VERDICT: FOREIGN LANE ACTIVE (claude codex direct-to-main)
PLATFORM: cursor | ON BRANCH (Dropbox checkout): cursor/cloud-agent-1786753856541-jx2lb (722 behind origin/main — NOT used)
LANE TAKEN: cursor-mspl-fork-B-L2
WORKTREE: ~/local-scratch/lanes/gllvmTMB-mspl-forkB-L2-goal @ origin/main (b6c50d28)
OTHER LANES: 11 Cursor MSPL lanes (including closed g0_unlock + L1) + many Claude/Codex
COORD BOARD: committed to origin/main
DESIGN NUMBERS: NEXT FREE = 128 (do not allocate a new Design; L2 uses Design 125)
```

"No foreign lane" would have been weak evidence anyway. We took a **new path**
the live lanes do not own.

---

## Phase 0.25 — Sweep receipt (gate: required before Phase 1)

| Surface | Evidence ran | Finding | Call |
|---|---|---|---|
| **repo git state** | `git status -sb` on Dropbox checkout; `branch_drift_check.sh`; `git worktree list`; `git branch -a \| rg forkB`; `git fetch origin main`; `git ls-tree origin/main` | Dropbox baton `cursor/cloud-agent-…` **4 ahead / 722 behind** `origin/main`, dirty (`dev/isdm-package-recovery/`, `.worktrees/`). Closed kit **is on `origin/main`**. No L2 kit on main. | **build-the-gap** on a **new** worktree from `origin/main` — do not use the Dropbox baton |
| **closed kit** | `git show origin/main:docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/{GOAL,checkpoint,arcs,decision-queue}.md` | STATE **GOAL_MET**. L0 #1130 `d7f526d4`; L1 #1128 `715326af`. NEXT = L2 needs Shinichi G0. Explicit: *if he signs L2, start a **new** kit*. | **resume construction, new kit** — do not reopen |
| **L1 numbers** | `git show origin/main:docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md` | Official: availability 1.000, refusal 0, cov_eff **0.880**, Wilson [0.7620, 0.9438], 50/0/44, `tape=Q_0`. Companion check-log 0.935 / 400-row is a **different harness**. | **inherit 0.880**; do not mix 0.935 into L2 headline |
| **ADEMP L2** | `git show origin/main:docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §P5 + local DGP | L2 = *multi-seed interior + one near-tail cell; dual coverage + refusal pricing recorded*. No numeric T\*-style band. Harness already has `L1-neartail-n40-T4` role=`L2-hold` and `prevalence="near_tail"`. | **reuse harness**; thin L2 runner |
| **PRs** | `gh pr view 1130` / `1128` | Both **MERGED**. #1077 still open draft (HARD OUT). | cite; do not undraft |
| **twin / sister** | drmTMB / GLLVM.jl not a source for this ADEMP gate | n/a | n/a |
| **brain** | MCP `search_notes` `search_all_projects=true` q=`MSPL fork B L2 … cov_eff 0.880 Design 125` and `cursor-mspl-fork-B LOOP GOAL_MET` | Semantic hits were stale/unrelated (VA, install). Repo docs on `origin/main` are the load-bearing record. | **reuse repo kit + ADEMP**; do not re-derive fork pick |
| **deterministic greps** | `rg -in "fork B\|Design 125\|cov_eff\|g0_unlock" ~/shinichi-brain/memory/AGENT_LOG.md` → empty; `memory/DECISIONS.md` → **D-149 / D-157** (MSPL-04 blocked; no Totoro relaunch); `memory/OPEN_QUESTIONS.md` → empty; `journal/` → no L2 hit; `projects/deep-research/README.md` → no Design 125 research note | Vault holds fences, not L2 numbers | **do not invent a new D-**; fences already signed |
| **Verdict** | — | G0 for L2 is **new**. Construction, L0, L1, and the near-tail DGP **already exist**. | **reuse / inherit / build-the-gap = L2 panel + new kit** |

---

## WHAT THE BRAIN ALREADY KNOWS

- **D-157:** B1 PARK; no Totoro relaunch; later intervals = new construction + new pre-reg; MSPL-04 blocked.
- **D-149:** public calibrated intervals stay binary-fenced; SE pins ≠ public intervals.
- **D-159** (repo `decisions.md` 2026-08-18 + vault renumber): MSPL-interval withhold; fork B is the named construction to *measure*, not a coverage claim.
- **G4c SIGNED B:** unpenalized Laplace at fixed MSPL nuisance; A = ablation; C not picked.
- Closed g0_unlock already told the next session: **new kit, do not reopen**.

## WHAT SHINICHI TOLD US (G0, this sitting)

AskQuestion signed: **local L2 only** — multi-seed + near-tail cell.
HARD OUTs he restated: NO Totoro/DRAC, NO T\* freeze, NO undraft #1077, NO public
se/vcov/confint, NO MSPL-04 → covered, NO NEWS covered, do not reopen closed
g0_unlock, no `git add -A` / isdm-package-recovery, prefer
`~/local-scratch/lanes/` from `origin/main`.
Kit-docs PR merge when CI green is **preapproved**. L2 **compute** is for `/goal`,
not this planning sitting.

## WHAT THE TEAM RAISED

```
TEAM RAISED
  Fisher — ADEMP L2 has no numeric PASS/FAIL band (unlike L1's Wilson-not-entirely-below-0.80). Inventing one here would be a silent T* freeze. · Recommendation: record dual coverage + refusal; compare interior seeds to inherited 0.880 descriptively. · Question: none — G0 already scoped recording. · Default: do not invent a band.
  Rose   — Two L1 numbers exist (official 0.880 vs companion 0.935). Mixing them is the cheapest future lie. · Recommendation: headline 0.880 only; name the companion as out-of-band. · Default: inherit #1128.
  Gauss  — Near-tail cell already exists as L2-hold in mspl-forkB-l1-ademp.R (beta ≈ -1.6). Rebuilding the DGP would rewrite history. · Recommendation: reuse; 1-rep smoke on near-tail first (saturation / R-SAT more likely). · Default: reuse harness.
  Curie  — 150 new 50-rep walks (~4–5 min if L1's 88 s / 50 holds) is local-sane. · Recommendation: seed_bases 20260819/20 interior + 20260821 near-tail; inherit 20260818. · Default: that freeze.
  Ada    — New kit under cursor-mspl-fork-B-L2; this sitting = plan + kit PR only; /goal runs K1–K5.
```

## ADA'S RECOMMENDATION

Ship the kit now. Execute L2 in a fresh `/goal` on the scratch worktree.
Treat L2 as **recorded**, not branded. Stop before Totoro.

## DECISIONS LOCKED

- Fork B; local L2 only; inherit official L1 0.880; reuse L1 harness; new kit path;
  worktree from `origin/main`; hard OUTs as signed.

## QUESTIONS STILL OPEN

None that block L2 recording. Totoro G0 is **not** asked here.

---

## Phase 0.3 / 0.3b — roster + two bars

- **PLATFORM:** Cursor (session_ownership.sh).
- **Roster used:** Cursor Models = Grok 4.6 (this sitting) for scout/kit write;
  Other Models = judgment if a later `/goal` needs a coverage-call review.
- **Bars:** Settings → Usage **unread this sitting** (no UI access from the
  agent). Route by skill default, do not burn a bar to even meters.
- **Phase 0.5 NotebookLM:** offered, **not run** — no novelty/priority claim;
  ADEMP + L1 receipt are the prior art.

---

## SLICE TABLE

| ID | Slice | Member | Model+effort | Bar | Dispatch | Time | Detail | Dep |
|---|---|---|---|---|---|---|---|---|
| R0 | RECON closed kit + ADEMP L2 + L1 receipt | Shannon/scout | Grok low | Cursor Models | this sitting | 15m | closed LOOP/; ADEMP §P5; #1128 receipt; harness `L2-hold` | — |
| K0 | Write NEW LOOP kit + after-task + check-log prepend + PR | Ada | Grok med | Cursor Models | this sitting | 40m | `docs/dev-log/lanes/cursor-mspl-fork-B-L2/**` only | R0 |
| K1 | Thin L2 runner reusing `dev/mspl-forkB-l1-ademp.R` | Curie | Grok med | Cursor Models | `/goal` | 30m | `dev/mspl-forkB-l2-smoke.R`; no L1 rewrite | K0 |
| K2a | Smoke-first 1-rep `L1-neartail-n40-T4` | Curie | Grok low | Cursor Models | `/goal` | 5m | inspect object past guards | K1 |
| K2b | Smoke-first 1-rep interior seed `20260819` | Curie | Grok low | Cursor Models | `/goal` | 5m | parallel with K2a | K1 |
| K3 | Local L2 panel (2×50 interior + 1×50 near-tail) | Curie | Grok med | Cursor Models | `/goal` | 15–25m | seeds 20260819/20 + 20260821; inherit 20260818 | K2a,K2b |
| K4 | Official L2 receipt (dual cov + refusal + Wilson + MCSE) | Fisher | Other Models med | Other Models | `/goal` | 20m | `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`; no calibrated brand | K3 |
| K5 | After-task + check-log + receipt PR | Rose | Grok med | Cursor Models | `/goal` | 20m | explicit paths; no `git add -A` | K4 |
| V1 | MECHANICAL-VERIFY fences | Rose/scout | Grok low | Cursor Models | `/goal` | 10m | #1077 draft; MSPL-04 blocked; closed kit untouched; root LOOP/ untouched | K5 |
| Rec | Melissa plan-vs-actual | Melissa | Other Models low | Other Models | `/goal` | 15m | `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-L2.md` | V1 |

SLICES: R0 → K0 (this sitting). `/goal`: {K2a,K2b} after K1; K3 ← K2\*; then K4→K5→V1→Rec.
PARALLEL: {K2a, K2b}. SEQUENTIAL: K3←K2, K4←K3.
FAN-OUT: this sitting = 0 children (kit write). `/goal` may use 2 scouts then 1 build.
FAN-OUT BUDGET: checkpoint=`mspl-forkB-L2-kit` · new children=0/6 · scout=R0 inline · build=K0 · ceiling=0
SCOUT SUITABILITY: yes — R0 + V1 are mechanical.
ULTRA EFFORT: no
CONTEXT BRAKE: parent input=unknown · fresh-task trigger=after K0 (hand to `/goal`)
COMPACTIONS: parent=0 · boundary=open for kit; `/goal` starts fresh
LANE RECEIPT: **START A FRESH TASK** after this kit lands · reason=ultra-plan skill: do not execute L2 smoke in the planning sitting
AUTO-REVIEW: guardian=unknown · action=batch git/gh
D-43 PANEL: milestone=not a public-claim milestone · status=not fired
MODELS: Grok / Cursor Models for scout+kit; Other Models for K4/Rec judgment
ESTIMATE: kit sitting ~1 h; `/goal` L2 ~1.5–2 h local · fits 1 `/goal` session · no HPC
PREFLIGHT: pasted above
REVIEW: Rose (receipt non-vacuous; fences) + Fisher (do not invent T\*) — this sitting
VERIFY: V1 mechanical fences + read L2 receipt object
CONSOLIDATE: kit on `origin/main` via docs PR; `/goal` adds receipt
RECONCILE: Melissa after K5 — required (meaningful close of L2 recording)

---

## Frozen L2 grid (do not renegotiate mid-loop)

| Role | Cell | seed_base | n_rep | Status |
|---|---|---|---|---|
| Seed A (inherit) | `L1-anchor-n80-T8` | `20260818` | 50 | **official L1** cov_eff 0.880 — cite, do not rerun as new history |
| Seed B (new) | `L1-anchor-n80-T8` | `20260819` | 50 | `/goal` |
| Seed C (new) | `L1-anchor-n80-T8` | `20260820` | 50 | `/goal` |
| Near-tail (one) | `L1-neartail-n40-T4` | `20260821` | 50 | `/goal`; already `L2-hold` in harness |

Estimand: **E1 only**. Tape: **Q_0 / fork B**. Family: Bernoulli logit.
`calibrated = FALSE`. Public doors refused.

L2 verdict language: **RECORDED** (PASS/FAIL only if the harness itself
breaks or refuses to produce typed rows). Do not apply L1's 0.80 Wilson rule
as a new freeze. Interior seeds may be *compared* to 0.880 in prose.

---

## File-ownership fence

| Path | Owner |
|---|---|
| `docs/dev-log/lanes/cursor-mspl-fork-B-L2/**` | **this kit** |
| `dev/mspl-forkB-l2-smoke.R` | `/goal` (K1) |
| `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md` | `/goal` (K4) |
| `docs/dev-log/after-task/2026-08-18-mspl-forkB-L2*.md` | this kit + `/goal` |
| `docs/dev-log/check-log.md` prepend | this kit + `/goal` (explicit path) |
| `docs/dev-log/lanes/cursor-mspl-fork-B/**` | **frozen GOAL_MET** — nobody |
| repo-root `LOOP/**` | **frozen REPLACE GOAL_MET** — nobody |
| `docs/design/125-*.md` · ADEMP · `decisions.md` | read-only |
| `R/` · `src/` · NEWS · register MSPL-04 · #1077 | **never** |
| `dev/isdm-package-recovery/**` | **never** |

---

## Hard OUT (repeat)

Totoro · T\* · undraft #1077 · public se/vcov/confint · MSPL-04→covered ·
NEWS covered · reopen g0_unlock · reopen Design 118/B1 · rebuild #1090 as a
claim · KF2021 beyond binomial · `git add -A` · isdm-package-recovery ·
overwrite root `LOOP/` · Dropbox cloud-agent baton.
