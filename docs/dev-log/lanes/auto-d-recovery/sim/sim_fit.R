## One dataset -> select_lv() sweep and per-criterion selected d (design.md M/E).
## Needs library(gllvmTMB) loaded. NB family constructor: gllvmTMB::nbinom2().
.family_obj <- function(family) {
  switch(family,
    gaussian = stats::gaussian(), poisson = stats::poisson(),
    binomial = stats::binomial(), nbinom2 = gllvmTMB::nbinom2(),
    stop("unknown family: ", family))
}
.fit_ctrl <- function() {
  gllvmTMB::gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"), se = FALSE)
}

fit_one <- function(dat, family, n_traits, binary_ridge = 2) {
  crits <- c("bic_sites", "bic", "aic", "aicc")
  n_warn <- 0L
  t0 <- proc.time()[["elapsed"]]
  res <- tryCatch(
    withCallingHandlers(
      gllvmTMB::select_lv(
        value ~ 0 + trait + latent(0 + trait | unit, unique = FALSE),
        data = dat, family = .family_obj(family), unit = "unit", trait = "trait",
        control = .fit_ctrl(), d_max = min(5L, n_traits - 1L), binary_ridge = binary_ridge),
      warning = function(w) {
        n_warn <<- n_warn + 1L
        invokeRestart("muffleWarning")
      }),
    error = function(e) e)
  seconds <- proc.time()[["elapsed"]] - t0
  sel <- stats::setNames(rep(NA_integer_, 4L), crits)
  if (inherits(res, "error")) {
    return(list(table = NULL, sel = sel, aborted = TRUE,
                abort_class = class(res)[1L], abort_message = conditionMessage(res),
                n_warn = n_warn, seconds = seconds, bic_sites_pkg = NA_integer_))
  }
  tab <- res$table
  elig <- tab$status %in% c("ok", "warm_start")
  for (cr in crits) {
    v <- tab[[cr]]; v[!elig] <- NA_real_
    if (any(!is.na(v))) sel[cr] <- as.integer(tab$d[which.min(v)])
  }
  list(table = tab, sel = sel, aborted = FALSE, abort_class = NA_character_,
       abort_message = NA_character_, n_warn = n_warn, seconds = seconds,
       bic_sites_pkg = as.integer(res$selected_d))
}
