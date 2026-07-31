## ADVERSARIAL #856 -- A4
##  (a) ITEM 4: seed sweep -- how OFTEN does a per-trait sigma_eps collapse to
##      the zero boundary on the ORIGINAL one-row-per-cell design, and does
##      check_gllvmTMB() catch it?
##  (b) D3: is sigma_eps[2] the RESIDUAL sd or the TOTAL sd (sd_B collapsed)?
##  (c) ITEM 1 residue: WIDE-format fits through predict()/simulate().
## Run in both builds; argv[1] is the label.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
LABEL <- (commandArgs(trailingOnly = TRUE)[1] %||% "FIXED")
cat("################ BUILD:", LABEL, "################\n\n")

## ---------- (a) seed sweep on the ORIGINAL fixture ----------------------
cat("===== (a) ITEM 4 seed sweep: original 1-row-per-cell make_gauss() =====\n")
cat("n_sites=30, n_species=1, mean_species_per_site=1, 4 gaussian traits,\n")
cat("fit = latent(0+trait|site, d=1, unique=FALSE); simulator sd_eps = 0.707\n\n")
n_collapse <- 0L; n_ok <- 0L; n_err <- 0L; rows <- list()
for (sd_ in 1:20) {
  set.seed(sd_)
  sim <- try(gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2), psi_B = rep(0.2, 4),
    seed = sd_), silent = TRUE)
  if (inherits(sim, "try-error")) { n_err <- n_err + 1L; next }
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, silent = TRUE))), error = function(e) e)
  if (inherits(fit, "error")) { n_err <- n_err + 1L; next }
  se <- as.numeric(fit$report$sigma_eps)
  pd <- tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA)
  collapsed <- any(se < 0.05)          # 14x below the true 0.707
  if (collapsed) n_collapse <- n_collapse + 1L else n_ok <- n_ok + 1L
  ck_status <- NA_character_
  if (collapsed) {
    ck <- tryCatch(check_gllvmTMB(fit), error = function(e) NULL)
    if (!is.null(ck)) {
      sub <- ck[grepl("^boundary_sigma_eps", ck$component), c("component", "status", "value")]
      ck_status <- paste(paste0(sub$component, "=", sub$status, "(", sub$value, ")"),
                         collapse = " | ")
    }
  }
  rows[[length(rows) + 1L]] <- data.frame(
    seed = sd_, conv = fit$opt$convergence, pdHess = pd,
    min_sigma_eps = signif(min(se), 4),
    collapsed = collapsed,
    sigma_eps = paste(signif(se, 3), collapse = "/"),
    stringsAsFactors = FALSE)
  if (collapsed) cat("  seed ", sd_, " COLLAPSE: sigma_eps=",
                     paste(signif(se, 4), collapse = ", "),
                     "  conv=", fit$opt$convergence, " pdHess=", pd,
                     "\n    check_gllvmTMB rows: ", ck_status, "\n", sep = "")
}
res <- do.call(rbind, rows)
print(res, row.names = FALSE)
cat("\nCOLLAPSE RATE: ", n_collapse, "/", n_collapse + n_ok,
    "   errors: ", n_err, "\n", sep = "")

## ---------- (b) D3: residual sd or total sd? ---------------------------
cat("\n===== (b) D3: is sigma_eps[2] the residual sd (2.0) or the TOTAL (2.236)? =====\n")
set.seed(103)
n_unit <- 120L
u <- matrix(rnorm(n_unit * 2, 0, 1), n_unit, 2)
d3 <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  rbind(data.frame(unit = i, trait = "t1", value = u[i, 1] + rnorm(4, 0, 0.5)),
        data.frame(unit = i, trait = "t2",
                   value = u[i, 2] + rnorm(if (i == 1L) 2L else 1L, 0, 2.0)))
}))
d3$unit <- factor(d3$unit); d3$trait <- factor(d3$trait)
fit3 <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = d3, unit = "unit", trait = "trait"))), error = function(e) e)
if (!inherits(fit3, "error")) {
  cat("sigma_eps : ", paste(signif(as.numeric(fit3$report$sigma_eps), 5), collapse = ", "),
      "   TRUE 0.5, 2.0\n", sep = "")
  cat("sd_B      : ", paste(signif(as.numeric(fit3$report$sd_B %||% NA), 5), collapse = ", "),
      "   TRUE 1.0, 1.0\n", sep = "")
  cat("implied total sd trait2 = sqrt(sd_B[2]^2 + sigma_eps[2]^2) = ",
      signif(sqrt(sum(c(as.numeric(fit3$report$sd_B %||% 0)[2],
                        as.numeric(fit3$report$sigma_eps)[min(2, length(fit3$report$sigma_eps))])^2)), 5),
      "   TRUE total = ", signif(sqrt(1 + 4), 5), "\n", sep = "")
  ck3 <- tryCatch(check_gllvmTMB(fit3), error = function(e) NULL)
  if (!is.null(ck3)) {
    print(ck3[grepl("sigma_eps|boundary|pd_hessian", ck3$component),
              c("component", "status", "value")], row.names = FALSE)
  }
}

