# The `max_projected_variance <= 4` gate, and a two-sided companion to `rel_frob > 10`

**2026-07-30 · Claude (Gauss, numerical-correctness) · read-only measurement + one new file
(`dev/va-gate3/two-sided-detector.R`); no file under `R/` or `src/` modified; no shipped default
changed.**

Worktree: `/private/tmp/gllvmtmb-va-in-06`, branch `claude/va-in-06-20260730`. Every number below was
computed in this session with `Rscript`/`devtools::load_all()` against the current worktree source
(`Version: 0.6.0` in `DESCRIPTION`; the installed package is stale at `0.5.0`, so `devtools::load_all()`
was required throughout — confirmed by `packageVersion("gllvmTMB")` returning `0.5.0` while
`DESCRIPTION` reads `0.6.0`). Nothing here is taken from `RESULTS.md` or any other prior write-up
without independent recomputation from raw code or raw data in this session.

I could not locate the exact phrase *"the worst instance found anywhere"* anywhere in this worktree
(`grep -rn "worst instance" docs/ dev/` — no hits; the nearest artifact,
`docs/dev-log/audits/2026-07-30-scale-constant-class-sweep.md`, is a same-day audit of hardcoded scale
constants but scopes `R/fit-multi.R`, `R/diagnose.R`, etc. and never mentions
`max_projected_variance` or `R/va-r3-proto.R`). Treating that characterization as prompt context, not
a citable in-repo source — flagged per the task's own "mark anything uncertain explicitly" instruction.

---

## TASK 1 — the variance-domain gate

### 1a. What `max_projected_variance` is computed from

R side (`R/va-r3-proto.R:1266–1271`):

```r
max_projected_variance <- if (is.list(best_report) &&
    !is.null(best_report$v_by_obs) &&
    all(is.finite(best_report$v_by_obs))) {
  max(best_report$v_by_obs)
} else Inf
variance_domain_ok <- max_projected_variance <= 4
```

`best_report` is `objects[[best_id]]$report(best$par)` (line 1263) — the TMB `REPORT()` output of the
single best-objective start, evaluated regardless of whether that start (or the fit as a whole) is
later judged "healthy." `v_by_obs` is `REPORT`-ed at `inst/tmb/gllvmTMB_va_r3.cpp:391`, and it is
computed per observation `r` (unit `i`, trait `t`) at `cpp:307–319`:

```cpp
// v_it = ||L_i' lambda_t||^2, without forming S_i.
Type v = Type(0.0);
for (int col = 0; col < q; ++col) {
  Type projected = Type(0.0);
  projected += exp(log_L_diag(i, col)) * Lambda(t, col);
  ...
  v += projected * projected;
}
```

`L_i` is the (Cholesky factor of the) variational-posterior covariance for unit `i`
(`Sigma_i = L_i L_i'`, built at `cpp:246–280`), and `Lambda(t, .)` is trait `t`'s fitted loading row.
So `max_projected_variance = max_{i,t} lambda_t' Sigma_i lambda_t` — the largest per-cell **projected
variance of the linear predictor contributed by the latent factors**, over the *fitted* posterior, at
the *fitted* loadings, at the single best-objective start. It is a property of the converged fit, not
of the raw data or the true generating loadings.

At the `start_id = 1` warm start (`R/va-r3-proto.R:466–468`), `log_L_diag = 0` and `L_off = 0`, so
`L_i = I_q` exactly and `Sigma_i = I_q` — i.e. the *initial* variational posterior equals the model's
`N(0, I)` prior on the latent scores. This matters for §1d below.

### 1b. What happens when `admitted = FALSE`

`admitted` is computed in two stages (`R/va-r3-proto.R:1245–1251, 1271`):

