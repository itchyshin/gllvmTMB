## Explicit LA-MSPL admission registry (Phase 2)
##
## Re-expresses the current Bernoulli surface as named cells. This file
## does not admit a new family, link, or structure. The live fence remains
## `.gllvmTMB_mspl_prepare()`; a successful prepare must resolve exactly
## one `admitted` row. B2 evidence is `partial_incomplete` — do not treat
## a registry row as a covered claim.

.gllvmTMB_mspl_link_name <- function(link_id) {
  switch(
    as.character(as.integer(link_id[[1L]])),
    "0" = "logit",
    "1" = "probit",
    "2" = "cloglog",
    NA_character_
  )
}

## Identity is link_id 0 for gaussian; Bernoulli reuses 0 as logit.
## Poisson log is also link_id 0 in family_to_id(); do not call it logit.
.gllvmTMB_mspl_family_link_name <- function(family_id, link_id) {
  fid <- as.integer(family_id[[1L]])
  if (fid %in% c(0L, 9L)) {
    ## gaussian / student: identity is link_id 0. Do not call it logit.
    if (!identical(as.integer(link_id[[1L]]), 0L)) {
      return(NA_character_)
    }
    return("identity")
  }
  if (fid %in% c(2L, 3L, 4L, 5L, 6L, 10L, 11L, 15L)) {
    ## Poisson / lognormal / Gamma / nbinom2 / Tweedie /
    ## truncated_poisson / truncated_nbinom2 / nbinom1:
    ## family_to_id() stores log as link_id 0. Do not call it logit.
    return("log")
  }
  .gllvmTMB_mspl_link_name(link_id)
}

## ML Gram diagonal S_jj = N^{-1} sum_i (y_{it} - mean_t)^2 for each trait.
## Trait order follows sort(unique(trait_id)) as integers 1..p.
.gllvmTMB_mspl_S_diag <- function(y, trait_id, unit_id) {
  y <- as.numeric(y)
  trait_id <- as.integer(trait_id)
  unit_id <- as.integer(unit_id)
  traits <- sort(unique(trait_id))
  N <- length(unique(unit_id))
  if (!is.finite(N) || N < 2L) {
    .gllvmTMB_mspl_abort(
      "Gaussian LA-MSPL requires at least two units to form S."
    )
  }
  vapply(
    traits,
    function(t) {
      yt <- y[trait_id == t]
      if (length(yt) != N) {
        .gllvmTMB_mspl_abort(c(
          "Gaussian LA-MSPL requires a complete balanced trait x unit grid.",
          "x" = "Trait {.val {t}} has {length(yt)} rows; expected {N} units."
        ))
      }
      sjj <- mean((yt - mean(yt))^2)
      if (!is.finite(sjj) || !(sjj > 0)) {
        .gllvmTMB_mspl_abort(c(
          "Gaussian LA-MSPL requires strictly positive trait sample variances.",
          "x" = "Trait {.val {t}} has S_jj = {.val {sjj}}."
        ))
      }
      sjj
    },
    numeric(1)
  )
}

