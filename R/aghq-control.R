## Adaptive Gauss-Hermite quadrature (AGHQ) controller -- node grid, per-cell
## optimizer/node-count resolution, and the "auto" on/off decision.
##
## Owned by A1.  Every function here is internal (no @export, no NAMESPACE
## edit).  Consumers: E1's TMB data assembly (R/fit-multi.R) and G1's gate
## (R/aghq-gate.R) via the fixed interface contract:
##
##   .aghq_grid(d, k)                                  -> list(nodes, logw)
##   .aghq_resolve(family, tier, n_traits, q, control)  -> list(k, optimizer,
##                                                             optArgs, reason)
##   .aghq_auto_decide(gate_table, n_traits, q, n)      -> list(use, k, reason)

## ---------------------------------------------------------------------------
## (1) Tensor-product Gauss-Hermite grid
## ---------------------------------------------------------------------------

## Physicists' Gauss-Hermite nodes/weights for weight function exp(-x^2), via
## Golub-Welsch: the nodes are eigenvalues of the symmetric tridiagonal Jacobi
## matrix for Hermite polynomials (zero diagonal, off-diagonal sqrt(i/2)), and
## the weights are sqrt(pi) * (first component of eigenvector)^2. This avoids
## adding `statmod` as a dependency (not currently in DESCRIPTION Imports) for
## ~15 lines of linear algebra.
.gauss_hermite_physicist <- function(k) {
  if (!is.numeric(k) || length(k) != 1L || k < 1 || k != as.integer(k)) {
    stop(".gauss_hermite_physicist: k must be a positive integer.", call. = FALSE)
  }
  k <- as.integer(k)
  if (k == 1L) {
    return(list(nodes = 0, weights = sqrt(pi)))
  }
  i <- seq_len(k - 1L)
  off_diag <- sqrt(i / 2)
  J <- matrix(0, k, k)
  J[cbind(seq_len(k - 1L), 2:k)] <- off_diag
  J[cbind(2:k, seq_len(k - 1L))] <- off_diag
  eig <- eigen(J, symmetric = TRUE)
  nodes <- eig$values
  ord <- order(nodes)
  nodes <- nodes[ord]
  first_row <- eig$vectors[1, ord]
  weights <- sqrt(pi) * first_row^2
  list(nodes = nodes, weights = weights)
}

## `.aghq_grid(d, k)` -- the d-dimensional tensor Gauss-Hermite grid, ready for
## ADAPTIVE consumption: nodes on the standard-normal (probabilists') scale,
## and `logw` already carrying BOTH the exp(u'u) adaptive correction AND the
## sqrt(2)^d change-of-variables constant, so the template needs nothing but
## `exp(logw + aghq_logdet) * h(node)` -- no GH convention of its own.
##
## Derivation (Liu & Pierce 1994; this is the textbook adaptive-quadrature
## identity, verified below by the moment self-test, not a free design
## choice):
##   - Golub-Welsch gives physicists' nodes u_i, weights w_i for
##       integral f(x) exp(-x^2) dx  ~=  sum_i w_i f(u_i),  sum_i w_i = sqrt(pi).
##   - Adaptive quadrature at a site with mode x_hat and local Cholesky factor
##     L (from the site's Hessian; aghq_Lt/aghq_logdet in the DATA contract)
##     substitutes x = x_hat + sqrt(2) * L * u, whose Jacobian is
##     (sqrt(2))^d * det(L). Writing the true (possibly non-Gaussian-shaped)
##     integrand h(x) = f(u) * exp(-u'u) for a locally-well-behaved f gives
##       integral h(x) dx
##         ~= (sqrt(2))^d * det(L) * sum_i w_i * exp(u_i'u_i) * h(x_hat + sqrt(2) L u_i).
##   - We split that constant in two: `det(L)` is SITE-specific and lives in
##     the caller's `aghq_logdet` (not here); `(sqrt(2))^d` is universal
##     (function of d alone) and is folded into `logw` here, together with
##     the `exp(u_i'u_i)` correction, so the template only ever needs
##     `exp(logw_row + aghq_logdet_site) * h(node)` and never has to know
##     sqrt(2)^d exists. In probabilists' node coordinates z = sqrt(2)*u, the
##     per-dimension log-weight is therefore
##       log(w_i) + u_i^2 + 0.5*log(2)     (NOT divided by sqrt(pi): dividing
##     by sqrt(pi) would be the right constant for a NON-adaptive expectation
##     sum_i (w_i/sqrt(pi)) g(z_i) ~= E[g(Z)], but here `h` is the FULL joint
##     integrand -- likelihood times the latent Gaussian prior -- not `g`
##     alone, and folding in a stray sqrt(pi) division breaks exact recovery
##     of the identity-adaptation moment identities, confirmed by
##     `.aghq_grid_selftest()` below).
##   - The tensor grid over d dimensions has k^d rows; nodes[, j] is
##     dimension j's z-coordinate (probabilists' scale, unadapted at mode 0,
##     scale I), and logw is the log of the per-row product weight.
.aghq_grid <- function(d, k) {
  if (!is.numeric(d) || length(d) != 1L || d < 1 || d != as.integer(d)) {
    stop(".aghq_grid: d must be a positive integer.", call. = FALSE)
  }
  d <- as.integer(d)
  gh <- .gauss_hermite_physicist(k)
  u <- gh$nodes            # physicists' 1-D nodes
  w <- gh$weights          # physicists' 1-D weights

  # Per-node log-weight: raw physicists' weight + adaptive exp(u^2)
  # correction + the sqrt(2) Jacobian constant (per dimension; see comment
  # above for the full derivation and why this is NOT divided by sqrt(pi)).
  log_w1 <- log(w) + u^2 + 0.5 * log(2)
  z1 <- sqrt(2) * u

  # Tensor product across d dimensions via expand.grid (k^d rows), keeping
  # column j = dimension j throughout.
  idx <- do.call(expand.grid, rep(list(seq_len(k)), d))
  idx <- as.matrix(idx)[, rev(seq_len(d)), drop = FALSE]  # dimension-1 varies fastest
  nodes <- matrix(z1[idx], nrow = nrow(idx), ncol = d)
  logw <- rowSums(matrix(log_w1[idx], nrow = nrow(idx), ncol = d))

  list(nodes = nodes, logw = logw)
}

