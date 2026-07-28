#!/usr/bin/env Rscript
## dev/real-data/real-data-benchmark.R
##
## Curie task: run all VA/EVA arms on REAL, field-standard datasets shipped
## by the `gllvm` package, instead of data simulated from our own model's
## assumptions. Internal research only -- no @export, no method= argument,
## no NAMESPACE/src edits, no testthat, no public claim.
##
## Datasets (gllvm::data(package = "gllvm") on this install ships:
## Skabbholmen, beetle, eSpider, fungi, kelpforest, microbialdata --
## no antTraits, no plain "spider"):
##   1. eSpider$abund  -- 100 sites x 12 spider species, REAL abundance
##      counts (0-189). Family picked honestly: Poisson (counts).
##   2. eSpider$abund > 0 -- the SAME 100x12 real survey, thresholded to
##      presence/absence. This is a standard ecological transform of real
##      field data (not a separate genuine survey, and not simulated) used
##      here ONLY to get a real binomial dataset so the JJ arm and gllvm's
##      EVA arm (which requires binomial) can be exercised on real data.
##      Flagged throughout as DERIVED.
##   3. beetle$Y, top-12-by-prevalence species -- 87 sites x 68 ground
##      beetle species, REAL abundance counts (0-3892), subsetted to the 12
##      most prevalent species to keep runtime local-only and comparable in
##      p to eSpider. Family: Poisson (counts).
##
## Arms per condition x q in {2, 3}:
##   gtmb_gh       .approximation_engine_fit(engine="va_r3", eval_method="gh")
##   gtmb_jj       eval_method="jj"                          [binomial only]
##   gllvm_va      gllvm::gllvm(method="VA")
##   gllvm_eva     gllvm::gllvm(method="EVA")                [errors on Poisson --
##                                                             established fact,
##                                                             re-verified below]
##   gtmb_laplace  gllvmTMB(... latent(1|site, d=q, unique=FALSE) ...),
##                 Psi-suppressed matched comparator.
##
## No known truth on real data -- metrics are AGREEMENT, not correctness.

suppressPackageStartupMessages({
  library(stats)
})
`%||%` <- function(x, y) if (is.null(x)) y else x

root <- normalizePath(getwd(), mustWork = TRUE)
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("This script requires devtools::load_all().", call. = FALSE)
}
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = FALSE))
source(file.path(root, "dev", "va-eva-comparator.R"), local = .GlobalEnv)
va_eva_source_private_engines(root, envir = .GlobalEnv)

if (!requireNamespace("gllvm", quietly = TRUE)) {
  stop("This script requires the gllvm package for the comparator arms.", call. = FALSE)
}
suppressPackageStartupMessages(library(gllvm))

out_dir <- file.path(root, "dev", "real-data")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

