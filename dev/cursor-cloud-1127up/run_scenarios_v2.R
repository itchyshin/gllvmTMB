#!/usr/bin/env Rscript
# cursor-cloud-1127up — user-style scenarios with correct APIs.
.libPaths(c(path.expand("~/R/library"), .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
options(cli.width = 120)

SHA <- system2("git", c("-C", "/agent/repos/gllvmTMB", "rev-parse", "HEAD"), stdout = TRUE)
OUT <- "/agent/repos/gllvmTMB/dev/cursor-cloud-1127up/results/v2_log.txt"
sink(OUT, split = TRUE)
on.exit(sink(), add = TRUE)

findings <- list()
log_find <- function(id, msg) {
  findings[[length(findings) + 1L]] <<- c(id, msg)
  cat(sprintf("\n*** FINDING %s: %s\n", id, msg))
}
pass <- function(msg) cat(sprintf("PASS: %s\n", msg))

conv <- function(fit) isTRUE(fit$fit$convergence == 0L)

fit_glv <- function(dat, d = 1L, unique = TRUE, family = gaussian(), ...) {
  lat <- if (unique) {
    as.formula(paste0("value ~ 0 + trait + latent(0 + trait | unit, d = ", d, ")"))
  } else {
    as.formula(paste0("value ~ 0 + trait + latent(0 + trait | unit, d = ", d, ", unique = FALSE)"))
  }
  gllvmTMB(lat, data = dat, trait = "trait", unit = "unit", family = family, ...)
}

# --- Scenario batch (28+) ---
set.seed(271127)

## 1-6 latent gaussian d/u
for (i in 1:6) {
  d <- c(1, 1, 2, 2, 3, 3)[i]
  u <- c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE)[i]
  Lam <- if (d == 1) matrix(runif(3, 0.3, 0.9), 3, 1) else matrix(runif(3 * d, -0.4, 0.8), 3, d)
  sim <- simulate_unit_trait(40, 2, 3, Lambda_B = Lam, psi_B = rep(0.15, 3), seed = 200 + i)
  fit <- fit_glv(sim$data, d = d, unique = u)
  if (!conv(fit)) log_find(sprintf("G%02d", i), "did not converge") else pass(sprintf("G%02d latent d=%d unique=%s", i, d, u))
  if (conv(fit)) {
    eta <- as.vector(fit$report$eta)
    pr <- as.vector(predict(fit, type = "link"))
    if (length(pr) == length(eta) && max(abs(pr - eta), na.rm = TRUE) > 1e-4) {
      log_find(sprintf("G%02d-predict", i), sprintf("predict(link) vs eta max diff %.4g", max(abs(pr - eta))))
    }
  }
}

## 7 indep
sim7 <- simulate_unit_trait(35, 2, 3, psi_B = rep(0.3, 3), seed = 7)
f7 <- gllvmTMB(value ~ 0 + trait + indep(0 + trait | unit), data = sim7$data,
               trait = "trait", unit = "unit", family = gaussian())
if (conv(f7)) {
  ysim <- simulate(f7, nsim = 1)
  if (inherits(ysim, "try-error") || any(!is.finite(ysim))) log_find("I07-sim", "simulate failed")
  else pass("I07 indep simulate")
  rr <- residuals(f7, type = "randomized_quantile")
  if (!is.numeric(rr$residual) && !is.numeric(rr)) log_find("I07-res", "rq residuals odd")
  else pass("I07 rq residuals")
}

## 8 dep advisory
sim8 <- simulate_unit_trait(30, 2, 3, seed = 8)
f8 <- gllvmTMB(value ~ 0 + trait + dep(0 + trait | unit), data = sim8$data,
               trait = "trait", unit = "unit", family = gaussian())
out <- capture.output(suppressMessages(extract_Sigma(f8)))
if (any(grepl("latent-only", out, ignore.case = TRUE))) {
  log_find("D08", "dep fit prints latent-only Sigma advisory")
} else {
  pass("D08 dep no latent-only advisory")
}

## 9-10 count families
sim9 <- simulate_unit_trait(40, 1, 3, Lambda_B = matrix(c(0.6, 0.3, -0.2), 3, 1),
                             psi_B = rep(0.1, 3), seed = 9)
sim9$data$value <- rpois(nrow(sim9$data), lambda = exp(pmin(sim9$data$value / 2 + 1, 5)))
f9 <- fit_glv(sim9$data, family = poisson())
if (conv(f9)) pass("P09 poisson") else log_find("P09", "poisson no conv")

sim10 <- sim9
sim10$data$value <- rbinom(nrow(sim10$data), 1, plogis(scale(sim10$data$value)))
f10 <- fit_glv(sim10$data, family = binomial(),
               control = gllvmTMBcontrol(warn_runaway = FALSE))
if (conv(f10)) {
  pr <- predict(f10, type = "response")
  if (any(pr < -0.001 | pr > 1.001, na.rm = TRUE)) log_find("B10", "response prob outside [0,1]")
  else pass("B10 binomial predict response in [0,1]")
} else log_find("B10", "binomial no conv")

## 11 nbinom2 only
dat11 <- data.frame(
  unit = rep(1:22, each = 3), trait = factor(rep(c("a", "b", "c"), 22)),
  value = rnbinom(66, mu = 3, size = 2)
)
f11 <- fit_glv(dat11, family = nbinom2(), control = gllvmTMBcontrol(warn_runaway = FALSE))
if (conv(f11)) pass("N11 nbinom2") else log_find("N11", "nbinom2 fit issue")

## 12 tweedie
dat12 <- data.frame(
  unit = rep(1:20, each = 3), trait = factor(rep(c("t1", "t2", "t3"), 20)),
  value = abs(rnorm(60)) + 0.05
)
f12 <- fit_glv(dat12, family = tweedie(p = 1.5))
if (conv(f12)) pass("T12 tweedie") else log_find("T12", "tweedie")

## 13 ordinal
dat13 <- data.frame(
  unit = rep(1:25, each = 2), trait = factor(rep(c("o1", "o2"), 25)),
  value = factor(sample(1:4, 50, replace = TRUE), ordered = TRUE)
)
f13 <- fit_glv(dat13, family = ordinal_logit())
if (conv(f13)) pass("O13 ordinal") else log_find("O13", "ordinal")

## 14 mixed gaussian binomial
set.seed(14)
dat14 <- data.frame(
  unit = rep(1:30, each = 2),
  trait = factor(rep(c("g", "b"), 30)),
  value = c(rnorm(30, 0, 1), rbinom(30, 1, 0.45))
)
fams <- list(g = gaussian(), b = binomial()); attr(fams, "family_var") <- "trait"
f14 <- fit_glv(dat14, family = fams, control = gllvmTMBcontrol(warn_runaway = FALSE))
if (conv(f14)) pass("M14 mixed") else log_find("M14", "mixed g+b failed")

## 15 site latent
sim15 <- simulate_site_trait(20, 5, 3, mean_species_per_site = 3,
                             Lambda_B = matrix(c(0.5, 0.2, -0.1), 3, 1), psi_B = rep(0.1, 3), seed = 15)
f15 <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
                data = sim15$data, trait = "trait", unit = "site")
