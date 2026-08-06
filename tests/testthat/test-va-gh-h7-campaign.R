## Pure contract tests for the Arc-2 H=7 campaign driver.  Source the driver
## into a private environment in dry-run mode: no package installation, fit,
## plan, receipt, or result is written to the repository.

skip_on_cran()

.campaign_driver <- normalizePath(
  file.path(test_path(), "..", "..", "dev", "va-gh-h7-campaign", "run-cell.R"),
  mustWork = TRUE
)

.campaign_env <- local({
  env <- new.env(parent = globalenv())
  env$commandArgs <- function(trailingOnly = FALSE) {
    if (isTRUE(trailingOnly)) c("--mode=dry-run", "--n=100") else
      paste0("--file=", .campaign_driver)
  }
  capture.output(sys.source(.campaign_driver, envir = env))
  env
})

.campaign_set_cli <- function(...) {
  .campaign_env$cli <- list(...)
}

.campaign_spec <- function(cell, q = 2L, p = 2L) {
  out <- .campaign_env$cells[.campaign_env$cells$cell == cell, , drop = FALSE]
  out$task_id <- 1L
  out$seed <- 1L
  out$H <- 7L
  out$q <- q
  out$n <- 100L
  out$p <- p
  out$estimator <- "va"
  out$va_match_laplace_residual_sd <- FALSE
  out
}

.campaign_result_row <- function(cell, status, seed) {
  link_id <- if (identical(cell, "binomial_probit")) 1L else 0L
  link <- if (identical(cell, "binomial_probit")) "probit" else "logit"
  data.frame(
    task_id = seed, cell = cell, family_id = 1L, link = link, link_id = link_id,
    route = "gh", seed = seed, H = 7L, q = 2L, n = 100L, p = 2L,
    estimator = "va", va_match_laplace_residual_sd = FALSE,
    status = status, error = if (status == "completed") "" else "fit failed",
    elapsed_seconds = 1, convergence_code = if (status == "completed") 0L else NA_integer_,
    healthy = status == "completed", objective = 1, pd_hessian = NA,
    max_gradient = 0, gradient_tolerance = 1e-4,
    beta_bias_mean = if (status == "completed") 0 else NA_real_,
    beta_squared_error_mean = if (status == "completed") 0 else NA_real_,
    beta_wald_available = status == "completed",
    beta_wald_coverage = if (status == "completed") 1 else NA_real_,
    beta_wald_width = if (status == "completed") 1 else NA_real_,
    family_parameter_available = FALSE, family_parameter_rmse = NA_real_,
    sigma_available = FALSE, sigma_rel_frob = NA_real_, sigma_diag_rmse = NA_real_,
    lv_sd_available = FALSE, lv_posterior_sd_mean = NA_real_,
    lv_posterior_sd_coverage = NA_real_, started_utc = "now", finished_utc = "now",
    stringsAsFactors = FALSE
  )
}

.campaign_shell_files <- file.path(
  dirname(.campaign_driver),
  c("prepare-runtime.sh", "run-preflight.sh", "launch-totoro.sh",
    "drac-array.sbatch", "submit-drac.sh")
)

test_that("campaign plans derive their task count and use canonical plural flags", {
  .campaign_set_cli()
  default <- .campaign_env$make_plan()
  expected <- 30L * 2L * (4L + 14L * 5L) + 30L * 2L * 18L
  expect_equal(nrow(default), expected)
  expect_identical(default$task_id, seq_len(expected))

  .campaign_set_cli(
    cells = "binomial_logit", seeds = "42", Hs = "7", qs = "2",
    estimators = "va", n = "100", p = "6"
  )
  one <- .campaign_env$make_plan()
  expect_equal(nrow(one), 1L)
  expect_identical(one$task_id, 1L)
  expect_identical(one$cell, "binomial_logit")
  expect_identical(one$seed, 42L)
  expect_identical(one$H, 7L)
})

test_that("campaign input rejects undersized n and unknown CLI flags", {
  .campaign_set_cli(cells = "binomial_logit", seeds = "1", Hs = "7", qs = "2",
                    estimators = "va", n = "99", p = "6")
  expect_error(.campaign_env$make_plan(), "n must be integer >= 100")

  .campaign_set_cli(cells = "binomial_logit", seeds = "1", Hs = "7", qs = "2",
                    estimators = "va", n = "100", p = "6", typo = "caught")
  expect_error(.campaign_env$make_plan(), "unknown.*typo")
})

