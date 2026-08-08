# Jason probe: does the integrated (mixed-family, duplicated-row) model work in WIDE format?

Lane: `claude/experiment-integrated-sdm` (worktree-only, no PR, no merge, no package edit).
Role: Jason, landscape scout. Measurement only.

## Setup

`traits(...)` wide format goes through `rewrite_traits_lhs()` (`R/traits-keyword.R:402`),
called from `gllvmTMB()` (`R/gllvmTMB.R:562`) whenever the LHS is a `traits(...)` call. It
pivots the wide frame long with `tidyr::pivot_longer(cols = tidyselect::all_of(trait_cols), ...)`
(`R/traits-keyword.R:517`), which by construction **keeps every non-selected column and
replicates it across the stacked trait rows** — nothing in that call restricts which columns
survive.

Toy data: 5 cells, **two rows per cell** (`source = "po"` / `"pa"`), 3 species columns
(`sp1, sp2, sp3`), plus a per-trait offset triple (`e1, e2, e3`) for the `offset(e1, e2, e3)`
wide syntax. This directly instantiates the wide-format iSDM shape: one PO row and one PA row
per spatial unit, family varying by the `source` column, not by trait.

Script (verbatim, run with `NOT_CRAN=true Rscript dev/isdm-wide-format-probe.R`):

```r
devtools::load_all("/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm", quiet = TRUE)
set.seed(1)
n_cell <- 5
base <- data.frame(
  cell_id = rep(seq_len(n_cell), each = 2),
  source  = rep(c("po", "pa"), times = n_cell),
  env     = rep(rnorm(n_cell), each = 2)
)
sp1 <- ifelse(base$source == "po", rpois(nrow(base), 3), rbinom(nrow(base), 1, 0.5))
sp2 <- ifelse(base$source == "po", rpois(nrow(base), 2), rbinom(nrow(base), 1, 0.4))
sp3 <- ifelse(base$source == "po", rpois(nrow(base), 4), rbinom(nrow(base), 1, 0.6))
wide <- cbind(base, sp1 = sp1, sp2 = sp2, sp3 = sp3)
wide$e1 <- ifelse(wide$source == "po", log(1.2), 0)
wide$e2 <- ifelse(wide$source == "po", log(0.8), 0)
wide$e3 <- ifelse(wide$source == "po", log(1.5), 0)

## Q1
f <- traits(sp1, sp2, sp3) ~ 1 + latent(1 | cell_id, d = 1)
rw <- gllvmTMB:::rewrite_traits_lhs(formula = f, data = wide, eval_env = environment())

## Q2
fam_list <- list(po = poisson(), pa = binomial(link = "cloglog"))
attr(fam_list, "family_var") <- "source"
fit_q2 <- gllvmTMB(
  traits(sp1, sp2, sp3) ~ 1 + latent(1 | cell_id, d = 1),
  data = wide, unit = "cell_id", family = fam_list, silent = TRUE
)

## Q3
fit_q3 <- gllvmTMB(
  traits(sp1, sp2, sp3) ~ 1 + offset(e1, e2, e3) + latent(1 | cell_id, d = 1),
  data = wide, unit = "cell_id", family = fam_list, silent = TRUE
)

## Q4
getLV(fit_q2)
```

## Q1 — does the traits() expander carry a non-trait column (`source`) through?

**YES.** `data_long` verbatim columns: `cell_id, source, env, e1, e2, e3, trait, .y_wide_`.
`"source" %in% names(rw$data_long)` is `TRUE`, and the printed head shows `source` correctly
replicated per stacked-trait row (`po` rows keep `po`, `pa` rows keep `pa`):

