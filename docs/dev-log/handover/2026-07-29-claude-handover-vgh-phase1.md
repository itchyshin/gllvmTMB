# Claude → Claude handover — VGH Phase 1 (new lane)

**2026-07-29.** You are Claude, opening a **new lane** to execute VGH Phase 1.
The planning, measurement and gating are DONE. Your job is the port.

**Approved plan:** `~/.claude/plans/memoized-growing-sparkle.md` (ultra-plan,
maintainer-approved this session). Read it — this doc carries state, that file
carries the slice table.

**⚠ MULTI-LANE.** At least three other Claude lanes are live on 2026-07-29
(`claude/manpage-honesty-…`, `claude/aftertask-814-…`, `claude/article-findings-…`).
This handover deliberately does **not** rewrite `CLAUDE.md`'s snapshot pointer —
doing so would orphan them. Check `docs/dev-log/handover/` for the current
lane-split board before claiming any shared file.

---

## 🔴 Read first — six corrections that must travel

The previous session (me) reported six things that later proved wrong. They are
listed because **the incorrect versions were said out loud to the maintainer**,
and one of them **was committed and pushed**.

1. **`bc9f6992` IS WRONG AND MUST BE REPAIRED.** I declared "Design 160" a
   phantom citation and rewrote eight references across `docs/design/106`, `107`,
   `108`. **Design 160 is real** — it lives in the sister package at
   `drmTMB/docs/design/160-gaussian-variational-approximation-gate.md`, and its
   line 98 states exactly the architecture decision being cited (the variational
   block is removed *"from `random=` (GVA optimizes it as a fixed parameter)"*).
   My search covered only gllvmTMB's own `docs/design/`.
   **Locked repair (maintainer, this session):** cite **both**, qualified —
   restore `drmTMB Design 160` *with the repo prefix* (the real defect is that
   the bare number reads as dangling, since gllvmTMB's numbering stops at 110),
   **keep** the `Design 72 §2` pointer I added (it is gllvmTMB's own statement of
   the same decision, lines 145–154), and **rewrite the A/B block's premise**: the
   fence was legitimate; what qualifies it is the measurement, not a missing doc.

2. **Arm A does NOT crash at N=3200.** I reported a crash and said it
   corroborated the recorded "VA does not complete beyond n≈2500". It completed in
   **895.6 s**; the crash was collateral from a killed background task, and the
   prior claim is **not reproduced**.

3. **`profile=` is not simply "refuted".** Per-evaluation cost is **linear**
   (slope 0.973, R²≈1.000) with flat memory, against `random=NULL`'s **N^1.35**
   and *quadratic* memory — 1340 Mb at N=3200, projected 9.3 GB at N=10,000 and
   37 GB at N=20,000. It loses today only on a constant. **The real limit on the
   status quo is memory, not time** (PORT's dense secant array). If the block is
   ever moved out of the fixed vector, `profile=` is the correct form.

4. **`random=` is invalid, not merely slow.** It estimates a different, badly
   biased `Σ_B` — relFrob 0.65–0.74, **flat in N** — because Laplace-marginalising
   optimisation variables is not a valid operation.

5. **The attenuation "sign question" was a false dichotomy, and partly a units
   error.** Design 109's prediction that exact-GH *over*-estimates `Σ_B` is
   **confirmed for binomial at small n** (attenuation 1.137, 12/12 above 1,
   p=0.0005 at n=200) and **decays to nothing by n=800**. My "0.99" probe sampled
   the regime where it had already vanished. Worse: the two circulating numbers
   were on **different scales** — `dev/three-engine-demo.md` reports *trace*
   ratios, my probe *Frobenius* ratios, and `atten_tr = atten_F²`. The demo's
   0.668 is **0.817** on my scale. Always state which.

6. **Design 109's "JJ beats GH on 20/20 seeds" reverses with n.** At n=800 GH
   wins decisively (0.218 vs 0.386) while JJ's shrinkage *worsens*
   (0.892 → 0.881 → 0.848, 0/12 above 1 at n≥400). The two-wrongs-cancel
   mechanism only holds while GH is inflated. 109's conclusion should be
   qualified as small-n.

**The pattern behind 2, 5 and the Poisson scare below:** three times a
**measurement or scope artefact** was reported as a property of the method.
Each tell was the same — *a result that degrades with n, from a method that
should improve with n*. **Rule for this lane: no recovery number is reportable
without its sweep count and convergence status attached.**

---

## Mission control

| | |
|---|---|
| **lane** | `claude/vgh-variational-20260729` — **pushed**, 13 ahead / **18 behind** `origin/main`. Rebase before any merge. |
| **plan** | `~/.claude/plans/memoized-growing-sparkle.md` (approved) |
| **state** | Phase 0 gate **CLEARED**. Nothing promoted, no package file touched, no export. |
| **risk** | **LOW** — everything is under `dev/vgh/` and `docs/`. `engine = "laplace"` remains the only user route. |
| **next** | Slice S1 (Anderson/SQUAREM) and S2 (port) — see the plan's slice table |

## What Phase 0 established (do not re-run)

* **Same objective.** `dev/vgh/vgh-engine.R` and `inst/tmb/gllvmTMB_va_r3.cpp`
  agree to **4.7e-15** across 46 comparisons (binomial n>1 and Bernoulli, poisson;
  q ∈ {2,4,5}; H ∈ {15,25,61}). **Seven negative controls fired** at magnitudes
  1.23–728.9, so the check had power. At H=15 the two agree on the *discretisation
  error itself* (3.4e-12) — only possible with node-for-node identical rules.
* **Same estimates.** 288 matched fits, 12 seeds/cell, **zero failures**. At
  binomial n=800 the paired difference is bounded within **±0.0003** on a metric
  whose level is 0.218 — an equivalence result, not a null. `va_r3` ran 4 starts
  to VGH's 1, biasing *against* VGH.
* **Speed.** Like-for-like **~17× per start**. Gaussian vs Laplace 8–15×.
* **Gaussian exactness.** ELBO = exact marginal log-likelihood to **1.26e-12**.
* **Quadrature order is irrelevant to recovery.** Q ∈ {9,15,21,31} gives identical
  rel-error and attenuation to four decimals; only cost changes. **Use Q=9.**

## The one real defect — this is slice S1

**34 of 36 Poisson fits hit `maxit = 200`** (median sweeps = 200) while binomial
converged in 25–34. Attenuation undershot in **36/36** paired seeds. Converged
properly (`tol=1e-13, maxit=5000`) the deficit vanishes: 0.1634→**0.0528**,
0.4331→**0.0643**, 0.1984→**0.0608**, against `va_r3` GH's 0.0749.

So: **block coordinate ascent converges slowly on Poisson** — 432 to 5000+ sweeps,
one seed unconverged at 5000. Expected zigzag (`A_i` depends on `Λ'W_iΛ` and `Λ`
depends on `A_i`); the log link makes `W_i` far more sensitive to `Λ`.

Two defaults are also wrong: `maxit = 200` is too low, and the convergence test is
**relative to |ELBO|**, so it *loosens* as n grows — backwards.
**Seeds 3 and 8 are bad at every n (relFrob 0.43–0.62) and need separate attention.**

## Locked decisions

* **API follows drmTMB Design 160** (maintainer, this session): an
  `engine`/`inference` control defaulting to laplace; variational SEs **labelled
  variational** and never presented as `sdreport` SEs; a convergence/ELBO
  diagnostic row. Design 160 is design-only in drmTMB too — neither package has
  built it, so matching it keeps the sisters consistent.
* **Report the Laplace MLE.** VGH warm-starts and screens; it does not publish an
  estimate. Every VA accuracy question is therefore out of scope for users.

## Files created this session (all on the lane, pushed)

```
dev/vgh/vgh-engine.R                 the engine (~330 lines, base R)
dev/vgh/vgh-validate.R               oracle ladder
dev/vgh/crosscheck-va-r3.R + .csv    46-comparison TMB cross-check
dev/vgh/phase0-matched-recovery.R/.csv/.md + phase0-runs/
dev/vgh/ab-random-vs-fixed.R + ab-runs/
dev/vgh/binom-tuning.R, scaling-vgh.R, tilt-probe.R, poisson-convergence-probe.R
docs/dev-log/2026-07-29-vgh-report.md                 consolidated report
docs/dev-log/2026-07-29-vgh-implementation-plan.md    4-phase plan
docs/dev-log/2026-07-29-vgh-coverage-map.md           13-14 of 16 families
docs/dev-log/2026-07-29-vgh-structured-stationarity.md  S_g^-1 = Q_gg + curvature
docs/dev-log/recovered/                               the 2026-07-27 diagnosis
docs/design/10{6,7,8}                                 ⚠ bc9f6992 — REPAIR THESE
```

## Gotchas paid for in blood

* **`devtools::test()` cannot catch packaging defects.** `test-eva-gate1.R` reads
  `docs/design/86-…json`, and `.Rbuildignore:18` has `^docs$` — 7 failures under
  `R CMD check`, invisible under `load_all()`. **Your test file must not read from
  `docs/`.** A second instance: `.eva_find_source()` also lacks a `system.file()`
  fallback.
* **Never `git add -A`** — a permission hook blocked it this session, correctly.
* **Do NOT run `devtools::document()`** — LANE 1 owns `NAMESPACE`.
* Background runs get killed around ~10 min; split long grids.
* `vgh_elbo()` has **no `n_trials` argument** — the binomial entry point is
  Bernoulli-only. Slice S2.

## Next immediate steps

1. Repair `bc9f6992` per the locked decision (docs-only, independent — do it first, it is cheap).
2. Rebase onto `origin/main` (18 behind).
3. S1 — Anderson/SQUAREM + stopping rule. **The headline.**
4. S2 — port to `R/va-vgh.R`, internal, `n_trials`, guards.
5. S3 — `tests/testthat/test-vgh-oracle.R`, fixtures **not** under `docs/`.
6. S4 — re-run the Poisson cells; the paired gap must close.
7. Verify with **`rcmdcheck` from a tarball**, not `devtools::test()` alone.

## Do not claim

More accurate than Laplace (not measured) · novelty of the mathematics
(Ormerod & Wand 2012; Opper & Archambeau 2009; Hui et al. 2017 probit case) ·
any interval or coverage property · that this reopens VA as an estimator (the
freeze was on **coverage**, and speed does not change that).

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git worktree add /private/tmp/gllvmtmb-vgh-p1 -b claude/vgh-phase1-20260730 origin/claude/vgh-variational-20260729
```

One command, from the repo root, in your own authenticated terminal:

```
claude "Rehydrate from docs/dev-log/handover/2026-07-29-claude-handover-vgh-phase1.md and the approved plan at ~/.claude/plans/memoized-growing-sparkle.md. Read the six corrections FIRST. Then repair commit bc9f6992 per the locked decision, rebase onto origin/main, and execute slices S1 and S2."
```
