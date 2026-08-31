# Exercise the exact trace expressions and evaluate hook without a model fit.
script <- parse("dev/covariance-teaching/render.R")
find_call <- function(prefix) {
  hit <- vapply(script, function(x) startsWith(paste(deparse(x), collapse = " "), prefix), logical(1))
  stopifnot(sum(hit) == 1L)
  script[[which(hit)]]
}
.fit_receipt <- new.env(parent = emptyenv())
.fit_receipt$count <- 0L
.fit_receipt$depth <- 0L
.fit_receipt$convergence <- integer()
fit_log <- tempfile()
warning_log <- tempfile()
file.create(fit_log, warning_log)
# Function environment is a package namespace, exactly as in the real target.
toy_env <- new.env()
toy_env$gllvmTMB <- eval(quote(function() list(opt = list(convergence = 0L,
                                                       message = "stub only"))),
                          asNamespace("gllvmTMB"))
trace_call <- find_call('trace("gllvmTMB"')
trace_call$where <- quote(toy_env)
eval(trace_call)
stopifnot(identical(toy_env$gllvmTMB()$opt$convergence, 0L),
          .fit_receipt$count == 1L,
          identical(.fit_receipt$convergence, 0L),
          any(grepl("START 1", readLines(fit_log), fixed = TRUE)),
          any(grepl("END 1 convergence 0 message stub only", readLines(fit_log), fixed = TRUE)))
cat("TRACE_NAMESPACE_BINDINGS_VERIFIED\n")
# Exercise nested forwarding separately with the same trace expressions.
recursive_env <- new.env(parent = asNamespace("gllvmTMB"))
recursive_env$gllvmTMB <- eval(quote(function(n = 1L) {
  if (n > 0L) return(gllvmTMB(n - 1L))
  list(opt = list(convergence = 0L, message = "recursive stub only"))
}), recursive_env)
trace_call$where <- quote(recursive_env)
eval(trace_call)
recursive_env$gllvmTMB()
stopifnot(.fit_receipt$count == 2L, .fit_receipt$depth == 0L,
          identical(.fit_receipt$convergence, c(0L, 0L)))
cat("NESTED_FORWARDING_COUNTS_ONE_FIT_VERIFIED\n")
eval(find_call("knitr::knit_hooks$set(evaluate"))
out <- knitr::knit(text = c("```{r toy-warning, warning=FALSE, echo=FALSE}",
                           "warning('HARNESS_WARNING_SENTINEL')", "1 + 1", "```"),
                   quiet = TRUE)
stopifnot(any(grepl("HARNESS_WARNING_SENTINEL", readLines(warning_log), fixed = TRUE)),
          !grepl("HARNESS_WARNING_SENTINEL", out, fixed = TRUE),
          grepl("2", out, fixed = TRUE))
cat("KNITR_SUPPRESSED_WARNING_CAPTURE_VERIFIED\n")
cat("HARNESS_VERIFIED_WITHOUT_FITS\n")
