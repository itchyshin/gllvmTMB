## dev/multinomial-structured/probe-scalar-null.R
##
## Slice 2 (Design 122, 2026-08-16), task item 5: NULL-DGP probe evidencing
## the phylo_scalar()/animal_scalar()/kernel_scalar() REFUSAL for multinomial
## (family_id 16). This is a DEV SCRIPT, not a test -- it reports numbers, it
## does not gate a pass/fail criterion.
##
## `*_scalar()` is not admitted for multinomial in this release (Design 122
## Slice 0/2, R/multinomial-fence.R): phylo_scalar()/animal_scalar() route
## through the unrelated `propto` engine (blocked by the late `use_propto`
## re-scan); kernel_scalar() shares the SAME phylo_rr/theta_rr_phy diagonal
## route as the now-admitted kernel_indep(), ties the T per-trait diagonal
## phylogenetic variances to ONE shared level, and is distinguished only by
## its `.kernel_mode` marker. Since `*_scalar()` itself cannot be fit for
## multinomial, this probe asks the PRECEDING question directly: on data with
## ZERO phylogenetic signal (V = 0 -- category-liabilities come from fixed
## effects only, no random component at all), does the admitted diagonal
## route (phylo_indep()) -- or a naive scalar SUMMARY built by hand from its
## per-contrast output (mean of the fitted diagonal) -- invent structure? If
## even the diagonal (indep) route reports non-trivial variance under a
## planted-null DGP, a SCALAR collapse across contrasts would compound that:
## it forces the model to report ONE number that is a weighted average across
## K-1 contrast dimensions whose (I+J) null-contrast geometry (Hadfield
## MCMCglmm; the softmax link residual shares that shape at pi^2/6, see
## R/extract-sigma.R) is not exchangeable, so a shared scalar has no natural
## null value.
##
## phylo_dep() is ALSO fit on the same null data (the admitted full-V twin)
## to report whether it invents a spurious among-category CORRELATION on top
## of spurious variance -- the question a scalar collapse cannot even ask,
## since it discards off-diagonal structure by construction.
##
## Usage:
##   Rscript dev/multinomial-structured/probe-scalar-null.R
##
## Writes dev/multinomial-structured/results/probe-scalar-null.csv and prints
## a summary table. 5 seeds, n_sp = 200 (D-139: ~1-2 sec/fit at this size per
## the S1 timing measurement scaled down from n_sp = 800 -- well under the
## 30-min line, run directly, no pre-run-test gate needed).

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."
source(file.path(.here, "dgp-multinomial-structured.R"))

PKG_DIR <- Sys.getenv("GLLVMTMB_DIR", ".")
RESULTS_DIR <- file.path(.here, "results")

suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))

SEEDS <- 601:605
N_SP  <- 200L
K     <- 3L

## Null DGP: sd_true = c(0, 0) -> V_true is the exact zero matrix, so
## G = kronecker(V_true, A_corr) = 0 and MASS::mvrnorm(Sigma = 0) returns the
## mean (all zero) up to floating-point noise -- category liabilities are
## PURE fixed effects (the b0 intercept block), no phylogenetic random
## component whatsoever.
.null_dgp <- function(seed) {
  dgp_multinomial_structured(
    n_sp = N_SP, seed = seed, K = K,
    sd_true = c(0, 0), rho_true = 0
  )
}

