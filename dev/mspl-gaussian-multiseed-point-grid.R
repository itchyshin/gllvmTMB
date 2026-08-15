## Local multi-seed Gaussian LA-ML vs LA-MSPL point grid (Arc A1).
## Failure-inclusive denominators. se = FALSE. No SE / sandwich / intervals.
## Recipe mirrors tests/testthat/test-mspl-gaussian-fit-smoke.R fixtures.
##
## Usage:
##   OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
##     dev/mspl-gaussian-multiseed-point-grid.R
##
## Outputs (repo-relative when run from worktree root):
##   docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-grid.tsv
##   /tmp/mspl-gaussian-multiseed-point-grid.rds
##   /tmp/mspl-gaussian-multiseed-point-grid.log  (stdout tee optional)

Sys.setenv(OMP_NUM_THREADS = "1", NOT_CRAN = "true")
options(warn = 1)

`%||%` <- function(x, y) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) y else x
}

rel_frob <- function(A, B) {
  if (is.null(A) || is.null(B)) return(NA_real_)
  num <- sqrt(sum((A - B)^2))
  den <- sqrt(sum(B^2))
  if (!is.finite(den) || den == 0) return(NA_real_)
  num / den
}

ROOT <- Sys.getenv(
  "GLLVMTMB_ROOT",
  unset = "/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap"
)
OUT_TSV <- file.path(
  ROOT, "docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-grid.tsv"
)
OUT_RDS <- "/tmp/mspl-gaussian-multiseed-point-grid.rds"
HARD_STOP_S <- 30 * 60

## ---- fixture (same DGP as test-mspl-gaussian-fit-smoke.R) ----------------
.mspl_gauss_fixture <- function(n_site = 40L, q = 1L, psi = NULL, seed = 150815L) {
  set.seed(seed + q)
  n_trait <- 3L
  if (is.null(psi)) psi <- c(0.55, 0.70, 0.40)
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- matrix(stats::rnorm(n_site * q), n_site, q)
  Lambda <- if (q == 1L) {
    matrix(c(0.90, -0.60, 0.45), n_trait, 1L)
  } else {
    matrix(c(0.90, -0.60, 0.45, 0, 0.50, -0.35), n_trait, 2L)
  }
  beta <- c(0.1, -0.2, 0.3)
  eta <- beta[as.integer(trait)] + rowSums(
    z[as.integer(site), , drop = FALSE] * Lambda[as.integer(trait), , drop = FALSE]
  )
  eps <- stats::rnorm(length(eta), sd = sqrt(psi[as.integer(trait)]))
  list(
    data = data.frame(site = site, trait = trait, y = eta + eps),
    Lambda = Lambda,
    psi = psi,
    G = tcrossprod(Lambda)
  )
}

.mspl_gauss_fit <- function(dat, q = 1L, estimator = "mspl") {
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = TRUE)",
    as.integer(q)
  ))
  suppressMessages(gllvmTMB(
    form,
    data = dat,
    family = stats::gaussian(link = "identity"),
    estimator = estimator,
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  ))
}

psi_from_fit <- function(fit) {
  ## Prefer free uniqueness sd_B / s_B; fall back to report slots.
  rep <- fit$report %||% list()
  cand <- list(rep$sd_B, rep$s_B, rep$psi_B)
  for (v in cand) {
    if (!is.null(v) && length(v) && all(is.finite(v))) return(as.numeric(v))
  }
  ## theta_diag_B is log-scale uniqueness in some harvests
  if (!is.null(rep$theta_diag_B) && length(rep$theta_diag_B)) {
    return(exp(as.numeric(rep$theta_diag_B)))
  }
  NA_real_
}

