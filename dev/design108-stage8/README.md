# Design 108 s0.2 -- Laplace silent-divergence rate

**Role:** Fisher. **Script:** `laplace-silent-divergence.R`. **Worktree:**
`/private/tmp/gllvmtmb-design108-stage4` (branch `claude/design108-stage4-probit`,
cut from `origin/main` `910ebd54`). Results are LOCAL only (D-50) -- never a
GitHub artifact, never committed.

## The question

The SHIPPED Laplace engine already fits binomial-probit, ordinal_probit, and
missing-response data today, with no code changes (`R/enum.R:20,27`,
`R/families.R:779`, `src/gllvmTMB.cpp:142,299,2122,2268`; verified by reading,
not re-derived). Separately, `dev/degeneracy/DETECTOR.md` measured that on one
Totoro grid (bernoulli/poisson, logit link, no missingness), 70/601 usable
`gtmb_laplace` fits (11.6%) were degenerate by `rel_frob > 10` against known
truth, and 59 of those 70 (84%) reported the package's own clean signal
(`convergence = 0`, `pdHess = TRUE`) -- i.e. silently. `docs/dev-log/
2026-07-30-heywood-gate-false-positive-sweep.md` section 7 separately found
that `gllvmTMBcontrol(aghq_ridge = 2)` fixes one such reproduction fit
(`||Lambda||_F` 979.1 -> 3.352), on the Laplace path.

**This campaign asks:** at what rate does that silent-divergence pattern occur
specifically on binomial-probit, ordinal-probit, and missing data, at
realistic size -- and does the ridge control change that rate? The answer
prices whether the 26-42 day Gate-A programme (presumably: VA-engine
robustness work) is worth running at all, versus the cheaper Laplace-path
remedy already available.

## The corrected #847 boundary

An earlier revision treated "67% runaway at n = 1600" as a general property
of the loading ridge. That was wrong in two ways. The number belonged to the
`laplace_ridge` arm, not `aghq_ridge`, and only to the binomial-logit,
`p = 6`, `sigma_lambda = 3` cell. The 2026-08-02 reproduction recorded in
`R/gllvmTMB.R` shows the interaction clearly: the corresponding `p = 12`
cells had zero runaways at every n, and probit/ordinal-probit had zero at the
large-n hard-loading cell. The ridge was strongly protective elsewhere.

The design therefore still spans `sigma_lambda = 0.7` and `3.0`, but for the
right reason: to measure regime dependence rather than to confirm a presumed
general 67% failure rate. No pooled statement about ridge safety or failure is
licensed by one family/shape cell.

## The Totoro n=1600 probe that resolved the affordability uncertainty

After the sigma_lambda revision above, the maintainer ran one real Totoro
probe (pinned `origin/main` `910ebd54`, installed package,
`OPENBLAS_NUM_THREADS=1`, one seed) at exactly Part B's most expensive
corner: `n = 1600, p = 27, q = 2, binomial-probit, sigma_lambda = 3`:

| arm | seconds | rel_frob | convergence |
|---|---|---|---|
| `default` | 37.6 | 0.178 | 0 |
| `ridge2`  | 35.2 | 0.148 | 0 |

Two consequences, both taken as given (not re-verified by me -- reported by
the maintainer, from a Totoro run I did not have access to and was
instructed not to attempt):

1. **~37s/fit at the most expensive corner makes heavy replication cheap**
   (720 Part-B fits at that cost / 96 workers is on the order of minutes,
   not hours). This retired the "3-seed compromise" from the prior revision
   -- it was the right call under the earlier uncertainty, but the
   uncertainty is now gone for binomial-probit specifically.
