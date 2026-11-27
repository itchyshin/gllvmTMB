#!/usr/bin/env Rscript
.libPaths(c(path.expand("~/R/library"), .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
SHA <- system2("git", c("-C", "/agent/repos/gllvmTMB", "rev-parse", "HEAD"), stdout = TRUE)
LOG <- "/agent/repos/gllvmTMB/dev/cursor-cloud-1127up/results/v3_findings.rds"

findings <- list()
add <- function(id, title, detail, repro) {
  findings[[length(findings) + 1L]] <<- list(id = id, title = title, detail = detail, repro = repro)
}

conv <- function(fit) isTRUE(fit$fit$convergence == 0L)
fit_lat <- function(dat, d = 1, family = gaussian(), unique = TRUE, ...) {
  uq <- if (unique) "" else ", unique = FALSE"
  fml <- as.formula(paste0("value ~ 0 + trait + latent(0 + trait | unit, d = ", d, uq, ")"))
  gllvmTMB(fml, data = dat, trait = "trait", unit = "unit", family = family, ...)
}

session_txt <- paste(capture.output(sessionInfo()), collapse = "\n")

# 1 simulate(..., family=gaussian()) on poisson WITHOUT newdata
set.seed(1)
sim <- simulate_unit_trait(35, 1, 3, Lambda_B = matrix(0.4, 3, 1), psi_B = rep(0.1, 3), seed = 1)
sim$data$value <- rpois(nrow(sim$data), lambda = 2)
fp <- fit_lat(sim$data, family = poisson())
if (conv(fp)) {
  s <- simulate(fp, nsim = 5, family = gaussian())
  if (any(s != floor(s), na.rm = TRUE)) {
    add("F01", "simulate(nsim, family=gaussian()) on Poisson latent returns non-integers",
        paste("range", paste(range(s), collapse = " ")),
        "poisson latent d=1 in-sample simulate with family override")
  }
  w <- simulate(fp, nsim = 1)
}

# 2 in-sample predict link vs eta gaussian latent
set.seed(2)
sim2 <- simulate_unit_trait(32, 2, 3, Lambda_B = matrix(c(0.7, 0.2, 0.1), 3, 1), psi_B = rep(0.2, 3), seed = 2)
fg <- fit_lat(sim2$data)
if (conv(fg)) {
  pr <- predict(fg, type = "link")
  if (is.numeric(pr)) {
    d <- max(abs(as.vector(pr) - as.vector(fg$report$eta)), na.rm = TRUE)
    if (d > 1e-3) add("F02", "predict(link) != report$eta on gaussian latent", paste("max diff", d), "")
  }
}

# 3 nbinom2 + gaussian mixed CORRECT data prep
set.seed(3)
u <- rep(1:20, each = 2)
dat3 <- data.frame(
  unit = u,
  trait = factor(rep(c("g", "n"), 20), levels = c("g", "n")),
  value = NA_real_
)
dat3$value[dat3$trait == "g"] <- rnorm(20, 1, 0.8)
dat3$value[dat3$trait == "n"] <- rnbinom(20, mu = 3, size = 2)
fams3 <- list(g = gaussian(), n = nbinom2()); attr(fams3, "family_var") <- "trait"
f3 <- tryCatch(fit_lat(dat3, family = fams3, control = gllvmTMBcontrol(warn_runaway = FALSE)),
               error = function(e) e)
if (inherits(f3, "error")) {
  add("F03", "mixed gaussian+nbinom2 latent refuses valid integer/count data", conditionMessage(f3), "dat3 dput")
} else if (!conv(f3)) {
  add("F03b", "mixed gaussian+nbinom2 latent does not converge on toy data", "", "")
} else {
  cr <- suppressWarnings(extract_correlations(f3, link_residual = "auto"))
  if (any(abs(cr$correlations) > 1.001, na.rm = TRUE)) {
    add("F04", "extract_correlations off-diagonal |r|>1 mixed gaussian+nbinom2", "", "")
  }
}

# 4 tweedie + binomial mixed
set.seed(4)
dat4 <- data.frame(unit = rep(1:18, 2), trait = factor(rep(c("tw", "bi"), each = 18), levels = c("tw", "bi")), value = NA)
dat4$value[dat4$trait == "tw"] <- abs(rgamma(18, 2, 1)) + 0.05
dat4$value[dat4$trait == "bi"] <- rbinom(18, 1, 0.4)
fams4 <- list(tw = tweedie(p = 1.6), bi = binomial()); attr(fams4, "family_var") <- "trait"
f4 <- tryCatch(fit_lat(dat4, family = fams4, control = gllvmTMBcontrol(warn_runaway = FALSE)), error = function(e) e)
if (inherits(f4, "error")) add("F05", "tweedie+binomial mixed latent error", conditionMessage(f4), "")

# 5 ordinal predict type response sum to 1 per row?
set.seed(5)
dat5 <- data.frame(unit = rep(1:24, 2), trait = factor(rep(c("o1", "o2"), 24)),
                   value = factor(sample(1:4, 48, replace = TRUE), ordered = TRUE))
f5 <- fit_lat(dat5, family = ordinal_logit())
if (conv(f5)) {
  pr <- predict(f5, type = "response")
  if (is.matrix(pr)) {
    rs <- rowSums(pr)
    if (max(abs(rs - 1), na.rm = TRUE) > 0.05) {
      add("F06", "ordinal predict(type=response) rows do not sum to 1", paste(range(rs), collapse = " "), "")
    }
  }
}

# 6 confint loading on binomial single-trial latent (psi dropped)
set.seed(6)
sim6 <- simulate_unit_trait(50, 1, 2, Lambda_B = matrix(c(0.6, 0.4), 2, 1), seed = 6)
sim6$data$value <- rbinom(nrow(sim6$data), 1, 0.5)
f6 <- fit_lat(sim6$data, family = binomial(), control = gllvmTMBcontrol(warn_runaway = FALSE))
if (conv(f6)) {
  ci <- suppressWarnings(tryCatch(confint(f6), error = function(e) e, warning = function(w) w))
  if (is.matrix(ci) && any(!is.finite(ci))) add("F07", "confint() non-finite on binomial latent", "", "")
}

# 7 logLik + AIC same value different formulas?
if (exists("fg") && conv(fg)) {
  ll <- as.numeric(logLik(fg))
  aic <- AIC(fg)
  if (is.finite(ll) && is.finite(aic) && aic < -2 * ll) add("F08", "AIC less than -2*logLik on unpenalised gaussian fit", paste(aic, ll), "")
}

# 8 extract_Sigma total symmetry
if (exists("fg") && conv(fg)) {
  S <- extract_Sigma(fg, part = "total")$Sigma
  if (!is.null(S) && max(abs(S - t(S)), na.rm = TRUE) > 1e-6) add("F09", "extract_Sigma total not symmetric", "", "")
}

# 9 simulate binomial in-range
if (exists("f6") && conv(f6)) {
  sb <- simulate(f6, nsim = 3)
  if (any(sb < -0.01 | sb > 1.01, na.rm = TRUE)) add("F10", "simulate binomial latent draws outside [0,1]", paste(range(sb), collapse = " "), "")
}

# 10 getLV colnames vs unit count
if (exists("fg") && conv(fg)) {
  lv <- getLV(fg)
  nu <- length(unique(fg$frame$unit))
  if (nrow(lv) != nu) add("F11", "getLV nrow != number of units", paste(nrow(lv), nu), "")
}

# 11 ordination scores rotation vs getLV correlation
if (exists("fg") && conv(fg)) {
  ord <- extract_ordination(fg)
  if (ncol(lv) >= 1 && ncol(ord$scores) >= 1) {
    ccor <- abs(cor(lv[, 1], ord$scores[, 1], use = "complete"))
    if (!is.na(ccor) && ccor < 0.5) add("F12", "getLV and extract_ordination scores poorly aligned", paste(ccor), "")
  }
}

# 12 vcov dim vs length par
if (exists("fg") && conv(fg)) {
  V <- tryCatch(vcov(fg), error = function(e) NULL)
  if (is.matrix(V) && nrow(V) != length(fg$fit$par)) {
    add("F13", "vcov nrow != length(fit$par)", paste(nrow(V), length(fg$fit$par)), "")
  }
}

# 13 residuals simulation_rank on poisson
if (exists("fp") && conv(fp)) {
  rr <- tryCatch(residuals(fp, type = "simulation_rank", nsim = 20, seed = 7), error = function(e) e)
  if (inherits(rr, "error")) add("F14", "residuals(simulation_rank) error poisson latent", conditionMessage(rr), "")
}

# 14 latent unique=FALSE extract_correlations vs unique=TRUE on same data - correlations identical wrongly?
set.seed(14)
sim14 <- simulate_unit_trait(40, 1, 3, Lambda_B = matrix(c(0.8, 0.4, 0.1), 3, 1), psi_B = rep(0.3, 3), seed = 14)
ft <- fit_lat(sim14$data, d = 1, unique = TRUE)
ff <- fit_lat(sim14$data, d = 1, unique = FALSE)
if (conv(ft) && conv(ff)) {
  ct <- extract_correlations(ft, link_residual = "none")$correlations
  cf <- extract_correlations(ff, link_residual = "none")$correlations
  if (is.matrix(ct) && is.matrix(cf) && max(abs(ct - cf), na.rm = TRUE) < 1e-6) {
    add("F15", "extract_correlations identical for unique=TRUE vs FALSE despite different Psi models", "", "")
  }
}

# 15 predict type=response on poisson integer check
if (exists("fp") && conv(fp)) {
  pr <- predict(fp, type = "response")
  if (any(pr < 0, na.rm = TRUE)) add("F16", "predict(response) negative on poisson latent", "", "")
}

# 16 nbinom2 only ordinal mix? skip

# 17 simulate_site_trait wide vs long latent
sim17 <- simulate_site_trait(18, 4, 3, mean_species_per_site = 3,
                             Lambda_B = matrix(0.3, 3, 1), psi_B = rep(0.1, 3), seed = 17)
f17 <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
                data = sim17$data, trait = "trait", unit = "site")
if (conv(f17)) {
  if (nobs(f17) != nrow(sim17$data)) add("F17", "nobs != nrow(data) site_trait latent", "", "")
}

# 18 df.residual
dr <- df.residual(fg)
if (is.null(dr)) add("F18", "df.residual() NULL on converged latent gaussian", "", "#1901 duplicate?")

# 19 fitted vs predict response gaussian
if (exists("fg") && conv(fg)) {
  fitv <- fitted(fg)
  prv <- predict(fg, type = "response")
  if (is.numeric(fitv) && is.numeric(prv) && length(fitv) == length(prv) &&
      max(abs(as.vector(fitv) - as.vector(prv)), na.rm = TRUE) > 0.01) {
    add("F19", "fitted() != predict(response) gaussian latent", paste(max(abs(fitv - prv)), collapse = " "), "")
  }
}

# 20 tweedie only latent confint dispersion
set.seed(20)
dat20 <- data.frame(unit = rep(1:18, 3), trait = factor(rep(c("a", "b", "c"), 18)), value = abs(rnorm(54)) + 0.01)
f20 <- fit_lat(dat20, family = tweedie(p = 1.55))
if (conv(f20)) {
  ci <- suppressWarnings(confint(f20))
  if (is.matrix(ci) && any(!is.finite(ci))) add("F20", "confint non-finite tweedie latent", "", "")
}

# 21 simulate conditional vs unconditional flags
# skip deep

# 22 extract_correlations interval coverage point
if (exists("fg") && conv(fg)) {
  c0 <- extract_correlations(fg, link_residual = "none")$correlations
  c1 <- tryCatch(extract_correlations(fg, interval = "wald", link_residual = "none")$correlations,
                 error = function(e) NULL)
  if (is.matrix(c0) && is.matrix(c1) && max(abs(c0 - c1), na.rm = TRUE) > 1e-5) {
    add("F21", "extract_correlations interval mode changes point estimates", "", "")
  }
}

# 22b binomial mixed correct prep converged postfit
set.seed(22)
dat22 <- data.frame(unit = rep(1:25, 2), trait = factor(rep(c("g", "b"), 25), levels = c("g", "b")), value = NA)
dat22$value[dat22$trait == "g"] <- rnorm(25)
dat22$value[dat22$trait == "b"] <- rbinom(25, 1, 0.5)
fams22 <- list(g = gaussian(), b = binomial()); attr(fams22, "family_var") <- "trait"
f22 <- fit_lat(dat22, family = fams22, control = gllvmTMBcontrol(warn_runaway = FALSE))
if (conv(f22)) {
  ll1 <- as.numeric(logLik(f22))
  ll2 <- as.numeric(logLik(f22))
  n1 <- nobs(f22)
  # compare AIC BIC
  bic <- BIC(f22)
  if (is.finite(bic) && bic < AIC(f22)) add("F22", "BIC < AIC on same fit", paste(bic, AIC(f22)), "suspicious")
}

# 23 penalties: loading_ridge Inf logLik at max?
f23 <- fit_lat(sim2$data, control = gllvmTMBcontrol(loading_ridge = Inf))
if (conv(f23)) {
  # gradient check
  mg <- if (!is.null(f23$fit_health$max_gradient)) f23$fit_health$max_gradient else NA_real_
  if (is.finite(mg) && mg > 0.01) add("F23", "converged with loading_ridge=Inf but max_gradient > 0.01", as.character(mg), "")
}

# 24 sim multivariate from simulate() dim names
if (exists("fp") && conv(fp)) {
  s <- simulate(fp, nsim = 2)
  if (is.null(dim(s))) add("F24", "simulate poisson returns vector not matrix when nsim>1", "", "")
}

# 25 extract_residual_split smoke
if (exists("f22") && conv(f22)) {
  er <- tryCatch(extract_residual_split(f22), error = function(e) e)
  if (inherits(er, "error")) add("F25", "extract_residual_split error mixed latent", conditionMessage(er), "")
}

# 26 gaussian latent d=3 n_traits=3 full rank psi
sim26 <- simulate_unit_trait(45, 1, 3, Lambda_B = diag(3), psi_B = rep(0.2, 3), seed = 26)
f26 <- fit_lat(sim26$data, d = 3)
if (conv(f26)) {
  ld <- extract_loadings(f26)
  if (any(abs(ld) > 1e6, na.rm = TRUE)) add("F26", "extract_loadings huge on full-rank d=3", "", "")
}

# 27 logLik duplicate calls identical
if (exists("fg") && conv(fg)) {
  if (abs(as.numeric(logLik(fg)) - as.numeric(logLik(fg))) > 1e-8) add("F27", "logLik not deterministic", "", "unlikely")
}

# 28 predict newdata gaussian rows
if (exists("fg") && conv(fg)) {
  nd <- fg$frame[1:5, c("unit", "trait")]
  pr <- tryCatch(predict(fg, newdata = nd, type = "link"), error = function(e) e)
  if (inherits(pr, "error")) add("F28", "predict newdata error gaussian latent", conditionMessage(pr), "")
}

saveRDS(list(findings = findings, sha = SHA, session = session_txt, n = length(findings)),
        LOG)
cat("Confirmed findings:", length(findings), "\n")
for (f in findings) cat(f$id, f$title, "\n")