## dev/m3-pilot-local-loop.R
## =========================
## Design 66 power-study -- SECOND (local) accumulation engine.
##
## A continuous, resumable, fail-soft loop that accumulates pilot reps on
## the maintainer's Mac, IN PARALLEL with (and independent of) the durable
## GitHub Actions cron (.github/workflows/power-pilot-sweep.yaml). It is a
## THIN driver over the validated accumulate engine in
## dev/m3-pilot-launch.R (run_accumulate_pilot_batch / pilot_accum_status /
## pilot_grid). It does NOT reimplement the DGP, the estimand machinery, or
## the accumulation logic -- it only schedules parallel calls to that
## engine with a DISJOINT seed namespace and a SEPARATE local store.
##
## WHY a second engine: the GHA cron is durable but rate-limited (~2 h
## cadence, concurrency-locked). Running a capped local pool in parallel
## adds reps faster while leaving the cron untouched. Because the two use
## DISJOINT seeds (below) their per-cell .rds stores are later COMBINABLE
## (rbind of independent draws) without double-counting any RNG draw.
##
## ---------------------------------------------------------------------
## CORE CAP: <= 10 cores.
##   LOCAL_CORES (default 10) workers via parallel::makeCluster(). The
##   pool size is the ONLY source of parallelism here (each worker runs
##   ONE cell sequentially, n_cores_boot = 1), so the process never uses
##   more than LOCAL_CORES cores. Lower it to leave more headroom.
##
## ---------------------------------------------------------------------
## DISJOINT-SEED SCHEME (local reps can NEVER collide with GHA reps):
##   Both engines call run_accumulate_pilot_batch(), which derives a
##   per-(cell,batch) seed base via a seed_fn(run_seed_base, cell_seed_base)
##   and m3_run_cell() then derives rep_seed = batch_seed_base + 1000*d +
##   100000*family_index + r. Two reps share an RNG draw IFF their rep_seed
##   coincide. So local+GHA are combinable IFF their rep_seed SETS are
##   disjoint.
##
##   GHA seed_fn (pilot_accum_batch_seed, UNCHANGED):
##     batch_seed_base = 700000 + run_number*5e6 + cell_seed_base
##     -> blocks for run_number = 1, 2, 3, ... (small monotonic integers;
##        ~84 runs in a 1-week campaign, ~12/day). The engine itself only
##        stays 32-bit fold-free to run_number ~429 and assumes a campaign
##        ends well before that.
##
##   LOCAL seed_fn (local_accum_batch_seed, THIS file):
##     batch_seed_base = LOCAL_SEED_BASE0 + (iteration mod LOCAL_SEED_LANES)
##                       * LOCAL_SEED_STRIDE + cell_seed_base
##     with LOCAL_SEED_BASE0 = 1.007e9, LOCAL_SEED_STRIDE = 1e6,
##     LOCAL_SEED_LANES = 800. The local band is [~1.0077e9 .. ~1.807e9],
##     all < .Machine$integer.max (2.147e9) -> NO fold.
##
##   Disjointness (verified numerically, see PR body): the SMALLEST GHA
##   run_number whose block could arithmetically reach the local band is
##   202 (~17 days of cron). A 1-week campaign uses ~84 GHA runs -> a
##   ~118-run (~10-day) margin. No GHA run in 1..200 touches the local
##   band, and every local lane is < imax (fold-free). LOCAL_SEED_STRIDE
##   (1e6) exceeds one batch's rep_seed span (~5.02e5 + step) so distinct
##   local iterations also never overlap EACH OTHER. The loop exits at the
##   cap long before LOCAL_SEED_LANES (800) iterations, so the mod never
##   wraps in practice (a wrap would merely reuse a lane, never collide
##   with GHA).
##
## ---------------------------------------------------------------------
## STORE: dev/m3-pilot-results-local/  (SEPARATE from the GHA branch
##   store dev/m3-pilot-results). It is under dev/ (in .Rbuildignore, so
##   never shipped) and is added to .gitignore (so local reps never commit
##   to main). Resumable: on (re)start the loop re-reads the store and
##   skips cells already at the cap. Combine with the GHA store offline.
##
## CONCURRENCY-SAFE INDEX: run_accumulate_pilot_batch() rewrites a single
##   shared pilot-index.rds after each cell. To avoid 10 workers racing on
##   that one file, each worker accumulates ITS cell inside a private temp
##   results_dir (seeded with a copy of just that cell's prior .rds); the
##   PARENT then copies each worker's updated per-cell .rds back into the
##   canonical local store and rebuilds the single index from disk via
##   pilot_load_index() (the same single-writer / rebuild-from-disk
##   pattern the GHA persist job uses). The per-cell .rds files are the
##   source of truth; the index is a derived cache.
##
## ---------------------------------------------------------------------
## CONTROLS:
##   --cap=N      / env LOCAL_N_SIM_CAP  : accumulated reps target per cell
##                                          (default 10000; same high cap as
##                                          the raised GHA cron).
##   --step=N     / env LOCAL_N_SIM_STEP : reps ADDED per cell per iteration
##                                          (default 150).
##   --cores=N    / env LOCAL_CORES      : worker pool size (default 10).
##   STOP FLAG    : dev/STOP-LOCAL-PILOT : if this file exists, the loop
##                                          finishes the current batch and
##                                          exits cleanly (no kill needed).
##   AUTO-STOP    : exits when every cell has reached the cap.
##
## This file is in dev/ (.Rbuildignore) -- NOT shipped with the package.
## It is a RUNTIME script, so Sys.time() (wall-clock logging / sleeps) is
## intentionally allowed here (unlike the deterministic workflow scripts).