if (conv(f15)) pass("S15 site") else log_find("S15", "site fit")

## 16 logLik vs objective sign
sim16 <- simulate_unit_trait(30, 2, 3, Lambda_B = matrix(c(0.7, 0.4, 0.1), 3, 1), seed = 16)
f16 <- fit_glv(sim16$data, d = 1)
if (conv(f16)) {
  ll <- as.numeric(logLik(f16))
  obj <- f16$fit$objective
  if (sign(ll) == sign(obj) && abs(ll + obj) > 1) log_find("L16", sprintf("logLik=%.3f objective=%.3f", ll, obj))
  else pass("L16 logLik/objective consistent sign")
}

## 17 AIC penalised warning + value
f17 <- fit_glv(sim16$data, d = 1, control = gllvmTMBcontrol(loading_ridge = 2))
if (conv(f17)) {
  w <- capture_warnings(AIC(f17))
  if (!length(w)) log_find("A17", "AIC on ridge fit without expected warning?")
  aic <- AIC(f17)
  k <- length(f17$fit$par)
  manual <- -2 * as.numeric(logLik(f17)) + 2 * k
  if (abs(aic - manual) > 1e-6) log_find("A17b", sprintf("AIC=%s vs manual=%s", aic, manual))
  else pass("A17 AIC formula consistent (penalised note separate)")
}

## 18 extract_correlations vs cor(Sigma) gaussian
if (conv(f16)) {
  cr <- suppressWarnings(extract_correlations(f16, link_residual = "none"))
  Sm <- extract_Sigma(f16, part = "total")$Sigma
  if (!is.null(Sm) && !is.null(cr$correlations)) {
    cd <- cor(Sm)
    diff <- max(abs(cr$correlations - cd), na.rm = TRUE)
    if (diff > 0.02) log_find("C18", sprintf("corr vs cor(Sigma) diff %.4f", diff))
    else pass("C18 correlations match cor(Sigma) with link_residual=none")
  }
}

## 19 simulate family override poisson
if (exists("f9") && conv(f9)) {
  s_wrong <- tryCatch(simulate(f9, nsim = 2, family = gaussian()), error = function(e) e)
  if (!inherits(s_wrong, "error")) {
    log_find("SIM19", "simulate(..., family=gaussian()) succeeded on poisson fit — check values")
    if (is.numeric(s_wrong) && any(s_wrong < 0, na.rm = TRUE)) log_find("SIM19b", "negative values from gaussian simulate on poisson fit")
  } else pass("SIM19 simulate family override refused or errored")
}

## 20 simulate newdata missing trait column
if (exists("f9") && conv(f9)) {
  nd <- f9$frame[1:3, "unit", drop = FALSE]
  nd$value <- NA
  err <- tryCatch(simulate(f9, newdata = nd, nsim = 1), error = function(e) conditionMessage(e))
  if (grepl("trait", err, ignore.case = TRUE)) pass("ND20 newdata clear error re trait")
  else log_find("ND20", paste("newdata error:", err))
}

