#!/usr/bin/env Rscript
source(file.path("dev", "design96-jj-recovery", "oracle.R"))
stopifnot(requireNamespace("TMB", quietly = TRUE), requireNamespace("jsonlite", quietly = TRUE))

out <- file.path("dev", "design96-jj-recovery", "results")
if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE)))
  stop("Design-96 results directory is nonempty; immutable smoke will not rerun")
if (!dir.exists(out) && !dir.create(out, recursive = TRUE)) stop("Cannot create Design-96 results directory")
atomic_json <- function(path, object) {
  if (file.exists(path)) stop("Refusing to overwrite ", path)
  con <- file(path, open = "wx"); on.exit(close(con), add = TRUE)
  writeLines(jsonlite::toJSON(object, auto_unbox = TRUE, null = "null", na = "null", digits = 16, pretty = TRUE), con)
}
as_record <- function(x) { if (is.null(x)) NULL else x }
cpp <- file.path("dev", "design96-jj-recovery", "src", "design96_jj_va.cpp")
TMB::compile(cpp, flags = "-O0")
dyn.load(TMB::dynlib(sub("[.]cpp$", "", cpp)))
atomic_json(file.path(out, "manifest.json"), list(
  design = 96L, seeds = c(strong = 96002L, moderate = 96003L), starts = c("A", "B", "C"),
  optimizer = list(nlminb = list(iter.max = 1000L, eval.max = 1200L), BFGS = list(reltol = 1e-12, maxit = 1500L)),
  source_md5 = unname(tools::md5sum(cpp)), R = R.version.string, TMB = as.character(utils::packageVersion("TMB")),
  platform = R.version$platform, started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)))

run_attempt <- function(fixture, start_label) {
  precheck <- all(fixture$y %in% c(0, 1)) && all(colSums(fixture$y) > 0) && all(colSums(fixture$y) < nrow(fixture$y)) && all(is.finite(fixture$y))
  if (!precheck) return(list(fixture = fixture$label, start = start_label, status = "PRECHECK_FAIL", healthy = FALSE))
  warnings <- character()
  ans <- tryCatch(withCallingHandlers({
    obj <- TMB::MakeADFun(data = list(y = fixture$y), parameters = d96_start(start_label, fixture$y), DLL = "design96_jj_va", silent = TRUE)
    p1 <- nlminb(obj$par, obj$fn, obj$gr, control = list(iter.max = 1000L, eval.max = 1200L))
    p2 <- optim(p1$par, obj$fn, obj$gr, method = "BFGS", control = list(reltol = 1e-12, maxit = 1500L))
    n <- nrow(fixture$y); T <- ncol(fixture$y); x <- p2$par; a <- T; b <- a + 2L * T - 1L; c <- b + 2L * n
    beta <- x[seq_len(a)]; lf <- x[(a + 1L):b]; mean <- matrix(x[(b + 1L):c], n, 2L); log_sd <- matrix(x[(c + 1L):(c + 2L * n)], n, 2L)
    Lhat <- d96_loading_from_free(lf, T); Shat <- Lhat %*% t(Lhat); Struth <- fixture$loading %*% t(fixture$loading)
    eig <- eigen(Shat, symmetric = TRUE, only.values = TRUE)$values[1:2]; etrue <- eigen(Struth, symmetric = TRUE, only.values = TRUE)$values[1:2]
    pi_hat <- d96_marginal_probability(beta, lf)
    truth_free <- c(log(fixture$loading[1, 1]), fixture$loading[2, 1], log(fixture$loading[2, 2]), as.vector(t(fixture$loading[3:T, , drop = FALSE])))
    pi_truth <- d96_marginal_probability(fixture$beta, truth_free)
    z <- list(fixture = fixture$label, start = start_label, status = "FITTED", phase1_convergence = p1$convergence,
      phase2_convergence = p2$convergence, objective = p2$value, gradient_max = max(abs(obj$gr(p2$par))),
      beta = beta, loading_free = lf, covariance = Shat, eigen = eig, marginal_probability = pi_hat,
      probability_rmse = sqrt(mean((pi_hat - pi_truth)^2)), covariance_max_error = max(abs(Shat - Struth)),
      beta_rmse = sqrt(mean((beta - fixture$beta)^2)), eigen_relative_error = abs(eig - etrue) / etrue,
      warnings = warnings, realised_seed = fixture$seed)
    z$healthy <- d96_health(z); z
  }, warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
  error = function(e) list(fixture = fixture$label, start = start_label, status = "ERROR", healthy = FALSE, error = conditionMessage(e), warnings = warnings, realised_seed = fixture$seed))
  ans
}

records <- list()
for (label in c("strong", "moderate")) {
  fixture <- d96_fixture(label)
  atomic_json(file.path(out, paste0("fixture-", label, ".json")), list(label = label, seed = fixture$seed, scale = fixture$scale,
    beta = fixture$beta, loading = fixture$loading, response = fixture$y))
  for (start in c("A", "B", "C")) {
    record <- run_attempt(fixture, start)
    atomic_json(file.path(out, paste0("attempt-", label, "-", start, ".json")), record)
    records[[paste(label, start, sep = "-")]] <- record
  }
}
fixture_verdict <- function(label) {
  r <- records[grep(paste0("^", label, "-"), names(records))]
  if (!all(vapply(r, function(x) isTRUE(x$healthy), logical(1)))) return(list(fixture = label, pass = FALSE, reason = "HEALTH_FAIL"))
  metric <- function(field) vapply(r, `[[`, numeric(1), field)
  covs <- lapply(r, `[[`, "covariance"); betas <- lapply(r, `[[`, "beta"); pis <- lapply(r, `[[`, "marginal_probability")
  pair_max <- function(xs) max(vapply(combn(seq_along(xs), 2L, simplify = FALSE), function(ix) max(abs(xs[[ix[1]]] - xs[[ix[2]]])), numeric(1)))
  pass <- all(metric("probability_rmse") < .10, metric("covariance_max_error") < .75, metric("beta_rmse") < .50,
    vapply(r, function(x) all(x$eigen_relative_error < .75), logical(1))) && pair_max(covs) < .25 && pair_max(betas) < .25 && pair_max(pis) < .05
  list(fixture = label, pass = pass, probability_rmse = metric("probability_rmse"), covariance_max_error = metric("covariance_max_error"),
    beta_rmse = metric("beta_rmse"), eigen_relative_error = lapply(r, `[[`, "eigen_relative_error"),
    pairwise = list(covariance = pair_max(covs), beta = pair_max(betas), marginal_probability = pair_max(pis)))
}
summary <- lapply(c("strong", "moderate"), fixture_verdict); names(summary) <- c("strong", "moderate")
atomic_json(file.path(out, "summary.json"), list(design = 96L, verdict = if (all(vapply(summary, `[[`, logical(1), "pass"))) "SMOKE_PASS" else "SMOKE_STOP", fixtures = summary,
  attempt_count = length(records), completed_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)))
cat("Design 96 verdict:", if (all(vapply(summary, `[[`, logical(1), "pass"))) "SMOKE_PASS" else "SMOKE_STOP", "\n")