suppressWarnings(suppressMessages({
  ## Load gllvmTMB itself (the harness fits models with it) and the
  ## harness + accumulate engine.
  library(gllvmTMB)
  source("dev/m3-grid.R")
  source("dev/m3-pilot-launch.R")
}))

## ---- Argument / environment parsing -----------------------------------

.local_args <- commandArgs(trailingOnly = TRUE)

.local_arg <- function(name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- .local_args[startsWith(.local_args, prefix)]
  if (length(hit) == 0L) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

## Resolve one integer setting from (1) --flag=, (2) env var, (3) default.
.local_int_setting <- function(flag, env, default) {
  v <- .local_arg(flag, NULL)
  if (is.null(v)) {
    v <- Sys.getenv(env, "")
  }
  if (!nzchar(as.character(v))) {
    return(as.integer(default))
  }
  out <- suppressWarnings(as.integer(v))
  if (is.na(out)) {
    return(as.integer(default))
  }
  out
}

## ---- Local engine constants -------------------------------------------

## Worker pool size == the hard core cap. EXACTLY this many workers; the
## process never uses more than this many cores. Easy to change.
LOCAL_CORES <- .local_int_setting("--cores", "LOCAL_CORES", 10L)

## Reps ADDED per cell per iteration (Design 66 step). Modest so a stop
## flag / Ctrl-C loses at most one small batch per worker.
LOCAL_N_SIM_STEP <- .local_int_setting("--step", "LOCAL_N_SIM_STEP", 150L)

## Accumulated-reps target per cell. Default 10000 == the raised GHA cron
## cap, so both engines accumulate toward the same target.
LOCAL_N_SIM_CAP <- .local_int_setting("--cap", "LOCAL_N_SIM_CAP", 10000L)

## n_boot for the primary Sigma_unit_diag bootstrap CI (pilot default;
## matches the GHA N_BOOT=25).
LOCAL_N_BOOT <- .local_int_setting("--n-boot", "LOCAL_N_BOOT", PILOT_N_BOOT_DEFAULT)

## Seconds to sleep between iterations (lets the OS breathe; cheap).
LOCAL_SLEEP_S <- .local_int_setting("--sleep", "LOCAL_SLEEP_S", 5L)

## SEPARATE local store (NOT the GHA branch store dev/m3-pilot-results).
LOCAL_RESULTS_DIR <- "dev/m3-pilot-results-local"

## Stop-flag file: create it to halt the loop cleanly after the current
## batch (no kill / no SIGTERM needed).
LOCAL_STOP_FLAG <- "dev/STOP-LOCAL-PILOT"

## Run-time log (one line per batch). Appended to.
LOCAL_LOG <- "dev/m3-pilot-local.log"

## ---- Disjoint local seed scheme ---------------------------------------
## See the header's DISJOINT-SEED SCHEME block for the full argument and
## the numeric disjointness proof. These three constants place every local
## rep_seed in a high 32-bit band that GHA's run-number-driven scheme
## cannot reach within (well beyond) the 1-week campaign, and keep all
## local seeds < .Machine$integer.max (no fold).

## Local band floor: above GHA's block for run_number 200 (~1.0019e9),
## rounded clear with margin. GHA run 1..200 (~16 days of 2-hourly cron)
## never reaches this.
LOCAL_SEED_BASE0 <- 1007000000

## Per-iteration stride. > one batch's rep_seed span (~5.02e5 + step), so
## consecutive local iterations occupy disjoint rep_seed blocks.
LOCAL_SEED_STRIDE <- 1000000

## Number of distinct iteration lanes before the (defensive) modular wrap.
## (LOCAL_SEED_BASE0 + LOCAL_SEED_LANES * LOCAL_SEED_STRIDE) + the cell +
## rep addends stays < imax. The loop exits at the cap long before this
## many iterations, so the wrap is a belt-and-braces guard only.
LOCAL_SEED_LANES <- 800L

## local_accum_batch_seed: the local engine's seed_fn. Same SHAPE as the
## GHA pilot_accum_batch_seed (run-level base + cell base -> integer seed),
## but mapped into the disjoint high band above. `run_seed_base` here is
## the loop ITERATION index (a small non-negative integer the engine
## passes through unchanged); the high offset lives in this function so the
## value handed to the engine stays a tidy iteration counter.
local_accum_batch_seed <- function(run_seed_base, cell_seed_base) {
  lane <- as.double(run_seed_base) %% LOCAL_SEED_LANES
  raw <- LOCAL_SEED_BASE0 +
    lane * LOCAL_SEED_STRIDE +
    as.double(cell_seed_base)
  imax <- .Machine$integer.max
  ## By construction raw < imax (see LOCAL_SEED_LANES sizing); assert it so
  ## a future constant edit that would fold is caught loudly rather than
  ## silently risking a GHA collision.
  if (raw > imax || raw < 0) {
    stop(sprintf(
      "local seed base %.0f out of 32-bit range; adjust LOCAL_SEED_* constants.",
      raw
    ))
  }
  as.integer(raw)
}

## ---- Logging helper ---------------------------------------------------

## Append one ASCII line to the run-time log AND echo to stdout. Wall-clock
## timestamps are fine here (runtime script, not a deterministic workflow).
local_log <- function(...) {
  line <- sprintf(
    "[%s] %s",
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    paste0(..., collapse = "")
  )
  line <- iconv(line, to = "ASCII", sub = "?")
  cat(line, "\n", sep = "")
  tryCatch(
    cat(line, "\n", sep = "", file = LOCAL_LOG, append = TRUE),
    error = function(e) invisible(NULL)
  )
  invisible(NULL)
}

## ---- Pending-cell selection (resume) ----------------------------------

## Cells still below the cap in the local store, as cell_ids. Reuses the
## accumulate-status rollup so "pending" means "accumulated n_sim < cap".
local_pending_cells <- function(results_dir = LOCAL_RESULTS_DIR,
                                n_sim_cap = LOCAL_N_SIM_CAP) {
  st <- pilot_accum_status(results_dir = results_dir, n_sim_cap = n_sim_cap)
  cells <- st$cells
  ## Least-filled FIRST: spread local reps evenly across all still-incomplete
  ## cells (complementing the even-but-slow GHA cron) instead of front-loading
  ## the lowest-id cells to the cap one batch at a time. Ties broken by cell_id
  ## for deterministic, resumable ordering.
  inc <- !cells$complete
  ord <- order(cells$n_sim[inc], cells$cell_id[inc])
  pending <- (cells$cell_id[inc])[ord]
  list(
    pending = pending,
    n_complete = sum(cells$complete),
    total = nrow(cells)
  )
}

## ---- One worker's job: accumulate ONE cell into a private temp dir ----

## Runs +step reps for a single cell via the validated engine, in an
## ISOLATED temp results_dir seeded with a copy of just that cell's prior
## .rds (so the engine resumes from the real prior count). Returns the path
## to the worker's updated per-cell .rds (or NULL on hard failure) plus a
## fail-soft status. The engine itself is fail-soft per cell; this wrapper
## adds a second tryCatch so a worker can never crash the pool.
local_run_one_cell <- function(cell_id, iteration,
                               n_sim_step, n_sim_cap, n_boot,
                               canonical_dir) {
  res <- tryCatch(
    {
      worker_dir <- tempfile(pattern = paste0("gll-local-", cell_id, "-"))
      dir.create(worker_dir, recursive = TRUE, showWarnings = FALSE)
      ## Seed the worker dir with the cell's prior reps (resume), if any.
      prior_path <- file.path(canonical_dir, paste0(cell_id, ".rds"))
      if (file.exists(prior_path)) {
        file.copy(prior_path, file.path(worker_dir, paste0(cell_id, ".rds")),
                  overwrite = TRUE)
      }
      out <- run_accumulate_pilot_batch(
        cell_ids = cell_id,
        n_sim_step = n_sim_step,
        n_sim_cap = n_sim_cap,
        seed_base = iteration,            # iteration index; offset is in seed_fn
        results_dir = worker_dir,
        n_boot = n_boot,
        seed_fn = local_accum_batch_seed, # DISJOINT high band (vs GHA)
        verbose = FALSE
      )
      updated <- file.path(worker_dir, paste0(cell_id, ".rds"))
      list(
        cell_id = cell_id,
        ok = TRUE,
        cell_path = if (file.exists(updated)) updated else NA_character_,
        fail_rate = out$fail_rate,
        error = NA_character_
      )
    },
    error = function(e) {
      msg <- gsub("[\r\n]+", " ", iconv(conditionMessage(e), to = "ASCII", sub = "?"))
      list(
        cell_id = cell_id,
        ok = FALSE,
        cell_path = NA_character_,
        fail_rate = NA_real_,
        error = msg
      )
    }
  )
  res
}

## ---- One loop ITERATION -----------------------------------------------
## Picks up to `n_workers` pending cells, runs them in parallel on `cl`,
## merges each worker's per-cell .rds back into the canonical store, and
## rebuilds the canonical index once (single writer). Returns a small
## summary list. Fail-soft: a worker error is logged + skipped.
local_one_iteration <- function(cl, iteration,
                                n_workers = LOCAL_CORES,
                                n_sim_step = LOCAL_N_SIM_STEP,
                                n_sim_cap = LOCAL_N_SIM_CAP,
                                n_boot = LOCAL_N_BOOT,
                                results_dir = LOCAL_RESULTS_DIR) {
  if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  }

  pend <- local_pending_cells(results_dir, n_sim_cap)
  if (length(pend$pending) == 0L) {
    return(list(done = TRUE, ran = 0L, errored = 0L,
                n_complete = pend$n_complete, total = pend$total))
  }

  ## Up to n_workers pending cells this iteration (<= the core cap).
  batch_cells <- utils::head(pend$pending, n_workers)
  cores_in_use <- min(length(batch_cells), n_workers)

  ## Run the batch in parallel: each worker accumulates ONE cell into its
  ## own temp dir (no shared-file race). parLapply blocks until all done.
  results <- parallel::parLapply(
    cl,
    batch_cells,
    local_run_one_cell,
    iteration = iteration,
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    n_boot = n_boot,
    canonical_dir = results_dir
  )

  ## Single-writer merge: copy each worker's updated per-cell .rds into the
  ## canonical store, then rebuild the one index from disk.
  n_err <- 0L
  for (r in results) {
    if (!isTRUE(r$ok)) {
      n_err <- n_err + 1L
      local_log(sprintf("  FAIL cell %s: %s", r$cell_id, r$error))
      next
    }
    if (!is.na(r$cell_path) && file.exists(r$cell_path)) {
      file.copy(r$cell_path,
                file.path(results_dir, paste0(r$cell_id, ".rds")),
                overwrite = TRUE)
    }
  }
  ## Rebuild + persist the canonical index from the merged per-cell files
  ## (pilot_load_index rebuilds from disk when the index is stale/missing).
  ## Remove the index first so the rebuild reflects exactly what is on disk.
  idx_path <- file.path(results_dir, "pilot-index.rds")
  suppressWarnings(file.remove(idx_path))
  idx <- pilot_load_index(results_dir)
  pilot_save_index(idx, results_dir)

  post <- local_pending_cells(results_dir, n_sim_cap)
  list(
    done = length(post$pending) == 0L,
    ran = length(batch_cells),
    errored = n_err,
    cores_in_use = cores_in_use,
    n_complete = post$n_complete,
    total = post$total
  )
}

