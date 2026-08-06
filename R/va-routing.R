## Translation layer: the formula/data API -> the variational (VA-R3) engine.
##
## `gllvmTMB(control = gllvmTMBcontrol(integration = "va"))` is an opt-in
## research route. This file is the ONLY connection between the package's
## formula API and `.approximation_engine_fit()`. It is R-side only: Design 72
## s7 keeps TMB / likelihood changes with the maintainer and Codex, never here.
##
## The governing property is NO SILENT FALLBACK. Every path below either
## returns a variational fit or aborts. None returns a Laplace fit, and none
## quietly drops model structure the engine cannot represent -- a dropped
## phylo / spatial / random-intercept term would still report a healthy status
## while fitting a different model than the one the user wrote.


## Which covstruct is the ordinary latent (low-rank) term the engine fits?
##
## `latent()` is desugared to `rr()` before the parser sees it (R/brms-sugar.R).
## Two other things also produce `kind == "rr"` and are NOT what the engine's
## scalar-`q` signature represents:
##   * `.dep = TRUE` -- dep() / animal_dep(): a FULL-RANK unstructured Cholesky
##     with `d` resolved to n_traits, not a low-rank factor model.
##   * `.latent_augmented = TRUE` -- latent(1 + x | g): the B-tier
##     reaction-norm engine, whose loadings are over the augmented
##     (intercept, slope) x trait vector rather than the intercept-only Lambda.
.va_route_ordinary_rr_idx <- function(covstructs) {
  which(vapply(covstructs, function(cs) {
    identical(cs$kind, "rr") &&
      !isTRUE(cs$extra$.dep) &&
      !isTRUE(cs$extra$.latent_augmented)
  }, logical(1L)))
}

## `.envir` defaults to the CALLER's frame so that cli's `{}` interpolation
## resolves against the variables the message actually refers to, rather than
## against this function's own (empty) frame.
.va_route_abort <- function(msg, hint, .envir = parent.frame()) {
  cli::cli_abort(c(
    "{.code integration = \"va\"} does not admit this model.",
    "x" = msg,
    "i" = hint,
    ">" = "Use {.code integration = \"laplace\"} (the default) for this fit."
  ), call = NULL, .envir = .envir)
}

## Resolve family / link vectors for the fence and VA engine (Design 108 Stage 2).
## Mixed families are admitted when every row maps to a fenced VA family/link.
.va_route_family_link <- function(family_per_row, family_id_vec, link_id_vec) {
  family_id_vec <- as.integer(family_id_vec)
  link_id_vec <- as.integer(link_id_vec)
  ## Laplace -> VA code; refuse unsupported families before the fence message.
  ## LINK-AWARE by construction. Laplace gives binomial-logit and
  ## binomial-probit the same family_id and separates them by link_id only, so
  ## a link-blind map would send probit data to VA code 1 -- whose template
  ## branch is the LOGISTIC softplus. That is a wrong model reported healthy,
  ## which is precisely what this file exists to prevent, so the link travels
  ## into the mapping rather than being checked after it.
  va_codes <- tryCatch(
    .va_r3_laplace_id_to_code(family_id_vec, link_id_vec),
    error = function(e) {
      .va_route_abort(
        "The model uses a response family/link the variational route does not admit.",
        conditionMessage(e)
      )
    }
  )
  ## Link checks: code 1 is binomial-LOGIT and admits link_id 0 ONLY -- widening
  ## it to link_id 1 would re-open the wrong-model trap above. Probit has its own
  ## code (4) with its own template branch. poisson/nbinom2 log; gaussian
  ## identity (link_id 0 for gaussian in fit-multi).
  for (i in seq_along(va_codes)) {
    code <- va_codes[[i]]
    lid <- link_id_vec[[i]]
    ok <- (code == 1L && lid == 0L) ||
      (code %in% c(2L, 3L) && lid == 0L) ||
      (code == 0L && lid == 0L) ||
      (code == 4L && lid == 1L)
    if (!ok) {
      .va_route_abort(
        "A response uses a family/link pair the variational route does not admit.",
        "Admitted: gaussian identity, binomial logit, poisson log (and research nbinom2 log / binomial probit)."
      )
    }
  }
  ## Code 4 reports as family "binomial" with link "probit" so the FENCE, not
  ## this translation layer, is what refuses it -- and refuses it with the
  ## message a user who wrote binomial(link = "probit") needs to read. There is
  ## no recovery evidence for probit under VA, so it stays outside the fence.
  fam_names <- vapply(seq_along(va_codes), function(i) {
    switch(as.character(va_codes[[i]]),
           "0" = "gaussian", "1" = "binomial", "2" = "poisson",
           "3" = "nbinom2", "4" = "binomial", "binomial")
  }, character(1L))
  link_names <- vapply(va_codes, function(code) {
    switch(as.character(code),
           "0" = "identity", "1" = "logit", "2" = "log", "3" = "log",
           "4" = "probit", "logit")
  }, character(1L))
  list(
    family = fam_names,
    link = link_names,
    family_codes = as.integer(va_codes),
    is_mixed = length(unique(va_codes)) > 1L
  )
}