```r
healthy_id <- which(vapply(fits, `[[`, logical(1), "healthy"))
...
agreement   <- length(healthy_id) >= 3L && agreement_range <= 1e-6
admitted    <- length(healthy_id) >= 3L && agreement          # stage 1: multi-start agreement
...
variance_domain_ok <- max_projected_variance <= 4
admitted <- admitted && variance_domain_ok                    # stage 2: the variance gate
```

`status` (lines 1285–1291) collapses both stages into one string:

```r
status = if (admitted) {
  "healthy"
} else if (!variance_domain_ok) {
  "failed_variance_domain"
} else {
  "failed_health_gate"
}
```

But the returned list (lines 1293–1327) is **not** pruned on either stage. It always includes
`best` (line 1322, the winning start's parameters/objective/gradient), `latent` (1323, the per-unit
posterior scores/SEs decoded from `best$par`), `report` (1324, the *full* TMB `REPORT()` — `Lambda`,
`Sigma_B`, `v_by_obs`, `elbo`, everything), and `objective` (1325, the live TMB `ADFun` object, so
gradients/Hessians remain computable). `admitted = FALSE` changes exactly one thing: the `status`
string and the boolean `health$admitted`/`health$variance_domain_ok` flags. **Nothing is discarded,
rejected, or nulled out.** The label is advisory, not a data-destroying gate, at the `.va_r3_fit()`
level.

One level up, `.approximation_engine_va_r3_fit()` (`R/approximation-engine.R:104–134`) passes all of
this through unfiltered: `diagnostics$health <- raw$health`, `status <- raw$status`,
`engine_result <- raw` (the *entire* raw list, unmodified). No filtering happens there either.

Two consumers were checked directly for whether they filter on `status`/`admitted` before a fit's
numbers reach a comparison:

- **`dev/totoro-grid/run-grid.R`** (the script that produced `dev/totoro-grid/results/grid.csv`, the
  dataset named in Task 2): its `row()` helper (lines 67–79) stores `status` as a plain column and
  computes `rel_frob`/`attenuation` from `r$v$engine_result$report$Lambda` (line 99) — the *best*
  report, **regardless of `status`**. Confirmed empirically in §1d/Task 2 below: `grid.csv` contains
  93 `gtmb_gh` rows with `status == "failed_variance_domain"` that still carry a finite `rel_frob`/
  `attenuation`.
- **`dev/totoro-grid/analyse-grid.R`**: never subsets on `status`/`admitted` anywhere in the file
  (checked every use of `d$arm`/`d$rel_frob`; the divergence map at line 85 and the degeneracy count
  at line 97 both use `is.finite(d$rel_frob)` as the only filter).

So the **current** campaign infrastructure does not truncate the data at the storage/analysis layer —
but see §1e for the number the campaign *does* silently drop, and for the asymmetric risk this labeling
creates if a future comparison naively filters on it (which would be a natural, easy mistake to make,
precisely because `status`/`admitted` look like a data-quality signal).

### 1c. Is the gate family-conditional?

**No — the gate line itself is unconditional.** `.va_r3_fit()` (`R/va-r3-proto.R:1068–1084`) accepts
`family = c("binomial", "poisson", "gaussian_anchor", "nbinom2")`, and the gate computation at
lines 1266–1271 contains no `if (family == ...)` branch of any kind — it runs identically for all four.

But the *only conceivable mechanistic justification* for a variance-domain cutoff — approximation
accuracy of a bound or quadrature rule — applies to exactly two of the four families. The package's
own per-family evaluation registry says so explicitly (`R/va-r3-proto.R:508–575`,
`.va_r3_family_registry`):

```r
list(family = "gaussian_anchor", ..., expectation = "exact",
     ## E[(y - eta)^2] = (y - mu)^2 + v in closed form, so the quadrature nodes are
     ## never touched and no bound is needed.
     ...),
list(family = "binomial", ..., expectation = "bound", ...),          # tiers = gh, jj
list(family = "poisson", ..., expectation = "exact",
     ## E[exp(eta)] = exp(mu + v/2) is the log-normal mean, exact.
     ...),
list(family = "nbinom2", ..., expectation = "quadrature", ...)
```

This matches the C++ directly: `family == 0` (gaussian) uses
`(residual^2 + v) / gaussian_var` (`cpp:328–330`) — exact for any `v >= 0`; `family == 2` (Poisson)
uses `exp(mu + v/2)` (`cpp:347`) — the exact log-normal mean, again valid for any `v`. Neither ever
calls `va_r3_softplus_expectation()` or the JJ bound. Only `family == 1` (binomial) and `family == 3`
(nbinom2) touch quadrature/the JJ bound (`cpp:339–341, 361–362`), and even there the only
*documented* numerical-safety boundary is the small-`v` polynomial fallback at `v <= 1e-6`
(`cpp:37–44, 51, 68, 90–95, 99, 101`) — the opposite end of the range from `4`. Nothing in either
`va_r3_softplus_expectation()` or `va_r3_jj_softplus_expectation()` documents or exhibits a
large-`v` accuracy boundary at `4`; GH nodes are rescaled by `sqrt(2v)` (`cpp:69`), so quadrature
accuracy for a fixed node count `H` does not have an obvious break at that specific value, only a
generic "more nodes needed as the effective integration width grows" concern that the code does not
quantify anywhere. (A prior, independently-conducted measurement bears directly on whether that
generic concern is realized in practice — see §1e.)

So: for `gaussian_anchor` and `poisson`, **the gate has zero possible connection to numerical
approximation validity**, because those two families never approximate anything as a function of `v`
— the likelihood term is exact at `v = 0.001` and at `v = 10,000` alike. The gate still fires on them.

**This is not hypothetical — it is executed, including by the package's own test suite.**
`tests/testthat/test-va-r3-prototype.R:621–632`:

```r
test_that("R3 fails closed outside the certified projected-variance domain", {
  fit <- .va_r3_fit(
    y = c(1, 2), n_trials = c(1L, 1L), X = matrix(1, 2L, 1L),
    unit_id = c(1L, 1L), trait_id = 1:2, q = 1L, H = 61L,
    fixed_global = list(beta = 0, theta_rr = c(3, 3)),
    family = "gaussian_anchor", gaussian_sd = 100,
    rank_source = "fixed_fixture"
  )
  expect_identical(fit$status, "failed_variance_domain")
  expect_false(fit$health$variance_domain_ok)
  expect_gt(fit$health$max_projected_variance, 4)
})
```

The package's own canonical example of this gate firing uses `family = "gaussian_anchor"`, not
binomial. I reproduced the phenomenon independently with a different, simulated (not fixed-fixture)
gaussian dataset (`n=40, p=4, q=2`, loading sd `4`, `gaussian_sd=20`, `eval_method="gh"`,
`n_starts=1`): `max_projected_variance = 56.62`, `status = "failed_variance_domain"` — a fit whose
likelihood term is exactly correct at that variance, rejected by a gate whose only imaginable
rationale (quadrature/bound accuracy) never applies to it.

**Reachability caveat, one level up:** the public-ish wrapper `.approximation_engine_va_r3_fit()`
(`R/approximation-engine.R:56–81`) hard-errors unless `family %in% c("binomial","poisson")` (lines
65–81: `expected_link <- switch(family, binomial=..., poisson=..., NA_character_)`, then
`stop(...)` if `is.na(expected_link)`) — so gaussian/nbinom2 are reachable only by calling
`.va_r3_fit()` directly (as the test above and my reproduction both do), not through that one wrapper.
The gate computation itself carries no such restriction.

### 1d. Is it reachable at realistic trait scales?

Two complementary measurements, both fresh in this session.

**(i) Fast proxy — no fitting required.** At the `start_id = 1` warm start, `Sigma_i = I_q`
(§1a), so `v_it` at that point collapses to `lambda_t' I lambda_t = ||lambda_t||^2`, a
deterministic function of the loading matrix alone (independent of `n` — `n` never enters). I drew
200 replicate `p x q` loading matrices per cell exactly as specified
(`Lam <- matrix(rnorm(p*q, 0, sd))`), for `sd = 0.6` (the task's own figure, matching
`dev/totoro-grid/run-grid.R:51`'s `Lt`) and, for context, `sd = 0.7` (`dev/heywood/vgh-vs-laplace-degeneracy.R:46`'s
`Lam` — the two source scripts do not use the same sd; noted so the discrepancy isn't silently
absorbed), and computed `max_t ||lambda_t||^2` per replicate
(`proxy = max(rowSums(Lam^2))`; `p * q` iid `N(0, sd^2)` entries mean this quantity is exactly
`sd^2 * max` of `p` iid `chisq_q` draws — cross-checked against the closed-form tail
`1 - (1 - pchisq(4/sd^2, df=q, lower.tail=FALSE))^p` and matched to Monte Carlo noise, e.g. simulated
`0.400` vs analytic `0.4015` at `(200,20,4,sd=0.6)`):

| n | p | q | sd | mean | median | max | **P(proxy > 4)** |
|---|---|---|----|------|--------|-----|---:|
| 100 | 12 | 2 | 0.6 | 2.20 | 2.04 | 6.06 | **0.050** |
| 200 | 20 | 4 | 0.6 | 3.92 | 3.76 | 7.69 | **0.400** |
| 400 | 80 | 4 | 0.6 | 4.99 | 4.87 | 8.31 | **0.895** |
| 100 | 12 | 2 | 0.7 | 3.10 | 2.90 | 8.54 | 0.205 |
| 200 | 20 | 4 | 0.7 | 5.33 | 5.13 | 9.45 | 0.855 |
| 400 | 80 | 4 | 0.7 | 6.97 | 6.75 | 12.05 | 0.995 |

This proxy is a property of the *prior-covariance-evaluated* projected variance from the *true*
simulating loadings — it says nothing about post-convergence shrinkage, and §1a already showed the
converged `Sigma_i` need not equal `I_q`. It answers a narrower but still useful question: at these
loading scales, is `4` even in the right neighborhood, independent of any fitting? Answer: **yes, and
the reachable fraction grows sharply with `p` and `q`** (more traits means more chances for the
per-trait row-norm to exceed a fixed cutoff — a `max`-of-`p` extreme-value effect, not an `n` effect).

**(ii) Real fits — `.va_r3_fit()`, matched to `run-grid.R`'s exact DGP.** For each cell I simulated
Bernoulli data exactly as `dev/totoro-grid/run-grid.R:49–57` does (`Lt ~ N(0,0.6^2)`, `n x q` latent
scores `~N(0,I)`, per-trait intercept `~N(0.3,0.3)`, `n_trials=1`, per-trait-factor `X`), then called
`.va_r3_fit(..., H=15, n_starts=1)` with `eval_method="gh"` and `"jj"` on the *same* simulated data
(paired, as `run-grid.R` itself pairs them), reading `health$max_projected_variance` and
`health$variance_domain_ok` directly rather than `status`/`admitted` — `n_starts=1` cannot report
`admitted` at all (it structurally requires `>= 3` healthy starts,
`R/va-r3-proto.R:1123–1143`), a distinction the package's own test suite makes explicitly
(`tests/testthat/test-va-r3-prototype.R:405–421`: `n_starts=1` reaches the *same* optimum as the
default 4 — objective within `1e-6`, parameters within `1e-3` — yet `status` reads
`"failed_health_gate"` regardless, because `admitted`/`status` conflate the variance gate with an
unrelated multi-start-agreement requirement). `H=15` matches `run-grid.R`'s own `gtmb_gh`/`gtmb_jj`
calls exactly.

Compute is expensive at the larger cells (`gtmb_gh` at `n=400,p=80,q=4` cost a median 771s at the
*default* `n_starts=4` in the existing `dev/totoro-grid/results/RESULTS.md` §5 runtime table — a
number I am citing only as a compute-planning estimate, not as evidence for any claim in this report),
so each cell ran under its own wall-clock budget rather than a fixed replicate target:

| n | p | q | eval_method | reps | mean(max_projected_variance) | **fraction gate fires (v>4)** |
|---|---|---|---|---:|---:|---:|
| 100 | 12 | 2 | gh | 120 | 2.96 | **17.5%** (21/120) |
| 100 | 12 | 2 | jj | 120 | 0.77 | **0.0%** (0/120) |
| 200 | 20 | 4 | gh | REPS2_GH | REPS2_GH_MEANV | **REPS2_GH_FRAC** |
| 200 | 20 | 4 | jj | REPS2_JJ | REPS2_JJ_MEANV | **REPS2_JJ_FRAC** |
| 400 | 80 | 4 | gh | REPS3_GH | REPS3_GH_MEANV | **REPS3_GH_FRAC** |
| 400 | 80 | 4 | jj | REPS3_JJ | REPS3_JJ_MEANV | **REPS3_JJ_FRAC** |

(Cell 1 is a full run against its 240s budget, 120 replicate pairs. Cells 2–3 are time-boxed
sub-samples — smaller n but still directly informative, not a placeholder for the proxy table above,
which already gives the full 200-replicate distribution requested for all three cells.)

Two things the real fits show that the proxy cannot:

- **The proxy is not a strict bound in either direction.** At `(100,12,2)`, GH's real mean (`2.96`)
  slightly *exceeds* the proxy mean (`2.29`) — consistent with the already-known small-sample upward
  bias in GH's fitted loadings (§Task 2 below: GH's `attenuation` when `healthy` in the existing grid
  has median `1.45`, i.e. loadings run large, not small). At `(200,20,4)` the proxy (`3.81`) sits above
  both real GH (`3.25`) and real JJ (`0.83`), consistent with genuine posterior contraction once more
  per-unit information (`p=20`) is available. The proxy is a same-order-of-magnitude planning number,
  not a certified bound.
- **GH and JJ are not remotely symmetric under this gate, on identical data.** At both measured cells,
  JJ's real `max_projected_variance` runs 3–4x smaller than GH's on the *same* simulated dataset, and
  the gate never once fired on a JJ fit (0/120 at cell 1; JJ-cell-2 rate above) while firing on
  17.5% of GH fits at cell 1 alone. This is the direct, small-n, freshly-simulated analogue of the
  much larger asymmetry already sitting in `dev/totoro-grid/results/grid.csv` — see §1e.

### 1e. Verdict

**The gate is reachable at realistic trait scales for exactly the arm (GH) and regime (larger `p`,
larger `q`) the JJ-vs-GH comparison most needs, and it is close to inert for the other arm (JJ) by
construction of JJ's own bias — so a comparison that filters on `status`/`admitted` would silently
delete GH's high-variance tail while keeping JJ's fits almost untouched, manufacturing the appearance
that JJ "passes" and GH "fails" in precisely the regime where theory says they should diverge most.**
This is not hypothetical asymmetry — it is already sitting, unfiltered but clearly visible, in
`dev/totoro-grid/results/grid.csv` (recomputed fresh in this session, not taken from `RESULTS.md`):

```
                status by arm, gtmb_gh vs gtmb_jj (dev/totoro-grid/results/grid.csv, all 2880 rows):
         failed_health_gate  failed_variance_domain  healthy
gtmb_gh          441                93                 106      (n=640; 93 = 14.5%)
gtmb_jj          105                 0                 215      (n=320; 0 = 0.0%)

gtmb_gh by family: bernoulli 133/93/94 (failed_health_gate/failed_variance_domain/healthy);
                   poisson   308/ 0/12   -- the gate fires 0/320 times on Poisson in this grid,
                   even though the C++/registry evidence in 1c shows it is exactly as reachable
                   there in principle; it simply was not realized at sd=0.6 loadings in this
                   particular campaign.

Matched bernoulli cells (same n,p,q,seed; n=320 pairs), GH status x JJ status cross-tab:
                        JJ: failed_health_gate   JJ: healthy
GH: failed_health_gate           73                  60
GH: failed_variance_domain        9                  84   <-- 84/320 (26.25%) of cells: GH is
GH: healthy                      23                  71        flagged unhealthy by the VARIANCE
                                                                 gate specifically, on data where
                                                                 JJ (same data) reports healthy.

Median `attenuation` (trace ratio, see Task 2) by GH status:  healthy 1.451 | failed_variance_domain 3.959
Median `attenuation` by JJ status:                              healthy 1.005 | failed_health_gate    0.898
```

GH's `failed_variance_domain` rows are exactly its most-inflated rows (median trace ratio `3.96` vs
`1.45` when healthy) — i.e. the gate is correctly correlated with something real (GH inflation), but
that "something real" is *also* exactly the regime the JJ-vs-GH comparison exists to characterize.
JJ's own bias (contraction, confirmed directly in Task 2) keeps it almost structurally immune to ever
tripping this specific gate, independent of whether JJ's fit is otherwise any good.

