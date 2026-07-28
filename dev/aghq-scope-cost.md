# AGHQ-on-Laplace (AGHQ-LA) cost scoping — Fisher, "what does it cost"

**Status:** research cost-scoping only. No package feature, no implementation,
no accuracy claim. Scope is COST ONLY, per the brief. This does not revisit
whether AGHQ-LA would be accurate — it asks what one would pay to find out.

**Scripts:** `dev/aghq-scope-cost-timing.R` (production Laplace `obj$fn()`
cost, n = 200/800/1600) and `dev/aghq-scope-cost-node-ratio.R` (per-node vs.
mode-solve cost ratio, using the existing unmodified O3 prototype). Raw
results: `dev/aghq-scope-cost-timing-results.rds`,
`dev/aghq-scope-cost-node-ratio-results.rds`. Worktree:
`/private/tmp/gllvmtmb-va-wiring-20260726`, `dev/` only, `R/`/`src/`/`tests/`
untouched.

**Machine load note.** `uptime` showed load averages ~28–34 throughout (this
Mac is running multiple concurrent Claude/Codex lanes per CLAUDE.md's active
lane split). The three `obj$fn()` fits (n=200/800/1600, one pass each) are
**not** protected against contention — they were not repeated, because a full
gllvmTMB fit is not cheap enough to repeat 3x per cell within this brief's
scope, and the brief's timing rule is about **evaluation** cost, not fit
cost. The evaluation-cost measurements themselves (the actual deliverable)
**are** interleaved, 10 reps/cell, and their spread is tight (<15% range per
cell — see raw table below), so contention does not appear to have corrupted
the number that this report is built on. Treat the three one-off *fit* times
(7.3s / 43.9s / 113.4s) as context, not as a validated scaling law.

---

## 1. MEASURED: cost of one production Laplace `obj$fn()` evaluation

Real `gllvmTMB()` fits, Bernoulli-logit, T = 20 traits, q = 2, ordinary
`latent(1 | site, d = 2, unique = FALSE)`, `se = FALSE` (drop `sdreport` —
out of scope for this question). Fit once per n, then 10 interleaved
`obj$fn(opt$par)` calls per n (visiting n=200 → 800 → 1600 → 200 → … each
rep), reporting the median.

| n | fixed pars | random pars (n·q) | fit time (s, one pass) | opt iterations |
|---:|---:|---:|---:|---:|
| 200 | 59 | 400 | 7.3 | 65 |
| 800 | 59 | 1600 | 43.9 | 151 |
| 1600 | 59 | 3200 | 113.4 | 208 |

**`obj$fn()` single-evaluation cost, median of 10 interleaved reps (s):**

| n | median | min | max |
|---:|---:|---:|---:|
| 200 | 0.0040 | 0.004 | 0.005 |
| 800 | 0.0180 | 0.017 | 0.018 |
| 1600 | 0.0355 | 0.035 | 0.041 |

Per-unit cost is close to constant: 2.00e-5, 2.25e-5, 2.19e-5 s/unit
(mean 2.156e-5 s/unit). A log-log fit across the three points gives

```
time ≈ exp(-11.10) · n^1.055        (R-side power-law fit, 3 points)
```

i.e. **`obj$fn()` scales close to linearly in n (exponent ≈ 1.05)** — as
expected, since TMB's Laplace inner solve for this model is block-diagonal
by unit (each unit's random effect only enters its own row of the
likelihood), so the sparse Cholesky factorization is effectively n
independent q×q solves and the per-node evaluation cost is dominated by that
block structure, not by any global n×n dense operation.

**DERIVED (extrapolated, not directly measured):** projecting to Ayumi's
cell, n = 5397, T = 20, q = 2:

- linear per-unit extrapolation: 2.156e-5 × 5397 ≈ **0.116 s**
- power-law extrapolation: exp(-11.10) × 5397^1.055 ≈ **0.131 s**

Call it **≈ 0.12 s per `obj$fn()` evaluation at Ayumi's scale** (order-of-
magnitude; the two extrapolation methods agree to ~13%). This is a **3x
extrapolation past the largest measured n (1600 → 5397)** — flagged as
DERIVED, not measured, and the true value could plausibly differ by 20-30%
without changing any conclusion below, since the conclusions turn on
ratios, not absolute seconds.

---

## 2. Cost model: mode-solve vs. per-node cost, using the O3 prototype

### 2a. What AGHQ actually shares with Laplace

