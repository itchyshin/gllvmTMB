## D-139 PRE-RUN for the ordination_uncertainty() coverage design
## (dev/gapclose/arcG/coverage-design.md, Section 9).
##
## MEASURE ONLY. No campaign, no Totoro, no PR. Times, for 5 cells x 2 seeds:
##   1. the model fit itself
##   2. sdreport(fit$tmb_obj, getJointPrecision = TRUE) -- a SECOND sdreport
##      call beyond the fit's own production sdreport()
##   3a. ordination_uncertainty(fit) called as the package export (includes
##       its OWN internal sdreport(getJointPrecision=TRUE) call -- redundant
##       with stage 2, timed this way because that is literally what the
##       task asked for: "the ordination_uncertainty() call on the fitted
##       object")
##   3b. JUST the Matrix::solve(Q, W) step, replicated inline from
##       R/ordination-uncertainty.R, reusing sdr_joint from stage 2 -- this
##       isolates the actually-flagged unknown (Section 9 item 2) from the
##       redundant sdreport() stage-3a necessarily includes.
##
## Cells (n_traits = 4 unless noted), matching the design's own grid rows:
##   d=1, n_units=40    | d=1, n_units=320   | d=2, n_units=40
##   d=2, n_units=320    | n_traits=8, d=2, n_units=80

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

devtools::load_all(".", quiet = TRUE)

cells <- list(
  list(label = "d1_n40",   n_sites = 40,  n_traits = 4, d = 1),
  list(label = "d1_n320",  n_sites = 320, n_traits = 4, d = 1),
  list(label = "d2_n40",   n_sites = 40,  n_traits = 4, d = 2),
  list(label = "d2_n320",  n_sites = 320, n_traits = 4, d = 2),
  list(label = "nt8_d2_n80", n_sites = 80, n_traits = 8, d = 2)
)

## Loadings, matching Section 4 exactly.
Lambda_B_K1_4 <- matrix(c(0.9, 0.6, -0.4, 0.5), nrow = 4, ncol = 1)
Lambda_B_K2_4 <- matrix(c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2), nrow = 4, ncol = 2)
## n_traits = 8 cell: one fixed draw appended to the K2 loadings, per
## Section 4 ("runif(4, 0.3, 1.0), random sign, one draw, hard-coded").
set.seed(99001)
extra4 <- matrix(runif(8, 0.3, 1.0) * sample(c(-1, 1), 8, replace = TRUE), nrow = 4, ncol = 2)
Lambda_B_K2_8 <- rbind(Lambda_B_K2_4, extra4)

get_lambda <- function(n_traits, d) {
  if (n_traits == 4 && d == 1) return(Lambda_B_K1_4)
  if (n_traits == 4 && d == 2) return(Lambda_B_K2_4)
  if (n_traits == 8 && d == 2) return(Lambda_B_K2_8)
  stop("unhandled cell")
}

SEEDS <- c(9001, 9002) ## 2 seeds/cell, disjoint from design seeds (1:500) and fixture seeds (2101, 2025)
MAX_CELL_SECONDS <- 300 ## 5-minute per-cell cutoff (stop that cell, report "exceeds 5 min")

results <- list()

