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
.gllvmTMB_mspl_family_link_name <- function(family_id, link_id) {
  if (identical(as.integer(family_id[[1L]]), 0L)) {
    if (!identical(as.integer(link_id[[1L]]), 0L)) {
      return(NA_character_)
    }
    return("identity")
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
  vapply(traits, function(t) {
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
  }, numeric(1))
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
    admitted_binom$family, admitted_binom$link, admitted_binom$structure,
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
    admitted_gauss$family, admitted_gauss$link, admitted_gauss$structure,
    admitted_gauss$q
  )

  excluded <- data.frame(
    family = c(
      "binomial", "binomial", "binomial", "binomial", "binomial",
      "binomial", "nbinom2", "poisson"
    ),
    link = c(
      "logit", "logit", "logit", "logit", "logit",
      "logit", "log", "log"
    ),
    structure = c(
      "ordinary", "ordinary", "ordinary", "ordinary", "ordinary",
      "dep", "ordinary", "ordinary"
    ),
    q = c(3L, 1L, 1L, 1L, 1L, 1L, 1L, 1L),
    status = "excluded",
    evidence = "fence",
    notes = c(
      "q > 2 deferred",
      "trials > 1 / weighted binomial deferred",
      "missing responses deferred",
      "nonzero offset deferred",
      "free Bernoulli Psi deferred",
      "unstructured dep not an admitted MSPL structure",
      "count families wait for Phase 4",
      "count families wait for Phase 4"
    ),
    stringsAsFactors = FALSE
  )
  excluded$cell_id <- paste(
    .gllvmTMB_mspl_registry_cell_id(
      excluded$family, excluded$link, excluded$structure, excluded$q
    ),
    c(
      "qgt2", "trials", "missing", "offset", "psi",
      "dep", "nbinom2", "poisson"
    ),
    sep = ":"
  )

  rows <- rbind(admitted_binom, admitted_gauss, excluded)
  rows[order(rows$status, rows$family, rows$structure, rows$link, rows$q), ]
}

.gllvmTMB_mspl_registry_cell_id <- function(family, link, structure, q) {
  q_lab <- ifelse(is.na(q), "qNA", paste0("q", as.integer(q)))
  paste(family, link, structure, q_lab, sep = ":")
}

.gllvmTMB_mspl_registry_lookup <- function(family = "binomial",
                                           link,
                                           structure,
                                           q = NA_integer_) {
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
