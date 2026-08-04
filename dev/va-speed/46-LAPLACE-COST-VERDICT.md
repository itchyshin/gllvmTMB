# Where the shipped Laplace engine's time goes — and what that means for VA

**Scope.** The verdict document the profiling fleet (`wf_e3a1cbdf-1e6`) never wrote. Its
raw output — six `41-ladder-*.rds` cells — was on disk but unread; the handover recorded
only the single `N=2500, q=5` cell. This reads the whole grid, and adds the paired
VA-vs-LA measurement that the grid implies but cannot itself supply.

**What this is not.** `dev/va-speed/PROFILE.md` is a *different* document from a *different*
lane (`claude/va-speed-arc`, cut from `origin/main` @ `19e9cedd`). It profiles the VA-R3
engine on a 20-core Mac. This one profiles the **shipped Laplace engine** on Totoro. They
answer different questions and their numbers are not interchangeable.

**Regime.** Every number below: binomial-probit, `NTR = 6`, `T = 20` traits,
`latent(0 + trait | unit, d = q, unique = FALSE)`, Totoro, `OPENBLAS_NUM_THREADS = 1`,
one seed per cell. Instrumentation is `trace()` around `MakeADFun` / `nlminb` / `sdreport`,
validated against `Rprof` to ~1pp in `38`/`39`.

---

## 1. The grid

| N | q | total s | nlminb | **sdreport** | MakeADFun | iters | n_fixed | n_random | load |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 250 | 2 | 17.11 | 58.3% | **39.3%** | 2.6% | 159 | 59 | 500 | 1.78 |
| 1000 | 2 | 70.55 | 60.0% | **37.8%** | 2.5% | 169 | 59 | 2000 | 1.96 |
| 2500 | 2 | 190.09 | 61.4% | **36.5%** | 2.4% | 185 | 59 | 5000 | ⚠ 35.52 |
| 250 | 5 | 76.76 | 71.2% | 28.1% | 0.7% | 445 | 110 | 1250 | 5.31 |
| 1000 | 5 | 393.99 | 77.3% | 22.2% | 0.5% | 634 | 110 | 5000 | 2.69 |
| 2500 | 5 | 1012.12 | 77.4% | **22.1%** | 0.5% | 674 | 110 | 12500 | 3.15 |

⚠ The `N=2500, q=5` row is the one the handover quoted. ⚠ The `N=2500, q=2` cell was
measured at **load 35.52**, the only contaminated row in the grid; its absolute seconds
should be treated as an upper bound. Every other cell ran at load ≤ 5.3.

## 2. Three corrections to the handover

**(a) `sdreport` is 22–39%, not 22%.** The handover quoted the grid's *minimum*. The share
is largest at `q = 2` (36.5–39.3%) — that is, **the free lever is biggest on the cheap,
common fits**, not the expensive rare ones. Making `sdreport` optional for users who want
only point estimates remains the best-value lever in this profile, and it is worth more
than the handover credited. It is statistically free: `sdreport` computes standard errors,
not estimates.

**(b) "The lever is the 674 outer iterations" is a `q = 5` statement.** At `q = 2` the same
N range needs 159–185 iterations. Iteration count grows only weakly with N in both arms
(159→185 and 445→674 over a 10× N range); it is the *per-iteration* cost that carries the
growth. Ranking "reduce outer iterations (conditioning)" as a top lever generalises one
cell of six.

**(c) The shipped Laplace engine is essentially LINEAR in N.** Fitted exponents:

| quantity | q=2 | q=5 |
|---|---:|---:|
| total wall-clock vs N | N^1.05 | N^1.12 |
| `nlminb` per-iteration cost vs N | N^1.00 | N^0.98 |

This is the load-bearing finding, and the handover had no way to see it from one cell. It
matters because the whole VA arc is premised on Laplace scaling badly.

## 3. The consequence: VA is SLOWER than Laplace, at every configuration measured

`43-va-vs-la-ladder.R` pairs the two engines **on the same dataset inside one process**, so
box load cancels in the ratio — the lesson from the 12-seed head-to-head. `n_starts = 1`
for VA (multistart is a separate, already-measured ~3.88× multiplier). The LA arm
**cross-validates the harness**: 159 iterations at `N=250, q=2`, identical to
`41-ladder-N250_q2.rds`.

| cell | H | VA s | LA s | verdict |
|---|---:|---:|---:|---|
| N=250, q=2, seed 1 | 61 (shipped default) | 173.78 | 20.09 | VA **8.6× slower** |
| N=250, q=2, seed 2 | 61 | 171.38 | 20.21 | VA **8.5× slower** |
| N=250, q=2, seed 3 | 61 | 183.37 | 17.92 | VA **10.2× slower** |
| N=250, q=2, seed 1 | 15 | 53.02 | 19.97 | VA **2.65× slower** |

The H=15 arm exists because `PROFILE.md` profiled `H = 15` while a user gets the formal
default `H = 61`. The confound is real and now measured: 173.78 → 53.02 s, a 3.3× swing,
consistent with GH quadrature being ~75–82% of a VA fn/gr call (`PROFILE.md` §Q1) and
linear in H. **But it does not change the sign.** Even at the configuration most
favourable to VA, VA is 2.65× slower than the engine it was supposed to accelerate.

**This contradicts the arc's founding premise** — ledger claim "VA is 5.8× faster than our
own Laplace" (`f3df8193`). **Regime caveat, per the arc's own primary discipline:** that
claim was measured on a matched model whose exact configuration is not recorded in the
handover and which I have not reproduced; the cells here are binomial-probit, T=20, q=2,
`unique = FALSE`, `n_starts = 1`. The two are not the same cell. What is established is
narrower and still decisive for the roadmap: **on the cells the Laplace profiling fleet
itself measured, VA loses at both H.**

**Not yet answered:** whether the gap widens or narrows with N. The `N ∈ {1000, 2500}`
cells were still running when this was written; `43-vala-N*.rds` carries them, with
right-censored entries for any cell that never finishes. That is the remaining half of
OWED step 2 and it decides whether VA has a large-N regime where it wins.

## 4. Ranked levers, revised

1. **Make `sdreport` optional.** 22–39% of wall-clock, no statistical cost, largest where
   fits are cheapest. Unambiguously the best lever in this profile.
2. **Reduce outer iterations via conditioning** (the loadings-diagonal pinning gllvm uses —
   `21-WHY-GLLVM-IS-FAST.md`). Still worth doing, but it is a `q = 5` lever, and
   `va-conditioning-audit-vs-gllvm.md` already rates it highest-effort/highest-risk.
3. **Do not spend further effort making VA faster until §3 is closed.** If VA is slower
   than Laplace at every N, its intervals are not the question.

## 5. Provenance

Raw: `41-ladder-{N250,N1000,N2500}_{q2,q5}.rds` (fleet `wf_e3a1cbdf-1e6`),
`43-vala-*.rds` (this session). Scripts: `41-profile-ladder.R`, `43-va-vs-la-ladder.R`.
Results are LOCAL per D-50; nothing here is promoted, advertised, or in NEWS.
