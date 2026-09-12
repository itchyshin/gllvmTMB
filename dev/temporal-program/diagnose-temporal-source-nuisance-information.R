## Independent nuisance-adjusted information diagnostic for the retained
## replicated Gaussian temporal_dep() + kernel_indep() fixture.  It uses a
## direct Gaussian covariance and never calls production simulation or fitting.

.tsni_truth <- function() {
  L <- rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48))
  list(beta = c(.2, -.3, .1), temporal = tcrossprod(L),
    residual_variance = .30^2, phi = .6, kernel_variance = c(.35, .28, .40)^2)
}

.tsni_kernel <- function(n_series) {
  id <- seq_len(n_series)
  coords <- cbind(id / n_series, sin(id * .7))
  raw <- exp(-as.matrix(stats::dist(coords)) / .16) + diag(.08, n_series)
  raw / sqrt(outer(diag(raw), diag(raw)))
}

.tsni_names <- function() c(paste0("beta_", 1:3), "residual_variance",
  "temporal_11", "temporal_22", "temporal_33", "temporal_21", "temporal_31",
  "temporal_32", "phi", paste0("kernel_variance_", 1:3))

.tsni_truth_parameter <- function() {
  x <- .tsni_truth()
  c(x$beta, x$residual_variance, x$temporal[cbind(c(1, 2, 3, 2, 3, 3), c(1, 2, 3, 1, 1, 2))],
    x$phi, x$kernel_variance) |> stats::setNames(.tsni_names())
}

.tsni_unpack <- function(par) {
  stopifnot(identical(names(par), .tsni_names()))
  S <- matrix(0, 3, 3)
  S[cbind(c(1, 2, 3, 2, 3, 3), c(1, 2, 3, 1, 1, 2))] <- par[5:10]
  S[upper.tri(S)] <- t(S)[upper.tri(S)]
  list(beta = par[1:3], residual_variance = par[[4]], temporal = S,
    phi = par[[11]], kernel_variance = par[12:14])
}

.tsni_validate <- function(par) {
  x <- .tsni_unpack(par)
  if (any(!is.finite(par)) || x$residual_variance <= 0 || any(x$kernel_variance <= 0) ||
      abs(x$phi) >= .999 || inherits(try(chol(x$temporal), silent = TRUE), "try-error")) {
    stop("natural parameter is outside the declared interior diagnostic domain", call. = FALSE)
  }
  invisible(x)
}

.tsni_index <- function(n_series, n_time, replicate = 2L) {
  d <- expand.grid(series = seq_len(n_series), time = seq_len(n_time), trait = seq_len(3L),
    replicate = seq_len(replicate), KEEP.OUT.ATTRS = FALSE)
  list(d = d, X = stats::model.matrix(~ 0 + factor(trait), d))
}

.tsni_covariance <- function(par, n_series, n_time, K = .tsni_kernel(n_series)) {
  x <- .tsni_validate(par)
  ix <- .tsni_index(n_series, n_time)$d
  same <- outer(ix$series, ix$series, "==")
  lag <- abs(outer(ix$time, ix$time, "-"))
  trait_pair <- outer(ix$trait, ix$trait, function(a, b) 3L * (b - 1L) + a)
  temporal <- same * x$phi^lag * x$temporal[trait_pair]
  kernel <- K[ix$series, ix$series] * (outer(ix$trait, ix$trait, "==")) *
    matrix(x$kernel_variance[ix$trait], nrow(ix), nrow(ix))
  V <- temporal + kernel
  diag(V) <- diag(V) + x$residual_variance
  V
}

.tsni_derivatives <- function(par, n_series, n_time, K = .tsni_kernel(n_series)) {
  x <- .tsni_validate(par); ix <- .tsni_index(n_series, n_time)$d
  N <- nrow(ix); same <- outer(ix$series, ix$series, "=="); lag <- abs(outer(ix$time, ix$time, "-"))
  trait_i <- ix$trait; trait_pair <- outer(trait_i, trait_i, function(a, b) 3L * (b - 1L) + a); base <- same * x$phi^lag
  out <- vector("list", length(par)); names(out) <- names(par)
  out[1:3] <- replicate(3L, matrix(0, N, N), simplify = FALSE)
  out[[4L]] <- diag(N)
  positions <- list(c(1, 1), c(2, 2), c(3, 3), c(2, 1), c(3, 1), c(3, 2))
  for (j in seq_along(positions)) {
    P <- matrix(0, 3, 3); P[positions[[j]][1], positions[[j]][2]] <- 1
    P[positions[[j]][2], positions[[j]][1]] <- 1
    out[[4L + j]] <- base * P[trait_pair]
  }
  dphi <- matrix(0, N, N); positive <- lag > 0
  dphi[positive] <- same[positive] * lag[positive] * x$phi^(lag[positive] - 1L) *
    x$temporal[trait_pair][positive]
  out[[11L]] <- dphi
  for (j in 1:3) out[[11L + j]] <- K[ix$series, ix$series] *
    outer(trait_i, trait_i, function(a, b) a == j & b == j)
  out
}

