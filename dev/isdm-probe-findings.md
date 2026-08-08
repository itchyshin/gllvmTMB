# ISDM probe: mixed family (Poisson po / Bernoulli-cloglog pa) within one species

Script: `dev/isdm-probe.R`. Package: `gllvmTMB` **0.6.0** (installed, loaded via
`library(gllvmTMB)`, no `devtools::load_all()`). R 4.6.0. Full raw output
captured verbatim below each task; nothing paraphrased where it matters.

## T1 — Does it run, and is the family truly per row?

Data: 1 species (`trait = "sp1"` constant), 60 cells, each cell contributing
one `source = "po"` row (Poisson count) and one `source = "pa"` row
(Bernoulli/cloglog). Formula `value ~ 1 + env + source`.
`family_list <- list(po = poisson(), pa = binomial(link = "cloglog"))`,
`attr(family_list, "family_var") <- "source"`.

```
T1 fit succeeded.
length(family_id_vec): 120 
length(link_id_vec):   120 
nrow(data):             120 

family_id_vec x source (1=binomial, 2=poisson):
   
    po pa
  1  0 60
  2 60  0

link_id_vec x source:
   
    po pa
  0 60  0
  2  0 60

fit$opt$convergence: 0 
fit$opt$message:      relative convergence (4) 
sd_report$pdHess:     TRUE 
```

`family_id_vec` and `link_id_vec` are length `nrow(data)` = 120, i.e. **per
row**, not collapsed to `n_traits`. The cross-tab is exact: every `po` row
gets family id 2 (poisson) / link id 0 (log), every `pa` row gets family id 1
(binomial) / link id 2 (cloglog) — matching `source` perfectly. This directly
confirms the source-trace claim (`R/fit-multi.R:524-527`,
`src/gllvmTMB.cpp:2171`): `family_id_vec` is built row-wise from the
`family_var` column, and `family_var` was pointed at `source`, not at the
trait column. The fit converged (`convergence = 0`) with a positive-definite
Hessian (`pdHess = TRUE`), with `family_var` keyed to a non-trait column and
only one species present.

**VERDICT: A single species can carry two different families on different
rows via `family_var` pointed at a non-trait column — it is genuinely
per-row, and the fit runs and converges cleanly.**

## T2 — Does it run with a latent() term and more than one species?

Same `po`/`pa` mix, now 3 species, `value ~ 0 + trait + trait:env +
latent(0 + trait | cell, d = 1)`, `cluster = "trait"` (see T4 for why this
matters). No `lv = ~ ...` argument used.

```
T2 fit succeeded.
fit$opt$convergence: 0 
fit$opt$message:      relative convergence (4) 
sd_report$pdHess:     TRUE 

family_id_vec x source:
   
     pa  po
  1 180   0
  2   0 180

getLV(fit2) dim: 60 x 1  (n_cell = 60 , n_sp = 3 )
```

The fit builds and converges with a PD Hessian, and `family_id_vec` again
tracks `source` exactly (180 `pa` rows = family 1, 180 `po` rows = family 2,
out of 360 total rows = 60 cells × 3 species × 2 sources). `getLV(fit2)` is
**60 × 1**: one latent score per CELL, not per (cell, species) and not per
(cell, source). This confirms the prior #942 probe's expectation.

**VERDICT: The mixed-within-species fit extends cleanly to 3 species plus a
shared `latent()` factor, one score per unit (cell), and converges.**

## T3 — Footgun A: starting values

```
start_provenance for the default-start T2 fit:
$init_strategy
[1] "default"
$start_method
[1] "default"
...

Illustration: manual lm.fit(X_fix, raw y) as the default init path
does when the family mix is not all-log-link and not multi-trial binomial
(see R/fit-multi.R ~2794-2850; our mix triggers the final `else` branch):
    traitsp1     traitsp2     traitsp3 traitsp1:env traitsp2:env traitsp3:env 
   1.3697579    1.1727320    0.8723925    0.3260270    0.2780579    0.1258405 

Comparison fit using control = gllvmTMBcontrol(start_method = list(method = "indep")),
which copies fixed effects from a per-family independent-diagonal fit instead:
default-start : convergence = 0  iterations = 61  logLik = -388.4603 
indep-start   : convergence = 0  iterations = 59  logLik = -388.4603 
```