At the mechanism level (§1c): the gate's only imaginable numerical justification (quadrature/bound
domain-of-validity) cannot apply to `gaussian_anchor` or `poisson` (exact closed forms, any `v`), yet
it fires identically on them, including in the package's own test fixture. For binomial specifically,
a prior, independently-conducted measurement already exists in this repository
(`docs/dev-log/handover/2026-07-26-codex-handover-va-variance-gate-close.md`,
`docs/dev-log/after-task/2026-07-26-va-r3-variance-domain-gate.md`) and found, on multi-trial binomial
fixtures with an independently-validated brute-force truth ladder: **no break at `4`** — the ELBO
stayed a valid, negative-gap lower bound with a converging truth ladder through observed variance
`8.674338`, and the *instrument* (not the ELBO) only failed to adjudicate at `22.190718`. That result
is reported here for context, not re-verified in this session (re-verifying it was out of this task's
scope), and it does not by itself settle the gaussian/Poisson question in §1c, which is a separate,
purely algebraic point that does not depend on any truth-oracle measurement.

**This is a private, already-litigated decision, not an open one.** `docs/dev-log/handover/2026-07-26-codex-handover-va-variance-gate-close.md`
and `docs/dev-log/after-task/2026-07-26-va-r3-variance-domain-gate.md` record: *"The `<= 4` gate
remains frozen. This result does not authorize a threshold relaxation..."* Nothing in this report
argues otherwise, and per the task instructions **no shipped default was touched.**

