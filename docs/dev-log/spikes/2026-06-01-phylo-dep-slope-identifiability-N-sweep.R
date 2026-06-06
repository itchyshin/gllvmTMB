## Identifiability of the non-Gaussian phylo_dep(1 + x1 + ... + xs | sp)
## augmented slope across sample size N, for ALL reserved core families.
## Spike for GAP-B1 (PHY-18, s = 1) and RE-03 (s = 2) per
## docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md.
##
## QUESTION: every non-Gaussian phylo_dep slope fit returns conv != 0 /
## non-PD Hessian at n_sp <= 100 (PHY-18, SPA-10). Is that genuine non-
## identifiability, or just finite-sample power? This sweeps n_sp and reports
## whether conv == 0 + pdHess == TRUE + recovery-within-band is reached, per
## family.
##
## METHOD (no engine change): build a scaffold fit under the TARGET family
## with the family-general correlated-unique augmented slope
## `phylo_unique(1 + x | species)` (sets up family_id_vec, link_id_vec, the
## augmented random-effect arrays and every family-specific dispersion param),
## then override the harvested tmb_data to the DEP path
## (use_phylo_dep_slope = 1L, full unstructured C x C Sigma_b via
## theta_dep_chol) and refit via TMB::MakeADFun. For s = 2 this deliberately
## bypasses the public fail-loud RE-03 guard: the harness is evidence-gathering,
## not capability admission. The C++ accumulates the dep slope into eta BEFORE
## the family dispatch, so each family's likelihood is exercised with the dep
## covariance. RESEARCH SPIKE -- not a gating test and not an engine change.
##
## REQUIRES an R environment with the package compiled (devtools::load_all).
## Authored in a container WITHOUT R; NOT executed there. Run locally or via
## the `dep-slope-identifiability-sweep` GitHub Actions dispatch workflow.
##
## Env knobs (all optional; the dispatch workflow sets them):
##   GLLVMTMB_SWEEP_FAMILIES  comma list (default all reserved cores + gaussian control)
##   GLLVMTMB_SWEEP_SGRID     comma list of slope counts s (default 1; use 2 for RE-03)
##   GLLVMTMB_SWEEP_NGRID     comma list of n_sp (default 80,150,300,600,1200)
##   GLLVMTMB_SWEEP_SEEDS     comma list of seeds (default 101,202,303)
##   GLLVMTMB_SWEEP_NREP      reps per (species,trait) cell (default 10)
##   GLLVMTMB_SWEEP_OUT       CSV output path (default dep-identifiability-sweep-results.csv)
##
## Run:  Rscript docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R

suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(ape))
suppressMessages(library(TMB))

T_tr <- 2L

## KNOWN PD unstructured (1+s)T x (1+s)T Sigma_b, column-major lower-tri incl
## diag. s = 1 is identical to the validated Gaussian recovery harness /
## original sweep fixture. s = 2 mirrors test-phylo-dep-slope-s2-gaussian.R.
.dep_Ltrue <- function(n_slope) {
  n_slope <- as.integer(n_slope)
  stride <- 1L + n_slope
  C <- stride * T_tr
  L <- matrix(0, C, C)
  if (identical(n_slope, 1L)) {
    L[lower.tri(L, diag = TRUE)] <- c(
      0.8, 0.2, -0.1, 0.15,   # col 1 (rows 1..4)
           0.6,  0.1, -0.05,  # col 2 (rows 2..4)
                 0.5,  0.1,   # col 3 (rows 3..4)
                       0.45   # col 4 (row 4)
    )
    return(L)
  }
  if (identical(n_slope, 2L)) {
    L[lower.tri(L, diag = TRUE)] <- c(
      0.80, 0.15, 0.10, -0.10, 0.08, -0.05, # col 1 (rows 1..6)
      0.55, 0.08, 0.05, -0.04, 0.03,        # col 2 (rows 2..6)
      0.50, 0.06, 0.04, -0.03,              # col 3 (rows 3..6)
      0.75, 0.10, 0.06,                     # col 4 (rows 4..6)
      0.55, 0.05,                           # col 5 (rows 5..6)
      0.50                                  # col 6 (row 6)
    )
    return(L)
  }
  stop("this sweep currently supports s = 1 or s = 2, not s = ", n_slope)
}
.Sigma_b_true <- function(n_slope) {
  L <- .dep_Ltrue(n_slope)
  L %*% t(L)
}
.slope_var_idx <- function(n_slope) {
  stride <- 1L + as.integer(n_slope)
  unlist(lapply(seq_len(T_tr), function(t) {
    base <- stride * (t - 1L)
    base + 1L + seq_len(n_slope)
  }), use.names = FALSE)
}
.slope_col_names <- function(n_slope) {
  if (identical(as.integer(n_slope), 1L)) "x" else paste0("x", seq_len(n_slope))
}