capture_call <- function(expr) {
  warns <- character(0)
  started <- proc.time()[["elapsed"]]
  value <- tryCatch(
    withCallingHandlers(
      expr,
      warning = function(w) {
        warns[[length(warns) + 1L]] <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - started
  list(value = value, warnings = warns, elapsed = elapsed,
       ok = !inherits(value, "arm_error"))
}

rel_frobenius_sym <- function(A, B) {
  if (is.null(A) || is.null(B) || !all(dim(A) == dim(B))) return(NA_real_)
  denom <- (norm(A, "F") + norm(B, "F")) / 2
  if (!is.finite(denom) || denom == 0) return(NA_real_)
  norm(A - B, "F") / denom
}

compare_loadings <- function(A, B) {
  ## Orthogonal Procrustes: rotate A onto B (both p x q), report per-factor
  ## correlation after rotation. Sign/rotation-invariant identifiability is
  ## exactly what factor loadings have, so this is the correct comparison
  ## (unlike a raw column-wise correlation, which is not rotation-invariant).
  if (is.null(A) || is.null(B) || !all(dim(A) == dim(B))) {
    return(list(cor_per_factor = rep(NA_real_, if (is.null(B)) NA else ncol(B))))
  }
  sv <- tryCatch(svd(t(A) %*% B), error = function(e) NULL)
  if (is.null(sv)) return(list(cor_per_factor = rep(NA_real_, ncol(B))))
  R <- sv$u %*% t(sv$v)
  A_rot <- A %*% R
  cor_per_factor <- vapply(seq_len(ncol(B)), function(k) {
    cc <- tryCatch(stats::cor(A_rot[, k], B[, k]), error = function(e) NA_real_)
    if (length(cc) != 1L || !is.finite(cc)) NA_real_ else cc
  }, numeric(1))
  list(R = R, A_rot = A_rot, cor_per_factor = cor_per_factor)
}

trunc_msg <- function(x, n = 300L) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(x)
  x <- gsub("\\s+", " ", x)
  if (nchar(x) > n) paste0(substr(x, 1L, n), " ...[truncated]") else x
}

# ---------------------------------------------------------------------------
# Warm-up: pay the one-time TMB-compile / first-fit-in-session penalty on a
# throwaway toy fixture for EVERY engine type BEFORE any timed real-data fit,
# so the timing table below is not contaminated by a ~3x first-fit tax that
# would otherwise land on whichever arm happens to run first. (Timing rule
## established this session in dev/warmstart-result.md and prior fixtures.)
# ---------------------------------------------------------------------------
cat("=== Warm-up: paying first-fit-in-session compile costs on toy fixtures ===\n")
{
  set.seed(1)
  n0 <- 20L; p0 <- 4L
  Y0 <- matrix(rpois(n0 * p0, 3), n0, p0)
  long0 <- data.frame(unit = factor(rep(seq_len(n0), times = p0)),
                      trait = factor(rep(seq_len(p0), each = n0)),
                      value = as.vector(Y0))
  X0 <- model.matrix(~ 0 + trait, long0)
  invisible(.approximation_engine_fit(
    engine = "va_r3", y = long0$value, n_trials = rep(1L, nrow(long0)), X = X0,
    unit_id = as.integer(long0$unit), trait_id = as.integer(long0$trait),
    q = 1L, family = "poisson", link = "log", H = 15L, silent = TRUE
  ))
  Yb0 <- matrix(rbinom(n0 * p0, 1, 0.4), n0, p0)
  longb0 <- data.frame(unit = factor(rep(seq_len(n0), times = p0)),
                       trait = factor(rep(seq_len(p0), each = n0)),
                       value = as.vector(Yb0))
  Xb0 <- model.matrix(~ 0 + trait, longb0)
  invisible(.approximation_engine_fit(
    engine = "va_r3", y = longb0$value, n_trials = rep(1L, nrow(longb0)), X = Xb0,
    unit_id = as.integer(longb0$unit), trait_id = as.integer(longb0$trait),
    q = 1L, family = "binomial", link = "logit", H = 15L, silent = TRUE,
    eval_method = "jj"
  ))
  invisible(tryCatch(
    gllvm::gllvm(y = Y0, family = "poisson", num.lv = 1, method = "VA",
                sd.errors = FALSE, seed = 1),
    error = function(e) NULL
  ))
  invisible(tryCatch(
    gllvm::gllvm(y = Yb0, family = "binomial", link = "logit", num.lv = 1,
                method = "EVA", sd.errors = FALSE, seed = 1),
    error = function(e) NULL
  ))
  df0 <- as.data.frame(Y0); names(df0) <- paste0("sp", seq_len(p0))
  df0$site <- factor(seq_len(n0))
  fml0 <- as.formula(paste0("traits(", paste(names(df0)[seq_len(p0)], collapse = ", "),
                            ") ~ 1 + latent(1 | site, d = 1, unique = FALSE)"))
  invisible(tryCatch(gllvmTMB(fml0, data = df0, family = poisson()),
                     error = function(e) NULL))
}
cat("Warm-up complete.\n\n")

# ---------------------------------------------------------------------------
# Load real datasets, honest family choice
# ---------------------------------------------------------------------------
data(eSpider, package = "gllvm", envir = environment())
data(beetle, package = "gllvm", envir = environment())

Y_spider_abund <- eSpider$abund
Y_spider_pa <- (eSpider$abund > 0) * 1L
storage.mode(Y_spider_pa) <- "integer"
dimnames(Y_spider_pa) <- dimnames(eSpider$abund)

beetle_prevalence <- colSums(beetle$Y > 0)
top12 <- names(sort(beetle_prevalence, decreasing = TRUE))[1:12]
Y_beetle_top12 <- beetle$Y[, top12]

conditions <- list(
  list(name = "eSpider_abund", Y = Y_spider_abund, family = "poisson", link = "log",
       real_or_derived = "real",
       note = "gllvm::eSpider$abund, 100 sites x 12 spider species, real abundance counts"),
  list(name = "eSpider_pa", Y = Y_spider_pa, family = "binomial", link = "logit",
       real_or_derived = "derived (presence/absence of the same real eSpider survey)",
       note = "gllvm::eSpider$abund > 0, 100 sites x 12 spider species"),
  list(name = "beetle_top12", Y = Y_beetle_top12, family = "poisson", link = "log",
       real_or_derived = "real",
       note = "gllvm::beetle$Y, 87 sites, top-12-by-prevalence of 68 ground beetle species")
)

cat("=== Dataset dimensions and family (chosen honestly from the data) ===\n")
for (cond in conditions) {
  cat(sprintf("  %-16s dim=%dx%d  family=%-9s  %s (range %d-%d)\n",
             cond$name, nrow(cond$Y), ncol(cond$Y), cond$family, cond$real_or_derived,
             min(cond$Y), max(cond$Y)))
}
cat("\n")

# ---------------------------------------------------------------------------
# Arm runners
# ---------------------------------------------------------------------------

run_gtmb_engine <- function(Y, family, link, q, eval_method) {
  n <- nrow(Y); p <- ncol(Y)
  trait_names <- colnames(Y)
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names),
    value = as.vector(Y)
  )
  X <- stats::model.matrix(~ 0 + trait, long)
  unit_id <- as.integer(long$unit)
  trait_id <- as.integer(long$trait)
  y <- long$value
  n_trials <- rep(1L, length(y))
  fam_code <- if (family == "poisson") "poisson" else "binomial"
  capture_call(
    .approximation_engine_fit(
      engine = "va_r3", y = y, n_trials = n_trials, X = X,
      unit_id = unit_id, trait_id = trait_id, q = q,
      family = fam_code, link = link, H = 15L, silent = TRUE,
      eval_method = eval_method
    )
  )
}

