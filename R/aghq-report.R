## Slice B (Arc 0 AGHQ engine): make a fit's downstream surfaces TELL THE
## TRUTH about which integration engine produced it.
##
## `fit$aghq` (set by R/fit-multi.R, Stage 1a onward) is
##   list(used, k, blocks, optimizer, reason, passes, mode_shift)
## with `used = FALSE` for the ordinary Laplace fit (the default) and, on a
## fit that predates AGHQ entirely, `fit$aghq` is simply absent (NULL).
## Every helper below treats NULL and `used = FALSE` identically: "Laplace".

## A short human-readable label for the engine that produced `fit`. Used by
## print.gllvmTMB_multi(), summary.gllvmTMB_multi() (both in
## R/methods-gllvmTMB.R) and attached to the logLik() object so AIC()/BIC()
## can detect a cross-engine comparison.
##
## Deliberately reads only `fit$aghq$used`, `$k`, and `$reason` -- not
## `$blocks`/`$passes`/`$mode_shift` -- because those are provenance detail
## for `gllvmTMB_diagnose()`, not the one-line summary this label is for.
.aghq_engine_label <- function(fit) {
  info <- fit$aghq
  if (is.null(info) || !isTRUE(info$used)) {
    return("Laplace")
  }
  k <- info$k
  ## The node count isn't a separate field in `fit$aghq`; it's embedded in
  ## `$reason`'s "d = <d>, k = <k>, <nodes> node(s)" clause (R/fit-multi.R,
  ## the `aghq_info <- list(... reason = sprintf("quadrature on z_B (d = %d, k
  ## = %d, %d node%s); ...")` assignment). Parse it rather than recompute k^d,
  ## since d is not itself stored on `fit$aghq` either.
  n_nodes <- NA_integer_
  reason <- info$reason
  if (is.character(reason) && length(reason) == 1L) {
    m <- regmatches(reason, regexpr("[0-9]+(?=\\s*nodes?\\b)", reason, perl = TRUE))
    if (length(m) == 1L && nzchar(m)) {
      n_nodes <- suppressWarnings(as.integer(m))
    }
  }
  if (!is.null(k) && !is.na(k) && !is.na(n_nodes)) {
    sprintf("AGHQ (k = %d, %d nodes)", as.integer(k), n_nodes)
  } else if (!is.null(k) && !is.na(k)) {
    sprintf("AGHQ (k = %d)", as.integer(k))
  } else {
    "AGHQ"
  }
}

## Warn ONCE when an AIC()/BIC() call mixes fits from different engines.
## `objs` is the full list of arguments passed to AIC()/BIC() (`object`
## plus `...`); non-gllvmTMB_multi objects (e.g. comparing against a glmmTMB
## fit) are silently skipped -- this only fires on a genuine engine clash
## among gllvmTMB_multi fits.
.aghq_check_engine_consistency <- function(objs) {
  is_fit <- vapply(objs, inherits, logical(1L), what = "gllvmTMB_multi")
  if (sum(is_fit) < 2L) {
    return(invisible(NULL))
  }
  labels <- vapply(objs[is_fit], .aghq_engine_label, character(1L))
  if (length(unique(labels)) > 1L) {
    cli::cli_warn(c(
      "Comparing fits produced by different integration engines: {paste(unique(labels), collapse = ', ')}.",
      "i" = "A log-likelihood computed under AGHQ quadrature is not on the same scale as one computed under the Laplace approximation.",
      ">" = "AIC/BIC differences across engines are not meaningful; refit every model being compared with the same {.arg aghq} control setting."
    ), .frequency = "once", .frequency_id = "gllvmTMB-aghq-cross-engine-aic")
  }
  invisible(NULL)
}

