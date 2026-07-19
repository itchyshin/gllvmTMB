# Session Handoff — Profile-route coverage CERTIFICATION (v2): 10/11 slices DONE, the arc is one 8h Bartlett run from close

**Meta:** 2026-07-18 · from Claude (Opus 4.8, ultracode) · TARGET = Claude or Codex (platform-agnostic; the finish is live-R aggregate + a review panel) · branch `claude/profile-coverage-remeasure-20260718` (off `claude/release-0.5.0`). **Executable plan:** `~/.claude/plans/memoized-gliding-dongarra.md` (v2, CORRECTED). **After-task DRAFT (2 blanks pending B3):** `scratchpad/after-task-DRAFT.md`.

## Critical Context (read or you will re-run finished work / re-import a disproven claim)
1. **The MEASUREMENT is done; only the Bartlett re-score (B3) is open.** Do NOT re-run A1–A3/PF-5, the REML test, or the binomial diagnostic — all complete. The ONE open question: **does the opt-in Bartlett correction lift gaussian n≥150 from 0.9455–0.9474 to a clean ≥0.95?** B3b is running on Totoro, **~8h ETA** (well-powered `b̂` = 20×500 refits/cell × n_sim=4000 fix-and-refit, load-290 node).
2. **Binomial is SETTLED = FENCE for 0.6** (adversarially corroborated, C1). Mechanism = a weakly-identified ΛΛ'-vs-total-variance **identifiability ridge** (single-trial Bernoulli can't separate Ψ from the fixed probit residual r=1). NOT the two-lever floor (disproven, PF-5). Bartlett is **powerless** for binomial (can't re-center a mislocated point). Fix = pin Ψ=0 for single-trial binomial = 1.0 Discussion-Checkpoint.
3. **`truth_psi` is a harness bug** (logs the raw pre-zeroing Gamma draw, not enforced-0 `psi_effective`) — `est_psi≈0` is CORRECT; the certificate target `truth_diag_sigma` is UNAFFECTED. (Follow-up: rewire the emission column.)
4. **Bartlett is a RESEARCH re-scoring instrument, NOT a shipped confint() feature** (Efron blocked the shipped framing: per-fit `b̂` under-powered ~100× at n=50). The R/ change is opt-in + byte-identical default. **The Bartlett R/ change is UNCOMMITTED in a worktree** (see Landing State).
5. **Multi-lane repo:** this is the COVERAGE lane. Lane C (multinomial, `R/extract-sigma.R`) and the cross-family lane (`~/gtmb_work`) are OFF-LIMITS. This lane's only R/ file is `R/profile-ci.R`.

## What Was Accomplished (this session, 10/11 slices)
- **S1:** committed the profile-route lane (`101f869d`) — profile→`coverage_certificate` wire, PF-3 guard, nbinom2 fenced, rho target. `results/profile-pilot-*` gitignored.
- **A (baseline):** pooled fresh-seed ~10k reps → gaussian n150 **d1 0.9474 / d2 0.9455, rep-clustered MCSE 0.0011** — borderline, clears 0.94 IUT bar, ~0.3–0.5pp under 0.95.
- **B1 + B1v (Bartlett):** opt-in `crit·(1+b/n)` in `.qchisq_threshold` (`R/profile-ci.R`), `b̂=n·(W_mean−1)` on W=2ΔL, pooled/independent-seed/boundary-excluded; `n=fit$n_sites`. **B1v adversarial panel SOUND (3 lenses, 0 blockers); heavy tests pass** (#12 byte-identical default, #13 widening-brackets). Path VALIDATED on Totoro: `b̂=7.368, W_mean=1.049` (~4.9% crit widening).
- **B2 (REML n=50):** ML 0.9437 (est/truth 0.985) → **REML 0.9488 (est/truth 1.005)** — closes ~½ the n=50 shortfall + removes the finite-cluster bias. Confirms the ML-VC-bias hypothesis.
- **C1 (binomial):** FENCE + named ridge mechanism (above).
- **C2 (truth_psi):** harness bug (above).
- **S4 (corr):** DIAGNOSTIC only; gaussian corr under-covers even where diag certifies (own arc). Moves no register row.

## Current Working State
- **Working / DONE:** S1, A, B1, B1v, B2, C1, C2, S4. After-task DRAFT written. D-43 panel Workflow + register-update plan staged.
- **In progress:** **B3b** — two detached Totoro campaigns (main gaussian d{1,2}×n{50,150}×σ{0.2,0.5} n_sim=4000 `--bartlett`; anchor n=400 σ=0.5 via `dev/run-bartlett-anchor-n400.R`). Alive, 0 errors, ~8h/~15h ETA. Poll+aggregate commands in `scratchpad/B3-bartlett-rescore.md` §5.
- **Not done / blocked on B3b:** P (D-43 panel), R (register + widget + CLAUDE.md pointer + handover finalize), M (Melissa reconcile).

## Key Decisions & Rationale
- **Bartlett = research instrument, opt-in, n≥150 target; n=50 → REML** (Efron plan-review; per-fit b̂ under-powered at small n). Making the crit the package DEFAULT = a SEPARATE later decision.
- **Binomial FENCED, mechanism = identifiability ridge, NOT two-lever** (C1 ×2 lenses + PF-5). Do not build Phase-B AGHQ/Cox–Reid on the unconfirmed two-lever route.
- **Curie B3b deviations (adaptive, for Melissa):** (1) `-P 32` not `-P 80` (per-task Bartlett cache would rerun the ~3–4 CPU-hr b-estimate per task → -P 80 wastes ~240–320 CPU-hr); (2) standalone n=400 runner (grid hardcodes NS=c(50,150)).
- **DISCIPLINE:** D-43 default NOT-DONE; panel sees RAW tables; ≥2 NOT-DONE withholds; no "certified/earned" next to a number pre-panel; compute LOCAL (D-50).

## Landing State (git ledger)
| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `gllvmTMB` `claude/profile-coverage-remeasure-20260718` @ `101f869d` (S1 profile-route wire + docs) | **y** | n | none | **LANDED (local; branch accumulates for 0.6)** |
| Bartlett R/ change — worktree `.claude/worktrees/agent-a1b37d9e4b149949e` (`R/profile-ci.R`, `R/profile-derived.R`, `dev/profile-pilot-run.R`, `dev/bartlett-b-estimator.R` [untracked], `tests/testthat/test-profile-ci.R`) | **n** | n | none | **CARRIED-OVER** — B1v SOUND + heavy tests pass; opt-in/byte-identical; commit is the maintainer's call + gated on B3 verdict. Merge the worktree branch to land. |
| B3b Bartlett campaign (Totoro `~/gllvm_work`, LOCAL) | n/a | n | none | **CARRIED-OVER** — running, ~8h; results LOCAL (D-50), never committed. Poll/aggregate per `scratchpad/B3-bartlett-rescore.md` §5. |
| P / R / M (panel, register, reconcile) | n | n | none | **NOT DONE** — gated on B3b coverage. |

**Never-commit:** `.claude/`, tier2a drafts, `docs/dev-log/check-log.md` (entangled tier2 append), `results/profile-pilot-*` (gitignored).

## Next Immediate Steps (ordered)
1. **Poll B3b to completion** (commands in `scratchpad/B3-bartlett-rescore.md` §5; short no-sleep ssh). When done-markers land, **aggregate** → per-cell **Bartlett-corrected `profile_total` coverage + rep-clustered MCSE + b̂ + boundary_hit_fraction + exclusion rate + IUT earn** (vs 0.95 AND 0.94), vs the uncorrected baseline (d1 0.9474 / d2 0.9455); + the n=400 anchor trend.
2. **Run P (D-43 panel)** — the staged Workflow (W-P in the plan): 4 lenses (Rose/Fisher/Efron/Gelman), RAW tables only, default NOT-DONE, IUT, ≥2 NOT-DONE ⇒ WITHHELD. Separate verdicts: gaussian-earned cells vs binomial-fenced.
3. **R (Rose closeout):** finalize `after-task-DRAFT.md` → `docs/dev-log/after-task/`; register CI-08/CI-10/CI-11 (promote ONLY panel-earned; disambiguate M3.3-bootstrap-era vs Design-73 numbers; binomial fenced w/ C1 mechanism; corr moves no row); capability widget/Mission Control; CLAUDE.md top pointer; clean profile-lane check-log entry (NOT tier2a). Decide with the maintainer whether to COMMIT the Bartlett worktree.
4. **M (Melissa reconcile):** plan-vs-actual six axes; record the two Curie deviations as ADAPTIVE; `docs/dev-log/plan-actual/`.

## Blockers / Open Questions
- **B3b ~8h** (Totoro load 290, shared). The corrected coverage table is the sole gate on P/R/M.
- **Does 4.9% crit widening (b̂=7.368) close ~0.4pp?** Unknown until B3b — the whole certificate verdict.
- **Commit the Bartlett R/ change?** Maintainer's call (Discussion-Checkpoint; opt-in/byte-identical so low-risk, but gate on the B3 verdict).

## Gotchas & Failed Approaches (do not retry)
- **The prior B3 (Curie) STALLED 3 ways** — a `while true` monitor stuck on a `task{}.log` filename bug (the `{}` never expanded); a bare `nohup … &` over non-interactive ssh **died on channel close** (use `setsid … < /dev/null`); and `--bartlett` silently not firing (no `[bartlett-b]` line). B3b fixed all three; keep the fixes.
- **`--ns=400` does NOT work** — the grid hardcodes `NS<-c(50L,150L)`; `--ns=` only subsets. Use `dev/run-bartlett-anchor-n400.R`.
- **Bartlett cache is per-xargs-task keyed by cell** → do NOT split a cell across many `-P` tasks (redundant ~3–4 CPU-hr b-estimate each). Use few chunks/cell.
- **DRAC is NOT headless-reachable** (Duo MFA per login; no live socket) — Totoro suffices (384 cores, key-auth, no MFA). Don't route to DRAC without a live socket.
- **Totoro connectivity:** a `~/.ssh/cm-*totoro*` glob returning nomatch does NOT mean down — a direct `ssh -o BatchMode=yes totoro '…'` works and self-creates the socket. Don't declare it unreachable from a socket-file probe.

## How to Resume
1. **One-command resume (paste in an authenticated terminal at repo root):**
   ```
   claude "Rehydrate from docs/dev-log/handover/2026-07-18-claude-handover-profile-cert-v2.md + the plan ~/.claude/plans/memoized-gliding-dongarra.md. The ONLY open slice is B3b (Bartlett gaussian re-score on Totoro ~/gllvm_work, ~8h). Poll+aggregate per scratchpad/B3-bartlett-rescore.md §5; then run the D-43 panel (W-P) on the RAW corrected-vs-uncorrected table; then Rose closeout (register/after-task/widget/CLAUDE.md pointer) + Melissa reconcile. Everything else is DONE — do NOT re-run. Binomial FENCED, truth_psi bug, REML confirms n=50; no 'certified' word pre-panel."
   ```
2. **Read order:** this doc → the plan (`memoized-gliding-dongarra.md`, esp. "B3 STATUS" + "Plan-review OUTCOME" + the W-P Workflow sketch) → `scratchpad/{after-task-DRAFT.md, B3-bartlett-rescore.md, C1-fisher-identifiability.md, C1-gelman-boundary.md, C2-truthpsi-audit.md, coverage-reconciled.md}`.
3. Spawn Rose (claims lens) + the D-43 panel before ANY coverage claim/register flip; D-43 default NOT-DONE.

## Mission-control summary
| slice | status | key number |
|---|---|---|
| S1 wire · A baseline | ✅ | gaussian n150 = 0.9474 / 0.9455 (MCSE 0.0011) |
| B1 Bartlett build + B1v verify | ✅ | SOUND; heavy tests pass; b̂=7.368 validated (~4.9% widen) |
| B2 REML n=50 | ✅ | 0.9437 → 0.9488 (bias 0.985→1.005) |
| C1 binomial · C2 truth_psi · S4 corr | ✅ | FENCE (ridge) · harness bug · diagnostic |
| **B3 Bartlett re-score** | 🔄 ~8h | **does n≥150 reach ≥0.95? — the whole verdict** |
| P panel → R register/close → M reconcile | ⏳ | gated on B3 |
