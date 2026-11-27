#!/usr/bin/env Rscript
# Claim tag: cursor-cloud-1127up (text label only)
# Non-phylo latent + extractor consistency harness — does not modify tests/src.

.libPaths(c(path.expand("~/R/library"), .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
suppressPackageStartupMessages(library(Matrix))

SHA <- system2("git", c("-C", "/agent/repos/gllvmTMB", "rev-parse", "HEAD"), stdout = TRUE)
if (length(SHA) == 0) SHA <- "unknown"

out_dir <- "/agent/repos/gllvmTMB/dev/cursor-cloud-1127up/results"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

findings <- list()
passed <- character()
suspicious <- list()

record_finding <- function(id, title, detail, repro) {
  findings[[length(findings) + 1L]] <<- list(
    id = id, title = title, detail = detail, repro = repro
  )
}

record_pass <- function(x) passed <<- c(passed, x)
record_suspicious <- function(id, note) suspicious[[id]] <<- note

`%||%` <- function(a, b) if (!is.null(a)) a else b

safe_run <- function(id, label, expr) {
  tryCatch(
    {
      res <- force(expr)
      list(ok = TRUE, value = res)
    },
    error = function(e) list(ok = FALSE, error = conditionMessage(e))
  )
}

converged_ok <- function(fit) {
  isTRUE(fit$fit$convergence == 0L) ||
    (is.list(fit$fit_health) && isTRUE(fit$fit_health$converged))
}

## Helpers --------------------------------------------------------------------

latent_formula <- function(d, unique = TRUE) {
  if (unique) {
    quote(value ~ 0 + trait + latent(0 + trait | unit, d = d))
  } else {
    quote(value ~ 0 + trait + latent(0 + trait | unit, d = d, unique = FALSE))
  }
}

fit_latent <- function(sim, d = 1L, unique = TRUE, family = gaussian(),
                       weights = NULL, control = gllvmTMBcontrol()) {
  fml <- latent_formula(d, unique)
  gllvmTMB(
    fml, data = sim$data, trait = "trait", unit = "unit",
    family = family, weights = weights, control = control
  )
}

check_sigma_identity <- function(fit, tol = 0.15, id) {
  sig <- tryCatch(extract_Sigma(fit, part = "total"), error = function(e) NULL)
  lam <- tryCatch(extract_loadings(fit), error = function(e) NULL)
  psi <- extract_Sigma(fit, part = "unique")
  if (is.null(lam) || is.null(sig) || is.null(psi)) {
    record_suspicious(id, "Could not extract Sigma/loadings/unique for identity check")
    return(invisible(NULL))
  }
  L <- as.matrix(lam)
  recon <- L %*% t(L)
  if (!is.null(psi$Sigma) || !is.null(psi)) {
    pdiag <- if (is.matrix(psi)) diag(psi) else if (is.list(psi) && !is.null(psi$Sigma)) {
      diag(psi$Sigma)
    } else {
      rep(NA_real_, ncol(recon))
    }
    if (!all(is.na(pdiag))) diag(recon) <- diag(recon) + pdiag
  }
  S <- if (is.list(sig) && !is.null(sig$Sigma)) sig$Sigma else as.matrix(sig)
  max_rel <- max(abs(recon - S) / (abs(S) + 1e-6), na.rm = TRUE)
  if (is.finite(max_rel) && max_rel > tol) {
    record_finding(
      id,
      sprintf("extract_Sigma total disagrees with Lambda Lambda' + Psi (max rel err %.3f)", max_rel),
      sprintf("Scenario %s: converged=%s; max_rel=%s", id, converged_ok(fit), max_rel),
      "see harness log"
    )
  }
  invisible(max_rel)
}

check_predict_eta <- function(fit, tol = 1e-5, id) {
  pr <- predict(fit, type = "link")
  eta <- fit$report$eta
  if (is.null(eta)) {
    record_suspicious(id, "fit$report$eta missing")
    return(invisible(NULL))
  }
  if (is.data.frame(pr)) pr <- as.matrix(pr)
  if (!is.numeric(pr)) {
    record_suspicious(id, sprintf("predict(link) returned class %s", paste(class(pr), collapse = "/")))
    return(invisible(NULL))
  }
  diff <- max(abs(as.vector(pr) - as.vector(eta)), na.rm = TRUE)
  if (!is.finite(diff) || diff > tol) {
    record_finding(
      id,
      sprintf("predict(type='link') disagrees with report$eta (max |diff|=%.4g)", diff),
      sprintf("converged=%s", converged_ok(fit)),
      "harness"
    )
  }
  invisible(diff)
}

check_loglik <- function(fit, id) {
  ll1 <- logLik(fit)
  ll2 <- fit$fit$objective
  if (is.finite(ll1) && is.finite(ll2)) {
    if (abs(as.numeric(ll1) + as.numeric(ll2)) > 0.05) {
      record_finding(
        id,
        "logLik() sign or scale disagrees with fit$fit$objective",
        sprintf("logLik=%s objective=%s converged=%s", ll1, ll2, converged_ok(fit)),
        "harness"
      )
    }
  }
  aic <- AIC(fit)
  n <- nobs(fit)
  if (is.finite(aic) && is.finite(n) && n < 1) {
    record_finding(id, "nobs() < 1 on converged fit", as.character(n), "harness")
  }
  invisible(NULL)
}

check_correlations <- function(fit, id) {
  cr <- tryCatch(extract_correlations(fit), error = function(e) e)
  if (inherits(cr, "error")) {
    record_finding(id, "extract_correlations() error on converged latent fit",
                   conditionMessage(cr), "harness")
    return(invisible(NULL))
  }
  sig <- extract_Sigma(fit, part = "total")
  Sm <- if (is.list(sig) && !is.null(sig$Sigma)) sig$Sigma else as.matrix(sig)
  cor_direct <- cov2cor(Sm)
  if (!is.null(cr$correlations)) {
    diff <- max(abs(cr$correlations - cor_direct), na.rm = TRUE)
    if (is.finite(diff) && diff > 0.05) {
      record_finding(
        id,
        sprintf("extract_correlations() != cor(extract_Sigma) (max diff %.3f)", diff),
        "Post-fit cross-trait correlation inconsistency",
        "harness"
      )
    }
  }
  invisible(NULL)
}

check_ordination_lv <- function(fit, id) {
  lv <- tryCatch(getLV(fit), error = function(e) e)
  if (inherits(lv, "error")) {
    record_finding(id, "getLV() fails on converged latent fit", conditionMessage(lv), "harness")
    return(invisible(NULL))
  }
  ord <- tryCatch(extract_ordination(fit), error = function(e) e)
  if (inherits(ord, "error")) {
    record_finding(id, "extract_ordination() fails", conditionMessage(ord), "harness")
    return(invisible(NULL))
  }
  if (!is.null(lv) && !is.null(ord$scores)) {
    n_diff <- nrow(lv) != nrow(ord$scores)
    if (n_diff) {
      record_finding(id, "getLV nrow != extract_ordination scores nrow", "", "harness")
    }
  }
  invisible(NULL)
}

check_simulate <- function(fit, id) {
  s1 <- tryCatch(simulate(fit, n = 1L), error = function(e) e)
  if (inherits(s1, "error")) {
    record_finding(id, "simulate() error on converged fit", conditionMessage(s1), "harness")
    return(invisible(NULL))
  }
  if (is.numeric(s1)) {
    if (any(!is.finite(s1))) {
      record_finding(id, "simulate() returned non-finite values", "", "harness")
    }
  }
  invisible(NULL)
}

check_residuals <- function(fit, id, family = "gaussian") {
  r <- tryCatch(residuals(fit, type = "pearson"), error = function(e) e)
  if (inherits(r, "error")) {
    record_finding(id, "residuals(pearson) error", conditionMessage(r), "harness")
    return(invisible(NULL))
  }
  if (family == "binomial" && any(abs(r) > 50, na.rm = TRUE)) {
    record_suspicious(id, "Very large Pearson residuals on binomial latent fit")
  }
  invisible(NULL)
}

check_confint_vcov <- function(fit, id) {
  ci <- tryCatch(suppressMessages(confint(fit)), error = function(e) e)
  if (inherits(ci, "error")) {
    record_suspicious(id, paste("confint:", conditionMessage(ci)))
  } else if (is.matrix(ci) && any(!is.finite(ci))) {
    record_finding(id, "confint() contains non-finite entries", "", "harness")
  }
  V <- tryCatch(vcov(fit), error = function(e) e)
  if (inherits(V, "error")) {
    record_suspicious(id, paste("vcov:", conditionMessage(V)))
  } else if (is.matrix(V)) {
    ev <- eigen(V, symmetric = TRUE, only.values = TRUE)$values
    if (any(ev < -1e-8, na.rm = TRUE)) {
      record_finding(id, "vcov() not positive semidefinite", paste(min(ev), collapse = " "), "harness")
    }
  }
  invisible(NULL)
}

run_standard_postfit <- function(fit, id, family = "gaussian") {
  if (!converged_ok(fit)) return(invisible(NULL))
  check_predict_eta(fit, id = id)
  check_loglik(fit, id = id)
  check_sigma_identity(fit, id = id)
  check_correlations(fit, id = id)
  check_ordination_lv(fit, id = id)
  check_simulate(fit, id = id)
  check_residuals(fit, id = id, family = family)
  check_confint_vcov(fit, id = id)
  invisible(NULL)
}

## Scenarios ------------------------------------------------------------------

set.seed(271127)

# S01–S06: d=1..3, unique TRUE/FALSE gaussian unit_trait
for (sc in list(
  list(id = "S01", d = 1L, u = TRUE),
  list(id = "S02", d = 1L, u = FALSE),
  list(id = "S03", d = 2L, u = TRUE),
  list(id = "S04", d = 2L, u = FALSE),
  list(id = "S05", d = 3L, u = TRUE),
  list(id = "S06", d = 3L, u = FALSE)
)) {
  Lam <- matrix(runif(3 * sc$d, -0.5, 0.8), 3, sc$d)
  sim <- simulate_unit_trait(40, 2, 3, Lambda_B = Lam, psi_B = rep(0.2, 3), seed = 100 + sc$d)
  r <- safe_run(sc$id, sc$id, fit_latent(sim, d = sc$d, unique = sc$u))
  if (!r$ok) {
    record_finding(sc$id, "gllvmTMB latent gaussian fit error", r$error, "harness")
  } else {
    run_standard_postfit(r$value, sc$id)
    if (converged_ok(r$value)) record_pass(paste0(sc$id, " gaussian latent d=", sc$d, " unique=", sc$u))
  }
}

# S07 indep baseline
sim7 <- simulate_unit_trait(35, 2, 3, psi_B = rep(0.4, 3), seed = 7)
r7 <- safe_run("S07", "S07", gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = sim7$data, trait = "trait", unit = "unit", family = gaussian()
))
if (r7$ok && converged_ok(r7$value)) {
  run_standard_postfit(r7$value, "S07")
  record_pass("S07 indep gaussian")
}

# S08 dep full
sim8 <- simulate_unit_trait(30, 2, 3, seed = 8)
r8 <- safe_run("S08", "S08", gllvmTMB(
  value ~ 0 + trait + dep(0 + trait | unit),
  data = sim8$data, trait = "trait", unit = "unit", family = gaussian()
))
if (r8$ok) {
  msg <- capture.output(extract_Sigma(r8$value))
  if (any(grepl("latent-only", msg, ignore.case = TRUE))) {
    record_finding(
      "S08",
      "extract_Sigma() prints latent-only advisory on dep() fit",
      paste(msg, collapse = " "),
      "dep() gaussian — see issue #1556 if still present on main"
    )
  } else if (converged_ok(r8$value)) {
    run_standard_postfit(r8$value, "S08")
    record_pass("S08 dep (advisory absent)")
  }
}

# S09–S10: Poisson / binomial counts via transformed simulate
sim9 <- simulate_unit_trait(45, 1, 3, Lambda_B = matrix(c(0.7, 0.4, -0.3), 3, 1),
                            psi_B = rep(0.1, 3), seed = 9)
sim9$data$value <- pmax(0L, round(exp(sim9$data$value)))
r9 <- safe_run("S09", "S09", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim9$data, trait = "trait", unit = "unit", family = poisson()
))
if (r9$ok && converged_ok(r9$value)) {
  run_standard_postfit(r9$value, "S09", family = "poisson")
  record_pass("S09 poisson latent d=1")
} else if (!r9$ok) record_finding("S09", "poisson latent fit error", r9$error, "")

