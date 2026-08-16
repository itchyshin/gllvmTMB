## Local multi-seed Poisson LA-ML vs LA-MSPL POINT smoke (Curie).
## Failure-inclusive denominators. se = FALSE. No SE / sandwich / intervals.
## Registry must stay planned. Do not flip admitted. No Totoro.
##
## Recipe mirrors tests/testthat/test-mspl-poisson-public-door.R
## (ordinary latent, unique = FALSE, poisson log) with a known-DGP
## fixture sized like the Gaussian point grid.
##
## Usage:
##   OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
##     dev/mspl-poisson-multiseed-point-smoke.R
##
## Outputs (repo-relative when run from worktree root):
##   docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.tsv
##   /tmp/mspl-poisson-multiseed-point-smoke.rds
##
## Grid default: {healthy, sparse} × q ∈ {1,2} × 8 seeds × 2 arms = 64.
## If the first pair projects >20 min, drop q=2; if still too slow,
## keep 8 seeds on healthy q=1 only. Never below 8 seeds.

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
  ROOT, "docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.tsv"
)
OUT_RDS <- "/tmp/mspl-poisson-multiseed-point-smoke.rds"
HARD_STOP_S <- 30 * 60
RUNAWAY_ABS_LAMBDA <- 15

## ---- fixture (Poisson analogue of the Gaussian ordinary DGP) ------------
.mspl_pois_fixture <- function(n_site = 24L, q = 1L, beta = NULL, seed = 160901L) {
  set.seed(as.integer(seed) + as.integer(q))
  n_trait <- 3L
  if (is.null(beta)) beta <- c(0.40, 0.10, 0.60)
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
  eta <- beta[as.integer(trait)] + rowSums(
    z[as.integer(site), , drop = FALSE] * Lambda[as.integer(trait), , drop = FALSE]
  )
  mu <- exp(eta)
  y <- stats::rpois(length(mu), lambda = mu)
  list(
    data = data.frame(site = site, trait = trait, y = y),
    Lambda = Lambda,
    beta = beta,
    G = tcrossprod(Lambda),
    mu = mu,
    mean_y = mean(y),
    zero_frac = mean(y == 0),
    trait_zero = as.numeric(tapply(y, trait, function(v) mean(v == 0)))
  )
}

.mspl_pois_fit <- function(dat, q = 1L, estimator = "mspl") {
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)",
    as.integer(q)
  ))
  suppressMessages(gllvmTMB(
    form,
    data = dat,
    family = stats::poisson(link = "log"),
    estimator = estimator,
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  ))
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
      min_beta = NA_real_,
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
  b_fix <- tryCatch(as.numeric(fit$opt$par[names(fit$opt$par) == "b_fix"]),
                    error = function(e) NA_real_)
  if (!length(b_fix) || !all(is.finite(b_fix))) {
    b_fix <- tryCatch(as.numeric(fit$report$b), error = function(e) NA_real_)
  }
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
    min_beta = if (length(b_fix) && all(is.finite(b_fix))) min(b_fix) else NA_real_,
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
    .mspl_pois_fit(dat, q = q, estimator = estimator),
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

row_from_arm <- function(cell, q, seed, arm_name, arm, pair_rel, dgp) {
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
    min_beta = arm$min_beta,
    dgp_mean_y = dgp$mean_y,
    dgp_zero_frac = dgp$zero_frac,
    wall_s = arm$elapsed_s,
    obj = arm$objective,
    stringsAsFactors = FALSE
  )
}

## ---- load package --------------------------------------------------------
cat("== load_all ==\n")
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
cat("OMP_NUM_THREADS:", Sys.getenv("OMP_NUM_THREADS"), "\n")

## Grid: healthy + sparse × q∈{1,2} × 8 seeds × 2 arms
SEEDS <- as.integer(c(160901L, 160902L, 160903L, 160904L, 160905L,
                      160906L, 160907L, 160908L))
CELLS <- list(
  list(name = "healthy", beta = c(0.40, 0.10, 0.60)),
  list(name = "sparse", beta = c(-1.80, -1.20, -2.00))
)
QS <- c(1L, 2L)