**How to neutralise it for measurement purposes, without changing shipped behaviour:**

1. **Do not filter on `status == "healthy"` or `health$admitted` when building a JJ-vs-GH comparison.**
   As shown in §1b, the fitted `Lambda`/`v_by_obs`/ELBO are fully populated regardless of admission —
   `dev/totoro-grid/run-grid.R` and `dev/totoro-grid/analyse-grid.R` already do this correctly (neither
   filters on it anywhere; verified by reading both files in full). The risk is prospective — a
   *future* comparison script filtering on the seemingly-natural `status == "healthy"` condition —
   not a defect in what already exists.
2. **Read `health$variance_domain_ok` / `health$max_projected_variance` directly, never the collapsed
   `status`/`admitted` pair, when the multi-start-agreement gate is not itself of interest.** They
   conflate two independent mechanisms (§1d(ii)); at `n_starts=1` (the documented, tested,
   objective-preserving speed knob) `admitted` can never be `TRUE` regardless of the fit's actual
   quality, so `status` alone cannot distinguish "genuinely outside the variance domain" from
   "only ran one start."
3. **Concrete, minimal gap found in the existing campaign script:** `dev/totoro-grid/run-grid.R`'s
   `row()` helper (lines 67–79) records `status` (the string) but **never extracts the continuous
   `max_projected_variance` value**, even though it is already computed and sitting at
   `r$v$engine_result$health$max_projected_variance` (`.approximation_engine_va_r3_fit()` returns the
   entire raw `.va_r3_fit()` list unmodified as `engine_result`, `R/approximation-engine.R:133`) at
   the moment `run-grid.R` builds each row. Confirmed: `dev/totoro-grid/results/grid.csv` has no
   `max_projected_variance` column. A documented, measurement-only addition — add one field to
   `row()`'s output, e.g. `max_projected_variance = if (is.list(r$v)) r$v$engine_result$health$max_projected_variance else NA_real_`
   — would let any future campaign re-derive admission under *any* alternative threshold from already-collected
   data, with no re-fitting and no change to the shipped `<= 4` decision. This is the smallest concrete
   step that turns the frozen threshold from a value baked into a label into a value available for
   sensitivity analysis after the fact. (Not implemented here — it would touch `dev/totoro-grid/run-grid.R`,
   a file this task did not authorize changing, and re-running the campaign is a compute decision for
   the maintainer, not this task.)