sim10 <- sim9
sim10$data$value <- as.integer(exp(sim10$data$value) > median(exp(sim10$data$value)))
r10 <- safe_run("S10", "S10", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim10$data, trait = "trait", unit = "unit", family = binomial()
))
if (r10$ok && converged_ok(r10$value)) {
  run_standard_postfit(r10$value, "S10", family = "binomial")
  pr <- tryCatch(predict(r10$value, type = "response"), error = function(e) e)
  if (!inherits(pr, "error") && (any(pr < -0.01, na.rm = TRUE) || any(pr > 1.01, na.rm = TRUE))) {
    record_finding("S10", "predict(type=response) outside [0,1] on binomial latent", "", "harness")
  } else {
    record_pass("S10 binomial latent d=1")
  }
}

# S11 nbinom2
set.seed(11)
n <- 120
dat11 <- data.frame(
  unit = rep(1:20, each = 6),
  trait = rep(rep(c("a", "b", "c"), 2), 20),
  value = rnbinom(120, mu = 5, size = 2)
)
r11 <- safe_run("S11", "S11", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dat11, trait = "trait", unit = "unit", family = nbinom2()
))
if (r11$ok && converged_ok(r11$value)) {
  run_standard_postfit(r11$value, "S11", family = "nbinom2")
  record_pass("S11 nbinom2 latent")
} else if (!r11$ok) record_finding("S11", "nbinom2 latent error", r11$error, "")