test_that("campaign runtime loader uses a character package name", {
  loader <- paste(deparse(body(.campaign_env$load_campaign_package)), collapse = "\n")
  expect_match(loader, 'library\\("gllvmTMB", character.only = TRUE\\)')
})

test_that("Gate-E receipts are structured, checksum-bound, and bind all families", {
  plain <- tempfile(fileext = ".receipt")
  writeLines("PASS", plain)
  expect_error(.campaign_env$verify_gate_receipt(plain), "DCF|lacks|wrong|malformed")

  report <- file.path(
    .campaign_env$repo_root, "docs", "dev-log", "audits",
    "2026-08-06-va-gh-h7-gate-e.md"
  )
  expect_true(file.exists(report))
  bad <- tempfile(fileext = ".dcf")
  write.dcf(data.frame(
    format_version = "2", gate = "Design-110-Gate-E", status = "PASS",
    git_revision = .campaign_env$git_revision(),
    template_checksum_md5 = .campaign_env$file_checksum(.campaign_env$gate_template_path()),
    report_path = .campaign_env$repo_relative_path(report),
    report_checksum_md5 = "deliberately-wrong", report_row_count = "18",
    passed_cells = paste(.campaign_env$cells$cell, collapse = ",")
  ), bad)
  expect_error(.campaign_env$verify_gate_receipt(bad), "checksum")
})

test_that("VA receives the same fixed Tweedie and Student metadata as Laplace", {
  captured <- list()
  testthat::local_mocked_bindings(
    .approximation_engine_va_r3_fit = function(...) {
      captured <<- list(...)
      list()
    },
    .va_route_build_fit = function(...) list(),
    .env = asNamespace("gllvmTMB")
  )
  dgp <- list(
    data = data.frame(unit = factor(rep(1:2, each = 2)),
                      trait = factor(rep(c("t01", "t02"), 2)), value = 1),
    n_trials = 1L
  )
  for (case in list(list("tweedie_log", "fixed_tweedie_power", 1.5),
                    list("student_identity", "fixed_student_df", 5))) {
    spec <- .campaign_spec(case[[1]], q = 1L, p = 2L)
    .campaign_env$private_va_fit(spec, dgp)
    expect_equal(captured[[case[[2]]]], rep(case[[3]], 2L))
    family <- .campaign_env$family_object(spec)
    field <- if (case[[1]] == "tweedie_log") "p" else "df"
    expect_equal(family[[field]], case[[3]])
  }
})

test_that("Tweedie DGP has the mgcv fallback available on campaign hosts", {
  skip_if_not_installed("mgcv")
  set.seed(17)
  draw <- .campaign_env$campaign_rtweedie(rep(1, 20), phi = 0.8, power = 1.5)
  expect_length(draw, 20L)
  expect_true(all(is.finite(draw)))
  expect_true(all(draw >= 0))
})

test_that("summary denominators retain failures and retain independent family verdicts", {
  out <- tempfile("va-gh-h7-summary-")
  dir.create(out)
  empty_beta <- .campaign_env$empty_beta_table()
  empty_family <- .campaign_env$empty_family_table()
  .campaign_env$publish_bundle(
    file.path(out, "replicates", "one.bundle"),
    .campaign_result_row("binomial_logit", "completed", 1L), empty_beta, empty_family, list()
  )
  .campaign_env$publish_bundle(
    file.path(out, "replicates", "two.bundle"),
    .campaign_result_row("binomial_probit", "failed", 2L), empty_beta, empty_family, list()
  )
  plan <- rbind(
    .campaign_spec("binomial_logit"), .campaign_spec("binomial_probit"),
    .campaign_spec("binomial_logit")
  )
  plan$task_id <- seq_len(nrow(plan))
  plan$seed <- seq_len(nrow(plan))
  ## The third immutable plan row has no bundle. It must materialise as a
  ## scheduler failure, rather than disappearing from a coverage denominator.
  bound <- .campaign_env$bind_results_to_plan(
    rbind(.campaign_result_row("binomial_logit", "completed", 1L),
          .campaign_result_row("binomial_probit", "failed", 2L)), plan
  )
  expect_identical(bound$status[[3L]], "scheduler_failed")
  .campaign_env$summarise_results(out, plan)
  path <- list.files(out, pattern = "^summary-.*\\.csv$", full.names = TRUE)
  summary <- read.csv(path, stringsAsFactors = FALSE)
  expect_equal(nrow(summary), 2L)
  expect_setequal(summary$cell, c("binomial_logit", "binomial_probit"))
  expect_equal(summary$failure_rate[summary$cell == "binomial_probit"], 1)
  logit <- summary[summary$cell == "binomial_logit", , drop = FALSE]
  expect_equal(logit$attempted, 2L)
  expect_equal(logit$beta_wald_coverage, 0.5)
})