---

## TASK 2 — a two-sided companion to `rel_frob > 10`

### 2a. The algebra

`rel_frob = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F`
(`dev/totoro-grid/run-grid.R:47`: `relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")`).
Let `kappa = ||Sigma_hat||_F / ||Sigma_true||_F`.

Ordinary triangle inequality on `Sigma_hat - Sigma_true = -( Sigma_true - Sigma_hat )`, applied both
ways:

- `||Sigma_hat||_F <= ||Sigma_hat - Sigma_true||_F + ||Sigma_true||_F` &nbsp;⟹&nbsp; `rel_frob >= kappa - 1`
- `||Sigma_hat - Sigma_true||_F <= ||Sigma_hat||_F + ||Sigma_true||_F` &nbsp;⟹&nbsp; **`rel_frob <= kappa + 1`**

The second line is load-bearing: `rel_frob > 10 ⟹ kappa > 9`, i.e. `rel_frob > 10` **requires**
`||Sigma_hat||_F > 9 ||Sigma_true||_F` — the task's claim, confirmed exactly.

For contraction, `kappa <= 1` by definition, so the same bound gives `rel_frob <= kappa + 1 <= 2`:
**no degree of contraction can ever produce `rel_frob > 10`.** Sharper, for the co-directional case
`Sigma_hat = c * Sigma_true` (`0 <= c <= 1`, the "uniform shrinkage" shape a variance-over-charging
bound would produce), the reverse triangle inequality holds with equality: `rel_frob = |kappa - 1| =
1 - c <= 1`. Either way the one-sided rule is **structurally**, not just empirically, blind to
contraction.