2. **Neither arm diverged on this one seed** (`rel_frob < 0.2` for both,
   against this design's own `rel_frob > 10` degenerate threshold), while
   the local n=60 smoke had `default` at `rel_frob = 605` under the same
   `sigma_lambda = 3`. This is a hint -- **one seed, not a result** -- that
   silent divergence may be a small-n phenomenon that decays with n,
   consistent with `dev/degeneracy/DETECTOR.md`'s own within-bernoulli
   dose-response (79% degenerate at n=40 down to 1% at n=400). If that
   holds at this campaign's scale too, the cheap small-n cells carry most of
   the rate signal, and the expensive n=1600 rung mainly serves to establish
   whether/where the problem goes away -- both are decision-relevant, and
   the design keeps both rather than dropping either.

## ADEMP

- **Aims:** estimate the silent-divergence rate (defined below) of
  `gllvmTMB()`'s default Laplace engine on {binomial-probit, ordinal_probit,
  gaussian-control} x {0%, 30% missing} x {default control, `aghq_ridge = 2`}
  x {`sigma_lambda` 0.7 mild, 3.0 the #847 ridge-failure regime}, across a
  realistic n/p ladder reaching toward Ayumi's BIRDBASE scale (n = 5397,
  p = 27, q = 2). `sigma_lambda` is now the most decision-relevant axis in
  the design (see "The #847 finding" above) -- more than missingness.
- **Data-generating mechanism:** see "Why this DGP is realistic" below. One
  DGP family ("homog": uniform per-trait loading SD), now measured at TWO
  loading-SD regimes (0.7 mild, 3.0 the documented #847 ridge-failure
  regime), no engineered sparsity or quasi-separation at either regime.