.tsni_nll <- function(par, y, n_series, n_time, K = .tsni_kernel(n_series)) {
  V <- .tsni_covariance(par, n_series, n_time, K); L <- chol(V)
  r <- y - .tsni_index(n_series, n_time)$X %*% .tsni_unpack(par)$beta
  .5 * (length(y) * log(2 * pi) + 2 * sum(log(diag(L))) + sum(backsolve(L, r, transpose = TRUE)^2))
}

.tsni_score <- function(par, y, n_series, n_time, K = .tsni_kernel(n_series)) {
  V <- .tsni_covariance(par, n_series, n_time, K); W <- solve(V); ix <- .tsni_index(n_series, n_time)
  r <- y - ix$X %*% .tsni_unpack(par)$beta; Wr <- drop(W %*% r); dV <- .tsni_derivatives(par, n_series, n_time, K)
  ans <- numeric(length(par)); ans[1:3] <- -drop(crossprod(ix$X, Wr))
  for (j in 4:length(par)) ans[[j]] <- .5 * sum(W * t(dV[[j]])) - .5 * sum(Wr * (dV[[j]] %*% Wr))
  stats::setNames(ans, names(par))
}

.tsni_central_gradient <- function(par, y, n_series, n_time, step = 1e-5) {
  ans <- numeric(length(par))
  for (j in seq_along(par)) { h <- step * max(1, abs(par[[j]])); plus <- minus <- par; plus[[j]] <- plus[[j]] + h; minus[[j]] <- minus[[j]] - h
    ans[[j]] <- (.tsni_nll(plus, y, n_series, n_time) - .tsni_nll(minus, y, n_series, n_time)) / (2 * h) }
  stats::setNames(ans, names(par))
}

.tsni_observed_information <- function(par, y, n_series, n_time, step = 1e-4) {
  H <- matrix(NA_real_, length(par), length(par), dimnames = list(names(par), names(par)))
  for (j in seq_along(par)) { h <- step * max(1, abs(par[[j]])); plus <- minus <- par; plus[[j]] <- plus[[j]] + h; minus[[j]] <- minus[[j]] - h
    H[, j] <- (.tsni_score(plus, y, n_series, n_time) - .tsni_score(minus, y, n_series, n_time)) / (2 * h) }
  (H + t(H)) / 2
}

.tsni_central_hessian <- function(par, y, n_series, n_time, step = 1e-4) {
  H <- matrix(NA_real_, length(par), length(par), dimnames = list(names(par), names(par)))
  for (j in seq_along(par)) { h <- step * max(1, abs(par[[j]])); plus <- minus <- par; plus[[j]] <- plus[[j]] + h; minus[[j]] <- minus[[j]] - h
    H[, j] <- (.tsni_central_gradient(plus, y, n_series, n_time) - .tsni_central_gradient(minus, y, n_series, n_time)) / (2 * h) }
  (H + t(H)) / 2
}

.tsni_small_fixture <- function() {
  par <- .tsni_truth_parameter(); n_series <- 4L; n_time <- 3L; set.seed(2609231L)
  V <- .tsni_covariance(par, n_series, n_time); X <- .tsni_index(n_series, n_time)$X
  list(par = par, n_series = n_series, n_time = n_time,
    y = drop(X %*% .tsni_unpack(par)$beta + t(chol(V)) %*% stats::rnorm(nrow(V))))
}

.tsni_block_information <- function(n_time, n_series = 80L, par = .tsni_truth_parameter()) {
  x <- .tsni_validate(par); K <- .tsni_kernel(n_series); E <- eigen(K, symmetric = TRUE)
  time <- rep(seq_len(n_time), times = 3L); trait <- rep(seq_len(3L), each = n_time); p <- length(time)
  pair <- outer(trait, trait, function(a, b) 3L * (b - 1L) + a)
  R <- x$phi^abs(outer(time, time, "-")) * x$temporal[pair]
  S <- outer(trait, trait, "==") * matrix(x$kernel_variance[trait], p, p)
  dT <- vector("list", 14L); dT[1:3] <- replicate(3L, matrix(0, p, p), simplify = FALSE); dT[[4]] <- diag(p)
  pos <- list(c(1,1),c(2,2),c(3,3),c(2,1),c(3,1),c(3,2))
  for (j in seq_along(pos)) { A <- matrix(0,3,3); A[pos[[j]][1],pos[[j]][2]] <- A[pos[[j]][2],pos[[j]][1]] <- 1; dT[[4+j]] <- 2*x$phi^abs(outer(time,time,"-"))*A[pair] }
  lag <- abs(outer(time,time,"-")); dT[[11]] <- ifelse(lag == 0, 0, 2*lag*x$phi^(pmax(lag-1,0))*x$temporal[pair])
  for(j in 1:3) dT[[11+j]] <- 2*outer(trait,trait,"==")*(trait[row(diag(p))]==j)
  I <- matrix(0,14,14,dimnames=list(names(par),names(par)))
  ones <- rep(1, n_series)
  for (b in seq_len(n_series)) { V <- 2*R + 2*E$values[[b]]*S + x$residual_variance*diag(p); W <- solve(V)
    D <- dT; for(j in 12:14) D[[j]] <- E$values[[b]]*D[[j]]
    z <- sqrt(2)*sum(E$vectors[,b])*rep(rep(1,n_time),times=3)
    Xb <- cbind(z*(trait==1), z*(trait==2), z*(trait==3))
    I[1:3,1:3] <- I[1:3,1:3] + crossprod(Xb,W%*%Xb)
    WD <- lapply(D[4:14], function(d) W %*% d)
    for(i in seq_along(WD)) for(j in seq_along(WD)) {
      I[i + 3L, j + 3L] <- I[i + 3L, j + 3L] + .5 * sum(t(WD[[i]]) * WD[[j]])
    }
  }
  I[[4,4]] <- I[[4,4]] + n_series*p/(2*x$residual_variance^2)
  I
}

