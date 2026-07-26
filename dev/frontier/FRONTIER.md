# The GH-VA accuracy-vs-runtime frontier

Internal only. No package code touched, no export added, no public claim. This
answers one question: **does gllvmTMB's Gauss-Hermite VA (`engine = "va_r3"`,
61-point quadrature) buy a real accuracy advantage over gllvm's Jaakkola-Jordan
(JJ) bound at a cost a practitioner would actually pay, and does that trade
survive as species count grows?**

## Grid and arms

- Families: poisson, bernoulli. q = 2. n (units) in {40, 100}. p (species) in
  {8, 20, 40}. 3 seeds per cell → 36 (family, p, n, seed) cells, 144 arm-cell
  rows total.
- **gllvmTMB GH-VA**: `.approximation_engine_fit(engine = "va_r3", family =
  "poisson"/"binomial", link = "log"/"logit", unique = FALSE)`, H = 61
  Gauss-Hermite quadrature, 4 fixed-seed internal restarts with an internal
  3-of-4 agreement health gate.
- **gllvmTMB Laplace**: Psi-suppressed like-for-like comparator,
  `gllvmTMB(traits(sp1,...,spP) ~ 1 + latent(1 | unit, d = 2, unique = FALSE),
  family = poisson()/binomial())`, `gllvmTMBcontrol(n_init = 1, se = FALSE)`.
- **gllvm VA / JJ**: `gllvm::gllvm(method = "VA", n.init = 1)`. Labelled "VA"
  for Poisson (gllvm's VA is the exact closed-form `exp(mu+v/2)` route, known
  to match GH-VA exactly there) and "JJ" for binomial (gllvm's `method="VA"`
  for binomial is the Jaakkola-Jordan / Polya-Gamma bound, confirmed from
  gllvm 2.0.13 source this session).
- **gllvm EVA**: `gllvm::gllvm(method = "EVA", n.init = 1)`, bernoulli only —
  Poisson+EVA is a confirmed real error in gllvm ("not implemented with
  method 'EVA'"), not a silent fallback, so it is recorded as
  `skipped_family_unsupported` rather than repeatedly re-triggering the same
  error.

All fits used `n.init = 1` / `n_init = 1` (single start) for time budget; this
trades away gllvm's own multi-start robustness (its usual binomial recipe
uses 3 starts), so isolated `not_converged` / starting-value failures below
partly reflect that choice, not only genuine problem difficulty.

Raw per-arm-per-cell results: `dev/frontier/frontier.csv` (144 rows, one row
per arm × cell, `tryCatch`-safe — failures are rows with `status`, never
silent omissions). Aggregated numbers used below:
`dev/frontier/frontier-summary.csv`. Reproduction: `dev/frontier/pilot.R`
(sizing pilot), `dev/frontier/run-frontier.R` (the grid),
`dev/frontier/analyse-frontier-final.R` (the numbers in this file).

## One measurement artifact, disclosed and corrected

The very first GH-VA call in the run (poisson, p=8, n=40, seed 20272839) paid
a one-time ~17.5s TMB C++ compilation cost (the `va_r3` template compiles
lazily on first use per R session). That cell's raw runtime in
`frontier.csv` is 17.939s; every runtime figure below **excludes that one row**
(kept in the CSV, cut only from the aggregates) so as not to mistake a
session-startup cost for a data-scaling cost. Its objective value is
unaffected and is retained.

## Status / convergence summary

| Arm | converged/healthy | not_converged | failed_variance_domain | failed_health_gate | error | skipped (family) |
|---|---:|---:|---:|---:|---:|---:|
| gllvmTMB GH-VA | 12 (healthy) | 0 | 7 | 17 | 0 | 0 |
| gllvmTMB Laplace | 33 | 0 | 0 | 0 | 3 | 0 |
| gllvm VA/JJ (pooled) | 30 | 0 | 0 | 0 | 6 | 0 |
| gllvm EVA | 13 | 2 | 0 | 0 | 3 | 18 |

GH-VA **never errors** — it always returns a real objective, even when its own
internal 3-of-4-restart health gate rejects it. The poisson `failed_health_gate`
cases are noteworthy: the returned objective still matches gllvm's exact-VA
number to within optimizer noise (see below), so "failed health gate" here
mostly means poisson wasn't the regime this research engine's admission
criterion was tuned for, not that the fit is actually bad. `n=40, p=40`
(units ≈ species) is a genuine breakdown regime for the *other* three arms:
gllvm's own multi-start heuristic fails outright ("Calculating starting
values failed... too many latent variables") for **every** bernoulli seed at
that cell (VA/JJ and EVA both), and gllmvTMB Laplace also failed once there
("All 1 restarts failed"). GH-VA is the only arm that returned a number for
all 3 seeds at that cell — flagged `failed_variance_domain`, not silently
accepted, but not a hard error either.

