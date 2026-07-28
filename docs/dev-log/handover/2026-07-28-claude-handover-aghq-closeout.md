# Claude → Claude handover, 2026-07-28 — the AGHQ close-out arc

Lane `claude/aghq-engine-20260728` · worktree `/private/tmp/gllvmtmb-arc0-identifiability` ·
base `main` @ `72c2e53d` · **52 commits, all pushed** · **PR #801 OPEN — DO NOT MERGE**.
Working tree clean and in sync. No jobs running.

---

## 1 · Mission control

| | |
|---|---|
| **verdict** | **WITHHELD TWICE.** Two fresh D-43 panels, both **NOT-DONE / DONE / NOT-DONE** |
| **engineering** | **PASSED**, independently reproduced by a panel lens |
| **default** | UNCHANGED. `aghq = FALSE`, nothing exported, NAMESPACE untouched |
| **suite** | AGHQ **FAIL 0 / SKIP 0 / PASS 1504** (was FAIL 2 / SKIP 1 / PASS 10) |
| **rung** | NOT READY. No capability claim. Merging is Shinichi's call |
| **START HERE** | `docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md` |

The engine is sound. **Every failure this arc was in the evidence or the instrument, never in
the mathematics.** That distinction is the whole handover.

---

## 2 · 🔴 Read before quoting ANY number from this arc

**Four figures are retracted or stale. A next session citing them will be wrong.**

1. **`aghq$used == TRUE` does not mean the quadrature ran.** Read **`fit$aghq$par_shift`**,
   added for this. `used` means only that the branch was entered.
2. **"poisson par_shift identically 0" is STALE.** Measured at `09b2dbcd`; my own fix
   `12648f44` changed it. Now nonzero (~0.004–0.05). *After an engine edit, re-run every
   measurement that engine produced — the invariant was insensitive to what changed.*
3. **"AGHQ+ridge reaches nominal coverage" is RETRACTED.** The DGP redrew the true Λ per seed,
   marginalising coverage over a Gaussian prior that the ridge *is*. Fixed-truth gives **0.892
   at n=1600**; 1 of 36 cells clears the 2·MCSE bar, and it is `laplace_ridge`.
4. **"The shipped Laplace default covers 0.023" is RETRACTED.** Using the within-truth
   empirical SD instead of my delta SE gives **0.970 / 0.969 / 0.959 / 0.649**. The "defect"
   was ~90% my own instrument.

**Every coverage number here is also below house standard.** Design 66 §7: ~200 seeds is
**PILOT ONLY**; **2000** is the adjudication floor. I ran 200 and 120.

---

## 3 · What is SOLID

* **Integral correctness.** 1.2e-09 against a brute-force `integrate()` oracle **at a fixed
  parameter point**; monotone in k (5.4e-05 → 8.7e-13 → **1.6e-14** at k=3/9/25, `par_shift`=0
  confirming a true fixed-point evaluation); k-independent Gaussian exactness that goes **red**
  under injected defects; Laplace path byte-identical.
* **Four engine bugs fixed**, each reproduced first and verified by an independent lens with
  `grad_tol` proven untouched across the *entire* file history.
* **Prototype dependency eliminated** — 15,900 fits through real `gllvmTMB()`. Lens 1's
  original objection, cleared.
* **A real test suite** — 1504 passing, 0 skipped, from 3 permanently-skipping assertions.
  Lens 2's original objection, cleared.
* **The ridge unbundled** (`4dc351ed`) — `Laplace+ridge`, the fair control, runnable for the
  first time. Opt-in; the default path is byte-identical (|Δobj| = 0).

**One instrument-independent candidate** (a candidate, *not* a claim): at lam_sd=1, n=1600 the
shipped Laplace default's Σ-diagonal **bias exceeds one sampling SD** (bias/SD = −1.115). Uses
the empirical SD, so it does not depend on the failed delta route.

---

## 4 · The four bugs

| bug | what it did | commit |
|---|---|---|
| **silent ineligibility** | `aghq=9` on the *current default* grammar returned plain Laplace with **no message** — poisson *and* binomial | `09b2dbcd` |
| **lying activity flag** | `used = TRUE` on fits returning Laplace **bit-for-bit** | `09b2dbcd` |
| **vacuous test** | GOLDEN 3 passed because AGHQ *wasn't running* | `09b2dbcd` |
| **false convergence** | reported "converged" at a gradient **5000×** its own tolerance | `12648f44` |

The last is the root cause of the others. The stopping test is an **OR**, so the `f_tol` leg
fires alone — and fires most easily when the optimiser moves *nothing*, so `dF = 0` and the
mode is unchanged, and *"nothing changed twice"* reads as *"settled"*. Tracing it also showed
**binomial was being called "converged" at 2.6× tolerance** too.

---

## 5 · 🔴 The brain held most of this already

A four-way sweep (`search_notes(search_all_projects = true)`) found the arc re-derived what was
on record. **Query the brain BEFORE building an instrument, not after a panel rejects it.**

| the arc did | already on record |
|---|---|
| 200/120-seed coverage cells | **Design 66 §7: ~200 = PILOT ONLY**; **2000 = adjudication floor** |
| "discovered" the truth-redraw confound | **fixed truth per cell is the unbroken standard** (`m3_sample_truth`) |
| complete-case coverage | documented failure mode **#1, silent denominator laundering** |
| delta SE with `qnorm` | **z→t for LOCATION-axis VCs**; per-class map filed as **gllvmTMB#565** |
| measured Laplace bias by simulation | **`R/check-consistency.R` already wraps `TMB::checkConsistency()`** |
| "flat likelihood direction" | **Rabe-Hesketh, Skrondal & Pickles 2002** predicts exactly this |