## Binomial trials per row. Default 12 (multi-trial, matching test-matrix-
## slope-binomial-logit.R) routed through the `weights = n_trials` engine API;
## set GLLVMTMB_BINOM_TRIALS=1 for the low-information Bernoulli case.
BINOM_TRIALS <- as.integer(Sys.getenv("GLLVMTMB_BINOM_TRIALS", "12"))

## Per-family link-scale intercepts (modest so non-Gaussian means stay in the
## family's stable range), the family object, and dispersion truth. Borrowed
## from the validated per-family slope tests (test-matrix-slope-*.R).
.fam_spec <- function(fam) {
  switch(fam,
    gaussian = list(obj = gaussian(),                 mu = c(1.0, -0.5), disp = NA,  ord = FALSE),
    poisson  = list(obj = poisson(link = "log"),      mu = c(1.0,  0.7), disp = NA,  ord = FALSE),
    nbinom2  = list(obj = gllvmTMB::nbinom2(),         mu = c(0.7,  0.7), disp = 2,   ord = FALSE),
    Gamma    = list(obj = Gamma(link = "log"),         mu = c(1.0,  0.5), disp = 2,   ord = FALSE),
    Beta     = list(obj = gllvmTMB::Beta(),            mu = c(0.3, -0.3), disp = 5,   ord = FALSE),
    binomial = list(obj = binomial(link = "logit"),    mu = c(0.2, -0.2), disp = NA,  ord = FALSE),
    ordinal_probit = list(obj = ordinal_probit(),      mu = c(0.0,  0.0), disp = NA,  ord = TRUE,
                          taus = c(0, 0.7, 1.4)),      # K = 4 (3 cutpoints), latent residual sd = 1
    stop("unsupported family ", fam)
  )
}

## Draw the augmented effects + response on the link scale, then apply the
## family. Returns the long data frame + tree.
.make_fixture <- function(fam, n_sp, n_rep, seed, n_slope = 1L) {
  set.seed(seed)
  sp <- .fam_spec(fam)
  n_slope <- as.integer(n_slope)
  stride <- 1L + n_slope
  C <- stride * T_tr
  Sigma_b_true <- .Sigma_b_true(n_slope)
  slope_cols <- .slope_col_names(n_slope)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- LA %*% matrix(rnorm(n_sp * C), n_sp, C) %*% chol(Sigma_b_true)   # interleaved (a_t, b_t)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(species = factor(tree$tip.label, levels = tree$tip.label),
                    rep = seq_len(n_rep))
  for (col in slope_cols) sr[[col]] <- rnorm(nrow(sr))
  if (!"x" %in% slope_cols) sr$x <- sr[[slope_cols[1L]]]  # scaffold alias
  trait_levels <- paste0("t", seq_len(T_tr))
  df <- merge(sr, data.frame(trait = factor(trait_levels, levels = trait_levels)), all = TRUE)
  df <- df[order(df$species, df$rep, df$trait), ]
  ti <- as.integer(df$trait)
  si <- match(as.character(df$species), tree$tip.label)
  eta <- sp$mu[ti] + B[cbind(si, stride * (ti - 1L) + 1L)]
  for (j in seq_len(n_slope)) {
    eta <- eta + B[cbind(si, stride * (ti - 1L) + 1L + j)] * df[[slope_cols[j]]]
  }

  wts <- NULL
  df$value <- switch(fam,
    gaussian = eta + rnorm(nrow(df), sd = 0.3),
    poisson  = rpois(nrow(df), exp(eta)),
    nbinom2  = rnbinom(nrow(df), mu = exp(eta), size = sp$disp),
    Gamma    = rgamma(nrow(df), shape = sp$disp, scale = exp(eta) / sp$disp),
    Beta     = {                                                              # clamp exact 0/1 (Beta support is open)
      mu <- plogis(eta)
      pmin(pmax(rbeta(nrow(df), mu * sp$disp, (1 - mu) * sp$disp), 1e-6), 1 - 1e-6)
    },
    binomial = {                                                             # multi-trial via weights = n_trials API
      wts <- rep(BINOM_TRIALS, nrow(df))
      rbinom(nrow(df), size = BINOM_TRIALS, prob = plogis(eta))
    },
    ordinal_probit = {
      z <- eta + rnorm(nrow(df))                                              # latent, residual sd = 1
      ordered(findInterval(z, sp$taus) + 1L, levels = seq_len(length(sp$taus) + 1L))
    },
    stop("add DGP for family ", fam)
  )
  list(df = df, tree = tree, fam_obj = sp$obj, weights = wts,
       n_slope = n_slope, C = C, Sigma_b_true = Sigma_b_true,
       slope_cols = slope_cols)
}

