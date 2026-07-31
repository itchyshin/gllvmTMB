## ADVERSARIAL #856 -- ITEM 4 (verify the Root-Cause-C "fixture artefact"
## verdict) + ITEM 7 (is the flat-direction case NO WORSE?) + the D3 SE check
## + does a bogus sigma_eps leak onto user-facing surfaces?
##
## Runs identically under the FIXED build and the PRE-FIX build so the two can
## be diffed. Pass the build label as argv[1].

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
LABEL <- (commandArgs(trailingOnly = TRUE)[1] %||% "FIXED")
cat("################ BUILD:", LABEL, "################\n\n")

pd_of <- function(fit) tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA)
se_of <- function(fit) as.numeric(fit$report$sigma_eps)

## ======================= ITEM 4: ROOT CAUSE C ==========================
## EXACT original fixture: make_gauss() BEFORE the #856 fixture change --
## n_species = 1, mean_species_per_site = 1 (ONE row per (site, trait)),
## 4 traits, rank-1 loadings-only latent().
cat("===== ITEM 4: the ORIGINAL make_gauss() fixture (1 row per cell) =====\n")
make_gauss_ORIGINAL <- function(seed = 1L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2),
    psi_B = rep(0.2, 4),
    seed = seed
  )
  sim$data
}
for (sd_ in 1:3) {
  df <- make_gauss_ORIGINAL(seed = sd_)
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = df, silent = TRUE
  ))), error = function(e) e)
  if (inherits(fit, "error")) {
    cat("seed", sd_, ": ERROR", conditionMessage(fit), "\n"); next
  }
  cat("seed ", sd_, ": conv=", fit$opt$convergence,
      " pdHess=", pd_of(fit),
      " sigma_eps=", paste(signif(se_of(fit), 4), collapse = ", "),
      "  (simulator sigma2_eps default 0.5 -> sd ", signif(sqrt(0.5), 4), ")\n", sep = "")
}

cat("\n----- same fixture, ONE row per cell but MORE SITES (n=60,120) -----\n")
for (ns in c(60L, 120L)) {
  set.seed(1L)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = ns, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2), psi_B = rep(0.2, 4), seed = 1L)
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, silent = TRUE))), error = function(e) e)
  if (inherits(fit, "error")) { cat("n_sites", ns, ": ERROR\n"); next }
  cat("n_sites ", ns, ": conv=", fit$opt$convergence, " pdHess=", pd_of(fit),
      " sigma_eps=", paste(signif(se_of(fit), 4), collapse = ", "), "\n", sep = "")
}

cat("\n----- the SHIPPED fixture (10 species/site) for comparison -----\n")
for (sd_ in 1:3) {
  set.seed(sd_)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 10, n_traits = 4, mean_species_per_site = 10,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2), psi_B = rep(0.2, 4), seed = sd_)
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, silent = TRUE))), error = function(e) e)
  if (inherits(fit, "error")) { cat("seed", sd_, ": ERROR\n"); next }
  cat("seed ", sd_, ": conv=", fit$opt$convergence, " pdHess=", pd_of(fit),
      " sigma_eps=", paste(signif(se_of(fit), 4), collapse = ", "), "\n", sep = "")
}

