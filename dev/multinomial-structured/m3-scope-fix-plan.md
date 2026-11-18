# M3 scope-fix patch plan (WRITTEN, NOT APPLIED)

Written per the coordinator's instruction after the S3 calibration verdict
(`6f34568e`) measured M3 sensitivity at 0/3 on the pre-registered
`spatial_indep` labeled cell. This is a PLAN document only — `R/diagnose.R`
is not touched by this commit (`det-s2b-builder` holds it for the ordinal
arms right now; the coordinator applies this patch after that lands).

## Root cause (confirmed, not guessed)

`.gllvmTMB_multinomial_degeneracy_row()`'s M3 block (`R/diagnose.R`, current
lines 842-885, quoted in full below) requires `Lambda_spde` to be readable
via `.gllvmTMB_report_matrix(object, "Lambda_spde")` before it will test ANY
response block:

```r
m3_cells <- list()
if (isTRUE(object$use$spde)) {
  L_spde <- .gllvmTMB_report_matrix(object, "Lambda_spde")
  kappa <- tryCatch(.gllvm_spatial_kappa(object), error = function(e) NULL)
  kappa_ok <- is.numeric(kappa) && length(kappa) == 1L &&
    is.finite(kappa) && kappa > 0
  if (!is.null(L_spde) && kappa_ok) {
    row_idx <- .gllvmTMB_match_rows_by_trait(L_spde, trait_names, ids)
    practical_range <- sqrt(8) / as.numeric(kappa)
    diameter <- .gllvmTMB_spatial_domain_diameter(object)
    for (b in unique(block)) {
      b_row <- row_idx[block == b]
      keep <- !is.na(b_row)
      if (sum(keep) < 1L) next
      Lb <- L_spde[b_row[keep], , drop = FALSE]
      loads_spatial <- any(is.finite(Lb) & Lb != 0)
      if (!loads_spatial) next
      if (is.finite(diameter) && diameter > 0) {
        value <- practical_range / diameter
        hit <- is.finite(value) && value < multinomial_range_collapse_thresh
        metric <- "range_over_diameter"
      } else {
        value <- practical_range
        hit <- is.finite(value) && value < multinomial_range_collapse_thresh
        metric <- "range_absolute"
      }
      m3_cells[[length(m3_cells) + 1L]] <- data.frame(
        block = b, metric = metric, value = value, m3 = hit,
        stringsAsFactors = FALSE
      )
    }
  }
}
```

`src/gllvmTMB.cpp:2104-2133` shows `REPORT(Lambda_spde)` firing ONLY inside
`if (spde_lv_k > 0)` — the `spatial_latent()`/`spatial_dep()` low-rank
route. `spatial_indep()` (`spde_lv_k == 0`, the per-trait diagonal route)
never populates `Lambda_spde` at all; it has no loading matrix in the
mathematical sense (each trait's field is independent, scaled by its own
`tau`, no shared low-rank factor). So `L_spde` is always `NULL` for
`spatial_indep()` fits, `!is.null(L_spde)` is always `FALSE`, and the
`for (b in unique(block))` loop never runs — `m3_cells` stays empty and no
`multinomial_contrast_degeneracy` row is emitted for that fit at all
(confirmed empirically: all 20 `deg_m3_spatial_indep` refits in
`results/detector-calibration-mn-20260817-070537.csv` show
`det_status = NA`, not `PASS` or `WARN`).

This is a keyword-SCOPE bug, not a threshold problem: no value of
`multinomial_range_collapse_thresh` can fix it, because the code that would
compare against the threshold never executes for this route.

## Proposed fix

Add a second branch for the diagonal (`spde_lv_k == 0`) route, using
`log_tau_spde` (REPORTed per-trait, length `n_traits`, whenever
`spde_lv_k == 0 || spde_lv_unique == 1` — `src/gllvmTMB.cpp:2110-2119`)
instead of `Lambda_spde` to determine BOTH (a) whether a response block
participates in the spatial tier at all, and (b) nothing else — the
diagonal route has no among-contrast structure, so there is no M1/M2
analogue to compute here (see "What does NOT change" below).

