# D-43(c) Lens: SCOPE — does the NARROWED sentence still generalise past what was measured?

Fresh reviewer, no prior involvement. Worktree `/private/tmp/gllvmtmb-arc0-identifiability`,
branch `claude/aghq-engine-20260728` (PR #801, open, not merged). Default verdict NOT-DONE;
only evidence below moved me. All numbers are either recomputed by me from the checked-in
CSVs, read from the checked-in code/commits, or fits I ran myself against this checkout via
`devtools::load_all(".")` (package library install was stale at 0.5.0; load_all reflects the
branch head). Scripts left in the scratchpad, not committed.

## Summary verdict up front

**VERDICT: NOT-DONE.** The narrowed sentence fixed the previous panel's biggest problem (the
silent-eligibility-gate scope gap is now disclosed and warned on) but it still overreaches in
three separate, falsifiable ways, two of them in clauses (B) and (C) I was specifically asked
to check:

1. **(B)'s "the ONE family where the engine demonstrably ENGAGES"** implies poisson does not
   engage. I ran fresh fits on this branch and poisson AGHQ **does** move the parameter vector
   — reproducibly, not noise — contradicting the "par_shift identically 0" number the sentence's
   own supporting document (`decisions.md`) and the golden test's code comments still assert.
2. **(B)'s "tracks traits-per-site in the direction theory predicts"** holds cleanly only in a
   narrow slice (`q=1`, `n=1600`, `lam_sd ∈ {0.5, 1}`) and breaks down — non-monotonically, with
   sign flips — everywhere else, especially at `lam_sd=3` where the underlying metric is
   dominated by divergent fits.
3. **(C)'s "in every cell measured"** is false. I found 6 of 48 `(lam_sd × n × part × ridge)`
   cells in `25-fixedtruth-inc.csv` where Laplace's coverage beats AGHQ's at matched ridge
   setting, by margins well outside 2×MCSE in the largest cases.

(D) reproduces exactly. (A) I did not re-verify (out of lens scope; the suite-pass claim in
particular would need a full run I did not have budget for).

---

## 1. Is "the ONE family where the engine demonstrably ENGAGES" the right qualifier?