# S12 tweedie (small)
set.seed(12)
dat12 <- data.frame(
  unit = rep(1:25, each = 3),
  trait = rep(c("t1", "t2", "t3"), 25),
  value = abs(rnorm(75, 2, 1)) + 0.01
)
r12 <- safe_run("S12", "S12", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dat12, trait = "trait", unit = "unit", family = tweedie(p = 1.5)
))
if (r12$ok && converged_ok(r12$value)) {
  run_standard_postfit(r12$value, "S12")
  record_pass("S12 tweedie latent")
} else if (!r12$ok) record_finding("S12", "tweedie latent error", r12$error, "")

# S13 ordinal
set.seed(13)
dat13 <- data.frame(
  unit = rep(1:30, each = 4),
  trait = rep(c("o1", "o2"), 60),
  value = factor(sample(1:4, 120, replace = TRUE), ordered = TRUE)
)
r13 <- safe_run("S13", "S13", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dat13, trait = "trait", unit = "unit", family = ordinal_logit()
))
if (r13$ok && converged_ok(r13$value)) {
  check_ordination_lv(r13$value, "S13")
  check_predict_eta(r13$value, tol = 1e-4, id = "S13")
  record_pass("S13 ordinal latent")
} else if (!r13$ok) record_finding("S13", "ordinal_logit latent error", r13$error, "")