## Timing probe: one healthy q=1 pair, then maybe shrink q or cells.
cat("\n==== timing probe: healthy q=1 seed=", SEEDS[[1L]], "====\n")
probe_fx <- .mspl_pois_fixture(
  n_site = 24L, q = 1L, beta = CELLS[[1L]]$beta, seed = SEEDS[[1L]]
)
cat(sprintf(
  "  DGP mean_y=%.3f zero_frac=%.3f trait_zero=%s\n",
  probe_fx$mean_y, probe_fx$zero_frac,
  paste(sprintf("%.2f", probe_fx$trait_zero), collapse = ",")
))
t_probe0 <- proc.time()[["elapsed"]]
probe_ml <- fit_one(probe_fx$data, 1L, "ml", probe_fx$G)
probe_mspl <- fit_one(probe_fx$data, 1L, "mspl", probe_fx$G)
probe_s <- proc.time()[["elapsed"]] - t_probe0
cat(sprintf(
  "  probe pair wall=%.2fs | ML conv=%s finite=%s relF=%s err=%s\n",
  probe_s, probe_ml$convergence,
  probe_ml$finite_par && probe_ml$finite_obj,
  format(probe_ml$rel_frob_vs_truth, digits = 4),
  probe_ml$error %||% ""
))
cat(sprintf(
  "  MSPL conv=%s finite=%s relF=%s reg=%s/%s/%s err=%s\n",
  probe_mspl$convergence,
  probe_mspl$finite_par && probe_mspl$finite_obj,
  format(probe_mspl$rel_frob_vs_truth, digits = 4),
  probe_mspl$registry_cell %||% "",
  probe_mspl$registry_status %||% "",
  probe_mspl$registry_evidence %||% "",
  probe_mspl$error %||% ""
))

n_pair_full <- length(CELLS) * length(QS) * length(SEEDS)
est_full <- probe_s * n_pair_full
cat(sprintf(
  "  projected full grid (32 pairs / 64 arms) ≈ %.1f min\n",
  est_full / 60
))

grid_note <- "full 64-arm grid (2 cells × 2 q × 8 seeds × 2 arms)"
if (isTRUE(est_full > 20 * 60)) {
  QS <- 1L
  n_pair <- length(CELLS) * length(QS) * length(SEEDS)
  est2 <- probe_s * n_pair
  grid_note <- "shrunk to q=1 only (2 cells × 8 seeds × 2 arms = 32)"
  cat("  SHRINK: drop q=2; projected ≈", round(est2 / 60, 1), "min\n")
  if (isTRUE(est2 > 20 * 60)) {
    CELLS <- CELLS[1L]
    grid_note <- "shrunk to healthy q=1 × 8 seeds × 2 arms = 16"
    cat("  SHRINK: drop sparse; keep ≥8 seeds on healthy q=1\n")
  }
}
cat("  GRID:", grid_note, "\n")

rows <- list()
pair_store <- list()
n_done <- 0L
t_grid0 <- proc.time()[["elapsed"]]

## Re-use the probe pair so the first cell is not fitted twice.
reuse_probe <- isTRUE(CELLS[[1L]]$name == "healthy") && isTRUE(QS[[1L]] == 1L)

