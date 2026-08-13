## #872 Totoro characterisation: native Gaussian ML/Laplace only.
## GRID_SMOKE=1 runs the first cell; GRID_WORKERS is capped at 150.
suppressMessages({ library(gllvmTMB); library(parallel) })
out <- Sys.getenv("GRID_OUT", "docs/dev-log/simulation-artifacts/2026-08-13-872-campaign")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
workers <- as.integer(Sys.getenv("GRID_WORKERS", "12")); stopifnot(workers >= 1L, workers <= 150L)
cells <- expand.grid(structure = c("single", "nested"), n_sites = c(150L, 400L),
                     k = c(1, 100, 5000), seed = 1:10, KEEP.OUT.ATTRS = FALSE)
if (identical(Sys.getenv("GRID_SMOKE"), "1")) cells <- cells[1L, , drop = FALSE]
one <- function(cell) tryCatch({
  set.seed(cell$seed); p <- 4L
  base <- simulate_site_trait(n_sites=cell$n_sites, n_species=3L, n_traits=p,
    mean_species_per_site=2L, Lambda_B=matrix(c(.9,.6,-.5,.4),p,1),
    psi_B=rep(.3,p), psi_W=rep(.3,p), beta=matrix(0,p,2), seed=cell$seed)
  f <- if (cell$structure == "nested") value ~ 0+trait+latent(0+trait|site,d=1)+unique(0+trait|site_species) else value ~ 0+trait+latent(0+trait|site,d=1)
  d <- base$data; d$value <- d$value * cell$k
  t <- system.time(fit <- suppressMessages(suppressWarnings(gllvmTMB(f,data=d,family=gaussian(),silent=TRUE,control=gllvmTMBcontrol(se=TRUE)))))[["elapsed"]]
  sb <- extract_Sigma(fit, level="unit")
  sw <- if (cell$structure == "nested") extract_Sigma(fit, level="unit_obs") else NULL
  data.frame(cell, status="OK", objective=fit$tmb_obj$fn(fit$opt$par), convergence=fit$opt$convergence,
    pdHess=isTRUE(fit$sd_report$pdHess), raw_gradient=max(abs(fit$tmb_obj$gr(fit$opt$par))),
    hessian_condition=kappa(fit$sd_report$cov.fixed), sigmaB_norm=norm(sb$Sigma,"F"),
    sigmaW_norm=if(is.null(sw)) NA_real_ else norm(sw$Sigma,"F"), elapsed_seconds=t, error=NA_character_)
}, error=function(e) data.frame(cell,status="ERROR",objective=NA_real_,convergence=NA_integer_,pdHess=NA,
  raw_gradient=NA_real_,hessian_condition=NA_real_,sigmaB_norm=NA_real_,sigmaW_norm=NA_real_,elapsed_seconds=NA_real_,error=conditionMessage(e)))
res <- do.call(rbind, mclapply(seq_len(nrow(cells)), function(i) one(cells[i,,drop=FALSE]), mc.cores=workers, mc.preschedule=FALSE))
write.csv(res, file.path(out,"cells.csv"), row.names=FALSE)
saveRDS(list(cells=res, commit=system2("git",c("rev-parse","HEAD"),stdout=TRUE), workers=workers, session=utils::sessionInfo()), file.path(out,"campaign.rds"))
cat(sprintf("#872 campaign wrote %d rows; %d OK\n", nrow(res), sum(res$status=="OK")))
