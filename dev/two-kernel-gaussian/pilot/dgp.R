# Source-safe Gaussian DGP; no draws occur until pilot_generate() is called.
pilot_design <- function(setting, n = 64L) {
  stopifnot(setting %in% c('baseline', 'weak', 'boundary'), n >= 2L)
  traits <- c('H1', 'H2', 'P1', 'P2')
  species <- c(sprintf('H%03d', seq_len(n)), sprintf('P%03d', seq_len(n)))
  a <- if (setting == 'weak') 0.1 else 0.6
  A <- outer(seq_len(n), seq_len(n), function(i, j) a^abs(i-j))
  I <- diag(n); rho <- 0.55
  K <- list(phy = rbind(cbind(A, rho*A), cbind(rho*A, A)),
            tip = rbind(cbind(I, rho*I), cbind(rho*I, I)))
  K <- lapply(K, function(x) { dimnames(x) <- list(species, species); x })
  lambda <- list(phy = c(.9, .8, .85, .75), tip = c(.7, .9, .8, .65))
  psi <- list(phy = c(.35, .45, .40, .30), tip = c(.40, .30, .35, .45))
  if (setting == 'boundary') psi <- lapply(psi, function(x) rep(.01, length(x)))
  Sigma <- lapply(names(K), function(s) tcrossprod(lambda[[s]]) + diag(psi[[s]]))
  names(Sigma) <- names(K)
  Sigma <- lapply(Sigma, function(x) { dimnames(x) <- list(traits, traits); x })
  mask <- outer(seq_len(2L*n), seq_along(traits), function(i,t) (i <= n) == (t <= 2L))
  dimnames(mask) <- list(species, traits)
  list(setting=setting,n=n,traits=traits,species=species,K=K,lambda=lambda,
       psi=psi,Sigma=Sigma,mask=mask,beta=setNames(c(.1,-.1,0,0),traits),
       sigma=sqrt(.04/3),ridge=1e-8)
}

pilot_covariance <- function(d) {
  obs <- which(d$mask, arr.ind=TRUE)
  V <- matrix(0,nrow(obs),nrow(obs))
  for (s in names(d$K)) {
    K <- d$K[[s]]; diag(K) <- diag(K)+d$ridge
    V <- V + K[obs[,1],obs[,1]] * d$Sigma[[s]][obs[,2],obs[,2]]
  }
  diag(V) <- diag(V)+d$sigma^2
  V
}

pilot_verify_design <- function(d) {
  obs <- which(d$mask, arr.ind=TRUE)
  # Kronecker implementation has different indexing from pilot_covariance.
  Vfull <- matrix(0, length(d$mask), length(d$mask))
  for (s in names(d$K)) {
    K <- d$K[[s]]; diag(K) <- diag(K)+d$ridge
    Vfull <- Vfull + kronecker(d$Sigma[[s]],K)
  }
  ids <- obs[,1] + (obs[,2]-1L)*nrow(d$mask)
  V <- Vfull[ids,ids,drop=FALSE] + diag(d$sigma^2,length(ids))
  stopifnot(sum(d$mask)==4L*d$n, sum(!d$mask)==4L*d$n,
            max(abs(V-pilot_covariance(d))) < 1e-10)
  ranks <- vapply(seq_along(d$traits), function(t) {
    ids <- which(d$mask[,t]); b <- sapply(d$K,function(K) as.vector(K[ids,ids]))
    qr(sweep(b,2L,sqrt(colSums(b^2)),'/'),tol=1e-8)$rank
  }, integer(1))
  stopifnot(all(ranks==2L), min(eigen(V,symmetric=TRUE,only.values=TRUE)$values)>0)
  # Compare complete wrong covariances, not merely nonzero components.
  for (s in names(d$K)) {
    K <- d$K[[s]]; diag(K) <- diag(K)+d$ridge
    omitted <- V - kronecker(diag(d$psi[[s]]),K)[ids,ids,drop=FALSE]
    ridge_omitted <- V - kronecker(d$Sigma[[s]],diag(d$ridge,nrow(K)))[ids,ids,drop=FALSE]
    kernel_changed <- V + kronecker(d$Sigma[[s]],diag(0.01,nrow(K)))[ids,ids,drop=FALSE]
    stopifnot(max(abs(V-omitted))>1e-8,
              max(abs(V-ridge_omitted))>1e-12,
              max(abs(V-kernel_changed))>1e-8)
  }
  omitted_error <- V - diag(d$sigma^2,nrow(V))
  doubled_error <- V + diag(d$sigma^2,nrow(V))
  stopifnot(max(abs(V-omitted_error))>1e-8,
            max(abs(V-doubled_error))>1e-8)
  invisible(list(rank=ranks,observed=sum(d$mask),missing=sum(!d$mask)))
}

pilot_generate <- function(d, seed) {
  set.seed(seed)
  eta <- matrix(0,length(d$species),length(d$traits))
  for (s in names(d$K)) {
    K <- d$K[[s]]; diag(K) <- diag(K)+d$ridge
    L <- t(chol(K)); g <- as.vector(L %*% rnorm(nrow(K)))
    u <- L %*% matrix(rnorm(nrow(K)*length(d$traits)),nrow(K))
    eta <- eta + tcrossprod(g,d$lambda[[s]]) + sweep(u,2L,sqrt(d$psi[[s]]),'*')
  }
  y <- sweep(eta,2L,d$beta,'+')
  # Generate record errors separately rather than treating the latent field as redrawn.
  e <- array(rnorm(length(y)*3L,sd=.2),dim=c(dim(y),3L))
  y <- y + apply(e,c(1L,2L),mean); y[!d$mask] <- NA_real_
  data.frame(row_id=factor(d$species,levels=d$species),
             species=factor(d$species,levels=d$species),
             setNames(as.data.frame(y),d$traits),check.names=FALSE)
}