for (cell in CELLS) {
  for (q in QS) {
    for (seed in SEEDS) {
      label <- sprintf("%s q=%d seed=%d", cell$name, q, seed)
      cat("\n====", label, "====\n")
      if (reuse_probe && identical(cell$name, "healthy") &&
          identical(as.integer(q), 1L) && identical(as.integer(seed), SEEDS[[1L]])) {
        fx <- probe_fx
        ml <- probe_ml
        mspl <- probe_mspl
        cat("  (reusing timing-probe pair)\n")
      } else {
        fx <- .mspl_pois_fixture(
          n_site = 24L, q = q, beta = cell$beta, seed = seed
        )
        cat(sprintf(
          "  DGP mean_y=%.3f zero_frac=%.3f\n", fx$mean_y, fx$zero_frac
        ))
        cat("  ML...\n")
        ml <- fit_one(fx$data, q, "ml", fx$G)
        cat("  MSPL...\n")
        mspl <- fit_one(fx$data, q, "mspl", fx$G)
      }
      cat(sprintf(
        "  ML   wall=%.2fs conv=%s finite=%s max|L|=%s minb=%s relF=%s err=%s\n",
        ml$elapsed_s, ml$convergence,
        ml$finite_par && ml$finite_obj,
        format(ml$max_abs_Lambda, digits = 4),
        format(ml$min_beta, digits = 4),
        format(ml$rel_frob_vs_truth, digits = 4),
        ml$error %||% ""
      ))
      cat(sprintf(
        "  MSPL wall=%.2fs conv=%s finite=%s max|L|=%s minb=%s relF=%s reg=%s/%s err=%s\n",
        mspl$elapsed_s, mspl$convergence,
        mspl$finite_par && mspl$finite_obj,
        format(mspl$max_abs_Lambda, digits = 4),
        format(mspl$min_beta, digits = 4),
        format(mspl$rel_frob_vs_truth, digits = 4),
        mspl$registry_status %||% "",
        mspl$registry_evidence %||% "",
        mspl$error %||% ""
      ))
      if (isTRUE(ml$elapsed_s > HARD_STOP_S) || isTRUE(mspl$elapsed_s > HARD_STOP_S)) {
        stop(sprintf("HARD STOP: fit wall > 30 min (%s)", label))
      }
      if ((proc.time()[["elapsed"]] - t_grid0) > HARD_STOP_S) {
        stop(sprintf("HARD STOP: grid wall > 30 min after %s", label))
      }

      pair_rel <- if (is.null(ml$Sigma_shared) || is.null(mspl$Sigma_shared)) {
        NA_real_
      } else {
        rel_frob(mspl$Sigma_shared, ml$Sigma_shared)
      }

      rows[[length(rows) + 1L]] <- row_from_arm(
        cell$name, q, seed, "ML", ml, pair_rel, fx
      )
      rows[[length(rows) + 1L]] <- row_from_arm(
        cell$name, q, seed, "MSPL", mspl, pair_rel, fx
      )
      pair_store[[label]] <- list(ml = ml, mspl = mspl, G_true = fx$G,
                                  pair_rel = pair_rel, beta_dgp = cell$beta,
                                  dgp = fx[c("mean_y", "zero_frac", "trait_zero")])
      n_done <- n_done + 2L
    }
  }
}

tab <- do.call(rbind, rows)
rownames(tab) <- NULL

dir.create(dirname(OUT_TSV), recursive = TRUE, showWarnings = FALSE)
utils::write.table(tab, OUT_TSV, sep = "\t", row.names = FALSE, quote = FALSE)
saveRDS(
  list(
    table = tab, pairs = pair_store, seeds = SEEDS,
    cells = vapply(CELLS, `[[`, "", "name"),
    qs = QS, grid_note = grid_note, hard_stop_s = HARD_STOP_S,
    probe_s = probe_s
  ),
  OUT_RDS
)

## ---- failure-inclusive summary -------------------------------------------
cat("\n======== FAILURE-INCLUSIVE SUMMARY ========\n")
cat("N_arm_rows =", nrow(tab), "\n")
cat("grid wall_s =", round(proc.time()[["elapsed"]] - t_grid0, 1), "\n")
cat("grid:", grid_note, "\n")
cat("n_seeds =", length(SEEDS), "\n")

agg <- function(df) {
  n <- nrow(df)
  n_conv0 <- sum(df$conv == 0L, na.rm = TRUE)
  n_finite <- sum(df$finite, na.rm = TRUE)
  n_err <- sum(!is.na(df$error) & nzchar(df$error), na.rm = TRUE)
  n_runaway <- sum(is.finite(df$max_abs_Lambda) &
                     df$max_abs_Lambda >= RUNAWAY_ABS_LAMBDA, na.rm = TRUE)
  med <- function(x) stats::median(x[is.finite(x)], na.rm = TRUE)
  data.frame(
    n = n,
    n_conv0 = n_conv0,
    n_finite = n_finite,
    n_err = n_err,
    n_runaway = n_runaway,
    med_rel_frob_vs_truth = med(df$rel_frob_vs_truth),
    med_max_abs_Lambda = med(df$max_abs_Lambda),
    med_min_beta = med(df$min_beta),
    med_wall_s = med(df$wall_s),
    stringsAsFactors = FALSE
  )
}

