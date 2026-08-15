## Callback adapter for PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1.
##
## This file does not construct an ADFun object.  A future clean worker passes
## one already-created object and owns its release.  The adapter preserves the
## raw callback evidence needed by the pure trust-region contract.

.spde_slope_gauge_tr_adapter_fail <- function(message) {
  stop(message, call. = FALSE)
}

.spde_slope_gauge_tr_adapter_scalar_character <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    .spde_slope_gauge_tr_adapter_fail(sprintf("%s must be one nonempty character value", what))
  }
  x
}

.spde_slope_gauge_tr_adapter_object_ok <- function(object) {
  raw_order <- spde_slope_gauge_raw_order()
  is.list(object) &&
    is.function(object$fn) &&
    is.function(object$gr) &&
    is.double(object$par) &&
    identical(names(object$par), raw_order) &&
    length(object$par) == length(raw_order) &&
    all(is.finite(object$par))
}

.spde_slope_gauge_tr_adapter_gradient <- function(value, raw_order) {
  if (!is.numeric(value) || length(value) != length(raw_order) || any(!is.finite(value))) {
    .spde_slope_gauge_tr_adapter_fail("gradient callback must return 22 finite coordinates")
  }
  supplied_names <- names(value)
  if (!is.null(supplied_names) && !identical(supplied_names, raw_order)) {
    .spde_slope_gauge_tr_adapter_fail("gradient callback supplied a noncanonical positional order")
  }
  list(
    supplied_names = supplied_names,
    raw_values = as.double(unname(value)),
    named_gradient = stats::setNames(as.double(unname(value)), raw_order)
  )
}

spde_slope_gauge_trust_region_callback_adapter <- function(
  object,
  object_id,
  dll_path,
  dll_md5,
  sdreport_fn
) {
  raw_order <- spde_slope_gauge_raw_order()
  if (!.spde_slope_gauge_tr_adapter_object_ok(object) || !is.integer(object_id) ||
      length(object_id) != 1L || is.na(object_id) || object_id <= 0L ||
      !is.function(sdreport_fn)) {
    .spde_slope_gauge_tr_adapter_fail("callback adapter object or factory evidence is invalid")
  }
  dll_path <- .spde_slope_gauge_tr_adapter_scalar_character(dll_path, "DLL path")
  dll_md5 <- .spde_slope_gauge_tr_adapter_scalar_character(dll_md5, "DLL MD5")
  audit <- new.env(parent = emptyenv())
  audit$objective <- list()
  audit$gradient <- list()
  audit$covariance <- list()
  audit$call_index <- 0L
  append_record <- function(type, record) {
    audit$call_index <- audit$call_index + 1L
    record$call_index <- as.integer(audit$call_index)
    record$object_id <- object_id
    record$dll_path <- dll_path
    record$dll_md5 <- dll_md5
    audit[[type]][[length(audit[[type]]) + 1L]] <- record
  }
  evaluate <- function(phi) {
    theta <- spde_slope_gauge_theta_from_phi(phi)
    objective <- tryCatch(object$fn(unname(theta)), error = function(e) e)
    if (inherits(objective, "error")) {
      .spde_slope_gauge_tr_adapter_fail(conditionMessage(objective))
    }
    objective <- .spde_slope_gauge_tr_scalar(as.double(unname(objective)), "objective callback")
    append_record("objective", list(raw_theta = theta, value = objective))
    gradient <- tryCatch(object$gr(unname(theta)), error = function(e) e)
    if (inherits(gradient, "error")) {
      .spde_slope_gauge_tr_adapter_fail(conditionMessage(gradient))
    }
    gradient <- .spde_slope_gauge_tr_adapter_gradient(gradient, raw_order)
    append_record("gradient", c(list(raw_theta = theta), gradient))
    list(objective = objective, raw_theta = theta, raw_gradient = gradient$named_gradient)
  }
  covariance <- function(theta) {
    theta <- .spde_slope_gauge_tr_raw(theta, "candidate raw theta")
    value <- tryCatch(sdreport_fn(object, unname(theta)), error = function(e) e)
    if (inherits(value, "error")) .spde_slope_gauge_tr_adapter_fail(conditionMessage(value))
    append_record("covariance", list(raw_theta = theta, result = value))
    value
  }
  list(
    evaluate = evaluate,
    covariance = covariance,
    audit = function() {
      list(
        object_id = object_id,
        dll_path = dll_path,
        dll_md5 = dll_md5,
        objective = audit$objective,
        gradient = audit$gradient,
        covariance = audit$covariance
      )
    }
  )
}