## Warn whenever AIC()/BIC() is taken on a PENALISED (ridged) fit.
##
## With a loading ridge the optimiser minimises F + 0.5*||lambda||^2/tau^2, so the
## reported parameters are a MAP point while `opt$objective` -- and hence
## `logLik()` -- is the UNPENALISED objective evaluated there. AIC = -2*logLik +
## 2*df therefore combines a likelihood that is NOT at its maximum with a
## parameter count that does NOT describe the effective flexibility of a
## penalised fit. Neither half is what AIC assumes.
##
## This is a DISCLOSURE, not a correction: no penalised-AIC variant is
## substituted, because the honest replacement (an effective-df criterion) has
## not been derived or validated here. The user is told the quantity is not AIC
## rather than being handed a differently-wrong number silently.
.aghq_check_penalised <- function(objs, fn_label = "AIC") {
  is_fit <- vapply(objs, inherits, logical(1L), what = "gllvmTMB_multi")
  if (!any(is_fit)) {
    return(invisible(NULL))
  }
  if (any(vapply(objs[is_fit], .gllvmTMB_is_mspl, logical(1L)))) {
    cli::cli_abort(c(
      "{fn_label}() is not defined for an {.code estimator = \"mspl\"} fit.",
      "i" = "The stored log-likelihood is evaluated at a softly penalised point, not at its own maximum, and an effective degrees-of-freedom correction has not been derived.",
      ">" = "Use the same estimator's prespecified point-estimation and predictive validation metrics instead."
    ), class = "gllvmTMB_mspl_model_comparison_unsupported")
  }
  pen <- vapply(objs[is_fit], function(f) {
    tau <- f$aghq$ridge_tau
    isTRUE(f$aghq$penalised) ||
      (is.numeric(tau) && length(tau) == 1L && is.finite(tau) && tau > 0)
  }, logical(1L))
  if (!any(pen)) {
    return(invisible(NULL))
  }
  cli::cli_warn(c(
    "{fn_label}() on a fit with a loading ridge ({.arg aghq_ridge}): this is not {fn_label}.",
    "i" = "The ridge makes the reported estimate a penalised (MAP) point, while {.fn logLik} is the unpenalised log-likelihood AT that point -- not at its maximum.",
    "i" = "The parameter count also overstates a penalised fit's effective flexibility, so both halves of {fn_label} = -2*logLik + k*df are violated.",
    ">" = "For likelihood-based model comparison set {.code aghq_ridge = Inf} and refit every model being compared."
  ))
  invisible(NULL)
}

.gllvmTMB_check_weighted_objective <- function(objs, fn_label) {
  is_fit <- vapply(objs, inherits, logical(1L), what = "gllvmTMB_multi")
  weighted <- vapply(objs[is_fit], function(f) {
    isTRUE(f$likelihood_weights$active)
  }, logical(1L))
  if (any(weighted)) {
    cli::cli_abort(c(
      "{fn_label}() is undefined for a non-unit weighted objective.",
      "i" = "Ordinary information criteria require a maximized likelihood; this fit uses a weighted estimating criterion.",
      ">" = "Refit with unit likelihood weights before likelihood-based model comparison."
    ), class = "gllvmTMB_weighted_objective_no_information_criterion")
  }
  invisible(NULL)
}