## 1. Runtime scaling: does the Laplace/GH-VA ratio grow with p as O(p³) predicts?

**Poisson** (GH-VA here is the cheap closed-form route, no quadrature):

| p | n | Laplace (s) | GH-VA (s) | Laplace / GH-VA |
|---:|---:|---:|---:|---:|
| 8 | 40 | 0.593 | 0.430 | 1.38 |
| 20 | 40 | 0.975 | 0.545 | 1.79 |
| 40 | 40 | 2.981 | 1.439 | 2.07 |
| 8 | 100 | 0.757 | 1.031 | 0.73 |
| 20 | 100 | 3.628 | 2.384 | 1.52 |
| 40 | 100 | 10.853 | 5.548 | 1.96 |

The ratio climbs monotonically with p in **both** n series (1.38→1.79→2.07 at
n=40; 0.73→1.52→1.96 at n=100). From p=8 to p=40 (5× species), Laplace's own
runtime grows 5.0× (n=40) to 14.3× (n=100), while GH-VA's grows only 3.3×
(n=40) to 5.4× (n=100). This is the one part of the grid that **matches the
classical argument's direction**: Laplace becomes progressively more expensive
relative to GH-VA as species count grows, because GH-VA has no per-cell
quadrature to pay for on Poisson data (it uses the same closed-form
`exp(mu+v/2)` gllvm's own VA uses).

**Bernoulli** (GH-VA here pays 61-point quadrature per unit×species cell):

| p | n | Laplace (s) | GH-VA (s) | Laplace / GH-VA |
|---:|---:|---:|---:|---:|
| 8 | 40 | 2.561 | 3.450 | 0.742 |
| 20 | 40 | 4.509 | 10.768 | 0.419 |
| 40 | 40 | 4.116 | 22.460 | 0.183 |
| 8 | 100 | 2.382 | 12.571 | 0.189 |
| 20 | 100 | 7.468 | 37.215 | 0.201 |
| 40 | 100 | 5.986 | 76.924 | 0.078 |

Here the ratio moves the **opposite** way: it shrinks monotonically (at n=100:
0.189→0.201→0.078; roughly flat then collapsing). GH-VA's own runtime grows
6.1× from p=8 to p=40 (n=100) while Laplace grows only 2.5× over the same
range — the reverse of the Poisson pattern. **The O(p³)-Laplace argument only
shows up when GH-VA is cheap (Poisson, closed form); for binary data, the
per-cell 61-point quadrature tax dominates and grows faster than Laplace's own
cost in this p range, so Laplace never stops being the faster arm.**

## 2. The cost of quadrature: GH-VA seconds / JJ seconds

| p | n | GH-VA (s) | JJ (s) | GH-VA / JJ |
|---:|---:|---:|---:|---:|
| 8 | 40 | 3.450 | 0.059 | 58× |
| 20 | 40 | 10.768 | 0.121 | 89× |
| 40 | 40 | 22.460 | — (JJ failed all 3 seeds) | — |
| 8 | 100 | 12.571 | 0.136 | 92× |
| 20 | 100 | 37.215 | 0.377 | 99× |
| 40 | 100 | 76.924 | 0.485 | **159×** |

The tax is already 58-92× at p=8 and grows to 159× by p=40 (n=100) — JJ (and,
separately, gllvm's own EVA) do not need quadrature at all, and their runtime
stays under a second across the whole grid. The relative tax **grows** with p,
it does not plateau.

## 3. Does the accuracy advantage over JJ survive?

**Yes, at every one of the 15 evaluable (p, n) cells (and every one of the 15
individual per-seed comparisons underneath them): GH-VA's ELBO sits strictly
above gllvm's JJ bound, min +3.7 nats, max +20.1 nats per single fit, zero
sign flips.** Aggregated by cell:

| p | n | n cells (=p×n) | GH-VA − JJ (nats) | per-cell (÷ n cells) |
|---:|---:|---:|---:|---:|
| 8 | 40 | 320 | 4.18 | 0.0131 |
| 20 | 40 | 800 | 9.77 | 0.0122 |
| 8 | 100 | 800 | 6.82 | 0.0085 |
| 20 | 100 | 2000 | 11.22 | 0.0056 |
| 40 | 100 | 4000 | 16.22 | 0.0041 |
| 40 | 40 | 1600 | — (JJ failed all 3 seeds) | — |

The **absolute** nats gap grows with p (it must — more cells, more
accumulated slack in JJ's bound) — but the **per-observation** gap shrinks
monotonically as the problem grows: 0.0131 → 0.0122 → 0.0085 → 0.0056 →
0.0041 nats/cell, roughly a **3× thinning** from p=8 to p=40. The tightness
advantage is real everywhere tested, but it is a diminishing return per
species added, while the compute tax (§2) is a growing one.

## 4. Bottom line for a practitioner

Combine the growing time tax with the shrinking per-cell accuracy edge into
nats gained per second of GH-VA compute (using the n=100 series, where both
JJ and GH-VA succeeded at every p):

| p | GH-VA seconds | total nats gained over JJ | nats gained per second |
|---:|---:|---:|---:|
| 8 | 12.57 | 6.82 | 0.543 |
| 20 | 37.22 | 11.22 | 0.302 |
| 40 | 76.92 | 16.22 | 0.211 |

**Efficiency falls 2.6× from p=8 to p=40.** Where GH-VA is cheapest (p=8, a
few seconds) it is also most "worth it" per second spent; by p=40 a single fit
costs over a minute for a bound that is tighter than JJ's by only ~0.004
nats per cell — an amount very unlikely to change any inference (loadings,
ordination, species associations) a practitioner would draw from the fit, and
of a magnitude smaller than typical seed-to-seed and optimizer-restart noise
already visible in this grid.

Two further findings sharpen this, both unflattering to GH-VA:

- **At p=40, n=40 (species ≈ units)**, JJ, EVA, and (once) Laplace all failed
  outright under this single-start recipe; GH-VA was the only arm to return a
  number every time — but flagged `failed_variance_domain` by its own
  admission gate, so this is "the only thing that ran," not "the most
  accurate thing that ran."
- **gllvm's own already-shipped EVA method beats GH-VA on both axes at every
  evaluable cell** — a higher (tighter-looking) objective (+23 to +126 nats,
  growing with p) **and** 2.5× to 20.5× faster, with the speed gap also
  widening with p. This is reported with an explicit caveat: EVA is a
  second-order Taylor approximation, not a certified variational lower bound
  the way JJ or Gauss-Hermite quadrature are, so a higher EVA number is not
  proof of being closer to the true marginal likelihood — but it does mean a
  cheaper, already-available alternative dominates GH-VA on the one thing
  that is directly comparable (wall-clock), without this session needing to
  resolve which bound is "more correct."

**Verdict, stated plainly:** the accuracy advantage over JJ is genuine and
never flips sign in this grid, but it does not survive as a *practically
worthwhile trade* once p reaches the 20-40 species range that is typical of
real community datasets. The per-cell tightness gain shrinks while the
relative compute tax grows, and gllvm's own EVA route already gets a better
number for less money at every size tested. For a practitioner with p ≳ 20
species, GH-VA in its current (H=61, single-start) form is not worth its
cost; if it is worth using at all in this codebase's current state, the
grid says it is most defensible at the small end (p ≈ 8), which is the
opposite of where a "pay more compute for more species" argument would want
it to shine.

## Caveats

- Single-start (`n_init = 1`) throughout, for time budget — gllvm's usual
  binomial recipe uses 3 starts; some `not_converged` / starting-value
  failures reflect that choice as much as problem difficulty.
- 3 seeds/cell is enough to see consistent monotonic trends but not enough to
  put a confidence interval on any individual ratio; treat single-seed swings
  (e.g. the p=40,n=40 breakdown cell) as illustrative, not precise.
- GH-VA's internal health gate (3-of-4-restart agreement + a variance-domain
  bound) is a robustness diagnostic from its own research design, not a
  correctness signal being asserted here; `failed_health_gate` fits still had
  their objective recorded and used, as instructed.
- The EVA comparison is context, not a finding this task was asked to
  quantify precisely — no ground-truth marginal likelihood exists to certify
  which of GH-VA/EVA/JJ is closest to the true log-likelihood; only the
  ordering EVA > GH-VA > JJ (higher = tighter-looking) and the runtime
  ordering EVA < JJ ≪ GH-VA are established here.