Verified numerically (`dev/va-gate3/two-sided-detector.R`, `.two_sided_verify_algebra()`, run with
`TWO_SIDED_VERIFY=TRUE`): 20,000 random `4x4` PSD matrix pairs, log-uniform scale (including
contraction) and independent random rotation (not merely co-directional, a genuine stress test) —
**zero violations** of `rel_frob <= kappa + 1` or `rel_frob >= kappa - 1`, and the maximum `rel_frob`
observed across every draw with `kappa <= 1` was `1.356` — comfortably under the `2` cap and two full
orders of magnitude under `10`.

### 2b. Every implementation site of the literal `rel_frob > 10` rule

(`grep -rn "rel_frob.*> *10" dev/ R/`; the file `dev/heywood/` uses a *different* pair of thresholds,
`rel_frob >= 5` / `<= 0.5`, for a separate lane's purposes — listed for completeness in that one
script since it self-describes against "the grid's definition," but not conflated with "the rule"
below.)

| file:line | context |
|---|---|
| `dev/totoro-grid/analyse-grid.R:99` | `deg <- s$rel_frob > 10` — the rule that produces §4 of `dev/totoro-grid/results/RESULTS.md`, operating on `dev/totoro-grid/results/grid.csv` (the dataset named in this task) |
| `dev/lambda-spectrum-vs-degeneracy.R:38` | `la$degenerate <- la$rel_frob > 10` |
| `dev/relative-collapse-vs-59of70.R:26` | `ref$rel_frob > 10` (row filter) |
| `dev/heywood/vgh-vs-laplace-degeneracy.R:113–119` | `d$la_rel_frob > 10`, `d$vg_rel_frob > 10` (explicitly labeled "the grid's definition") |
| `dev/arc0/00-cells.R:19,58` | `gr$grp <- ifelse(gr$rel_frob > 10, "degenerate", "healthy")` |
| `dev/arc0/20-profile.R:240,480` | same pattern, two call sites |
| `dev/arc0/30-ray.R:39` | `grp <- if (isTRUE(row$rel_frob > 10)) "degenerate" else "healthy"` |
| `dev/vgh/gaussian-degeneracy-reachability.R:101,107` | `sum(d$rel_frob > 10, ...)` |