## Under AGHQ (Stage 1a), the between-unit (z_B) latent block is REMOVED
## from the base `eta` that the template REPORTs -- src/gllvmTMB.cpp's
## eta-assembly loop guards the z_B contribution with
## `use_rr_B == 1 && use_aghq == 0` and adds it only per quadrature node,
## never back into the reported `eta`. The z_B PARAMETER itself is mapped
## off under AGHQ (not a random effect, and absent from `last.par.best`
## entirely). VERIFIED on a 12-site q = 1 binomial fixture (this slice's
## report has the full transcript): `report$eta` for the AGHQ fit collapsed
## to 2 distinct values (one per trait, i.e. fixed-effects-only) where the
## Laplace fit on the same data had 8; `last.par.best[names(.) == "z_B"]`
## was length 0 for the AGHQ fit vs. 12 real values for Laplace; and
## `getLV()` on the AGHQ fit silently returned all-NA rather than erroring.
##
## Any consumer reading `report$eta` for a training-row value, or z_B via
## `last.par.best` / `sd_report$par.random`, therefore silently DROPS the
## between-unit latent contribution under AGHQ rather than merely computing
## it on a different scale -- unlike the Wald-SE / bootstrap-variance
## differences elsewhere in this file, which are expected and correct.
## `predict()` and the conditional branch of `simulate()` are the two call
## sites of this in the hooked file; both call this warner. The
## UNCONDITIONAL `simulate()` path (the default) is NOT affected -- it
## rebuilds eta from `X_fix %*% b_fix` and freshly redrawn z ~ N(0, I) via
## `.simulate_eta_unconditional()`, never reading `report$eta` or z_B, so it
## is deliberately not warned here.
##
## This is scoped to `object$aghq$used`, which (per the AGHQ gate) is only
## ever TRUE for the single-block `rr_B`-only fits this gap applies to, so
## no further structural check is needed.
##
## UNVERIFIED / not attempted here: an actual repair (re-adding the
## adapted-mode contribution to `eta`/z_B for reporting purposes) touches
## the template's eta assembly and/or the post-fit state-forcing block in
## R/fit-multi.R, both outside this slice's file ownership.
.aghq_warn_re_gap <- function(object, fn_label) {
  if (!isTRUE(object$aghq$used)) {
    return(invisible(NULL))
  }
  cli::cli_warn(c(
    "{fn_label} on an AGHQ-fitted model does not currently include the between-unit ({.code z_B}) latent contribution.",
    "i" = "Under AGHQ, {.code z_B} is quadrature-internal and is not written back to {.code report$eta} or {.code last.par.best}; the result is fixed-effects-only, not per-unit.",
    ">" = "Refit with {.code aghq = FALSE} (Laplace) if you need per-unit predictions or conditional simulation."
  ), .frequency = "once", .frequency_id = paste0("gllvmTMB-aghq-re-gap-", fn_label))
  invisible(NULL)
}

## S3 overrides for the base generics. These intentionally do their own
## engine-consistency check and then hand off to `NextMethod()` (which
## resolves to `stats:::AIC.default` / `stats:::BIC.default`, since
## gllvmTMB_multi has no other class in its chain) for the actual
## computation -- so the returned data.frame, its row names, and the
## single-object numeric-vector return path are byte-identical to the
## pre-existing (undecorated) behaviour.
##
## EXPORT NOTE (revised, Arc O5 / issue #1242): the AGHQ arc-0 slice that
## created these functions worked under a scope fence ("Do NOT edit
## NAMESPACE. Do NOT export anything") and wired S3 dispatch at runtime via
## `registerS3method()` in `.onLoad()` instead of a roxygen `@export` tag,
## specifically to stay inside that fence. That fence does not apply to this
## later slice, `devtools::document()` flags the missing `@export` as a NOTE
## (no .Rd is generated for an S3 method that is exported this way, and
## `select_lv()` and `anova.gllvmTMB_multi()` need the SAME dispatch
## mechanism these functions already use, documented consistently), and a
## plain `@export` tag is what every other stats-generic S3 method in this
## package already uses (`logLik.gllvmTMB_multi`, `nobs.gllvmTMB_multi`,
## `coef.gllvmTMB_multi`, ...) -- see R/methods-gllvmTMB.R. Adding it here
## makes `AIC.gllvmTMB_multi` / `BIC.gllvmTMB_multi` / `anova.gllvmTMB_multi`
## consistent with the rest of the package and lets roxygen2 generate the
## `S3method(AIC, gllvmTMB_multi)` / `S3method(BIC, gllvmTMB_multi)` /
## `S3method(anova, gllvmTMB_multi)` NAMESPACE lines itself -- the exact
## registration the manual `.onLoad()` block below used to do by hand. The
## manual `.onLoad()` is therefore removed as redundant, not left in place
## as a defensive duplicate: a NAMESPACE `S3method()` entry is registered by
## R's own package-loading machinery before any `.onLoad()` hook runs, so a
## second, hand-written `registerS3method()` call would only re-register the
## identical entry.
##
## The underlying technical finding from the original comment (kept here
## because it explains WHY `@export` -- not just "any exported name" --
## is required) stays true: `AIC`/`BIC`/`anova` are generics owned by
## `stats`, not `gllvmTMB`, and `UseMethod()` inside them resolves against
## the S3 method REGISTRATION table, not a plain search-path name lookup.
## An unregistered `AIC.gllvmTMB_multi` -- however visible on the search
## path -- is never entered when calling `AIC(fit)`. Both `registerS3method()`
## and a NAMESPACE `S3method()` line solve this the same way; the latter is
## the idiomatic, roxygen2-maintained mechanism and is what CRAN expects.

