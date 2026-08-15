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

.gllvmTMB_mspl_registry <- function() {
  links <- c("logit", "probit", "cloglog")
  admitted <- rbind(
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
  admitted$status <- "admitted"
  admitted$evidence <- "partial_b2_incomplete"
  admitted$notes <- "Design 88 live surface; B2 shards incomplete; not a covered claim"
  admitted$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    admitted$family, admitted$link, admitted$structure, admitted$q
  )

  planned <- data.frame(
    family = "gaussian",
    link = "identity",
    structure = "ordinary",
    q = c(1L, 2L),
    status = "planned",
    evidence = "none",
    notes = "Phase 3 Heywood route; not admitted",
    stringsAsFactors = FALSE
  )
  planned$cell_id <- .gllvmTMB_mspl_registry_cell_id(
    planned$family, planned$link, planned$structure, planned$q
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

  rows <- rbind(admitted, planned, excluded)
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