run_gllvm <- function(Y, family, link, q, method) {
  capture_call(
    if (family == "poisson") {
      gllvm::gllvm(y = Y, family = "poisson", num.lv = q, method = method,
                  sd.errors = FALSE, seed = 1:4, control.start = list(n.init = 4, jitter.var = 0.2))
    } else {
      gllvm::gllvm(y = Y, family = "binomial", link = link, num.lv = q, method = method,
                  sd.errors = FALSE, seed = 1:4, control.start = list(n.init = 4, jitter.var = 0.2))
    }
  )
}

run_gtmb_laplace <- function(Y, family, q) {
  n <- nrow(Y)
  trait_names <- colnames(Y)
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))
  fml <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "), ") ~ 1 + latent(1 | site, d = ",
    q, ", unique = FALSE)"
  ))
  fam_obj <- if (family == "poisson") stats::poisson() else stats::binomial()
  capture_call(gllvmTMB(fml, data = df, family = fam_obj))
}

extract_lambda_gtmb <- function(res) {
  if (!res$ok) return(NULL)
  lam <- res$value$engine_result$report$Lambda
  if (is.null(lam) || !is.matrix(lam) || !is.numeric(lam) || !all(is.finite(lam))) return(NULL)
  lam
}

extract_lambda_gllvm <- function(res, q) {
  if (!res$ok) return(NULL)
  fit <- res$value
  theta <- fit$params$theta
  sigma_lv <- fit$params$sigma.lv
  if (is.null(theta)) return(NULL)
  lam <- if (!is.null(sigma_lv)) theta %*% diag(sigma_lv, nrow = q, ncol = q) else theta
  if (!is.matrix(lam) || !is.numeric(lam) || !all(is.finite(lam))) return(NULL)
  lam
}