test_that("predeclared adjudication yields independent family-rank verdicts", {
  .campaign_set_cli(
    seeds = "1:30", Hs = "5,7,9,15,61", qs = "2,5",
    estimators = "va,laplace", n = "120", p = "8"
  )
  totoro_plan <- .campaign_env$make_plan()
  .campaign_set_cli(
    seeds = "1:500", Hs = "7", qs = "2,5",
    estimators = "va,laplace", n = "120", p = "8"
  )
  drac_plan <- .campaign_env$make_plan()
  make_results <- function(plan) {
    data.frame(
      plan, status = "completed", beta_squared_error_mean = 0.01,
      sigma_rel_frob = 0.10, beta_wald_available = TRUE,
      beta_wald_coverage = 0.95, lv_sd_available = plan$estimator == "va",
      lv_posterior_sd_coverage = ifelse(plan$estimator == "va", 0.95, NA_real_),
      family_parameter_available = TRUE, family_parameter_rmse = 0.05,
      published_bundle = TRUE, stringsAsFactors = FALSE
    )
  }
  expect_invisible(.campaign_env$validate_adjudication_plans(totoro_plan, drac_plan))
  verdict <- .campaign_env$adjudicate_campaigns(
    make_results(totoro_plan), make_results(drac_plan), reps = 100L
  )
  expect_equal(nrow(verdict), 36L)
  expect_true(all(verdict$reliability_verdict == "PASS"))
  expect_true(all(verdict$point_recovery_verdict == "PASS"))
  expect_true(all(verdict$overall_point_route_verdict == "PASS"))
  expect_true(all(verdict$beta_wald_calibration == "CALIBRATED"))
  expect_true(all(verdict$latent_sd_calibration == "CALIBRATED"))
  expect_equal(sum(verdict$h7_stability_verdict == "NOT_APPLICABLE"), 8L)
  expect_true(all(
    verdict$h7_stability_verdict[verdict$route != "exact"] == "PASS"
  ))
  expect_true(all(
    verdict$family_parameter_adjudication[verdict$family_parameter_applicable] ==
      "DESCRIPTIVE_ONLY_NO_PREDECLARED_THRESHOLD"
  ))
  expect_true(all(verdict$unique_psi_adjudication ==
                    "OUT_OF_SCOPE_DGP_UNIQUE_FALSE"))

  verdict_path <- tempfile(fileext = ".csv")
  totoro_path <- tempfile(fileext = ".csv")
  drac_path <- tempfile(fileext = ".csv")
  write.csv(totoro_plan, totoro_path, row.names = FALSE)
  write.csv(drac_plan, drac_path, row.names = FALSE)
  input_manifest <- rbind(
    data.frame(
      campaign = "totoro", task_id = totoro_plan$task_id,
      published_bundle = TRUE,
      bundle_name = paste0(totoro_plan$task_id, ".bundle"),
      complete_manifest_checksum_md5 = rep("a", nrow(totoro_plan))
    ),
    data.frame(
      campaign = "drac", task_id = drac_plan$task_id,
      published_bundle = TRUE,
      bundle_name = paste0(drac_plan$task_id, ".bundle"),
      complete_manifest_checksum_md5 = rep("b", nrow(drac_plan))
    )
  )
  provenance_fields <- c(
    git_revision = "revision", template_checksum_md5 = "template",
    runtime_manifest_checksum_md5 = "runtime",
    gate_receipt_checksum_md5 = "gate",
    preflight_receipt_checksum_md5 = "preflight",
    plan_checksum_md5 = "plan"
  )
  export_fields <- c(
    results_checksum_md5 = "results-export",
    input_manifest_checksum_md5 = "manifest-export",
    receipt_checksum_md5 = "receipt-export"
  )
  make_provenance <- function(values = provenance_fields,
                              gate_report = "gate-report") {
    out <- as.list(values)
    attr(out, "gate_report_checksum_md5") <- gate_report
    out
  }
  campaign_provenance <- list(
    totoro = make_provenance(), drac = make_provenance()
  )
  .campaign_env$write_adjudication(
    verdict, verdict_path, totoro_path, drac_path, reps = 100L,
    input_manifest = input_manifest,
    campaign_provenance = campaign_provenance,
    campaign_exports = list(
      totoro = as.list(export_fields), drac = as.list(export_fields)
    ),
    require_clean = FALSE
  )
  receipt <- read.dcf(paste0(verdict_path, ".dcf"))
  expect_identical(receipt[[1L, "data_status"]], "COMPLETE")
  expect_identical(receipt[[1L, "point_route_pass_n"]], "36")
  expect_identical(receipt[[1L, "point_route_fail_n"]], "0")
  expect_identical(receipt[[1L, "all_point_routes_pass"]], "TRUE")
  expect_true(nzchar(receipt[[1L, "input_manifest_checksum_md5"]]))
  expect_true(nzchar(receipt[[1L, "adjudicator_checksum_md5"]]))
  expect_identical(receipt[[1L, "totoro_runtime_manifest_checksum_md5"]],
                   "runtime")
  expect_identical(receipt[[1L, "drac_preflight_receipt_checksum_md5"]],
                   "preflight")

  expect_error(
    .campaign_env$write_adjudication(
      verdict, tempfile(fileext = ".csv"), totoro_path, drac_path, reps = 100L,
      input_manifest = input_manifest[-1L, ],
      campaign_provenance = campaign_provenance,
      campaign_exports = list(
        totoro = as.list(export_fields), drac = as.list(export_fields)
      ),
      require_clean = FALSE
    ),
    "input manifest is incomplete"
  )

  mismatched_provenance <- campaign_provenance
  mismatched_provenance$drac$template_checksum_md5 <- "other-template"
  expect_error(
    .campaign_env$write_adjudication(
      verdict, tempfile(fileext = ".csv"), totoro_path, drac_path, reps = 100L,
      input_manifest = input_manifest,
      campaign_provenance = mismatched_provenance,
      campaign_exports = list(
        totoro = as.list(export_fields), drac = as.list(export_fields)
      ),
      require_clean = FALSE
    ),
    "do not share the same VA template and Gate-E evidence"
  )

  had_system2 <- exists("system2", envir = .campaign_env, inherits = FALSE)
  if (had_system2) old_system2 <- .campaign_env$system2
  on.exit({
    if (had_system2) {
      .campaign_env$system2 <- old_system2
    } else if (exists("system2", envir = .campaign_env, inherits = FALSE)) {
      rm("system2", envir = .campaign_env)
    }
  }, add = TRUE)
  .campaign_env$system2 <- function(...) " M deliberately-dirty"
  expect_error(
    .campaign_env$write_adjudication(
      verdict, tempfile(fileext = ".csv"), totoro_path, drac_path, reps = 100L,
      input_manifest = input_manifest,
      campaign_provenance = campaign_provenance,
      campaign_exports = list(
        totoro = as.list(export_fields), drac = as.list(export_fields)
      )
    ),
    "clean committed checkout"
  )

  incomplete_totoro <- make_results(totoro_plan)
  selected <- with(
    incomplete_totoro,
    cell == "binomial_logit" & q == 2L & estimator == "va" &
      H == 5L & seed == 1L
  )
  incomplete_totoro$published_bundle[selected] <- FALSE
  incomplete_totoro$status[selected] <- "scheduler_failed"
  incomplete <- .campaign_env$adjudicate_campaigns(
    incomplete_totoro, make_results(drac_plan), reps = 100L
  )
  affected <- incomplete$cell == "binomial_logit" & incomplete$q == 2L
  expect_identical(incomplete$overall_point_route_verdict[affected], "INCOMPLETE")
  expect_true(all(incomplete$overall_point_route_verdict[!affected] == "PASS"))
})

