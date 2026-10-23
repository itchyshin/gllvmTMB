# GOAL — Design 125 fork B, DRAC confirm panel (IMMUTABLE for this run)

**Re-read this file at the top of EVERY arc, before anything else.** Chat history is disposable;
this file and `checkpoint.md` are the truth.

## Mission

Run the **post-T1 DRAC confirm panel** for fork B (unpenalized Laplace at fixed
MSPL nuisance): **~800 fits** as **SLURM job arrays** on **Fir / Nibi / Rorqual**
(optional Narval), dual coverage and refusal pricing, **RECORD only**. Smoke-first
(local 1-rep, then one-cluster 1-rep) **before** the full panel. Stop after the
confirm receipt. Do **not** freeze T\* unless Shinichi signs after reading
`docs/dev-log/research/2026-08-19-mspl-forkB-tstar-discussion-packet.md`.
Do not open public interval doors.

This `/goal` **owns** the DRAC runner, `sbatch` deploy, the confirm receipt, and
this kit. **Totoro is smoke / fallback only.** Reuse `dev/mspl-forkB-t1-smoke.R`
and `dev/mspl-forkB-l1-ademp.R`. Do not edit `R/`, `src/`, Design 125 body,
ADEMP body, `decisions.md`, closed T1 / L2 / g0_unlock kits, or repo-root `LOOP/`.

## Headline

An honest **confirm receipt from DRAC arrays**: L1-scale confirm cell +
multi-seed \(n=160\) anchor expansion; dual coverage + refusal pricing + Wilson +
MCSE. Inherit T1 anchors 0.940 / 0.975 and L1/L2 official numbers.
`calibrated: FALSE`. `public_confint: refused`. `tstar_status: NOT-FROZEN`
unless a **separate signed G0** follows the discussion packet.

## Authoritative WHAT

`LOOP/ultra-plan.md` (frozen at approval).
Locked grid: `LOOP/grid-proposal.md` (pointer to research note).
Upstream: T1 receipt [#1173](https://github.com/itchyshin/gllvmTMB/pull/1173) ·
T\* packet `docs/dev-log/research/2026-08-19-mspl-forkB-tstar-discussion-packet.md` ·
official L1 [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) ·
official L2 [#1162](https://github.com/itchyshin/gllvmTMB/pull/1162).

## Locked confirm grid (do not renegotiate)

**800 fits total.** None of these cells re-walks T1 seeds `20260830`–`20260833`.
T1 primary 800 is **done** — do not repeat it.

| cell_id | n | T | prevalence | seed_base(s) | n_rep | rule | fits |
|---|---:|---:|---|---|---:|---|---:|
| `T1-confirm-n80-T8` | 80 | 8 | `anchor` | 20260834 | 200 | RECORD | 200 |
| `T1-anchor-n160-T8` | 160 | 8 | `anchor` | 20260831, 20260835, 20260836 | 200 each | RECORD | 600 |

**Why these two blocks**

- **Confirm** — same DGP as official L1 cell at \(n=200\); checks scale, not
  a new \((n,T,\pi)\) corner (declared optional in T1 grid proposal).
- **Multi-seed n160** — T1 showed 0.975 on one seed; three seeds test
  stability where T1 was single-seed by design.

Estimand **E1** only. Fork **B** (`tape = Q_0`). Family **binomial logit**.
Structure `latent(d = 1, unique = FALSE)`.

## Invariants (never violate)

1. **One new lane.** Write only paths in `ultra-plan.md` §File-ownership fence.
   Closed kits (`cursor-mspl-fork-B-totoro`, `cursor-mspl-fork-B-L2`,
   `cursor-mspl-fork-B`, repo-root `LOOP/`) are **GOAL_MET** — cite, do not edit.
2. **Inherit official numbers.** L1 0.880; L2 0.900 / 0.780; T1 0.940 / 0.975 /
   near 0.710 / far 0.580. Do not rewrite those receipts.
3. **Verification = read LOG + object**, never exit code. Confirm deploy SHA before
   believing fits.
4. **Smoke before scale.** Local 1-rep on **each** confirm cell, then one DRAC
   cluster 1-rep × 2 blocks — *then* the 800-fit arrays.
5. **Compute = DRAC arrays.** Prefer **Fir + Nibi + Rorqual** (+ Narval if useful).
   One cell block per cluster or one `--array` over `params.csv`.
   `--cpus-per-task=1`, `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`.
   Install on **login**; never compute on login. Keepers off `/scratch` (D-50).
   ControlMaster sockets only (D-64). Totoro ≤16 cores for smoke/fallback.
   Not GitHub Actions (D-50).
6. **Fail closed.** Refusals price into effective coverage as non-coverage.
7. **RECORD only.** Report unfrozen candidate rules; do **not** apply a FAIL band
   unless Shinichi signs T\* in a separate sitting.
8. **Never merge from the execute chat** unless a later human gate says so.

## Out of scope — the fence

- Freezing T\* from this panel (unless explicit signed G0 after discussion packet)
- Undrafting [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077)
- Public `se = TRUE`, `vcov()`, `confint()`
- MSPL-04 off `blocked`; NEWS / README / article `covered`
- Re-walking T1 seeds `20260830`–`20260833` or L1/L2 seeds `20260818`–`20260821`
- E2, other families, Design 118 / B1 reopen
- GPU clusters (Killarney / Vulcan / tamIA)
- `git add -A`; `dev/isdm-package-recovery/**`

## Definition of done

- [ ] **D0 — this sitting:** kit exists under `docs/dev-log/lanes/cursor-mspl-fork-B-drac-confirm/`
- [ ] **D1 — runner:** extend `dev/mspl-forkB-t1-smoke.R` or thin sibling for
      confirm + multi-seed n160 blocks
- [ ] **D2 — smoke:** local 1-rep × 2 blocks; one DRAC cluster 1-rep inspected
- [ ] **D3 — DRAC panel:** 800 fits via job arrays; seeds as locked above
- [ ] **D4 — receipt:** dual coverage + refusal + Wilson + MCSE;
      `calibrated: FALSE`; `tstar_status: NOT-FROZEN` (unless signed elsewhere)
- [ ] **D5 — after-task + check-log + receipt PR**

Campaign-level done = **confirm panel recorded**, not T\* frozen, not MSPL-04
promoted, not #1077 undrafted.
