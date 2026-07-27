## Is `start_method = "res"` also worse on NON-Gaussian reduced-rank fits?
##
## This is the load-bearing gap in the 2026-07-27 evidence. The whole campaign
## was Gaussian, but `res` is documented as "most relevant to non-Gaussian
## reduced-rank fits" (docs/design/49) -- i.e. every measurement so far is from
## the regime the method was NOT primarily aimed at. Any decision to retire
## `res` needs this cell first.
##
## Same design as the Gaussian sweep: 3 traits, d = 1 (the exactly-identified,
## Heywood-prone corner), 200 sites, ~8 species per site, random Lambda per seed.
## `simulate_site_trait()` is Gaussian-only, so the counts are built here.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
options(gllvmTMB.quiet_grammar_notes = TRUE, warn = -1)

make_counts <- function(seed, p = 3L, n_sites = 200L, n_species = 15L,
                        mean_spp = 8L, family = c("poisson", "nbinom2"),
                        alpha0 = 1.5, nb_phi = 3) {
  family <- match.arg(family)
  set.seed(seed)
  Lam <- matrix(round(runif(p * p, -0.8, 0.8), 2), p, p)
  Sigma <- Lam %*% t(Lam) + diag(0.3, p)
  ch <- chol(Sigma)
  u <- matrix(rnorm(n_sites * p), n_sites, p) %*% ch   # site x trait
  alpha <- alpha0 + rnorm(p, 0, 0.2)

  rows <- do.call(rbind, lapply(seq_len(n_sites), function(s) {
    k <- max(2L, rpois(1L, mean_spp))
    spp <- sample.int(n_species, min(k, n_species))
    expand.grid(site = s, species = spp, trait = seq_len(p))
  }))
  eta <- alpha[rows$trait] + u[cbind(rows$site, rows$trait)]
  mu <- exp(pmin(eta, 6))
  rows$value <- if (family == "poisson") rpois(nrow(mu <- as.matrix(mu)), mu)
                else rnbinom(length(mu), mu = mu, size = nb_phi)
  rows$site    <- factor(rows$site)
  rows$species <- factor(rows$species)
  rows$trait   <- factor(paste0("t", rows$trait))
  list(data = rows, Sigma = Sigma)
}

obj_of <- function(ff, dat, fam, ctrl) {
  f <- try(gllvmTMB(ff, data = dat, family = fam, control = ctrl), silent = TRUE)
  if (inherits(f, "try-error")) return(c(obj = NA_real_, pd = NA))
  c(obj = f$opt$objective, pd = isTRUE(f$sd_report$pdHess))
}

run_family <- function(fam_name, fam, seeds) {
  cat(sprintf("\n=== %s: 3 traits, d = 2, %d seeds ===\n", fam_name, length(seeds)))
  out <- do.call(rbind, lapply(seeds, function(s) {
    sim <- make_counts(s, family = fam_name)
    ff <- value ~ 0 + trait + latent(0 + trait | site, d = 2)
    a <- obj_of(ff, sim$data, fam, gllvmTMBcontrol(n_init = 1L))
    b <- obj_of(ff, sim$data, fam, gllvmTMBcontrol(n_init = 1L,
           start_method = list(method = "res")))
    cat(sprintf("  seed %4d | default %10.3f | res %10.3f | %+9.4f nats | pdHess %s/%s\n",
                s, a[["obj"]], b[["obj"]], b[["obj"]] - a[["obj"]],
                a[["pd"]], b[["pd"]])); flush.console()
    data.frame(family = fam_name, seed = s, obj_def = a[["obj"]],
               obj_res = b[["obj"]], nats_worse = b[["obj"]] - a[["obj"]],
               pd_def = a[["pd"]], pd_res = b[["pd"]])
  }))
  out
}

seeds <- seq(101L, 1201L, by = 100L)
res <- rbind(
  run_family("poisson", poisson(), seeds),
  run_family("nbinom2", nbinom2(), seeds)
)

cat("\n=== TALLY (positive = res WORSE) ===\n")
for (f in unique(res$family)) {
  r <- res[res$family == f & is.finite(res$nats_worse), ]
  cat(sprintf("%s: %d/%d res materially WORSE (>0.01), %d BETTER, max gap %+.3f nats\n",
              f, sum(r$nats_worse > 0.01), nrow(r), sum(r$nats_worse < -0.01),
              if (nrow(r)) max(r$nats_worse) else NA))
}
print(res[abs(res$nats_worse) > 0.01 & !is.na(res$nats_worse), ], row.names = FALSE)
saveRDS(res, "dev/2026-07-27-res-nongaussian-d2.rds")
cat("\nDONE\n")
