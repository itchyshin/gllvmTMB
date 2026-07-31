## #851 -- the comparator result across SEEDS, not one.
##
## The single-seed result (gllvmTMB equivariant; gllvm 17% out at k=100;
## glmmTMB rel.err ~1-2) is strong on mechanism but is one DGP and one seed.
## A claim of the form "gllvmTMB is scale-equivariant where the comparators are
## not" needs to survive resampling before it is said out loud anywhere.
##
## Same law throughout: Lambda(k*Y) must equal k*Lambda(Y). tol 0.02.

suppressPackageStartupMessages({
  library(gllvm); library(glmmTMB)
  devtools::load_all("/private/tmp/gllvmtmb-851", quiet = TRUE)
})

n <- 150L; p <- 4L
Lam_true <- matrix(c(0.9, 0.6, -0.5, 0.4), p, 1L)

mk <- function(Y) data.frame(
  unit  = factor(rep(seq_len(nrow(Y)), times = ncol(Y))),
  trait = factor(rep(paste0("t", seq_len(ncol(Y))), each = nrow(Y))),
  value = as.numeric(Y))

lam_tmb <- function(Y) {
  f <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), data = mk(Y),
    unit = "unit", trait = "trait", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE))))
  as.numeric(f$report$Lambda_B)
}
lam_gl <- function(Y) {
  f <- suppressWarnings(gllvm(y = Y, family = gaussian(), num.lv = 1,
                              seed = 1, trace = FALSE))
  s <- tryCatch(as.numeric(f$params$sigma.lv)[1], error = function(e) 1)
  as.numeric(f$params$theta) * s
}
lam_gt <- function(Y) {
  f <- suppressWarnings(glmmTMB(value ~ 0 + trait + rr(trait + 0 | unit, d = 1),
                                data = mk(Y), family = gaussian()))
  as.numeric(f$obj$env$report(f$fit$parfull)$fact_load[[1]])
}

rel <- function(base, got, k) {
  if (inherits(base, "try-error") || inherits(got, "try-error")) return(NA_real_)
  if (length(base) != length(got)) return(NA_real_)
  max(abs(got - base * k) / pmax(abs(base * k), 1e-8))
}

seeds <- 1:8
ks <- c(100, 5000)
res <- list()
for (sd_ in seeds) {
  set.seed(sd_)
  Z  <- matrix(rnorm(n), n, 1L)
  Y1 <- Z %*% t(Lam_true) + matrix(rnorm(n * p, sd = sqrt(0.3)), n, p)
  b <- list(tmb = try(lam_tmb(Y1), TRUE), gl = try(lam_gl(Y1), TRUE), gt = try(lam_gt(Y1), TRUE))
  for (k in ks) {
    a <- list(tmb = try(lam_tmb(Y1 * k), TRUE), gl = try(lam_gl(Y1 * k), TRUE),
              gt = try(lam_gt(Y1 * k), TRUE))
    res[[length(res) + 1L]] <- data.frame(
      seed = sd_, k = k,
      gllvmTMB = rel(b$tmb, a$tmb, k),
      gllvm    = rel(b$gl,  a$gl,  k),
      glmmTMB  = rel(b$gt,  a$gt,  k))
  }
}
R <- do.call(rbind, res)

cat("\n=== per-seed relative error of Lambda vs the exact law (tol 0.02) ===\n")
print(within(R, {
  gllvmTMB <- signif(gllvmTMB, 3); gllvm <- signif(gllvm, 3); glmmTMB <- signif(glmmTMB, 3)
}), row.names = FALSE)

cat("\n=== VIOLATION RATE (rel.err >= 0.02), by package and k ===\n")
for (k in ks) {
  s <- R[R$k == k, ]
  f <- function(v) sprintf("%d/%d", sum(v >= 0.02, na.rm = TRUE), sum(!is.na(v)))
  cat(sprintf("  k=%-6g  gllvmTMB %-6s   gllvm %-6s   glmmTMB %-6s\n",
              k, f(s$gllvmTMB), f(s$gllvm), f(s$glmmTMB)))
}
cat("\n=== worst case per package (any k, any seed) ===\n")
cat(sprintf("  gllvmTMB %.3g   gllvm %.3g   glmmTMB %.3g\n",
            max(R$gllvmTMB, na.rm = TRUE), max(R$gllvm, na.rm = TRUE),
            max(R$glmmTMB, na.rm = TRUE)))
