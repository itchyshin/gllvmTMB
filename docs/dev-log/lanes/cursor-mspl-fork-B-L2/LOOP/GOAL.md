# GOAL — Design 125 fork B, local L2 only (IMMUTABLE for this run)

**Re-read this file at the top of EVERY arc, before anything else.** Chat history is disposable;
this file and `checkpoint.md` are the truth.

## Mission

Record **ADEMP / Design 125 gate L2** for fork B (unpenalized Laplace at fixed
MSPL nuisance): **multi-seed interior + one near-tail cell**, with dual coverage
and refusal pricing, on **local compute only**. Stop after the L2 receipt. Do
not escalate to Totoro. Do not reopen the closed g0_unlock kit.

This `/goal` **owns** the L2 runner, the L2 receipt, and this kit. Reuse
`dev/mspl-forkB-l1-ademp.R` (the near-tail cell is already `L2-hold`). Do not
edit `R/`, `src/`, Design 125 body, `decisions.md`, or
`docs/dev-log/lanes/cursor-mspl-fork-B/**`.

## Headline

An honest L2 receipt: dual coverage (\(\widehat{\mathrm{cov}}_{\mathrm{ret}}\) and
\(\widehat{\mathrm{cov}}_{\mathrm{eff}}\)) + refusal pricing + Wilson + MCSE on
(a) new independent interior seeds of `L1-anchor-n80-T8` and (b) one near-tail
cell `L1-neartail-n40-T4`. Official L1 cov_eff **0.880** is **inherited**, not
re-run as new history.

## Authoritative WHAT

`LOOP/ultra-plan.md` (frozen at approval).
Upstream: ADEMP §P5 L2 (`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`) ·
Design 125 · official L1 `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md`
via [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) · L0
[#1130](https://github.com/itchyshin/gllvmTMB/pull/1130).

## Invariants (never violate, even to finish faster)

1. **One new lane.** Write only paths in `ultra-plan.md` §File-ownership fence.
   Closed g0_unlock at `docs/dev-log/lanes/cursor-mspl-fork-B/` is **GOAL_MET** —
   cite it, do not edit it. Repo-root `LOOP/` is the closed Poisson \(W_*\)
   REPLACE record — never overwrite it. Bleed-through is the thing that must
   not happen (D-88).
2. **Inherit L1 numbers.** Official L1 is cov_eff **0.880**, Wilson [0.7620, 0.9438],
   50/0/44, `tape=Q_0`, seed_base `20260818`, cell `L1-anchor-n80-T8`. Do not
   rewrite that receipt. Do not mix it with the companion 0.935 / 400-row walk.
3. **Verification is reading the LOG and the returned OBJECT** — never an exit
   code. Confirm the loaded namespace matches the checkout (`origin/main` +
   this branch) before believing any fit.
4. **Smoke before scale.** One replicate on the near-tail cell and one on a
   new interior seed, non-empty / non-NA / in-range, one fit inspected past
   its guards — *then* the 50-rep panel. Abort the moment the first cell is
   empty or broken.
5. **Compute is LOCAL.** Totoro and DRAC need their own G0 (D-50 / D-139 / D-157).
   Not this lane.
6. **Fail closed.** A refusal prices into effective coverage as non-coverage.
   Never substitute an uncalibrated Wald interval for an unavailable profile.
7. **L2 is a recording gate.** ADEMP L2 does **not** freeze a new numeric
   PASS/FAIL band (G4d froze L\* only; T\* stays open). Record dual coverage
   + refusal pricing. Do not invent a T\* threshold. Do not brand the receipt
   `calibrated` or `covered`.
8. **Never merge or publish from the `/goal` execute chat** unless a later
   human gate says so. This kit-docs PR is the exception already G0-preapproved.
9. **A surprise that invalidates the plan sends you back to G0**, not into a
   mid-loop patch.
10. **Close every arc honestly** — record what it did *not* cover.

## Out of scope — the fence (do NOT drift here)

- Totoro / DRAC; T1/T2; freezing T\* thresholds
- Undrafting [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077)
- Public `se = TRUE`, `vcov()`, `confint()` — `.gllvmTMB_mspl_assert_inference` stays
- Flipping register row **MSPL-04** off `blocked`; any NEWS / README / article `covered` claim
- Reopening the closed g0_unlock kit or repo-root `LOOP/`
- Reopening Design 118, B1, or Arc 1A (D-157)
- Any family beyond **binomial** (logit / probit / cloglog), any structure beyond
  `latent(d = 1, unique = FALSE)`, any estimand beyond **E1** (E2 stays
  NOT-EVALUABLE on the current `b_fix` probe)
- Re-picking the fork — **B is signed**; A is ablation only
- `git add -A`; `dev/isdm-package-recovery/**`; Dropbox cloud-agent baton

## Definition of done

- [x] **K0 — this sitting:** kit exists under `docs/dev-log/lanes/cursor-mspl-fork-B-L2/`
      on a branch from `origin/main` (docs PR; merge when CI green)
- [ ] **K1 — L2 runner:** thin `dev/mspl-forkB-l2-smoke.R` reuses
      `dev/mspl-forkB-l1-ademp.R`; does not rewrite L1 history
- [ ] **K2 — smoke-first:** 1-rep near-tail + 1-rep new interior seed inspected
- [ ] **K3 — L2 panel (local):**
      - inherit seed `20260818` / `L1-anchor-n80-T8` as **Seed A** (cov_eff 0.880)
      - new seed_bases `20260819` and `20260820` on the same interior cell, \(n_{\mathrm{rep}}=50\)
      - one near-tail cell `L1-neartail-n40-T4`, seed_base `20260821`, \(n_{\mathrm{rep}}=50\)
- [ ] **K4 — official receipt:** dual coverage + refusal pricing + Wilson + MCSE;
      `calibrated: FALSE`; `public_confint: refused`; `coverage_claim: none`
- [ ] **K5 — after-task + check-log + receipt PR**
- [ ] **Reconcile:** Melissa plan-vs-actual; checkpoint NEXT = Totoro (blocked)

Campaign-level done is **L2 recorded**, not Totoro admitted.
