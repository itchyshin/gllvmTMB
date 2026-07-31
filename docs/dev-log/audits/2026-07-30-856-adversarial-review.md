# Adversarial review — issue #856, per-trait `sigma_eps`

**Reviewer role:** Rose, statistical-reviewer hat. Load-bearing adversarial gate.
**Bar:** refute, not confirm. Default verdict NOT-DONE.
**Worktree:** `/private/tmp/gllvmtmb-856-sigma-eps`, branch
`claude/856-sigma-eps-archaeology-20260730`, HEAD `45d62ff7`.
**Baseline for every regression claim:** a second worktree at `16aeb208`
(`b986c779^`, the last commit before the engine change), TMB recompiled from
that source: `/private/tmp/gllvmtmb-856-PREFIX`. Referred to below as PREFIX;
the branch build is FIXED.
**Probe scripts:** `dev/adversarial-856/A1`…`A7` (added by this review).
All scripts use `devtools::load_all(".")`.

**Overall verdict: DO-NOT-SHIP.**
REFUTED 3 (items 3, 4, 7) · SURVIVES 3 (items 1, 5, 6) · UNCERTAIN 1 (item 2).
Blockers: **item 7** (a clean, cheap-to-fix regression that the C++ comment
already claims is fixed) and **item 4** (a 0/20 → 13/20 silent boundary-collapse
change on a canonical design, undisclosed in NEWS).

---

## 0. Re-verification of the two "already measured" claims

Both reproduce exactly. Not taken on trust; re-run.

`Rscript dev/856-sigma-eps-pooled-cost.R` (seed 2026):

```
converged: 0
FITTED sigma_eps: 0.19695 2.0116  (length 2 )
model-free within-cell SD: t1 = 0.197  t2 = 2.012
```

`Rscript dev/856-sigma-eps-mixed-design-guard.R` (seed 4242):

```
ℹ Trait affected: "t2".
map$log_sigma_eps: 1, NA
report$sigma_eps: 0.50165, 0.0013421  (length 2 )
```

Matches the brief's numbers to all reported digits.

---

## 1. THE SURVIVING FALLBACKS — **SURVIVES** (could not break it)

**Question:** is either broadcast branch reachable on a multi-trait fit through
a public entry point, with a wrong number?

**Answer: I could not reach any of the three with a wrong value.** This is
"could not break it", not "proved correct".

### 1a. `R/methods-gllvmTMB.R:329` — `rep(sigma_eps[1L], n)`

The fallback fires iff `is.null(trait_id_1) || length(trait_id_1) != n`.
Three callers exist (`grep -rn "apply_linkinv_per_row" R/`):

| caller | passes `trait_id_1`? | length guaranteed = `n`? |
|---|---|---|
| `R/methods-gllvmTMB.R:1767` (`predict`, `newdata=NULL`) | `object$tmb_data$trait_id + 1L` | yes — branch is gated on `length(fid_vec) == nrow(out)`, and `trait_id`/`family_id_vec`/`report$eta` are all length `n_obs` |
| `R/methods-gllvmTMB.R:1808` (`predict`, `newdata=`) | `tr_out` | yes — `tr_out <- as.integer(out[[trait_col]])`, length `nrow(out)` |
| `R/diagnose.R:476` | **no** (and no `sigma_eps` either) | fallback IS taken |

The `diagnose.R:476` caller is the only reachable one, and it is harmless: it
passes `sigma_eps = NULL` (→ 0), and its result `fitted_prob` is read only
through the `binomial_rows` mask (`R/diagnose.R:449-486`), so the `fid == 3L`
lognormal branch that consumes `sigma_eps_row` is never read from it.

Instrumented probe (`dev/adversarial-856/A1-fallback-reachability.R` replaces
`.apply_linkinv_per_row` in the namespace with a wrapper that records whether
the fallback predicate held). 2-trait lognormal fit, `sigma_eps = 0.19918,
1.1549` (true 0.2, 1.2):

