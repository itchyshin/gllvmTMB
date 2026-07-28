## Arc 0 verification -- JJ binomial default + L-BFGS-B polish.
##
## Three claims, each checked separately:
##   1. eval_method resolution:  "auto" -> JJ on binomial, GH elsewhere; the
##      explicit "gh" level reproduces the OLD "auto" behaviour exactly.
##   2. Objective identity: the L-BFGS-B polish reaches the same objective as
##      the BFGS polish it replaces, from the same nlminb optimum.
##   3. Speed, measured INTERLEAVED (never a single sequential pass -- there is
##      a ~3x first-fit-in-session penalty that has retracted three claims).
##
## Poisson must be untouched throughout.

root <- normalizePath(".")
suppressMessages(devtools::load_all(root, quiet = TRUE))

ok <- function(label) cat(sprintf("  OK  %s\n", label))
section <- function(x) cat(sprintf("\n== %s ==\n", x))

## ---------------------------------------------------------------------------
## 1. Resolution semantics
## ---------------------------------------------------------------------------
section("1. eval_method resolution")

stopifnot(identical(.va_r3_resolve_eval_method("auto", 1L), "jj"))
ok('auto + binomial   -> jj   (the flip)')
stopifnot(identical(.va_r3_resolve_eval_method("auto", 2L), "gh"))
ok('auto + poisson    -> gh   (untouched)')
stopifnot(identical(.va_r3_resolve_eval_method("auto", 3L), "gh"))
ok('auto + gaussian   -> gh   (untouched)')
stopifnot(identical(.va_r3_resolve_eval_method("gh", 1L), "gh"))
ok('gh   + binomial   -> gh   (GH still reachable: the controlled arms need it)')

stopifnot(identical(.va_r3_eval_method_code("auto", 1L), 1L),
          identical(.va_r3_eval_method_code("gh", 1L), 0L),
          identical(.va_r3_eval_method_code("jj", 1L), 1L),
          identical(.va_r3_eval_method_code("auto", 2L), 0L))
ok("TMB data codes agree (0 = GH, 1 = JJ)")

stopifnot(inherits(try(.va_r3_resolve_eval_method("jj", 2L), silent = TRUE), "try-error"))
ok("jj on a non-binomial family still fails closed")

stopifnot(identical(.va_r3_objective_type("jj"), "ELBO_JJ"),
          identical(.va_r3_objective_type("gh"), "ELBO_GH"))
ok("objective_type reports the RESOLVED bound, not the request")

## ---------------------------------------------------------------------------
## Fixtures
## ---------------------------------------------------------------------------
simulate_long <- function(n_units, n_traits, q, seed, family) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(n_traits))
  Lambda <- matrix(rnorm(n_traits * q, sd = 0.7), n_traits, q)
  beta <- rnorm(n_traits, sd = 0.3)
  Z <- matrix(rnorm(n_units * q), n_units, q)
  eta <- matrix(beta, n_units, n_traits, byrow = TRUE) + Z %*% t(Lambda)
  Y <- if (family == "binomial") {
    matrix(rbinom(n_units * n_traits, 1L, plogis(eta)), n_units, n_traits)
  } else {
    matrix(rpois(n_units * n_traits, exp(eta)), n_units, n_traits)
  }
  long <- data.frame(
    unit  = factor(rep(seq_len(n_units), times = n_traits)),
    trait = factor(rep(trait_names, each = n_units), levels = trait_names),
    value = as.vector(Y)
  )
  list(y = long$value, n_trials = rep(1L, nrow(long)),
       X = stats::model.matrix(~ 0 + trait, long),
       unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
       q = q, family = family,
       link = if (family == "binomial") "logit" else "log")
}

build_objective <- function(fx, eval_method, H = 15L) {
  validated <- .va_r3_validate_data(
    fx$y, fx$n_trials, fx$X, fx$unit_id, fx$trait_id, fx$q,
    NULL, NULL, fx$family, fx$link, FALSE, FALSE, FALSE, NULL, FALSE, FALSE, 1
  )
  obj <- .va_r3_make_objective(
    validated, H = H, parameters = .va_r3_default_parameters(validated, 1L),
    silent = TRUE, eval_method = eval_method
  )
  list(obj = obj, validated = validated)
}

CONTROL <- list(eval.max = 2000L, iter.max = 2000L)

## ---------------------------------------------------------------------------
## 2. Objective identity: BFGS polish vs L-BFGS-B polish
## ---------------------------------------------------------------------------
section("2. objective identity -- BFGS vs L-BFGS-B, same nlminb optimum")