```r
m3_cells <- list()
if (isTRUE(object$use$spde)) {
  L_spde <- .gllvmTMB_report_matrix(object, "Lambda_spde")
  kappa <- tryCatch(.gllvm_spatial_kappa(object), error = function(e) NULL)
  kappa_ok <- is.numeric(kappa) && length(kappa) == 1L &&
    is.finite(kappa) && kappa > 0
  if (kappa_ok) {
    practical_range <- sqrt(8) / as.numeric(kappa)
    diameter <- .gllvmTMB_spatial_domain_diameter(object)
    ## Two mutually exclusive routes populate m3_cells: the low-rank route
    ## (Lambda_spde readable -- spatial_latent()/spatial_dep(), UNCHANGED
    ## from the code above) and the NEW diagonal route (spatial_indep(),
    ## Lambda_spde absent, participation read from log_tau_spde instead).
    if (!is.null(L_spde)) {
      row_idx <- .gllvmTMB_match_rows_by_trait(L_spde, trait_names, ids)
      for (b in unique(block)) {
        b_row <- row_idx[block == b]
        keep <- !is.na(b_row)
        if (sum(keep) < 1L) next
        Lb <- L_spde[b_row[keep], , drop = FALSE]
        loads_spatial <- any(is.finite(Lb) & Lb != 0)
        if (!loads_spatial) next
        m3_cells[[length(m3_cells) + 1L]] <- .gllvmTMB_m3_row(
          b, practical_range, diameter, multinomial_range_collapse_thresh,
          route = "low_rank"
        )
      }
    } else {
      log_tau_spde <- object$report$log_tau_spde
      if (!is.null(log_tau_spde) && length(log_tau_spde) > 0L) {
        participates <- .gllvmTMB_spde_diag_participation(object, trait_names, ids)
        row_idx <- match(seq_along(ids), ids)  # ids are already trait indices
        for (b in unique(block)) {
          b_ids <- ids[block == b]
          if (!any(participates[as.character(b_ids)])) next
          m3_cells[[length(m3_cells) + 1L]] <- .gllvmTMB_m3_row(
            b, practical_range, diameter, multinomial_range_collapse_thresh,
            route = "diagonal"
          )
        }
      }
    }
  }
}
```

`.gllvmTMB_m3_row()`: a small extracted helper (factor out the
`value`/`hit`/`metric` construction that is currently inlined in the loop),
returning `data.frame(block = b, metric = ..., value = ..., m3 = hit,
route = route)` — the new `route` column is for the `value` text (see
"Value column" below), not a new gating condition.

`.gllvmTMB_spde_diag_participation()`: a NEW small helper, `object,
trait_names, ids -> named logical vector` (names = trait id as character).
**Open question to resolve during implementation, not guessed here**:
whether a multinomial trait that does NOT use the spatial tier (a mixed fit
where only SOME traits are spatial) gets a real, finite `log_tau_spde` entry
anyway (a harmless unused parameter) or a mapped-off placeholder. Recommend
checking `object$tmb_obj$env$map$log_tau_spde` first, mirroring
`.gllvmTMB_sigma_eps_mapped_off()`'s existing pattern (`R/diagnose.R:1190-1196`:
`map <- object$tmb_obj$env$map; if (!"log_tau_spde" %in% names(map)) <every
trait with a finite report value participates>; else <trait participates iff
its own map$log_tau_spde entry is NOT NA (mapped-off)>`) — this needs an
empirical check against a real mixed-family spatial_indep fit before
shipping, which this plan does not include (out of scope for a plan-only
commit). For the CURRENT calibration campaign's own fixtures (`multinomial`
is the only family, every trait spatial), this distinction does not arise
and either implementation would pass; it only matters for a future mixed-
family spatial_indep fit.

## What does NOT change

- `.gllvm_spatial_kappa()` already reads `report$kappa` first, unconditional
  on route (`R/plot.R:148-151`) — confirmed empirically, `kappa = 5513.33`
  read correctly off a `spatial_indep()` fit in this campaign's debug run.
  No change needed here; the coordinator's "read kappa from report$kappa
  regardless of route" instruction is already satisfied by existing code.
- No M1/M2 analogue is added for the diagonal route. `spatial_indep()` has
  no shared Lambda -- there is no "contrast variance" or "contrast rail" to
  test at the spatial tier for this route, the same structural reason M2 is
  exempt at `d = 1` (a single shared axis has no meaningful rail either).
  This should be stated explicitly in the roxygen once implemented, so a
  reader does not infer M1/M2 silently cover `spatial_indep()` once M3 does.
- SPDE loadings stay OUT of every absolute-loading statistic elsewhere in
  the file (the existing 6.5e6-vs-66 unit-tier hazard the roxygen already
  documents). The diagonal-route branch above never touches a Lambda matrix
  at all, so this invariant holds automatically, not by new code.

## Value column: carry the triggering diagnostic quantity per arm

Coordinator's second item: the row's `value` text should surface the
observed quantity that tripped each arm, not just the aggregate status.
Current behaviour, read from the row-assembly code (`R/diagnose.R`, the
`worst_line` block after the M1/M2/M3 tables are built):