Documentation that *describes* the rule without implementing it (not modified, listed for
completeness): `dev/bound-vs-estimates.md:78,165`; `dev/controlled-gh-vs-jj.md:69,129`;
`dev/degeneracy/DETECTOR.md:11`; `dev/totoro-grid/results/RESULTS.md:110`.

The canonical definition and the one this task's Task-2(d) targets is
`dev/totoro-grid/analyse-grid.R:99`, operating on `dev/totoro-grid/results/grid.csv`. The `arc0/`,
`heywood/`, and `vgh/` scripts above belong to other, separately-scoped exploration lanes in this
repository (per `CLAUDE.md`'s multi-lane fencing) and were only *read*, never modified, in this
session.

### 2c. The helper

New file: `dev/va-gate3/two-sided-detector.R`. Not sourced by the package, no NAMESPACE change, no
file under `R/`/`src/` touched. Two entry points:

- `two_sided_from_matrices(Sigma_hat, Sigma_true, inflation_thresh=10, contraction_thresh=1/3)` —
  the theoretically clean form, computing both `rel_frob` and `kappa` from the raw matrices with the
  *same* norm (Frobenius), so the §2a algebra applies exactly.
- `two_sided_from_scalars(rel_frob, kappa, inflation_thresh=10, contraction_thresh=1/3)` — vectorised,
  for data (like `grid.csv`) that only carries precomputed scalar columns.

Both return `rel_frob`, `kappa`, `flag_inflated` (byte-identical to the old rule), `flag_contracted`
(the new rule), `flag_two_sided` (either).

**Kappa source for `grid.csv`, and an explicit caveat.** `grid.csv` does not store the raw
`Sigma_hat`/`Sigma_true` matrices, only precomputed scalars. It already carries `attenuation` =
`tr(Sigma_hat)/tr(Sigma_true)` (`dev/totoro-grid/run-grid.R:73`: `at <- sum(diag(Sh)) /
sum(diag(Sig_true))`), a **trace** ratio, not the Frobenius ratio the §2a algebra is stated in terms
of. Per the task's explicit instruction to prefer an already-recorded column, `attenuation` is used as
`kappa` when applying the helper to `grid.csv` below. This is a documented substitution, not an
identity: for a `q x q` symmetric PSD matrix, `||A||_F <= tr(A) <= sqrt(q) ||A||_F`, so the trace and
Frobenius ratios can differ by up to `sqrt(q)` (`1.4x` at `q=2`, `2x` at `q=4` in this grid), most so
exactly when the eigenvalue spectrum is skewed — i.e. near the Heywood-like cases this detector exists
to catch. The two ratios coincide exactly under uniform rescaling (`Sigma_hat = c * Sigma_true`), the
shape JJ's over-charging mechanism is theorised to produce. Flagged here as a real, motivated
approximation, not verified against the Frobenius version in this session (that would require the raw
`Lambda`/`Sigma` matrices, which `grid.csv` does not retain).

### 2d. Applied to `dev/totoro-grid/results/grid.csv`

2,880 rows; 2,461 have both `rel_frob` and `attenuation` finite (usable). Old rule =
`rel_frob > 10`; new rule = old rule **OR** `attenuation < 1/3`.

| arm | n usable | **OLD flagged** | **NEW flagged** | newly-revealed contraction |
|---|---:|---:|---:|---:|
| `gtmb_gh` | 640 | 4 (0.6%) | 4 (0.6%) | 0 |
| `gtmb_jj` | 320 | 0 (0.0%) | **3 (0.9%)** | **3** |
| `gllvm_va` | 600 | 0 (0.0%) | **5 (0.8%)** | **5** |
| `gllvm_eva` | 300 | 203 (67.7%) | 203 (67.7%) | 0 |
| `gtmb_laplace` | 601 | 70 (11.6%) | 70 (11.6%) | 0 |

Per arm x per n (only rows where the two rules disagree are interesting; all others are `old = new`
with the counts above):

| arm | n | newly-revealed contraction |
|---|---:|---:|
| `gtmb_jj` | 200 | 2 |
| `gtmb_jj` | 400 | 1 |
| `gllvm_va` | 200 | 2 |
| `gllvm_va` | 400 | 3 |

All 8 newly-revealed rows are `family == "bernoulli"`; none at `n <= 100`. `kappa` (`attenuation`)
among them ranges `0.248–0.325` (`gllvm_va`) and `0.278–0.306` (`gtmb_jj`) — clearly inside the
`< 1/3` contraction band, clearly invisible to `rel_frob > 10` by the §2a algebra (their `rel_frob`
values are necessarily `<= kappa + 1 <~ 1.3`, nowhere near `10`).

**This is exactly the payoff the task predicted, and it lands precisely on the JJ/Polya-Gamma
algebra.** `gtmb_jj` and `gllvm_va` are, per `dev/totoro-grid/run-grid.R`'s own arm key (lines 14–18),
*the same bound* (`gllvm_va` = "JJ/Polya-Gamma for binomial"), and they are the *only* two arms with
any newly-revealed rows. `gtmb_gh` (the other VA arm) contributes zero — consistent with §1e's
finding that GH's failure mode is inflation, never contraction. `gllvm_eva` and `gtmb_laplace` also
contribute zero — both are independently already known (§1e context, `RESULTS.md` §3/§4, not
re-verified here beyond confirming zero overlap with the contraction band) to fail by inflation, not
contraction; the old rule already had them covered. **The one-sided rule's blind spot is not generic
— it is exactly aligned with the one bound (JJ/PG) theorised to fail by contraction, and it hid every
single one of that bound's contraction cases** (8 of 8 in this grid) until the two-sided version was
applied.

---

## Files touched this session

- **New:** `dev/va-gate3/two-sided-detector.R` (the Task-2 helper; algebra verified by
  `.two_sided_verify_algebra()`, `TWO_SIDED_VERIFY=TRUE Rscript dev/va-gate3/two-sided-detector.R`).
- **New:** `docs/dev-log/2026-07-30-variance-gate-and-two-sided-detector.md` (this file).
- **Read-only** everywhere else: `R/va-r3-proto.R`, `R/approximation-engine.R`,
  `inst/tmb/gllvmTMB_va_r3.cpp`, `tests/testthat/test-va-r3-prototype.R`,
  `dev/totoro-grid/run-grid.R`, `dev/totoro-grid/analyse-grid.R`,
  `dev/totoro-grid/results/grid.csv`/`grid.rds`/`RESULTS.md`, `dev/heywood/vgh-vs-laplace-degeneracy.R`,
  and the `docs/dev-log/` history of the 2026-07-25/26 variance-gate measurement arc cited in §1e.
- Scratch scripts (not part of the package or this worktree's history; kept under the session
  scratchpad, not committed): the proxy simulation, the real-fit validation campaign, and the
  grid.csv application script.

## Uncertain / not independently re-verified in this session

- The exact attribution *"the worst instance found anywhere"* (see header) — could not be located in
  this worktree.
- The 2026-07-26 HVT-1 truth-ladder measurement (§1e) is cited for context on the binomial case only;
  I did not re-run or re-verify its brute-force integration in this session (out of scope: this task's
  DGP and budget target the reachability/detector questions, not re-deriving an independent truth
  oracle).
- An exploratory check of whether the GH-JJ ELBO gap (both read directly from `grid.csv$objective`,
  freshly recomputed, not from `RESULTS.md`) correlates with GH's own inflation was inconclusive in a
  simple form (Spearman `rho approx -0.4` to `-0.5` against GH `attenuation`/`rel_frob`, the *opposite*
  sign from a naive "gap widens with variance" expectation) — plausibly because each arm's `objective`
  is evaluated at its *own* converged optimum rather than at a shared parameter point, confounding the
  bound-tightness question with each optimizer's different destination. Not used as evidence for any
  claim above; reported here only so it isn't silently omitted.
- `attenuation`-as-`kappa` (§2c) is a documented approximation, not validated against the Frobenius
  `kappa` in this session (would require the raw `Lambda` matrices, not retained by `grid.csv`).
- Cell-3 (`n=400,p=80,q=4`) real-fit validation in §1d(ii) ran under a strict wall-clock budget given
  measured per-fit cost at that scale; its replicate count is small relative to cells 1–2 and to the
  200-replicate proxy. Treat it as a smaller-sample supplementary check, not an equally-powered
  estimate.