.gllvmTMB_mspl_registry <- function() {
  links <- c("logit", "probit", "cloglog")
  admitted_binom <- rbind(
    expand.grid(
      family = "binomial",
      link = links,
      structure = "ordinary",
      q = c(1L, 2L),
      stringsAsFactors = FALSE
    ),
    expand.grid(
      family = "binomial",
      link = links,
      structure = "spatial_indep",
      q = NA_integer_,
      stringsAsFactors = FALSE
    ),
    expand.grid(
      family = "binomial",
      link = links,
      structure = "spatial_latent",
      q = c(1L, 2L),
      stringsAsFactors = FALSE
    )
  )
  admitted_binom$status <- "admitted"
  admitted_binom$evidence <- "partial_b2_incomplete"
  admitted_binom$notes <- "Design 88 live surface; B2 shards incomplete; not a covered claim"
  admitted_binom$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    admitted_binom$family,
    admitted_binom$link,
    admitted_binom$structure,
    admitted_binom$q
  )

  admitted_gauss <- data.frame(
    family = "gaussian",
    link = "identity",
    structure = "ordinary",
    q = c(1L, 2L),
    status = "admitted",
    evidence = "oracle_local",
    notes = paste(
      "Phase 3 ordinary FA pick C (pinned sigma_eps); Hirose atom;",
      "experimental point only (se=FALSE smoke); not a covered campaign;",
      "SE/intervals PROTECTED on Codex Lane B"
    ),
    stringsAsFactors = FALSE
  )
  admitted_gauss$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    admitted_gauss$family,
    admitted_gauss$link,
    admitted_gauss$structure,
    admitted_gauss$q
  )

  ## Poisson ordinary q=1,2: experimental point after #1008 + G0 2026-08-16.
  ## #990 smoke was operational PASS / admit-evidence FAIL. Not covered.
  ## No public SE / vcov / confint.
  admitted_pois <- data.frame(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = c(1L, 2L),
    status = "admitted",
    evidence = "admit_packet",
    notes = paste(
      "Phase 4 GLM-outer W=diag(mu), not I_LA(beta);",
      "c_P event-count rate + event-weighted loading atom (#1008);",
      "experimental point (G0 2026-08-16); #990 operational PASS /",
      "admit-evidence FAIL; not a covered campaign; no public SE"
    ),
    stringsAsFactors = FALSE
  )
  admitted_pois$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    admitted_pois$family,
    admitted_pois$link,
    admitted_pois$structure,
    admitted_pois$q
  )

  ## nbinom1 / nbinom2 ordinary q=1,2: planned fenced tape. NOT admitted.
  planned_nb <- data.frame(
    family = rep(c("nbinom1", "nbinom2"), each = 2L),
    link = "log",
    structure = "ordinary",
    q = c(1L, 2L, 1L, 2L),
    status = "planned",
    evidence = "phase4_prep",
    notes = c(
      paste(
        "Phase 4 fenced planned tape: GLM-outer PMF-summed exact I,",
        "NOT quasi W=mu/(1+phi); public estimator=mspl is experimental;",
        "not admitted; not covered"
      ),
      paste(
        "Phase 4 fenced planned tape: GLM-outer PMF-summed exact I,",
        "NOT quasi W=mu/(1+phi); public estimator=mspl is experimental;",
        "not admitted; not covered"
      ),
      paste(
        "Phase 4 fenced planned tape: GLM-outer W=mu*phi/(phi+mu),",
        "not I_LA(beta); public estimator=mspl is experimental;",
        "not admitted; not covered"
      ),
      paste(
        "Phase 4 fenced planned tape: GLM-outer W=mu*phi/(phi+mu),",
        "not I_LA(beta); public estimator=mspl is experimental;",
        "not admitted; not covered"
      )
    ),
    stringsAsFactors = FALSE
  )
  planned_nb$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned_nb$family, planned_nb$link, planned_nb$structure,
    planned_nb$q
  )

  ## Gamma(log) and lognormal(log) ordinary q=1,2: planned Phase-4-style
  ## prep only. NOT admitted. No prepare widen. No C++ tape.
  planned_gamma <- data.frame(
    family = "gamma",
    link = "log",
    structure = "ordinary",
    q = c(1L, 2L),
    status = "planned",
    evidence = "phase4_prep",
    notes = paste(
      "Phase 4-style prep: GLM-outer W=phi (mean-inert);",
      "not Tweedie p->2; not admitted; not covered; se=FALSE only"
    ),
    stringsAsFactors = FALSE
  )
  planned_gamma$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned_gamma$family, planned_gamma$link, planned_gamma$structure,
    planned_gamma$q
  )

  planned_lnorm <- data.frame(
    family = "lognormal",
    link = "log",
    structure = "ordinary",
    q = c(1L, 2L),
    status = "planned",
    evidence = "phase4_prep",
    notes = paste(
      "Phase 4-style prep: GLM-outer W=1/sigma_eps^2 on log y;",
      "shared sigma_eps with gaussian is not a theorem transfer;",
      "not admitted; not covered; se=FALSE only"
    ),
    stringsAsFactors = FALSE
  )
  planned_lnorm$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned_lnorm$family, planned_lnorm$link, planned_lnorm$structure,
    planned_lnorm$q
  )

  ## Tweedie log / Beta logit ordinary q=1,2: planned fenced tape. NOT admitted.
  planned_tb <- data.frame(
    family = rep(c("tweedie", "Beta"), each = 2L),
    link = c("log", "log", "logit", "logit"),
    structure = "ordinary",
    q = c(1L, 2L, 1L, 2L),
    status = "planned",
    evidence = "phase4_prep",
    notes = c(
      paste(
        "Phase 4 fenced planned tape: working logistic W_* on eta",
        "(true W=mu^{2-p}/phi rewards phi -> 0; one-sided, not a repair);",
        "Huber on log_phi and logit(p-1); no public door;",
        "not admitted; not covered"
      ),
      paste(
        "Phase 4 fenced planned tape: working logistic W_* on eta",
        "(true W=mu^{2-p}/phi rewards phi -> 0; one-sided, not a repair);",
        "Huber on log_phi and logit(p-1); no public door;",
        "not admitted; not covered"
      ),
      paste(
        "Phase 4 fenced planned tape: GLM-outer Jeffreys I_mu (Ferrari-Cribari-Neto K_bb),",
        "w = phi^2 {mu(1-mu)}^2 {trigamma(a)+trigamma(b)};",
        "NOT coercive at mu -> 0/1 (hostility, not a repair);",
        "public estimator=mspl is experimental;",
        "not admitted; not covered"
      ),
      paste(
        "Phase 4 fenced planned tape: GLM-outer Jeffreys I_mu (Ferrari-Cribari-Neto K_bb),",
        "w = phi^2 {mu(1-mu)}^2 {trigamma(a)+trigamma(b)};",
        "NOT coercive at mu -> 0/1 (hostility, not a repair);",
        "public estimator=mspl is experimental;",
        "not admitted; not covered"
      )
    ),
    stringsAsFactors = FALSE
  )
  planned_tb$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned_tb$family,
    planned_tb$link,
    planned_tb$structure,
    planned_tb$q
  )

  ## Delta/hurdle ordinary q=1,2: planned Phase-4-style prep. NOT admitted.
  ## Prepare still rejects family_id 12/13 — no public estimator door.
  planned_hurdle <- data.frame(
    family = rep(c("delta_lognormal", "delta_gamma"), each = 2L),
    link = "log",
    structure = "ordinary",
    q = c(1L, 2L, 1L, 2L),
    status = "planned",
    evidence = "phase4_prep",
    notes = paste(
      "Phase 5 cell; Phase-4-style prep only; shared-eta hurdle atom;",
      "prepare still rejects family_id 12/13; no public estimator door;",
      "not admitted; not covered"
    ),
    stringsAsFactors = FALSE
  )
  planned_hurdle$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned_hurdle$family, planned_hurdle$link, planned_hurdle$structure,
    planned_hurdle$q
  )

  ## student / ordinal_probit / betabinomial / truncated_* / multinomial
  ## ordinary q=1,2: planned Phase-4-style prep. NOT admitted.
  ## Prepare still rejects family_id 8/9/10/11/14/16 — no public door.
  planned_rest <- data.frame(
    family = c(
      "student", "student",
      "ordinal_probit", "ordinal_probit",
      "betabinomial", "betabinomial",
      "truncated_poisson", "truncated_poisson",
      "truncated_nbinom2", "truncated_nbinom2",
      "multinomial", "multinomial"
    ),
    link = c(
      "identity", "identity",
      "probit", "probit",
      "logit", "logit",
      "log", "log",
      "log", "log",
      "logit", "logit"
    ),
    structure = "ordinary",
    q = rep(c(1L, 2L), 6L),
    status = "planned",
    evidence = "phase4_prep",
    notes = c(
      rep(paste(
        "Phase 4-style prep: GLM-outer W=(nu+1)/(nu+3)/sigma^2 (mean-inert);",
        "not Gaussian Hirose; prepare still rejects family_id 9;",
        "no public door; not admitted; not covered; se=FALSE only"
      ), 2L),
      rep(paste(
        "Phase 4-style prep: GLM-outer W=E[s_eta^2] (threshold probit);",
        "psi pinned at 1; not Bernoulli V_loading;",
        "prepare still rejects family_id 14; no public door;",
        "not admitted; not covered; se=FALSE only"
      ), 2L),
      rep(paste(
        "Phase 4-style prep: GLM-outer PMF-summed exact I_eta,",
        "NOT binomial N*mu*(1-mu); prepare still rejects family_id 8;",
        "no public door; not admitted; not covered; se=FALSE only"
      ), 2L),
      rep(paste(
        "Phase 4-style prep: GLM-outer W=Var(Y|Y>=1), NOT Poisson mu;",
        "prepare still rejects family_id 10; no public door;",
        "not admitted; not covered; se=FALSE only"
      ), 2L),
      rep(paste(
        "Phase 4-style prep: GLM-outer truncated exact I,",
        "NOT untruncated W=mu*phi/(phi+mu);",
        "prepare still rejects family_id 11; no public door;",
        "not admitted; not covered; se=FALSE only"
      ), 2L),
      rep(paste(
        "Phase 4-style prep: GLM-outer I=diag(p)-pp' on K-1 contrasts,",
        "NOT independent Bernoulli; prepare still rejects family_id 16;",
        "no public door; not admitted; not covered; se=FALSE only"
      ), 2L)
    ),
    stringsAsFactors = FALSE
  )
  planned_rest$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned_rest$family, planned_rest$link, planned_rest$structure,
    planned_rest$q
  )

  excluded <- data.frame(
    family = c(
      "binomial",
      "binomial",
      "binomial",
      "binomial",
      "binomial",
      "binomial"
    ),
    link = c(
      "logit",
      "logit",
      "logit",
      "logit",
      "logit",
      "logit"
    ),
    structure = c(
      "ordinary",
      "ordinary",
      "ordinary",
      "ordinary",
      "ordinary",
      "dep"
    ),
    q = c(3L, 1L, 1L, 1L, 1L, 1L),
    status = "excluded",
    evidence = "fence",
    notes = c(
      "q > 2 deferred",
      "trials > 1 / weighted binomial deferred",
      "missing responses deferred",
      "nonzero offset deferred",
      "free Bernoulli Psi deferred",
      "unstructured dep not an admitted MSPL structure"
    ),
    stringsAsFactors = FALSE
  )
  excluded$cell_id <- paste(
    .gllvmTMB_mspl_registry_cell_id(
      excluded$family,
      excluded$link,
      excluded$structure,
      excluded$q
    ),
    c(
      "qgt2",
      "trials",
      "missing",
      "offset",
      "psi",
      "dep"
    ),
    sep = ":"
  )

  rows <- rbind(
    admitted_binom, admitted_gauss, admitted_pois, planned_nb,
    planned_gamma, planned_lnorm, planned_tb, planned_hurdle,
    planned_rest, excluded
  )
  rows[order(rows$status, rows$family, rows$structure, rows$link, rows$q), ]
}

.gllvmTMB_mspl_registry_cell_id <- function(family, link, structure, q) {
  q_lab <- ifelse(is.na(q), "qNA", paste0("q", as.integer(q)))
  paste(family, link, structure, q_lab, sep = ":")
}

.gllvmTMB_mspl_registry_lookup <- function(
  family = "binomial",
  link,
  structure,
  q = NA_integer_
) {
  tbl <- .gllvmTMB_mspl_registry()
  q <- if (identical(structure, "spatial_indep")) {
    NA_integer_
  } else {
    as.integer(q)
  }
  want <- .gllvmTMB_mspl_registry_cell_id(family, link, structure, q)
  hit <- tbl[tbl$cell_id == want, , drop = FALSE]
  if (nrow(hit) != 1L) {
    return(NULL)
  }
  hit
}
