.make_animal_coef_fixture <- function(seed = 13141L, n_traits = 5L,
                                      n_unit = 16L) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  data <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  data$x <- stats::rnorm(nrow(data))
  data$z <- stats::rnorm(nrow(data))
  data$value <- 0.2 + stats::rnorm(nrow(data), sd = 0.45)

  d <- seq(0.7, 1.3, length.out = n_traits)
  R <- 0.35^abs(outer(seq_len(n_traits), seq_len(n_traits), "-"))
  A <- outer(d, d) * R
  dimnames(A) <- list(traits, traits)
  list(data = data, traits = traits, A = A)
}

.make_animal_coef_pedigree_fixture <- function(seed = 13145L) {
  ped <- data.frame(
    id = paste0("t", 1:6),
    sire = c(NA, NA, "t1", "t1", "t3", "t3"),
    dam = c(NA, NA, "t2", "t2", "t4", "t4"),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  fx <- .make_animal_coef_fixture(
    seed = seed, n_traits = nrow(A), n_unit = 14L
  )
  fx$A <- A[fx$traits, fx$traits, drop = FALSE]
  fx$Ainv <- gllvmTMB::pedigree_to_Ainv_sparse(ped)
  fx$pedigree <- ped
  fx
}

.parse_animal_coef_formula <- function(formula, data, trait = "trait") {
  gllvmTMB:::.parse_column_coef_formula(
    formula = formula,
    trait_col = trait,
    row_vars = names(data),
    column_vars = character(),
    response_vars = all.vars(formula[[2L]])
  )
}

.free_animal_map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) {
    if (is.null(x)) NULL else as.integer(x)
  })
}

.expect_animal_route_identical <- function(coef_fit, slope_fit,
                                          diagnostics = NULL) {
  expect_identical(coef_fit$tmb_data, slope_fit$tmb_data)
  expect_identical(coef_fit$tmb_obj$env$random, slope_fit$tmb_obj$env$random)
  expect_identical(names(coef_fit$opt$par), names(slope_fit$opt$par))
  expect_identical(
    .free_animal_map_signature(coef_fit),
    .free_animal_map_signature(slope_fit)
  )
  common <- slope_fit$opt$par
  expect_identical(coef_fit$tmb_obj$fn(common), slope_fit$tmb_obj$fn(common))
  coef_gradient <- coef_fit$tmb_obj$gr(common)
  slope_gradient <- slope_fit$tmb_obj$gr(common)
  expect_identical(coef_gradient, slope_gradient)
  if (!is.null(diagnostics)) {
    diagnostics$endpoint_gradients <- list(
      at = common, coef = coef_gradient, slope = slope_gradient
    )
  }
  expect_identical(coef_fit$opt$objective, slope_fit$opt$objective)
  expect_identical(coef_fit$opt$par, slope_fit$opt$par)
  expect_identical(coef_fit$report, slope_fit$report)
  expect_identical(
    suppressMessages(stats::fitted(coef_fit)),
    suppressMessages(stats::fitted(slope_fit))
  )
}

# Diagnostic only: preserve the original optimizer calls and warning delivery.
# This runs around the existing two-bar equivalence test, without adding fits
# or evaluating its objective/gradient outside the calls already made there.
.with_animal_trial_diagnostics <- function(code, label, diagnostics) {
  diagnostics$label <- label
  diagnostics$calls <- list()
  original <- get(".gllvmTMB_run_nlminb", asNamespace("gllvmTMB"))
  wrapped <- function(args) {
    record <- new.env(parent = emptyenv())
    record$start <- args$start
    record$controls <- args[intersect(
      names(args), c("control", "lower", "upper", "scale")
    )]
    record$objective_calls <- 0L
    record$nonfinite_trials <- list()
    record$warnings <- character()
    diagnostics$calls[[length(diagnostics$calls) + 1L]] <- record
    objective <- args$objective
    args$objective <- function(par, ...) {
      value <- objective(par, ...)
      record$objective_calls <- record$objective_calls + 1L
      if (any(!is.finite(value))) {
        record$nonfinite_trials[[length(record$nonfinite_trials) + 1L]] <- list(
          evaluation = record$objective_calls, par = par, value = value
        )
      }
      value
    }
    result <- withCallingHandlers(original(args), warning = function(w) {
      record$warnings <- c(record$warnings, conditionMessage(w))
    })
    record$result <- result
    result
  }
  on.exit({
    calls <- lapply(diagnostics$calls, as.list.environment)
    if (any(vapply(calls, function(x) length(x$warnings) > 0L, logical(1)))) {
      cat("\nANIMAL_TRIAL_DIAGNOSTICS_BEGIN\n")
      dput(list(label = diagnostics$label, calls = calls,
                endpoint_gradients = diagnostics$endpoint_gradients))
      cat("ANIMAL_TRIAL_DIAGNOSTICS_END\n")
    }
  }, add = TRUE)
  testthat::with_mocked_bindings(
    force(code), .gllvmTMB_run_nlminb = wrapped, .package = "gllvmTMB"
  )
}

.fit_animal_coef_test <- function(fx, formula) {
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
}
