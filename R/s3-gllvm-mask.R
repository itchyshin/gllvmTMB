## #1759 / #1768. gllvm exports S3 generics named getLoadings, getLV,
## getResidualCov, getResidualCor, VP, and simulate. After library(gllvm) those generics
## mask gllvmTMB's plain functions, and UseMethod finds no method for a
## gllvmTMB fit. The exported functions stay plain functions with their
## current formals. These wrappers exist only so a call that arrives
## through gllvm's generic (first formal `object`) is forwarded to them.
##
## Registration is delayed, in the style of vctrs::s3_register: .onLoad
## registers immediately when gllvm is already loaded, and a package-load
## hook registers if gllvm is loaded later. gllvm is not imported.

.gllvm_mask_hook_installed <- FALSE

.gllvm_mask_classes <- c(
  "gllvmTMB",
  "gllvmTMB_multi",
  "gllvmTMB_mspl",
  "gllvmTMB_va",
  "gllvmTMB_julia"
)

.gllvm_mask_call <- function(fn, object, ...) {
  fn(fit = object, ...)
}

.gllvm_mask_getLoadings <- function(object, ...) {
  .gllvm_mask_call(getLoadings, object, ...)
}

.gllvm_mask_getLV <- function(object, ...) {
  .gllvm_mask_call(getLV, object, ...)
}

.gllvm_mask_getResidualCov <- function(object, ...) {
  .gllvm_mask_call(getResidualCov, object, ...)
}

.gllvm_mask_getResidualCor <- function(object, ...) {
  .gllvm_mask_call(getResidualCor, object, ...)
}

.gllvm_mask_VP <- function(object, ...) {
  .gllvm_mask_call(VP, object, ...)
}

.gllvm_mask_simulate <- function(object, ...) {
  stats::simulate(object, ...)
}

.gllvm_mask_methods <- list(
  getLoadings = .gllvm_mask_getLoadings,
  getLV = .gllvm_mask_getLV,
  getResidualCov = .gllvm_mask_getResidualCov,
  getResidualCor = .gllvm_mask_getResidualCor,
  VP = .gllvm_mask_VP,
  simulate = .gllvm_mask_simulate
)

.gllvm_mask_body_calls_usemethod <- function(fn) {
  b <- body(fn)
  if (!is.language(b)) {
    return(FALSE)
  }
  found <- FALSE
  walk <- function(e) {
    if (found) {
      return(invisible(NULL))
    }
    if (is.call(e) && identical(e[[1L]], quote(UseMethod))) {
      found <<- TRUE
      return(invisible(NULL))
    }
    if (is.pairlist(e) || is.call(e) || is.expression(e)) {
      for (arg in as.list(e)) {
        if (!is.null(arg)) {
          walk(arg)
        }
      }
    }
    invisible(NULL)
  }
  walk(b)
  found
}

.gllvm_mask_is_generic <- function(fn) {
  if (!is.function(fn)) {
    return(FALSE)
  }
  if (isTRUE(utils::isS3stdGeneric(fn))) {
    return(TRUE)
  }
  .gllvm_mask_body_calls_usemethod(fn)
}

.register_gllvm_masking_methods <- function() {
  if (!isNamespaceLoaded("gllvm")) {
    return(invisible(FALSE))
  }
  ns <- asNamespace("gllvm")
  for (genname in names(.gllvm_mask_methods)) {
    if (!exists(genname, envir = ns, mode = "function", inherits = FALSE)) {
      next
    }
    gen <- get(genname, envir = ns, mode = "function", inherits = FALSE)
    if (!.gllvm_mask_is_generic(gen)) {
      next
    }
    method <- .gllvm_mask_methods[[genname]]
    for (cls in .gllvm_mask_classes) {
      registerS3method(genname, cls, method, envir = ns)
    }
  }
  invisible(TRUE)
}

.gllvm_mask_on_gllvm_load <- function(...) {
  .register_gllvm_masking_methods()
}
