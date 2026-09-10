#!/usr/bin/env Rscript
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
core_dir <- file.path(repo, "inst/sim/cran07-core")
v3_dir <- file.path(repo, "inst/sim/cran07-v3")
source(file.path(core_dir, "schema.R"), local = .GlobalEnv)
source(file.path(core_dir, "campaign.R"), local = .GlobalEnv)
source(file.path(core_dir, "batch.R"), local = .GlobalEnv)
source(file.path(v3_dir, "campaign-v3.R"), local = .GlobalEnv)
source(file.path(v3_dir, "gates-v3.R"), local = .GlobalEnv)
source(file.path(script_dir, "adjudication.R"), local = .GlobalEnv)

registry <- cran07_v3_read_campaign_registry("cran07-core-recovery-v3", repo)
psi <- data.frame(cell_id = "x", replicate = 1L, estimand = "Psi",
  component = c("t1_t1", "t2_t1"), applicable = TRUE,
  truth = c(1, 0), estimate = c(1, 0), trait_i = c(1L, 2L),
  trait_j = c(1L, 1L))
normalized <- cran07_adjudication_normalize_psi(psi)
stopifnot(identical(normalized$applicable, c(TRUE, FALSE)),
          attr(normalized, "psi_structural_rows_normalized") == 1L)
bad_psi <- psi
bad_psi$estimate[[2L]] <- .Machine$double.eps
stopifnot(inherits(try(cran07_adjudication_normalize_psi(bad_psi), silent = TRUE),
                     "try-error"))

make_corr <- function(cell, error) data.frame(
  cell_id = cell, replicate = seq_len(400L),
  estimand = "correlation_shared", component = "t2_t1",
  applicable = TRUE, truth = 1, estimate = 1 + error,
  trait_i = 2L, trait_j = 1L)
pairs <- data.frame(pair_id = "indep", small_cell = "s", large_cell = "l")
gate <- data.frame(pair_id = "indep", estimand = "correlation_shared",
  component = "t2_t1", n_small = 400L, n_large = 400L,
  expected_component = TRUE, pass = FALSE)
tiny <- rbind(make_corr("s", 2 * .Machine$double.eps),
              make_corr("l", 3 * .Machine$double.eps))
tiny_gate <- cran07_adjudication_apply_numerical_zero(gate, tiny, pairs)
stopifnot(tiny_gate$pass, tiny_gate$numerical_zero_rule)
large <- rbind(make_corr("s", 2 * .Machine$double.eps),
               make_corr("l", 1e-8))
large_gate <- cran07_adjudication_apply_numerical_zero(gate, large, pairs)
stopifnot(!large_gate$pass, !large_gate$numerical_zero_rule)

nb2_registry <- registry[registry$cell_id == "nb2_latent_n100", , drop = FALSE]
nb2_gate <- data.frame(cell_id = "nb2_latent_n100", cell_pass = TRUE)
nb2_marked <- cran07_adjudication_mark_dispersion(nb2_gate, tiny, nb2_registry)
stopifnot(!nb2_marked$dispersion_evidence_pass, !nb2_marked$cell_pass,
          nb2_marked$dispersion_evidence_reason == "primary_estimand_absent")

tmp <- tempfile(fileext = ".rds")
saveRDS(list(not = "an input"), tmp)
bad_paths <- stats::setNames(rep(tmp, 4L), CRAN07_ADJUDICATION_INPUTS$role)
stopifnot(inherits(try(cran07_adjudication_assert_inputs(bad_paths), silent = TRUE),
                     "try-error"))
stopifnot(identical(CRAN07_ADJUDICATION_SOURCE_SHA256,
  "c0372f037738a902c0c6d7ecd60f4170fcfc9d1d163709456eb0cd9f91615996"))
cat(paste0("psi_structural_zero_normalized=TRUE nonzero_psi=rejected ",
  "rank1_roundoff=accepted substantive_rmse=held ",
  "missing_nb2_dispersion=held bad_input_hash=rejected ",
  "thresholds_changed=FALSE fits_run=0\n"))
