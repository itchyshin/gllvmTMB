## ADVERSARIAL #856 -- ITEM 1: are the surviving broadcast fallbacks REACHABLE
## on a MULTI-TRAIT fit through a PUBLIC entry point?
##
## Sites under attack:
##   R/methods-gllvmTMB.R:329  `rep(sigma_eps[1L], n)` in .apply_linkinv_per_row
##   R/methods-gllvmTMB.R:1157 `rep(sigma[1L], length(eta))` in simulate(newdata=)
##   R/predictive-diagnostics.R:406 `sigma_eps[1L]` when tid out of range
##
## Strategy: instrument each fallback with a global flag, then drive every
## public entry point (predict/predict(newdata)/simulate/simulate(newdata)/
## residuals) on a 2-trait fit with WELL-SEPARATED per-trait sigma_eps, and
## record (a) whether the fallback branch executed, (b) whether the NUMBERS
## are the per-trait-correct ones.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

FLAG <- new.env(parent = emptyenv())
reset_flags <- function() {
  FLAG$linkinv_fallback <- FALSE
  FLAG$linkinv_called <- FALSE
  FLAG$sim_nd_fallback <- FALSE
  FLAG$resid_oob <- FALSE
}
reset_flags()

## ---- instrument .apply_linkinv_per_row -----------------------------------
orig_linkinv <- gllvmTMB:::.apply_linkinv_per_row
patched_linkinv <- function(eta, family_id, link_id, sigma_eps = NULL,
                            trait_id_1 = NULL) {
  FLAG$linkinv_called <- TRUE
  n <- length(eta)
  se <- as.numeric(sigma_eps %||% 0)
  took_fallback <- !(!is.null(trait_id_1) && length(trait_id_1) == n && length(se))
  if (took_fallback) FLAG$linkinv_fallback <- TRUE
  orig_linkinv(eta, family_id, link_id, sigma_eps, trait_id_1)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

assignInNamespace(".apply_linkinv_per_row", patched_linkinv, ns = "gllvmTMB")

cat("################ FIXTURE: 2-trait LOGNORMAL, sigma 0.2 vs 1.2 ##########\n")
set.seed(9001)
n_unit <- 80L
true_sig <- c(a = 0.2, b = 1.2)
long <- do.call(rbind, lapply(1:2, function(t) {
  data.frame(unit = seq_len(n_unit), trait_idx = t)
}))
long$value <- exp(rnorm(nrow(long), mean = 1, sd = true_sig[long$trait_idx]))
long$unit <- factor(long$unit)
long$trait <- factor(c("a", "b")[long$trait_idx], levels = c("a", "b"))

fit <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait, data = long, unit = "unit", trait = "trait",
  family = lognormal()
)))
sig <- as.numeric(fit$report$sigma_eps)
cat("convergence:", fit$opt$convergence, " sigma_eps:", signif(sig, 5),
    " (length", length(sig), ")\n")
cat("TRUE:", true_sig, "\n\n")

## ---- E1: predict(type='response'), training rows -------------------------
reset_flags()
pr <- predict(fit, type = "response")
eta <- predict(fit, type = "link")$est
exp_correct <- exp(eta + 0.5 * sig[as.integer(long$trait)]^2)
exp_wrong   <- exp(eta + 0.5 * sig[1L]^2)
cat("E1 predict(response) training rows\n")
cat("   fallback branch taken:", FLAG$linkinv_fallback, "\n")
cat("   max|pred - PER-TRAIT correct| :", signif(max(abs(pr$est - exp_correct)), 4), "\n")
cat("   max|pred - trait-1 broadcast| :", signif(max(abs(pr$est - exp_wrong)), 4), "\n\n")

## ---- E2: predict(newdata=), BOTH traits ----------------------------------
reset_flags()
nd <- long[c(1:5, (n_unit + 1):(n_unit + 5)), c("unit", "trait", "value")]
pr2 <- predict(fit, newdata = nd, type = "response")
eta2 <- predict(fit, newdata = nd, type = "link")$est
c2 <- exp(eta2 + 0.5 * sig[as.integer(nd$trait)]^2)
w2 <- exp(eta2 + 0.5 * sig[1L]^2)
cat("E2 predict(newdata, response) both traits\n")
cat("   fallback branch taken:", FLAG$linkinv_fallback, "\n")
cat("   max|pred - PER-TRAIT|:", signif(max(abs(pr2$est - c2)), 4),
    "  max|pred - trait1|:", signif(max(abs(pr2$est - w2)), 4), "\n\n")

## ---- E3: predict(newdata=), TRAIT 2 ONLY (level-index hazard) ------------
reset_flags()
nd3 <- long[(n_unit + 1):(n_unit + 10), c("unit", "trait", "value")]
nd3$trait <- droplevels(nd3$trait) # user passes a factor with ONLY level "b"
cat("E3 newdata trait column levels:", paste(levels(nd3$trait), collapse = ","),
    " (as.integer ->", paste(unique(as.integer(nd3$trait)), collapse = ","), ")\n")