`21-wide-inc.csv` (the pre-fix campaign) shows `aghq_used == TRUE` on 100% of both binomial
*and* poisson AGHQ-arm fits (`3776`/`3780` rows respectively) — so `aghq_used` alone cannot
license "the ONE family." That is exactly why the arc added `par_shift` in commit `09b2dbcd`,
and its commit message asserts poisson `par_shift` is **identically 0** at T=4 and T=12 (and
the golden-test file, `tests/testthat/test-aghq-golden.R:311-324`, repeats this as "on poisson
it is legitimately 0 on this fixture").

**I reproduced the mechanism the fix targeted, but not the "identically 0" result it
reported.** Live fits on this branch (`devtools::load_all(".")`, `gllvmTMBcontrol(aghq=9)`,
`unique=FALSE`, single `latent()` block):

```
GOLDEN 3 fixture (.golden_poisson_data(), T=3, n_site=30, seed=103), 3 repeated runs:
  par_shift = 0.004429382   (identical across 3 runs — deterministic, not noise)

Varying seed on the same fixture generator (T=3, n_site=30):
  seed=101  par_shift = 0.02426259
  seed=102  par_shift = 0.05378663
  seed=103  par_shift = 0.004429382
  seed=104  par_shift = 0.02064703
  seed=105  par_shift = 0.007946259

T=4, n=100, poisson, 2 seeds:  par_shift = 0.008383, 0.003417
T=6, n=100, poisson, 2 seeds:  par_shift = 0.004860, 0.008029
(same cells, binomial, for scale:  T=4: 0.513, 0.580;  T=6: 0.390, 0.511)
```

This is not zero, and it is reproducible across three re-runs of the identical fixture — it is
not stochastic jitter. The reason is traceable: commit `12648f44` ("stop reporting 'converged'
when the gradient says otherwise"), which lands in this same PR **immediately after**
`09b2dbcd`'s "identically 0" verification, fixes the OR-stopping-test bug that had been causing
the AGHQ loop to falsely declare convergence at its Laplace warm start without moving at all.
That is the exact mechanism the `12648f44` commit message documents on poisson (`T=6, n=200`:
"declared converged at a gradient 5000x its own tolerance, having never left the Laplace warm
start"). Once that bug is fixed, poisson's AGHQ loop is no longer artificially frozen, and it
now takes small but real, non-numerical-noise steps (~1e-2 to ~5e-2, roughly 10–100× smaller
than binomial's ~0.4–0.6, but ~1e4–1e6× above a typical `shift_tol`/numerical-noise floor).

**So "identically 0" is stale evidence, made stale by a later commit inside the same PR that
never re-ran the number it superseded.** `decisions.md`'s "does not say... AGHQ does not run at
all on poisson (par_shift identically 0)" (line 2049) and the golden-test comment both still
carry the pre-`12648f44` number.

**Does this change the practical claim?** Not much, but it changes what the qualifier can
honestly say. `21-wide-inc.csv`'s `frob_rat` is functionally identical across all four arms for
poisson (medians 0.9857/0.9848/0.9859/0.9809 for aghq/aghq_ridge/laplace/laplace_ridge — a
spread of 0.005, versus binomial's spread of 0.5), so the tiny poisson par_shift does not
translate into any measured change in loading recovery. "The engine demonstrably engages" is
still defensible for binomial in the strong sense (large, answer-changing moves); "the ONE
family where the engine engages" is not defensible in the literal, binary sense the sentence
implies, because poisson also engages — just by an amount too small to matter for the metric
being reported. The honest form is "the one family where engagement is large enough to move the
answer," not "the one family where the engine engages."

## 2. Does "tracks traits-per-site in the direction theory predicts" survive across lam_sd and n?

Recomputed the AGHQ-vs-Laplace bias reduction (`1 - median(frob_rat)`, binomial, `conv==0 &
!failed`) across the full `T × lam_sd × n × q` grid in `21-wide-inc.csv`:

```
q=1, n=1600 (large-n, clean cell), reduction (bias_laplace - bias_aghq) by T:
  lam_sd=0.5:  T=2: 0.525   T=4: 0.453   T=6: 0.213   T=12: 0.071   -- MONOTONE, direction holds
  lam_sd=1.0:  T=2: 0.296   T=4: 0.272   T=6: 0.144   T=12: 0.063   -- MONOTONE, direction holds
  lam_sd=3.0:  T=2: 4.451   T=4: 4.082   T=6: -1.741  T=12: 0.002   -- NOT monotone, sign flips

q=1, n=100/400 (smaller n), lam_sd=0.5 or 1.0: T=4 spikes above T=2 in 3 of 4 slices
  (e.g. lam_sd=1, n=100: T=2:0.210, T=4:0.658, T=6:0.110, T=12:0.045 -- not monotone)

q=2 (random-slope shape): lam_sd=0.5, T=12, n=100: reduction = -13.85
  lam_sd=1.0, T=6, n=100: reduction = +14.69; T=12, n=100: reduction = -9.77
```

The direction ("more traits per site → smaller AGHQ advantage") **does** hold cleanly, but only
in the `q=1, n=1600, lam_sd ∈ {0.5, 1}` slice — exactly the large-n, well-identified corner. It
fails, sometimes with large sign reversals, at smaller n, at `q=2`, and everywhere at `lam_sd=3`.

The `lam_sd=3` breakdown is not just noisy — it is a different regime. Checking the number of
surviving `conv==0` fits per cell at `lam_sd=3, q=1, n=1600` (binomial): `aghq` T=2/4/6/12 has
only 8/3/3/3 of 15 seeds surviving the convergence filter, with surviving medians of `frob_rat`
= 5.1/9.2/0.97/1.02 — i.e. most fits are excluded as non-converged, and the ones that remain are
frequently divergent estimates (5–13× the truth in Frobenius norm), not a stable comparison of
two well-behaved integration schemes. A "direction theory predicts" claim computed on a median
of mostly-diverged fits is not evidence for the mechanism; it is evidence about which regime is
unstable. The claim as worded doesn't restrict itself to the slice where it actually holds.

## 3. "In every cell measured" — falsified

Recomputed Wald coverage of Sigma from `25-fixedtruth-inc.csv` (`status=="ok"`, finite `lo`/`hi`),
`arm ∈ {aghq, aghq_ridge, laplace, laplace_ridge}` split by ridge status, paired at matched
ridge setting (aghq vs laplace non-ridge; aghq_ridge vs laplace_ridge), across all
`lam_sd ∈ {0.5,1,3} × n ∈ {100,200,400,1600} × part ∈ {diag,offdiag}` = 48 matched-ridge cells:

```
6 of 48 cells: AGHQ < Laplace at matched ridge setting
  lam_sd=0.5  n=400   offdiag  no-ridge:  aghq 0.9331  vs laplace 0.9673   diff = -0.034
  lam_sd=0.5  n=200   offdiag  no-ridge:  aghq 0.9573  vs laplace 0.9879   diff = -0.031
  lam_sd=1.0  n=100   diag       ridge :  aghq 0.9563  vs laplace 0.9682   diff = -0.012
  lam_sd=0.5  n=400   offdiag    ridge :  aghq 0.9615  vs laplace 0.9682   diff = -0.007
  lam_sd=0.5  n=200   offdiag    ridge :  aghq 0.9795  vs laplace 0.9856   diff = -0.006
  lam_sd=0.5  n=100   offdiag    ridge :  aghq 0.9918  vs laplace 0.9934   diff = -0.002
```

The two largest are not noise. Per-seed MCSE (mean/SD-across-seeds/√n_seed, matching the
project's own B3b certification convention):

```
n=200, offdiag, no-ridge:  aghq 0.9529 (mcse 0.0080, ~105 seeds)  vs laplace 0.9879 (mcse 0.0026, ~110 seeds)
  -> aghq's 2*mcse upper bound (0.969) is below laplace's 2*mcse lower bound (0.983): non-overlapping
n=400, offdiag, no-ridge:  aghq 0.9294 (mcse 0.0092, ~105 seeds)  vs laplace 0.9673 (mcse 0.0048, ~108 seeds)
  -> aghq's 2*mcse upper bound (0.948) is below laplace's 2*mcse lower bound (0.958): non-overlapping
```

These are genuine, statistically distinguishable reversals, both at `lam_sd=0.5` (the small,
well-specified true-loading regime) and `part=offdiag`, at small-to-moderate `n`. "In every cell
measured" is false; the correct, narrower claim would be something like "AGHQ's coverage
advantage widens with n and dominates in the aggregate (mean diff 0.073→0.112→0.165→0.232 across
n=100/200/400/1600), but at small true loadings and off-diagonal entries, Laplace can beat AGHQ
at small-to-moderate n." Checking monotonicity of the gap per slice (12 `lam_sd × part × ridge`
slices): only 4 of 12 are monotone non-decreasing in n — the aggregate "gap widening in n" claim
is defensible as an average-across-cells statement, but "in every cell" and per-cell monotonicity
are both overreach.

## 4. Is 0.023 reproducible, and is "the SHIPPED LAPLACE DEFAULT" the right description?

Reproduced exactly from `25-fixedtruth-inc.csv`: `laplace`, `lam_sd=3`, `n=1600`, `part=diag`,
`mean(covered) = 0.02265` → matches the claimed "0.023." Good.

"The SHIPPED LAPLACE DEFAULT" is ambiguous but I judge it defensible as worded, not a violation:
the sentence's own first line already frames "Laplace" as the shipped **engine** default (as
opposed to opt-in AGHQ), and clause (D) is contrasting engines, not model grammars — it does not
claim this coverage failure occurs under the package's default *formula* grammar. The data point
does use `unique = FALSE` (soft-deprecated compatibility syntax, not the current default
`latent()` grammar that carries Psi), so a careless reader could conflate "shipped Laplace
default" with "default model configuration" and conclude the failure applies to an ordinary
`latent()` fit — it has not been shown to. This is a real ambiguity worth a one-clause fix
("...under `unique = FALSE`, has a previously unmeasured coverage failure...") but it is not,
on the sentence's own terms, a false claim — Laplace genuinely is the default *engine*, and this
run genuinely used it.

## 5. Anything under-claimed?

Not materially by my count. If anything, the aggregate "gap widening in n" understates how large
the gap gets at `lam_sd=3` (up to 0.69 at n=1600, diag, ridge) — but the sentence doesn't need a
correction in the "too modest" direction; its problems are all overreach.

---

## What I did not exercise

- Did not independently re-verify claim (A)'s oracle-agreement numbers, the monotone-in-k
  sequence, or the "FAIL 0 / SKIP 0 / PASS 1504" full-suite claim — out of my lens's scope and
  a full-suite run was not in budget; another lens should check this.
- Did not re-run the 7550/3199/3200-fit campaigns; all CSV recomputation only, plus targeted
  live fits (< 30 fits total) to check engagement and reproducibility.
- Did not check whether the poisson `par_shift` non-zero-ness generalizes to `n_site` values
  outside {30, 100} or to `q=2`.

## SMALLEST EVIDENCE THAT WOULD CHANGE MY VERDICT

1. Reword (B) to drop the implied binary ("the ONE family where... engages") in favor of
   something like "the family where the engine's movement is large enough to change the answer"
   — and correct the stale `par_shift`-identically-0 claim in `decisions.md` and the golden-test
   comment to reflect the post-`12648f44` reproducible non-zero value.
2. Either scope (B)'s "tracks... in the direction theory predicts" explicitly to `q=1,
   n≥1600-ish, lam_sd ≤ 1` (where I confirmed it holds cleanly), or show it holds more broadly
   with a cleaner divergence-filtered metric than raw `frob_rat` medians at `lam_sd=3`.
3. Either drop "in every cell measured" from (C) in favor of the true aggregate statement (gap
   widens with n on average; 6 of 48 matched-ridge cells reverse, concentrated at small
   `lam_sd` and `part=offdiag`), or add a caveat naming the reversal region.

VERDICT: NOT-DONE
