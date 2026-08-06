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
  expect_match(preflight, "SLURM_JOB_ID")
  expect_match(preflight, "PREFLIGHT_CONTEXT=totoro requires a Totoro host")
  expect_match(preflight, "VA_PREFLIGHT_RECEIPT= Rscript --vanilla")
  expect_match(prepare, "must run in a DRAC allocation")

  for (name in c("launch-totoro.sh", "drac-array.sbatch")) {
    joined <- paste(text[[name]], collapse = "\n")
    expect_match(joined, "--gate-receipt")
    expect_match(joined, "--runtime-manifest")
    expect_match(joined, "--preflight-receipt")
  }

  submit <- paste(text[["submit-drac.sh"]], collapse = "\n")
  array <- paste(text[["drac-array.sbatch"]], collapse = "\n")
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