for (cell in cells) {
  cell_t0 <- Sys.time()
  cat(sprintf("\n=== cell %s (n_sites=%d, n_traits=%d, d=%d) ===\n",
              cell$label, cell$n_sites, cell$n_traits, cell$d))
  Lambda_B <- get_lambda(cell$n_traits, cell$d)
  psi_B <- rep(0.3, cell$n_traits)

  for (seed in SEEDS) {
    cat(sprintf("  seed %d ... ", seed))
    row <- list(cell = cell$label, n_sites = cell$n_sites, n_traits = cell$n_traits,
                d = cell$d, seed = seed,
                t_fit = NA_real_, t_sdreport_joint = NA_real_,
                t_ordu_full = NA_real_, t_solve_only = NA_real_,
                W_ncol = NA_integer_, Q_dim = NA_integer_,
                converged = NA, pdHess = NA, status = "ok")

    if (as.numeric(Sys.time() - cell_t0, units = "secs") > MAX_CELL_SECONDS) {
      row$status <- "cell exceeded 5 min budget -- skipped remaining seeds"
      cat("SKIPPED (cell budget exceeded)\n")
      results[[length(results) + 1]] <- row
      next
    }

    sim <- simulate_site_trait(
      n_sites = cell$n_sites, n_species = 12, n_traits = cell$n_traits,
      mean_species_per_site = 6, Lambda_B = Lambda_B, psi_B = psi_B, seed = seed
    )

    t_fit <- system.time({
      fit <- tryCatch(
        suppressMessages(suppressWarnings(gllvmTMB(
          value ~ 0 + trait + latent(0 + trait | site, d = cell$d),
          data = sim$data
        ))),
        error = function(e) e
      )
    })["elapsed"]
    row$t_fit <- as.numeric(t_fit)

    if (inherits(fit, "error")) {
      row$status <- paste("FIT ERROR:", conditionMessage(fit))
      cat("FIT ERROR\n")
      results[[length(results) + 1]] <- row
      next
    }
    row$converged <- isTRUE(fit$sd_report$pdHess) ## proxy; also captured below
    row$pdHess <- isTRUE(fit$sd_report$pdHess)

    if (!isTRUE(fit$sd_report$pdHess)) {
      row$status <- "non-PD Hessian -- stages 2/3 skipped (no interval to check)"
      cat("non-PD Hessian, skipping stages 2/3\n")
      results[[length(results) + 1]] <- row
      next
    }

    ## Stage 2: the SECOND sdreport() call with getJointPrecision = TRUE.
    t_sdr <- system.time({
      sdr_joint <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
    })["elapsed"]
    row$t_sdreport_joint <- as.numeric(t_sdr)
    Q <- sdr_joint$jointPrecision
    row$Q_dim <- if (!is.null(Q)) nrow(Q) else NA_integer_

    ## Stage 3a: the ACTUAL exported ordination_uncertainty() call (includes
    ## its own internal, redundant sdreport(getJointPrecision=TRUE)).
    t_ordu <- system.time({
      ordu <- tryCatch(ordination_uncertainty(fit, level = "unit"),
                        error = function(e) e)
    })["elapsed"]
    row$t_ordu_full <- as.numeric(t_ordu)
    if (inherits(ordu, "error")) {
      row$status <- paste("ordination_uncertainty ERROR:", conditionMessage(ordu))
    }

    ## Stage 3b: JUST the sparse multi-RHS solve, reusing Q from stage 2 --
    ## isolates Section 9's actually-flagged unknown.
    if (!is.null(Q)) {
      par_names <- rownames(Q)
      zpos <- which(par_names == "z_B")
      n_par <- nrow(Q)
      t_solve <- system.time({
        W <- Matrix::sparseMatrix(i = zpos, j = seq_along(zpos), x = 1,
                                   dims = c(n_par, length(zpos)))
        V <- Matrix::solve(Q, W)
      })["elapsed"]
      row$t_solve_only <- as.numeric(t_solve)
      row$W_ncol <- length(zpos)
    }

    cat(sprintf("fit=%.2fs sdr_joint=%.2fs ordu_full=%.2fs solve_only=%.2fs (W ncol=%s, Q dim=%s)\n",
                row$t_fit, row$t_sdreport_joint, row$t_ordu_full, row$t_solve_only,
                row$W_ncol, row$Q_dim))

    results[[length(results) + 1]] <- row
  }
}

out <- do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
write.csv(out, "dev/gapclose/arcG/prerun-timing-results.csv", row.names = FALSE)
cat("\n\n=== SUMMARY ===\n")
print(out, row.names = FALSE)
