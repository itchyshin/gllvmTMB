## Can gllvmTMB fit a presence-only IPP via the Berman-Turner quadrature device?
## (Warton & Shepherd 2010; Renner et al. 2015): weighted Poisson with
## y = presence/w at points, y = 0 at quadrature nodes, weights = w.
suppressMessages(devtools::load_all(".", quiet = TRUE))

sim_one <- function(seed) {
  set.seed(seed)
  ## Environment on a fine lattice
  ns <- 60; gx <- seq(0, 1, length.out = ns)
  G <- expand.grid(x = gx, y = gx)
  G$env <- as.numeric(scale(sin(3*G$x) + cos(2.5*G$y) + 0.6*G$x*G$y))
  sp <- c("A","B"); a0 <- c(5.2, 4.8); b1 <- c(1.10, -0.70)   # TRUTH

  cellarea <- (1/ (ns-1))^2
  rows <- list()
  for (j in seq_along(sp)) {
    lam <- exp(a0[j] + b1[j] * G$env)          # intensity per unit area
    npt <- rpois(nrow(G), lam * cellarea)      # thin to a point pattern
    idx <- rep(seq_len(nrow(G)), npt)
    ## presence rows: weight tiny, y = 1/w
    w_p <- rep(1e-6, length(idx))
    ## quadrature rows: the lattice itself, weight = cell area, y = 0
    rows[[j]] <- rbind(
      data.frame(trait=sp[j], env=G$env[idx], y=1/w_p, w=w_p),
      data.frame(trait=sp[j], env=G$env,      y=0,     w=cellarea))
  }
  d <- do.call(rbind, rows)
  d$trait <- factor(d$trait, levels = sp)
  d$cell_id <- factor(seq_len(nrow(d)))        # one obs per row
  f <- try(gllvmTMB(y ~ 0 + trait + trait:env, data = d, trait = "trait",
                    unit = "cell_id", family = poisson(), weights = d$w,
                    silent = TRUE), silent = TRUE)
  if (inherits(f, "try-error")) return(NULL)
  b <- f$opt$par[names(f$opt$par) == "b_fix"]
  est <- unname(b[grep(":env$", f$X_fix_names)])
  list(conv = f$opt$convergence, est = est, truth = b1,
       npt = sum(d$y > 0))
}
res <- lapply(1:5, sim_one)
res <- Filter(Negate(is.null), res)
cat("fits:", length(res), " conv==0:", sum(sapply(res,`[[`,"conv")==0), "\n")
E <- do.call(rbind, lapply(res, `[[`, "est"))
cat("true slopes :", res[[1]]$truth, "\n")
cat("mean est    :", round(colMeans(E),4), "\n")
cat("sd  est     :", round(apply(E,2,sd),4), "\n")
cat("mean |err|  :", round(colMeans(abs(sweep(E,2,res[[1]]$truth))),4), "\n")