- **Estimands:** per-cell silent-divergence rate; secondary: `rel_frob`
  distribution, `attenuation`, convergence/pdHess agreement with `rel_frob`,
  and the shipped `check_gllvmTMB()` `binomial_prevalence_loading` row's
  agreement with the truth-based label (opportunistic, not the primary
  metric -- that check is calibrated for logit-link binomial specifically,
  per `dev/heywood/link-coverage.R`'s own header note).
- **Methods:** one Laplace fit per grid cell (`gllvmTMB()`, `unit = "site"`,
  `latent(0 + trait | site, d = q, unique = FALSE)`), Sigma_B extracted as
  `tcrossprod(fit$report$Lambda_B)` (the rotation-invariant Gram, matching the
  brief's metric definition exactly -- not `extract_Sigma_B()`, which
  DETECTOR.md flags as possibly including a link-implicit residual on the
  diagonal for some families).
- **Performance measures:** `silent_divergent = rel_frob > 10 & convergence
  == 0 & pdHess == TRUE`, tabulated by family x arm x sigma_lambda x
  missingness x n x p.

## Metric

```
rel_frob = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F
Sigma_true = Lambda_true %*% t(Lambda_true)
Sigma_hat  = tcrossprod(fit$report$Lambda_B)
degenerate       := rel_frob > 10
silent_divergent := degenerate & (fit$opt$convergence == 0) & isTRUE(fit$sd_report$pdHess)
```

This is exactly `dev/degeneracy/DETECTOR.md`'s definition. `fit$report$Lambda_B`
is the same field `dev/heywood/link-coverage.R` and `dev/heywood/
missing-and-spatial-coverage.R` already use for their `binomial_prevalence_loading`
checks, so the metric is directly comparable to that prior work.

## Arms

Two `control =` values per fit, crossed with every other factor:

- **`default`**: `gllvmTMBcontrol()` -- `aghq_ridge` is NOT named by the
  caller, so it stays inert on the Laplace path (verified by reading
  `R/gllvmTMB.R:1496-1512`: `aghq_ridge_explicit <- !missing(aghq_ridge)`
  gates whether the ridge fires; the argument's own default value of `2`
  never applies unless the caller writes `aghq_ridge = ...` explicitly, by
  design, to avoid silently repenalising every existing fit).
- **`ridge2`**: `gllvmTMBcontrol(aghq_ridge = 2)` -- the caller names it, so
  the ridge fires.

This is the single most important design requirement per the brief: without
it, the campaign would only measure the un-remedied rate, and the false-positive
sweep doc already shows that rate may not reflect what a user gets once they
apply the (already-shipped) one-line control change.

**Why `default` is the headline number.** `aghq_ridge` defaults to `2` as a
`gllvmTMBcontrol()` *argument* (`R/gllvmTMB.R:1454`), but on the Laplace path
it is opt-in ONLY: `R/gllvmTMB.R:1512` reads
`aghq_ridge_explicit <- !missing(aghq_ridge)`, and the rationale at
`R/gllvmTMB.R:1506-1511` states plainly that applying the argument's own
default on the Laplace path "would silently penalise every existing fit"
were it not gated this way. **A user who calls `gllvmTMB()` with no
`control =` argument at all -- the overwhelmingly common case -- gets NO
ridge**, regardless of what `formals(gllvmTMBcontrol)$aghq_ridge` shows. So
the `default`-arm silent-divergence rate is what actually happens to today's
users; the `ridge2`-arm rate is what happens only to a user who has already
read this far into the control docs and opted in.

**Smoke evidence this arm distinction matters** (see below): at one seed,
binomial-probit `default` gave `rel_frob = 197.5` (silently: `conv = 0`,
`pdHess = TRUE`); the same DGP realisation under `ridge2` gave
`rel_frob = 0.65` (healthy). Same draw, opposite outcome, arm is the only
difference.

## Families

- **`binomial_probit`**: `stats::binomial(link = "probit")`, response `y`.
- **`ordinal_probit`**: `gllvmTMB::ordinal_probit()`, K = 4 categories, fixed
  cutpoints `tau = c(0, 0.7, 1.4)` (matches `tests/testthat/
  test-ordinal-recovery-depth.R`'s convention), response `value`.
- **`gaussian_control`**: `stats::gaussian()`, response `y`, residual SD 0.4.
  **Positive control** -- if this family also shows a non-trivial
  silent-divergence rate, that implicates the harness itself (DGP or
  extraction code), not something binomial/ordinal-probit-specific, and the
  result should not be trusted until the harness is fixed.

All three use the same formula shape:
`<response> ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE)`.

## Missingness

`miss in {0, 0.3}`: after generating the full response vector, a `miss`
fraction of cells is set to `NA` (uniform at random over the flattened
`n * p` vector), then fit with the package's DEFAULT missing-data handling
(`miss_control()`, i.e. `response = "drop"`). This already exercises the
missing-response path at `src/gllvmTMB.cpp:142` -- `dev/heywood/
missing-and-spatial-coverage.R` PART 1 uses the identical injection idiom and
default handling, and its header note confirms `response = "drop"` already
reaches that code path; no explicit `miss_control(response = "include")` call
is required to test it. (`response = "include"` changes which cells
`predict_missing()` can return, not which likelihood is optimised -- out of
scope for this rate measurement.)

## Why this DGP is realistic

`dev/heywood/link-coverage.R` defines three DGP arms via `loading_sd()`:
`homog` (uniform SD = 0.7), `sparse50` (half the traits at SD = 0.05, half at
1.0), and `sparse75` (75% at SD = 0.05). The brief flagged `sparse75` as
**adversarial by design** -- it is built to manufacture failures for detector
calibration and produces a ~73% degenerate rate, which is not a rate anyone
should read as "how often does this happen in practice."

This campaign uses **only the `homog` shape** (uniform per-trait loading SD,
no per-trait heterogeneity, no engineered near-zero loadings that would
starve some traits' identification) -- never `sparse50`/`sparse75`. That is
the least adversarial of the three published DGP *shapes* in
`link-coverage.R`. Within that shape, the loading SD itself is now a design
factor at two levels:

- `sigma_lambda = 0.7` -- an unremarkable, moderate ordination signal
  strength, not a constructed edge case.
- `sigma_lambda = 3.0` -- the evaluated hard-loading regime. The earlier 67%
  failure result applied only to the Laplace-ridge, binomial-logit, `p = 6`
  cell; it is not a general statement that the ridge remedy fails throughout
  this design. The level is retained so that this programme measures the same
  demanding loading scale without transferring that route-specific verdict.

Trait-level intercepts are drawn `N(0, 0.3)` at both `sigma_lambda` levels,
matching `link-coverage.R`'s and `missing-and-spatial-coverage.R`'s own
convention for "ordinary" prevalence variation (not extreme-prevalence
separation, which is a separate, already-studied failure mode in
`docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md`).

**Caveat, stated plainly:** "realistic" here means "not adversarially
engineered by this campaign," not "empirically matched to any specific real
dataset's loading distribution." No real-data loading-SD survey backs either
the 0.7 or the 3.0 choice; 0.7 is inherited from the existing `homog`
convention in the two reused scripts, and 3.0 is inherited from the #847
measurement already on record in this repo's own source comments. **A
conclusion of "the ridge fixes silent divergence" drawn only from the
`sigma_lambda = 0.7` cells would be invalid** -- it would silently exclude
the one regime the package's own code comments say the ridge already fails
in most of the time.

## n/p/q ladder -- reaching toward Ayumi's scale

Two parts, both crossed with `sigma_lambda in {0.7, 3.0}`:

- **Part A** (main grid): `n in {60, 150, 400}`, `p in {12, 27}` (RESTORED
  -- see "What was traded" below), `seed in 1:20`. Realistic
  small-to-moderate community-ecology sizes; `p = 27` matches Ayumi's trait
  count exactly, and is now present at every `n` in Part A, not only at
  Part B's single large-n rung.
- **Part B** (large-cell probe): `n = 1600` (moved from 1500 so the design
  measures the same large-n boundary examined in #847), `p = 27` (Ayumi's trait
  count), `seed in 1:30` (raised from 1:3 -- see "What was traded" below).
  This reaches *toward* Ayumi's `n = 5397` (about 30% of the way) without
  matching it -- no Laplace fit time at anywhere near n = 5397 was measured
  before writing this script (the only such timing evidence in the repo,
  `docs/dev-log/2026-07-28-morning-brief.md`, is for a VA-GH fit with a
  block-diagonal Schur solve, not this Laplace path). n = 1600 itself is no
  longer an open cost question -- see the Totoro probe above.

`q = 2` throughout, matching Ayumi's `q = 2`.

### What was traded (revised on measured Totoro cost)

**Round 1** (sigma_lambda added, cost unmeasured): adding a 2-level
`sigma_lambda` axis, crossed with everything, would have doubled the grid
from 780 to 1560 cells if nothing else changed. Under that uncertainty I
swapped Part A's `p` axis for `sigma_lambda` (Part A fixed at `p = 12`) and
cut Part B's seed from 5 to 3, landing at 792 cells total.

**Round 2** (this revision, cost now measured): the maintainer's Totoro
probe (~37s at the single most expensive corner, n=1600/p=27/sigma_lambda=3)
showed the Round-1 affordability constraint no longer binds, so both Round-1
cuts are reversed and go further:

1. **Part A's `p` axis is RESTORED to `{12, 27}`**, now crossed with
   `sigma_lambda` (not swapped for it) -- Part A regains the p=12-vs-27
   contrast at moderate n that Round 1 gave up.
2. **Part A's `seed` raised from 10 to 20** -- affordable because small-n
   fits are ~1-7s (measured), and per the Totoro probe's hint (silent
   divergence may concentrate at small n), this is also where replication
   is most valuable.
3. **Part B's `seed` raised from 3 to 30** -- 3 seeds can only return
   0/33/67/100%, which is not a usable rate estimate for a regime-dependent
   failure probability; 30 is affordable at the measured ~37s/fit cost for
   binomial-probit, but see the wall-clock section below for the important
   caveat that this is NOT affordable at the same confidence for
   `ordinal_probit`, whose cost at n=1600 was never measured.

Net: Part A 2880 + Part B 720 = **3600 cells**, up from 792. This is a
genuine, deliberate cost increase (not a wash like the Round-1 trade), made
because the Round-1 constraint that justified staying near 780 cells no
longer holds.

## Reuse

- `dev/totoro-grid/run-grid.R`: the mirai-daemon Totoro-runner idiom
  (`GRID_SMOKE`/`GRID_WORKERS` env vars, `daemons()`/`mirai_map()`/
  `.progress`, `OPENBLAS_NUM_THREADS=1` pinned inside every worker, results
  written to `~/gllvm_work/results` as `.rds` + `.csv`). Carried over
  essentially unchanged; `GRID_FIT_SECONDS` was dropped because the source
  script accepted but never used it.
- `dev/heywood/link-coverage.R`: the probit fit+score idiom (`loading_sd`
  DGP shape, `tcrossprod(Lambda_B)` rel_frob, `check_gllvmTMB()`'s
  `binomial_prevalence_loading` row, `.gllvmTMB_max_loading_by_trait()`).
- `dev/heywood/missing-and-spatial-coverage.R` PART 1: the NA-injection
  idiom and confirmation that default missing-data handling already reaches
  the C++ missing-response path.
- `dev/degeneracy/DETECTOR.md`: the `rel_frob`/degenerate/silent-divergence
  metric definitions, read but not re-run (its cross-arm trace-ratio
  detector is a candidate follow-on analysis on this campaign's output, not
  something this script computes).

## Smoke test (run, GREEN)

Re-run after the sigma_lambda revision, on the updated `GRID_SMOKE` subset,
which now covers the mild corner AND the new #847 worst-case corner:

```
cd /private/tmp/gllvmtmb-design108-stage4
GRID_SMOKE=TRUE GRID_WORKERS=4 Rscript dev/design108-stage8/laplace-silent-divergence.R
```

4 cells (binomial_probit, miss = 0, n = 60, p = 12, seed = 1; both arms x
both `sigma_lambda` levels), completed in 1.9s wall-clock. Output: non-empty,
non-NA, in-range.

```
family miss arm      sigma_lambda n  p q seed seconds status conv pdHess objective  rel_frob attenuation check_status
binomial_probit 0 default 0.7 60 12 2 1 1.242 OK 0  TRUE -431.91 197.4921  181.4666  WARN
binomial_probit 0 ridge2  0.7 60 12 2 1 0.945 OK 0 FALSE -405.55   0.6461    1.3657  PASS
binomial_probit 0 default 3.0 60 12 2 1 1.812 OK 0  TRUE -268.67 605.0226  440.1548  WARN
binomial_probit 0 ridge2  3.0 60 12 2 1 0.818 OK 0  TRUE -260.70   0.7915    0.2806  PASS
```

- `sigma_lambda = 0.7` (mild, as before): `default` silently degenerate
  (`rel_frob = 197.5`, `conv = 0`, `pdHess = TRUE`); `ridge2` recovers
  (`rel_frob = 0.65`).
- `sigma_lambda = 3.0` (the #847 regime): `default` silently degenerate and
  markedly WORSE (`rel_frob = 605.0`, `conv = 0`, `pdHess = TRUE`); `ridge2`
  ALSO recovers here (`rel_frob = 0.79`, `conv = 0`, `pdHess = TRUE`).

**Read this carefully, and do not over-read it.** At this one seed, at the
SMALLEST n (60), the ridge recovered even at `sigma_lambda = 3`. That is
NOT a general ridge result: this smoke deliberately used `n = 60` to stay
fast. A single small-n seed recovering tells us only that the harness
distinguishes the two `sigma_lambda` regimes and produces valid output at
both. It says nothing about the large-n, link, or trait-count interactions
that the full grid was designed to measure.

An additional, non-shipped ad hoc check from the first review round (not
part of `GRID_SMOKE`, not re-run this round) fit one `ordinal_probit` and
one `gaussian_control` cell at the same tiny size and `sigma_lambda = 0.7`:
`ordinal_probit` (`default` arm) also showed silent divergence (`rel_frob =
310.7`, `conv = 0`, `pdHess = TRUE`, 6.8s); `gaussian_control` (`default`)
recovered cleanly (`rel_frob = 0.27`, 0.14s) -- the positive control behaves
as it should.

## Totoro launch command

```
ssh totoro   # once, for Duo, if the ControlMaster socket is not already live
# on Totoro:
cd ~/gllvm_work   # or wherever this worktree/branch is checked out on Totoro
GRID_SMOKE=FALSE GRID_WORKERS=96 Rscript dev/design108-stage8/laplace-silent-divergence.R
```

Results land in `~/gllvm_work/results/design108-stage8-grid.{rds,csv}` on
Totoro. Per D-50, rsync them back and keep them local -- never a GitHub
artifact, never committed to this repo.

**This script has NOT been launched at grid scale.** The brief gates the
full-grid launch on the orchestrator's review of this smoke; nothing beyond
the two local smokes above and one ad hoc single-cell check per non-binomial
family has been run.

## Honest wall-clock estimate (full grid, 96 workers) -- measured basis

Two real anchors now exist, both binomial-probit:
`(n=60, p=12)` -> ~1.2s (mean of the 4-row local smoke), and
`(n=1600, p=27, sigma_lambda=3)` -> ~36.4s (mean of the maintainer's Totoro
probe, 37.6s/35.2s). Fitting a power law in problem size
(`cost = 1.2 * (n*p/720)^alpha`) to these two points gives
`alpha = ln(36.4/1.2) / ln(43200/720) = 0.83` -- i.e. cost grows a bit
slower than linearly in `n*p`, which is a plausible shape for a sparse
Laplace solve. Using this to interpolate the untested `(n,p)` cells (150,
400 x 12, 27) gives, for **binomial-probit**:

| n | p=12 | p=27 |
|---|---|---|
| 60 | 1.2s (measured) | 2.4s |
| 150 | 2.6s | 5.1s |
| 400 | 5.8s | 11.5s |
| 1600 | -- | 36.4s (measured) |

For **gaussian-control**, scaling the same shape by the measured
n=60/p=12 ratio (0.14/1.2 = 0.117x binomial) gives roughly 0.14-1.3s across
Part A and ~4.3s at Part B's n=1600 cell (not directly measured at n=1600,
extrapolated only).

**`ordinal_probit` is the flagged gap (per the maintainer's item 5).** Its
only anchor is the single n=60/p=12 local measurement, 6.8s -- about 5.7x
binomial's 1.2s at that same cell. Applying that single ratio across the
whole ladder (there is no reason to believe it is right at other `n`/`p`,
since ordinal's extra cost driver -- K-1 cutpoints per trait -- is a
structurally different problem from binomial's loading-only likelihood, and
it has NEVER been measured at `p = 27` or at any `n > 60`):

| n | p=12 | p=27 |
|---|---|---|
| 60 | 6.8s (measured) | 13.4s |
| 150 | 14.6s | 28.7s |
| 400 | 33.0s | 65.1s |
| 1600 | -- | ~206s (~3.4 min, pure extrapolation) |

**Serial-time roll-up** (cells x mean cost per family, using the tables
above):

| | cells | binomial | gaussian | ordinal | family total |
|---|---|---|---|---|---|
| Part A | 960/family | 4560s | 530s | ~25,900s | |
| Part B | 240/family | 8740s | 1020s | ~49,500s | |
| **total** | | 13,300s | 1,550s | **~75,400s** | **~90,200s (~25 h)** |

**`ordinal_probit` alone is ~84% of total serial compute**, despite being
exactly 1/3 of the cells, driven entirely by the unverified 5.7x
per-fit-time multiplier. At 96 workers with dynamic dispatch (`mirai_map` +
`dispatcher = TRUE`) and 3600 cells >> 96 workers, wall-clock should track
serial-time/96 reasonably well: **~90,200s / 96 ~= 940s ~= 15-16 minutes**,
plausibly 15-25 minutes allowing for daemon startup and imperfect
load-balancing on the slower ordinal cells.

**Does ordinal x n=1600 x 30 seeds blow the budget? No, on this estimate --
but the estimate itself rests on one unverified extrapolation factor.** At
~15-25 minutes total, the grid stays comfortably affordable even with
ordinal dominating serial compute. I am NOT proposing a trim. What I am
proposing instead, because so much of the estimate's honesty rides on a
single untested multiplier: **run one more real Totoro probe -- one
`ordinal_probit` fit at `n=1600, p=27, sigma_lambda=3`** (mirroring exactly
what was just done for binomial) before the full launch. That single fit
would replace the whole ordinal-at-scale column above with a measured
number instead of a 5.7x guess, at a cost of one fit (a worst case of a few
minutes even if ordinal turns out far slower than extrapolated). If that
probe comes back much higher than ~206s, the cheap lever is to cut ordinal's
Part-B seeds specifically (e.g. 30 -> 15) while leaving binomial and
gaussian at 30, rather than cutting the whole grid.

## Open design decision I am not sure about

**The ordinal-at-scale extrapolation, not replication depth.** Replication
depth is resolved for the two families with real timing evidence
(binomial-probit measured directly; gaussian-control's shape is at least
anchored at the small-n end). `ordinal_probit`'s cost at `n = 1600` and at
`p = 27` (at ANY n) is pure extrapolation from one small-n/small-p data
point, using a scaling exponent (`alpha = 0.83`) borrowed from binomial with
no reason to think it transports to a family whose parameter count (cutpoints)
scales differently. If the true ordinal cost at n=1600 is, say, 3x higher
than my ~206s guess, the grid is still probably fine (adds a few more
minutes of wall-clock) -- but if it is 10x higher, ordinal's Part B alone
could become the dominant cost. I would rather resolve this with one more
cheap Totoro probe than guess further.