polish_pair <- function(fx, eval_method, H = 15L) {
  b <- build_objective(fx, eval_method, H)
  obj <- b$obj
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr, control = CONTROL)
  old <- stats::optim(opt$par, obj$fn, obj$gr, method = "BFGS",
                      control = list(maxit = 500L, reltol = 1e-12))
  new <- stats::optim(opt$par, obj$fn, obj$gr, method = "L-BFGS-B",
                      control = list(maxit = 500L,
                                     factr = 1e-12 / .Machine$double.eps))
  list(nlminb = opt$objective, bfgs = old$value, lbfgsb = new$value,
       bfgs_conv = old$convergence, lbfgsb_conv = new$convergence,
       bfgs_evals = unname(old$counts[1]), lbfgsb_evals = unname(new$counts[1]),
       grad_bfgs = max(abs(obj$gr(old$par))),
       grad_lbfgsb = max(abs(obj$gr(new$par))))
}

cases <- list(
  list(tag = "binomial GH", fx = simulate_long(200, 8, 2, 101, "binomial"), em = "gh"),
  list(tag = "binomial JJ", fx = simulate_long(200, 8, 2, 101, "binomial"), em = "jj"),
  list(tag = "poisson  GH", fx = simulate_long(200, 8, 2, 202, "poisson"),  em = "auto")
)

identity_rows <- lapply(cases, function(cs) {
  r <- polish_pair(cs$fx, cs$em)
  reldiff <- abs(r$bfgs - r$lbfgsb) / max(1, abs(r$bfgs))
  cat(sprintf(
    "  %-12s nlminb=%.10f  BFGS=%.10f  L-BFGS-B=%.10f  rel.diff=%.3e\n",
    cs$tag, r$nlminb, r$bfgs, r$lbfgsb, reldiff))
  cat(sprintf("  %-12s max|grad| BFGS=%.3e  L-BFGS-B=%.3e   fn evals %d vs %d\n",
              "", r$grad_bfgs, r$grad_lbfgsb, r$bfgs_evals, r$lbfgsb_evals))
  data.frame(case = cs$tag, bfgs = r$bfgs, lbfgsb = r$lbfgsb, reldiff = reldiff)
})
identity_tab <- do.call(rbind, identity_rows)
stopifnot(all(identity_tab$reldiff < 1e-8))
ok("all objectives agree to < 1e-8 relative")

## ---------------------------------------------------------------------------
## 3. Interleaved timing
## ---------------------------------------------------------------------------
section("3. interleaved timing")

## 3a. The polish step alone -- the part Arc 0 actually changed.
time_polish <- function(fx, eval_method, reps = 5L) {
  b <- build_objective(fx, eval_method)
  obj <- b$obj
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr, control = CONTROL)
  tb <- tl <- numeric(reps)
  for (i in seq_len(reps)) {            # A/B/A/B, never a sequential pass
    t0 <- proc.time()[["elapsed"]]
    stats::optim(opt$par, obj$fn, obj$gr, method = "BFGS",
                 control = list(maxit = 500L, reltol = 1e-12))
    tb[i] <- proc.time()[["elapsed"]] - t0
    t0 <- proc.time()[["elapsed"]]
    stats::optim(opt$par, obj$fn, obj$gr, method = "L-BFGS-B",
                 control = list(maxit = 500L, factr = 1e-12 / .Machine$double.eps))
    tl[i] <- proc.time()[["elapsed"]] - t0
  }
  list(bfgs = median(tb), lbfgsb = median(tl))
}

for (n in c(200L, 800L)) {
  fx <- simulate_long(n, 8L, 2L, 303L, "binomial")
  tp <- time_polish(fx, "gh")
  cat(sprintf("  polish n=%4d  BFGS=%.3fs  L-BFGS-B=%.3fs  speed-up=%.1fx\n",
              n, tp$bfgs, tp$lbfgsb, tp$bfgs / tp$lbfgsb))
}

## 3b. Whole fit, GH vs JJ -- the binomial default flip. This is the number
## that matters; the polish step above is only the part Arc 0 edited.
time_fit <- function(fx, eval_method) {
  t0 <- proc.time()[["elapsed"]]
  f <- .approximation_engine_fit(
    engine = "va_r3", y = fx$y, n_trials = fx$n_trials, X = fx$X,
    unit_id = fx$unit_id, trait_id = fx$trait_id, q = fx$q,
    family = fx$family, link = fx$link, H = 15L, silent = TRUE,
    eval_method = eval_method)
  secs <- proc.time()[["elapsed"]] - t0
  st <- f$status
  list(secs = secs,
       status = if (is.list(st)) as.character(st[[1L]]) else as.character(st))
}

for (n in c(200L, 400L, 800L)) {
  fx <- simulate_long(n, 8L, 2L, 404L, "binomial")
  tg <- tj <- numeric(3L)
  for (i in 1:3) {                      # interleaved A/B/A/B
    tg[i] <- time_fit(fx, "gh")$secs
    tj[i] <- time_fit(fx, "jj")$secs
  }
  cat(sprintf("  full fit n=%4d binomial  GH=%6.2fs  JJ=%6.2fs  speed-up=%.1fx\n",
              n, median(tg), median(tj), median(tg) / median(tj)))
}

cat("\nARC 0 VERIFICATION PASSED\n")
