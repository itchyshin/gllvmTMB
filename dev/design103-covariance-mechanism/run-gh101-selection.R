args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 5L)
seed <- as.integer(args[1]); n <- as.integer(args[2]); regime <- args[3]
out <- args[4]; src <- args[5]
source("/project/def-snakagaw/snakagaw/design102-20260724/code/R/core.R")
f <- d102_fixture(seed, n, regime)
d <- tempfile("d103-"); dir.create(d)
file.copy(src, file.path(d, "design103_gh.cpp"))
old <- setwd(d); on.exit(setwd(old), add = TRUE)
TMB::compile("design103_gh.cpp", flags = "-O0")
dyn.load(TMB::dynlib("design103_gh"))
gh <- d102_gh(101L)
o <- TMB::MakeADFun(list(y = f$y, gh_nodes = gh$z, gh_weights = gh$w),
                     list(beta = rep(0, 6), loading_free = rep(0, 11)),
                     DLL = "design103_gh", silent = TRUE)
rec <- readRDS(sprintf("/project/def-snakagaw/snakagaw/design102-20260724/records/%s-%s-%s.rds", seed, n, regime))
methods <- lapply(names(d102_methods), function(method) {
  attempts <- rec$attempts[grep(paste0("^", method, "-"), names(rec$attempts))]
  attempts <- Filter(function(x) identical(x$status, "healthy") && is.finite(x$objective) && all(is.finite(c(x$beta, x$lf))), attempts)
  native <- vapply(attempts, `[[`, 0.0, "objective")
  gh101 <- vapply(attempts, function(x) o$fn(c(x$beta, x$lf)), 0.0)
  list(native_objective = native, gh101_nll = gh101,
       native_winner = names(native)[which.max(native)],
       gh101_winner = names(gh101)[which.min(gh101)],
       gh101_gap = max(gh101) - min(gh101))
})
names(methods) <- names(d102_methods)
payload <- list(schema = "design103-gh101-selection-v1", seed = seed, n = n,
                regime = regime, gh_n = 101L, methods = methods)
tmp_out <- paste0(out, ".tmp-", Sys.getpid())
saveRDS(payload, tmp_out)
if (!file.rename(tmp_out, out)) stop("atomic receipt rename failed")
