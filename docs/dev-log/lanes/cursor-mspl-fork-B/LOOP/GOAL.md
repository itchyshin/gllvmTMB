# GOAL — Design 125 fork B, G0-unlock (IMMUTABLE for this run)

**Re-read this file at the top of EVERY arc, before anything else.** Chat history is disposable;
this file and `checkpoint.md` are the truth.

## Mission

Carry **Design 125 fork B** — profile the *unpenalized* Laplace objective
(`fit$mspl$unpenalized_tmb_obj`, `estimator_id = 2`) at **fixed** MSPL nuisance coordinates — from
the SIGNED 2026-08-18 G0 across the pre-registration's gate **L0** (plumbing) and gate **L1** (small
local coverage smoke), and **stop at L2**. Leave an auditable receipt trail for each verdict,
whether it reads PASS or FAIL.

This `/goal` is the **conductor**. Implement L0 in
`cursor/mspl-forkB-l0-20260818` and L1 in `cursor/mspl-forkB-l1-smoke-20260818`.
Do not edit `R/`, `src/`, or `tests/` from this worktree.

## Headline

The **L1 receipt**: conditional coverage, refusal rate by code, and priced effective coverage
\(\widehat{\mathrm{cov}}_{\mathrm{eff}} = (1-\widehat r)\,\widehat{\mathrm{cov}}_{\mathrm{ret}}\)
on the frozen anchor cell, with Wilson intervals and MCSE on both. An honest FAIL is a successful
run of this lane.

## Authoritative WHAT

`LOOP/ultra-plan.md` (frozen at approval) — arcs, slice table, file-ownership contract.
Upstream authority: `docs/dev-log/decisions.md` (2026-08-18 G0) ·
`docs/design/125-mspl-profile-led-intervals.md` ·
`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §P1–P5.

## Invariants (never violate, even to finish faster)

1. **One lane, docs only.** Write only the paths in `ultra-plan.md` §File-ownership fence. This kit
   owns `docs/dev-log/lanes/cursor-mspl-fork-B/**` plus its after-task and a check-log prepend —
   nothing else. `R/` belongs to `cursor/mspl-forkB-l0-20260818`; the L1 smoke to
   `cursor/mspl-forkB-l1-smoke-20260818`; Design 125, the ADEMP pre-reg and `decisions.md` to
   `cursor/mspl-forkB-decision`. Repo-root `LOOP/` is the **closed** Poisson \(W_*\) REPLACE
   `GOAL_MET` record (#1124) — frozen, owned by nobody, never overwritten. Bleed-through is the
   thing that must not happen (D-88).
2. **Verification is reading the LOG and the returned OBJECT** — never an exit code, never a green
   tick. Confirm the loaded namespace matches the checkout before believing any fit.
3. **Smoke before scale.** One cell, three reps, non-empty and non-NA and in-range, one fit
   inspected past its guards — *then* the grid. Read the first cell's output early and abort the
   moment it is empty or broken.
4. **Compute is LOCAL.** Totoro and DRAC need their own G0 (D-50 / D-139 / D-157). Not this lane.
5. **Fail closed.** A refusal prices into effective coverage as non-coverage. Never substitute an
   uncalibrated Wald interval for an unavailable profile.
6. **Never push, merge, or publish.** Those are human gates; settings deny them deliberately. Do not
   work around it — surface instead.
7. **A surprise that invalidates the plan sends you back to G0**, not into a mid-loop patch.
8. **Close every arc honestly** — record what it did *not* cover.

## Out of scope — the fence (do NOT drift here)

- **L2 and every gate above it**; all Totoro/DRAC compute; freezing T\* thresholds
- Undrafting [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077)
- Public `se = TRUE`, `vcov()`, `confint()` on an MSPL fit — `.gllvmTMB_mspl_assert_inference` stays
- Flipping register row **MSPL-04** off `blocked`; any NEWS / README / article `covered` claim
- Reopening Design 118, B1, or Arc 1A (parked under D-157)
- Any family beyond **binomial** (logit / probit / cloglog), any structure beyond
  `latent(d = 1, unique = FALSE)`, any estimand beyond **E1** (intercept) and **E2** (loading)
- Extending the Kosmidis & Firth (2021) caveat beyond binomial responses
- Re-picking the fork — **B is signed**; A survives as the ablation arm only
- `git add -A`

## Definition of done

**Campaign-level** — this kit *tracks* the sibling-owned rows and does not claim them. The owner
lane is named on each line; only the last two are this lane's to finish.

- [ ] **A1/A2 — fork B recorded** against Design 125 + the ADEMP pre-reg as an amendment, and the
      2026-08-18 G0 landed in `decisions.md`  · `cursor/mspl-forkB-decision`
- [ ] **A4 — L0 verdict recorded**: both `objective` arms return typed success/refuse on a toy
      binomial MSPL fit; fork A default proven byte-identical to prior behaviour; unexported,
      `calibrated = FALSE`, public door still refused  · `cursor/mspl-forkB-l0-20260818`
- [ ] **A5 — L1 verdict recorded**: grid frozen from the pre-reg verbatim with fresh seeds; smoke
      run **locally**, smoke-first, first cell inspected early; scored with dual reporting + Wilson
      + MCSE + availability + usability floor; verdict stated against the frozen rule
      (`cov_eff` Wilson not entirely below 0.80, availability ≥0.90, refusal ≤0.15) — PASS **or**
      FAIL, plainly  · `cursor/mspl-forkB-l1-smoke-20260818`
- [x] **A0 — this lane:** the kit exists in a ref under `docs/dev-log/lanes/cursor-mspl-fork-B/`
- [ ] **A6 — this lane:** after-task + check-log landed and docs PR
      [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) **opened** (merge stays a human gate)
- [ ] **Reconcile (after A5):** `checkpoint.md` names the next open gate as **L2 — needs Shinichi
      G0**, and Melissa's plan-vs-actual lands at
      `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-g0-unlock.md`