```
E1 predict(response) training rows
   fallback branch taken: FALSE
   max|pred - PER-TRAIT correct| : 0
   max|pred - trait-1 broadcast| : 2.892

E2 predict(newdata, response) both traits
   fallback branch taken: FALSE
   max|pred - PER-TRAIT|: 0   max|pred - trait1|: 2.892
```

**The factor-level hazard is closed.** I expected `as.integer(nd[[trait_col]])`
to be a silent-wrong-value route: a user passing newdata whose trait factor has
been `droplevels()`d to only level `"b"` would index position 1. It is not,
because `predict()` first calls `.gllvmTMB_restore_newdata_factor_levels()`
(`R/methods-gllvmTMB.R:155-181`), which re-levels every shared factor against
the training data and aborts on unseen levels:

```
E3 newdata trait column levels: b  (as.integer -> 1 )
   fallback branch taken: FALSE
   max|pred - trait2 (CORRECT)|: 0   max|pred - trait1 (WRONG)|: 2.892

E4 character trait column: fallback: FALSE  max|pred - trait2|: 0  max|pred - trait1|: 2.892
```

### 1b. `R/methods-gllvmTMB.R:1157` — `rep(sigma[1L], length(eta))` in `simulate(newdata=)`

Fires iff `trait_col ∉ names(pp)`, where `pp <- predict(object, newdata=)`
returns `data.frame(nd, est = eta)`. Since `predict()` itself requires the
trait column (both for `model.matrix(object$formula, nd)` on a `0 + trait`
formula and for the RE block at `:1697`), I found no route.

Measured, 2-trait gaussian, `sigma_eps = 0.10375, 5.1434`:

```
E5 simulate(newdata=)
   object$trait_col: trait  present in predict(newdata) output: TRUE
   empirical sd of draws by trait: 0.1033 5.13
   fitted sigma_eps by trait      : 0.1038 5.143
   if broadcast, BOTH would be    : 0.1038
E6 simulate(condition_on_RE=TRUE) sd by trait: 0.1035 5.157
E6 simulate(default/unconditional) sd by trait: 0.1033 5.141
```

The most promising remaining route — a **wide-format** `traits()` fit, whose
newdata has no trait column — fails earlier and loudly, identically in both
builds (`dev/adversarial-856/A4-rate-and-wide.R`):

```
object$trait_col = trait ; names(object$data): unit, trait, .y_wide_, species, site_species
predict(newdata = WIDE frame): ERROR -- object '.y_wide_' not found
simulate(newdata = WIDE frame): ERROR -- object '.y_wide_' not found
```