.fail_row <- function(fam, n_sp, seed, n_slope, note) {
  data.frame(family = fam, n_slope = n_slope, n_sp = n_sp, seed = seed,
             conv = NA_integer_, pdHess = NA,
             max_sigma_diff = NA_real_, slope_var_ratio_1 = NA_real_,
             slope_var_ratio_2 = NA_real_, slope_var_ratio_min = NA_real_,
             slope_var_ratio_max = NA_real_, slope_var_ratios = NA_character_,
             note = note, stringsAsFactors = FALSE)
}

## Fit ONE dep-slope cell: scaffold under the target family, override to dep,
## refit, sdreport. Returns a one-row result. Every stage is wrapped so one
## bad cell yields a noted row, never a crash, and the sweep continues.
run_cell <- function(fam, n_sp, n_rep = 10L, seed = 1L, n_slope = 1L) {
  fx <- tryCatch(.make_fixture(fam, n_sp, n_rep, seed, n_slope = n_slope),
                 error = function(e) e)
  if (inherits(fx, "error")) return(.fail_row(fam, n_sp, seed, n_slope, paste("fixture:", conditionMessage(fx))))

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  base <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(1 + x | species),
      data = fx$df, phylo_tree = fx$tree, unit = "species",
      family = fx$fam_obj, weights = fx$weights, control = ctl))),
    error = function(e) e)
  if (inherits(base, "error")) return(.fail_row(fam, n_sp, seed, n_slope, paste("scaffold:", conditionMessage(base))))

  dat <- base$tmb_data; par <- base$tmb_params; map <- base$tmb_map
  n_aug <- dat$n_aug_phy; n_obs <- length(dat$y)

  ## Override harvested scaffold to the DEP path (full unstructured C x C).
  dat$use_phylo_dep_slope <- 1L
  dat$n_lhs_cols <- fx$C
  trid <- dat$trait_id
  Z <- array(0.0, dim = c(n_obs, fx$C, 1L))
  stride <- 1L + fx$n_slope
  for (o in seq_len(n_obs)) {
    t0 <- trid[o]
    base <- stride * t0
    Z[o, base + 1L, 1L] <- 1.0
    for (j in seq_len(fx$n_slope)) {
      Z[o, base + 1L + j, 1L] <- fx$df[[fx$slope_cols[j]]][o]
    }
  }
  dat$Z_phy_aug <- Z
  par$b_phy_aug <- array(0.0, dim = c(n_aug, fx$C, 1L))
  par$theta_dep_chol <- numeric(fx$C * (fx$C + 1L) / 2L)
  par$theta_dep_chol[seq_len(fx$C)] <- log(0.5)
  map$b_phy_aug <- NULL
  map$log_sd_b  <- factor(rep(NA, length(par$log_sd_b)))
  if (length(par$atanh_cor_b) > 0) map$atanh_cor_b <- factor(rep(NA, length(par$atanh_cor_b)))
  map$theta_dep_chol <- NULL

  obj <- tryCatch(TMB::MakeADFun(data = dat, parameters = par, map = map,
                                 random = "b_phy_aug", DLL = "gllvmTMB", silent = TRUE),
                  error = function(e) e)
  if (inherits(obj, "error")) return(.fail_row(fam, n_sp, seed, fx$n_slope, paste("MakeADFun:", conditionMessage(obj))))

  fit <- tryCatch(nlminb(obj$par, obj$fn, obj$gr, control = list(iter.max = 3000, eval.max = 4000)),
                  error = function(e) e)
  if (inherits(fit, "error")) return(.fail_row(fam, n_sp, seed, fx$n_slope, paste("nlminb:", conditionMessage(fit))))

  sdr <- tryCatch(TMB::sdreport(obj), error = function(e) e)
  pdHess <- if (inherits(sdr, "error")) NA else isTRUE(sdr$pdHess)
  Sigma_hat <- tryCatch(obj$report()$Sigma_b_dep, error = function(e) NULL)
  if (is.null(Sigma_hat)) return(.fail_row(fam, n_sp, seed, fx$n_slope, "report() lacked Sigma_b_dep"))
  slope_var_idx <- .slope_var_idx(fx$n_slope)
  ratios <- diag(Sigma_hat)[slope_var_idx] / diag(fx$Sigma_b_true)[slope_var_idx]
  ratio_out <- round(ratios, 3)

  data.frame(family = fam, n_slope = fx$n_slope, n_sp = n_sp, seed = seed,
             conv = fit$convergence, pdHess = pdHess,
             max_sigma_diff = round(max(abs(Sigma_hat - fx$Sigma_b_true)), 4),
             slope_var_ratio_1 = ratio_out[1L],
             slope_var_ratio_2 = if (length(ratio_out) >= 2L) ratio_out[2L] else NA_real_,
             slope_var_ratio_min = round(min(ratios, na.rm = TRUE), 3),
             slope_var_ratio_max = round(max(ratios, na.rm = TRUE), 3),
             slope_var_ratios = paste(ratio_out, collapse = ";"),
             note = if (inherits(sdr, "error")) "sdreport failed" else "", stringsAsFactors = FALSE)
}