`tests/testthat/helper-aghq-o3.R::.o3_q2_log_integral()` (the existing,
unmodified q=2 O3 helper) already implements the efficient structure the
brief asks about:

```r
.o3_q2_log_integral <- function(y, n_trials, eta_fixed, loading, nodes) {
  rule <- .o3_gh(nodes)
  m <- .o3_q2_mode(y, n_trials, eta_fixed, loading)   # ONE mode+Hessian solve
  grid <- as.matrix(expand.grid(rule$x, rule$x))       # H^2 nodes
  u <- sweep(sqrt(2) * t(backsolve(m$R, t(grid))), 2L, m$mode, "+")
  a <- apply(u, 1L, m$log_density) + lw + rowSums(grid^2)   # H^2 cheap evals
  ...
}
```

`.o3_q2_mode()` is called **once** per unit (a BFGS solve for the 2-d
conditional mode, plus the Hessian at that mode — architecturally identical
to what Laplace's inner Newton solve already does; the O3 spike states the
1-node AGHQ product **is** the Laplace identity). The H² quadrature nodes
are then built by one cheap affine transform of that single mode/Cholesky,
and each node is a closed-form density evaluation (`m$log_density`, no
further optimization). So: **the brief's premise is correct** — a per-node
evaluation is cheaper than a full Laplace evaluation, because the expensive
part (finding the mode, factoring the Hessian) is shared across all H^q
nodes and done once, not H^q times. This is NOT automatic — it requires the
adaptive-quadrature implementation to actually reuse one mode/Hessian per
unit, which the O3 prototype does but which is a design commitment a real
implementation must also make (a naive re-optimize-per-node AGHQ would not
have this property — see the "naive" rows in §3-4 for how bad that would
be).

### 2b. Measured ratio: mode-solve cost vs. per-node marginal cost

Single-unit fixture, T = 20 traits, q = 2, Bernoulli, matching §1's cell.
Timed in batches of 200 calls (proc.time() elapsed-clock resolution is too
coarse for single sub-millisecond calls), 50 interleaved blocks/cell.

| H | H² (nodes) | median full time (s) | ratio to mode-alone |
|---:|---:|---:|---:|
| 1 | 1 | 0.000335 | 1.595 |
| 3 | 9 | 0.000410 | 1.952 |
| 5 | 25 | 0.000490 | 2.333 |
| 7 | 49 | 0.000605 | 2.881 |
| 9 | 81 | 0.000745 | 3.548 |

(mode-solve alone, median of 50×200 calls: **0.000210 s**)

A linear fit `full_time = FIXED + MARGINAL × (H^q nodes)` across these five
points is an excellent fit (R² = 0.990, all coefficients significant at
p<0.001):

```
FIXED    = 3.5325e-4 s   (per-unit call overhead: mode solve + grid setup)
MARGINAL = 4.9621e-6 s   (marginal cost of ONE additional quadrature node)
```

So in this uncompiled R prototype, **one quadrature node costs about 1/71 of
the fixed mode-solve+setup cost** (3.5325e-4 / 4.9621e-6 ≈ 71.2), or about
1/42 of the bare mode-solve alone (2.10e-4 / 4.9621e-6 ≈ 42.3). Node
evaluations are cheap relative to the solve, confirming the brief's premise
directionally — but this specific ratio is measured in an **R-interpreted
loop** (`optim()`, `apply()`), not the compiled TMB C++/AD-tape machinery a
real feature would use. Compiling would very likely shrink *both* terms, and
there is no measurement here of whether it would shrink them by the same
factor. **This is the single largest assumption in the projection below**,
stated explicitly, not measured: *the compiled implementation preserves the
same relative ratio between mode-solve cost and per-node cost that the R
prototype shows.* If compiled per-node cost falls faster than compiled
mode-solve cost (plausible — nodes are pure arithmetic, the mode solve
needs iterative Newton steps with repeated AD passes), the projections below
are pessimistic (AGHQ-LA would be cheaper than projected). If the reverse
holds, they are optimistic.

---

## 3. Projected AGHQ-LA cost at Ayumi's cell (n=5397, T=20, q=2)

Using `ratio(H,q) = (FIXED + MARGINAL·H^q) / mode_alone` from §2b, applied
as a multiplier on the measured Laplace numbers from context (fit 590s,
`obj$fn()` ≈ 0.12s at Ayumi scale from §1), under the assumption that AGHQ-LA
needs a **similar number of outer optimizer iterations** as Laplace (this is
itself unmeasured — no AGHQ-LA optimizer trace exists to check it against;
if AGHQ's smoother/more-accurate surface converges in fewer iterations the
projection is pessimistic, if it needs more (e.g. from grid-induced
non-smoothness) it is optimistic):

