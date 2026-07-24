#!/usr/bin/env Rscript

design_dir <- normalizePath(file.path("dev", "design98-factorial-va-jj"))
options(d98_design_dir = design_dir)
source(file.path(design_dir, "R", "records.R"))
source(file.path(design_dir, "R", "oracle.R"))
source(file.path(design_dir, "R", "fits.R"))

assert <- function(x, label) if (!isTRUE(x)) stop(label, " failed")

y <- rbind(c(1, 0, 1), c(0, 1, 0), c(1, 1, 0), c(0, 0, 1))
beta <- c(-.2, .1, .25)
loading <- rbind(c(.7, 0), c(.1, .6), c(-.25, .2))
loading_free <- d98_loading_to_free(loading)
truth <- list(beta = beta, loading = loading)
input <- list(truth = truth)

make_fixed <- function(method) {
  full <- d98_fit_full(method)
  local <- d98_declared_local_start(nrow(y), full)
  transformed <- d98_transform_variational(
    beta, loading_free, local$mean, local$chol_free, method
  )
  elbo <- d98_variational_elbo(
    y, beta, loading_free, local$mean, local$chol_free, method, d98_gh(31L)
  )
  list(
    status = "healthy",
    estimator_kind = "fixed_local",
    method = method,
    start_id = "fixed",
    raw_coordinates = c(as.vector(local$mean), as.vector(local$chol_free)),
    transformed_parameters = transformed,
    objective = -elbo,
    metrics = c(
      d98_accuracy_metrics(transformed, truth),
      list(optimized_objective = -elbo)
    )
  )
}

fixed <- lapply(c("QD", "QF", "JD", "JF"), make_fixed)
names(fixed) <- c("QD", "QF", "JD", "JF")
fixed$JD$status <- "unhealthy"
contrasts <- d98_fixed_factorial_contrasts(fixed, y, input)
assert(isTRUE(contrasts$available$G_Q), "G_Q survives unrelated JD failure")
assert(isTRUE(contrasts$available$B_F), "B_F survives unrelated JD failure")
assert(isTRUE(contrasts$available$D_F), "D_F survives unrelated JD failure")
assert(!isTRUE(contrasts$available$G_J), "G_J requires JD")
assert(!isTRUE(contrasts$available$B_D), "B_D requires JD")
assert(!isTRUE(contrasts$available$D_D), "D_D requires JD")

entry <- function(id, payload, terminal = "healthy") {
  list(
    task_id = id,
    terminal_status = terminal,
    terminal = list(status = terminal),
    payload_sha256 = paste0("hash-", id),
    payload = payload
  )
}
fixed_eval <- d98_evaluate_fixed_local(
  input,
  Map(entry, paste0("fixed_", names(fixed)), fixed),
  y,
  truth
)
assert(identical(fixed_eval$status, "healthy"),
       "partial fixed-local adjudication")
assert(isTRUE(fixed_eval$contrasts$available$G_Q),
       "partial contrasts retained")

# Authoritative terminal health overrides a nominally healthy payload.
endpoint <- list(
  status = "healthy",
  metrics = list(
    accuracy_flag = TRUE,
    epsilon_GH = 0,
    gh_log_marginal_61 = -10
  )
)
summary <- d98_evaluate_summary(
  list(),
  list(
    entry("evaluate_gh_low", endpoint, "timed_out"),
    entry("evaluate_gh_high", endpoint)
  )
)
assert(identical(summary$decision_status, "TECHNICAL_INCOMPLETE"),
       "terminal-invalid payload cannot label")
assert(!isTRUE(summary$dependency_availability$evaluate_gh_low),
       "terminal health is authoritative")

cat("Design 98 adjudication tests: PASS\n")