test_that("adjudication rejects duplicate or incomplete plan cross-products", {
  .campaign_set_cli(
    seeds = "1:30", Hs = "5,7,9,15,61", qs = "2,5",
    estimators = "va,laplace", n = "120", p = "8"
  )
  totoro_plan <- .campaign_env$make_plan()
  .campaign_set_cli(
    seeds = "1:500", Hs = "7", qs = "2,5",
    estimators = "va,laplace", n = "120", p = "8"
  )
  drac_plan <- .campaign_env$make_plan()

  corrupted <- drac_plan
  source <- which(
    corrupted$cell == "binomial_logit" & corrupted$seed == 1L &
      corrupted$q == 2L & corrupted$estimator == "va"
  )[[1L]]
  target <- which(
    corrupted$cell == "binomial_logit" & corrupted$seed == 2L &
      corrupted$q == 2L & corrupted$estimator == "va"
  )[[1L]]
  key_columns <- c("cell", "family_id", "link", "link_id", "route", "seed",
                   "H", "q", "n", "p", "estimator",
                   "va_match_laplace_residual_sd")
  corrupted[target, key_columns] <- corrupted[source, key_columns]
  expect_error(
    .campaign_env$validate_adjudication_plans(totoro_plan, corrupted),
    "exact required.*cross-product"
  )
})

