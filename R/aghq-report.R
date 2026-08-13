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
## SCOPE NOTE (fenced to this slice's file ownership -- see the AGHQ arc-0
## brief, "Do NOT edit NAMESPACE. Do NOT export anything"): these are plain
## functions, not exported via roxygen `@export`, so `S3method(AIC,
## gllvmTMB_multi)` / `S3method(BIC, gllvmTMB_multi)` are NOT added to
## NAMESPACE. Dispatch is instead wired at runtime via `registerS3method()`
## in `.onLoad()` below (see the comment there for why the obvious-looking
## "unexported function of the right name" is NOT sufficient on its own).
## `registerS3method()` is not a NAMESPACE edit and not an export.
AIC.gllvmTMB_multi <- function(object, ..., k = 2) {
  .gllvmTMB_check_weighted_objective(c(list(object), list(...)), "AIC")
  .aghq_check_engine_consistency(c(list(object), list(...)))
  .aghq_check_penalised(c(list(object), list(...)), "AIC")
  NextMethod()
}

BIC.gllvmTMB_multi <- function(object, ...) {
  .gllvmTMB_check_weighted_objective(c(list(object), list(...)), "BIC")
  .aghq_check_engine_consistency(c(list(object), list(...)))
  .aghq_check_penalised(c(list(object), list(...)), "BIC")
  NextMethod()
}

anova.gllvmTMB_multi <- function(object, ...) {
  objs <- c(list(object), list(...))
  is_fit <- vapply(objs, inherits, logical(1L), what = "gllvmTMB_multi")
  if (any(is_fit) && any(vapply(objs[is_fit], .gllvmTMB_is_mspl, logical(1L)))) {
    cli::cli_abort(c(
      "{.fn anova} and likelihood-ratio tests are not defined for LA-MSPL fits.",
      "i" = "LA-MSPL is a softly penalised point estimator, not a maximised ordinary likelihood."
    ), class = "gllvmTMB_mspl_model_comparison_unsupported")
  }
  NextMethod()
}

## VERIFIED (see this slice's report): an unexported `AIC.gllvmTMB_multi` is
## NOT enough for `AIC(fit)` to reach it. `AIC`/`BIC` are generics owned by
## `stats`, not `gllvmTMB`; `UseMethod("AIC")` inside `stats::AIC` resolves
## against the S3 method REGISTRATION table, not a plain search-path name
## lookup -- confirmed by `trace()`-instrumenting AIC.gllvmTMB_multi and
## observing it is never entered when calling `AIC(fit_lap, fit_aghq)`, even
## though `methods("AIC")` and `find("AIC.gllvmTMB_multi")` both show it as
## visible under `devtools::load_all()`'s export-all shim.
## `registerS3method()` is the fix and is NOT a NAMESPACE edit and NOT an
## export: it neither adds an `S3method()`/`export()` line to NAMESPACE nor
## makes `AIC.gllvmTMB_multi` callable as `gllvmTMB::AIC.gllvmTMB_multi()`;
## it only tells R's S3 dispatch table where to find the method for the
## `stats::AIC`/`stats::BIC` generics. This is the standard pattern for
## adding a method for another package's generic without formally
## depending on it (e.g. the `vctrs`-style `s3_register()` idiom).
## The 4th argument is load-bearing and was missing. `registerS3method()` looks
## the GENERIC up with `get(genname, envir = envir)`, and `envir` defaults to
## `parent.frame()` -- here the `.onLoad` frame. At load time only the base
## namespace is guaranteed present, so `AIC` was not found and `.onLoad` threw
## `object 'AIC' not found`. R CMD check surfaced that as three WARNINGs
## ("package can[not] be loaded with stated dependencies", "cannot be unloaded
## cleanly", "namespace cannot be loaded with stated dependencies") plus two
## NOTEs -- CRAN-blocking.
##
## `devtools::load_all()` does NOT reproduce it, which is exactly why a green
## `devtools::test()` run did not catch this and only R CMD check did.
##
## Naming `asNamespace("stats")` is the documented idiom, and is what the
## `vctrs::s3_register()` pattern cited above actually does: look the generic up
## where the generic LIVES, not wherever the call happens to sit. `stats` is
## already in DESCRIPTION Imports, so this adds no dependency and still requires
## no NAMESPACE edit -- the fence the original slice worked under is preserved.
.onLoad <- function(libname, pkgname) {
  registerS3method(
    "AIC", "gllvmTMB_multi", AIC.gllvmTMB_multi,
    envir = asNamespace("stats")
  )
  registerS3method(
    "BIC", "gllvmTMB_multi", BIC.gllvmTMB_multi,
    envir = asNamespace("stats")
  )
  registerS3method(
    "anova", "gllvmTMB_multi", anova.gllvmTMB_multi,
    envir = asNamespace("stats")
  )
}
