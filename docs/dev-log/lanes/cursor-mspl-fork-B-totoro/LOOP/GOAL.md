# GOAL — Design 125 fork B, DRAC T1 (IMMUTABLE for this run)

**Re-read this file at the top of EVERY arc, before anything else.** Chat history is disposable;
this file and `checkpoint.md` are the truth.

## Mission

Run **ADEMP / Design 125 gate T1** for fork B (unpenalized Laplace at fixed
MSPL nuisance) on the **DRAC fleet** (Fir / Nibi / Rorqual, optional Narval):
the **locked** four-cell hold-out grid (800 fits) as **SLURM job arrays**,
dual coverage and refusal pricing, **RECORD only**. Smoke-first (local
1-rep × 4, then Totoro or one-cluster 1-rep) **before** the full 800.
Stop after the T1 receipt. Do **not** freeze T\*. Do not open public
interval doors.

This `/goal` **owns** the T1 runner, DRAC `sbatch` deploy, the T1 receipt,
and this kit. Totoro is **smoke / fallback only**. Reuse
`dev/mspl-forkB-l1-ademp.R`. Do not edit `R/`, `src/`, Design 125 body,
ADEMP body, `decisions.md`,
`docs/dev-log/lanes/cursor-mspl-fork-B-L2/**`, or
`docs/dev-log/lanes/cursor-mspl-fork-B/**`.

## Headline

An honest T1 receipt from **DRAC arrays**: locked 800-fit hold-out +
RECORD-only candidates + dual coverage + refusal pricing + Wilson + MCSE.
Inherit L1 0.880 and L2 0.900 / 0.780. `calibrated: FALSE`.
`public_confint: refused`. `tstar_status: NOT-FROZEN`.

## Authoritative WHAT