| H | nodes (H²) | ratio to Laplace | projected `obj$fn()` (s) | projected FULL FIT (s) | vs Laplace (590s) | vs VA-JJ (6815s) | vs VA-GH (8313s) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 5 | 25 | 2.27x | 0.27 | **~1340 s (~22 min)** | 2.3x slower | **5.1x faster** | **6.2x faster** |
| 9 | 81 | 3.60x | 0.42 | **~2120 s (~35 min)** | 3.6x slower | **3.2x faster** | **3.9x faster** |

The O3 spike's own node ladder (q=2, joint-Laplace difference 9.8e-8 at
1 node; 7-vs-9-node difference below 1e-4) says H=7 is already converged, so
H=5 is close to sufficient and H=9 is comfortably past convergence — meaning
the **cheaper** row (H=5, ~22 min) is the operationally relevant one, not
H=9.

**Contrast with the naive (wrong) H^q multiplier.** If a real
implementation did NOT reuse one mode/Hessian per unit across all H^q nodes
— i.e. re-solved the mode at every node, the architecturally naive way to
build a quadrature rule — the multiplier would be H^q directly, not the
§2b ratio:

| H | naive multiplier (H²) | naive projected fit (s) |
|---:|---:|---:|
| 5 | 25x | 14,750 s (~4.1 h) — worse than both VA arms |
| 9 | 81x | 47,790 s (~13.3 h) — far worse than both VA arms |

This is the gap between "AGHQ is cheap" and "AGHQ is catastrophically
expensive": it lives entirely in whether the implementation shares the
mode/Hessian solve across nodes. The O3 prototype already does this
correctly; a production implementation must preserve that design or the
brief's "linear in node count" claim fails.

**Bottom line at q=2, CONDITIONAL on §3.5 below (MEASURED cost structure +
DERIVED extrapolation + stated assumptions):** AGHQ-LA at Ayumi's scale,
done the way the O3 prototype already does it, projects to roughly **22–35
minutes** — 2–4x slower than Laplace's 590s, but **3–6x faster than either
VA arm** (6815s / 8313s), while (per the separate, out-of-scope-here
accuracy claim in the brief) strictly improving on Laplace's accuracy with
each added node. **This number assumes the outer optimizer gets an
AD-native gradient of the AGHQ objective, as cheap as Laplace's own `gr()`
call. §3.5 reports that this is not currently demonstrated to exist in this
codebase, and the fallback that IS demonstrated to work (finite differences)
is roughly 20x more expensive** — which would put AGHQ-LA at 2–4 hours,
worse than both VA arms, not better. Read the two numbers together, not the
first one alone.

### 3.5. Critical caveat: does a cheap gradient exist? (it is not shown to)

The §3 table above prices only **function evaluations**. An outer optimizer
needs **gradients**. Laplace's `obj$gr()` is fast because TMB differentiates
the whole Laplace-marginalized objective by reverse-mode AD in roughly a
small constant multiple of one `fn()` call (typically ~2-4x, not measured
separately here). **Whether an equivalently cheap gradient exists for the
AGHQ objective is exactly the question a separate, sibling investigation in
this same worktree already asked and answered: no, not yet.**
`dev/aghq-scope-gap.md` (a different lens/agent, same session lineage, dated
today) tested the natural shortcut directly — reusing
`obj$env$spHess(theta, random = FALSE)` as the fixed×random cross-block
needed for an implicit-function-theorem gradient chain through the per-unit
mode — and found it **returns exact zero at cross-block positions that a
finite difference on `obj$env$f(theta, order=1)` shows are genuinely
nonzero (3.37, not small-and-truncated)**. That shortcut does not work. No
other AD-native gradient path for the AGHQ objective is demonstrated to
exist in this repo today; the O3 prototype's own mode/Hessian functions are
plain-R (`optim()`, closed-form curvature), not AD-differentiable through
the implicit mode either.

**What this means for the cost model.** Without new AD/C++ work, the
gradient a real AGHQ-LA outer optimizer could actually use today is a
**finite-difference** gradient over the p = 59 fixed parameters (T=20
traits, q=2 → 59 fixed effects, MEASURED, constant across n). A rough
order-of-magnitude inflation, using a forward-difference gradient
((p+1) AGHQ-objective evaluations per outer gradient call) against an
assumed AD-native `gr()`/`fn()` cost ratio of ~3x (typical for TMB
reverse-mode AD, not separately measured here):

