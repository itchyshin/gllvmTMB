# Arc D — cheap speed levers: the scope was wrong, and the one real lever is ~1.1×

**Date:** 2026-08-04 · **Platform:** Claude Code · **Compute:** Totoro (load 1.15 → 1.81, idle box)
**Script:** `dev/va-speed/64-nlminb-scale-lever.R` · **Results:** `64-scale-lever-run-N*-s*.rds`

## 1. The scope correction — four of five "levers" are not levers

The handover listed five *"cheap untested levers"* in recommended order. Checked against `R/`:

| lever | reachable today? | evidence |
|---|---|---|
| `nlminb(scale=)` | **YES** | `gllvmTMBcontrol(optArgs=)` whitelists `scale` (`R/fit-multi.R:5196`) and passes it to `nlminb` (`:5211`) |
| sdmTMB `multiphase` | **no** | zero hits for `multiphase` in `R/` |
| `optimHess` polish | **no** | zero hits in `R/` except one comment at `R/va-r3-proto.R:1479` |
| `sdreport` knobs (`skip.delta.method`, `ignore.parm.uncertainty`) | **no** | zero hits in `R/`; the production call is hardcoded at `R/fit-multi.R:6087` |
| gllvm `inner.control` | **n/a** | that is a *comparator's* knob, not ours |

**So Arc D is one measurement plus three build-then-measures, not five measurements.** A prior
lever on the same list — the AD framework, described as "a one-liner" — had already been built and
**closed by measurement** (`b4fb920f`: TMBad **1.76× slower**). The "cheap untested levers" list was
optimistic about its own cheapness.

## 2. The one real lever: `nlminb(scale=)`

Gaussian, `value ~ 0 + trait + (1 | site_f)`, T=8, single-threaded
(`OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`), untimed warm-up, median of 3 reps, 3 seeds.

| arm | N=250 median s | N=1000 median s |
|---|---:|---:|
| A baseline | 0.375 / 0.398 / 0.399 | 1.535 / 1.541 / 1.547 |
| **B `scale = 1` (null control)** | 0.377 / 0.403 / 0.403 | 1.534 / 1.552 / 1.556 |
| C `scale = 0.1` | 0.433 / 0.442 / 0.447 | 1.820 / 1.834 / 1.835 |
| **D `scale = 10`** | **0.349 / 0.352 / 0.360** | **1.371 / 1.406 / 1.432** |

**Status column, beside the result (this lane's standing rule):** every arm, every seed,
**3/3 converged**. No cell is a giving-up timing.

**Both controls pass.**
- `scale = 1` reproduces the baseline log-likelihood **exactly** — so the `optArgs` pass-through
  does what it claims and nothing else. Without this arm, "the lever works" is indistinguishable
  from "the harness moved something".
- **Every arm returns an identical log-likelihood** at every seed. The lever is **free**: it
  changes the optimiser's step scaling, not the answer. (This is what makes it different from
  gllvm's `inner.control`, where `tol10` may move estimates.)

**Direction:** `scale = 10` is faster, `scale = 0.1` is slower, consistently, at both N, across all
three seeds. Ratio vs baseline ≈ **1.10–1.13×** faster, and ≈ 0.88× for `scale = 0.1`.

## 3. ⚠ What I would not claim from this, and why

**The arms were not interleaved.** Each arm ran its three reps consecutively, then the next arm.
This lane's own discipline — established in ledger claim 32 — is **paired, interleaved,
order-rotated** precisely so that machine drift cannot be confounded with the arm. Mine can be.
The effect (~10%) is larger than the within-arm seed spread (~6%) and reverses cleanly between
`scale = 0.1` and `scale = 10`, which is reassuring, but **direction is what this establishes;
the magnitude is soft.**

**The regime is narrow:** one family (Gaussian), one structure, one T, two N. Nothing here
licenses a claim about non-Gaussian families, larger q, or the VA path.

**`scale` is a blunt instrument here.** All four arms used a *constant* vector. A real
implementation would derive per-parameter scaling from parameter magnitudes or Hessian diagonals,
which is exactly the conditioning question this lever is a cheap proxy for — and that is a build,
not a knob.

**VA-R3 cannot use this at all.** `.va_r3_run_primary()` (`R/va-r3-proto.R:1523-1526`) calls
`nlminb(start, obj$fn, obj$gr, control = control)` with no `scale` and no `optArgs`-style
pass-through. Plumbing it there is a separate change.

## 4. Verdict

**A modest, free, real ~1.1× on the Laplace path at these sizes — provisional pending an
interleaved re-run.** Nothing promoted, nothing wired as a default: a constant `scale = 10` that
happens to help one Gaussian cell is not a default, and choosing a principled per-parameter scale
is the actual open question.

**Next, if this is worth continuing:** interleave and rotate the arms; then decide whether to
plumb the three unplumbed levers, cheapest first (`optimHess` polish and `multiphase` are "free by
construction"; the `sdreport` knobs are now more interesting than before because
`standard_errors()` makes that call user-triggerable).

---

## UPDATE 2026-08-04 — re-run INTERLEAVED; the caveat is discharged

§3 flagged that the arms were not interleaved, so only the *direction* stood. That has now been
fixed and re-run: the outer loop is the **replicate** and the arm order **rotates within it**
(rep 1 = A,B,C,D; rep 2 = B,C,D,A; …), so machine drift is spread across arms instead of landing
on whichever ran while the box was busy. 5 seeds × 2 N, Totoro, single-threaded.

| N | baseline median s | `scale = 10` median s | ratio | seeds where `scale=10` wins |
|---:|---:|---:|---:|---:|
| 250 | 0.400 | 0.355 | **1.127×** | **5 / 5** |
| 1000 | 1.555 | 1.407 | **1.105×** | **5 / 5** |

**10 of 10 cells in the same direction**, null control (`scale = 1`) passing every time, 3/3
converged in every arm of every cell. **The magnitude now stands at ~1.11–1.13×**, not just the
direction. `scale = 0.1` remains consistently slower.

Incidental but worth noting: `scale = 10` is also markedly more *stable* — its per-seed spread at
N=250 is 0.350–0.361 (3%) against the baseline's 0.375–0.426 (14%).

### One claim tightened, not loosened

The original wrote that "every arm returns an identical log-likelihood", on the strength of the
script's own gate — which uses `all.equal(tolerance = 1e-8)`, i.e. **mean relative** difference.
Checking exact equality instead shows the arms are **not** bit-identical: worst absolute difference
across all ten cells is **1.5e-07**, which is **~8e-11 relative** to a log-likelihood of order 1800.

That is optimiser noise at the convergence tolerance, not a different answer — so the lever is
still **free in the sense that matters**: it changes the path to the optimum, not the optimum. But
it is *not* bit-exact, and it should not be described the way the `se = FALSE` bootstrap speedups
were, which really did pass `all.equal(tol = 0)` with zero cells differing. Different strength of
evidence, different words.

**Still not promoted.** A constant `scale = 10` that helps one Gaussian cell is not a default;
choosing a principled per-parameter scale remains the open question, and VA-R3 still has no
`scale` pass-through at all.