.tsni_schur <- function(I) { k <- 12:14; n <- setdiff(seq_len(nrow(I)), k); Inn <- I[n,n,drop=FALSE]; if(inherits(try(chol(Inn),silent=TRUE),"try-error")) stop("nuisance block is not positive definite",call.=FALSE); I[k,k,drop=FALSE]-I[k,n,drop=FALSE]%*%solve(Inn,I[n,k,drop=FALSE]) }

.tsni_decomposition <- function(n_time = 16L) {
  x <- .tsni_truth(); q <- qr.Q(qr(cbind(rep(1/sqrt(n_time), n_time), diag(n_time)[, -1, drop = FALSE])))
  Z <- kronecker(diag(3), q); time <- rep(seq_len(n_time), times = 3L); trait <- rep(seq_len(3L), each = n_time)
  pair <- outer(trait, trait, function(a, b) 3L * (b - 1L) + a)
  temporal <- x$phi^abs(outer(time, time, "-")) * x$temporal[pair]
  source <- outer(trait, trait, "==") * matrix(x$kernel_variance[trait], length(time), length(time))
  V <- temporal + source + diag(x$residual_variance, length(time)); transformed <- t(Z) %*% V %*% Z
  source_transformed <- t(Z) %*% source %*% Z; temporal_transformed <- t(Z) %*% temporal %*% Z
  mean_index <- c(1L, n_time + 1L, 2L * n_time + 1L); contrast_index <- setdiff(seq_len(nrow(V)), mean_index)
  list(max_reconstruction_error = max(abs(Z %*% transformed %*% t(Z) - V)),
    max_contrast_source = max(abs(source_transformed[contrast_index, ])),
    temporal_mean_contrast_max = max(abs(temporal_transformed[mean_index, contrast_index])),
    source_mean = diag(source_transformed)[mean_index])
}

.tsni_oracle <- function() { f <- .tsni_small_fixture(); g <- .tsni_score(f$par,f$y,f$n_series,f$n_time); ng <- .tsni_central_gradient(f$par,f$y,f$n_series,f$n_time); H <- .tsni_observed_information(f$par,f$y,f$n_series,f$n_time); nH <- .tsni_central_hessian(f$par,f$y,f$n_series,f$n_time); list(max_score_error=max(abs(g-ng)), max_hessian_error=max(abs(H-nH)), information=H) }
.tsni_design <- function() { out <- lapply(c(16L,32L,64L),function(T){S <- .tsni_schur(.tsni_block_information(T)); c(n_time=T,diag(S))}); do.call(rbind,out) }

if (sys.nframe()==0L) { a <- commandArgs(trailingOnly=TRUE); if(length(a)!=1L||!a%in%c("--self-test","--oracle","--decomposition","--design")) stop("usage: diagnose-temporal-source-nuisance-information.R {--self-test|--oracle|--decomposition|--design}",call.=FALSE)
  if(a=="--self-test") { stopifnot(identical(names(.tsni_truth_parameter()),.tsni_names())); cat("TEMPORAL_SOURCE_NUISANCE_INFORMATION_SELF_TEST_PASS\n") }
  if(a=="--oracle") {z<-.tsni_oracle(); if(z$max_score_error>2e-5||z$max_hessian_error>2e-3) stop("natural-scale derivative oracle failed",call.=FALSE); print(z[1:2]);cat("TEMPORAL_SOURCE_NUISANCE_INFORMATION_ORACLE_PASS\n")}
  if(a=="--decomposition") {z<-.tsni_decomposition();if(z$max_reconstruction_error>1e-12||z$max_contrast_source>1e-12)stop("mean/contrast decomposition failed",call.=FALSE);print(z);cat("TEMPORAL_SOURCE_NUISANCE_INFORMATION_DECOMPOSITION_PASS\n")}
  if(a=="--design") {z<-.tsni_design();if(any(!is.finite(z))||any(z[,-1]<=0))stop("expected information is not positive",call.=FALSE);print(z);cat("TEMPORAL_SOURCE_NUISANCE_INFORMATION_DESIGN_PASS\n")}
}