## ---------- (c) ITEM 1 residue: WIDE-format fits -----------------------
cat("\n===== (c) ITEM 1: WIDE-format traits() fit through predict/simulate =====\n")
set.seed(555)
nu <- 100L
wide <- data.frame(unit = factor(seq_len(nu)))
bu <- rnorm(nu, 0, 1)
wide$y1 <- 2 + bu + rnorm(nu, 0, 0.1)
wide$y2 <- 5 + bu + rnorm(nu, 0, 4.0)     # 40x larger residual sd
fitw <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
  traits(y1, y2) ~ 1 + latent(1 | unit, d = 1, unique = FALSE),
  data = wide, unit = "unit"))), error = function(e) e)
if (inherits(fitw, "error")) {
  cat("wide fit ERROR: ", conditionMessage(fitw), "\n", sep = "")
} else {
  cat("wide fit conv=", fitw$opt$convergence,
      " sigma_eps=", paste(signif(as.numeric(fitw$report$sigma_eps), 5), collapse = ", "),
      " (TRUE 0.1, 4.0)\n", sep = "")
  cat("object$trait_col = ", fitw$trait_col %||% "NULL",
      " ; names(object$data): ", paste(utils::head(names(fitw$data), 8), collapse = ", "), "\n", sep = "")
  ## Can the user pass WIDE newdata (no trait column)?
  p_wide <- tryCatch(predict(fitw, newdata = wide, type = "response"),
                     error = function(e) e)
  cat("predict(newdata = WIDE frame): ",
      if (inherits(p_wide, "error")) paste("ERROR --", conditionMessage(p_wide)) else
        paste("returned", nrow(p_wide), "rows; trait col present:",
              (fitw$trait_col %||% "trait") %in% names(p_wide)), "\n", sep = "")
  s_wide <- tryCatch(suppressWarnings(suppressMessages(
    simulate(fitw, nsim = 50L, seed = 3L, newdata = wide))), error = function(e) e)
  cat("simulate(newdata = WIDE frame): ",
      if (inherits(s_wide, "error")) paste("ERROR --", conditionMessage(s_wide)) else
        paste("returned", nrow(s_wide), "x", ncol(s_wide)), "\n", sep = "")
  ## Long newdata built from the fit's own stored (pivoted) data
  ndl <- fitw$data
  p_long <- tryCatch(predict(fitw, newdata = ndl, type = "response"),
                     error = function(e) e)
  cat("predict(newdata = fit$data i.e. LONG): ",
      if (inherits(p_long, "error")) paste("ERROR --", conditionMessage(p_long)) else
        paste("OK,", nrow(p_long), "rows"), "\n", sep = "")
  s_long <- tryCatch(suppressWarnings(suppressMessages(
    simulate(fitw, nsim = 300L, seed = 4L, newdata = ndl))), error = function(e) e)
  if (!inherits(s_long, "error")) {
    tr <- fitw$data[[fitw$trait_col]]
    sdt <- vapply(split(seq_len(nrow(s_long)), tr), function(r)
      mean(apply(s_long[r, , drop = FALSE], 2L, sd)), numeric(1))
    cat("simulate(newdata=LONG) sd by trait: ", paste(signif(sdt, 4), collapse = ", "),
        "  (per-trait sigma_eps = ", paste(signif(as.numeric(fitw$report$sigma_eps), 4), collapse = ", "),
        "; broadcast would give both = ", signif(as.numeric(fitw$report$sigma_eps)[1], 4), ")\n", sep = "")
  } else {
    cat("simulate(newdata=LONG) ERROR: ", conditionMessage(s_long), "\n", sep = "")
  }
}
