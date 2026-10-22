# Fixed-point likelihood checks: TMB integrates Gaussian scores, but no outer
# optimizer is entered. These do not constitute parameter-recovery evidence.
.rho_capture_payload <- function(formula, data, family = gaussian(), unit="obs", unit_obs=NULL) {
  payload <- NULL
  testthat::local_mocked_bindings(MakeADFun = function(data, parameters, map, random, ...) {
    payload <<- list(data = data, parameters = parameters, map = map, random = random)
    stop("structured-rho-payload-captured", call. = FALSE)
  }, .package = "TMB")
  testthat::local_mocked_bindings(.gllvmTMB_run_nlminb = function(...) {
    stop("Outer optimizer forbidden in fixed-point oracle")
  }, .package = "gllvmTMB")
  err <- tryCatch(suppressMessages(gllvmTMB(formula, data = data, trait = "trait",
    unit = unit, unit_obs=unit_obs, cluster = "group", family = family,
    control = gllvmTMBcontrol(se = FALSE))), error = identity)
  if (!inherits(err, "error")) stop("Payload capture unexpectedly returned without the capture sentinel")
  if (!grepl("structured-rho-payload-captured", conditionMessage(err))) stop(err)
  payload
}

.rho_fixed_fixture <- function(n_traits = 3L) {
  labels <- c("ancestor", "g1", "g2", "g3", "g4")
  K <- outer(seq_len(5), seq_len(5), function(i,j) .45^abs(i-j)) *
    outer(sqrt(c(2,3,4,2.5,1.5)), sqrt(c(2,3,4,2.5,1.5)))
  dimnames(K) <- list(labels, labels)
  groups <- c("g4","g1","g3","g2")
  dat <- expand.grid(trait = paste0("t", seq_len(n_traits)), rep = 1:2, group = groups)
  dat$group <- factor(dat$group, levels = groups)
  dat$obs <- interaction(dat$group, dat$rep, drop = TRUE)
  dat$y <- sin(seq_len(nrow(dat))) + .1*cos(seq_len(nrow(dat))/3)
  list(K = K, Q = Matrix::Matrix(solve(K), sparse = TRUE), data = dat)
}

.rho_independent_gaussian_nll <- function(par, obj, payload, K, rho) {
  p <- obj$env$parList(par)
  nt <- payload$data$n_traits
  if (payload$data$use_propto == 1L) {
    S <- diag(exp(p$loglambda_phy), nt)
  } else {
    rank <- payload$data$d_phy
    L <- matrix(0, nt, rank)
    diag(L) <- p$theta_rr_phy[seq_len(rank)]
    L[lower.tri(L)] <- p$theta_rr_phy[-seq_len(rank)]
    S <- tcrossprod(L)
  }
  if (payload$data$use_phylo_diag == 1L) S <- S + diag(exp(2*p$log_sd_phy_diag), nt)
  Kr <- rho * K
  diag(Kr) <- diag(K)
  gi <- payload$data$species_id + 1L
  ti <- payload$data$trait_id + 1L
  V <- Kr[gi,gi] * S[ti,ti]
  diag(V) <- diag(V) + exp(2*p$log_sigma_eps)
  residual <- as.numeric(payload$data$y - payload$data$X_fix %*% p$b_fix)
  .5 * (length(residual)*log(2*pi) + as.numeric(determinant(V, logarithm=TRUE)$modulus) +
          drop(crossprod(residual, solve(V, residual))))
}

# Assemble a public result at one declared parameter point. This replaces the
# outer optimizer with one objective evaluation; it is not a fitted estimator
# and must never enter recovery summaries or count as an optimization attempt.
.rho_at_point <- function(formula, data, unit="obs", unit_obs=NULL) {
  testthat::local_mocked_bindings(.gllvmTMB_run_nlminb=function(args) {
    par <- args$start
    par[names(par)=="theta_rr_phy"] <- seq(.4,.8,length.out=sum(names(par)=="theta_rr_phy"))
    par[names(par)=="log_sd_phy_diag"] <- log(.4)
    par[names(par)=="log_sigma_eps"] <- log(.7)
    par[names(par)=="eta_structured_rho"] <- qlogis(.35)
    par[names(par)=="theta_rr_spde_lv"] <- seq(.4,.8,length.out=sum(names(par)=="theta_rr_spde_lv"))
    par[names(par)=="log_tau_spde"] <- -log(seq(.3,.7,length.out=sum(names(par)=="log_tau_spde")))
    list(par=par,objective=args$objective(par),convergence=0L,iterations=0L,
      evaluations=setNames(c(1L,0L),c("function","gradient")),message="Test fixture: one evaluation, no optimization")
  }, .package="gllvmTMB")
  ctl <- gllvmTMBcontrol(se=FALSE)
  ctl$.internal_continuation <- FALSE
  suppressMessages(gllvmTMB(formula,data=data,trait="trait",unit=unit,unit_obs=unit_obs,cluster="group",
    family=gaussian(),control=ctl))
}