## Self-test: exercises `.aghq_grid()` exactly as an ADAPTIVE-quadrature
## template would -- at IDENTITY adaptation (mode = 0, site Jacobian
## det(L) = 1, i.e. `aghq_logdet` = 0) the consumer's formula collapses to
## `sum_i exp(logw_i) * h(node_i)` with `h(z) = g(z) * phi(z)` (the
## observation density times the standard-normal latent prior -- exactly what
## a per-site AGHQ nll contribution looks like with the likelihood replaced by
## a known polynomial g). This must recover E[g(Z)], Z ~ N(0,1), EXACTLY (up
## to floating point) for polynomial g of degree <= 2k-1, for both k and the
## exp(u'u)-correction/Jacobian folding to be correct -- an error in either
## would break this identity. Returns a data.frame of measured absolute
## errors; exercised by tests/testthat/test-aghq-golden.R (owned by E3).
.aghq_grid_selftest <- function(ks = c(3L, 5L, 7L, 9L, 11L)) {
  dnorm_prod <- function(nodes) {
    apply(nodes, 1, function(row) prod(dnorm(row)))
  }
  moment <- function(nodes, logw, powers) {
    w <- exp(logw) * dnorm_prod(nodes)
    z_pow <- rep(1, nrow(nodes))
    for (j in seq_along(powers)) z_pow <- z_pow * nodes[, j]^powers[j]
    sum(w * z_pow)
  }
  out <- do.call(rbind, lapply(ks, function(k) {
    g1 <- .aghq_grid(1L, k)
    g2 <- .aghq_grid(2L, k)
    data.frame(
      k = k,
      d = c(1L, 1L, 1L, 2L, 2L),
      moment = c("E[1]", "E[z^2]", "E[z^4]", "E[1]", "E[z1^2*z2^2]"),
      target = c(1, 1, 3, 1, 1),
      value = c(
        moment(g1$nodes, g1$logw, 0),
        moment(g1$nodes, g1$logw, 2),
        moment(g1$nodes, g1$logw, 4),
        moment(g2$nodes, g2$logw, c(0, 0)),
        moment(g2$nodes, g2$logw, c(2, 2))
      )
    )
  }))
  out$abs_error <- abs(out$value - out$target)
  out
}

## ---------------------------------------------------------------------------
## (2) Per-cell node count + optimizer resolution
## ---------------------------------------------------------------------------

## Node floor: Rabe-Hesketh, Skrondal & Pickles (2002, "Reliable estimation of
## generalized linear mixed models using adaptive quadrature", Stata Journal)
## warn that too few quadrature points flatten the log-likelihood w.r.t.
## covariance parameters and drive predicted posterior SDs toward zero -- a
## live failure mode in this package's variance-component estimation. The
## floor is 5, not 1.
.AGHQ_K_LADDER <- c(5L, 7L, 9L, 11L)
.AGHQ_K_FLOOR <- 5L

