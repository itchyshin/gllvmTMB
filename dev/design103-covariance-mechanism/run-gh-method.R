args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 9L)
seed <- as.integer(args[1]); n <- as.integer(args[2]); regime <- args[3]
method <- args[4]; gh_n <- as.integer(args[5]); iter_max <- as.integer(args[6])
sentinel_n <- as.integer(args[7]); out <- args[8]; src <- args[9]
source("/project/def-snakagaw/snakagaw/design102-20260724/code/R/core.R")
stopifnot(method %in% names(d102_methods), gh_n %in% c(61L, 101L), sentinel_n %in% c(0L, 101L))
f <- d102_fixture(seed, n, regime)
d <- tempfile("d103-"); dir.create(d)
file.copy(src, file.path(d, "design103_gh.cpp"))
old <- setwd(d); on.exit(setwd(old), add = TRUE)
TMB::compile("design103_gh.cpp", flags = "-O0")
dyn.load(TMB::dynlib("design103_gh"))
rec <- readRDS(sprintf("/project/def-snakagaw/snakagaw/design102-20260724/records/%s-%s-%s.rds", seed, n, regime))
attempts <- rec$attempts[grep(paste0("^", method, "-"), names(rec$attempts))]
healthy <- Filter(function(x) identical(x$status, "healthy") && is.finite(x$objective) && all(is.finite(c(x$beta, x$lf))), attempts)
if (!length(healthy)) stop("no healthy native endpoint")
winner <- healthy[[which.max(vapply(healthy, `[[`, 0.0, "objective"))]]
make_obj <- function(nodes) {
  gh <- d102_gh(nodes)
  TMB::MakeADFun(list(y = f$y, gh_nodes = gh$z, gh_weights = gh$w), list(beta = winner$beta, loading_free = winner$lf), DLL = "design103_gh", silent = TRUE)
}
if (sentinel_n == 101L) {
  o101_start <- make_obj(101L)
  score101 <- function(endpoint) o101_start$fn(c(endpoint$beta, endpoint$lf))
  selection101 <- vapply(healthy, score101, 0.0)
  endpoint101 <- score101(winner)
  rm(o101_start); gc(verbose = FALSE)
} else {
  selection101 <- NULL; endpoint101 <- NA_real_
}
o <- make_obj(gh_n)
start <- c(winner$beta, winner$lf)
t0 <- proc.time()[["elapsed"]]
fit <- nlminb(start, o$fn, o$gr, control = list(iter.max = iter_max, eval.max = iter_max + 40L))
elapsed <- proc.time()[["elapsed"]] - t0
fit_grad <- max(abs(o$gr(fit$par)))
rm(o); gc(verbose = FALSE)
if (sentinel_n == 101L) {
  o101_terminal <- make_obj(101L)
  terminal101 <- o101_terminal$fn(fit$par)
  rm(o101_terminal); gc(verbose = FALSE)
} else terminal101 <- NA_real_
L <- d102_loading(fit$par[7:17])
payload <- list(
  schema = "design103-gh-method-v1", seed = seed, n = n, regime = regime,
  method = method, gh_refit = gh_n, iter_max = iter_max, sentinel_n = sentinel_n,
  native_winner = list(beta = winner$beta, lf = winner$lf, objective = winner$objective,
                       sigma_rel = winner$sigma_rel, beta_rmse = winner$beta_rmse),
  selection101 = selection101,
  gh101 = list(endpoint_nll = endpoint101, terminal_nll = terminal101,
               endpoint_gap = endpoint101 - terminal101),
  fit = list(code = fit$convergence, message = fit$message,
             grad = fit_grad, nll = fit$objective, elapsed_sec = elapsed,
             beta_rmse = sqrt(mean((fit$par[1:6] - f$beta)^2)),
             sigma_rel = sqrt(sum((tcrossprod(L) - tcrossprod(f$L))^2)) / sqrt(sum(tcrossprod(f$L)^2))),
  terminal = list(beta = fit$par[1:6], lf = fit$par[7:17])
)
tmp_out <- paste0(out, ".tmp-", Sys.getpid())
saveRDS(payload, tmp_out)
if (!file.rename(tmp_out, out)) stop("atomic receipt rename failed")