#' @rdname gllvmTMB_multi-methods
#' @param k Penalty per parameter for [AIC()]; default `2` (ordinary AIC).
#' @export
AIC.gllvmTMB_multi <- function(object, ..., k = 2) {
  .gllvmTMB_check_weighted_objective(c(list(object), list(...)), "AIC")
  .aghq_check_engine_consistency(c(list(object), list(...)))
  .aghq_check_penalised(c(list(object), list(...)), "AIC")
  NextMethod()
}

#' @rdname gllvmTMB_multi-methods
#' @export
BIC.gllvmTMB_multi <- function(object, ...) {
  .gllvmTMB_check_weighted_objective(c(list(object), list(...)), "BIC")
  .aghq_check_engine_consistency(c(list(object), list(...)))
  .aghq_check_penalised(c(list(object), list(...)), "BIC")
  NextMethod()
}

## ---------------------------------------------------------------------
## anova.gllvmTMB_multi() -- Arc O5 (issue #1242, vault D-210)
## ---------------------------------------------------------------------
##
## Extends the pre-existing MSPL refusal with a full nested-model
## likelihood-ratio table. Two, and only two, kinds of transition between
## adjacent (by increasing parameter count) models are classified and
## tested:
##
##  * a FIXED-EFFECT (interior) step: the between-unit latent rank `d_B`,
##    the active covstruct routes (`$use`), and the family/link are
##    identical, and the smaller model's fixed-effect columns are a strict
##    subset of the larger's. This is an ordinary regular (non-boundary)
##    nested comparison; plain Wilks chi-square applies.
##  * a RANK (boundary) step of exactly ONE new latent dimension: fixed
##    effects, covstruct routes, and family/link are identical, and `d_B`
##    increases by exactly 1. The newly added loading column has
##    `p - d_prev` free parameters (the package's own lower-triangular `rr()`
##    identifiability convention, `src/gllvmTMB.cpp`'s
##    `gll_unpack_rr_loadings()`: `n_rows * rank - rank * (rank - 1) / 2` free
##    entries total, so one added column contributes exactly `p - d_prev`).
##    Under the null that column is 0, the chi-bar-square mixture
##    (`chibar2_pvalue()`, R/chibar.R) is used, WITH AN EXPLICIT CAVEAT: the
##    Self-Liang (1987) mixture assumes the boundary components are
##    mutually independent scalar variances with regular Fisher information
##    elsewhere. A newly added loading column is not literally a set of
##    independent scalar variances -- it is a VECTOR of loadings whose
##    direction is unidentified when the column is exactly 0 (the associated
##    latent score drops out of the likelihood entirely at that point, a
##    Davies (1977, 1987)-type nuisance-parameter-unidentified-under-the-null
##    complication on top of the ordinary boundary complication, closer to
##    the "testing the number of factors" / reduced-rank testing literature
##    than to a set of independent random-effect variances). No closed-form
##    correction for that additional complication is implemented here.
##    `chibar2_pvalue()` is used as a documented, testable APPROXIMATION
##    (matching GLLVM.jl's `select_lv`/`chibar2_pvalue` treatment of
##    K-selection, which makes the same simplification); its empirical size
##    is measured directly by simulation in
##    `tests/testthat/test-select-lv-anova.R` and the result -- whatever it
##    is -- is reported, not asserted, in `dev/gapclose/arcD/O5-report.md`.
##
## Anything else (more than one new latent dimension in a single step, a
## change to covstruct routes, family, or link, or a fixed-effect AND rank
## change in the same step) is a COMPOUND change this implementation does
## not classify, and the whole `anova()` call refuses with a named reason
## rather than guessing which test applies.