## The engine requires a DENSE crossed unit x trait design -- exactly one
## row per (unit, trait) cell (`.va_r3_validate_data()`, R/va-r3-proto.R). Long-
## format community data is frequently ragged, so this is checked here to give
## one clear message rather than a deep internal stop(). Design 107 keeps this
## dense layout under response="include" (masked cells remain as rows).
.va_route_check_complete_design <- function(unit_id, trait_id, n_units, n_traits) {
  cell <- as.integer(unit_id) * n_traits + as.integer(trait_id)
  expected <- n_units * n_traits
  if (length(cell) != expected || anyDuplicated(cell) != 0L ||
      !identical(sort(cell), seq.int(0L, expected - 1L))) {
    ## `n_units` is `nlevels()`, which counts levels with no rows. When that is
    ## the cause, the count in the message above looks wrong to the user, so
    ## name the real problem instead of leaving them to find it.
    n_present <- length(unique(unit_id))
    hint <- if (n_present < n_units) {
      "The unit factor has {n_units - n_present} level{?s} with no rows at all.
       {.code droplevels()} on the data will remove them; note this also
       changes the unit count the {.code n >= 100} admission check sees."
    } else {
      "Ragged designs (a response not measured at every unit) are outside the
       evidenced region. This is a data-shape limit of the engine, not a
       missing-data model."
    }
    .va_route_abort(
      "The unit x response design is not complete: the variational route needs
       exactly one row for every combination of {n_units} unit{?s} and
       {n_traits} response{?s} ({expected} rows), but the data supply
       {length(cell)}.",
      hint
    )
  }
  invisible(TRUE)
}

