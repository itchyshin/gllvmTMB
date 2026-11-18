## Private, no-fit G2e support-multiplier fixture contract.
## G2e is deliberately separate from the frozen G2d runner and results.

g2e_truth_constants <- function() {
  list(
    alpha = c(sp1 = -1.40, sp2 = -1.20, sp3 = -1.55, sp4 = -1.35, sp5 = -1.60, sp6 = -1.10),
    beta = c(sp1 = -0.55, sp2 = 0.35, sp3 = 0.70, sp4 = -0.40, sp5 = 0.55, sp6 = 0.20),
    lambda = c(sp1 = 0.70, sp2 = -0.55, sp3 = 0.45, sp4 = 0.60, sp5 = -0.40, sp6 = 0.50),
    psi_sd = c(sp1 = 0.35, sp2 = 0.30, sp3 = 0.40, sp4 = 0.32, sp5 = 0.38, sp6 = 0.34),
    gamma = c(sp1 = 0.45, sp2 = -0.35, sp3 = 0.25, sp4 = -0.40, sp5 = 0.30, sp6 = 0.20),
    gbif_contrast = c(sp1 = 0.30, sp2 = -0.20, sp3 = 0.15, sp4 = -0.25, sp5 = 0.20, sp6 = -0.10)
  )
}

g2e_support_multiplier <- 2
g2e_seed <- 86101L

g2e_make_fixture <- function(seed = g2e_seed, n_cell = 120L) {
  stopifnot(identical(n_cell, 120L), identical(g2e_support_multiplier, 2))
  set.seed(seed)
  tr <- g2e_truth_constants()
  species <- names(tr$alpha)
  cells <- paste0("cell_", seq_len(n_cell))
  x <- seq(-1, 1, length.out = n_cell)
  b <- as.numeric(scale(stats::rnorm(n_cell)))
  z <- stats::rnorm(n_cell)
  eps <- sapply(tr$psi_sd, function(sd) stats::rnorm(n_cell, sd = sd))
  eta <- sweep(outer(x, tr$beta), 2L, tr$alpha, "+") + outer(z, tr$lambda) + eps
  a_g_baseline <- exp(seq(log(.8), log(2), length.out = n_cell))
  a_s_baseline <- exp(seq(log(.6), log(1.4), length.out = n_cell))
  a_g <- g2e_support_multiplier * a_g_baseline
  a_s <- g2e_support_multiplier * a_s_baseline
  grid <- expand.grid(cell_id = cells, trait = species, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  eta_vec <- as.vector(eta)
  b_vec <- rep(b, times = length(species))
  g_support <- rep(a_g, times = length(species))
  s_support <- rep(a_s, times = length(species))
  gbif <- transform(
    grid, source = "gbif", survey_event_id = NA_character_, branch = "count", support = g_support,
    value = stats::rpois(nrow(grid), g_support * exp(eta_vec + rep(tr$gbif_contrast, each = n_cell) + b_vec * rep(tr$gamma, each = n_cell))),
    visit = NA_integer_
  )
  pa <- lapply(seq_len(3L), function(event) transform(
    grid, source = "survey", survey_event_id = paste0("survey_v", event, "_", cell_id),
    branch = "pa", support = s_support,
    value = stats::rbinom(nrow(grid), 1L, -expm1(-s_support * exp(eta_vec))), visit = event
  ))
  rows_three <- do.call(rbind, c(list(gbif), pa))
  rows_one <- rbind(gbif, pa[[1L]])
  make_XB <- function(rows) {
    ix <- match(paste(rows$cell_id, rows$trait), paste(grid$cell_id, grid$trait))
    list(
      X = matrix(rep(x, times = length(species))[ix], ncol = 1L, dimnames = list(NULL, "env")),
      B = matrix(ifelse(rows$source == "gbif", b_vec[ix], NA_real_), ncol = 1L, dimnames = list(NULL, "bias"))
    )
  }
  one_design <- make_XB(rows_one)
  three_design <- make_XB(rows_three)
  list(
    one_visit = c(list(rows = rows_one), one_design),
    three_visit = c(list(rows = rows_three), three_design),
    truth = list(
      seed = seed, n_cell = n_cell, n_species = length(species), n_visit = 3L,
      support_multiplier = g2e_support_multiplier,
      support_g_baseline = a_g_baseline, support_s_baseline = a_s_baseline,
      support_g = a_g, support_s = a_s, eta = eta, x = x, b = b, z = z, eps = eps,
      shared_Sigma = tcrossprod(tr$lambda), psi_variance = tr$psi_sd^2, constants = tr
    )
  )
}

g2e_validate_fixture <- function(fx) {
  tr <- fx$truth
  one <- fx$one_visit
  three <- fx$three_visit
  stopifnot(
    identical(tr$n_cell, 120L), identical(tr$n_species, 6L), identical(tr$n_visit, 3L),
    identical(tr$support_multiplier, 2), identical(names(tr$constants$alpha), paste0("sp", 1:6)),
    identical(dim(tr$shared_Sigma), c(6L, 6L)), length(tr$psi_variance) == 6L,
    isTRUE(all.equal(tr$support_g, 2 * tr$support_g_baseline, tolerance = 0)),
    isTRUE(all.equal(tr$support_s, 2 * tr$support_s_baseline, tolerance = 0)),
    all(one$rows$source %in% c("gbif", "survey")),
    all(three$rows$source %in% c("gbif", "survey")),
    all(is.finite(three$B[three$rows$source == "gbif", 1L])),
    all(is.na(three$B[three$rows$source == "survey", 1L])),
    all(three$rows$branch[three$rows$source == "gbif"] == "count"),
    all(three$rows$branch[three$rows$source == "survey"] == "pa")
  )
  survey <- three$rows$source == "survey"
  event_count <- table(three$rows$cell_id[survey], three$rows$trait[survey])
  stopifnot(all(event_count == 3L), !anyDuplicated(three$rows[survey, c("cell_id", "trait", "survey_event_id")]))
  key <- paste(three$rows$source, three$rows$cell_id, three$rows$trait, three$rows$survey_event_id)
  one_key <- paste(one$rows$source, one$rows$cell_id, one$rows$trait, one$rows$survey_event_id)
  paired <- three$rows[match(one_key, key), , drop = FALSE]
  row.names(paired) <- row.names(one$rows) <- NULL
  stopifnot(identical(one$rows, paired))
  paired_index <- match(one_key, key)
  stopifnot(
    identical(one$X, three$X[paired_index, , drop = FALSE]),
    identical(one$B, three$B[paired_index, , drop = FALSE])
  )
  invisible(TRUE)
}

g2e_expected_information <- function(fx) {
  tr <- fx$truth
  species <- names(tr$constants$alpha)
  cell_species <- expand.grid(cell = seq_len(tr$n_cell), species = species, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  s <- match(cell_species$species, species)
  c <- cell_species$cell
  mu <- tr$support_g[c] * exp(tr$eta[cbind(c, s)] + tr$constants$gbif_contrast[s] + tr$b[c] * tr$constants$gamma[s])
  info <- vapply(seq_along(species), function(k) sum(mu[s == k] * tr$b^2), numeric(1))
  names(info) <- species
  survey_probability <- -expm1(-outer(tr$support_s, rep(1, length(species))) * exp(tr$eta))
  list(gamma_poisson_information = info, survey_probability = survey_probability)
}
