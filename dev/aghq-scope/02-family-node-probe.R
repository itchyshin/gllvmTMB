## READ-ONLY: (a) is the conditional (random-block) Hessian block-diagonal by
## unit? (b) does obj$env$f(theta, order=0) survive far AGHQ nodes for the
## awkward families (ordinal clamp, tweedie, hurdle, truncated, betabinomial)?
suppressPackageStartupMessages(library(gllvmTMB))
ctl <- gllvmTMBcontrol(se = FALSE)

## ---------- (a) sparsity of spHess(random = TRUE) ----------
set.seed(9); n_sites <- 20L; n_tr <- 4L
Y <- matrix(rnorm(n_sites*n_tr), n_sites, n_tr); colnames(Y) <- paste0("t",1:n_tr)
w <- data.frame(site = factor(seq_len(n_sites)), Y, check.names = FALSE)
f_def <- suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4) ~ 1 + latent(1 | site, d = 2),
  data = w, unit = "site", family = gaussian(), control = ctl)))
o <- f_def$tmb_obj
H <- o$env$spHess(o$env$last.par.best, random = TRUE)
cat("== default latent(d=2): spHess(random=TRUE) ==\n")
cat("  dim:", paste(dim(H), collapse="x"), " nnz:", length(H@x),
    " nnz/row:", round(length(H@x)/nrow(H), 2), "\n")
gr <- igraph_like <- NULL
## connected components of the sparsity graph = conditional-independence blocks
Hs <- as(H, "TsparseMatrix")
comp <- seq_len(nrow(H))
repeat { old <- comp
  for (e in seq_along(Hs@i)) { a <- Hs@i[e]+1L; b <- Hs@j[e]+1L
    m <- min(comp[a], comp[b]); comp[a] <- m; comp[b] <- m }
  for (e in rev(seq_along(Hs@i))) { a <- Hs@i[e]+1L; b <- Hs@j[e]+1L
    m <- min(comp[a], comp[b]); comp[a] <- m; comp[b] <- m }
  if (identical(old, comp)) break }
tb <- table(comp)
cat("  conditional-independence blocks:", length(tb),
    " | block sizes:", paste(sort(unique(as.integer(tb))), collapse=","), "\n")

## phylo comparison
suppressPackageStartupMessages(library(ape)); set.seed(4)
n_sp <- 20L; tree <- ape::rcoal(n_sp, tip.label = paste0("sp", seq_len(n_sp)))
Yp <- matrix(rnorm(n_sp*3), n_sp, 3); colnames(Yp) <- paste0("t",1:3)
wp <- data.frame(species = factor(tree$tip.label, levels = tree$tip.label), Yp, check.names = FALSE)
f_ph <- suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3) ~ 1 + phylo_latent(1 | species, d = 1),
  data = wp, unit = "species", cluster = "species", phylo_tree = tree,
  family = gaussian(), control = ctl)))
op <- f_ph$tmb_obj
Hp <- op$env$spHess(op$env$last.par.best, random = TRUE)
Hps <- as(Hp, "TsparseMatrix")
compp <- seq_len(nrow(Hp))
repeat { old <- compp
  for (e in seq_along(Hps@i)) { a <- Hps@i[e]+1L; b <- Hps@j[e]+1L
    m <- min(compp[a], compp[b]); compp[a] <- m; compp[b] <- m }
  for (e in rev(seq_along(Hps@i))) { a <- Hps@i[e]+1L; b <- Hps@j[e]+1L
    m <- min(compp[a], compp[b]); compp[a] <- m; compp[b] <- m }
  if (identical(old, compp)) break }
cat("\n== phylo_latent(d=1), 20 tips: spHess(random=TRUE) ==\n")
cat("  dim:", paste(dim(Hp), collapse="x"), " nnz:", length(Hp@x), "\n")
cat("  conditional-independence blocks:", length(table(compp)),
    " | block sizes:", paste(sort(unique(as.integer(table(compp)))), collapse=","), "\n")

## ---------- (b) far-node integrand behaviour, by family ----------
cat("\n== obj$env$f(theta, order=0) at shifted random values ==\n")
mk <- function(fam, gen) {
  set.seed(21); ns <- 25L; nt <- 3L
  Y <- gen(ns, nt); colnames(Y) <- paste0("t",1:nt)
  d <- data.frame(site = factor(seq_len(ns)), Y, check.names = FALSE)
  fit <- try(suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1,t2,t3) ~ 1 + latent(1 | site, d = 1, unique = FALSE),
    data = d, unit = "site", family = fam, control = ctl))), silent = TRUE)
  fit
}
gens <- list(
  ordinal_probit = list(f = ordinal_probit(), g = function(ns,nt) matrix(sample(1:4, ns*nt, TRUE), ns, nt)),
  tweedie        = list(f = tweedie(),        g = function(ns,nt) matrix(ifelse(runif(ns*nt)<0.4,0,rgamma(ns*nt,2,1)), ns, nt)),
  delta_gamma    = list(f = delta_gamma(),    g = function(ns,nt) matrix(ifelse(runif(ns*nt)<0.4,0,rgamma(ns*nt,2,1)), ns, nt)),
  truncated_poisson = list(f = truncated_poisson(), g = function(ns,nt) matrix(rpois(ns*nt,3)+1L, ns, nt)),
  poisson        = list(f = poisson(),        g = function(ns,nt) matrix(rpois(ns*nt,3), ns, nt))
)
for (nm in names(gens)) {
  fit <- mk(gens[[nm]]$f, gens[[nm]]$g)
  if (inherits(fit, "try-error")) { cat(sprintf("  %-18s FIT FAILED: %s", nm, as.character(fit))); next }
  ob <- fit$tmb_obj; th <- ob$env$last.par.best; ri <- ob$env$random
  vals <- vapply(c(0, 1, 3, 5, 8, 12), function(sh) {
    t2 <- th; t2[ri] <- t2[ri] + sh
    v <- try(as.numeric(ob$env$f(t2, order = 0)), silent = TRUE)
    if (inherits(v, "try-error")) NA_real_ else v
  }, numeric(1))
  cat(sprintf("  %-18s f at shift 0/1/3/5/8/12 SD: %s\n", nm,
      paste(formatC(vals, format="g", digits=6), collapse=" | ")))
}