## 21 vcov finite
if (conv(f16)) {
  V <- tryCatch(vcov(f16), error = function(e) e)
  if (inherits(V, "error")) log_find("V21", conditionMessage(V))
  else if (any(!is.finite(V))) log_find("V21", "vcov has non-finite entries")
  else pass("V21 vcov finite")
}

## 22 confint fixed effects
if (conv(f16)) {
  ci <- suppressWarnings(tryCatch(confint(f16), error = function(e) e))
  if (inherits(ci, "error")) log_find("CI22", conditionMessage(ci))
  else if (any(!is.finite(ci))) log_find("CI22", "confint non-finite")
  else pass("CI22 confint finite")
}

## 23 getLV rows = n_unit * d?
if (conv(f16)) {
  lv <- getLV(f16)
  ord <- extract_ordination(f16)
  if (nrow(lv) != nrow(ord$scores)) log_find("LV23", sprintf("getLV nrow %d vs ordination %d", nrow(lv), nrow(ord$scores)))
  else pass("LV23 getLV/ordination nrow match")
}

## 24 mixed gaussian nbinom2
dat24 <- data.frame(
  unit = rep(1:20, each = 2), trait = factor(rep(c("g", "n"), 20)),
  value = c(rnorm(20, 2, 1), rnbinom(20, mu = 4, size = 2))
)
f24 <- tryCatch({
  fams <- list(g = gaussian(), n = nbinom2()); attr(fams, "family_var") <- "trait"
  fit_glv(dat24, family = fams, control = gllvmTMBcontrol(warn_runaway = FALSE))
}, error = function(e) e)
if (inherits(f24, "error")) log_find("M24", conditionMessage(f24))
else if (conv(f24)) pass("M24 gaussian+nbinom2")
else log_find("M24", "no convergence")

## 25 tweedie + binomial
dat25 <- data.frame(
  unit = rep(1:18, each = 2), trait = factor(rep(c("tw", "bi"), 18)),
  value = c(abs(rgamma(18, 2, 1)) + 0.1, rbinom(18, 1, 0.35))
)
f25 <- tryCatch({
  fams <- list(tw = tweedie(p = 1.6), bi = binomial()); attr(fams, "family_var") <- "trait"
  fit_glv(dat25, family = fams, control = gllvmTMBcontrol(warn_runaway = FALSE))
}, error = function(e) e)
if (inherits(f25, "error")) log_find("M25", conditionMessage(f25))
else if (conv(f25)) pass("M25 tweedie+binomial")
else log_find("M25", "no convergence")

## 26 nobs matches rows
if (conv(f16)) {
  n1 <- nobs(f16)
  n2 <- nrow(f16$frame)
  if (n1 != n2) log_find("N26", sprintf("nobs %d frame %d", n1, n2))
  else pass("N26 nobs matches frame")
}

## 27 predict response ordinal
if (exists("f13") && conv(f13)) {
  pr <- tryCatch(predict(f13, type = "response"), error = function(e) e)
  if (inherits(pr, "error")) log_find("O27", conditionMessage(pr))
  else {
    if (is.matrix(pr) && any(pr < -0.01 | pr > 1.01, na.rm = TRUE)) log_find("O27", "ordinal response probs out of range")
    else pass("O27 ordinal predict response")
  }
}

## 28 unique FALSE vs TRUE Sigma rank
sim28 <- simulate_unit_trait(35, 1, 3, Lambda_B = matrix(c(0.8, 0.5, 0.2), 3, 1), seed = 28)
f28u <- fit_glv(sim28$data, d = 1, unique = TRUE)
f28f <- fit_glv(sim28$data, d = 1, unique = FALSE)
if (conv(f28u) && conv(f28f)) {
  Su <- extract_Sigma(f28u, part = "total")$Sigma
  Sf <- extract_Sigma(f28f, part = "total")$Sigma
  if (!is.null(Su) && !is.null(Sf)) {
    pass("U28 both unique modes converged")
    ## loadings-only total can equal LLt only
  }
}

## 29 simulate poisson integer
if (exists("f9") && conv(f9)) {
  ys <- simulate(f9, nsim = 3)
  if (any(ys != floor(ys), na.rm = TRUE)) log_find("P29", "poisson simulate non-integer")
  else pass("P29 poisson simulate integer")
}

## 30 extract_Sigma part unique psi positive gaussian
if (conv(f28u)) {
  pu <- extract_Sigma(f28u, part = "unique")
  psi <- if (is.list(pu) && !is.null(pu$Sigma)) diag(pu$Sigma) else diag(pu)
  if (any(psi <= 0, na.rm = TRUE)) log_find("PSI30", "non-positive psi on unique part")
  else pass("PSI30 positive psi")
}

cat("\n=== TOTAL FINDINGS:", length(findings), "===\n")
for (f in findings) cat(paste(f, collapse = " | "), "\n")
cat("SHA:", SHA, "\n")
saveRDS(list(findings = findings, sha = SHA), "/agent/repos/gllvmTMB/dev/cursor-cloud-1127up/results/v2_summary.rds")