pr3 <- predict(fit, newdata = nd3, type = "response")
eta3 <- predict(fit, newdata = nd3, type = "link")$est
c3 <- exp(eta3 + 0.5 * sig[2L]^2)
w3 <- exp(eta3 + 0.5 * sig[1L]^2)
cat("   fallback branch taken:", FLAG$linkinv_fallback, "\n")
cat("   max|pred - trait2 (CORRECT)|:", signif(max(abs(pr3$est - c3)), 4),
    "  max|pred - trait1 (WRONG)|:", signif(max(abs(pr3$est - w3)), 4), "\n\n")

## ---- E4: predict(newdata=) with CHARACTER trait column -------------------
reset_flags()
nd4 <- nd3
nd4$trait <- as.character(nd4$trait)
pr4 <- tryCatch(predict(fit, newdata = nd4, type = "response"),
                error = function(e) e)
if (inherits(pr4, "error")) {
  cat("E4 character trait column -> ERROR:", conditionMessage(pr4), "\n\n")
} else {
  cat("E4 character trait column: fallback:", FLAG$linkinv_fallback,
      " max|pred - trait2|:", signif(max(abs(pr4$est - c3)), 4),
      " max|pred - trait1|:", signif(max(abs(pr4$est - w3)), 4), "\n\n")
}

cat("################ FIXTURE 2: 2-trait GAUSSIAN, sigma 0.1 vs 5.0 #########\n")
set.seed(8561)
g <- do.call(rbind, lapply(1:2, function(t) {
  data.frame(unit = rep(seq_len(60L), each = 4L), trait_idx = t)
}))
gs <- c(0.1, 5.0)
g$value <- rnorm(nrow(g), mean = c(2, 5)[g$trait_idx], sd = gs[g$trait_idx])
g$unit <- factor(g$unit)
g$trait <- factor(paste0("t", g$trait_idx))
fitg <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait, data = g, unit = "unit", trait = "trait"
)))
sg <- as.numeric(fitg$report$sigma_eps)
cat("convergence:", fitg$opt$convergence, " sigma_eps:", signif(sg, 5), "\n")
cat("TRUE: 0.1 5.0\n\n")

## ---- E5: simulate(newdata=) ---------------------------------------------
## Instrument the simulate() newdata fallback by checking the branch predicate
## directly on the object, then measure the empirical sd of the draws.
reset_flags()
ndg <- g[, c("unit", "trait", "value")]
cat("E5 simulate(newdata=)\n")
cat("   object$trait_col:", fitg$trait_col %||% "NULL",
    " present in predict(newdata) output:",
    fitg$trait_col %in% names(predict(fitg, newdata = ndg)), "\n")
simn <- suppressWarnings(suppressMessages(
  simulate(fitg, nsim = 300L, seed = 11L, newdata = ndg)
))
sd_by <- vapply(split(seq_len(nrow(simn)), g$trait), function(rows) {
  mean(apply(simn[rows, , drop = FALSE], 2L, sd))
}, numeric(1))
cat("   empirical sd of draws by trait:", signif(sd_by, 4), "\n")
cat("   fitted sigma_eps by trait      :", signif(sg, 4), "\n")
cat("   if broadcast, BOTH would be    :", signif(sg[1L], 4), "\n\n")

## ---- E6: simulate() no-newdata (both paths) ------------------------------
sim_cond <- simulate(fitg, nsim = 300L, seed = 12L, condition_on_RE = TRUE)
sdc <- vapply(split(seq_len(nrow(sim_cond)), g$trait), function(rows) {
  mean(apply(sim_cond[rows, , drop = FALSE], 2L, sd))
}, numeric(1))
cat("E6 simulate(condition_on_RE=TRUE) sd by trait:", signif(sdc, 4), "\n")
sim_unc <- suppressWarnings(suppressMessages(simulate(fitg, nsim = 300L, seed = 13L)))
sdu <- vapply(split(seq_len(nrow(sim_unc)), g$trait), function(rows) {
  mean(apply(sim_unc[rows, , drop = FALSE], 2L, sd))
}, numeric(1))
cat("E6 simulate(default/unconditional) sd by trait:", signif(sdu, 4), "\n\n")

## ---- E7: residuals() exact CDF ------------------------------------------
res <- residuals(fitg, type = "randomized_quantile")
ub <- split(res$u, res$trait)
cat("E7 residuals() u by trait: mean/sd\n")
for (nm in names(ub)) {
  cat("   ", nm, ": mean =", signif(mean(ub[[nm]]), 4),
      " sd =", signif(sd(ub[[nm]]), 4), " (target 0.5 / 0.2887)\n")
}
cat("   statuses:", paste(unique(res$status), collapse = ","), "\n\n")

cat("################ E8: LOGNORMAL through residuals() #####################\n")
resl <- residuals(fit, type = "randomized_quantile")
cat("E8 lognormal residuals statuses:", paste(unique(resl$status), collapse = ","), "\n")