`LOOP/ultra-plan.md` (frozen at approval).
Locked grid:
`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`
(pointer `LOOP/grid-proposal.md`).
Upstream: ADEMP §P5 T1 · Design 125 · official L1
[#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) · official L2
[#1162](https://github.com/itchyshin/gllvmTMB/pull/1162) /
GOAL_MET [#1168](https://github.com/itchyshin/gllvmTMB/pull/1168).

## Locked T1 grid (do not renegotiate)

Four new hold-out cells. One independent seed each. \(n_{\mathrm{rep}}=200\).
**800 fits.** None of these cells was an L1/L2 coverage cell. Every cell is
**RECORD** (far-tail **RECORD-ONLY**). No T\* FAIL band.

| cell_id | n | T | prevalence | seed_base | n_rep | rule |
|---|---:|---:|---|---:|---:|---|
| `T1-anchor-n40-T8` | 40 | 8 | `anchor` | 20260830 | 200 | RECORD |
| `T1-anchor-n160-T8` | 160 | 8 | `anchor` | 20260831 | 200 | RECORD |
| `T1-neartail-n80-T8` | 80 | 8 | `near_tail` | 20260832 | 200 | RECORD |
| `T1-fartail-n40-T4` | 40 | 4 | `far_tail` (\(\beta_0=-2.4\)) | 20260833 | 200 | RECORD-ONLY |

`far_tail` intercepts are declared as \((-2.4,-2.2,-2.6,-2.3)\). The T1
runner must extend the L1 DGP; do not silently reuse `near_tail`.
Optional confirm `T1-confirm-n80-T8` / seed `20260834` is **out** of the
primary 800.

## Invariants (never violate, even to finish faster)

1. **One new lane.** Write only paths in `ultra-plan.md` §File-ownership fence.
   Closed L2 at `docs/dev-log/lanes/cursor-mspl-fork-B-L2/` is **GOAL_MET** —
   cite it, do not edit it. Closed g0_unlock and repo-root `LOOP/` are
   **GOAL_MET**. Bleed-through is the thing that must not happen (D-88).
2. **Inherit L1 / L2 numbers.** Official L1 cov_eff **0.880** (seed
   `20260818`). Official L2 Seed B/C **0.900**, near-tail **0.780**. Do not
   rewrite those receipts. Do not mix the companion 0.935 / 400-row walk.
   Do not re-walk seeds `20260818`–`20260821` as new T1 history.
3. **Verification is reading the LOG and the returned OBJECT** — never an
   exit code. Confirm the loaded namespace matches the checkout
   (`origin/main` + this branch) and the Totoro deploy SHA before believing
   any fit.
4. **Smoke before scale.** Local 1-rep on **each of the four** T1 cells, then
   Totoro SSH + deploy + 1-rep × 4, inspect objects past guards — *then*
   the 800-fit panel. Abort the moment the first cell is empty or broken.
5. **Compute is Totoro.** Host `totoro.biology.ualberta.ca`. Cap **16 cores**
   (shared lab box). `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`. DRAC is
   fallback only if Totoro is unreachable after the BatchMode smoke. Not
   GitHub Actions (D-50).
6. **Fail closed.** A refusal prices into effective coverage as non-coverage.
   Never substitute an uncalibrated Wald interval for an unavailable profile.
7. **T1 is RECORD only. T\* is NOT frozen.** Report dual coverage + Wilson +
   MCSE + refusal-by-reason. Record *unfrozen* candidate rules C-L1 / C-lo80 /
   C-avail / C-ref as described in the locked grid. Do **not** apply a FAIL
   band. Do not brand `calibrated` or `covered`. Far-tail and the near-tail
   hold-out stay RECORD-ONLY for every candidate (L2 near-tail 0.780 would
   silently fail a copied 0.80 band).
8. **Never merge or publish from the `/goal` execute chat** unless a later
   human gate says so. This kit-docs PR is the exception already G0-preapproved.
9. **A surprise that invalidates the plan sends you back to G0**, not into a
   mid-loop patch.
10. **Close every arc honestly** — record what it did *not* cover.

## Out of scope — the fence (do NOT drift here)

- Undrafting [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077)
- Public `se = TRUE`, `vcov()`, `confint()` — `.gllvmTMB_mspl_assert_inference` stays
- Flipping register row **MSPL-04** off `blocked`; any NEWS / README / article `covered` claim
- Freezing T\* or branding this grid `calibrated`
- Reopening the closed L2 kit, g0_unlock kit, or repo-root `LOOP/`
- Reopening Design 118, B1, or Arc 1A (D-157)
- Any family beyond **binomial logit** (probit / cloglog are a later arm)
- Any structure beyond `latent(d = 1, unique = FALSE)`
- Any estimand beyond **E1** (E2 stays NOT-EVALUABLE on the current `b_fix` probe)
- Re-picking the fork — **B is signed**; A is ablation only
- \(n\to 2000\) “fix” of Design 118; Design 118 H1∪H2∪H3 reuse
- `git add -A`; `dev/isdm-package-recovery/**`; Dropbox cloud-agent baton

## Definition of done

- [ ] **K0 — this sitting:** kit exists under `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/`
      on a branch from `origin/main` (docs PR; merge when CI green)
- [ ] **K1 — T1 runner:** thin `dev/mspl-forkB-t1-smoke.R` reuses
      `dev/mspl-forkB-l1-ademp.R`; adds the four locked `T1-*` cells and
      `far_tail`; does not rewrite L1/L2
- [ ] **K2 — smoke-first:** local 1-rep × 4 inspected; then Totoro BatchMode
      + deploy + 1-rep × 4 inspected
- [ ] **K3 — T1 panel (Totoro):** locked 800-fit grid; seeds `20260830`–
      `20260833`; L1/L2 seeds not re-walked
- [ ] **K4 — official receipt:** dual coverage + refusal pricing + Wilson +
      MCSE; candidate rules recorded unfrozen;
      `calibrated: FALSE`; `public_confint: refused`;
      `coverage_claim: none`; `tstar_status: NOT-FROZEN`
- [ ] **K5 — after-task + check-log + receipt PR**
- [ ] **Reconcile:** Melissa plan-vs-actual

Campaign-level done is **T1 recorded against the locked 800-fit grid**,
not T\* frozen, not MSPL-04 promoted, and not #1077 undrafted.
