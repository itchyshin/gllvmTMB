## READ-ONLY structural probe: what does TMB declare as `random`, and how long
## is the vector AGHQ would have to integrate over?
## Run: Rscript 02-random-vector-probe.R
suppressPackageStartupMessages(library(gllvmTMB))
set.seed(11)

n_sites <- 40L; n_tr <- 5L; q <- 2L
site <- factor(seq_len(n_sites))
z <- matrix(rnorm(n_sites * q), n_sites, q)
Lam <- matrix(rnorm(n_tr * q, 0, 0.7), n_tr, q)
eta <- z %*% t(Lam)
Y <- eta + matrix(rnorm(n_sites * n_tr, 0, 0.5), n_sites, n_tr)
colnames(Y) <- paste0("t", seq_len(n_tr))
wide <- data.frame(site = site, Y, check.names = FALSE)
ctl <- gllvmTMBcontrol(se = FALSE)

report <- function(tag, fit) {
  o <- fit$tmb_obj
  idx <- o$env$random
  pl <- o$env$parList()
  blocks <- fit$random
  dims <- vapply(blocks, function(b) length(pl[[b]]), integer(1))
  cat(sprintf("\n== %s ==\n", tag))
  cat("  fit$random blocks : ", paste(blocks, collapse = ", "), "\n")
  cat("  per-block lengths : ", paste(sprintf("%s=%d", blocks, dims), collapse = ", "), "\n")
  cat("  length(env$random): ", length(idx), "\n")
  cat("  n fixed par       : ", length(o$par), "\n")
  invisible(NULL)
}

f1 <- suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4,t5) ~ 1 + latent(1 | site, d = 2),
  data = wide, unit = "site", family = gaussian(), control = ctl)))
report("latent(d=2) DEFAULT (Psi on)", f1)

f2 <- suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4,t5) ~ 1 + latent(1 | site, d = 2, unique = FALSE),
  data = wide, unit = "site", family = gaussian(), control = ctl)))
report("latent(d=2, unique=FALSE) loadings only", f2)

## Missing responses: mask 12% of cells and see whether the random dim changes.
wide_mis <- wide
mis <- sample(which(!is.na(as.matrix(wide[,-1]))), 12)
M <- as.matrix(wide_mis[, -1]); M[mis] <- NA; wide_mis[, -1] <- M
f3 <- try(suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4,t5) ~ 1 + latent(1 | site, d = 2),
  data = wide_mis, unit = "site", family = gaussian(), control = ctl))), silent = TRUE)
if (!inherits(f3, "try-error")) {
  report("latent(d=2) DEFAULT, 12 masked response cells", f3)
  cat("  is_y_observed sum : ", sum(f3$tmb_data$is_y_observed), " / ",
      length(f3$tmb_data$is_y_observed), "\n")
} else cat("\n== masked fit FAILED ==\n", as.character(f3), "\n")

cat("\nsessionInfo pkg version: ", as.character(packageVersion("gllvmTMB")), "\n")
