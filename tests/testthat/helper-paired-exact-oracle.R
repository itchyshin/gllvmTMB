# Test-only dense Gaussian oracle for the exact two-kernel marginal route.
# This is independent of the TMB objective and uses base R matrix algebra.
.paper2_observed_covariance <- function(unit_id, trait_id, K_phy, K_tip,
                                        Sigma_phy, Sigma_tip,
                                        V_known = NULL) {
  n_unit <- nrow(K_phy)
  n_trait <- nrow(Sigma_phy)
  stopifnot(
    is.matrix(K_phy), is.matrix(K_tip),
    nrow(K_phy) == ncol(K_phy), nrow(K_tip) == ncol(K_tip),
    identical(dim(K_phy), dim(K_tip)),
    is.matrix(Sigma_phy), is.matrix(Sigma_tip),
    identical(dim(Sigma_phy), dim(Sigma_tip)),
    nrow(Sigma_phy) == ncol(Sigma_phy),
    length(unit_id) == length(trait_id),
    all(is.finite(unit_id)), all(is.finite(trait_id)),
    all(unit_id == as.integer(unit_id)),
    all(trait_id == as.integer(trait_id)),
    all(unit_id >= 1L & unit_id <= n_unit),
    all(trait_id >= 1L & trait_id <= n_trait)
  )
  symmetric <- function(x) isTRUE(all.equal(x, t(x), tolerance = 1e-12))
  if (!symmetric(K_phy) || !symmetric(K_tip) ||
      !symmetric(Sigma_phy) || !symmetric(Sigma_tip)) {
    stop("kernels and trait covariance matrices must be symmetric", call. = FALSE)
  }

  covariance <- kronecker(Sigma_phy, K_phy) +
    kronecker(Sigma_tip, K_tip)
  selected <- (trait_id - 1L) * n_unit + unit_id
  observed <- covariance[selected, selected, drop = FALSE]
  if (!is.null(V_known)) {
    if (!is.matrix(V_known) || !identical(dim(V_known), dim(observed)) ||
        !symmetric(V_known)) {
      stop("V_known must be a symmetric observed-cell covariance matrix",
           call. = FALSE)
    }
    observed <- observed + V_known
  }
  observed
}

.paper2_marginal_gaussian <- function(y, unit_id, trait_id, K_phy, K_tip,
                                      Sigma_phy, Sigma_tip,
                                      V_known = NULL, mean = rep(0, length(y))) {
  if (length(y) != length(unit_id) || length(y) != length(trait_id) ||
      length(y) != length(mean) || any(!is.finite(y)) ||
      any(!is.finite(mean))) {
    stop("y, mean, unit_id, and trait_id must have equal finite lengths",
         call. = FALSE)
  }
  covariance <- .paper2_observed_covariance(
    unit_id = unit_id, trait_id = trait_id, K_phy = K_phy, K_tip = K_tip,
    Sigma_phy = Sigma_phy, Sigma_tip = Sigma_tip, V_known = V_known
  )
  upper <- tryCatch(chol(covariance), error = function(e) {
    stop("selected covariance is not positive definite: ",
         conditionMessage(e), call. = FALSE)
  })
  residual <- y - mean
  whitened <- backsolve(upper, residual, transpose = TRUE)
  list(
    nll = unname(0.5 * (length(y) * log(2 * pi) +
      2 * sum(log(diag(upper))) + sum(whitened^2))),
    covariance = covariance
  )
}
