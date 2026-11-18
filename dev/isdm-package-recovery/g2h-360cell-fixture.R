## Private, no-fit G2h fixture: 360 independent cells, six species, three PA visits.
g2h_truth_constants <- function() list(
  alpha = c(sp1=-1.40, sp2=-1.20, sp3=-1.55, sp4=-1.35, sp5=-1.60, sp6=-1.10),
  beta = c(sp1=-.55, sp2=.35, sp3=.70, sp4=-.40, sp5=.55, sp6=.20),
  lambda = c(sp1=.70, sp2=-.55, sp3=.45, sp4=.60, sp5=-.40, sp6=.50),
  psi_sd = c(sp1=.35, sp2=.30, sp3=.40, sp4=.32, sp5=.38, sp6=.34),
  gamma = c(sp1=.45, sp2=-.35, sp3=.25, sp4=-.40, sp5=.30, sp6=.20),
  gbif_contrast = c(sp1=.30, sp2=-.20, sp3=.15, sp4=-.25, sp5=.20, sp6=-.10)
)
g2h_seed <- 86121L
g2h_make_fixture <- function(seed = g2h_seed, n_cell = 360L) {
  stopifnot(identical(n_cell, 360L)); set.seed(seed)
  tr <- g2h_truth_constants(); species <- names(tr$alpha); cells <- paste0("cell_", seq_len(n_cell))
  x <- seq(-1, 1, length.out = n_cell)
  b_raw <- rnorm(n_cell); b <- as.numeric(scale(resid(stats::lm(b_raw ~ x))))
  z <- rnorm(n_cell); eps <- sapply(tr$psi_sd, function(sd) rnorm(n_cell, sd = sd))
  eta <- sweep(outer(x, tr$beta), 2L, tr$alpha, "+") + outer(z, tr$lambda) + eps
  a_g <- exp(seq(log(.8), log(2), length.out = n_cell)); a_s <- exp(seq(log(.6), log(1.4), length.out = n_cell))
  grid <- expand.grid(cell_id = cells, trait = species, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  eta_vec <- as.vector(eta); b_vec <- rep(b, times = length(species)); g_support <- rep(a_g, times = length(species)); s_support <- rep(a_s, times = length(species))
  gbif <- transform(grid, source = "gbif", survey_event_id = NA_character_, branch = "count", support = g_support,
    value = rpois(nrow(grid), g_support * exp(eta_vec + rep(tr$gbif_contrast, each = n_cell) + b_vec * rep(tr$gamma, each = n_cell))), visit = NA_integer_)
  pa <- lapply(1:3, function(v) transform(grid, source = "survey", survey_event_id = paste0("survey_v", v, "_", cell_id), branch = "pa", support = s_support,
    value = rbinom(nrow(grid), 1L, -expm1(-s_support * exp(eta_vec))), visit = v))
  rows <- do.call(rbind, c(list(gbif), pa)); ix <- match(paste(rows$cell_id, rows$trait), paste(grid$cell_id, grid$trait))
  list(rows = rows, X = matrix(rep(x, times = length(species))[ix], ncol = 1L, dimnames = list(NULL, "env")), B = matrix(ifelse(rows$source == "gbif", b_vec[ix], NA_real_), ncol = 1L, dimnames = list(NULL, "bias")), truth = list(seed = seed, n_cell = n_cell, n_species = 6L, n_visit = 3L, support_g = a_g, support_s = a_s, eta = eta, x = x, b = b, z = z, eps = eps, shared_Sigma = tcrossprod(tr$lambda), psi_variance = tr$psi_sd^2, constants = tr))
}
g2h_information_oracle <- function(fx) {
  tr <- fx$truth$constants; mu <- sapply(seq_len(6L), function(s) fx$truth$support_g * exp(fx$truth$eta[, s] + tr$gbif_contrast[[s]] + fx$truth$b * tr$gamma[[s]]))
  list(gamma_information = colSums(mu * fx$truth$b^2), x_b_correlation = cor(fx$truth$x, fx$truth$b), fixed_design_rank = qr(cbind(1, fx$truth$x, fx$truth$b))$rank)
}
g2h_validate_fixture <- function(fx) {
  o <- g2h_information_oracle(fx); survey <- fx$rows$source == "survey"
  stopifnot(identical(fx$truth$n_cell, 360L), identical(fx$truth$n_species, 6L), identical(fx$truth$n_visit, 3L), abs(o$x_b_correlation) <= .10, identical(o$fixed_design_rank, 3L), all(o$gamma_information >= 130), all(is.finite(fx$B[!survey, 1L])), all(is.na(fx$B[survey, 1L])), all(table(fx$rows$cell_id[survey], fx$rows$trait[survey]) == 3L))
  invisible(TRUE)
}