## ----- configurable grid -------------------------------------------------
.env_list <- function(key, default) {
  v <- Sys.getenv(key, "")
  if (!nzchar(v)) return(default)
  trimws(strsplit(v, ",")[[1]])
}
families <- .env_list("GLLVMTMB_SWEEP_FAMILIES",
                      c("gaussian", "poisson", "nbinom2", "Gamma", "Beta", "binomial", "ordinal_probit"))
s_grid   <- as.integer(.env_list("GLLVMTMB_SWEEP_SGRID", c("1")))
if (any(!s_grid %in% c(1L, 2L))) {
  stop("GLLVMTMB_SWEEP_SGRID currently supports only 1 and 2.")
}
n_grid   <- as.integer(.env_list("GLLVMTMB_SWEEP_NGRID", c("80", "150", "300", "600", "1200")))
seeds    <- as.integer(.env_list("GLLVMTMB_SWEEP_SEEDS", c("101", "202", "303")))
n_rep    <- as.integer(Sys.getenv("GLLVMTMB_SWEEP_NREP", "10"))
out_csv  <- Sys.getenv("GLLVMTMB_SWEEP_OUT", "dep-identifiability-sweep-results.csv")

## gaussian is the CONTROL: it should pass (conv 0 + pdHess) at every N. If it
## does NOT, the harness itself is broken, not the identifiability question.
## A "covered" verdict for a non-Gaussian family at some N = conv 0 + pdHess +
## slope-var ratios within roughly [1/2, 2] (the validated Gaussian band).
grid <- expand.grid(family = families, n_slope = s_grid, n_sp = n_grid,
                    seed = seeds, stringsAsFactors = FALSE)
cat(sprintf("Running %d cells (%d families x %d s-grid x %d N x %d seeds), n_rep=%d.\n",
            nrow(grid), length(families), length(s_grid), length(n_grid),
            length(seeds), n_rep))
for (s in s_grid) {
  truth <- .Sigma_b_true(s)
  cat(sprintf("True slope variances (s=%d): %s\n", s,
              paste(round(diag(truth)[.slope_var_idx(s)], 3), collapse = ", ")))
}
cat("\n")