test_that("adjudication bundle reader retains missing rows and rejects corruption", {
  .campaign_set_cli(
    cells = "binomial_logit", seeds = "1:2", Hs = "7", qs = "2",
    estimators = "va", n = "100", p = "2"
  )
  plan <- .campaign_env$make_plan()
  out <- tempfile("va-gh-h7-bound-")
  dir.create(out)

  no_bundles <- .campaign_env$read_bound_campaign_results(out, plan)
  expect_equal(nrow(no_bundles), 2L)
  expect_true(all(no_bundles$status == "scheduler_failed"))
  expect_false(any(no_bundles$published_bundle))

  one <- .campaign_result_row("binomial_logit", "completed", 1L)
  one$task_id <- 1L
  .campaign_env$publish_bundle(
    file.path(out, "replicates", "one.bundle"), one,
    .campaign_env$empty_beta_table(), .campaign_env$empty_family_table(), list()
  )
  partial <- .campaign_env$read_bound_campaign_results(out, plan)
  expect_identical(partial$status, c("completed", "scheduler_failed"))
  expect_identical(partial$published_bundle, c(TRUE, FALSE))

  write("corrupt", file.path(out, "replicates", "one.bundle", "result.csv"))
  expect_error(
    .campaign_env$read_bound_campaign_results(out, plan),
    "incomplete or corrupt"
  )
})

test_that("adjudication bundle reader rejects duplicate task claims", {
  .campaign_set_cli(
    cells = "binomial_logit", seeds = "1:2", Hs = "7", qs = "2",
    estimators = "va", n = "100", p = "2"
  )
  plan <- .campaign_env$make_plan()
  out <- tempfile("va-gh-h7-duplicate-")
  dir.create(out)
  duplicate <- .campaign_result_row("binomial_logit", "completed", 1L)
  duplicate$task_id <- 1L
  for (name in c("one.bundle", "two.bundle")) {
    .campaign_env$publish_bundle(
      file.path(out, "replicates", name), duplicate,
      .campaign_env$empty_beta_table(), .campaign_env$empty_family_table(), list()
    )
  }
  expect_error(
    .campaign_env$read_bound_campaign_results(out, plan),
    "more than one result bundle claims"
  )
})

test_that("adjudication bundle reader enforces the supplied runtime chain", {
  .campaign_set_cli(
    cells = "binomial_logit", seeds = "1", Hs = "7", qs = "2",
    estimators = "va", n = "100", p = "2"
  )
  plan <- .campaign_env$make_plan()
  out <- tempfile("va-gh-h7-provenance-")
  dir.create(out)
  expected <- list(
    git_revision = "revision-a", template_checksum_md5 = "template-a",
    runtime_manifest_checksum_md5 = "runtime-a",
    gate_receipt_checksum_md5 = "gate-a",
    preflight_receipt_checksum_md5 = "preflight-a",
    plan_checksum_md5 = "plan-a"
  )
  result <- .campaign_result_row("binomial_logit", "completed", 1L)
  .campaign_env$publish_bundle(
    file.path(out, "replicates", "one.bundle"), result,
    .campaign_env$empty_beta_table(), .campaign_env$empty_family_table(),
    list(provenance = expected)
  )
  bound <- .campaign_env$read_bound_campaign_results(out, plan, expected)
  expect_true(bound$published_bundle)
  expect_identical(
    attr(bound, "bundle_manifest")$task_id, plan$task_id
  )
  wrong <- expected
  wrong$plan_checksum_md5 <- "plan-b"
  expect_error(
    .campaign_env$read_bound_campaign_results(out, plan, wrong),
    "disagrees with the supplied runtime chain.*plan_checksum_md5"
  )
})