## Starting rung on the ladder, by family/tier regime. Discrete/sparse
## responses and families whose conditional shape is least quadratic
## (hurdle/delta, ordinal, Tweedie) start higher on the ladder; continuous,
## more Gaussian-like conditionals start at the floor.
.aghq_start_index <- function(family, tier) {
  family <- tolower(as.character(family))
  tier <- tolower(as.character(tier))

  high_curvature <- c(
    "tweedie", "ordinal", "ordinal_probit", "ordinal_logit",
    "hurdle_poisson", "hurdle_nbinom2", "hurdle_gaussian",
    "delta_gamma", "delta_lognormal", "zip", "zinb"
  )
  discrete_sparse <- c("binomial", "bernoulli", "poisson", "nbinom1", "nbinom2")

  if (any(vapply(high_curvature, function(p) grepl(p, family, fixed = TRUE), logical(1)))) {
    return(3L)  # start at k = 9
  }
  if (any(vapply(discrete_sparse, function(p) grepl(p, family, fixed = TRUE), logical(1)))
      && grepl("sparse|jj|rare", tier)) {
    return(2L)  # start at k = 7
  }
  if (any(vapply(discrete_sparse, function(p) grepl(p, family, fixed = TRUE), logical(1)))) {
    return(1L)  # start at k = 5 (floor) for ordinary discrete cells
  }
  1L  # continuous / gaussian-like: start at the floor
}

## Per-(family, tier) optimizer table. Measured evidence: a family-level
## choice is wrong because binomial's two tiers point in OPPOSITE directions
## (binomial-jj favours lbfgsb 2.54x; binomial-gh favours nlminb, where lbfgsb
## is 1.7x SLOWER). nbinom2 favours nlminb (lbfgsb 2.4x slower). Unknown
## cells default to nlminb as the safe choice.
.aghq_optimizer_table <- function(family, tier) {
  family <- tolower(as.character(family))
  tier <- tolower(as.character(tier))

  if (grepl("binomial", family) && grepl("jj", tier)) {
    return(list(optimizer = "lbfgsb", reason = "binomial-jj: lbfgsb measured 2.54x faster"))
  }
  if (grepl("binomial", family) && grepl("gh", tier)) {
    return(list(optimizer = "nlminb", reason = "binomial-gh: lbfgsb measured 1.7x slower here (opposite of binomial-jj)"))
  }
  if (grepl("nbinom2", family)) {
    return(list(optimizer = "nlminb", reason = "nbinom2: lbfgsb measured 2.4x slower"))
  }
  list(optimizer = "nlminb", reason = "unknown (family, tier) cell: nlminb is the safe default")
}

## `.aghq_resolve(family, tier, n_traits, q, control)` -> list(k, optimizer,
## optArgs, reason).
##
## Climbs the node ladder {5, 7, 9, 11} starting from a family/tier-dependent
## rung. Ladder climbing itself (stop when the objective stops moving) is a
## runtime decision made by the caller across successive fits; this function
## supplies the STARTING k for that climb and the fixed ceiling, plus the
## optimizer/optArgs for the resolved (family, tier) cell. If `control$aghq`
## is a positive integer, that k is used directly (user override) and the
## ladder is not consulted.
.aghq_resolve <- function(family, tier, n_traits, q, control = list()) {
  opt <- .aghq_optimizer_table(family, tier)
  optArgs <- list()
  if (identical(opt$optimizer, "lbfgsb")) {
    # MUST accompany every lbfgsb route: with optim's default factr, lbfgsb
    # terminates in ~24ms at an objective 125-151 WORSE while still reporting
    # convergence = 0 (measured, 3/3 replicates).
    optArgs$factr <- 1e-12 / .Machine$double.eps
  }

  user_k <- control$aghq
  if (is.numeric(user_k) && length(user_k) == 1L && user_k >= 1) {
    k <- as.integer(user_k)
    reason <- sprintf(
      "user override: aghq = %d (node ladder not consulted); optimizer = %s (%s)",
      k, opt$optimizer, opt$reason
    )
    return(list(k = k, optimizer = opt$optimizer, optArgs = optArgs, reason = reason))
  }

  start_idx <- .aghq_start_index(family, tier)
  k <- .AGHQ_K_LADDER[start_idx]
  reason <- sprintf(
    "family = %s, tier = %s: start k = %d on ladder {%s} (floor %d, RSP 2002); climb until objective stops moving; optimizer = %s (%s)",
    family, tier, k, paste(.AGHQ_K_LADDER, collapse = ","), .AGHQ_K_FLOOR,
    opt$optimizer, opt$reason
  )
  list(k = k, optimizer = opt$optimizer, optArgs = optArgs, reason = reason)
}

## ---------------------------------------------------------------------------
## (3) The "auto" on/off decision
## ---------------------------------------------------------------------------

