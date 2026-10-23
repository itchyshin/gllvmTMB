suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(fmesher))
set.seed(7)
sp <- c("A","B","C")
## Two arms at COMPLETELY DIFFERENT locations -- the real data shape.
n_po <- 180; n_sv <- 90
po <- data.frame(x = runif(n_po, 0, 10), y = runif(n_po, 0, 10))
sv <- data.frame(x = runif(n_sv, 0, 10), y = runif(n_sv, 0, 10))
envf <- function(x,y) 0.7*sin(x/2.5) + 0.5*cos(y/3)
po$env <- envf(po$x, po$y); sv$env <- envf(sv$x, sv$y)
mu <- mean(c(po$env, sv$env)); sdv <- sd(c(po$env, sv$env))
po$env <- (po$env-mu)/sdv; sv$env <- (sv$env-mu)/sdv

mk <- function(loc, src, off) do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(site = paste0(src, "_", seq_len(nrow(loc))),
             x = loc$x, y = loc$y, env = loc$env, trait = sp[j], src = src,
             value = rpois(nrow(loc), exp(off[j] + c(0.9,-0.4,0.5)[j]*loc$env)))))
d <- rbind(mk(po,"po",c(1.1,0.8,0.9)), mk(sv,"survey",c(0.4,0.2,0.3)))
d$trait <- factor(d$trait, levels=sp); d$src <- factor(d$src); d$site <- factor(d$site)

cat("PO sites:", n_po, " survey sites:", n_sv, "\n")
cat("shared site ids between arms:",
    length(intersect(unique(d$site[d$src=="po"]), unique(d$site[d$src=="survey"]))), "\n")
cat("shared coordinates (x,y) between arms:",
    length(intersect(paste(po$x,po$y), paste(sv$x,sv$y))), "\n")

loc <- unique(d[,c("site","x","y")])
mesh <- fm_mesh_2d(loc = as.matrix(loc[,c("x","y")]), max.edge = c(1.2, 3), cutoff = 0.4)
cat("mesh nodes:", mesh$n, "\n")
t0 <- Sys.time()
f <- try(suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + trait:env + src,
  data = d, trait = "trait", unit = "site",
  family = poisson(), mesh = mesh, silent = TRUE))), silent = TRUE)
if (inherits(f,"try-error")) { cat("FIT FAILED:\n"); cat(as.character(f)) } else {
  b <- f$opt$par[names(f$opt$par)=="b_fix"]
  est <- unname(b[grep(":env$", f$X_fix_names)])
  cat(sprintf("convergence %s | iterations %s | objective %.4g | %.1f s\n",
      f$opt$convergence,
      ifelse(is.null(f$opt$iterations),"NA",f$opt$iterations),
      f$opt$objective, as.numeric(difftime(Sys.time(),t0,units="secs"))))
  cat("true env slopes :", c(0.9,-0.4,0.5), "\n")
  cat("estimated       :", round(est,3), "\n")
}