## The route proper. Called from `gllvmTMB_multi_fit()` once the design matrix
## and the id vectors exist, and BEFORE any TMB data assembly -- the
## variational route must not build the Laplace objective at all.
.gllvmTMB_va_route <- function(parsed, y, n_trials, X, unit_id, trait_id,
                               n_units, n_traits, unit_col, family_per_row,
                               family_id_vec, link_id_vec,
                               is_y_observed, weights_i, mi_enabled,
                               offset_expr, REML = FALSE,
                               lambda_constraint = NULL, Xcoef_fixed = NULL,
                               engine = "tmb", call = NULL,
                               va_H = 61L, va_eval_method = "auto") {
  covstructs <- parsed$covstructs
  rr_idx <- .va_route_ordinary_rr_idx(covstructs)

  if (length(rr_idx) == 0L) {
    .va_route_abort(
      "The model has no ordinary {.fn latent} term.",
      "There is no latent structure for a variational approximation to
       integrate over. Add a {.fn latent} term, or fit with Laplace."
    )
  }
  if (length(rr_idx) > 1L) {
    .va_route_abort(
      "The model has {length(rr_idx)} ordinary {.fn latent} terms.",
      "The variational engine represents one latent tier: one rank {.arg d} and
       one grouping. Fit a single {.fn latent} term, or use Laplace."
    )
  }

  cs <- covstructs[[rr_idx]]
  q <- as.integer(cs$extra$d %||% 1L)
  lv_group <- deparse(cs$group)

  ## The engine is handed ONE `unit_id` vector -- the fit's unit column. A
  ## latent term at any other admitted grouping (`site_species`, `species`,
  ## `cluster2`) would therefore be refitted at the unit level: a different
  ## model, reported healthy. Refuse instead of substituting.
  if (!identical(lv_group, unit_col)) {
    .va_route_abort(
      "The {.fn latent} term is grouped by {.val {lv_group}}, not by the unit
       column {.val {unit_col}}.",
      "The variational route fits latent scores at the unit level only. Fitting
       this term at {.val {unit_col}} instead would silently be a different
       model, so it is refused."
    )
  }

  ## Whitelist, not blacklist. The route honours exactly the latent options
  ## listed here; anything else present on the term would be SILENTLY DROPPED,
  ## which is the failure this file exists to prevent. Keeping it a whitelist
  ## means a latent option added later fails loudly here instead of being
  ## quietly ignored until someone notices the fit was wrong.
  ##   `d`        -- the rank, honoured (passed as `q`).
  ##   `lhs_form` -- the parsed left-hand side; carries no structure the engine
  ##                 needs beyond `X`, which is built from `parsed$fixed`.
  ## The `.` markers are the exclusion flags read by
  ## `.va_route_ordinary_rr_idx()` and by the Psi companion test.
  ##
  ## Measured, not assumed -- `names(cs$extra)` on the selected `rr` covstruct:
  ##   latent(unique = FALSE)          -> [d, lhs_form]
  ##   latent(unique = TRUE) / bare    -> [d, lhs_form]  (+ a `diag` companion)
  ##   latent() + explicit unique()    -> [d, lhs_form]
  ##   latent(..., lv = ~ x)           -> [d, lv_formula, lhs_form]  <- aborts
  ## so no supported form is refused, and the constrained ordination is.
  honoured_extra <- c("d", "lhs_form", ".dep", ".latent_augmented",
                      ".latent_augmented_unique", ".auto_unique")
  unhonoured <- setdiff(names(cs$extra), honoured_extra)
  if (length(unhonoured) > 0L) {
    hint <- if ("lv_formula" %in% unhonoured) {
      "A constrained ordination ({.code latent(..., lv = ~ x)}) needs a
       unit-level predictor channel the variational engine does not have; the
       constraint would be dropped and an UNCONSTRAINED ordination fitted."
    } else {
      "The variational route would silently ignore it and fit a different
       model."
    }
    .va_route_abort(
      "The {.fn latent} term carries {.arg {unhonoured}}, which the variational
       route cannot honour.",
      hint
    )
  }

  ## Psi is not stored as a flag. `latent(unique = TRUE)` folds in a paired
  ## `diag()` companion at the SAME group (R/brms-sugar.R), and the explicit
  ## `latent() + unique()` compatibility pair produces the same shape -- so the
  ## question "does this model carry Psi" is answered by co-occurrence.
  is_companion_diag <- vapply(covstructs, function(z) {
    identical(z$kind, "diag") && identical(deparse(z$group), lv_group)
  }, logical(1L))
  unique_flag <- any(is_companion_diag)

  ## Anything else in the formula would be SILENTLY DROPPED by a route that
  ## only wires (X, unit_id, trait_id, q). Refuse instead.
  accounted <- seq_along(covstructs) %in% rr_idx | is_companion_diag
  if (!all(accounted)) {
    ## Report the USER's keyword, not the parser's `kind`: dep() and augmented
    ## latent() both desugar to "rr", so naming the kind would tell the user
    ## their `dep()` term is an "rr" term.
    other <- vapply(covstructs[!accounted], function(z) {
      if (isTRUE(z$extra$.dep)) "dep"
      else if (isTRUE(z$extra$.latent_augmented)) "latent(1 + x | g)"
      else z$kind
    }, character(1L))
    .va_route_abort(
      "The model carries structure the variational route cannot represent:
       {.val {unique(other)}}.",
      "The route fits the ordinary {.fn latent} term only. Any phylogenetic,
       spatial, or additional random-effect structure would be dropped rather
       than fitted, so it is refused."
    )
  }

  fl <- .va_route_family_link(family_per_row, family_id_vec, link_id_vec)

  ## The fence, now with every value it was written to check. Until routing
  ## landed only `engine` was knowable, so `n`/`q`/`p`/family/link were
  ## implemented and tested but unreachable from `gllvmTMB()`.
  fam_link <- unique(data.frame(
    family = fl$family, link = fl$link, stringsAsFactors = FALSE
  ))
  .gllvmTMB_check_integration_fence(
    "va",
    family = fam_link$family, link = fam_link$link,
    q = q, p = n_traits, n = n_units,
    unique = unique_flag, engine = engine
  )
  ## nbinom2 is template-admitted but not on the public VA fence.
  if (any(fl$family_codes == 3L)) {
    .va_route_abort(
      "Family {.val nbinom2} has no admitted public variational evaluation.",
      "The variational fence currently admits gaussian, binomial, and poisson."
    )
  }

  ## Design 107 Gate A Stage 1: dense response masks travel as is_y_observed
  ## into the VA template (term-skip). Predictor missingness (mi) stays refused.
  if (isTRUE(mi_enabled)) {
    .va_route_abort(
      "The model has {.fn mi} missing predictors.",
      "The variational route has no latent covariate model."
    )
  }
  if (!is.null(offset_expr)) {
    .va_route_abort(
      "The model has an {.fn offset} term.",
      "The variational route has no offset channel; the offset would be
       dropped from the linear predictor."
    )
  }
  ## These three are consumed FURTHER DOWN `gllvmTMB_multi_fit()`, i.e. after
  ## this branch returns, so without an explicit refusal each would be accepted
  ## and then silently ignored.
  if (isTRUE(REML)) {
    .va_route_abort(
      "{.arg REML} is not available for the variational route.",
      "The variational objective has no restricted-likelihood form here; the
       request would be ignored rather than honoured."
    )
  }
  ## `length() > 0` rather than `!is.null()`: an empty list is a no-op under
  ## Laplace, so refusing it here would reject a fit that asks for nothing.
  if (length(lambda_constraint) > 0L) {
    .va_route_abort(
      "{.arg lambda_constraint} is not available for the variational route.",
      "The loading constraints would be dropped, fitting a confirmatory model
       as an exploratory one."
    )
  }
  if (length(Xcoef_fixed) > 0L) {
    .va_route_abort(
      "{.arg Xcoef_fixed} is not available for the variational route.",
      "The fixed coefficient values would be dropped and estimated freely."
    )
  }
  if (!is.null(weights_i) && !isTRUE(all.equal(unname(weights_i),
                                               rep(1, length(weights_i))))) {
    .va_route_abort(
      "The model has per-observation {.arg weights}.",
      "The variational route has no likelihood-weight channel. Binomial trial
       counts are supported and travel separately as {.arg n_trials}."
    )
  }
  .va_route_check_complete_design(unit_id, trait_id, n_units, n_traits)

  ## SETTLED by Gate 3 (2026-07-31), maintainer decision the same day. This was
  ## provisionally "gh" while the campaign ran; the campaign chose "jj".
  ##
  ## Under the paired-exclusion rule, va_jj passes the RMSE criterion in EVERY
  ## cell of the design (50/50; 54/54 raw), with a worst-case gap of 0.0393
  ## against a 0.05 tolerance. Ignoring the Laplace comparator entirely, it has
  ## the lower Sigma_B error in 52 of 54 cells (sign test p = 1.7e-13), and that
  ## holds in all eleven leave-one-out subsets over truth, q, p and n -- it is
  ## not carried by any single factor. va_gh passes 13/50, and 26 of its 35
  ## apparent raw-rule passes rest on a Laplace comparator that was itself
  ## degenerate.
  ##
  ## Still named EXPLICITLY rather than inherited from `default_tier` (which is
  ## also "jj", R/va-r3-proto.R): the choice is evidence, so it should be
  ## visible here and on the fit, not implied by a default that could move.
  ##
  ## Binomial only. The Jaakkola-Jordan bound is defined for the logistic term
  ## and nothing else -- poisson-log implements the single tier "gh", where the
  ## expectation is EXACT in closed form, so there is no estimator choice to
  ## make and no Gate 3 evidence to carry (the campaign was Bernoulli). Asking
  ## for "jj" there would simply error. "auto" resolves through the family
  ## registry, which is the right behaviour when the family admits one tier.
  ## Pure binomial keeps JJ (Gate 3); any mixed or non-binomial admitted set
  ## uses GH (Design 108 Stage 2). Named explicitly — "auto" would also resolve
  ## to GH for non-binomial registry entries, but mixed has no single registry
  ## default_tier, so the route pins "gh" rather than relying on that path.
  ## The routing above is what `va_eval_method = "auto"` resolves to, and "auto"
  ## is the default -- so this block is byte-equivalent to the previous hard-wire
  ## for every caller who does not opt out. A caller may now name the tier
  ## explicitly via `gllvmTMBcontrol(va_eval_method = )`; the engine
  ## (`.approximation_engine_va_r3_fit`) validates the family/tier pairing and
  ## refuses "jj" outside pure binomial-logit, so an impossible request errors
  ## there with a family-specific message rather than being silently re-routed.
  ##
  ## WHY THE OPT-OUT EXISTS. "auto" sends pure binomial-logit to "jj" (Gate 3,
  ## 2026-07-31, chosen on Sigma_B RMSE). But `jj`'s recovered loading scale is
  ## asymptotically biased -- trace 0.777/0.600/0.538/0.535 at n = 150...2000,
  ## a plateau, not a small-sample effect -- while `gh` converges (1.583 ->
  ## 1.132 -> 1.014). A user who needs loading MAGNITUDES rather than an
  ## ordination had no way to ask for the convergent route. Now they do.
  eval_method <- if (identical(va_eval_method, "auto")) {
    if (!isTRUE(fl$is_mixed) && all(fl$family_codes == 1L)) "jj" else "gh"
  } else {
    va_eval_method
  }

  ## KNOWN LIMITATION, recorded rather than guarded. The engine runs its own
  ## multi-start and optimiser policy, so `gllvmTMBcontrol()`'s search settings
  ## -- n_init, optimizer, optArgs, start_from, init_*, se -- do not reach it
  ## and have no effect on this route. They are search settings, not model
  ## structure: unlike the refusals above, ignoring them cannot change WHICH
  ## model is fitted, only how it is searched for. They are therefore accepted
  ## silently rather than made errors, which would break callers who set a
  ## house-standard control object and switch routes. Documented in
  ## ?gllvmTMBcontrol under `integration`.

  fit <- tryCatch(
    .approximation_engine_fit(
      engine = "va_r3",
      y = y, n_trials = n_trials, X = X,
      unit_id = unit_id, trait_id = trait_id,
      q = q, N = n_units, T = n_traits,
      family = if (isTRUE(fl$is_mixed)) "binomial" else fl$family[[1L]],
      link = if (isTRUE(fl$is_mixed)) "logit" else fl$link[[1L]],
      eval_method = eval_method,
      H = va_H,
      is_y_observed = is_y_observed,
      family_codes = fl$family_codes
    ),
    error = function(e) {
      cli::cli_abort(c(
        "The variational engine rejected this model.",
        "x" = conditionMessage(e),
        ">" = "Use {.code integration = \"laplace\"} (the default) for this fit."
      ), call = NULL)
    }
  )

  ## Health is recovery-shaped, not convergence-shaped: both engines report
  ## convergence == 0 on degenerate fits, which is why the engine computes its
  ## own multi-start / variance-domain status. A non-healthy status must abort
  ## rather than return an object whose problem is buried in $diagnostics.
  if (!identical(fit$status, "healthy")) {
    reason <- fit$engine_result$reason %||% NULL
    cli::cli_abort(c(
      "The variational fit did not pass its own health gate.",
      "x" = "Engine status: {.val {fit$status}}.",
      if (!is.null(reason)) c("i" = reason) else NULL,
      "i" = "Status, not the optimiser's convergence code, is the health signal
             for this engine.",
      ">" = "Use {.code integration = \"laplace\"} (the default) for this fit."
    ), call = NULL)
  }

  .va_route_build_fit(
    fit, call = call, q = q, p = n_traits, n = n_units,
    eval_method = eval_method,
    family = if (isTRUE(fl$is_mixed)) "mixed" else fl$family[[1L]],
    link = if (isTRUE(fl$is_mixed)) "mixed" else fl$link[[1L]]
  )
}

## Wrap the research-shaped engine result as a fitted object.
##
## The field vocabulary is deliberately kept DISJOINT from an ordinary fit --
## no `opt`, `report`, `sdr`, or `tmb_data`. That is a second, structural layer
## of the same protection the class choice gives: code written for a
## `gllvmTMB_multi` fit cannot accidentally find something plausible here.
.va_route_build_fit <- function(fit, call, q, p, n, eval_method, family, link) {
  fit$call <- call
  fit$integration <- "va"
  fit$eval_method <- eval_method
  fit$family <- family
  fit$link <- link
  fit$q <- q
  fit$p <- p
  fit$n <- n
  fit$fence_limits <- .gllvmTMB_integration_fence_limits()
  ## Explicit and load-bearing: the inverse VA Hessian is NOT calibrated
  ## frequentist uncertainty (Design 85 s10), so 0.6 ships this route with no
  ## standard errors and no intervals.
  fit$calibrated <- FALSE
  fit$package_version <- utils::packageVersion("gllvmTMB")
  class(fit) <- c("gllvmTMB_va", "gllvmTMB")
  fit
}