# S14 mixed gaussian + binomial
set.seed(14)
sim14 <- simulate_unit_trait(25, 2, 2, Lambda_B = matrix(c(0.6, 0.5), 2, 1),
                             psi_B = c(0.2, 0.2), seed = 14)
sim14$data$trait <- factor(sim14$data$trait)
sim14$data$value2 <- sim14$data$value
sim14$data$value <- ifelse(sim14$data$trait == levels(sim14$data$trait)[2],
                           as.integer(plogis(sim14$data$value) > 0.5),
                           sim14$data$value)
wide <- merge(sim14$data[sim14$data$trait == levels(sim14$data$trait)[1],
                          c("unit", "observation", "value")],
              sim14$data[sim14$data$trait == levels(sim14$data$trait)[2],
                        c("unit", "observation", "value")],
              by = c("unit", "observation"), suffixes = c("_g", "_b"))
dat14 <- rbind(
  data.frame(unit = wide$unit, trait = "g", value = wide$value_g),
  data.frame(unit = wide$unit, trait = "b", value = wide$value_b)
)
dat14$trait <- factor(dat14$trait)
fams <- list(g = gaussian(), b = binomial())
attr(fams, "family_var") <- "trait"
r14 <- safe_run("S14", "S14", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dat14, trait = "trait", unit = "unit", family = fams
))
if (r14$ok && converged_ok(r14$value)) {
  run_standard_postfit(r14$value, "S14", family = "binomial")
  record_pass("S14 mixed gaussian+binomial latent")
} else if (!r14$ok) record_finding("S14", "mixed-family latent error", r14$error, "")

# S15 simulate_site_trait latent on site (no phylo)
sim15 <- simulate_site_trait(25, 6, 3, mean_species_per_site = 4,
                             Lambda_B = matrix(c(0.5, 0.3, -0.2), 3, 1),
                             psi_B = rep(0.15, 3), seed = 15)
r15 <- safe_run("S15", "S15", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | site, d = 1),
  data = sim15$data, trait = "trait", unit = "site"
))
if (r15$ok && converged_ok(r15$value)) {
  run_standard_postfit(r15$value, "S15")
  record_pass("S15 site_trait latent")
}

