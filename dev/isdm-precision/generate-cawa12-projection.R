## ---------------------------------------------------------------------------
## The projection null, ON THE TWELVE-SPECIES DESIGN.
##
## The article previously quoted five paired objective differences from a
## SEPARATE three-species model on a different landscape -- a number no chunk
## on the page produced. This recomputes it on the shipped design so the claim
## is reproducible from the article's own simulator.
##
## Question: can the likelihood tell a mesh built on projected (UTM km)
## coordinates from one built on unprojected lon/lat?
## ---------------------------------------------------------------------------
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-1132", quiet = TRUE))
source("/private/tmp/gllvmtmb-1132/dev/isdm-precision/generate-cawa12.R")

N_SEED <- 6L
land <- cawa12_landscape(); spec <- cawa12_species()

fit_on <- function(d, xy, cutoff) {
  m <- make_mesh(d, xy_cols = xy, cutoff = cutoff)
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + isdm_source + offset(log_effort) +
      spatial_latent(0 + trait | coords, d = 2),
    data = d, trait = "trait", unit = "cell_id",
    family = isdm_sources(ebird = poisson(), abmi = binomial(link = "cloglog")),
    mesh = m, silent = TRUE))), silent = TRUE)
  if (inherits(f, "try-error")) return(list(ok = FALSE))
  ok <- identical(as.integer(f$opt$convergence), 0L) &&
        !is.null(f$opt$iterations) && f$opt$iterations > 1L &&
        is.finite(f$opt$objective)
  b <- f$opt$par[names(f$opt$par) == "b_fix"]
  list(ok = ok, obj = f$opt$objective, it = f$opt$iterations,
       nodes = ncol(m$A_st),
       slopes = unname(b[grep(":env$", f$X_fix_names)]))
}

truth <- spec$beta
rows <- list()
for (s in seq_len(N_SEED)) {
  d <- sim_cawa12(1000L + s, land = land, spec = spec)
  ## lon/lat mesh: cutoff in DEGREES, tuned for a comparable node count
  a <- fit_on(d, c("lon", "lat"), 0.46)
  b <- fit_on(d, c("X", "Y"), 40)
  if (!isTRUE(a$ok) || !isTRUE(b$ok)) { cat("seed", s, "rejected\n"); next }
  rows[[length(rows) + 1L]] <- data.frame(
    seed = 1000L + s,
    obj_lonlat = a$obj, obj_utm = b$obj, d_obj = a$obj - b$obj,
    nodes_lonlat = a$nodes, nodes_utm = b$nodes,
    it_lonlat = a$it, it_utm = b$it,
    err_lonlat = mean(abs(a$slopes - truth)),
    err_utm    = mean(abs(b$slopes - truth)))
  cat("seed", s, "d_obj", round(a$obj - b$obj, 3),
      "| err", round(a$err <- mean(abs(a$slopes - truth)), 4),
      "vs", round(mean(abs(b$slopes - truth)), 4), "\n")
}
res <- do.call(rbind, rows)
out <- list(built = format(Sys.time()), n_seeds = nrow(res), per_seed = res,
            mean_d_obj = mean(res$d_obj), se_d_obj = sd(res$d_obj)/sqrt(nrow(res)),
            sign_flips = sum(sign(res$d_obj) != sign(mean(res$d_obj))),
            utm_better_n = sum(res$err_utm < res$err_lonlat),
            mean_err_lonlat = mean(res$err_lonlat), mean_err_utm = mean(res$err_utm))
saveRDS(out, "/private/tmp/gllvmtmb-1132/dev/isdm-precision/cawa12-projection.rds")
cat("\n=== SUMMARY ===\n")
cat(sprintf("seeds %d | mean d_obj %.3f (SE %.3f) | sign flips %d | UTM better %d/%d\n",
  out$n_seeds, out$mean_d_obj, out$se_d_obj, out$sign_flips, out$utm_better_n, out$n_seeds))
cat(sprintf("mean |err|: lon/lat %.4f  UTM %.4f\n", out$mean_err_lonlat, out$mean_err_utm))
cat("nodes: lon/lat", paste(res$nodes_lonlat, collapse=","), "| UTM", paste(res$nodes_utm, collapse=","), "\n")