summarise_arm <- function(fit_or_err, elapsed, G_true, err_msg = NA_character_) {
  if (!is.null(err_msg) && !is.na(err_msg)) {
    return(list(
      estimator = NA_character_,
      convergence = NA_integer_,
      finite_par = FALSE,
      finite_obj = FALSE,
      objective = NA_real_,
      n_par = NA_integer_,
      registry_cell = NA_character_,
      registry_status = NA_character_,
      registry_evidence = NA_character_,
      max_abs_Lambda = NA_real_,
      min_psi = NA_real_,
      min_sd_B = NA_real_,
      rel_frob_vs_truth = NA_real_,
      Sigma_shared = NULL,
      Lambda = NULL,
      elapsed_s = unname(elapsed["elapsed"]),
      error = err_msg,
      class = NA_character_
    ))
  }
  fit <- fit_or_err
  conv <- fit$opt$convergence %||% NA_integer_
  par_ok <- isTRUE(all(is.finite(fit$opt$par)))
  obj_ok <- isTRUE(is.finite(fit$opt$objective))
  Lambda <- fit$report$Lambda_B
  if (is.null(Lambda)) {
    Lambda <- tryCatch(
      getLoadings(fit, level = "unit", rotate = "none"),
      error = function(e) NULL
    )
  }
  G_hat <- if (!is.null(Lambda)) tcrossprod(Lambda) else NULL
  Sigma_shared <- tryCatch(
    extract_Sigma(
      fit, level = "unit", part = "shared", link_residual = "none"
    )$Sigma,
    error = function(e) G_hat
  )
  psi <- psi_from_fit(fit)
  list(
    estimator = fit$estimator %||% NA_character_,
    convergence = as.integer(conv),
    finite_par = par_ok,
    finite_obj = obj_ok,
    objective = fit$opt$objective %||% NA_real_,
    n_par = length(fit$opt$par),
    registry_cell = fit$mspl$registry_cell %||% NA_character_,
    registry_status = fit$mspl$registry_status %||% NA_character_,
    registry_evidence = fit$mspl$registry_evidence %||% NA_character_,
    max_abs_Lambda = if (is.null(Lambda)) NA_real_ else max(abs(Lambda)),
    min_psi = if (length(psi) && all(is.finite(psi))) min(psi) else NA_real_,
    min_sd_B = if (length(psi) && all(is.finite(psi))) min(psi) else NA_real_,
    rel_frob_vs_truth = if (is.null(Sigma_shared)) NA_real_
      else rel_frob(Sigma_shared, G_true),
    Sigma_shared = Sigma_shared,
    Lambda = Lambda,
    elapsed_s = unname(elapsed["elapsed"]),
    error = NA_character_,
    class = paste(class(fit), collapse = "/")
  )
}

fit_one <- function(dat, q, estimator, G_true) {
  t0 <- proc.time()
  err <- NA_character_
  fit <- tryCatch(
    .mspl_gauss_fit(dat, q = q, estimator = estimator),
    error = function(e) {
      err <<- conditionMessage(e)
      NULL
    }
  )
  elapsed <- proc.time() - t0
  if (!is.null(err) && !is.na(err)) {
    return(summarise_arm(NULL, elapsed, G_true, err_msg = err))
  }
  summarise_arm(fit, elapsed, G_true)
}

row_from_arm <- function(cell, q, seed, arm_name, arm, pair_rel) {
  data.frame(
    cell = cell,
    q = as.integer(q),
    seed = as.integer(seed),
    arm = arm_name,
    conv = arm$convergence,
    finite = isTRUE(arm$finite_par) && isTRUE(arm$finite_obj),
    finite_obj = isTRUE(arm$finite_obj),
    error = arm$error %||% NA_character_,
    registry_cell = arm$registry_cell,
    registry_status = arm$registry_status,
    registry_evidence = arm$registry_evidence,
    rel_frob_vs_truth = arm$rel_frob_vs_truth,
    rel_frob_mspl_vs_ml = pair_rel,
    max_abs_Lambda = arm$max_abs_Lambda,
    min_psi = arm$min_psi,
    min_sd_B = arm$min_sd_B,
    wall_s = arm$elapsed_s,
    obj = arm$objective,
    stringsAsFactors = FALSE
  )
}