```
inflation ≈ (p + 1) / 3 ≈ 60 / 3 ≈ 20x
```

Applied to the §3 numbers:

| H | §3 projection (AD-gradient assumed) | with finite-difference fallback (≈20x) |
|---:|---:|---:|
| 5 | ~1,341 s (22 min) | **~26,800 s (~7.4 h)** |
| 9 | ~2,122 s (35 min) | **~42,400 s (~11.8 h)** |

Under the finite-difference fallback, AGHQ-LA at q=2 is **worse than both
VA arms** (6815s / 8313s), not better — the opposite of §3's headline. This
20x figure is explicitly a rough back-of-envelope (AGENT-INFERRED, not
measured): it assumes the finite-difference step count and TMB's typical
AD gr()/fn() ratio, neither separately measured in this brief. But the
qualitative point does not depend on getting 20x exactly right: **the whole
"AGHQ-LA is cheap" conclusion in §3 rests on an AD-native gradient chain
that has been actively checked for and not found**, not merely left
unmeasured. Building one (a real C++/AD Laplace-style implementation inside
`src/gllvmTMB.cpp`, generalizing the `obj$env$spHess(random=TRUE)` per-unit
curvature block that IS confirmed to work generically per
`dev/aghq-scope-gap.md` §3) is a prerequisite for §3's number to be
achievable, not an optional refinement.

---

## 4. The q-scaling table — where AGHQ-LA stops being viable