# S16 unique=FALSE loadings-only correlations warning behaviour
sim16 <- simulate_unit_trait(35, 1, 4, Lambda_B = matrix(1, 4, 1), seed = 16)
r16 <- safe_run("S16", "S16", fit_latent(sim16, d = 1, unique = FALSE))
if (r16$ok && converged_ok(r16$value)) {
  sig_only <- extract_Sigma(r16$value, part = "lower_rank")
  sig_tot <- extract_Sigma(r16$value, part = "total")
  if (!is.null(sig_only) && !is.null(sig_tot)) {
    record_pass("S16 unique=FALSE extract_Sigma parts")
  }
  check_correlations(r16$value, "S16")
}

# S17 predict response gaussian
sim17 <- simulate_unit_trait(30, 2, 3, Lambda_B = matrix(c(0.8, 0.2, -0.1), 3, 1),
                             seed = 17)
r17 <- safe_run("S17", "S17", fit_latent(sim17, d = 1))
if (r17$ok && converged_ok(r17$value)) {
  pl <- predict(r17$value, type = "link")
  pr <- predict(r17$value, type = "response")
  if (max(abs(pl - pr), na.rm = TRUE) > 1e-6) {
    record_finding("S17", "gaussian: predict response != link", "", "harness")
  } else {
    record_pass("S17 gaussian link=response identity")
  }
}

# S18 AIC vs manual
if (exists("r17") && r17$ok && converged_ok(r17$value)) {
  aic <- AIC(r17$value)
  k <- length(r17$value$fit$par)
  aic2 <- -2 * as.numeric(logLik(r17$value)) + 2 * k
  if (abs(aic - aic2) > 0.5) {
    record_finding("S18", "AIC() inconsistent with -2*logLik + 2k", sprintf("AIC=%s manual=%s", aic, aic2), "")
  } else {
    record_pass("S18 AIC consistent")
  }
}

# S19 simulate newdata poisson
if (exists("r9") && r9$ok && converged_ok(r9$value)) {
  nd <- r9$value$frame[1:3, c("unit", "trait")]
  nd$value <- NA
  s19 <- tryCatch(simulate(r9$value, newdata = nd, n = 2L), error = function(e) e)
  if (inherits(s19, "error")) {
    record_suspicious("S19", paste("simulate newdata:", conditionMessage(s19)))
  } else {
    record_pass("S19 simulate newdata poisson")
  }
  s19b <- tryCatch(simulate(r9$value, n = 3L, family = gaussian()), error = function(e) e)
  if (!inherits(s19b, "error") && is.numeric(s19b)) {
    record_finding(
      "S19b",
      "simulate(..., family=gaussian()) on poisson fit succeeds (wrong family silent?)",
      paste(range(s19b), collapse = " "),
      "extends #1978 pattern"
    )
  }
}

# S20 extract_Sigma part unique vs indep
sim20 <- simulate_unit_trait(28, 2, 3, psi_B = rep(0.5, 3), seed = 20)
r20 <- safe_run("S20", "S20", gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = sim20$data, trait = "trait", unit = "unit", family = gaussian()
))
if (r20$ok && converged_ok(r20$value)) {
  u <- extract_Sigma(r20$value, part = "unique")
  t <- extract_Sigma(r20$value, part = "total")
  if (!is.null(u) && !is.null(t)) record_pass("S20 indep Sigma parts")
}

# S21 latent d=2 with n_traits=2 (full rank)
sim21 <- simulate_unit_trait(40, 2, 2, Lambda_B = diag(2), psi_B = c(0.1, 0.1), seed = 21)
r21 <- safe_run("S21", "S21", fit_latent(sim21, d = 2))
if (r21$ok && converged_ok(r21$value)) {
  run_standard_postfit(r21$value, "S21")
  record_pass("S21 d=2 n_traits=2")
}

# S22 confint on loadings if available
if (exists("r21") && r21$ok && converged_ok(r21$value)) {
  ci <- suppressMessages(tryCatch(confint(r21$value, parm = "loadings"),
                                  error = function(e) e, warning = function(w) w))
  if (inherits(ci, "error")) {
    record_suspicious("S22", conditionMessage(ci))
  } else {
    record_pass("S22 confint loadings attempted")
  }
}

