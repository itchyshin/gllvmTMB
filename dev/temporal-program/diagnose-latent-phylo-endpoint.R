## Retained endpoint diagnostic for temporal_latent() + phylo_indep().
##
## This script deliberately repeats the fixed DGP rather than calling the
## package simulator.  It is not a recovery rerun: it interrogates only the
## retained phi = .6, seed = 2609243 endpoint described in the companion
## contract.
root <- normalizePath(".", mustWork = TRUE)
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)

args <- commandArgs(trailingOnly = TRUE)
coordinate_arg <- sub("^--coordinate=", "", args[grepl("^--coordinate=", args)])
if (length(coordinate_arg) != 1L || is.na(suppressWarnings(as.integer(coordinate_arg))))
  stop("supply exactly one --coordinate=N outer-coordinate index", call. = FALSE)
coordinate <- as.integer(coordinate_arg)
output <- file.path(root, "dev", "temporal-program", "results", "diagnostics",
  sprintf("latent-phylo-endpoint-20260912-coordinate-%02d.rds", coordinate))
if (file.exists(output)) stop("output must name a new result file", call. = FALSE)

truth <- list(
  beta = c(.2, -.3, .1), temporal_loading = c(.55, .40, -.35),
  phylo_sd = c(.35, .28, .40), residual = .30
)
n_series <- 80L; n_time <- 16L; n_measurement <- 2L
series <- paste0("s", seq_len(n_series)); traits <- paste0("t", 1:3)
set.seed(2609240L)
phylo_tree <- ape::rcoal(n_series)
phylo_tree$tip.label <- series
Cphy <- ape::vcv(phylo_tree, corr = TRUE)

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  static <- t(chol(Cphy)) %*% sweep(matrix(rnorm(n_series * 3L), n_series, 3L),
    2L, truth$phylo_sd, "*")
  state <- matrix(0, n_series, n_time)
  state[, 1L] <- rnorm(n_series)
  for (tt in 2:n_time) state[, tt] <- phi * state[, tt - 1L] +
    sqrt(1 - phi^2) * rnorm(n_series)
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + state[cbind(g, tt)] * truth$temporal_loading[j] +
    static[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = n_measurement), , drop = FALSE]
  data$measurement <- rep(paste0("m", seq_len(n_measurement)),
    times = nrow(data) / n_measurement)
  data$value <- data$mean_value + rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  data
}

labels <- function(x) paste0(names(x), "[", ave(seq_along(x), names(x), FUN = seq_along), "]")