(That error is a separate pre-existing usability gap in the wide API, present in
PREFIX too. Not a #856 defect; noted, not opened.)

### 1c. `R/predictive-diagnostics.R:403-407` — `sigma_eps[1L]` when `tid` out of range

`tid` comes from `.gllvmTMB_diagnostic_row_metadata()` and is always in
`1..n_traits` for a well-formed fit. Separately, the exact-CDF loop handles only
fid 0/2/5/15; **lognormal (fid 3) is `unsupported_family`**, so the lognormal
residual SD never reaches this site at all:

```
E7 residuals() u by trait: mean/sd
    t1 : mean = 0.4976  sd = 0.2893  (target 0.5 / 0.2887)
    t2 : mean = 0.4937  sd = 0.29    (target 0.5 / 0.2887)
   statuses: ok
E8 lognormal residuals statuses: unsupported_family
```

Trait 2's true residual SD is 50× trait 1's; a broadcast would have driven
trait 2's `u` to a degenerate spike, not `sd = 0.29`.

**Verdict: SURVIVES.** The original silent-wrong-value defect does not survive
behind these fallbacks on any call I could construct. Residual risk: all three
branches are unguarded and unasserted, so a future caller that omits
`trait_id_1` inherits the old behaviour silently. Converting them to
`cli::cli_abort()` (or at least a `stopifnot`) would close the class rather than
the instance.

---

## 2. THE GUARD ITSELF — **UNCERTAIN**

Battery in `dev/adversarial-856/A2-guard-attack.R`. The guard does exactly what
it claims on every design where the confound is exact. It does **not** cover the
neighbourhood just outside "exact", and that neighbourhood produces the
dangerous outcome.

### Designs where the guard behaves correctly

| design | result |
|---|---|
| D1 — 3 traits, reps 1/2/5, `indep(0+trait\|unit)` | `map = NA, 2, 3`; `sigma_eps = 0.0018433, 1.0966, 1.8676` (true 0.5/1.0/2.0). Only the 1-rep trait suppressed. conv 0, pdHess TRUE. |
| D2 — every trait exactly **2 rows/cell** (identifiability boundary) | guard correctly does not fire; `sigma_eps = 0.25337, 0.92223, 2.9967` (true 0.3/1.0/3.0). pdHess TRUE. Sane. |
| D4 — `indep(0+trait\|obs)`, `obs` per-row (W tier) | `map = NA, NA`; both suppressed at 0.001442. |
| D5 — same at a shared W grouping | `map = NA, NA`; both suppressed. |
| D6 — **default `latent(0+trait\|site, d=2)` with folded Psi**, one row per cell | guard **does** fire (`map = NA,NA,NA,NA`). I had hypothesised a folded-Psi `latent()` would not register as `kinds == "diag"` and would slip the guard; it does register. FIXED and PREFIX are numerically identical here (`sigma_eps = 0.0014766`, `sd_B = 0.9416, 0.8657, 0.6826, 0.7598`, pdHess FALSE in **both**) — so D6's non-PD Hessian is pre-existing, not a #856 regression. |

### D3 — the case that breaks: near-degenerate, not exactly degenerate

The guard's test is `length(unique(cell[rows_t])) == length(rows_t)` — *exact*
one-row-per-cell. Make one single cell replicated out of 120 and the guard goes
silent while the design is, statistically, still degenerate.

Design: trait 1 has 4 rows/unit (fine); trait 2 has **1 unit with 2 rows and 119
units with 1 row**. True `sd_B = 1.0`, `sigma_eps = 2.0` for both.

FIXED (`dev/adversarial-856/A4-rate-and-wide.R`):

```
sigma_eps : 0.48845, 2.3211   TRUE 0.5, 2.0
sd_B      : 0.97887, 0.00086309   TRUE 1.0, 1.0
implied total sd trait2 = 2.3211   TRUE total = 2.2361
            pd_hessian   PASS           TRUE
        boundary_flags   WARN near_zero_sd_B
 boundary_sigma_eps_t2   PASS          2.321
```

and the standard error looks *precise*
(`dev/adversarial-856/A3-rootcauseC-and-leaks.R`):

```
log_sigma_eps estimate / SE:
              Estimate Std. Error
log_sigma_eps  -0.7165    0.03727
log_sigma_eps   0.8420    0.06428
```

This is the dangerous outcome named in the brief: converged, positive-definite
Hessian, a 6.4% relative SE — and `sigma_eps[2] = 2.32` is **not the residual
SD (2.0)**, it is the *total* SD (2.236), because `sd_B[2]` collapsed to
0.00086. The user is told the residual SD with apparent precision and is given
the total instead.

**But it is not cleanly a regression.** PREFIX on the same data:

```
sigma_eps : 0.51367   TRUE 0.5, 2.0
sd_B      : 0.97563, 2.254   TRUE 1.0, 1.0
     boundary_flags   PASS   none
```

PREFIX is *also* wrong — it puts trait 2's variance entirely into `sd_B[2] =
2.254` — and it raises no flag at all. FIXED at least trips
`boundary_flags = WARN near_zero_sd_B`. So: differently wrong, arguably slightly
better-signposted, not worse.

Milder unbalance (12/120 units replicated) recovers acceptably:
`sigma_eps = 0.50538, 1.8044`.

**Verdict: UNCERTAIN.** The guard is correct for the condition it tests. The
adjacent near-degenerate regime is not covered, converges with a PD Hessian,
and reports a wrong number with a tight SE. I did not find a case where the
guard fires *wrongly*; I found a case it does not fire *at all* and should
arguably warn.

---

## 3. MIXED FAMILY WITHIN ONE TRAIT — **REFUTED**

Family is per-row (`R/fit-multi.R:349-353`, galamm-style `family_var` column),
and only `ordinal_probit` guards against a within-trait family mix
(`R/fit-multi.R:2676-2684`: *"The mixed-family API allows one family per row,
but ordinal_probit must own its trait entirely."*). Nothing stops a trait from
carrying both gaussian (identity-scale) and lognormal (log-scale) rows.

D9 (`dev/adversarial-856/A2-guard-attack.R`, `A7-d9.R`): trait A = 300 gaussian
rows with identity-scale SD **3.0** + 300 lognormal rows with log-scale SD
**0.2**; trait B = 450 gaussian rows, SD 1.0.

```
D9 rows per (trait, fam):
      g  ln
  A 300 300
  B 450   0

-- was any WARNING emitted for the within-trait family mix? --
(nothing)

  convergence      : 0
  sdreport pdHess  : TRUE
  sigma_eps        : 5.1077, 1.0738
```

`sigma_eps[A] = 5.1077` means neither 3.0 nor 0.2 — it is a pooled number over
two incommensurable scales. **No warning, no error, no NA.** And it is then
printed on a public surface with the trait's own name attached:

```
             component status  value                                   message
  boundary_sigma_eps_A   PASS  5.108 estimated continuous-family residual scale
  boundary_sigma_eps_B   PASS  1.074 estimated continuous-family residual scale
```

The package already knows the right answer. `link_residual_per_trait()`
(`R/extract-sigma.R:115-148`), the precedent the brief names, on the *same fit*:

```
   WARNING: Trait 'A' has rows from multiple families (0, 3); no single link-residual variance is defined.
   WARNING: Link-scale residual variance is unavailable for trait(s): A. Returning NA rather than substituting a finite value.
   value: NA, 0
```

**Is it a numerical regression?** No. PREFIX on the same data gives a single
scalar `sigma_eps = 3.99915` — also meaningless. **It is a presentation
regression.** Pre-change there was one anonymous pooled number that nobody could
mistake for a per-trait quantity. Post-change `sigma_eps[A]` is labelled with
trait A's name, printed per trait by `check_gllvmTMB()`, and marked PASS. The
promotion makes a wrong number materially more credible, and does so while
declining to follow its own established NA+warning precedent 30 lines away in
the same package.

**Verdict: REFUTED.** The case is silently pooled, not NA+warned.

---

## 4. THE ROOT-CAUSE-C VERDICT — **REFUTED**

The claim under test: `test-lme4-style-weights.R`'s failure was a **fixture
artefact**, correctly fixed by strengthening the fixture's replication
(`n_species`/`mean_species_per_site` 1 → 10).

**The mechanism half of the diagnosis is correct and I independently confirm
it. The "fixture artefact" conclusion is wrong.**

### 4a. Rate: 13/20 vs 0/20

Exact original fixture — `n_sites = 30, n_species = 1, mean_species_per_site =
1` (one row per (site, trait)), 4 gaussian traits, fit
`latent(0 + trait | site, d = 1, unique = FALSE)`, simulator residual sd 0.707.
Seeds 1–20, both builds (`dev/adversarial-856/A4-rate-and-wide.R`):

| build | collapse rate (any trait's `sigma_eps` < 0.05) |
|---|---|
| **PREFIX** | **0 / 20** — all values 0.83–1.33 |
| **FIXED** | **13 / 20** |

Every one of the 13 has `conv = 0` **and `pdHess = TRUE`** — the silent outcome,
not the loud one. Examples:

```
  seed 2  COLLAPSE: sigma_eps=0.0003503, 0.9293, 0.8621, 1.189   conv=0 pdHess=TRUE
  seed 8  COLLAPSE: sigma_eps=1.978, 1.083, 0.0002401, 0.9295    conv=0 pdHess=TRUE
  seed 12 COLLAPSE: sigma_eps=1.092, 0.8716, 0.8056, 8.805e-05   conv=0 pdHess=TRUE
  seed 16 COLLAPSE: sigma_eps=0.982, 4.678e-05, 1.308, 0.8245    conv=0 pdHess=TRUE
```

### 4b. `check_gllvmTMB()` misses 11 of the 13

`sigma_eps_thresh = 1e-4` (`R/diagnose.R:747`). Most collapsed values land in
2e-4…8e-4, *above* the threshold, so the boundary row reads PASS:

```
  seed 2:  boundary_sigma_eps_trait_1=PASS(0.0003503)   <- collapsed, reported PASS
  seed 12: boundary_sigma_eps_trait_4=WARN(8.805e-05)   <- caught
  seed 16: boundary_sigma_eps_trait_2=WARN(4.678e-05)   <- caught
```

Only 2 of 13 are caught. A user running the documented fit-health check on a
collapsed fit is told it is fine.

### 4c. It is structural, not a sample-size problem

The fixture comment asserts this; I confirm it, holding seed 2 fixed and growing
`n_sites` at one row per cell (`dev/adversarial-856/A5-nsites.R`):

```
n_sites 30  (rows 120):  sigma_eps=0.0003503, ...  collapsed=TRUE
n_sites 60  (rows 240):  sigma_eps=0.0005579, ...  collapsed=TRUE
n_sites 120 (rows 480):  sigma_eps=1.176, ...      collapsed=FALSE
n_sites 240 (rows 960):  sigma_eps=0.0006312, ...  collapsed=TRUE
n_sites 480 (rows 1920): sigma_eps=1.405, ...      collapsed=FALSE
```

Still collapsing at 960 rows. Erratic in `n_sites`, which is what a
boundary-seeking ridge looks like. **Replication cures it immediately:**

```
species/site 1 (rows 120): collapsed=TRUE
species/site 2 (rows 200): sigma_eps=0.6963, 0.913, 0.9332, 1.096  collapsed=FALSE
species/site 3 (rows 288): collapsed=FALSE
species/site 4 (rows 388): collapsed=FALSE
```

(One correction to the record: I could not reproduce the comment's specific
"doubling n_sites to 60 at mean_species_per_site = 1" check at seed 1 — seed 1
does not collapse at n = 30 either, so that check was uninformative as run. The
seed sweep establishes the same conclusion far more strongly.)

### 4d. Why this is a disclosure item, not a test fix

One row per (site, trait) with a shared low-rank score is *the* canonical
joint-SDM / trait-matrix layout, not an exotic fixture. The mechanism is exactly
as the comment says: with one row per cell, the per-site latent score can absorb
one trait's site-to-site pattern entirely, driving that trait's residual to the
zero boundary; the pre-#856 shared scalar could not follow it there because the
other traits needed it positive. Removing that accidental coupling is
*defensible as a modelling choice* — but its consequence is a 65% silent
boundary-collapse rate on a standard design, invisible to `conv`, to `pdHess`,
and (11/13) to `check_gllvmTMB()`.

The current handling — strengthen the fixture, say nothing in NEWS — records the
cost as a test-fixture detail. It is a user-facing cost of the promotion.

**Verdict: REFUTED.** Mechanism confirmed; "fixture artefact" refuted; NEWS
disclosure and a `sigma_eps_thresh` review are owed.

---

## 5. THE JULIA BOUNDARY — **SURVIVES**

The two scalar sites are `R/julia-bridge.R:2265` and `:2379`, both
`as.numeric(object$sigma_eps %||% NA_real_)[1L]` *inside a per-trait
`for (i in seq_len(p))` loop* — i.e. structurally the shape that would silently
collapse a per-trait vector to trait 1.

They cannot be fed one:

1. **Class gate.** Their only callers are `.gllvm_julia_residual_variance`
   (from `residuals.gllvmTMB_julia`, `R/julia-bridge.R:3213`) and
   `.gllvm_julia_simulation_draw` (from `simulate.gllvmTMB_julia`, `:3305`).
   S3 dispatch on `gllvmTMB_julia`; a TMB fit is `gllvmTMB_multi` and never
   reaches them.
2. **No writer.** `grep -rn '\$sigma_eps *<-' R/` returns **nothing**. The only
   `sigma_eps =` writes in the whole package are the two named arguments to
   `.apply_linkinv_per_row` (`R/methods-gllvmTMB.R:1771, :1812`). Nothing ever
   assigns `$sigma_eps` onto an object.
3. **No R→Julia route.** The `gllvmTMB_julia` object is built solely from the
   JuliaCall return (`res <- do.call(JuliaCall::julia_call, args)` at `:2824`,
   class set at `:2980`), and the outbound payload `res$bridge_input` (`:2963`:
   `y, family, num.lv, N, X, X_lv, mask, units_are_rows, setup_args`,
   optionally `coef_fixed`) has no `sigma_eps` field.

`test-julia-bridge.R`: 0 failures.

**Verdict: SURVIVES.** No boundary collapse. Note for the record that the
robustness here is incidental — it rests on "nothing writes this field" rather
than on a shape check — so if GLLVM.jl's `σ_eps` ever becomes per-trait, or an
R-side fit is ever marshalled into the bridge shape, both sites become wrong
silently. A `length(sigma) == 1L || stop(...)` at each would make it explicit.

---

## 6. REGRESSION SURFACE — **SURVIVES** (with a coverage caveat)

`test-sigma-eps-autosuppress.R` is **untouched** by the #856 arc:

```
$ git log --oneline 16448745..HEAD -- tests/testthat/test-sigma-eps-autosuppress.R
(empty)
$ git diff 16448745..HEAD --stat -- tests/testthat/test-sigma-eps-autosuppress.R
(empty)
```

and it passes. With `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`:

```
##### test-sigma-eps-autosuppress.R          PASS=7  FAIL=0 SKIP=0 WARN=0
##### test-sigma-eps-per-trait.R             PASS=4  FAIL=0 SKIP=0 WARN=0
##### test-sigma-eps-per-trait-consumers.R   PASS=29 FAIL=0 SKIP=0 WARN=0
##### test-lme4-style-weights.R              PASS=24 FAIL=0 SKIP=0 WARN=0
```

The 13 files the arc touched (incl. `test-profile-targets.R`,
`test-confint-inspect.R`, `test-coverage-study.R`, the three
`test-missing-predictor-*`, `test-stage37-mixed-family.R`,
`test-mixed-family-extractor.R`, `test-julia-bridge.R`) run clean.

**Caveat, and it matters for how much this evidence is worth.** Without those
two env vars the new tests do not run at all — they are gated behind *both*
`skip_if_not_heavy()` (`tests/testthat/setup.R:16`) and `skip_on_cran()`:

```
##### test-sigma-eps-per-trait.R             sigma-eps-per-trait: S
##### test-sigma-eps-per-trait-consumers.R   sigma-eps-per-trait-consumers: SSSSSS...
##### test-lme4-style-weights.R              (all skipped)
```

`setup.R` says routine PR CI leaves `GLLVMTMB_HEAVY_TESTS` unset. So **routine
CI exercises none of the per-trait recovery claims**, and none of the three
findings in items 3, 4 and 7 would ever be caught by the test suite as gated.
Green here is a statement about the fast suite, not about the promotion.

**Verdict: SURVIVES.**

---

## 7. THE FLAT DIRECTION — **REFUTED: it is worse than before**

The brief asks only to confirm this is *no worse* and not to open it. It is
worse, and the C++ already claims the fix that would make it no worse.

Design D8: trait 1 gaussian, trait 2 **poisson**, `indep(0 + trait | unit)`,
3 rows/cell — an ordinary mixed-family fit. Trait 2 has **no** rows with
`family_id ∈ {0, 3}`, so `log_sigma_eps[2]` has no data.

| | FIXED | PREFIX |
|---|---|---|
| `convergence` | 0 | 0 |
| **`sdreport pdHess`** | **FALSE** | **TRUE** |
| **`hessian_rank`** | **NA/6 (WARN)** | **5/5 (PASS)** |
| gradient at `log_sigma_eps` | `-6.38e-07, ` **`0`** | `-0.00017` |
| `sigma_eps` | `0.544232,` **`1.78021`** | `0.544232` |

The gradient at `log_sigma_eps[2]` is **exactly zero** — an exactly flat
parameter direction that did not exist before the promotion. The reported
`1.78021` is the frozen `lm`-residual start value
(`R/fit-multi.R:2821-2824`) computed on Poisson counts; it never moves.

It reaches a public surface:

```
             component status  value                                   message
            pd_hessian   WARN  FALSE positive-definite Hessian for curvature-based inference
          hessian_rank   WARN   NA/6 rank of the fixed-parameter covariance matrix from sdreport
 boundary_sigma_eps_t2   PASS   1.78 estimated continuous-family residual scale
```

A fabricated residual scale for a Poisson trait, marked PASS.

Two consumers are clean and worth recording: `.vp_residual_per_trait()` returns
`0.29619, 0` (family-aware, correct), and `simulate()` draws Poisson properly
(`sd by trait: 0.9509, 1.746`; √3 = 1.732).

### The fix is already documented — it just was not written

`src/gllvmTMB.cpp:312-314` states:

```
  // sigma_eps is a length-n_traits vector (PARAMETER_VECTOR(log_sigma_eps));
  // a trait's entry is mapped off when no row of that trait has
  // family_id_vec(o) in {0, 3} (R/fit-multi.R Q7 per-trait auto-suppress).
```

`R/fit-multi.R` does **not** do this. The family test is dataset-wide only
(`:4644`, `any_sigma_eps <- any(family_id_vec %in% c(0L, 3L))`), and the
per-trait suppression at `:4676-4686` is built purely from
`per_row_diag_B_t | per_row_diag_W_t` — no family term. The comment describes a
guard that does not exist.

The smallest correct change is one more term in `suppress_eps_t`: a per-trait
`has_eps_rows_t <- vapply(seq_len(n_traits), function(t) any(family_id_vec[trait_id == (t-1L)] %in% c(0L, 3L)), logical(1))`,
then `suppress_eps_t <- per_row_diag_B_t | per_row_diag_W_t | !has_eps_rows_t`.
That restores `pdHess = TRUE` and removes the fabricated number, and it makes
the C++ comment true.

**Verdict: REFUTED.** Not pre-existing, not shared with
`log_sigma_student` / `log_phi_gamma` in this form — the promotion created it.

---

## Summary

| # | item | verdict |
|---|---|---|
| 1 | surviving fallbacks | **SURVIVES** (could not break it) |
| 2 | the guard itself | **UNCERTAIN** — correct where it fires; near-degenerate designs slip through converged/PD/tight-SE with the total SD reported as the residual SD |
| 3 | mixed family within one trait | **REFUTED** — silently pooled, no warning; own precedent not followed |
| 4 | Root-Cause-C verdict | **REFUTED** — 13/20 vs 0/20; structural, silent, `check_gllvmTMB()` misses 11/13 |
| 5 | Julia boundary | **SURVIVES** |
| 6 | regression surface | **SURVIVES** — but the load-bearing tests are double-gated out of routine CI |
| 7 | flat direction | **REFUTED** — a new regression: `pdHess` TRUE → FALSE, exactly-zero gradient, fabricated value on a public surface |

**Blockers**

1. **Item 7.** A regression, on an ordinary mixed-family fit, with a small
   named fix that the C++ comment already asserts exists.
2. **Item 4.** Not necessarily fixable — it may be intrinsic to per-trait
   residuals — but it is a 65% silent-failure rate on a canonical design and it
   is undisclosed. NEWS must say it; `sigma_eps_thresh = 1e-4` should be
   revisited (it misses 11/13 of the collapses it exists to catch).

**Non-blocking but owed:** item 3 should adopt the `link_residual_per_trait()`
NA+warning precedent, or at minimum be disclosed. Items 1 and 5 would benefit
from converting their implicit shape assumptions into explicit aborts.

*This review reports; it does not fix. No package code was modified. The only
files added are the probe scripts under `dev/adversarial-856/` and this
document. The comparison worktree `/private/tmp/gllvmtmb-856-PREFIX` (detached
at `16aeb208`) is left in place for re-verification; remove with
`git worktree remove /private/tmp/gllvmtmb-856-PREFIX`.*