```r
worst_line <- character(0)
if (!is.null(tab)) {
  hit <- tab[tab$m1 | tab$m2, , drop = FALSE]
  src <- if (nrow(hit) > 0L) hit[1L, , drop = FALSE] else tab[1L, , drop = FALSE]
  worst_line <- c(worst_line, paste0(
    src$block, "@", src$tier, ": d=", src$d,
    "; min_contrast_var=", .gllvmTMB_fmt_num(src$min_contrast_var),
    "; max_rail_rho=", .gllvmTMB_fmt_num(src$max_rail_rho)
  ))
}
if (!is.null(m3_tab)) {
  hit3 <- m3_tab[m3_tab$m3, , drop = FALSE]
  src3 <- if (nrow(hit3) > 0L) hit3[1L, , drop = FALSE] else m3_tab[1L, , drop = FALSE]
  worst_line <- c(worst_line, paste0(
    src3$block, "@spatial: ", src3$metric, "=",
    .gllvmTMB_fmt_num(src3$value)
  ))
}
```

This DOES already include `min_contrast_var` and `max_rail_rho` (M1/M2) and
`metric=value` (M3, e.g. `range_over_diameter=7e-05`) in the `value` text —
so the coordinator's concern is not "nothing is there", it is that BOTH
`min_contrast_var` and `max_rail_rho` are always printed together
regardless of which specific arm fired (an M2-only WARN still shows an
uninformative `min_contrast_var=0.38` next to the actually-triggering
`max_rail_rho=1`), and the new diagonal-route M3 finding needs its own
distinguishable text so a reader does not read a diagonal-route range
collapse as if it came from the low-rank route.

**Proposed refinement (bundle with the M3 scope fix, same PR):**
1. In the M1/M2 `worst_line` text, print only the quantity for the arm(s)
   that actually fired on `src` (`min_contrast_var=` only when `src$m1`,
   `max_rail_rho=` only when `src$m2`), falling back to both when
   `status == "PASS"` (so a healthy row still shows what it checked).
2. Tag the M3 `worst_line` text with the route
   (`"...@spatial(diagonal): range_over_diameter=..."` vs
   `"...@spatial(low_rank): range_over_diameter=..."`), using the `route`
   column `.gllvmTMB_m3_row()` now attaches.
3. Also surface the raw `practical_range` (not just the ratio) in the value
   text when a domain diameter is reachable, so a reader can see both the
   ratio that tripped the threshold and the absolute range in coordinate
   units without re-deriving it from `kappa`.

## Testing plan (once implemented)

Add to `tests/testthat/test-sanity-categorical.R`, mirroring the existing
`mk_mn(..., spde = list(...), use = list(spde = TRUE))` fixture shape but
WITHOUT a `Lambda_spde` (only `report$kappa` + `report$log_tau_spde`, no
`report$Lambda_spde` at all):
- a collapsed-kappa diagonal fixture fires M3 with `route = "diagonal"` (or
  however the value text ends up tagging it) and fires neither M1 nor M2;
- a healthy-kappa diagonal fixture PASSes with no `multinomial_contrast_degeneracy`
  arms fired;
- a MIXED fixture (one multinomial block on the low-rank route, another on
  the diagonal route in the same fit, if constructible) exercises both
  branches in one `check_gllvmTMB()` call without cross-contaminating each
  other's `value` text.

## Re-measurement plan (once implemented)

Re-run `dev/multinomial-structured/detector-calibration-mn.R --mode full`
(or a scoped re-run of just the `deg_m3_spatial_indep` cell, seeds
201:220 -- 20 fits, ~2 sec/fit, well under a minute) against the SAME
pre-registered labeled cell (`pass-criteria-detector-mn.md`'s 3 labeled
PD-Hessian range-collapse seeds: 303, 304, 312). Expect M3 sensitivity to
reach 3/3 (the fix makes the row appear and read the same
`kappa`/`practical_range`/`diameter` values that already produced the
labeled collapse in `results/s3-summary-20260816-190701.csv`), and expect
zero new false positives on the 17 non-labeled `spatial_indep` seeds in the
same cell (their `range_hat` values are already known from the committed
summary CSV and stay well above the `0.02` threshold). Also re-check the
`healthy_s4_re_int`/`healthy_d1_phylo_latent`/`healthy_s1b_phylo_latent_rep`
healthy pool is unaffected (none of those fixtures have any spatial tier at
all, so the diagonal branch should never fire on them) -- expect the same
0-FP result already measured.
