# Rscript dev/issue-1467/refit.R /absolute/path/dat.csv /absolute/output/directory [ridge-multistart]
# Uses the loaded package. Keep raw data and fitted objects outside Git.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) %in% c(2L, 3L), file.exists(args[[1L]]))
multistart <- length(args) == 3L
if (multistart && args[[3L]] != "ridge-multistart") stop("Unknown refit mode.")
library(gllvmTMB)
dat <- read.csv(args[[1L]], check.names = FALSE)
needed <- c('word_present', 'analysis_word', 'article_id', 'Fox_Nativeness')
stopifnot(all(needed %in% names(dat)))
if (anyNA(dat[needed])) stop('Missing values require an explicit handling decision.')
if (!all(dat$word_present %in% c(0, 1))) stop('word_present must be Bernoulli 0/1.')
per_unit <- split(dat$Fox_Nativeness, dat$article_id)
if (!all(vapply(per_unit, function(x) length(unique(x)) == 1L, logical(1)))) {
  stop('Fox_Nativeness varies within article_id.')
}
dat$analysis_word <- factor(dat$analysis_word)
dat$article_id <- factor(dat$article_id)
dat$Fox_Nativeness <- relevel(factor(dat$Fox_Nativeness), ref = 'Introduced')
dir.create(args[[2L]], recursive = TRUE, showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), file.path(args[[2L]], 'session-info.txt'))
settings <- list(d1 = list(d = 1L, tau = Inf), d2 = list(d = 2L, tau = Inf),
                 d2_ridge_tau2 = list(d = 2L, tau = 2))
if (multistart) settings <- list(d2_ridge_tau2_multistart = list(d = 2L, tau = 2))
results <- list()
for (label in names(settings)) {
  s <- settings[[label]]
  fit_control <- if (multistart) {
    gllvmTMBcontrol(loading_ridge = s$tau, n_init = 5L, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000)))
  } else gllvmTMBcontrol(loading_ridge = s$tau)
  warnings <- character()
  set.seed(1467)
  elapsed <- system.time(fit <- withCallingHandlers(
    gllvmTMB(word_present ~ 0 + analysis_word +
               latent(0 + analysis_word | article_id, d = s$d, lv = ~ Fox_Nativeness),
             trait = 'analysis_word', unit = 'article_id',
             family = binomial(link = 'probit'), data = dat,
             control = fit_control),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart('muffleWarning')
    }
  ))
  saveRDS(fit, file.path(args[[2L]], paste0(label, '.rds')))
  writeLines(warnings, file.path(args[[2L]], paste0(label, '-warnings.txt')))
  writeLines(capture.output(summary(fit)), file.path(args[[2L]], paste0(label, '-summary.txt')))
  writeLines(capture.output(gllvmTMB_diagnose(fit)), file.path(args[[2L]], paste0(label, '-diagnose.txt')))
  for (kind in c('axis_effect', 'trait_effect')) {
    write.csv(extract_lv_effects(fit, type = kind),
              file.path(args[[2L]], paste0(label, '-', kind, '.csv')), row.names = FALSE)
  }
  ridge_tau <- if (is.null(fit$aghq$ridge_tau)) Inf else fit$aghq$ridge_tau
  gr <- gllvmTMB:::.gllvmTMB_penalised_gradient(fit$tmb_obj, fit$opt$par, ridge_tau)
  # Retain the fit's objective distinctions: ridged estimates are MAP.
  results[[label]] <- data.frame(model = label, d = s$d, ridge_tau = s$tau,
    elapsed_seconds = elapsed[['elapsed']], convergence = fit$opt$convergence,
    pdHess = isTRUE(fit$sd_report$pdHess), max_gradient = max(abs(gr)),
    unpenalised_loglik_at_estimate = as.numeric(suppressWarnings(logLik(fit))),
    penalised_objective = fit$opt$objective)
  grDevices::pdf(file.path(args[[2L]], paste0(label, '-ordination.pdf')))
  tryCatch(ordiplot(fit), finally = grDevices::dev.off())
}
write.csv(do.call(rbind, results), file.path(args[[2L]], 'comparison.csv'), row.names = FALSE)