## Build a comparison signature: everything that must be IDENTICAL across
## every fit being compared, for `anova()` to be defined at all (data,
## estimator, engine, weighting, family). Returns a list; `anova()` checks
## element-wise equality across all fits and aborts naming the first
## mismatch.
.gllvmTMB_anova_global_check <- function(objs) {
  ## The MSPL refusal predates this arc (it is the ONE check the original
  ## anova.gllvmTMB_multi() body already had) and is checked first,
  ## independent of argument count or of every argument being a
  ## gllvmTMB_multi fit -- test-mspl-api.R calls `anova(fit)` with a SINGLE
  ## MSPL fit and expects this exact class, so it must fire before the
  ## "needs at least two fits" / "all arguments must be fits" checks below.
  is_fit <- vapply(objs, inherits, logical(1L), what = "gllvmTMB_multi")
  if (any(is_fit) && any(vapply(objs[is_fit], .gllvmTMB_is_mspl, logical(1L)))) {
    cli::cli_abort(c(
      "{.fn anova} and likelihood-ratio tests are not defined for LA-MSPL fits.",
      "i" = "LA-MSPL is a softly penalised point estimator, not a maximised ordinary likelihood."
    ), class = "gllvmTMB_mspl_model_comparison_unsupported")
  }
  if (length(objs) < 2L) {
    cli::cli_abort(
      c(
        "{.fn anova} needs at least two {.cls gllvmTMB_multi} fits to compare.",
        ">" = "Pass the fits you want compared, e.g. {.code anova(fit_d1, fit_d2)}, or use {.fn select_lv} to fit and compare a range of latent ranks in one call."
      ),
      class = "gllvmTMB_anova_not_comparable"
    )
  }
  if (!all(is_fit)) {
    cli::cli_abort(c(
      "{.fn anova} for {.cls gllvmTMB_multi} fits compares only {.cls gllvmTMB_multi} objects.",
      "i" = "{sum(!is_fit)} of {length(objs)} argument(s) are not gllvmTMB fits.",
      ">" = "Pass only objects returned by {.fn gllvmTMB}."
    ), class = "gllvmTMB_anova_not_comparable")
  }
  .gllvmTMB_check_weighted_objective(objs, "anova")

  estimators <- vapply(objs, function(f) toupper(f$estimator %||% NA_character_), character(1L))
  if (any(estimators != "ML")) {
    cli::cli_abort(c(
      "{.fn anova} likelihood-ratio comparison requires ordinary ML fits.",
      "i" = "REML likelihoods are not comparable across differing fixed-effect or random-effect structures, and {.fn anova} does not attempt to verify that restriction under REML.",
      ">" = "Refit every model with {.code REML = FALSE} (the default) before comparing with {.fn anova}."
    ), class = "gllvmTMB_anova_not_comparable")
  }

  engines <- vapply(objs, .aghq_engine_label, character(1L))
  if (length(unique(engines)) > 1L) {
    cli::cli_abort(c(
      "{.fn anova} requires every fit to use the same integration engine.",
      "i" = "Engines being compared: {paste(unique(engines), collapse = ', ')}.",
      ">" = "Refit every model with the same {.arg aghq} control setting before comparing."
    ), class = "gllvmTMB_anova_not_comparable")
  }

  pen <- vapply(objs, function(f) {
    tau <- f$aghq$ridge_tau %||% Inf
    isTRUE(f$aghq$penalised) ||
      (is.numeric(tau) && length(tau) == 1L && is.finite(tau) && tau > 0)
  }, logical(1L))
  if (any(pen)) {
    cli::cli_abort(c(
      "{.fn anova} is not defined when any compared fit used a loading ridge ({.arg aghq_ridge}).",
      "i" = "A ridge makes the reported likelihood a value at a penalised (MAP) point, not at its own maximum -- see {.fn logLik}'s penalised-fit warning.",
      ">" = "Refit with {.code aghq_ridge = Inf} for every model before a likelihood-ratio comparison."
    ), class = "gllvmTMB_anova_not_comparable")
  }

  nobs_v <- vapply(objs, stats::nobs, numeric(1L))
  if (length(unique(nobs_v)) > 1L) {
    cli::cli_abort(c(
      "{.fn anova} requires every fit to use the same data.",
      "i" = "Likelihood-contributing observation counts differ: {paste(nobs_v, collapse = ', ')}.",
      ">" = "Refit every model on identical data before comparing with {.fn anova}."
    ), class = "gllvmTMB_anova_not_comparable")
  }
  y_ref <- objs[[1L]]$tmb_data$y
  same_y <- vapply(objs[-1L], function(f) isTRUE(all.equal(f$tmb_data$y, y_ref)), logical(1L))
  if (!all(same_y)) {
    cli::cli_abort(c(
      "{.fn anova} requires every fit to use the same response data.",
      ">" = "Refit every model on identical data before comparing with {.fn anova}."
    ), class = "gllvmTMB_anova_not_comparable")
  }
  fam_ref <- objs[[1L]]$tmb_data$family_id_vec
  same_fam <- vapply(objs[-1L], function(f) identical(f$tmb_data$family_id_vec, fam_ref), logical(1L))
  if (!all(same_fam)) {
    cli::cli_abort(c(
      "{.fn anova} requires every fit to use the same family/link for every trait.",
      ">" = "Compare models that differ only in fixed effects or latent rank, not in family."
    ), class = "gllvmTMB_anova_not_comparable")
  }
  invisible(NULL)
}