## Cluster-size (= n_traits, NOT n_sites) cutoff above which AGHQ is declined
## by default. Grounded in Pinheiro & Chao (2006, JCGS, "Efficient Laplacian
## and adaptive Gaussian quadrature algorithms for multilevel generalized
## linear mixed models"): they measured the AGHQ-over-Laplace gain falling
## from 5-15% at d=1 with ~5 observations per cluster, to 2-5% at d=2 with 20,
## to three-decimal agreement (i.e. negligible) at d=3 with >= 30. The
## observations-per-cluster axis in THIS package is n_traits per site (the
## stacked-trait "cluster" at one latent-variable site), not the number of
## sites. We decline auto-AGHQ once n_traits >= 20: below Pinheiro & Chao's
## d=2/n=20 cell the gain is still in the few-percent range and worth 3^q-9^q
## extra cost; at or above it, cost keeps climbing (k^(q+1)) while the
## measured payoff is already approaching the three-decimal floor, so
## defaulting on would spend real cost chasing a gain the literature shows is
## nearly gone.
.AGHQ_AUTO_N_TRAITS_CUTOFF <- 20L

## The call-site seam for the auto decision.
##
## `.aghq_auto_decide()` below was written complete and then left with NO CALL
## SITE. `aghq = "auto"` ran through `.gllvmTMB_aghq_k()`, which asks
## `.aghq_resolve()` for a NODE COUNT and never for the on/off decision, so
## "auto" always turned AGHQ ON and the n_traits cutoff could never fire.
##
## This wraps the decision for the fit-time eligibility chain, which is the one
## place where the gate table exists. Returns NULL when AGHQ may proceed, or the
## decline reason when the auto policy says no.
##
## Only `aghq = "auto"` is subject to the policy: an EXPLICIT numeric `aghq` is
## a deliberate request and is never vetoed here. The cutoff is a default, not a
## prohibition.
.aghq_auto_gate <- function(control, gate_table, n_traits, q, n) {
  if (!identical(control$aghq, "auto")) {
    return(NULL)
  }
  dec <- .aghq_auto_decide(gate_table, n_traits, q, n)
  if (isTRUE(dec$use)) {
    return(NULL)
  }
  dec$reason
}

## `.aghq_auto_decide(gate_table, n_traits, q, n)` -> list(use, k, reason).
## `gate_table` is the data.frame produced by `.aghq_gate()` (owned by G1):
## columns block, size, n_components, treewidth, route, reason. This function
## makes the FINAL default call for `aghq = "auto"`: reliability first, so
## any ambiguity in the gate (missing/malformed table, no "quadrature"-routed
## block, treewidth unresolved) declines to Laplace.
.aghq_auto_decide <- function(gate_table, n_traits, q, n) {
  decline <- function(reason) list(use = FALSE, k = NA_integer_, reason = reason)

  if (!is.data.frame(gate_table) || nrow(gate_table) == 0L) {
    return(decline("auto: gate table missing or empty -- reliability first, declining to Laplace"))
  }
  needed <- c("block", "size", "n_components", "treewidth", "route", "reason")
  if (!all(needed %in% names(gate_table))) {
    return(decline("auto: gate table missing expected columns -- reliability first, declining to Laplace"))
  }
  quad_rows <- gate_table[gate_table$route == "quadrature", , drop = FALSE]
  if (nrow(quad_rows) == 0L) {
    return(decline("auto: gate found no affordable quadrature-routed block -- staying with Laplace"))
  }
  if (!is.numeric(n_traits) || length(n_traits) != 1L || is.na(n_traits) || n_traits < 1) {
    return(decline("auto: n_traits not resolvable -- reliability first, declining to Laplace"))
  }
  if (!is.numeric(q) || length(q) != 1L || is.na(q) || q < 1) {
    return(decline("auto: latent dimension q not resolvable -- reliability first, declining to Laplace"))
  }
  if (any(is.na(quad_rows$treewidth))) {
    return(decline("auto: gate reports an unresolved treewidth -- reliability first, declining to Laplace"))
  }

  if (n_traits >= .AGHQ_AUTO_N_TRAITS_CUTOFF) {
    return(decline(sprintf(
      "auto: n_traits = %d >= cutoff %d -- Pinheiro & Chao (2006) measure the AGHQ-over-Laplace gain falling to three-decimal agreement by cluster size ~30 at d=3 (and already small at d=2, n=20); declining to Laplace rather than paying k^(q+1) cost for a near-vanished gain",
      n_traits, .AGHQ_AUTO_N_TRAITS_CUTOFF
    )))
  }

  # k here is a starting suggestion only; the per-block ladder climb in
  # .aghq_resolve() is what actually resolves the node count used at fit time.
  list(
    use = TRUE,
    k = .AGHQ_K_FLOOR,
    reason = sprintf(
      "auto: n_traits = %d < cutoff %d and gate reports %d affordable quadrature block(s) (treewidth <= %d) -- Pinheiro & Chao (2006) measure a 2-15%% gain in this cluster-size range, worth the cost; turning AGHQ on",
      n_traits, .AGHQ_AUTO_N_TRAITS_CUTOFF, nrow(quad_rows), max(quad_rows$treewidth, na.rm = TRUE)
    )
  )
}
