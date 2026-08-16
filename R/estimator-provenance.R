## Internal estimator provenance (Arc 1A)
##
## Separates resolved integration, outer criterion, numerical kernel, and
## penalty-eval without changing accepted calls or the TMB tape contract.
## `estimator_id` remains the existing DATA integer 0/1/2; this file only
## *derives* it. Unexported. Do not advertise on print/summary/NEWS.

.gllvmTMB_estimator_compatibility_table <- function() {
  data.frame(
    public_estimator = c("ml", "ml", "ml", "ml", "mspl", "mspl"),
    reml = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE),
    integration = c("laplace", "va", "aghq", "laplace", "laplace", "laplace"),
    tape_role = c(
      "primary", "primary", "primary", "primary",
      "primary", "penalty_off_provenance"
    ),
    criterion_id = c("la_ml", "va_elbo", "la_ml", "reml", "la_mspl", "la_mspl"),
    numeric_kernel_id = c(
      "legacy_ml", "va", "legacy_ml", "legacy_ml",
      "audited_stable_mspl", "audited_stable_mspl"
    ),
    penalty_eval_id = c("off", "off", "off", "off", "on", "provenance_off"),
    estimator_id = c(0L, NA_integer_, 0L, 0L, 1L, 2L),
    public_label = c("ML", "ML", "ML", "REML", "MSPL", "MSPL"),
    public_estimator_is_coarse = c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE),
    accepted = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_resolve_estimator_provenance <- function(estimator = "ml",
                                                  reml = FALSE,
                                                  integration = "laplace",
                                                  tape_role = "primary") {
  estimator <- if (is.null(estimator) || !nzchar(estimator[[1L]])) {
    "ml"
  } else {
    tolower(as.character(estimator[[1L]]))
  }
  if (identical(estimator, "ML")) estimator <- "ml"
  if (identical(estimator, "MSPL")) estimator <- "mspl"
  if (!estimator %in% c("ml", "mspl")) {
    estimator <- "ml"
  }
  reml <- isTRUE(reml)
  integration <- as.character(integration[[1L]] %||% "laplace")
  if (!integration %in% c("laplace", "va", "aghq")) {
    integration <- "laplace"
  }
  tape_role <- as.character(tape_role[[1L]] %||% "primary")
  if (!tape_role %in% c("primary", "penalty_off_provenance")) {
    tape_role <- "primary"
  }
  if (!identical(estimator, "mspl") || !identical(integration, "laplace")) {
    tape_role <- "primary"
  }

  tbl <- .gllvmTMB_estimator_compatibility_table()
  row <- tbl[
    tbl$public_estimator == estimator &
      tbl$reml == reml &
      tbl$integration == integration &
      tbl$tape_role == tape_role,
    ,
    drop = FALSE
  ]
  if (nrow(row) != 1L) {
    ## REML is only a Laplace-row in the table. An explicit REML+VA/AGHQ
    ## combination is not a current admitted route; record the resolved
    ## integration and keep the REML public label without inventing a TMB id.
    if (isTRUE(reml)) {
      row <- tbl[tbl$public_estimator == "ml" & tbl$reml & tbl$tape_role == "primary", , drop = FALSE]
      row$integration <- integration
      row$public_estimator_is_coarse <- !identical(integration, "laplace")
      row$criterion_id <- "reml"
      row$numeric_kernel_id <- if (identical(integration, "va")) "va" else "legacy_ml"
      row$estimator_id <- if (identical(integration, "va")) NA_integer_ else 0L
    } else {
      ## Last-resort descriptive row: never abort an accepted call.
      row <- tbl[tbl$public_estimator == "ml" & !tbl$reml & tbl$integration == "laplace" & tbl$tape_role == "primary", , drop = FALSE]
      row$integration <- integration
      row$criterion_id <- if (identical(integration, "va")) "va_elbo" else "la_ml"
      row$numeric_kernel_id <- if (identical(integration, "va")) "va" else "legacy_ml"
      row$estimator_id <- if (identical(integration, "va")) NA_integer_ else 0L
      row$public_estimator_is_coarse <- !identical(integration, "laplace")
    }
  }

  notes <- character()
  if (isTRUE(row$public_estimator_is_coarse) && identical(row$integration, "va")) {
    notes <- c(
      notes,
      "public label ML is coarse: this fit optimises a variational objective, not LA-ML"
    )
  }
  if (isTRUE(row$public_estimator_is_coarse) && identical(row$integration, "aghq")) {
    notes <- c(
      notes,
      "public label ML is coarse: this fit uses AGHQ, not Laplace"
    )
  }
  if (identical(row$penalty_eval_id, "provenance_off")) {
    notes <- c(
      notes,
      "estimator_id = 2 is the penalty-off stable kernel at the MSPL point, not public ML"
    )
  }

  penalty_off_tape <- NULL
  if (identical(estimator, "mspl") && identical(integration, "laplace") &&
      identical(tape_role, "primary")) {
    off <- .gllvmTMB_resolve_estimator_provenance(
      estimator = "mspl",
      reml = FALSE,
      integration = "laplace",
      tape_role = "penalty_off_provenance"
    )
    penalty_off_tape <- list(
      estimator_id = off$estimator_id,
      numeric_kernel_id = off$numeric_kernel_id,
      penalty_eval_id = off$penalty_eval_id,
      notes = off$notes
    )
  }

  list(
    criterion_id = as.character(row$criterion_id[[1L]]),
    numeric_kernel_id = as.character(row$numeric_kernel_id[[1L]]),
    penalty_eval_id = as.character(row$penalty_eval_id[[1L]]),
    integration = as.character(row$integration[[1L]]),
    estimator_id = as.integer(row$estimator_id[[1L]]),
    public_estimator = as.character(row$public_label[[1L]]),
    public_estimator_is_coarse = isTRUE(row$public_estimator_is_coarse[[1L]]),
    tape_role = tape_role,
    accepted = isTRUE(row$accepted[[1L]]),
    notes = notes,
    penalty_off_tape = penalty_off_tape
  )
}

.gllvmTMB_estimator_id_for_tape <- function(provenance) {
  id <- provenance$estimator_id
  if (length(id) != 1L || is.na(id) || !id %in% 0:2) {
    stop(
      "internal: provenance has no TMB estimator_id in {0,1,2}",
      call. = FALSE
    )
  }
  as.integer(id)
}

.gllvmTMB_resolved_integration <- function(fit) {
  if (inherits(fit, "gllvmTMB_va") || identical(fit$integration, "va")) {
    return("va")
  }
  if (isTRUE(fit$aghq$used)) {
    return("aghq")
  }
  "laplace"
}

.gllvmTMB_attach_estimator_provenance <- function(fit,
                                                 estimator = "ml",
                                                 reml = FALSE,
                                                 integration = NULL,
                                                 tape_role = "primary") {
  if (is.null(integration)) {
    integration <- .gllvmTMB_resolved_integration(fit)
  }
  fit$estimator_provenance <- .gllvmTMB_resolve_estimator_provenance(
    estimator = estimator,
    reml = reml,
    integration = integration,
    tape_role = tape_role
  )
  fit
}