## Classify one adjacent pair (already ordered by ascending npar) as an
## interior fixed-effect step, a single-dimension rank step, or a compound
## step this implementation refuses. Returns a list describing the step;
## does not itself compute a p-value.
.gllvmTMB_anova_classify_step <- function(prev, curr) {
  same_use <- identical(prev$use, curr$use)
  same_xfix <- identical(prev$X_fix_names, curr$X_fix_names)
  xfix_nested <- all(prev$X_fix_names %in% curr$X_fix_names)
  d_prev <- as.integer(prev$d_B %||% NA_integer_)
  d_curr <- as.integer(curr$d_B %||% NA_integer_)
  same_d <- isTRUE(identical(d_prev, d_curr))
  rank_step <- !is.na(d_prev) && !is.na(d_curr) && (d_curr - d_prev) >= 1L

  if (!xfix_nested) {
    return(list(kind = "not_nested"))
  }
  if (same_use && same_d && !same_xfix) {
    return(list(kind = "fixed"))
  }
  if (same_use && same_xfix && rank_step) {
    return(list(kind = "rank", delta_d = d_curr - d_prev, p_traits = curr$n_traits, d_prev = d_prev))
  }
  list(kind = "compound")
}

#' Likelihood-ratio comparison of nested `gllvmTMB` fits
#'
#' @description
#' Sequential nested likelihood-ratio comparison of two or more ordinary
#' (ML, unpenalised, non-MSPL) `gllvmTMB` fits, sorted by increasing free
#' parameter count. Each adjacent pair is classified as either an
#' **interior fixed-effect step** (plain Wilks chi-square applies) or a
#' **rank (boundary) step of exactly one new latent dimension** (the
#' Self-Liang chi-bar-square mixture is used, as an explicitly documented
#' approximation -- see Details). Anything else -- more than one new latent
#' dimension in a step, a change to covstruct routes/family, or a fixed-effect
#' change combined with a rank change in the same step -- is refused with a
#' named reason rather than guessed at.
#'
#' @param object,... Two or more fits from [gllvmTMB()].
#' @param test One of `"chibar"` (default: chi-bar-square for rank steps,
#'   plain chi-square for interior fixed-effect steps), `"chisq"` (plain
#'   chi-square everywhere -- **conservative** (its p-value is too large,
#'   understating the evidence) at a rank/boundary step, and flagged as such
#'   in the returned table's notes), or `"none"` (report the table with no
#'   p-values).
#'
#' @details
#' # Comparability (refused outright)
#' `anova()` aborts, naming the reason, if the fits: are not all
#' `gllvmTMB_multi` objects; include an LA-MSPL fit; include a `REML = TRUE`
#' fit; use different integration engines (Laplace vs AGHQ) or a loading
#' ridge; were fit to different data (row count, or the response itself), or
#' different families/links; or are not fixed-effect-nested when ordered by
#' parameter count. It also refuses (per-step, in the returned table's
#' `test`/`note` columns rather than aborting the whole call) any adjacent
#' pair that changes more than the latent rank `d` by more than one
#' dimension, or that changes both the fixed effects and the rank in the
#' same step -- compare those in separate steps instead.
#'
#' # The rank-step chi-bar-square is an approximation
#' The Self & Liang (1987) chi-bar-square mixture ([chibar2_pvalue()]) is
#' derived for `q` INDEPENDENT scalar boundary variance components with
#' regular Fisher information elsewhere. A newly added latent-loading column
#' is `p - d` free parameters (this package's `rr()` lower-triangular
#' identifiability convention), but they are not literally independent
#' scalar variances: at the null (the new column exactly 0) the associated
#' latent score itself becomes unidentified, which is closer to the
#' "testing the number of factors" / reduced-rank-testing literature (known
#' to have non-standard LRT asymptotics in general) than to Self & Liang's
#' setting. `anova()` uses the chi-bar-square mixture anyway, exactly as
#' GLLVM.jl's oracle implementation does for K-selection, but labels every
#' rank-step p-value with this caveat in the table's notes rather than
#' presenting it as an exact result. Its empirical size was measured by
#' simulation (`tests/testthat/test-select-lv-anova.R`,
#' `dev/gapclose/arcD/O5-report.md`); consult that evidence, not this
#' docstring, for whether it is close to nominal.
#'
#' @return A `data.frame` of class `c("anova.gllvmTMB_multi", "data.frame")`
#'   with columns `model`, `formula`, `d` (latent rank, `NA` if not
#'   applicable), `npar`, `logLik`, `deviance`, `df` (parameter-count
#'   change from the previous row), `LRT`, `test` (method actually used, or
#'   `"refused"`), and `p.value`. An attribute `"note"` carries a per-row
#'   explanation (recommended alternative when refused; the approximation
#'   caveat for chi-bar rows).
#'
#' @seealso [chibar2_pvalue()], [select_lv()]
#' @export
anova.gllvmTMB_multi <- function(object, ..., test = c("chibar", "chisq", "none")) {
  test <- match.arg(test)
  objs <- c(list(object), list(...))
  .gllvmTMB_anova_global_check(objs)

  ll_list <- lapply(objs, stats::logLik)
  npar_v <- vapply(ll_list, attr, numeric(1L), which = "df")
  if (anyDuplicated(npar_v)) {
    cli::cli_abort(
      c(
        "Two or more fits have the same number of free parameters ({unique(npar_v[duplicated(npar_v)])}); {.fn anova} cannot order them for a sequential comparison.",
        ">" = "Compare fits that differ in free parameters -- e.g. a different {.arg d} in {.fn latent} -- or drop the duplicate from the call. Equally sized models are not nested, so a sequential likelihood-ratio test does not apply to them."
      ),
      class = "gllvmTMB_anova_not_comparable"
    )
  }
  ord <- order(npar_v)
  objs <- objs[ord]
  ll_list <- ll_list[ord]
  npar_v <- npar_v[ord]

  n_rows <- length(objs)
  loglik_v <- vapply(ll_list, as.numeric, numeric(1L))
  d_B_v <- vapply(objs, function(f) {
    v <- f$d_B
    if (is.null(v)) NA_integer_ else as.integer(v)
  }, integer(1L))
  deviance_v <- -2 * loglik_v
  df_diff <- c(NA_real_, diff(npar_v))
  lrt_v <- c(NA_real_, -diff(deviance_v))
  method_v <- rep(NA_character_, n_rows)
  pvalue_v <- rep(NA_real_, n_rows)
  note_v <- rep(NA_character_, n_rows)

  for (i in seq_len(n_rows)[-1L]) {
    step <- .gllvmTMB_anova_classify_step(objs[[i - 1L]], objs[[i]])
    if (identical(step$kind, "not_nested")) {
      cli::cli_abort(c(
        "{.fn anova} requires nested fixed-effect structures.",
        "i" = "Model {i - 1}'s fixed effects are not a subset of model {i}'s.",
        ">" = "Compare only fits whose fixed-effect formulas nest."
      ), class = "gllvmTMB_anova_not_comparable")
    } else if (identical(step$kind, "compound")) {
      method_v[i] <- "refused"
      note_v[i] <- paste(
        "Models differ by more than a single latent-rank step or a clean nested",
        "fixed-effect change; this implementation does not classify the boundary",
        "geometry of a compound change. Compare in two separate steps (fixed",
        "effects, then rank, or vice versa), or use select_lv() for a",
        "criterion-based choice of rank."
      )
    } else if (identical(step$kind, "fixed")) {
      if (test == "none") {
        method_v[i] <- "none"
      } else {
        pvalue_v[i] <- stats::pchisq(lrt_v[i], df = df_diff[i], lower.tail = FALSE)
        method_v[i] <- "chisq"
        note_v[i] <- "Interior (regular) fixed-effect comparison; ordinary Wilks chi-square applies."
      }
    } else if (identical(step$kind, "rank")) {
      if (step$delta_d != 1L) {
        method_v[i] <- "refused"
        note_v[i] <- sprintf(
          paste(
            "delta d = %d spans more than one new latent dimension in a single",
            "step; chi-bar-square weights are not established here for compound",
            "rank changes (the boundary components are not shown independent).",
            "Compare one added dimension at a time, or use select_lv() for a",
            "criterion-based choice across many d."
          ),
          step$delta_d
        )
      } else {
        q <- step$p_traits - step$d_prev
        if (test == "none") {
          method_v[i] <- "none"
        } else if (test == "chisq") {
          pvalue_v[i] <- stats::pchisq(lrt_v[i], df = df_diff[i], lower.tail = FALSE)
          method_v[i] <- "chisq (requested)"
          note_v[i] <- paste(
            "User-requested plain chi-square at a boundary (rank) comparison:",
            "this p-value is too LARGE (the naive test is conservative, i.e.",
            "understates the evidence) because it ignores the positive",
            "probability mass the null places exactly at the boundary of the",
            "parameter space. Prefer test = \"chibar\", which is smaller and",
            "correctly sized for q independent boundary components."
          )
        } else {
          pvalue_v[i] <- chibar2_pvalue(lrt_v[i], q)
          method_v[i] <- sprintf("chibar (q=%d)", q)
          note_v[i] <- paste(
            "Self-Liang chi-bar-square mixture with q =", q,
            "independent boundary components (Self & Liang 1987). Independence",
            "of these q new loading parameters is a documented APPROXIMATION for",
            "gllvmTMB's rank/dimension test, not a proven fact for this",
            "parameterisation -- see ?anova.gllvmTMB_multi and",
            "dev/gapclose/arcD/O5-report.md for the measured empirical size."
          )
        }
      }
    }
  }

  out <- data.frame(
    model = paste0("Model ", seq_len(n_rows)),
    formula = vapply(objs, function(f) paste(deparse(f$formula), collapse = " "), character(1L)),
    d = d_B_v,
    npar = npar_v,
    logLik = loglik_v,
    deviance = deviance_v,
    df = df_diff,
    LRT = lrt_v,
    test = method_v,
    p.value = pvalue_v,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  attr(out, "note") <- note_v
  class(out) <- c("anova.gllvmTMB_multi", "data.frame")
  out
}

#' @rdname anova.gllvmTMB_multi
#' @param x An `"anova.gllvmTMB_multi"` object.
#' @export
print.anova.gllvmTMB_multi <- function(x, digits = 4, ...) {
  cat("Likelihood-ratio comparison of gllvmTMB fits\n\n")
  show <- as.data.frame(x)[, c("model", "d", "npar", "logLik", "deviance", "df", "LRT", "test", "p.value")]
  print(show, row.names = FALSE, digits = digits)
  notes <- attr(x, "note")
  has_notes <- !is.na(notes)
  if (any(has_notes)) {
    cat("\nNotes:\n")
    for (i in which(has_notes)) {
      cat(strwrap(sprintf("Model %d: %s", i, notes[i]), exdent = 2, prefix = "  ", initial = "  "), sep = "\n")
    }
  }
  invisible(x)
}
