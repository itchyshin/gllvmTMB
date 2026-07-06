## Report-ready table extraction for gllvmTMB diagnostic objects.

#' Extract report-ready tables from diagnostic objects
#'
#' `diagnostic_table()` turns the metadata attached by [predictive_check()]
#' and [residuals.gllvmTMB_multi()] into plain data frames. It is the
#' public path for articles, reports, and tests that need the plotted
#' diagnostic rows, residual rows, row-status counts, or fit-health table
#' without inspecting object attributes directly.
#'
#' Scope boundary (DIA-13): IN, table extraction from existing
#' `attr(x, "gllvmTMB_diagnostic")` metadata on `predictive_check()`
#' plots and diagnostic residual data frames. PARTIAL, this helper does
#' not compute new diagnostics, refit models, run formal residual tests,
#' or calibrate uncertainty. PLANNED, richer article tables can build on
#' this stable metadata path once the diagnostic examples are restored.
#'
#' @param x A `ggplot` returned by [predictive_check()] or a data frame
#'   returned by `residuals(fit, type = "randomized_quantile")` or
#'   `residuals(fit, type = "simulation_rank")`.
#' @param table Table to extract. `"data"` returns plotted data for
#'   predictive-check plots or the residual rows themselves for residual
#'   objects; `"row_status"` counts residual row `status` values when
#'   present; `"fit_health_status"` returns counts of `PASS` / `WARN` /
#'   `FAIL` rows from [check_gllvmTMB()]; `"check_gllvmTMB"` returns the
#'   full fit-health table attached to the diagnostic object.
#' @return A plain data frame.
#' @export
#' @examples
#' \donttest{
#' set.seed(3)
#' n <- 24
#' df <- data.frame(
#'   unit = factor(rep(seq_len(n), each = 2)),
#'   trait = factor(rep(c("a", "b"), n)),
#'   value = rpois(2 * n, lambda = 2)
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | unit, d = 1),
#'   data = df,
#'   trait = "trait",
#'   unit = "unit",
#'   family = poisson()
#' )
#' p <- predictive_check(fit, type = "rq_qq", seed = 1)
#' diagnostic_table(p, table = "row_status")
#' diagnostic_table(p, table = "fit_health_status")
#' diagnostic_table(p, table = "data")
#'
#' r <- residuals(fit, type = "randomized_quantile", seed = 1)
#' diagnostic_table(r, table = "data")
#' }
diagnostic_table <- function(
  x,
  table = c("data", "row_status", "fit_health_status", "check_gllvmTMB")
) {
  table <- match.arg(table)
  meta <- .gllvmTMB_diagnostic_metadata(x)

  switch(
    table,
    data = .gllvmTMB_diagnostic_data_table(x, meta),
    row_status = .gllvmTMB_diagnostic_row_status_table(x, meta),
    fit_health_status = .gllvmTMB_diagnostic_fit_health_status_table(meta),
    check_gllvmTMB = .gllvmTMB_diagnostic_check_table(meta)
  )
}

.gllvmTMB_diagnostic_metadata <- function(x) {
  meta <- attr(x, "gllvmTMB_diagnostic", exact = TRUE)
  if (!is.list(meta)) {
    cli::cli_abort(c(
      "{.arg x} does not carry {.pkg gllvmTMB} diagnostic metadata.",
      "i" = "Use {.fn predictive_check} or {.fn residuals} on a {.cls gllvmTMB_multi} fit before calling {.fn diagnostic_table}."
    ))
  }
  meta
}

.gllvmTMB_diagnostic_data_table <- function(x, meta) {
  data <- meta$data
  if (is.null(data) && is.data.frame(x)) {
    data <- x
  }
  if (!is.data.frame(data)) {
    cli::cli_abort(c(
      "No diagnostic row data are attached to {.arg x}.",
      "i" = "Try {.code diagnostic_table(x, table = \"check_gllvmTMB\")} or refit with the current diagnostic helpers."
    ))
  }
  .gllvmTMB_plain_diagnostic_data_frame(data)
}

.gllvmTMB_diagnostic_row_status_table <- function(x, meta) {
  data <- .gllvmTMB_diagnostic_data_table(x, meta)
  if (!"status" %in% names(data)) {
    return(data.frame(
      status = "not_recorded",
      n = nrow(data),
      stringsAsFactors = FALSE
    ))
  }
  status <- as.character(data$status)
  status[is.na(status) | status == ""] <- "missing"
  tab <- table(status, useNA = "no")
  data.frame(
    status = names(tab),
    n = as.integer(tab),
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_diagnostic_fit_health_status_table <- function(meta) {
  status <- meta$fit_health_status
  if (!is.data.frame(status)) {
    cli::cli_abort("No fit-health status table is attached to {.arg x}.")
  }
  .gllvmTMB_plain_diagnostic_data_frame(status)
}

.gllvmTMB_diagnostic_check_table <- function(meta) {
  check <- meta$check_gllvmTMB
  if (is.data.frame(check)) {
    return(.gllvmTMB_plain_diagnostic_data_frame(check))
  }
  # If check_gllvmTMB() was attempted but errored for this fit (its message is
  # captured in fit_health_error), surface the failure as a single diagnostic
  # row rather than aborting: one failing fit must not break a whole report or
  # pkgdown article that tabulates several fits together.
  check_error <- unname(meta$fit_health_error["check_gllvmTMB"])
  if (length(check_error) == 1L && !is.na(check_error) && nzchar(check_error)) {
    return(.gllvmTMB_plain_diagnostic_data_frame(data.frame(
      component = "check_gllvmTMB",
      status = "ERROR",
      value = NA_character_,
      threshold = NA_character_,
      message = paste0("check_gllvmTMB() could not be computed: ", check_error),
      action = "inspect convergence, sdreport, and identifiability for this fit",
      stringsAsFactors = FALSE
    )))
  }
  cli::cli_abort("No {.fn check_gllvmTMB} table is attached to {.arg x}.")
}

.gllvmTMB_plain_diagnostic_data_frame <- function(x) {
  out <- as.data.frame(x, optional = TRUE)
  attr(out, "gllvmTMB_diagnostic") <- NULL
  attr(out, "method") <- NULL
  rownames(out) <- NULL
  out
}
