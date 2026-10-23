## Second, harder pre-run dataset: aims to actually trigger a runaway/Heywood
## loading (dataset 1 did not: ML max_loading = 1.93, runaway_flag FALSE
## across every arm). Same fitting/extraction logic as tau-prerun.R.
## Orchestrator-directed DGP: smaller n, sparser+narrower prevalence range,
## larger true loading SD to push a few items toward quasi-separation.

Sys.setenv(OMP_NUM_THREADS = "1")
suppressPackageStartupMessages(library(gllvmTMB))

out_dir <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/46df980d-b0f8-4444-a181-ed4b4a683bbe/scratchpad"

set.seed(20260903)

n_sites <- 150L
p       <- 24L

prevalence_grid <- seq(0.01, 0.30, length.out = p)
true_intercept   <- qnorm(prevalence_grid)

true_loading <- rnorm(p, mean = 0, sd = 1.5)
true_z       <- rnorm(n_sites, mean = 0, sd = 1)

eta       <- outer(true_z, true_loading) + matrix(true_intercept, n_sites, p, byrow = TRUE)
true_prob <- pnorm(eta)
y         <- matrix(rbinom(n_sites * p, size = 1, prob = as.vector(true_prob)),
                     nrow = n_sites, ncol = p)
colnames(y) <- paste0("item", seq_len(p))

dat <- data.frame(
  site  = rep(seq_len(n_sites), times = p),
  trait = rep(colnames(y), each = n_sites),
  value = as.vector(y)
)
dat$trait <- factor(dat$trait, levels = colnames(y))

cat("Dataset 2 realised prevalence range:", round(range(colMeans(y)), 3), "\n")

formula <- value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
fam     <- binomial(link = "probit")

arms <- list(
  ml            = list(control = gllvmTMBcontrol()),
  ridge_tau0.25 = list(control = gllvmTMBcontrol(loading_ridge = 0.25)),
  ridge_tau0.5  = list(control = gllvmTMBcontrol(loading_ridge = 0.5)),
  ridge_tau1    = list(control = gllvmTMBcontrol(loading_ridge = 1)),
  ridge_tau2    = list(control = gllvmTMBcontrol(loading_ridge = 2)),
  va            = list(control = gllvmTMBcontrol(integration = "va"))
)

fit_one <- function(nm) {
  ctrl <- arms[[nm]]$control
  timing <- system.time({
    fit <- tryCatch(
      gllvmTMB(formula, data = dat, family = fam, trait = "trait",
               unit = "site", control = ctrl, silent = TRUE),
      error = function(e) e
    )
  })
  runtime_s <- as.numeric(timing["elapsed"])

  if (inherits(fit, "error")) {
    return(list(
      arm = nm, converged = NA, max_gradient = NA_real_, max_loading = NA_real_,
      loading_spearman = NA_real_, lv_cor = NA_real_, prob_rmse = NA_real_,
      runaway_flag = NA, runtime_s = runtime_s,
      note = paste0("FIT ERROR: ", conditionMessage(fit))
    ))
  }

  is_va <- inherits(fit, "gllvmTMB_va")

  if (is_va) {
    converged    <- identical(fit$status, "healthy")
    max_gradient <- NA_real_
  } else {
    converged    <- isTRUE(fit$fit_health$converged)
    max_gradient <- fit$fit_health$max_gradient
  }

  est_loading <- tryCatch(as.vector(getLoadings(fit, level = "unit")), error = function(e) NA_real_)
  est_z       <- tryCatch(as.vector(getLV(fit, level = "unit")), error = function(e) NA_real_)

  max_loading      <- if (all(is.finite(est_loading))) max(abs(est_loading)) else NA_real_
  loading_spearman <- if (all(is.finite(est_loading)))
    abs(suppressWarnings(cor(est_loading, true_loading, method = "spearman"))) else NA_real_
  lv_cor <- if (all(is.finite(est_z)))
    abs(suppressWarnings(cor(est_z, true_z))) else NA_real_

  prob_rmse <- tryCatch({
    fdf       <- fitted(fit)
    true_vec  <- as.vector(true_prob)
    key_est   <- paste(as.character(fdf$site), as.character(fdf$trait))
    key_true  <- paste(as.character(dat$site), as.character(dat$trait))
    idx       <- match(key_est, key_true)
    sqrt(mean((fdf$est - true_vec[idx])^2, na.rm = TRUE))
  }, error = function(e) NA_real_)

  runaway_flag <- if (is_va) {
    NA
  } else {
    tryCatch({
      chk <- check_gllvmTMB(fit)
      any(chk$component == "binomial_prevalence_loading" & chk$status %in% c("WARN", "FAIL"))
    }, error = function(e) NA)
  }

  list(
    arm = nm, converged = converged, max_gradient = max_gradient,
    max_loading = max_loading, loading_spearman = loading_spearman,
    lv_cor = lv_cor, prob_rmse = prob_rmse, runaway_flag = runaway_flag,
    runtime_s = runtime_s, note = ""
  )
}

arm_names <- names(arms)
can_fork <- .Platform$OS.type == "unix"
results <- if (can_fork) {
  tryCatch(
    parallel::mclapply(arm_names, fit_one, mc.cores = min(6L, length(arm_names))),
    error = function(e) lapply(arm_names, fit_one)
  )
} else {
  lapply(arm_names, fit_one)
}
names(results) <- arm_names

bad <- vapply(results, function(x) is.null(x) || inherits(x, "try-error"), logical(1))
if (any(bad)) {
  for (nm in arm_names[bad]) results[[nm]] <- fit_one(nm)
}

res_df <- do.call(rbind, lapply(results, function(x) {
  data.frame(
    arm = x$arm, converged = x$converged, max_gradient = x$max_gradient,
    max_loading = x$max_loading, loading_spearman = x$loading_spearman,
    lv_cor = x$lv_cor, prob_rmse = x$prob_rmse,
    runaway_flag = x$runaway_flag, runtime_s = x$runtime_s,
    note = x$note, stringsAsFactors = FALSE
  )
}))
rownames(res_df) <- NULL
res_df <- res_df[match(c("ml", "ridge_tau0.25", "ridge_tau0.5", "ridge_tau1",
                          "ridge_tau2", "va"), res_df$arm), ]

print(res_df, digits = 4)

write.csv(res_df, file.path(out_dir, "tau-prerun-dataset2.csv"), row.names = FALSE)
cat("\nWrote", file.path(out_dir, "tau-prerun-dataset2.csv"), "\n")