Reading `R/fit-multi.R` around lines 2794-2850 confirms the mechanism the
task describes: the init path checks `has_multi_trial` (needs `n_trials > 1`
binomial — false here, our binomial rows are single-trial Bernoulli),
`log_link_only` (requires **every** row's family in the log-link set
`{2,3,4,5,6,10,11,12,13,15}` — false here because binomial, family id 1, is
in the mix), `beta_only`, `ordinal_only` — all false — so it falls to the
final `else: fit_lm <- stats::lm.fit(X_fix, y)`, i.e. OLS on the **raw**
response column that literally mixes Poisson counts and 0/1 indicators. The
illustrative coefficients above (traitsp1 intercept 1.37, etc.) are a
compromise between the Poisson log-scale intercepts (true values 0.1-0.3) and
the binomial cloglog-scale intercepts (true values -0.4 to 0.1) — on neither
family's correct scale.

`Xcoef_fixed` is **not** a general starting-value hook: `?gllvmTMB` and
`.normalise_Xcoef_fixed()` in `R/fit-multi.R` state values "must currently be
`0`" — it is a zero-pinning constraint mechanism, not a way to supply
arbitrary starting coefficients.

`gllvmTMBcontrol(start_method = list(method = "indep"))` **is** exposed and
does something relevant: per its roxygen doc it "first fit[s] the matching
independent diagonal GLMM/GLLVM and copy[ies] its estimated fixed effects...
into the full latent covariance fit," which routes around the raw-`lm.fit`
step for `b_fix`. Measured on this toy fit: default start converged in 61
iterations to `logLik = -388.4603`; `start_method = "indep"` converged in 59
iterations to the **identical** `logLik = -388.4603`. Both reached
`convergence = 0`.

**VERDICT: The described starting-value footgun is real and traceable in the
source (raw-`y` OLS init when the family mix is neither all-log-link nor
multi-trial), and a partial mitigation (`start_method = "indep"`) exists —
but at this toy scale (n=60 cells, 3 species) it cost only ~2 extra
iterations and zero difference in the final optimum, so no convergence
failure was demonstrated here; the risk may only bite at harder scales/
starting geometries than this probe covers.**

## T4 — Footgun B: unit_obs collapse

```
With cluster = "trait" (T2's fit):
  unit_obs_col: site_species 
  n_site_species: 180  (n_cell * n_sp = 180 )
  distinct sources sharing one site_species level (table of counts):
  2 
180 
  example rows for cell=1, trait=sp1:
   cell trait source site_species
1     1   sp1     po        1_sp1
61    1   sp1     pa        1_sp1

With the DEFAULT cluster ("species", not present in this data -- a
common real-world case since the mixed-family `source` example has no
separate 'species' column distinct from `trait`):
  unit_obs_col: site_species 
  n_site_species: 60  (n_cell = 60 )
  levels (head):
[1] "1_placeholder"  "10_placeholder" "11_placeholder" "12_placeholder"
[5] "13_placeholder" "14_placeholder"
```

Two distinct findings, more nuanced than the task's hypothesis
(`unit_obs = factor(paste(unit, trait))`):

1. **When `cluster = "trait"` is set explicitly** (the natural choice when
   the 3 species genuinely are the `trait` levels), `unit_obs` (`site_species`
   in the code) is built as `paste(unit, species)` where `species <-
   cluster`, giving exactly what the task predicted: 180 levels (60 cells x 3
   species), and every level has exactly 2 rows — one `po`, one `pa` —
   collapsed together (confirmed directly: `site_species == "1_sp1"` for both
   the po and pa row of cell 1 / sp1).

2. **With the package's actual default** (`cluster` defaults to a column
   named `"species"`, distinct from `trait`, and — per `R/gllvmTMB.R`
   ~470-475 — is silently synthesised as a constant `"placeholder"` when that
   column is absent), the collapse is **worse than hypothesised**:
   `unit_obs` has only 60 levels (one per cell), meaning species identity
   *and* `source` both collapse into a single within-unit level per cell.
   This is a general property of any multi-species long-format fit that
   doesn't pass `cluster =`, not specific to mixed-family fits, but it
   compounds the mixed-family footgun if a user leaves `cluster` at its
   default while relying on `trait` alone to distinguish species.

Implication: any model that adds a within-unit (`unit_obs`-tier) term —
e.g. `latent(0 + trait | site_species)` or `indep(0 + trait | site_species)`
— would, under `cluster = "trait"`, share that term's variance across the
`po` and `pa` rows of the same (cell, species) rather than modelling them
separately; under the package default it would additionally pool across
species. No such model was fit (not required by the task).

**VERDICT: The unit_obs collapse is real and confirmed, but its shape depends
on `cluster`: with `cluster` aligned to the trait/species column it collapses
exactly `source` (po+pa) within (cell, species) as hypothesised; with the
package's out-of-the-box default it additionally collapses across species,
which is a more severe and easier-to-hit footgun than #945's framing
suggests.**