## ---- load package --------------------------------------------------------
cat("== load_all ==\n")
need_compile <- !file.exists(file.path(ROOT, "src", "gllvmTMB.so")) &&
  !file.exists(file.path(ROOT, "src", "gllvmTMB.dylib"))
## Prefer installed DLL via load_all(compile=FALSE); compile once if needed.
tryCatch(
  pkgload::load_all(ROOT, compile = FALSE, quiet = FALSE),
  error = function(e) {
    cat("load_all(compile=FALSE) failed:", conditionMessage(e), "\n")
    cat("Retrying with compile=TRUE once...\n")
    pkgload::load_all(ROOT, compile = TRUE, quiet = FALSE)
  }
)
cat("gllvmTMB version:", as.character(utils::packageVersion("gllvmTMB")), "\n")
cat("ROOT:", ROOT, "\n")

## Grid: healthy + near-Heywood × q∈{1,2} × 8 seeds × 2 arms
SEEDS <- as.integer(c(160801L, 160802L, 160803L, 160804L, 160805L,
                      160806L, 160807L, 160808L))
CELLS <- list(
  list(name = "healthy", psi = c(0.55, 0.70, 0.40)),
  list(name = "near_heywood", psi = c(0.02, 0.55, 0.60))
)
QS <- c(1L, 2L)

rows <- list()
pair_store <- list()
n_done <- 0L
t_grid0 <- proc.time()[["elapsed"]]

for (cell in CELLS) {
  for (q in QS) {
    for (seed in SEEDS) {
      label <- sprintf("%s q=%d seed=%d", cell$name, q, seed)
      cat("\n====", label, "====\n")
      fx <- .mspl_gauss_fixture(
        n_site = 40L, q = q, psi = cell$psi, seed = seed
      )
      dat <- fx$data
      G_true <- fx$G

      cat("  ML...\n")
      ml <- fit_one(dat, q, "ml", G_true)
      cat(sprintf(
        "  ML wall=%.2fs conv=%s finite=%s max|L|=%s min_psi=%s relF=%s err=%s\n",
        ml$elapsed_s, ml$convergence,
        ml$finite_par && ml$finite_obj,
        format(ml$max_abs_Lambda, digits = 4),
        format(ml$min_psi, digits = 4),
        format(ml$rel_frob_vs_truth, digits = 4),
        ml$error %||% ""
      ))
      if (isTRUE(ml$elapsed_s > HARD_STOP_S)) {
        stop(sprintf("HARD STOP: ML fit wall %.1fs > 30 min (%s)",
                     ml$elapsed_s, label))
      }

      cat("  MSPL...\n")
      mspl <- fit_one(dat, q, "mspl", G_true)
      cat(sprintf(
        "  MSPL wall=%.2fs conv=%s finite=%s max|L|=%s min_psi=%s relF=%s reg=%s/%s err=%s\n",
        mspl$elapsed_s, mspl$convergence,
        mspl$finite_par && mspl$finite_obj,
        format(mspl$max_abs_Lambda, digits = 4),
        format(mspl$min_psi, digits = 4),
        format(mspl$rel_frob_vs_truth, digits = 4),
        mspl$registry_status %||% "",
        mspl$registry_evidence %||% "",
        mspl$error %||% ""
      ))
      if (isTRUE(mspl$elapsed_s > HARD_STOP_S)) {
        stop(sprintf("HARD STOP: MSPL fit wall %.1fs > 30 min (%s)",
                     mspl$elapsed_s, label))
      }

      pair_rel <- if (is.null(ml$Sigma_shared) || is.null(mspl$Sigma_shared)) {
        NA_real_
      } else {
        rel_frob(mspl$Sigma_shared, ml$Sigma_shared)
      }

      rows[[length(rows) + 1L]] <- row_from_arm(
        cell$name, q, seed, "ML", ml, pair_rel
      )
      rows[[length(rows) + 1L]] <- row_from_arm(
        cell$name, q, seed, "MSPL", mspl, pair_rel
      )
      pair_store[[label]] <- list(ml = ml, mspl = mspl, G_true = G_true,
                                  pair_rel = pair_rel, psi_dgp = cell$psi)
      n_done <- n_done + 2L
    }
  }
}