## ======================= ITEM 7: the flat direction ====================
cat("\n===== ITEM 7: a trait with NO gaussian/lognormal rows =====\n")
set.seed(108)
n_unit <- 120L; nt <- 2L
u <- matrix(rnorm(n_unit * nt, 0, 1), n_unit, nt)
d8 <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  do.call(rbind, lapply(seq_len(nt), function(t) {
    data.frame(unit = i, trait = paste0("t", t),
               value = u[i, t] + rnorm(3L, 0, c(0.5, 1.0)[t]))
  }))
}))
d8$unit <- factor(d8$unit); d8$trait <- factor(d8$trait)
d8$family <- factor(ifelse(d8$trait == "t1", "g", "p"), levels = c("g", "p"))
set.seed(9); d8$value[d8$family == "p"] <- rpois(sum(d8$family == "p"), lambda = 3)
fl <- list(gaussian(), poisson()); attr(fl, "family_var") <- "family"
fit8 <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = d8, unit = "unit", trait = "trait", family = fl))), error = function(e) e)
if (inherits(fit8, "error")) {
  cat("ERROR:", conditionMessage(fit8), "\n")
} else {
  cat("conv=", fit8$opt$convergence, " pdHess=", pd_of(fit8),
      "\nsigma_eps = ", paste(signif(se_of(fit8), 6), collapse = ", "),
      "  (trait 2 is POISSON: it has NO fid 0/3 rows)\n", sep = "")
  m8 <- fit8$tmb_obj$env$map$log_sigma_eps
  cat("map$log_sigma_eps: ",
      if (is.null(m8)) "ABSENT (BOTH free)" else paste(as.character(m8), collapse = ", "), "\n", sep = "")
  ## Is the poisson trait's log_sigma_eps direction EXACTLY flat?
  par <- fit8$tmb_obj$env$last.par.best
  fx <- fit8$tmb_obj$env$lfixed()
  gr <- tryCatch(fit8$tmb_obj$gr(par[fx]), error = function(e) NA)
  nmf <- names(par[fx])
  idx <- which(nmf == "log_sigma_eps")
  cat("gradient at log_sigma_eps entries: ",
      paste(signif(as.numeric(gr)[idx], 3), collapse = ", "), "\n", sep = "")
  h <- tryCatch(fit8$tmb_obj$he(par[fx]), error = function(e) NULL)
  if (!is.null(h)) {
    cat("Hessian diagonal at log_sigma_eps entries: ",
        paste(signif(diag(h)[idx], 4), collapse = ", "), "\n", sep = "")
    cat("min eigenvalue of the fixed-effect Hessian: ",
        signif(min(eigen(h, symmetric = TRUE, only.values = TRUE)$values), 4), "\n", sep = "")
  }
  cat("\n-- does the bogus value LEAK to public surfaces? --\n")
  ck <- tryCatch(check_gllvmTMB(fit8), error = function(e) NULL)
  if (!is.null(ck)) {
    sub <- ck[grepl("sigma_eps|pd_hessian|hessian_rank|sdreport", ck$component), c("component", "status", "value", "message")]
    print(sub, row.names = FALSE)
  }
  vp <- tryCatch(gllvmTMB:::.vp_residual_per_trait(fit8), error = function(e) e)
  cat("\n.vp_residual_per_trait(): ",
      if (inherits(vp, "error")) paste("ERROR", conditionMessage(vp)) else paste(signif(as.numeric(vp), 5), collapse = ", "),
      "  <- trait 2 is Poisson; a sigma_eps^2 here would be spurious\n", sep = "")
  sm <- tryCatch(simulate(fit8, nsim = 200L, seed = 5L, condition_on_RE = TRUE),
                 error = function(e) e)
  if (!inherits(sm, "error")) {
    sdt <- vapply(split(seq_len(nrow(sm)), d8$trait), function(r)
      mean(apply(sm[r, , drop = FALSE], 2L, sd)), numeric(1))
    cat("simulate() sd by trait: ", paste(signif(sdt, 4), collapse = ", "),
        "  (trait2 poisson: should be ~sqrt(3)=1.732, NOT sigma_eps[2])\n", sep = "")
  }
}

## ======================= D3 SE check ===================================
cat("\n===== D3 revisited: is the near-degenerate sigma_eps[2] SE honest? =====\n")
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
  cat("sigma_eps=", paste(signif(se_of(fit3), 5), collapse = ", "),
      " (true 0.5, 2.0)  pdHess=", pd_of(fit3), "\n", sep = "")
  s <- tryCatch(summary(fit3$sd_report, "fixed"), error = function(e) NULL)
  if (!is.null(s)) {
    rr <- s[rownames(s) == "log_sigma_eps", , drop = FALSE]
    cat("log_sigma_eps estimate / SE:\n"); print(signif(rr, 4))
    cat("-> SE on the LOG scale; an SE >> 0.5 means the split is barely identified\n")
  }
}
