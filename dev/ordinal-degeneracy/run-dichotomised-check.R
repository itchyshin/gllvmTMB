## dev/ordinal-degeneracy/run-dichotomised-check.R
##
## Scores the DICHOTOMISED ordinal degeneracy check against the frozen
## criteria in pass-criteria-dichotomised.md. Reuses the S1 probe's own
## dichotomise_and_refit() (which collapses at the middle cutpoint, refits
## binomial-probit, and runs the existing binomial detector) and the main
## ordinal campaign's four pre-registered arms, so labels transfer
## fit-for-fit and this candidate is scored on exactly the population that
## eliminated the other four.
##
## Usage (from the package root):
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=10 \
##     Rscript dev/ordinal-degeneracy/run-dichotomised-check.R [n_values] [seed_scale] [--pilot]

suppressMessages(devtools::load_all(".", quiet = TRUE))

## --- the S1 probe's constants, simulators and dichotomisation machinery ---
psrc <- readLines("dev/ordinal-degeneracy/probe-mechanism.R")
kc <- grep("^(TAUS|P_TRAITS|Q_FACTORS|UNDERFLOW|K_CATS|DEGEN_RF)", psrc)
eval(parse(text = paste(psrc[kc], collapse = "\n")), envir = globalenv())
fun_starts <- grep("^[A-Za-z_.]+ <- function", psrc)
take_fun <- function(name) {
  i <- grep(paste0("^", name, " <- function"), psrc)[1]
  j <- fun_starts[fun_starts > i][1]
  if (is.na(j)) j <- length(psrc) + 1L
  eval(parse(text = paste(psrc[i:(j - 1L)], collapse = "\n")), envir = globalenv())
}
for (fn in c("relfrob", "sim_ordinal", "fit_ordinal", "fit_binomial_dichot",
             "dichotomise_and_refit")) {
  take_fun(fn)
}

## --- the campaign's transport / mixed arms (same definitions, same seeds) ---
csrc <- readLines("dev/ordinal-degeneracy/campaign-ordinal-calibration.R")
cut <- grep("mode timing ---", csrc)[1] - 1L
eval(parse(text = paste(csrc[seq_len(cut)], collapse = "\n")), envir = globalenv())

args <- commandArgs(trailingOnly = TRUE)
PILOT <- "--pilot" %in% args
args <- args[args != "--pilot"]
N_VALUES <- if (length(args) >= 1L) as.integer(strsplit(args[1], ",")[[1]]) else c(100L, 400L)
SCALE <- if (length(args) >= 2L) as.numeric(strsplit(args[2], ",")[[1]]) else rep(1, length(N_VALUES))
CORES <- as.integer(Sys.getenv("CAMPAIGN_CORES", "10"))
SEEDS <- list(degenerate = 40L, healthy = 60L, transport = 60L, mixed = 50L)

one <- function(arm, n, seed) {
  t0 <- proc.time()[["elapsed"]]
  out <- tryCatch({
    sim <- switch(arm,
      degenerate = sim_ordinal(n, P_TRAITS, Q_FACTORS, 3.0, seed),
      healthy    = sim_ordinal(n, P_TRAITS, Q_FACTORS, 0.7, seed),
      transport  = sim_ordinal_transport(n, P_TRAITS, Q_FACTORS, seed),
      mixed      = sim_ordinal_mixed(n, Q_FACTORS, seed)
    )
    ## Truth label comes from the ORDINAL fit, exactly as the main campaign
    ## defines it -- the dichotomised refit is the CHECK, never the label.
    ofit <- suppressWarnings(suppressMessages(
      if (arm == "mixed") fit_ordinal_mixed(sim$data, Q_FACTORS) else fit_ordinal(sim$data)))
    lam <- tryCatch(ofit$report$Lambda_B, error = function(e) NULL)
    rf <- if (!is.null(lam) && all(is.finite(lam)) && !is.null(sim$Sig_true)) {
      relfrob(tcrossprod(lam), sim$Sig_true)
    } else NA_real_
    dc <- dichotomise_and_refit(sim$data, sim$Sig_true)
    data.frame(
      arm = arm, n = n, seed = seed, status = "OK",
      rel_frob = rf, degenerate_label = isTRUE(rf > DEGEN_RF),
      ## Field names are the probe's own: `status` and `detector_fired`.
      ## An earlier version of this driver read `dichot_status` /
      ## `dichot_detector_fired`, which do not exist, so every cell silently
      ## recorded FALSE and the whole grid came back 0/315 -- an all-negative
      ## pattern that is a harness failure, never a finding.
      dichot_status = if (is.null(dc$status)) NA_character_ else dc$status,
      dichot_fired = if (is.null(dc$detector_fired)) NA else dc$detector_fired,
      stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(
    arm = arm, n = n, seed = seed, status = "ERROR", rel_frob = NA_real_,
    degenerate_label = NA, dichot_status = NA_character_, dichot_fired = NA,
    stringsAsFactors = FALSE))
  out$seconds <- proc.time()[["elapsed"]] - t0
  out
}
`%||%` <- function(a, b) if (is.null(a)) b else a

grid <- do.call(rbind, lapply(names(SEEDS), function(a) {
  do.call(rbind, lapply(seq_along(N_VALUES), function(k) {
    ns <- max(1L, as.integer(round(SEEDS[[a]] * SCALE[k])))
    data.frame(arm = a, n = N_VALUES[k], seed = seq_len(ns) + 1000L,
               stringsAsFactors = FALSE)
  }))
}))
if (PILOT) grid <- grid[!duplicated(grid$arm), ]

cat(sprintf("dichotomised-check grid: %d cells, cores=%d, pilot=%s\n",
            nrow(grid), CORES, PILOT))
t0 <- proc.time()[["elapsed"]]
rows <- parallel::mclapply(seq_len(nrow(grid)),
                           function(i) one(grid$arm[i], grid$n[i], grid$seed[i]),
                           mc.cores = CORES)
res <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
el <- proc.time()[["elapsed"]] - t0
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
out <- sprintf("dev/ordinal-degeneracy/results/dichotomised-%s%s.csv",
               if (PILOT) "pilot-" else "", stamp)
write.csv(res, out, row.names = FALSE)
cat(sprintf("DICHOT DONE in %.1f s | rows %d | %s\n", el, nrow(res), out))
if (PILOT) {
  per <- mean(res$seconds, na.rm = TRUE)
  full <- sum(vapply(names(SEEDS), function(a) SEEDS[[a]], integer(1))) *
    sum(SCALE) / length(SCALE)
  cat(sprintf("D-139 projection: %.1f s/cell -> %.0f cells ~= %.1f min on %d cores\n",
              per, full, per * full / CORES / 60, CORES))
}
