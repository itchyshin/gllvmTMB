## Rscript 1_run.R --ids 1:100 --cores 4 --out DIR [--lib LIB] [--check-auto K]
## The launcher must ALSO export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
args <- commandArgs(trailingOnly = TRUE)
getarg <- function(flag, default = NULL) {
  i <- match(flag, args); if (is.na(i)) default else args[i + 1L]
}
ids_arg <- getarg("--ids"); ids_file <- getarg("--ids-file")
cores <- as.integer(getarg("--cores", "1"))
out <- getarg("--out", Sys.getenv("AUTOD_OUT", "docs/dev-log/lanes/auto-d-recovery/sim/out"))
lib <- getarg("--lib"); check_auto <- as.integer(getarg("--check-auto", "0"))
if (!is.null(lib)) .libPaths(c(lib, .libPaths()))
script_dir <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) dirname(normalizePath(sub("^--file=", "", a[1]))) else "."
})
library(gllvmTMB)
source(file.path(script_dir, "sim_dgp.R"))
source(file.path(script_dir, "sim_fit.R"))

grid <- readRDS(file.path(out, "grid.rds"))
ids <- if (!is.null(ids_file)) as.integer(scan(ids_file, quiet = TRUE)) else if (!is.null(ids_arg)) {
  p <- strsplit(ids_arg, ":", fixed = TRUE)[[1]]
  if (length(p) == 2L) seq.int(as.integer(p[1]), as.integer(p[2])) else as.integer(strsplit(ids_arg, ",")[[1]])
} else stop("give --ids a:b (or a,b,c) or --ids-file")
resdir <- file.path(out, "res"); dir.create(resdir, recursive = TRUE, showWarnings = FALSE)
si <- file.path(out, "sessionInfo.txt")
if (!file.exists(si)) writeLines(capture.output(sessionInfo()), si)
auto_ids <- head(ids, check_auto)

run_task <- function(id) {
  f <- file.path(resdir, sprintf("task_%05d.rds", id))
  if (file.exists(f)) return(invisible("skip"))
  row <- grid[grid$task_id == id, ]
  dat <- sim_dataset(row$family, row$n_units, row$n_traits, row$d, row$seed)
  fo <- fit_one(dat, row$family, row$n_traits)
  auto_d <- NA_integer_
  if (id %in% auto_ids) {
    af <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = "auto", unique = FALSE),
      data = dat, family = .family_obj(row$family),
      unit = "unit", trait = "trait", control = .fit_ctrl()))),
      error = function(e) e)
    auto_d <- if (inherits(af, "error")) NA_integer_ else as.integer(af$select_lv$selected_d)
  }
  saveRDS(list(grid = row, fit = fo, redraws = attr(dat, "redraws"),
               degenerate_after_redraws = attr(dat, "degenerate_after_redraws"),
               auto_d = auto_d), f)
  invisible("done")
}
r <- parallel::mclapply(ids, function(i) tryCatch(run_task(i), error = function(e) paste("ERR", i, conditionMessage(e))),
                        mc.cores = cores, mc.preschedule = FALSE)
errs <- Filter(function(x) is.character(x) && startsWith(x, "ERR"), r)
cat(length(ids), "ids;", sum(unlist(r) == "done", na.rm = TRUE), "run;", length(errs), "errors\n")
if (length(errs)) print(unlist(errs))
