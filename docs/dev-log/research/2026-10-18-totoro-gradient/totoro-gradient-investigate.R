args <- commandArgs(TRUE)
.libPaths(unique(c(args[1], path.expand('~/R/lib'), .libPaths())))
suppressPackageStartupMessages(library(gllvmTMB))
options(gllvmTMB.quiet_grammar_notes = TRUE)
dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
ex <- readRDS(system.file('extdata', 'examples', 'behavioural-reaction-norm-example.rds', package = 'gllvmTMB'))
fit_one <- function(label, wide = FALSE, reltol = NULL) {
  opt <- list(method = 'BFGS')
  if (!is.null(reltol)) opt$control <- list(reltol = reltol)
  call <- list(formula = if (wide) ex$formula_wide else ex$formula_long,
    data = if (wide) ex$data_wide else ex$data_long,
    unit = ex$fit_args$unit, unit_obs = ex$fit_args$unit_obs,
    family = ex$fit_args$family,
    control = gllvmTMBcontrol(se = FALSE, optimizer = 'optim', optArgs = opt, loading_ridge = Inf))
  if (!wide) call$trait <- ex$fit_args$trait
  tm <- system.time(fit <- suppressMessages(suppressWarnings(do.call(gllvmTMB, call))))
  h <- check_gllvmTMB(fit)
  obj <- fit$tmb_obj
  gradient <- obj$gr(fit$opt$par)
  record <- list(label = label, elapsed = unname(tm['elapsed']), opt = fit$opt,
    max_gradient = max(abs(gradient)), gradient = gradient,
    parameter_names = names(fit$opt$par), fit_health = fit$fit_health,
    loading_ridge = call$control$loading_ridge,
    diagnostic = h[h$component %in% c('optimizer_convergence', 'max_gradient'), ],
    fixed = tidy(fit, effects = 'fixed'), Sigma = extract_Sigma(fit, level = 'unit_slope', part = 'total')$Sigma)
  saveRDS(record, file.path(args[2], paste0(label, '.rds')))
  jsonlite::write_json(record, file.path(args[2], paste0(label, '.json')), auto_unbox = TRUE, pretty = TRUE, digits = 16)
  cat(label, 'elapsed', record$elapsed, 'objective', fit$opt$objective, 'gradient', record$max_gradient, '\n')
  flush.console()
  record
}
out <- list(baseline = fit_one('baseline'), tight10 = fit_one('tight10', reltol = 1e-10),
  tight12 = fit_one('tight12', reltol = 1e-12), wide10 = fit_one('wide10', TRUE, 1e-10))
saveRDS(out, file.path(args[2], 'comparison.rds'))
capture.output(sessionInfo(), file = file.path(args[2], 'session-info.txt'))