for (cn in unique(tab$cell)) {
  for (qq in unique(tab$q)) {
    sub <- tab[tab$cell == cn & tab$q == qq, , drop = FALSE]
    if (!nrow(sub)) next
    cat(sprintf("\n-- %s q=%d (N=%d arm-rows) --\n", cn, qq, nrow(sub)))
    for (arm in c("ML", "MSPL")) {
      a <- agg(sub[sub$arm == arm, , drop = FALSE])
      cat(sprintf(
        "  %-4s N=%d conv0=%d finite=%d err=%d runaway=%d | med relF=%.4f max|L|=%.4f minb=%.4f wall=%.2fs\n",
        arm, a$n, a$n_conv0, a$n_finite, a$n_err, a$n_runaway,
        a$med_rel_frob_vs_truth, a$med_max_abs_Lambda,
        a$med_min_beta, a$med_wall_s
      ))
    }
    both <- merge(
      sub[sub$arm == "ML", c("seed", "finite", "rel_frob_vs_truth")],
      sub[sub$arm == "MSPL", c("seed", "finite", "rel_frob_vs_truth",
                               "rel_frob_mspl_vs_ml", "registry_status")],
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

mspl_tab <- tab[tab$arm == "MSPL", , drop = FALSE]
ml_tab <- tab[tab$arm == "ML", , drop = FALSE]
n_seeds <- length(unique(tab$seed))
n_mspl <- nrow(mspl_tab)
n_mspl_ok <- sum(mspl_tab$conv == 0L & mspl_tab$finite, na.rm = TRUE)
n_mspl_err <- sum(!is.na(mspl_tab$error) & nzchar(mspl_tab$error), na.rm = TRUE)
n_mspl_run <- sum(is.finite(mspl_tab$max_abs_Lambda) &
                    mspl_tab$max_abs_Lambda >= RUNAWAY_ABS_LAMBDA, na.rm = TRUE)
n_planned <- sum(mspl_tab$registry_status == "planned", na.rm = TRUE)
n_admitted <- sum(mspl_tab$registry_status == "admitted", na.rm = TRUE)

healthy <- tab[tab$cell == "healthy", , drop = FALSE]
healthy_mspl_closer <- NA_integer_
healthy_n_ok <- NA_integer_
if (nrow(healthy)) {
  both_h <- merge(
    healthy[healthy$arm == "ML", c("q", "seed", "finite", "rel_frob_vs_truth")],
    healthy[healthy$arm == "MSPL", c("q", "seed", "finite", "rel_frob_vs_truth")],
    by = c("q", "seed"), suffixes = c("_ml", "_mspl")
  )
  ok_h <- both_h$finite_ml & both_h$finite_mspl
  healthy_n_ok <- sum(ok_h)
  healthy_mspl_closer <- sum(
    ok_h & both_h$rel_frob_vs_truth_mspl < both_h$rel_frob_vs_truth_ml,
    na.rm = TRUE
  )
}

## Operational smoke: the grid ran and MSPL points are finite/stationary.
op_pass <- isTRUE(n_seeds >= 8L) &&
  isTRUE(n_mspl_err == 0L) &&
  isTRUE(n_mspl_ok == n_mspl) &&
  isTRUE(n_mspl_run == 0L) &&
  isTRUE(n_planned == n_mspl) &&
  isTRUE(n_admitted == 0L)

## Admit-evidence bar (programme Phase 4 exit + §8). Finite fits alone
## do not pass. Rate c=1 is unpinned; Poisson loading atom is OPEN;
## Shinichi gate is required. This smoke can only FAIL that packet.
admit_pass <- FALSE
admit_why <- paste(
  "FAIL for admit evidence: Phase 4 exit requires family-specific",
  "TMB oracles, healthy+boundary recovery, prediction, and penalty",
  "sensitivity; finite count fits alone do not pass. Rate c=1 is",
  "unpinned; Poisson loading atom under Laplace is OPEN; Shinichi",
  "gate has not flipped planned -> admitted. This note does not",
  "flip the registry."
)

cat("\n======== VERDICT ========\n")
cat("n_seeds =", n_seeds, "\n")
cat("n_arm_rows =", nrow(tab), "\n")
cat("n_mspl =", n_mspl, " conv0+finite =", n_mspl_ok, " err =", n_mspl_err,
    " runaway =", n_mspl_run, "\n")
cat("registry planned/admitted =", n_planned, "/", n_admitted, "\n")
cat("healthy MSPL closer to G =", healthy_mspl_closer, "/", healthy_n_ok, "\n")
cat("OPERATIONAL_SMOKE:", if (op_pass) "PASS" else "FAIL", "\n")
cat("ADMIT_EVIDENCE:", if (admit_pass) "PASS" else "FAIL", "\n")
cat(admit_why, "\n")

cat("\nwrote", OUT_TSV, "\n")
cat("wrote", OUT_RDS, "\n")
cat("DONE\n")