test_that("historical receipt chains are mutually checksum-bound", {
  plan_path <- tempfile(fileext = ".csv")
  write.csv(data.frame(task_id = 1L), plan_path, row.names = FALSE)
  gate_path <- tempfile(fileext = ".dcf")
  runtime_path <- tempfile(fileext = ".dcf")
  preflight_path <- tempfile(fileext = ".dcf")
  write.dcf(data.frame(
    format_version = "2", gate = "Design-110-Gate-E", status = "PASS",
    git_revision = "revision-a", template_checksum_md5 = "template-a",
    report_checksum_md5 = "report-a", report_row_count = "18",
    passed_cells = paste(.campaign_env$cells$cell, collapse = ",")
  ), gate_path)
  write.dcf(data.frame(
    format_version = "2", git_revision = "revision-a",
    template_checksum_md5 = "template-a",
    gate_receipt_checksum_md5 = .campaign_env$file_checksum(gate_path),
    gate_report_checksum_md5 = "report-a"
  ), runtime_path)
  spec <- .campaign_env$preflight_spec()
  write.dcf(data.frame(
    format_version = "2", status = "PASS",
    runtime_manifest_checksum_md5 = .campaign_env$file_checksum(runtime_path),
    gate_receipt_checksum_md5 = .campaign_env$file_checksum(gate_path),
    git_revision = "revision-a", template_checksum_md5 = "template-a",
    cell = spec$cell, seed = spec$seed, H = spec$H, q = spec$q,
    n = spec$n, p = spec$p, va_status = "completed",
    laplace_status = "completed"
  ), preflight_path)
  provenance <- .campaign_env$historical_campaign_provenance(
    plan_path, gate_path, runtime_path, preflight_path
  )
  expect_identical(provenance$git_revision, "revision-a")
  expect_identical(
    provenance$plan_checksum_md5, .campaign_env$file_checksum(plan_path)
  )

  broken_path <- tempfile(fileext = ".dcf")
  broken <- read.dcf(preflight_path)
  broken[[1L, "runtime_manifest_checksum_md5"]] <- "wrong-runtime"
  write.dcf(as.data.frame(broken), broken_path)
  expect_error(
    .campaign_env$historical_campaign_provenance(
      plan_path, gate_path, runtime_path, broken_path
    ),
    "receipt chain is inconsistent"
  )
})

test_that("host-local campaign exports round-trip and reject tampering", {
  .campaign_set_cli(
    cells = "binomial_logit", seeds = "1:2", Hs = "7", qs = "2",
    estimators = "va", n = "100", p = "2"
  )
  plan <- .campaign_env$make_plan()
  plan_path <- tempfile(fileext = ".csv")
  write.csv(plan, plan_path, row.names = FALSE)
  provenance <- list(
    git_revision = "revision-a", template_checksum_md5 = "template-a",
    runtime_manifest_checksum_md5 = "runtime-a",
    gate_receipt_checksum_md5 = "gate-a",
    preflight_receipt_checksum_md5 = "preflight-a",
    plan_checksum_md5 = .campaign_env$file_checksum(plan_path)
  )
  attr(provenance, "gate_report_checksum_md5") <- "gate-report-a"
  raw <- tempfile("va-gh-h7-export-raw-")
  dir.create(raw)
  result <- .campaign_result_row("binomial_logit", "completed", 1L)
  .campaign_env$publish_bundle(
    file.path(raw, "replicates", "one.bundle"), result,
    .campaign_env$empty_beta_table(), .campaign_env$empty_family_table(),
    list(provenance = provenance)
  )
  bound <- .campaign_env$read_bound_campaign_results(raw, plan, provenance)
  export_path <- tempfile(fileext = ".csv")
  .campaign_env$write_campaign_export(
    bound, export_path, plan_path, provenance
  )
  restored <- .campaign_env$read_campaign_export(export_path, plan_path)
  expect_identical(restored$status, c("completed", "scheduler_failed"))
  expect_identical(
    attr(restored, "campaign_provenance")$git_revision, "revision-a"
  )
  expect_true(all(nzchar(unlist(
    attr(restored, "campaign_export_checksums"), use.names = FALSE
  ))))

  write("tampered", export_path)
  expect_error(
    .campaign_env$read_campaign_export(export_path, plan_path),
    "checksum or format validation failed"
  )
})