results <- do.call(rbind, Map(function(f, ss, n, seed) {
  cat(sprintf("  [%-14s s=%d n_sp=%5d seed=%d] ...\n", f, ss, n, seed))
  r <- run_cell(f, n_sp = n, n_rep = n_rep, seed = seed, n_slope = ss)
  cat(sprintf("      -> conv=%s pdHess=%s maxdiff=%s ratios=%s %s\n",
              r$conv, r$pdHess, r$max_sigma_diff, r$slope_var_ratios,
              if (nzchar(r$note)) paste0("[", r$note, "]") else ""))
  r
}, grid$family, grid$n_slope, grid$n_sp, grid$seed))

cat("\n===== IDENTIFIABILITY SWEEP RESULTS (this run's fresh seeds) =====\n")
print(results, row.names = FALSE)

## Accumulation: when a durable store is supplied (GLLVMTMB_SWEEP_STORE), prepend
## the prior rows so the written CSV + aggregate are CUMULATIVE across the
## campaign's runs. The workflow derives FRESH seeds from the run number each
## run, so rows never collide and the per-cell seed count grows through the week
## -- tightening the seed-sensitive cells (nbinom2 / ordinal_probit).
store <- Sys.getenv("GLLVMTMB_SWEEP_STORE", "")
if (nzchar(store) && file.exists(store)) {
  prev <- tryCatch(utils::read.csv(store, stringsAsFactors = FALSE), error = function(e) NULL)
  if (!is.null(prev) && nrow(prev) > 0L) {
    if (!"n_slope" %in% names(prev)) prev$n_slope <- 1L
    if (!"slope_var_ratio_min" %in% names(prev) ||
          !"slope_var_ratio_max" %in% names(prev)) {
      ratio_cols <- intersect(c("slope_var_ratio_1", "slope_var_ratio_2"), names(prev))
      ratio_mat <- as.matrix(prev[, ratio_cols, drop = FALSE])
      prev$slope_var_ratio_min <- apply(ratio_mat, 1L, function(z) {
        if (all(is.na(z))) NA_real_ else min(z, na.rm = TRUE)
      })
      prev$slope_var_ratio_max <- apply(ratio_mat, 1L, function(z) {
        if (all(is.na(z))) NA_real_ else max(z, na.rm = TRUE)
      })
    }
    if (!"slope_var_ratios" %in% names(prev)) {
      prev$slope_var_ratios <- apply(
        prev[, intersect(c("slope_var_ratio_1", "slope_var_ratio_2"), names(prev)), drop = FALSE],
        1L,
        function(z) paste(z[!is.na(z)], collapse = ";")
      )
    }
    for (nm in setdiff(names(results), names(prev))) prev[[nm]] <- NA
    results <- rbind(prev[, names(results), drop = FALSE], results)
    cat(sprintf("Accumulated with %d prior rows from %s -> %d total rows.\n",
                nrow(prev), store, nrow(results)))
  }
}
write.csv(results, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s (%d rows)\n", out_csv, nrow(results)))

## Per-(family, s, N) verdict over ALL accumulated seeds: PD-fraction,
## recovery-within-band fraction, and seed count.
res2 <- transform(
  results,
  pd = as.integer(conv == 0 & pdHess == TRUE),
  recovered = as.integer(
    conv == 0 & pdHess == TRUE &
      slope_var_ratio_min >= 0.5 & slope_var_ratio_max <= 2
  )
)
agg_f <- aggregate(pd ~ family + n_slope + n_sp, res2,
                   FUN = function(z) round(mean(z, na.rm = TRUE), 3), na.action = stats::na.pass)
agg_r <- aggregate(recovered ~ family + n_slope + n_sp, res2,
                   FUN = function(z) round(mean(z, na.rm = TRUE), 3), na.action = stats::na.pass)
agg_n <- aggregate(pd ~ family + n_slope + n_sp, res2,
                   FUN = function(z) sum(!is.na(z)), na.action = stats::na.pass)
agg <- Reduce(function(x, y) merge(x, y, by = c("family", "n_slope", "n_sp")),
              list(agg_f, agg_r, agg_n))
names(agg)[4:6] <- c("pd_frac", "recovery_frac", "n_seeds")
cat("\n===== CUMULATIVE FRACTION conv==0 & pdHess + recovery (accumulated seed count) =====\n")
print(agg[order(agg$family, agg$n_slope, agg$n_sp), ], row.names = FALSE)
cat("\nIDENTIFIABILITY_SWEEP_DONE\n")