## Independent marginal Gaussian likelihood.  It depends only on documented
## fit data and parameter packing; no production simulation or objective is
## called here.  The full dense covariance is evaluated with the determinant
## lemma/Woodbury identity, which is algebraically exact and avoids allocating
## a second 3,840 x 3,840 factor on a workstation already running TMB.
dense_nll <- function(fit, fixed) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  ## Two complete measurements occur at every state--trait cell.  The
  ## mean/difference transform has determinant one, so its joint density is
  ## exactly the original 7,680-row Gaussian density.  It lets the dense
  ## covariance operate on 3,840 means while retaining all measurement-noise
  ## constants through the independent differences.
  key <- paste(td$temporal_state_id, td$trait_id, sep = ":")
  groups <- split(seq_along(key), key)
  if (!all(lengths(groups) == 2L))
    stop("frozen endpoint no longer has exactly two measurements per state--trait", call. = FALSE)
  first <- vapply(groups, `[[`, integer(1), 1L)
  second <- vapply(groups, `[[`, integer(1), 2L)
  state <- td$temporal_state_id[first] + 1L
  trait <- td$trait_id[first] + 1L
  source <- td$species_aug_id[first] + 1L
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal_var <- tcrossprod(par$theta_temporal_rr)
  phylo_var <- diag(par$theta_rr_phy[seq_len(td$n_traits)]^2, td$n_traits)
  sigma2 <- exp(2 * par$log_sigma_eps[[1L]])
  fitted <- drop(td$X_fix %*% par$b_fix)
  residual <- (td$y[first] + td$y[second]) / 2 - (fitted[first] + fitted[second]) / 2
  contrast <- (td$y[first] - td$y[second]) - (fitted[first] - fitted[second])
  n_mean <- length(residual)
  n_state <- as.integer(td$n_temporal_states)
  n_trait <- as.integer(td$n_traits)
  ## g_phy is indexed by species_aug_id and has precision Ainv_phy_rr.  Its
  ## marginal covariance is therefore the inverse of that exact operator,
  ## rather than the user-facing tip-order display matrix.
  Cphy_fit <- as.matrix(solve(td$Ainv_phy_rr))
  n_source <- nrow(Cphy_fit)
  ## Form U' U and U' r directly.  This is the exact cross-product of the
  ## full low-rank design, but does not materialise U at every finite
  ## difference.  The lower factors satisfy K = L L'.
  ## Build the AR1 covariance from the exact predecessor and gap vectors sent
  ## to TMB, instead of assuming the public pair table has the engine order.
  Ktime <- matrix(0, n_state, n_state)
  predecessor <- as.integer(td$temporal_predecessor) + 1L
  for (s in seq_len(n_state)) {
    if (predecessor[[s]] <= 0L) {
      Ktime[s, s] <- 1
    } else {
      a <- phi ^ td$temporal_gap[[s]]
      Ktime[s, s] <- 1
      Ktime[s, seq_len(s - 1L)] <- a * Ktime[predecessor[[s]], seq_len(s - 1L)]
      Ktime[seq_len(s - 1L), s] <- Ktime[s, seq_len(s - 1L)]
    }
  }
  L_time <- t(chol(Ktime))
  L_phy <- as.matrix(Matrix::bdiag(lapply(seq_len(n_trait), function(j) {
    t(par$theta_rr_phy[[j]] * chol(Cphy_fit))
  })))
  phy_column <- (trait - 1L) * n_source + source
  btime_bphy <- matrix(0, n_state, n_trait * n_source)
  btime_bphy[cbind(state, phy_column)] <- par$theta_temporal_rr[trait]
  btime_r <- numeric(n_state)
  bphy_r <- numeric(n_trait * n_source)
  for (i in seq_len(n_mean)) {
    btime_r[[state[[i]]]] <- btime_r[[state[[i]]]] +
      par$theta_temporal_rr[[trait[[i]]]] * residual[[i]]
    bphy_r[[phy_column[[i]]]] <- bphy_r[[phy_column[[i]]]] + residual[[i]]
  }
  scale <- sigma2 / 2
  S_tt <- diag(n_state) + sum(par$theta_temporal_rr^2) * crossprod(L_time) / scale
  S_pp <- diag(n_trait * n_source) + n_time * crossprod(L_phy) / scale
  S_tp <- crossprod(L_time, btime_bphy %*% L_phy) / scale
  S <- rbind(cbind(S_tt, S_tp), cbind(t(S_tp), S_pp))
  L <- chol(S)
  Utr <- c(crossprod(L_time, btime_r), crossprod(L_phy, bphy_r))
  solved <- backsolve(L, forwardsolve(t(L), Utr))
  quadratic <- sum(residual^2) / scale - sum(Utr * solved) / scale^2
  .5 * (n_mean * log(2 * pi * sigma2 / 2) + 2 * sum(log(diag(L))) + quadratic) +
    .5 * (length(contrast) * log(2 * pi * 2 * sigma2) + sum(contrast^2) / (2 * sigma2))
}

d <- simulate_fixture(.6, 2609243L)
message("endpoint diagnostic: fitting frozen endpoint")
fit <- suppressWarnings(gllvmTMB(
  value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
      d = 1, unique = FALSE) +
    phylo_indep(0 + trait | series, vcv = Cphy),
  data = d, unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 3000, reltol = 1e-14)),
    optimizer_passes = 2L)
))
fixed <- fit$opt$par
message("endpoint diagnostic: rebuilding TMB objective")
stored <- utils::read.csv(file.path(root, "dev", "temporal-program", "results",
  "latent-phylo-recovery-20260911.csv"))
