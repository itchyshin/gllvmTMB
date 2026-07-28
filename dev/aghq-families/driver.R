## dev/aghq-families/driver.R -- sequential driver over (family x seed)
## cells. DOES NOT PARALLELISE ITSELF: the caller is expected to mclapply
## over the cell list this file builds (e.g. one call per family, or shard
## by seed) -- see the header comment in family_spec.R and the brief this
## harness was built against ("Assume the CALLER parallelises with
## mclapply -- do not spawn workers").
##
## THIS FILE ONLY BUILDS AND RUNS CELLS SEQUENTIALLY, appending one row to
## the output CSV after EVERY cell so a kill mid-run leaves usable partial
## output. A bad cell (simulate() error, fit error, non-finite objective)
## is caught inside run_family() and recorded in that row's `error` column;
## it never aborts the loop.
##
## Environment variables (all optional; defaults shown):
##   AGHQ_FAM_SEEDS      Number of seeds per family, i.e. seeds 1..N.
##                       Default 8 (the kill rule's min_seeds).
##   AGHQ_FAM_K          AGHQ node count. Default 9.
##   AGHQ_FAM_FAMILIES   Comma-separated family names to run. Default: all
##                       16 names from family_spec().
##   AGHQ_FAM_OUT        Output CSV path. Default
##                       "dev/aghq-families/results.csv" (relative to the
##                       working directory the driver is sourced from).
##   AGHQ_FAM_SEED_START Starting seed (for sharding across parallel
##                       callers without seed collisions). Default 1.
##
## SAFETY DEFAULT: sourcing this file does NOT run anything by itself --
## it only defines aghq_fam_run_driver(). You must call that function
## yourself (or set AGHQ_FAM_DRIVER_AUTORUN=1 before sourcing) to run even
## a small cell. This is deliberate: nobody should launch the full 16 x 8
## campaign as a side effect of `source()`.
##
## Usage (single process, small smoke run):
##   source("dev/aghq-families/family_spec.R")
##   source("dev/aghq-families/run_family.R")
##   source("dev/aghq-families/driver.R")
##   aghq_fam_run_driver(n_seeds = 2, families = c("gaussian", "poisson"))
##
## Usage (Totoro-style sharding -- one mclapply call per family, this file
## unchanged, invoked once per shard with AGHQ_FAM_SEED_START offset and
## AGHQ_FAM_SEEDS = seeds-per-shard):
##   parallel::mclapply(family_names, function(fam) {
##     Sys.setenv(AGHQ_FAM_FAMILIES = fam, AGHQ_FAM_DRIVER_AUTORUN = "1")
##     source("dev/aghq-families/driver.R")
##   }, mc.cores = N)

.aghq_fam_driver_write_row <- function(row, path) {
  first <- !file.exists(path)
  utils::write.table(row, file = path, sep = ",", row.names = FALSE,
                      col.names = first, append = !first, qmethod = "double")
}

aghq_fam_run_driver <- function(
  n_seeds    = as.integer(Sys.getenv("AGHQ_FAM_SEEDS", "8")),
  k          = as.integer(Sys.getenv("AGHQ_FAM_K", "9")),
  families   = { f <- Sys.getenv("AGHQ_FAM_FAMILIES", ""); if (identical(f, "")) NULL else strsplit(f, ",")[[1]] },
  out_path   = Sys.getenv("AGHQ_FAM_OUT", "dev/aghq-families/results.csv"),
  seed_start = as.integer(Sys.getenv("AGHQ_FAM_SEED_START", "1"))
) {
  specs <- family_spec()
  if (!is.null(families)) {
    families <- trimws(families)
    specs <- Filter(function(s) s$name %in% families, specs)
    missing_fam <- setdiff(families, vapply(specs, `[[`, character(1), "name"))
    if (length(missing_fam) > 0L) {
      warning("aghq_fam_run_driver: unknown family name(s) ignored: ",
              paste(missing_fam, collapse = ", "))
    }
  }

  seeds <- seq.int(seed_start, seed_start + n_seeds - 1L)
  n_cells <- length(specs) * length(seeds)
  cat(sprintf("aghq-families driver: %d families x %d seeds = %d cells, k = %d -> %s\n",
              length(specs), length(seeds), n_cells, k, out_path))

  t0 <- Sys.time()
  done <- 0L
  for (spec in specs) {
    for (seed in seeds) {
      row <- tryCatch(
        run_family(spec, seed, k),
        error = function(e) {
          ## run_family() already catches everything it can; this is a last-
          ## resort net so a truly unexpected error (e.g. a bug in the
          ## harness itself) still produces a row instead of killing the
          ## whole driver.
          data.frame(family = spec$name, fid = spec$fid, seed = seed, k = k,
                     n = spec$n, p = spec$p, q = spec$q, n_rep = spec$n_rep,
                     objective_laplace = NA_real_, objective_aghq = NA_real_,
                     frob_laplace = NA_real_, frob_aghq = NA_real_,
                     rel_frob_laplace = NA_real_, rel_frob_aghq = NA_real_,
                     attenuation_laplace = NA_real_, attenuation_aghq = NA_real_,
                     convergence_laplace = NA_integer_, convergence_aghq = NA_integer_,
                     aghq_used = NA, aghq_reason = NA_character_,
                     elapsed_laplace = NA_real_, elapsed_aghq = NA_real_,
                     error = paste0("driver-level catch: ", conditionMessage(e)),
                     stringsAsFactors = FALSE)
        }
      )
      .aghq_fam_driver_write_row(row, out_path)
      done <- done + 1L
      cat(sprintf("  [%d/%d] %-18s seed=%-3d %s\n",
                  done, n_cells, spec$name, seed,
                  if (is.na(row$error[1])) "ok" else paste0("ERROR: ", row$error[1])))
    }
  }
  cat(sprintf("driver done: %d cells in %.1f min -> %s\n",
              done, as.numeric(Sys.time() - t0, units = "mins"), out_path))
  invisible(out_path)
}

## SAFETY: default is NOT to autorun. Sourcing this file only defines
## aghq_fam_run_driver(); nothing runs (and no campaign launches) unless the
## caller explicitly sets AGHQ_FAM_DRIVER_AUTORUN=1 first. This harness was
## built to be run deliberately (one family, a couple of seeds, sized by
## hand) or dispatched to Totoro/DRAC by the caller -- never as a side
## effect of `source()`.
if (identical(Sys.getenv("AGHQ_FAM_DRIVER_AUTORUN", "0"), "1")) {
  aghq_fam_run_driver()
}