**gllvmTMB#565's per-class map** — Λ / Ψ / sd_B = location → t may help; NB2 φ, Γ shape, Beta φ,
Tweedie = dispersion → do **NOT** apply t; correlations → Fisher-z. *t is not a blanket
default; the sign of the z-error flips with the axis.*

**Genuinely new:** the **stall**. The sweep searched for a prior adaptive-quadrature warm-start
stall and found none.

**Also surfaced:** a **2026-07-28 Bolker brief** (`FOR-GLLVMTMB-2026-07-28-bolker-brief`) —
independent convergence on AGHQ at **5–10 nodes**. Alex Stringer is named as a possible
advisor but **has NOT agreed to anything**; do not cite him as involved.

---

## 6 · Next arc — planned, decisions locked

**`docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`** — 11 h (8–12), 10 slices,
copy-paste GOAL block, Phase 0.25 receipt complete.

**Headline: extend the CERTIFIED profile route to low-rank Σ.** gllvmTMB already has one
coverage-certified interval (the Gaussian `Sigma_unit` **diagonal** profile, n≥150, d≤2,
~0.946–0.948) — but `R/profile-route-matrix.R:631` says **low-rank total Σ falls back to
bootstrap**, ruled the wrong route on 2026-07-18. AGHQ forces `unique = FALSE`, so every AGHQ
fit is low-rank and the whole arc measured through that fallback.

**Two decisions Shinichi locked this session:**
1. **Instrument first, then multinomial** — multinomial would inherit the same broken
   measurement, and its recorded blocker is data-hungriness (N≈800), not the integrator.
2. **A1/A3 are SUPERSEDED — record the reversal explicitly** (S1), the way the 2026-05-15
   reversal was, so a future reader can tell they were overturned rather than overlooked.

**Do S5 before S6:** `R/profile-ci.R:32` uses a bare `qchisq(level, 1)/2`, but at a boundary
the LR reference is a **chi-bar-square mixture** (Self–Liang, D-12) — it mis-covers *in
profile's own best regime*. Any low-rank extension inherits it uncorrected.

**Multinomial (S8) needs less than my earlier handover claimed:**
`expand_multinomial_response` already makes K−1 pseudo-traits, so the factor route needs **no
new C++**, and a phylo-multinomial arc was already built (Design 84, `88d7820e`). But: the
multinomial **latent scale is non-identified and must be fixed by convention**, and quadrature
over that same latent interacts with it — settle that first. **Do NOT re-attempt the
`R=(1/K)(I+J)` OLRE regularization** — recorded negative, marked do-not-repeat.

---

## 7 · Do not repeat

* Do **not** read `aghq_used` as evidence the quadrature did anything.
* Do **not** quote complete-case coverage without the fit-health denominator beside it.
* Do **not** cite `‖Λ̂‖/‖Λ‖ > 2` as an independent result — circular with a penalty equal to
  `0.5·tr(Σ̂)/τ²`; McNemar on 47%→73% gives **p = 0.134**.
* Do **not** treat `O(1/T)` as established — `bias × T` is constant only in the single
  `(lam_sd = 1, n = 1600)` cell of the 7550.
* Do **not** write a pre-registered gate and skip it. `25-coverage-fixedtruth.R:26-31` carries
  one in my own words; a panel computed it and it **fails in 45 of 48 cells**.
* Do **not** merge PR #801. Two panels have withheld the claim.
* `pgrep -f Rscript` reports 0 for healthy R jobs — R runs as `exec/R`.

---

## 8 · Compute

Totoro is set up and **~10× faster per fit than the laptop**. Branch installed at
`~/h4_work/aghq-lib`, source `~/h4_work/aghq-src`, campaigns in `~/h4_work/`. Rebuild after any
`src/` change:

```bash
R CMD INSTALL --no-docs --library=$HOME/h4_work/aghq-lib aghq-src
```

**Delete `src/*.so` and `src/*.o` on the remote first** — `rsync --delete` protects excluded
files, and a macOS `.so` gives `invalid ELF header`. Cap 150 cores; local ≤6 (Codex shares it).

---

## 9 · ⚠ Loose ends for Shinichi

* **Concurrent lane** `claude/aghq-family-axis-20260728` (`/private/tmp/gllvmtmb-family-axis`,
  1 commit ahead) **conflicts with this branch on `docs/dev-log/decisions.md`** — both append.
  Its family-axis finding is *compatible*. **Merge order is your call, not an agent's.**
* **An orphan note is uncommitted in the MAIN worktree:**
  `docs/dev-log/2026-07-22-quadrature-regime-trap-and-the-correlation-boundary-gap.md`. It holds
  the Rabe-Hesketh / Liu–Pierce regime analysis that *predicts* this arc's flat-likelihood
  finding. **S1 lands it.**
* **8 untracked `dev/aghq-*` files** in this worktree are a prior session's; left alone.
* **Codex implementation review** `task-ms52uh0u-4mcgsc` was dispatched and its result never
  read. It is the first reading of this *code* rather than its claims — worth collecting.

---

## 10 · How to resume

```bash
cd /private/tmp/gllvmtmb-arc0-identifiability
git fetch origin && git status -sb
```

Read: **this file** → `docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md` → the
2026-07-28 entries in `docs/dev-log/decisions.md` (the last four are the corrections) →
`dev/aghq-evidence/D43c-lens{1,2,3}-*.md`.

---

## 11 · The one thing to carry

Four results dissolved this arc, and the fourth was **unfavourable** to AGHQ — being
unflattering gave it no protection. All four had the same shape: **a correct theory and a
broken mechanism predicted the same number, and the match stopped the checking.**

> **A result that confirms your prediction is where the mechanism check is most needed, not
> least. And query the brain before building the instrument — the house rules, the literature,
> and the prior attempt all existed.**