## ---- The continuous loop ----------------------------------------------

run_local_pilot_loop <- function(n_workers = LOCAL_CORES,
                                 n_sim_step = LOCAL_N_SIM_STEP,
                                 n_sim_cap = LOCAL_N_SIM_CAP,
                                 n_boot = LOCAL_N_BOOT,
                                 results_dir = LOCAL_RESULTS_DIR,
                                 sleep_s = LOCAL_SLEEP_S,
                                 stop_flag = LOCAL_STOP_FLAG,
                                 max_iterations = Inf) {
  stopifnot(n_workers >= 1L)
  if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  }

  local_log(sprintf(
    "START local pilot loop: cores=%d step=%d cap=%d n_boot=%d store=%s",
    n_workers, n_sim_step, n_sim_cap, n_boot, results_dir
  ))
  local_log(sprintf(
    "seed band [%.0f .. %.0f] (disjoint from GHA; fold-free < %.0f)",
    LOCAL_SEED_BASE0 + 660001,
    LOCAL_SEED_BASE0 + (LOCAL_SEED_LANES - 1) * LOCAL_SEED_STRIDE + 660048,
    .Machine$integer.max
  ))

  ## EXACTLY n_workers workers -> the process pins to <= n_workers cores.
  cl <- parallel::makeCluster(n_workers)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  ## Load the package + harness + engine once per worker.
  parallel::clusterEvalQ(cl, {
    suppressWarnings(suppressMessages({
      library(gllvmTMB)
      source("dev/m3-grid.R")
      source("dev/m3-pilot-launch.R")
    }))
    TRUE
  })
  ## Ship the local seed_fn + its constants to the workers (they are not in
  ## the sourced files). clusterExport pushes the objects by name.
  parallel::clusterExport(
    cl,
    varlist = c(
      "local_accum_batch_seed", "local_run_one_cell",
      "LOCAL_SEED_BASE0", "LOCAL_SEED_STRIDE", "LOCAL_SEED_LANES"
    ),
    envir = environment()
  )

  iteration <- 0L
  repeat {
    ## Stop-flag: clean exit after finishing nothing further.
    if (file.exists(stop_flag)) {
      local_log(sprintf("STOP flag %s present -> exiting cleanly.", stop_flag))
      break
    }
    if (iteration >= max_iterations) {
      local_log(sprintf("reached max_iterations=%s -> exiting.", format(max_iterations)))
      break
    }
    iteration <- iteration + 1L

    it <- tryCatch(
      local_one_iteration(
        cl, iteration,
        n_workers = n_workers,
        n_sim_step = n_sim_step,
        n_sim_cap = n_sim_cap,
        n_boot = n_boot,
        results_dir = results_dir
      ),
      error = function(e) {
        msg <- gsub("[\r\n]+", " ", iconv(conditionMessage(e), to = "ASCII", sub = "?"))
        local_log(sprintf("ITER %d hard error (continuing): %s", iteration, msg))
        list(done = FALSE, ran = 0L, errored = 0L,
             cores_in_use = 0L, n_complete = NA, total = NA)
      }
    )

    local_log(sprintf(
      "iter %d: ran %d cell(s) on %d core(s); errored %d; cells done %s/%s (step=%d, cap=%d)",
      iteration,
      it$ran %||% 0L,
      it$cores_in_use %||% 0L,
      it$errored %||% 0L,
      format(it$n_complete %||% NA),
      format(it$total %||% NA),
      n_sim_step, n_sim_cap
    ))

    if (isTRUE(it$done)) {
      local_log("ALL cells at cap -> campaign complete; exiting cleanly.")
      break
    }

    ## Re-check the stop flag before sleeping so a stop during a long batch
    ## takes effect promptly.
    if (file.exists(stop_flag)) {
      local_log(sprintf("STOP flag %s present -> exiting cleanly.", stop_flag))
      break
    }
    if (sleep_s > 0L) Sys.sleep(sleep_s)
  }

  local_log("STOP local pilot loop.")
  invisible(TRUE)
}

## ---- Entry point ------------------------------------------------------
## Run the continuous loop only when executed as a script (Rscript / R -f),
## NOT when sourced for its functions (e.g. the bounded smoke test).
if (sys.nframe() == 0L && !interactive()) {
  run_local_pilot_loop()
}