```
   cell_id source        env        e1         e2        e3 trait .y_wide_
1        1     po -0.6264538 0.1823216 -0.2231436 0.4054651   sp1        2
2        1     po -0.6264538 0.1823216 -0.2231436 0.4054651   sp2        2
3        1     po -0.6264538 0.1823216 -0.2231436 0.4054651   sp3        4
4        1     pa -0.6264538 0.0000000  0.0000000 0.0000000   sp1        0
5        1     pa -0.6264538 0.0000000  0.0000000 0.0000000   sp2        1
6        1     pa -0.6264538 0.0000000  0.0000000 0.0000000   sp3        1
...
formula_long:
.y_wide_ ~ 0 + trait + latent(0 + trait | cell_id, d = 1)
```

This was expected from reading `tidyr::pivot_longer(cols = all_of(trait_cols), ...)`
(`R/traits-keyword.R:517-523`) — it never subsets to a `trait_cols`-only frame, so `source`
rides along automatically. No hidden failure at the plumbing layer.

## Q2 — does `attr(family_list, "family_var") <- "source"` survive and drive `family_id_vec`?

**YES**, once the toy data's grouping column name (`cell_id`) is passed as `unit = "cell_id"`
(the naive first call errored `Column site not found in data` — the default `unit` argument
is `"site"`, unrelated to this question; not a wide-format defect).

```
family_id_vec table:
fid
 1  2 
15 15 
crosstab family_id_vec x source:
    fid
      1  2
  pa 15  0
  po  0 15
```

`family_id_vec` comes back length 30 = `nrow(data_long)` = 5 cells x 2 sources x 3 traits, and
cross-tabs perfectly against `source`: every `pa` row is family id 1 (binomial), every `po` row
is family id 2 (poisson). `fam_var <- attr(family, "family_var") %||% "family"` (`R/fit-multi.R:510`)
reads straight off `data`, which by the time it reaches `gllvmTMB_multi_fit()` is already the
long-rewritten frame — the attribute mechanism does not care that the frame originated from a
wide pivot rather than a hand-built long frame.

## Q3 — does the wide `offset(e1, e2, e3)` survive row duplication?

**YES.** The fit completed and `fit_q3$tmb_data$offset` is `num [1:30]`, matching
`0.182 -0.223 0.405 0 0 ...` for the first cell's `po` row (its `e1,e2,e3` values) followed by
zeros for the `pa` row — exactly the per-row-duplicated stacking predicted. This was flagged as
the likeliest breaking point (the offset collapse happens once, per source row, in
`.traits_offset_rewrite()` before the pivot — `R/traits-keyword.R:469`), but it stacks in lockstep
with the response column via the same `t(as.matrix(...))` unstacking (`R/traits-keyword.R:542-548`)
and imposed no extra assumption about row uniqueness.

## Q4 — does `getLV()` return one score per CELL, not per cell x source?

**YES.** `dim(getLV(fit_q2))` is `5 x 1` — one latent score per `cell_id`, not per
`(cell_id, source)` pair (which would have been `10 x 1`). Confirms the framing in the task
prompt: duplicate `(unit, trait)` rows already share one latent score by the package's existing
long-format contract, and that contract composes unchanged with the wide pivot.

## Caveats / not tested here

- Only `d = 1`, `n_cell = 5`, one covariate (`env`, unused in the fitted formula), no PD-Hessian
  or recovery check — this is plumbing verification only, not the Phase A recovery gate ported
  to wide format.
- Did not check `attr(family, "family_var")` resolving to something OTHER than a literal column
  name already present pre-pivot (e.g. a derived factor) — `source` here is an ordinary column
  that ships through unmodified.
- Did not check interaction with `missing = miss_control(response = "include")` (NA-cell masking)
  in combination with mixed family — orthogonal to this question, untested.

WIDE FORMAT: WORKS — the `traits()` expander carries an arbitrary non-trait column (`source`) through the wide-to-long pivot untouched, `family_var` keyed on it produces a correct per-row `family_id_vec`, the wide `offset(e1,e2,e3)` stacks correctly across duplicated rows, and `getLV()` returns one score per cell (not per cell x source) — all four questions confirm the naive "wide can't work" expectation is wrong, with no code changes to the package required.