`H^q` (nodes per unit) for H ∈ {5, 9}, q ∈ {1..5}, and the projected full-fit
time at Ayumi's cell under the §2b shared-solve ratio model (`590 ×
ratio(H,q)`), against the naive H^q model for contrast:

| q | H | H^q (nodes) | ratio (shared-solve model) | projected fit (shared-solve) | projected fit (naive H^q) |
|---:|---:|---:|---:|---:|---:|
| 1 | 5 | 5 | 1.80x | 1,062 s (18 min) | 2,950 s |
| 1 | 9 | 9 | 1.90x | 1,118 s (19 min) | 5,310 s |
| 2 | 5 | 25 | 2.27x | 1,341 s (22 min) | 14,750 s |
| 2 | 9 | 81 | 3.60x | 2,122 s (35 min) | 47,790 s |
| 3 | 5 | 125 | 4.64x | 2,735 s (46 min) | 73,750 s |
| **3** | **9** | **729** | **18.9x** | **11,156 s (3.1 h) — already worse than VA-GH (8313s)** | 430,110 s |
| **4** | **5** | **625** | **16.5x** | **9,706 s (2.7 h) — already worse than VA-GH (8313s)** | 368,750 s |
| 4 | 9 | 6,561 | 156.7x | 92,461 s (25.7 h) | 3,870,990 s |
| 5 | 5 | 3,125 | 75.5x | 44,559 s (12.4 h) | 1,843,750 s |
| 5 | 9 | 59,049 | 1397x | 824,206 s (9.5 days) | 34,838,910 s |

**Viability crossover, under the shared-solve model (the O3 prototype's own
architecture, not the naive strawman):**

- **q = 1–2: clearly viable.** Faster than both VA arms at either node
  count (H=5 or H=9).
- **q = 3: borderline, node-count dependent.** H=5 (46 min) stays faster
  than both VA arms; H=9 (3.1 h) is already slower than VA-GH. Whether q=3
  is viable therefore depends on whether H=5 is numerically sufficient —
  the O3 q=2 ladder converged by H=7, so this is plausible but **not
  verified at q=3**, where the O3 spike text explicitly stops ("no q ≥ 3
  implementation ... is justified here").
- **q = 4: not viable at either node count.** Even H=5 (2.7 h) exceeds
  VA-GH's 8313s; H=9 is 25.7 hours.
- **q = 5: not viable.** H=5 alone is 12.4 hours; H=9 is 9.5 days.

So the honest answer to "at what q does it die" is **q = 3 is the hinge, q =
4 is where it is unambiguously dead** under this model — not q = 2 as the
O3 spike's node-count argument alone (81 vs. 729 raw points) would suggest,
and not "never" as a naive reading of "AGHQ is linear in node count, and
Laplace already scales well" might suggest either. The reason it survives
one dimension further than the raw `H^q` table implies is exactly the
shared-mode-solve saving in §2; the reason it still dies by q=4-5 is that
**no constant ratio saves you from exponential growth** — `H^q` is the
dominant term in the linear cost model too, once it grows large enough to
swamp the fixed per-unit overhead. This is the same structural limit the O3
spike already named (`n_q^q` growth), sharpened here into an actual
time-to-die.

**One thing this table cannot tell you:** whether q=3-4 is even a regime
Ayumi's models need. gllvmTMB ordination cells more commonly run q=2-3; if
q=4-5 is rare, the practical ceiling above matters less. That is a modeling
question, out of scope for this cost brief.

---

## 5. Sparse-grid / dimension-reduced quadrature

**I do not know, and I am not speculating a number.** This repository has
no sparse-grid or Smolyak quadrature implementation anywhere in `R/` or
`dev/` — the only in-repo mention is a single open research question in
`docs/dev-log/research/2026-07-19-highdim-inference-local-sister-inventory.md`
(item 5: "What dimensional/sparsity regimes make adaptive or sparse-grid
quadrature competitive with Laplace or structured VA for latent dimensions
1–3 versus larger stacked-trait fields?") — posed, not answered, not
implemented.

What can be said without measurement, as textbook orientation only (NOT a
projection, NOT a number to plan around): sparse-grid methods (e.g.
Smolyak/nested Gauss-Hermite, as used by the standalone `aghq` R package)
reduce node count from `H^q` toward something sub-exponential for smooth
integrands at moderate q, but they do not remove the exponential dependence
entirely, add implementation complexity (nested rules, sometimes negative
weights, different conditioning behavior), and — critically for this
codebase — would be a **new C++/AD-tape implementation inside the TMB
template**, not a parameter change to the existing dense-tensor-grid
approach the O3 spike prototyped. Whether it would push the q=3-4 viability
hinge found in §4 out to q=5-6 or further is unknown without building and
measuring it. That is future scoping work, not this brief.

---

## Assumptions exposed (summary)

1. AGHQ-LA needs a similar number of **outer optimizer iterations** as
   Laplace to converge (unmeasured — no AGHQ-LA optimizer trace exists).
2. The **ratio** between mode-solve cost and per-node marginal cost measured
   in the uncompiled R prototype (§2b, ~42-71:1) **carries over** to a
   compiled TMB C++/AD-tape implementation. Not measured; could go either
   direction.
3. A production AGHQ-LA implementation **reuses one mode/Hessian solve per
   unit across all H^q nodes**, exactly as the existing O3 prototype already
   does (§2a). If it does not, §3-4's "naive" column is the honest number,
   and AGHQ-LA is not competitive with VA even at q=2.
4. `obj$fn()` cost at Ayumi's n=5397 is **extrapolated** (3x past the
   largest measured n=1600), not measured directly; two extrapolation
   methods agree to ~13%.
5. The three one-pass Laplace fit times (7.3/43.9/113.4s, §1) are
   **contention-unverified** (this machine's load average was 28-34
   throughout); only the interleaved per-evaluation `obj$fn()` timings (the
   number this report is built on) were checked for stability and were
   found tight (<15% spread per cell).
6. **§3's headline number assumes an AD-native gradient for the AGHQ
   objective, at Laplace-like cost.** §3.5 reports this is actively checked
   for elsewhere in this worktree (`dev/aghq-scope-gap.md`) and not found;
   the demonstrated fallback (finite differences over p=59 fixed
   parameters) is roughly 20x more expensive (rough order-of-magnitude, not
   measured), which reverses the "AGHQ-LA beats VA" conclusion. This is the
   single most consequential open assumption in this report.

## Confidence labels

- **MEASURED:** §1 `obj$fn()` costs at n=200/800/1600; §2b mode-solve vs.
  per-node ratio in the R prototype; §3.5's `spHess(random=FALSE)`
  zero-cross-block finding (measured in `dev/aghq-scope-gap.md`, cited not
  re-derived here).
- **DERIVED** (arithmetic/extrapolation from measured numbers, assumptions
  stated): §1 Ayumi-scale `obj$fn()` extrapolation; §3-4 projected fit
  times (conditional on §3.5's AD-gradient assumption holding).
- **AGENT-INFERRED / speculative, explicitly flagged as such, not to be
  treated as a plan input:** §5's qualitative sparse-grid orientation; §3.5's
  ~20x finite-difference inflation factor (order-of-magnitude only, built on
  an unmeasured AD gr()/fn() cost ratio assumption of ~3x).