test_that("broad export verifies and excludes the legacy Totoro smoke bundle", {
  .campaign_set_cli(
    cells = "binomial_logit", seeds = "1", Hs = "7", qs = "2",
    estimators = "va", n = "100", p = "2"
  )
  plan <- .campaign_env$make_plan()
  plan_path <- tempfile(fileext = ".csv")
  write.csv(plan, plan_path, row.names = FALSE)
  broad_provenance <- list(
    git_revision = "revision-a", template_checksum_md5 = "template-a",
    runtime_manifest_checksum_md5 = "runtime-a",
    gate_receipt_checksum_md5 = "gate-a",
    preflight_receipt_checksum_md5 = "preflight-a",
    plan_checksum_md5 = .campaign_env$file_checksum(plan_path)
  )
  out <- tempfile("va-gh-h7-legacy-smoke-")
  dir.create(out)
  broad_result <- .campaign_result_row("binomial_logit", "completed", 1L)
  .campaign_env$publish_bundle(
    file.path(out, "replicates", "broad.bundle"), broad_result,
    .campaign_env$empty_beta_table(), .campaign_env$empty_family_table(),
    list(provenance = broad_provenance)
  )

  .campaign_set_cli(
    cells = "binomial_logit", seeds = "202608061", Hs = "7", qs = "2",
    estimators = "va", n = "120", p = "6"
  )
  smoke_plan <- .campaign_env$make_plan()
  smoke_path <- file.path(out, "smoke-plan.csv")
  write.csv(smoke_plan, smoke_path, row.names = FALSE)
  smoke_result <- .campaign_result_row(
    "binomial_logit", "completed", 202608061L
  )
  spec_columns <- names(smoke_plan)
  smoke_result[spec_columns] <- smoke_plan[1L, spec_columns]
  smoke_provenance <- broad_provenance
  smoke_provenance$plan_checksum_md5 <- .campaign_env$file_checksum(smoke_path)
  .campaign_env$publish_bundle(
    file.path(out, "replicates", "legacy-smoke.bundle"), smoke_result,
    .campaign_env$empty_beta_table(), .campaign_env$empty_family_table(),
    list(provenance = smoke_provenance)
  )

  expect_message(
    bound <- .campaign_env$read_bound_campaign_results(
      out, plan, broad_provenance
    ),
    "excluded 1 auxiliary smoke bundle"
  )
  expect_equal(nrow(bound), 1L)
  expect_identical(bound$seed, 1L)
  expect_true(bound$published_bundle)
})

test_that("adjudication thresholds fail material degradation and miscalibration", {
  reliable <- data.frame(status = rep("completed", 500L))
  failed <- data.frame(status = c(rep("failed", 100L), rep("completed", 400L)))
  expect_identical(.campaign_env$reliability_diagnostics(reliable)$verdict, "PASS")
  expect_identical(.campaign_env$reliability_diagnostics(failed)$verdict, "FAIL")

  degraded <- .campaign_env$bootstrap_ratio(
    rep(0.04, 30L), rep(0.01, 30L), root = TRUE, reps = 100L
  )
  expect_equal(degraded$ratio, 2)
  expect_gt(degraded$upper, 1.25)

  coverage <- data.frame(
    status = rep("completed", 500L), available = TRUE, value = 0.80
  )
  calibration <- .campaign_env$calibration_diagnostics(
    coverage, "value", "available"
  )
  expect_identical(calibration$verdict, "UNCALIBRATED")
})

test_that("campaign shell contracts are parseable and dry-run remains one task", {
  expect_true(all(file.exists(.campaign_shell_files)))
  statuses <- vapply(.campaign_shell_files, function(path) {
    system2("bash", c("-n", path), stdout = FALSE, stderr = FALSE)
  }, integer(1L))
  expect_true(all(statuses == 0L))

  launch <- file.path(dirname(.campaign_driver), "launch-totoro.sh")
  output <- system2("bash", launch, stdout = TRUE, stderr = TRUE)
  expect_identical(attr(output, "status") %||% 0L, 0L)
  expect_match(paste(output, collapse = "\n"), "tasks: 1")
})