extract_lambda_laplace <- function(res) {
  if (!res$ok) return(NULL)
  fit <- res$value
  ord <- tryCatch(extract_ordination(fit, level = "unit"), error = function(e) NULL)
  if (is.null(ord) || is.null(ord$loadings)) return(NULL)
  lam <- ord$loadings
  if (!is.matrix(lam) || !is.numeric(lam) || !all(is.finite(lam))) return(NULL)
  lam
}

status_of <- function(res, arm) {
  if (!res$ok) return(paste0("ERROR: ", trunc_msg(res$value$error_message)))
  v <- res$value
  switch(arm,
    gtmb_gh = , gtmb_jj = v$status %||% NA_character_,
    gllvm_va = , gllvm_eva = if (isTRUE(v$convergence)) "converged" else "not_converged",
    gtmb_laplace = if (isTRUE(v$sd_report$pdHess %||% NA)) "pd_hessian" else "no_pd_hessian_or_unavailable",
    NA_character_
  )
}

objective_of <- function(res, arm) {
  ## Returns list(name=, value=, is_bound=) -- our arms report NEGATIVE ELBO
  ## (a bound, to be minimised); gllvm/Laplace report log-likelihood (to be
  ## maximised). Never conflate an ELBO with a likelihood.
  if (!res$ok) return(list(name = NA_character_, value = NA_real_))
  v <- res$value
  switch(arm,
    gtmb_gh = list(name = "negative_elbo_gh", value = as.numeric(v$score$negative_elbo_gh %||% NA_real_)),
    gtmb_jj = list(name = "negative_elbo_jj", value = as.numeric(v$score$negative_elbo_gh %||% NA_real_)),
    gllvm_va = list(name = "gllvm_VA_logL", value = as.numeric(v$logL %||% NA_real_)),
    gllvm_eva = list(name = "gllvm_EVA_logL", value = as.numeric(v$logL %||% NA_real_)),
    gtmb_laplace = list(name = "laplace_logLik", value = as.numeric(-v$opt$objective %||% NA_real_)),
    list(name = NA_character_, value = NA_real_)
  )
}

# ---------------------------------------------------------------------------
# Main loop: for each condition x q, run every applicable arm, extract
# Lambda/Sigma_B, record status/objective/timing/warnings.
# ---------------------------------------------------------------------------

all_fit_rows <- list()
lambda_store <- list()  # keyed by condition/q/arm -> Lambda matrix or NULL

q_values <- c(2L, 3L)

