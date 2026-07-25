#!/usr/bin/env Rscript

# Design 89: this runner intentionally contains exactly the upstream fixture
# preparation and gllvm() call. It must be executed once only after its source
# lock has been reviewed. It does not fit gllvmTMB or construct a new fixture.

locked_library <- Sys.getenv("D89_GLLVM_LIB", unset = "")
if (!nzchar(locked_library) || !dir.exists(locked_library)) {
  stop("Set D89_GLLVM_LIB to the locked private gllvm library.")
}
.libPaths(c(locked_library, .libPaths()))
if (!requireNamespace("gllvm", quietly = TRUE)) stop("Locked gllvm is unavailable.")
if (as.character(utils::packageVersion("gllvm")) != "2.0.13") {
  stop("Design 89 requires locked gllvm 2.0.13.")
}
library(gllvm)

result_dir <- file.path("dev", "design89-upstream-reference", "results")
result_file <- file.path(result_dir, "upstream-reference-result.rds")
json_file <- file.path(result_dir, "upstream-reference-result.json")
if (file.exists(result_file) || file.exists(json_file)) {
  stop("A Design-89 result already exists; the one-call rule forbids rerun.")
}
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)

capture <- character()
warnings <- character()
call_error <- NULL
fit <- withCallingHandlers(
  tryCatch({
    # Begin verbatim fixture preparation from test-fitgllvm.R.
    data("kelpforest", package = "gllvm")
    SPinfo <- kelpforest$SPinfo
    y<- (kelpforest$Y[kelpforest$X$YEAR<2004 & (kelpforest$X$SITE!="AHND"),SPinfo$GROUP=="ALGAE"]>0)*1
    X<- kelpforest$X[kelpforest$X$YEAR<2004 & (kelpforest$X$SITE!="AHND"),]
    studyDesign = data.frame(site = factor(X$SITE), transect = factor(X$TRANSECT), st = factor(paste(X$SITE, X$TRANSECT, sep = "")), YEAR=factor(X$YEAR))
    y<- y[,colSums(y>0, na.rm = TRUE)>9]
    distm = matrix(X$YEAR-min(X$YEAR))
    disty <- c((table(studyDesign$YEAR, studyDesign$site)>0)*(1:4))
    disty<- matrix(disty[disty>0])

    # Exact upstream EVA invocation (test-fitgllvm.R:278-279).
    fitlv2ar1cy = gllvm(y,scale(X[,4:5]), family = "binomial", method="EVA", num.lv.c = 1, Lambda.struc="diagonal", seed = 1, sd.errors=FALSE, starting.val ="zero",
                    studyDesign = studyDesign, lvCor = ~corAR1(0 + YEAR|site), corWithinLV = TRUE)
    fitlv2ar1cy
  }, error = function(e) { call_error <<- conditionMessage(e); NULL }),
  warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") },
  message = function(m) { capture <<- c(capture, conditionMessage(m)); invokeRestart("muffleMessage") }
)

finite_or_false <- function(x) is.numeric(x) && length(x) > 0L && all(is.finite(x))
rho_assertion <- FALSE
lv_dimension_assertion <- FALSE
convergence <- FALSE
log_likelihood <- NA_real_
parameters <- numeric()
gradient <- numeric()
if (!is.null(fit)) {
  rho_assertion <- isTRUE(all(round(fit$params$rho.lv, digits = 2) - c(0.85) < 0.1))
  lv_dimension_assertion <- isTRUE(all(dim(fit$lvs) == c(27, 1)))
  # gllvm.TMB.R stores this as the logical success flag `optrFinal$convergence == 0`.
  convergence <- isTRUE(fit$convergence)
  log_likelihood <- fit$logL
  parameters <- unlist(fit$params, recursive = TRUE, use.names = TRUE)
  gradient <- tryCatch(fit$TMBfn$gr(fit$TMBfn$par), error = function(e) numeric())
}
max_abs_gradient <- if (finite_or_false(gradient)) max(abs(gradient)) else NA_real_
strict_health <- !is.null(fit) && rho_assertion && lv_dimension_assertion &&
  finite_or_false(log_likelihood) && finite_or_false(parameters) && convergence &&
  is.finite(max_abs_gradient) && max_abs_gradient <= 0.05
verdict <- if (strict_health) "UPSTREAM_REFERENCE_PASS" else "UPSTREAM_REFERENCE_STOP"

result <- list(
  design = "Design 89 — upstream-reference EVA reproducer",
  verdict = verdict,
  executed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  gllvm_version = as.character(utils::packageVersion("gllvm")),
  gllvm_library = find.package("gllvm"),
  r_version = R.version.string,
  tmb_version = if (requireNamespace("TMB", quietly = TRUE)) as.character(utils::packageVersion("TMB")) else NA_character_,
  fixture = "upstream test-fitgllvm.R: corWithinLV works / fitlv2ar1cy",
  upstream_assertions = list(rho_lv = rho_assertion, lvs_dimension = lv_dimension_assertion),
  diagnostics = list(convergence = convergence, log_likelihood = log_likelihood,
                     parameters_finite = finite_or_false(parameters),
                     gradient_finite = finite_or_false(gradient), max_abs_gradient = max_abs_gradient,
                     warnings = warnings, messages = capture, error = call_error),
  health_rule = "source identity + upstream assertions + finite objective/parameters + convergence + finite max|gradient| <= 0.05"
)
saveRDS(result, result_file)
if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(result, json_file, auto_unbox = TRUE, pretty = TRUE, null = "null")
} else {
  writeLines(c("{", paste0('  "verdict": "', verdict, '",'), paste0('  "error": ', dQuote(ifelse(is.null(call_error), "", call_error))), "}"), json_file)
}
message(verdict)
if (!strict_health) quit(status = 2L)