tab <- do.call(rbind, rows)
rownames(tab) <- NULL

dir.create(dirname(OUT_TSV), recursive = TRUE, showWarnings = FALSE)
utils::write.table(tab, OUT_TSV, sep = "\t", row.names = FALSE, quote = FALSE)
saveRDS(
  list(table = tab, pairs = pair_store, seeds = SEEDS, hard_stop_s = HARD_STOP_S),
  OUT_RDS
)

## ---- failure-inclusive summary -------------------------------------------
cat("\n======== FAILURE-INCLUSIVE SUMMARY ========\n")
cat("N_arm_rows =", nrow(tab), "(must equal 4 cells ×", length(SEEDS),
    "seeds × 2 arms =", 4L * length(SEEDS) * 2L, ")\n")
cat("grid wall_s =", round(proc.time()[["elapsed"]] - t_grid0, 1), "\n")

agg <- function(df) {
  n <- nrow(df)
  n_conv0 <- sum(df$conv == 0L, na.rm = TRUE)
  n_finite <- sum(df$finite, na.rm = TRUE)
  n_err <- sum(!is.na(df$error) & nzchar(df$error), na.rm = TRUE)
  med <- function(x) stats::median(x[is.finite(x)], na.rm = TRUE)
  data.frame(
    n = n,
    n_conv0 = n_conv0,
    n_finite = n_finite,
    n_err = n_err,
    med_rel_frob_vs_truth = med(df$rel_frob_vs_truth),
    med_max_abs_Lambda = med(df$max_abs_Lambda),
    med_min_psi = med(df$min_psi),
    med_wall_s = med(df$wall_s),
    stringsAsFactors = FALSE
  )
}

for (cn in unique(tab$cell)) {
  for (qq in unique(tab$q)) {
    sub <- tab[tab$cell == cn & tab$q == qq, , drop = FALSE]
    cat(sprintf("\n-- %s q=%d (N=%d arm-rows) --\n", cn, qq, nrow(sub)))
    for (arm in c("ML", "MSPL")) {
      a <- agg(sub[sub$arm == arm, , drop = FALSE])
      cat(sprintf(
        "  %-4s N=%d conv0=%d finite=%d err=%d | med relF=%.4f max|L|=%.4f minψ=%.4f wall=%.2fs\n",
        arm, a$n, a$n_conv0, a$n_finite, a$n_err,
        a$med_rel_frob_vs_truth, a$med_max_abs_Lambda,
        a$med_min_psi, a$med_wall_s
      ))
    }
    ## pair disagreement on seeds where both finite
    both <- merge(
      sub[sub$arm == "ML", c("seed", "finite", "rel_frob_vs_truth")],
      sub[sub$arm == "MSPL", c("seed", "finite", "rel_frob_vs_truth",
                               "rel_frob_mspl_vs_ml")],
      by = "seed", suffixes = c("_ml", "_mspl")
    )
    ok <- both$finite_ml & both$finite_mspl
    cat(sprintf(
      "  paired finite seeds: %d/%d; med pair relF(MSPL vs ML)=%.4f; MSPL closer to G on %d/%d\n",
      sum(ok), nrow(both),
      stats::median(both$rel_frob_mspl_vs_ml[ok], na.rm = TRUE),
      sum(ok & both$rel_frob_vs_truth_mspl < both$rel_frob_vs_truth_ml, na.rm = TRUE),
      sum(ok)
    ))
  }
}

cat("\nwrote", OUT_TSV, "\n")
cat("wrote", OUT_RDS, "\n")
cat("DONE\n")