stored <- stored[stored$phi == .6 & stored$seed == 2609243L, , drop = FALSE]
stopifnot(nrow(stored) == 1L)

fresh <- TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
  map = fit$tmb_map, random = fit$random, DLL = "gllvmTMB", silent = TRUE)
native <- as.numeric(fit$tmb_obj$fn(fixed))
fresh_native <- as.numeric(fresh$fn(fixed))
native_gradient <- fit$tmb_obj$gr(fixed)
fresh_gradient <- fresh$gr(fixed)

message("endpoint diagnostic: evaluating independent Gaussian likelihood")
started <- proc.time()[["elapsed"]]
dense <- dense_nll(fit, fixed)
elapsed_dense_seconds <- proc.time()[["elapsed"]] - started
h <- 1e-5
## The all-coordinate central derivative compares the independent dense
## likelihood to TMB's outer score at the retained endpoint.
if (coordinate < 1L || coordinate > length(fixed))
  stop("requested coordinate is outside the fitted outer parameter vector", call. = FALSE)
message("endpoint diagnostic: central gradient for coordinate ", coordinate)
central <- {
  i <- coordinate
  plus <- fixed; minus <- fixed
  plus[[i]] <- plus[[i]] + h; minus[[i]] <- minus[[i]] - h
  (dense_nll(fit, plus) - dense_nll(fit, minus)) / (2 * h)
}

phylo_2 <- which(names(fixed) == "theta_rr_phy")[2L]
one_sided_steps <- c(1e-6, 1e-4, 1e-2)
one_sided <- if (coordinate == phylo_2) vapply(one_sided_steps, function(step) {
    moved <- fixed; moved[[phylo_2]] <- moved[[phylo_2]] + step
    dense_nll(fit, moved) - dense
  }, numeric(1)) else rep(NA_real_, length(one_sided_steps))
hessian <- tryCatch(fit$tmb_obj$he(fixed), error = identity)

result <- list(
  contract = "TEMPORAL-LATENT-PHYLO-ENDPOINT-DIAGNOSTIC-v1",
  endpoint = list(phi = .6, seed = 2609243L),
  stored = list(objective = stored$objective, max_gradient = stored$max_gradient),
  native = list(objective = native, max_gradient = max(abs(native_gradient))),
  fresh = list(objective = fresh_native, max_gradient = max(abs(fresh_gradient)),
    objective_error = fresh_native - native,
    gradient_error_max = max(abs(fresh_gradient - native_gradient))),
  dense = list(objective = dense, objective_error = dense - native,
    central_gradient_error_max = max(abs(central - native_gradient)),
    elapsed_seconds = elapsed_dense_seconds),
  coordinate = list(index = coordinate, label = labels(fixed)[[coordinate]],
    native_gradient = native_gradient[[coordinate]], dense_central = central,
    error = central - native_gradient[[coordinate]]),
  phylo_second_loading = list(value = fixed[[phylo_2]], steps = one_sided_steps,
    objective_change = one_sided),
  hessian = if (inherits(hessian, "error")) list(status = "error", message = conditionMessage(hessian))
    else list(status = "available", dimension = dim(hessian)),
  phylo_alignment = list(
    input_dimnames = dimnames(Cphy), fitted_dimnames = dimnames(fit$phylo_vcv),
    maximum_unlabelled_difference = max(abs(Cphy - as.matrix(fit$phylo_vcv))),
    maximum_labelled_difference = max(abs(Cphy[rownames(fit$phylo_vcv),
      colnames(fit$phylo_vcv)] - as.matrix(fit$phylo_vcv)))
  ),
  phylo_engine = fit$tmb_data[c("n_aug_phy", "structured_rho_field_active",
    "structured_rho_sparse", "structured_rho_dense_estimated", "species_aug_id")],
  session = utils::sessionInfo()
)
saveRDS(result, output)
cat("TEMPORAL_LATENT_PHYLO_ENDPOINT_DIAGNOSTIC_PASS\n")