for (cond in conditions) {
  for (q in q_values) {
    cat(sprintf("--- condition=%s  q=%d ---\n", cond$name, q))
    arm_results <- list()

    r <- run_gtmb_engine(cond$Y, cond$family, cond$link, q, eval_method = "gh")
    arm_results[["gtmb_gh"]] <- r
    cat(sprintf("  gtmb_gh:      ok=%s elapsed=%.2fs status=%s\n",
               r$ok, r$elapsed, status_of(r, "gtmb_gh")))

    if (cond$family == "binomial") {
      r <- run_gtmb_engine(cond$Y, cond$family, cond$link, q, eval_method = "jj")
      arm_results[["gtmb_jj"]] <- r
      cat(sprintf("  gtmb_jj:      ok=%s elapsed=%.2fs status=%s\n",
                 r$ok, r$elapsed, status_of(r, "gtmb_jj")))
    }

    r <- run_gllvm(cond$Y, cond$family, cond$link, q, method = "VA")
    arm_results[["gllvm_va"]] <- r
    cat(sprintf("  gllvm_va:     ok=%s elapsed=%.2fs status=%s\n",
               r$ok, r$elapsed, status_of(r, "gllvm_va")))

    r <- run_gllvm(cond$Y, cond$family, cond$link, q, method = "EVA")
    arm_results[["gllvm_eva"]] <- r
    cat(sprintf("  gllvm_eva:    ok=%s elapsed=%.2fs status=%s\n",
               r$ok, r$elapsed, status_of(r, "gllvm_eva")))

    r <- run_gtmb_laplace(cond$Y, cond$family, q)
    arm_results[["gtmb_laplace"]] <- r
    cat(sprintf("  gtmb_laplace: ok=%s elapsed=%.2fs status=%s\n",
               r$ok, r$elapsed, status_of(r, "gtmb_laplace")))

    for (arm in names(arm_results)) {
      res <- arm_results[[arm]]
      lam <- switch(arm,
        gtmb_gh = , gtmb_jj = extract_lambda_gtmb(res),
        gllvm_va = , gllvm_eva = extract_lambda_gllvm(res, q),
        gtmb_laplace = extract_lambda_laplace(res)
      )
      key <- paste(cond$name, q, arm, sep = "||")
      lambda_store[[key]] <- lam

      obj <- objective_of(res, arm)
      evaluations <- NA_integer_
      if (res$ok && arm %in% c("gtmb_gh", "gtmb_jj")) {
        ev <- res$value$engine_result$best$evaluations
        if (is.numeric(ev) && length(ev)) evaluations <- as.integer(ev[1])
      }
      warn_text <- if (length(res$warnings)) paste(vapply(res$warnings, trunc_msg, character(1)), collapse = " | ") else NA_character_

      all_fit_rows[[length(all_fit_rows) + 1L]] <- data.frame(
        condition = cond$name, family = cond$family, real_or_derived = cond$real_or_derived,
        n = nrow(cond$Y), p = ncol(cond$Y), q = q, arm = arm,
        ok = res$ok, status = status_of(res, arm),
        objective_name = obj$name, objective_value = obj$value,
        lambda_available = !is.null(lam),
        evaluations = evaluations,
        elapsed_s = res$elapsed,
        warnings = warn_text,
        error = if (!res$ok) trunc_msg(res$value$error_message) else NA_character_,
        stringsAsFactors = FALSE
      )
    }
    cat("\n")
  }
}

fit_table <- do.call(rbind, all_fit_rows)
write.csv(fit_table, file.path(out_dir, "real-data-fits.csv"), row.names = FALSE)
cat("Wrote", file.path(out_dir, "real-data-fits.csv"), "\n\n")

# ---------------------------------------------------------------------------
# Pairwise agreement: relative Frobenius on Sigma_B (rotation-invariant,
# no alignment needed) and Procrustes per-factor correlation on Lambda
# (needs alignment -- factor loadings are rotation-invariant only up to Q).
# ---------------------------------------------------------------------------

arm_order <- c("gtmb_gh", "gtmb_jj", "gllvm_va", "gllvm_eva", "gtmb_laplace")