test_that("shell launchers use structured receipts and derived array geometry", {
  text <- stats::setNames(
    lapply(.campaign_shell_files, readLines, warn = FALSE),
    basename(.campaign_shell_files)
  )
  all_shell <- unlist(text, use.names = FALSE)
  expect_false(any(grepl("grep.*PASS", all_shell)))
  expect_false(any(grepl("^#SBATCH.*--array", text[["drac-array.sbatch"]])))
  expect_false(any(grepl("--mode=preflight", text[["prepare-runtime.sh"]], fixed = TRUE)))
  preflight <- paste(text[["run-preflight.sh"]], collapse = "\n")
  prepare <- paste(text[["prepare-runtime.sh"]], collapse = "\n")
  expect_match(preflight, "fir.*nibi.*rorqual.*trillium.*narval")
  expect_match(preflight, "CC_CLUSTER")
  expect_match(preflight, "CLUSTER")
  expect_match(preflight, "SLURM_JOB_ID")
  expect_match(preflight, "PREFLIGHT_CONTEXT=totoro requires a Totoro host")
  expect_match(preflight, "VA_PREFLIGHT_RECEIPT= Rscript --vanilla")
  expect_match(prepare, "must run in a DRAC allocation")
  expect_match(prepare, "CC_CLUSTER")

  for (name in c("launch-totoro.sh", "drac-array.sbatch")) {
    joined <- paste(text[[name]], collapse = "\n")
    expect_match(joined, "--gate-receipt")
    expect_match(joined, "--runtime-manifest")
    expect_match(joined, "--preflight-receipt")
  }

  submit <- paste(text[["submit-drac.sh"]], collapse = "\n")
  array <- paste(text[["drac-array.sbatch"]], collapse = "\n")
  launch <- paste(text[["launch-totoro.sh"]], collapse = "\n")
  expect_match(launch, "SMOKE_OUTPUT_DIR")
  expect_true(grepl('ACTION="${ACTION:-write}"', submit, fixed = TRUE))
  expect_match(submit, "nrow\\(x\\)")
  expect_match(submit, "MAX_ARRAY_TASKS")
  expect_true(grepl('if [[ "$ACTION" == "write" ]]', submit, fixed = TRUE))
  expect_match(array, "TASK_OFFSET")
  expect_true(grepl(
    'task_index=$((TASK_OFFSET + SLURM_ARRAY_TASK_ID))', array, fixed = TRUE
  ))
})

test_that("q=2 and q=5 posterior-SD calibration is rotation-aware", {
  saved <- mget(c("private_va_fit", "beta_table", "family_parameter_table",
                  "extract_fit_components"), envir = .campaign_env, inherits = FALSE)
  on.exit(list2env(saved, envir = .campaign_env), add = TRUE)
  .campaign_env$private_va_fit <- function(...) list(status = "healthy", diagnostics = list(
    convergence = 0L, max_abs_gradient = 0, health = list(gradient_tolerance = 1e-4)
  ), score = list(negative_elbo_gh = 1))
  .campaign_env$beta_table <- function(...) .campaign_env$empty_beta_table()
  .campaign_env$family_parameter_table <- function(...) .campaign_env$empty_family_table()

  for (q in c(2L, 5L)) {
    set.seed(q)
    scores <- matrix(rnorm(20L * q), 20L, q)
    Lambda <- diag(q)
    rotation <- if (q == 2L) matrix(c(0, -1, 1, 0), 2L) else {
      qr.Q(qr(matrix(rnorm(q * q), q)))
    }
    .campaign_env$extract_fit_components <- local({
      fitted_scores <- scores %*% rotation
      fitted_lambda <- Lambda %*% rotation
      function(...) list(
        Sigma = Lambda %*% t(Lambda), Lambda = fitted_lambda,
        latent = list(scores = fitted_scores, se = matrix(1e-8, nrow(scores), q))
      )
    })
    spec <- .campaign_spec("gaussian_identity", q = q, p = q)
    dgp <- list(beta = rep(0, q), Lambda = Lambda, Sigma = Lambda %*% t(Lambda),
                scores = scores, family = data.frame())
    scored <- .campaign_env$fit_and_score(spec, dgp)
    expect_equal(scored$lv_posterior_sd_coverage, 1, tolerance = 1e-12,
                 info = paste("q =", q))
  }
})