## T5 — Footgun C: the scoring call

```
--- link_residual = 'none' ---
Sigma:
           sp1        sp2         sp3
sp1  0.9156687  0.4915401 -0.25849206
sp2  0.4915401  0.2638637 -0.13876113
sp3 -0.2584921 -0.1387611  0.07297197
R:
    sp1 sp2 sp3
sp1   1   1  -1
sp2   1   1  -1
sp3  -1  -1   1

--- link_residual = 'auto' ---
WARNING: Trait 'sp1' has rows from multiple families (2, 1); no single link-residual variance is defined. 
WARNING: Trait 'sp2' has rows from multiple families (2, 1); no single link-residual variance is defined. 
WARNING: Trait 'sp3' has rows from multiple families (2, 1); no single link-residual variance is defined. 
WARNING: Link-scale residual variance is unavailable for trait(s): sp1, sp2, sp3. Returning NA rather than substituting a finite value. 
Sigma:
           sp1        sp2         sp3
sp1  0.9156687  0.4915401 -0.25849206
sp2  0.4915401  0.2638637 -0.13876113
sp3 -0.2584921 -0.1387611  0.07297197
R:
    sp1 sp2 sp3
sp1   1   1  -1
sp2   1   1  -1
sp3  -1  -1   1

identical(none$Sigma, auto$Sigma): TRUE 
any(is.na(auto$Sigma)): FALSE 
```

`link_residual = "none"` behaves exactly as documented: a sensible 3x3 Sigma
and correlation matrix, no error, no NULL, no warning.

`link_residual = "auto"` **does** warn, three times per-trait ("has rows from
multiple families... no single link-residual variance is defined") plus once
in aggregate ("Link-scale residual variance is unavailable for trait(s):
sp1, sp2, sp3. Returning NA rather than substituting a finite value."). But
the returned `Sigma` is **not** NA anywhere and is in fact `identical()` to
the `link_residual = "none"` result. Tracing this in
`R/extract-sigma.R:1458-1550`: `link_residual_per_trait()` correctly computes
`NA_real_` for each mixed-family trait (line ~376-388), but the gate that
applies the correction is

```r
if (any(link_resid_per_trait != 0, na.rm = TRUE)) {
  diag(Sigma) <- diag(Sigma) + link_resid_per_trait
}
```

(`R/extract-sigma.R:1548-1550`). Because every entry of `link_resid_per_trait`
is `NA` here, `link_resid_per_trait != 0` is all-`NA`, and
`any(..., na.rm = TRUE)` over an all-`NA` vector is `FALSE` — so the branch is
skipped entirely and Sigma is silently returned as if `link_residual =
"none"` had been requested. The warning text ("Returning NA rather than
substituting a finite value") does not match what actually happens: no NA is
returned anywhere in the output; the function silently no-ops instead.

**VERDICT: `link_residual = "auto"` warns correctly that no single residual
is defined for a mixed-family trait, but then — due to the `na.rm = TRUE` in
the `any()` gate at `R/extract-sigma.R:1548` — silently falls back to adding
nothing, contradicting its own warning text; it neither errors nor actually
returns NA.**

---

## ADJUDICATION OF #945

**YES — a mixed-family-within-species fit is runnable today**, on direct
evidence: T1 (single species, `family_var` pointed at a non-trait `source`
column) fits and converges with a positive-definite Hessian, and T2 extends
this to 3 species plus a shared `latent()` factor, also converging cleanly.
The source-trace claim in the issue thread is correct: `family_id_vec` is
built row-wise (`R/fit-multi.R:524-527`) and dispatched per row in the C++
likelihood (`src/gllvmTMB.cpp:2171`), and this probe confirms it end-to-end
with a real fit rather than by reading code alone. Issue #945's own comment
("cannot be run today — the R interface maps family per trait") is **not
supported by measurement** and should be corrected.

That said, "runs" is not "safe by default": three real footguns were
confirmed to different degrees —
(A) the default fixed-effect starting values regress raw mixed
count/binary data (confirmed in source and by illustration; no convergence
failure demonstrated at this toy scale, but the mechanism is real and a
partial fix, `start_method = "indep"`, exists);
(B) the default `unit_obs` grouping collapses `po`/`pa` rows of the same
(cell, species) together — and, worse, collapses across species too if
`cluster` is left at its default;
(C) `extract_Sigma(..., link_residual = "auto")` warns about undefined
residual variance for a mixed-family trait but then silently does nothing
(a no-op masquerading as a documented NA-return, traced to a `na.rm = TRUE`
bug in the gating condition) — `link_residual = "none"` is unaffected and
behaves correctly.
