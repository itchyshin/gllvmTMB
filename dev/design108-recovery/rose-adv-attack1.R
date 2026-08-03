## ROSE ADVERSARIAL REVIEW -- Attack 1: is the 66% VA non-completion a VA
## property or a HARNESS property? The campaign's grid script swallowed every
## failure into NA with no message. This re-runs known-FAILING cells with the
## error CAPTURED, and classifies where the NA comes from:
##   (a) .va_r3_fit() itself errored          -> engine/optimizer property
##   (b) fit returned, layout extraction failed -> harness property
##   (c) fit + layout OK, tier-sigma extraction failed -> harness property
## Then re-runs the SAME failing cells with n_starts = 4 (the harness's own
## .d108_fit_va default) to test whether n_starts = 1 causes the failures.
setwd("/private/tmp/gllvmtmb-d108-recovery")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source("dev/design108-recovery/dgp.R")
source("dev/design108-recovery/harness.R")

T0 <- 10L

## Exact replica of the campaign's inline VA call, but classifying the failure.
probe <- function(N, q, seed, n_starts) {
  sim <- simulate_two_tier(N = N, T = T0, q = q, seed = seed,
                           phylo_scale = 1, n_trials = 6L)
  yv <- as.numeric(scale(sim$data$y)); d <- sim$data
  X <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
  phy <- .d108_va_phylo_tiers("augmented", sim$tree, sim$species_levels, d$unit, T0, q)
  t2t <- sim$truth$tier2$Sigma_B_loadings

  t0 <- proc.time()[["elapsed"]]
  va <- tryCatch(
    gllvmTMB:::.va_r3_fit(y = yv, n_trials = d$n_trials, X = X, unit_id = d$unit,
      trait_id = d$trait, q = q, family = "gaussian_anchor", link = "identity",
      unique = TRUE, structured = phy$structured, extra_tiers = phy$extra_tiers,
      profile_variational = TRUE, n_starts = n_starts, H = 15L,
      control = list(eval.max = 600L, iter.max = 300L)),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "va_err"))
  secs <- round(proc.time()[["elapsed"]] - t0, 1)

  if (inherits(va, "va_err"))
    return(data.frame(N = N, q = q, seed = seed, n_starts = n_starts,
                      stage = "FIT_ERROR", secs = secs, va_t2 = NA_real_,
                      detail = substr(va$msg, 1, 160)))
  if (is.null(va))
    return(data.frame(N = N, q = q, seed = seed, n_starts = n_starts,
                      stage = "FIT_NULL", secs = secs, va_t2 = NA_real_, detail = ""))

  lay <- tryCatch(gllvmTMB:::.va_r3_validate_data(y = yv, n_trials = d$n_trials,
           X = X, unit_id = d$unit, trait_id = d$trait, q = q,
           family = "gaussian_anchor", link = "identity", unique = TRUE,
           structured = phy$structured, extra_tiers = phy$extra_tiers)$tier_layout,
         error = function(e) structure(list(msg = conditionMessage(e)), class = "va_err"))
  if (inherits(lay, "va_err") || is.null(lay))
    return(data.frame(N = N, q = q, seed = seed, n_starts = n_starts,
                      stage = "LAYOUT_FAIL", secs = secs, va_t2 = NA_real_,
                      detail = if (is.list(lay)) substr(lay$msg, 1, 160) else ""))

  s2 <- tryCatch(.d108_va_tier_sigma(va$best$par, lay, 3L, 4L, T0),
                 error = function(e) structure(list(msg = conditionMessage(e)), class = "va_err"))
  if (inherits(s2, "va_err") || is.null(s2))
    return(data.frame(N = N, q = q, seed = seed, n_starts = n_starts,
                      stage = "TIERSIGMA_FAIL", secs = secs, va_t2 = NA_real_,
                      detail = if (is.list(s2)) substr(s2$msg, 1, 160) else "returned NULL"))

  ## also record the VA status/health so we can see WHAT the engine said
  st <- tryCatch(as.character(va$status), error = function(e) NA_character_)
  data.frame(N = N, q = q, seed = seed, n_starts = n_starts, stage = "OK",
             secs = secs, va_t2 = rel_frob(s2$Sigma_B_loadings, t2t),
             detail = paste0("status=", st))
}

## Cells recorded NA in campaign_grid.csv (N=500,q=1): seeds 2,3,4 (all failed).
## Cell recorded OK: seed 1 (va_t2 == 1.000, the zero-collapse).
CELLS <- list(c(500,1,2), c(500,1,3), c(500,1,4), c(500,1,1))

res <- do.call(rbind, lapply(CELLS, function(c3)
  probe(as.integer(c3[1]), as.integer(c3[2]), as.integer(c3[3]), n_starts = 1L)))
cat("\n########## n_starts = 1 (the campaign's setting) ##########\n")
print(res, row.names = FALSE)

res4 <- do.call(rbind, lapply(CELLS, function(c3)
  probe(as.integer(c3[1]), as.integer(c3[2]), as.integer(c3[3]), n_starts = 4L)))
cat("\n########## n_starts = 4 (the harness .d108_fit_va default) ##########\n")
print(res4, row.names = FALSE)

saveRDS(rbind(res, res4), "dev/design108-recovery/pilot-results/rose-adv-attack1.rds")
cat("\nROSE_ATTACK1_DONE\n")