.fit_route <- function(keyword, dgp) {
  form <- switch(keyword,
    phylo_indep = value ~ 0 + trait + phylo_indep(0 + trait | species, tree = dgp$tree),
    phylo_dep   = value ~ 0 + trait + phylo_dep(0 + trait | species, tree = dgp$tree),
    stop("unknown keyword: ", keyword)
  )
  t0 <- Sys.time()
  out <- tryCatch({
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      form, data = dgp$data, family = multinomial(),
      trait = "trait", unit = "species"
    )))
    pdhess <- isTRUE(fit$sd_report$pdHess)
    stationary <- tryCatch(.fit_stationary_probe(fit), error = function(e) NA)
    Vhat <- tryCatch({
      s <- extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")
      if (is.matrix(s)) s else s$Sigma
    }, error = function(e) matrix(NA_real_, K - 1L, K - 1L))
    list(keyword = keyword, seed = dgp$seed, pdHess = pdhess, stationary = stationary,
         V_hat = Vhat, error = NA_character_)
  }, error = function(e) {
    list(keyword = keyword, seed = dgp$seed, pdHess = NA, stationary = NA,
         V_hat = matrix(NA_real_, K - 1L, K - 1L), error = conditionMessage(e))
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

## Local copy of the stationarity predicate (setup.R is test-only, not
## sourced by a plain Rscript run).
.fit_stationary_probe <- function(fit) {
  v <- tryCatch(fit$fit_health$stationary_by_scaled_gradient, error = function(e) NULL)
  if (is.logical(v) && length(v) == 1L && !is.na(v)) return(isTRUE(v))
  g <- tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
  obj <- tryCatch(fit$opt$objective, error = function(e) NA_real_)
  if (is.na(g) || is.na(obj)) return(FALSE)
  isTRUE(g / (1 + abs(obj)) < gllvmTMB:::.gllvmTMB_converged_gtol)
}

results <- list()
for (seed in SEEDS) {
  dgp <- .null_dgp(seed)
  results[[length(results) + 1L]] <- .fit_route("phylo_indep", dgp)
  results[[length(results) + 1L]] <- .fit_route("phylo_dep", dgp)
}

.row_from_result <- function(r) {
  V <- r$V_hat
  var1 <- if (is.matrix(V) && nrow(V) >= 1L) V[1, 1] else NA_real_
  var2 <- if (is.matrix(V) && nrow(V) >= 2L) V[2, 2] else NA_real_
  cov12 <- if (is.matrix(V) && nrow(V) >= 2L) V[1, 2] else NA_real_
  rho_hat <- if (is.finite(var1) && is.finite(var2) && var1 > 0 && var2 > 0) {
    cov12 / sqrt(var1 * var2)
  } else NA_real_
  ## The naive "scalar-like" summary a *_scalar() collapse would report: the
  ## mean of the fitted per-contrast diagonal, treating the K-1 contrasts as
  ## exchangeable (which the (I+J) null-contrast geometry says they are NOT).
  scalar_like_mean_var <- mean(c(var1, var2), na.rm = TRUE)
  data.frame(
    keyword = r$keyword, seed = r$seed, pdHess = isTRUE(r$pdHess),
    stationary = isTRUE(r$stationary),
    var1_hat = var1, var2_hat = var2, cov12_hat = cov12, rho_hat = rho_hat,
    scalar_like_mean_var = scalar_like_mean_var,
    elapsed_sec = r$elapsed_sec, error = r$error %||% NA_character_,
    stringsAsFactors = FALSE
  )
}
`%||%` <- function(a, b) if (is.null(a)) b else a

summ <- do.call(rbind, lapply(results, .row_from_result))

cat("== dev/multinomial-structured/probe-scalar-null.R ==\n")
cat(sprintf("Null DGP (V_true = 0, sd_true = c(0,0)), n_sp = %d, K = %d, seeds %s\n",
            N_SP, K, paste(range(SEEDS), collapse = "-")))
print(summ, row.names = FALSE)

converged <- summ[isTRUE_vec <- (summ$pdHess & summ$stationary & is.na(summ$error)), ]
cat(sprintf(
  "\n%d/%d fits jointly PD + stationary.\n", nrow(converged), nrow(summ)
))
if (nrow(converged) > 0L) {
  cat(sprintf(
    "phylo_indep(): median scalar-like mean variance = %s (truth = 0); range [%s, %s]\n",
    signif(median(converged$scalar_like_mean_var[converged$keyword == "phylo_indep"], na.rm = TRUE), 3),
    signif(min(converged$scalar_like_mean_var[converged$keyword == "phylo_indep"], na.rm = TRUE), 3),
    signif(max(converged$scalar_like_mean_var[converged$keyword == "phylo_indep"], na.rm = TRUE), 3)
  ))
  cat(sprintf(
    "phylo_dep():   median |rho_hat| = %s (truth = 0); range [%s, %s]\n",
    signif(median(abs(converged$rho_hat[converged$keyword == "phylo_dep"]), na.rm = TRUE), 3),
    signif(min(abs(converged$rho_hat[converged$keyword == "phylo_dep"]), na.rm = TRUE), 3),
    signif(max(abs(converged$rho_hat[converged$keyword == "phylo_dep"]), na.rm = TRUE), 3)
  ))
}
cat("\nThis is a REPORT, not a gate (Design 122): it evidences whether a scalar-\n")
cat("like summary would be interpretable on the (I+J) contrast geometry -- it\n")
cat("does not itself decide the *_scalar() admission question.\n")

if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE)
write.csv(summ, file.path(RESULTS_DIR, "probe-scalar-null.csv"), row.names = FALSE)
cat("\nwrote:\n  ", file.path(RESULTS_DIR, "probe-scalar-null.csv"), "\n")