# S23 ordiplot smoke
if (exists("r17") && r17$ok && converged_ok(r17$value)) {
  op <- tryCatch({
    ord <- extract_ordination(r17$value)
    list(ok = TRUE, n = nrow(ord$scores))
  }, error = function(e) list(ok = FALSE, err = conditionMessage(e)))
  if (!op$ok) record_finding("S23", "extract_ordination failed gaussian", op$err, "")
  else record_pass("S23 ordination scores")
}

# S24 nbinom2 + gaussian mixed
set.seed(24)
dat24 <- data.frame(
  unit = rep(1:18, each = 4),
  trait = rep(c("g", "n"), 36),
  value = c(rnorm(36, 5, 1), rnbinom(36, mu = 4, size = 1.5))
)
dat24$value <- ifelse(dat24$trait == "n", dat24$value, dat24$value)
dat24$trait <- factor(dat24$trait)
f24 <- list(g = gaussian(), n = nbinom2())
attr(f24, "family_var") <- "trait"
r24 <- safe_run("S24", "S24", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dat24, trait = "trait", unit = "unit", family = f24
))
if (r24$ok && converged_ok(r24$value)) {
  run_standard_postfit(r24$value, "S24")
  record_pass("S24 mixed gaussian+nbinom2")
} else if (!r24$ok) record_finding("S24", "mixed gaussian nbinom2 error", r24$error, "")

# S25 residuals simulate round-trip Pearson mean
if (exists("r17") && r17$ok && converged_ok(r17$value)) {
  ysim <- simulate(r17$value, n = 1L)
  if (is.numeric(ysim) && any(!is.finite(ysim))) {
    record_finding("S25", "simulate gaussian non-finite", "", "")
  } else {
    record_pass("S25 simulate gaussian finite")
  }
}

# S26 tweedie + binomial mix
set.seed(26)
dat26 <- data.frame(
  unit = rep(1:15, each = 4),
  trait = rep(c("tw", "bi"), 30),
  value = c(abs(rgamma(30, 2, 1)) + 0.1, rbinom(30, 1, 0.4))
)
dat26$trait <- factor(dat26$trait)
f26 <- list(tw = tweedie(p = 1.6), bi = binomial())
attr(f26, "family_var") <- "trait"
r26 <- safe_run("S26", "S26", gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dat26, trait = "trait", unit = "unit", family = f26
))
if (r26$ok && converged_ok(r26$value)) {
  check_correlations(r26$value, "S26")
  record_pass("S26 tweedie+binomial mixed")
} else if (!r26$ok) record_finding("S26", "tweedie+binomial mixed error", r26$error, "")

# S27 converged flag when gradient bad
sim27 <- simulate_unit_trait(15, 1, 3, seed = 27)
r27 <- safe_run("S27", "S27", fit_latent(sim27, d = 3))
if (r27$ok) {
  fg <- r27$value$fit_health$max_gradient %||% NA_real_
  if (converged_ok(r27$value) && is.finite(fg) && fg > 0.1) {
    record_finding(
      "S27",
      "convergence TRUE (or 0) despite large max_gradient",
      sprintf("max_gradient=%s", fg),
      "small n, d=3 — check fit_health"
    )
  } else {
    record_pass("S27 gradient/convergence gate")
  }
}

# S28 extract_correlations interval vs point
if (exists("r21") && r21$ok && converged_ok(r21$value)) {
  cr0 <- extract_correlations(r21$value, interval = FALSE)
  cr1 <- tryCatch(extract_correlations(r21$value, interval = TRUE), error = function(e) e)
  if (!inherits(cr1, "error") && !is.null(cr0$correlations) && !is.null(cr1$correlations)) {
    if (max(abs(cr0$correlations - cr1$correlations), na.rm = TRUE) > 1e-6) {
      record_finding("S28", "extract_correlations point vs interval=TRUE point differ", "", "")
    } else {
      record_pass("S28 correlations interval point match")
    }
  }
}

# Write summary
summary <- list(
  claim_tag = "cursor-cloud-1127up",
  sha = SHA,
  sessionInfo = utils::capture.output(sessionInfo()),
  n_findings = length(findings),
  findings = findings,
  passed = passed,
  suspicious = suspicious,
  n_passed = length(passed)
)
saveRDS(summary, file.path(out_dir, "harness_summary.rds"))
if (requireNamespace("jsonlite", quietly = TRUE)) {
  writeLines(jsonlite::toJSON(summary, auto_unbox = TRUE, pretty = TRUE),
             file.path(out_dir, "harness_summary.json"))
}
cat(sprintf("DONE: %d findings, %d passed\n", length(findings), length(passed)))