pairwise_rows <- list()
for (cond in conditions) {
  for (q in q_values) {
    applicable_arms <- if (cond$family == "binomial") arm_order else setdiff(arm_order, "gtmb_jj")
    lams <- lapply(applicable_arms, function(a) lambda_store[[paste(cond$name, q, a, sep = "||")]])
    names(lams) <- applicable_arms
    for (i in seq_along(applicable_arms)) {
      for (j in seq_along(applicable_arms)) {
        if (j <= i) next
        ai <- applicable_arms[i]; aj <- applicable_arms[j]
        Ai <- lams[[ai]]; Aj <- lams[[aj]]
        if (is.null(Ai) || is.null(Aj)) {
          pairwise_rows[[length(pairwise_rows) + 1L]] <- data.frame(
            condition = cond$name, q = q, arm_i = ai, arm_j = aj,
            rel_frob_Sigma = NA_real_, procrustes_mean_cor = NA_real_,
            procrustes_min_cor = NA_real_, evaluable = FALSE,
            stringsAsFactors = FALSE
          )
          next
        }
        Sigma_i <- Ai %*% t(Ai)
        Sigma_j <- Aj %*% t(Aj)
        rf <- rel_frobenius_sym(Sigma_i, Sigma_j)
        proc <- compare_loadings(Ai, Aj)
        pairwise_rows[[length(pairwise_rows) + 1L]] <- data.frame(
          condition = cond$name, q = q, arm_i = ai, arm_j = aj,
          rel_frob_Sigma = rf,
          procrustes_mean_cor = mean(abs(proc$cor_per_factor), na.rm = TRUE),
          procrustes_min_cor = suppressWarnings(min(abs(proc$cor_per_factor), na.rm = TRUE)),
          evaluable = TRUE,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}
pairwise_table <- do.call(rbind, pairwise_rows)
write.csv(pairwise_table, file.path(out_dir, "real-data-pairwise-agreement.csv"), row.names = FALSE)
cat("Wrote", file.path(out_dir, "real-data-pairwise-agreement.csv"), "\n\n")

# ---------------------------------------------------------------------------
# Bound-ordering check (binomial conditions only): our GH ELBO must exceed
# our JJ ELBO (tighter bound is higher, both are lower bounds -> higher is
# better/tighter), and BOTH ELBOs must sit at or below the matched Laplace
# logLik (Laplace approximates the true marginal log-likelihood; VA gives a
# lower bound on it).
# ---------------------------------------------------------------------------
cat("=== Bound-ordering check (binomial conditions) ===\n")
bound_rows <- list()
for (cond in conditions) {
  if (cond$family != "binomial") next
  for (q in q_values) {
    gh_row <- fit_table[fit_table$condition == cond$name & fit_table$q == q & fit_table$arm == "gtmb_gh", ]
    jj_row <- fit_table[fit_table$condition == cond$name & fit_table$q == q & fit_table$arm == "gtmb_jj", ]
    lap_row <- fit_table[fit_table$condition == cond$name & fit_table$q == q & fit_table$arm == "gtmb_laplace", ]
    neg_elbo_gh <- gh_row$objective_value[1]
    neg_elbo_jj <- jj_row$objective_value[1]
    laplace_logLik <- lap_row$objective_value[1]
    elbo_gh <- -neg_elbo_gh
    elbo_jj <- -neg_elbo_jj
    gh_ge_jj <- if (is.finite(elbo_gh) && is.finite(elbo_jj)) elbo_gh >= elbo_jj - 1e-6 else NA
    gh_le_laplace <- if (is.finite(elbo_gh) && is.finite(laplace_logLik)) elbo_gh <= laplace_logLik + 1e-6 else NA
    jj_le_laplace <- if (is.finite(elbo_jj) && is.finite(laplace_logLik)) elbo_jj <= laplace_logLik + 1e-6 else NA
    cat(sprintf("  %s q=%d: ELBO_GH=%s ELBO_JJ=%s Laplace_logLik=%s | GH>=JJ:%s GH<=Lap:%s JJ<=Lap:%s\n",
               cond$name, q, format(elbo_gh, digits = 8), format(elbo_jj, digits = 8),
               format(laplace_logLik, digits = 8), gh_ge_jj, gh_le_laplace, jj_le_laplace))
    bound_rows[[length(bound_rows) + 1L]] <- data.frame(
      condition = cond$name, q = q, elbo_gh = elbo_gh, elbo_jj = elbo_jj,
      laplace_logLik = laplace_logLik, gh_ge_jj = gh_ge_jj,
      gh_le_laplace = gh_le_laplace, jj_le_laplace = jj_le_laplace,
      stringsAsFactors = FALSE
    )
  }
}
bound_table <- do.call(rbind, bound_rows)
write.csv(bound_table, file.path(out_dir, "real-data-bound-ordering.csv"), row.names = FALSE)
cat("Wrote", file.path(out_dir, "real-data-bound-ordering.csv"), "\n\n")

cat("=== DONE ===\n")
