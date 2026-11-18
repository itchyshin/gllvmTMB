suppressMessages(devtools::load_all(".", quiet = TRUE))
envf <- function(x,y) sin(3*x) + cos(2.5*y) + 0.6*x*y
## fixed point pattern per seed (simulated on a fine lattice), quadrature varied
sim <- function(seed, nq) {
  set.seed(seed)
  ns <- 120; gx <- seq(0,1,length.out=ns); G <- expand.grid(x=gx,y=gx)
  raw <- envf(G$x,G$y); mu <- mean(raw); sdv <- sd(raw); G$env <- (raw-mu)/sdv
  sp <- c("A","B"); a0 <- c(5.2,4.8); b1 <- c(1.10,-0.70); ca <- (1/(ns-1))^2
  qx <- seq(0,1,length.out=nq); Q <- expand.grid(x=qx,y=qx)
  Q$env <- (envf(Q$x,Q$y)-mu)/sdv; qw <- 1/nq^2
  rows <- list()
  for (j in seq_along(sp)) {
    npt <- rpois(nrow(G), exp(a0[j]+b1[j]*G$env)*ca)
    idx <- rep(seq_len(nrow(G)), npt); wp <- rep(1e-6,length(idx))
    rows[[j]] <- rbind(data.frame(trait=sp[j],env=G$env[idx],y=1/wp,w=wp),
                       data.frame(trait=sp[j],env=Q$env,y=0,w=qw))
  }
  d <- do.call(rbind,rows); d$trait <- factor(d$trait,levels=sp)
  d$cell_id <- factor(seq_len(nrow(d)))
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(y ~ 0+trait+trait:env,
      data=d, trait="trait", unit="cell_id", family=poisson(),
      weights=d$w, silent=TRUE))), silent=TRUE)
  if (inherits(f,"try-error") || f$opt$convergence!=0) return(rep(NA_real_,2))
  b <- f$opt$par[names(f$opt$par)=="b_fix"]
  unname(b[grep(":env$", f$X_fix_names)])
}
truth <- c(1.10,-0.70)
for (nq in c(30,60,100)) {
  E <- t(sapply(1:5, sim, nq=nq))
  cat(sprintf("quad %3dx%3d (%5d nodes): est %6.3f %6.3f | bias %+.3f %+.3f\n",
      nq,nq,nq^2, mean(E[,1]), mean(E[,2]),
      mean(E[,1])-truth[1], mean(E[,2])-truth[2]))
}
