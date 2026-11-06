test_that("prior attachment rejects mapped vectors, repeated application and extreme scales", {
  q <- .gllvmTMB_resolve_fixed_priors(
    data.frame(coefficient = "b", mean = 0, sd = 2), c("a", "b", "c"))
  obj <- list(par = setNames(c(.1, .2), c("b_fix", "b_fix")),
              fn = function(p) sum(p^2), gr = function(p) 2*p)
  expect_error(.gllvmTMB_attach_fixed_priors(obj, q), "unmapped")
  obj$par <- setNames(c(.1, .8, .2, .3), c("b_fix", "nuisance", "b_fix", "b_fix"))
  attached <- .gllvmTMB_attach_fixed_priors(obj, q)
  expect_null(attached$he)
  expect_equal(unname(attached$gr(obj$par) - obj$gr(obj$par)), c(0, 0, .2/4, 0))
  expect_error(.gllvmTMB_attach_fixed_priors(attached, q), "already")
  for (s in c(1e-200, 1e200)) {
    expect_error(.gllvmTMB_resolve_fixed_priors(
      data.frame(coefficient = "a", mean = 0, sd = s), "a"), "precision")
  }
})

test_that("link-aware helper reports explicit latent-reference scales", {
  expect_error(fixed_effect_priors("logit", "traita", "traita:x"), "standard")
  a <- fixed_effect_priors("logit", c("traita", "traitb"), "traita:x",
                           standardized = TRUE, intercept_scale = 2, slope_scale = .5)
  expect_equal(a$sd, c(2, 2, .5) * pi / sqrt(3))
  expect_equal(a$mean, c(0, 0, 0))
  expect_equal(a$coefficient, c("traita", "traitb", "traita:x"))
  b <- fixed_effect_priors("probit", "traita", "traita:x", standardized = TRUE,
                           additional_variance = 3)
  expect_equal(b$sd, c(2, 2))
  expect_error(fixed_effect_priors("cloglog", "a", "b", standardized = TRUE), "link")
  expect_error(fixed_effect_priors("logit", "a", "a", standardized = TRUE), "distinct")
  expect_error(fixed_effect_priors("logit", "a", "b", standardized = TRUE,
                                  additional_variance = -1), "variance")
  expect_error(fixed_effect_priors("logit", "a", "b", standardized = TRUE,
    intercept_scale=1e308, additional_variance=1e308), "generated SD")
})

test_that("fixed-effect priors resolve exact design columns, including item intercepts", {
  X <- model.matrix(~ 0 + trait + trait:x,
                    data.frame(trait = factor(rep(c("a", "b"), 3)), x = 1:6))
  priors <- data.frame(coefficient = c("traita", "traitb:x"),
                       mean = c(1, -2), sd = c(2, 10))
  p <- .gllvmTMB_resolve_fixed_priors(priors, colnames(X))
  expect_equal(p$index, c(1L, 4L))
  expect_error(.gllvmTMB_resolve_fixed_priors(transform(priors, coefficient = "bad"),
                                            colnames(X)), "coefficient")
  expect_error(.gllvmTMB_resolve_fixed_priors(transform(priors, sd = 0), colnames(X)), "sd")
  expect_null(.gllvmTMB_resolve_fixed_priors(NULL, colnames(X)))
  expect_error(.gllvmTMB_resolve_fixed_priors(transform(priors, mean = NA_real_), colnames(X)), "mean")
  expect_error(.gllvmTMB_resolve_fixed_priors(priors[c(1, 1), ], colnames(X)), "coefficient")
  expect_error(.gllvmTMB_resolve_fixed_priors(list(sd = 1), colnames(X)), "data.frame")
})

test_that("unsupported routes fail before fitting", {
  priors <- data.frame(coefficient = "traita", mean = 0, sd = 10)
  expect_silent(.gllvmTMB_fixed_prior_route(priors, "tmb", "ml", FALSE,
                                           list(integration = "laplace", aghq = FALSE)))
  for (route in list(
    list("julia", "ml", FALSE, list()),
    list("tmb", "mspl", FALSE, list()),
    list("tmb", "ml", TRUE, list()),
    list("tmb", "ml", FALSE, list(integration = "va")))) {
    expect_error(do.call(.gllvmTMB_fixed_prior_route, c(list(priors), route)),
                 class = "gllvmTMB_fixed_prior_unsupported")
  }
  expect_silent(.gllvmTMB_fixed_prior_route(NULL, "julia", "mspl", TRUE, list()))
})

test_that("normal penalty has analytic objective, gradient and Hessian", {
  par <- setNames(c(.4, -.8, .2), c("b_fix", "b_fix", "theta_rr_B"))
  obj <- list(par = par, fn = function(p) sum(p^2), gr = function(p) 2*p,
              he = function(p) diag(2, length(p)))
  priors <- data.frame(coefficient = c("a", "b"), mean = c(.5, -1), sd = c(2, 3))
  resolved <- .gllvmTMB_resolve_fixed_priors(priors, c("a", "b"))
  out <- .gllvmTMB_attach_fixed_priors(obj, resolved)
  expected <- -sum(dnorm(par[1:2], priors$mean, priors$sd, log = TRUE))
  expect_equal(out$fn(par) - obj$fn(par), expected)
  expect_equal(as.numeric(out$gr(par) - obj$gr(par)), unname(c((par[1:2]-priors$mean)/priors$sd^2, 0)))
  expect_equal(out$he(par) - obj$he(par), diag(c(1/4, 1/9, 0)))
  numeric_gradient <- vapply(seq_along(par), function(j) {
    delta <- numeric(length(par)); delta[j] <- 1e-5
    (out$fn(par + delta) - out$fn(par - delta)) / 2e-5
  }, numeric(1))
  expect_equal(out$gr(par), numeric_gradient, ignore_attr = TRUE)
  expect_equal(out$he(par), unname(stats::optimHess(par, out$fn)), tolerance = 1e-6)
  expect_identical(.gllvmTMB_attach_fixed_priors(obj, NULL), obj)
  unpen <- .gllvmTMB_resolve_fixed_priors(transform(priors, sd = Inf), c("a", "b"))
  expect_identical(.gllvmTMB_attach_fixed_priors(obj, unpen), obj)
})
test_that("control retains the opt-in coefficient prior specification", {
  p <- data.frame(coefficient = "traita", mean = 0, sd = 10)
  expect_identical(gllvmTMBcontrol(fixed_effect_priors = p)$fixed_effect_priors, p)
  expect_null(gllvmTMBcontrol()$fixed_effect_priors)
})


.fixed_prior_fixture <- function(link = "logit", separated = FALSE) {
  set.seed(846)
  n <- 60L
  x <- as.numeric(scale(seq(-2, 2, length.out = n))) / 2
  z <- rnorm(n)
  dat <- expand.grid(trait = factor(c("a", "b", "c")), unit = factor(seq_len(n)))
  dat$x <- rep(x, each = 3)
  eta <- rep(c(-.3, .1, .4), n) + rep(c(.6, -.4, .3), n)*dat$x +
    rep(c(.5, -.3, .4), n)*rep(z, each = 3)
  dat$value <- rbinom(nrow(dat), 1, if (link == "logit") plogis(eta) else pnorm(eta))
  if (separated) dat$value[dat$trait == "a"] <- as.integer(x > 0)
  dat
}

test_that("Laplace normal priors propagate to criterion, diagnostics, curvature and refits", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  for (link in c("logit", "probit")) {
    dat <- .fixed_prior_fixture(link)
    pri <- fixed_effect_priors(link, paste0("trait", letters[1:3]),
      paste0("trait", letters[1:3], ":x"), standardized = TRUE)
    f <- value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE)
    fit <- suppressWarnings(gllvmTMB(f, dat, trait = "trait", unit = "unit",
      family = binomial(link), control = gllvmTMBcontrol(
        fixed_effect_priors = pri, loading_ridge = .75, se = TRUE, svd_start = FALSE, n_init = 1L)))
    wide <- data.frame(unit=factor(seq_len(60)),x=unique(dat$x),
      a=dat$value[dat$trait=="a"],b=dat$value[dat$trait=="b"],c=dat$value[dat$trait=="c"])
    wide_fit <- suppressWarnings(gllvmTMB(
      traits(a,b,c) ~ 1+x+latent(1|unit,d=1,unique=FALSE),wide,unit="unit",
      family=binomial(link),control=gllvmTMBcontrol(
        fixed_effect_priors=pri,loading_ridge=.75,se=FALSE,svd_start=FALSE,n_init=1L)))
    expect_equal(coef(wide_fit),coef(fit),tolerance=1e-6)
    expect_equal(wide_fit$objective_components$optimization_nll,
      fit$objective_components$optimization_nll,tolerance=1e-6)
    expect_identical(fit$estimator_provenance$criterion_id, "laplace_plus_normal_priors")
    expect_identical(fit$estimator_provenance$public_estimator, "MAP")
    expect_identical(fit$estimator_provenance$penalty_eval_id, "off")
    expect_true(fit$estimator_provenance$fixed_effect_prior_applied)
    obj <- fit$tmb_obj
    p <- fit$opt$par
    expect_equal(fit$objective_components$fixed_effect_prior_nll,
      -sum(dnorm(p[names(p) == "b_fix"], pri$mean, pri$sd, log = TRUE)))
    expect_equal(fit$objective_components$optimization_nll, fit$opt$objective, tolerance = 1e-7)
    expect_equal(fit$objective_components$likelihood_nll,
      as.numeric(obj$fixed_effect_priors$likelihood_fn(p)), tolerance = 1e-8)
    H <- .gllvmTMB_loading_ridge_hessian(obj, p, .75)
    expect_equal(fit$sd_report$cov.fixed, solve(H), tolerance = 1e-6)
    expect_equal(as.numeric(fit$sd_report$gradient.fixed),
      .gllvmTMB_penalised_gradient(obj, p, .75), tolerance = 1e-8)
    expect_equal(fit$fit_health$max_gradient,
      max(abs(.gllvmTMB_penalised_gradient(obj,p,.75))), tolerance=1e-8)
    expect_false(attr(fit$sd_report, "fixed_effect_prior_curvature")$calibrated_sampling_covariance)
    expect_true(all(is.finite(vcov(fit))))
    expect_identical(attr(vcov(fit),"inference_status"),
      "local_approximate_posterior_curvature")
    prediction <- predict(fit, type = "response")$est
    expect_length(prediction, nrow(dat))
    expect_true(all(is.finite(prediction)))
    expect_true(all(prediction >= 0 & prediction <= 1))
    expect_equal(predict(fit,newdata=dat,type="response")$est,prediction,tolerance=1e-8)
    expect_error(predict(fit, se.fit = TRUE), class = "gllvmTMB_fixed_prior_inference_unsupported")
    expect_error(confint(fit), class = "gllvmTMB_fixed_prior_inference_unsupported")
    expect_error(generics::tidy(fit,conf.int=TRUE),
      class="gllvmTMB_fixed_prior_inference_unsupported")
    expect_identical(generics::tidy(fit)$inference_status,
      rep("local_approximate_posterior_curvature",length(coef(fit))))
    expect_error(bootstrap_Sigma(fit), class = "gllvmTMB_fixed_prior_inference_unsupported")
    ll <- suppressWarnings(logLik(fit))
    expect_false(attr(ll, "at_maximum"))
    expect_equal(as.numeric(ll), -fit$objective_components$likelihood_nll)
    args <- .bootstrap_refit_args(fit, "test")
    expect_identical(args$control$fixed_effect_priors, pri)
    args$formula <- f
    args$data <- dat
    again <- suppressWarnings(do.call(gllvmTMB, args))
    expect_equal(again$opt$par, fit$opt$par, tolerance = 1e-6)
    again <- suppressWarnings(standard_errors(again))
    expect_equal(again$sd_report$cov.fixed, fit$sd_report$cov.fixed, tolerance = 1e-6)
  }
})

test_that("separation shrinkage and disabled-prior behavior hold in package fits", {
  dat <- .fixed_prior_fixture(separated = TRUE)
  f <- value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE)
  fit_at <- function(sd) suppressWarnings(gllvmTMB(f, dat, trait = "trait", unit = "unit",
    family = binomial(), control = gllvmTMBcontrol(loading_ridge = .75, se = FALSE,
      svd_start = FALSE, n_init = 1L, fixed_effect_priors = if (is.null(sd)) NULL else
        data.frame(coefficient = colnames(model.matrix(~0+trait+trait:x, dat)), mean = 0, sd = sd))))
  strong <- fit_at(.5)
  weak <- fit_at(10)
  expect_lt(abs(coef(strong)["traita:x"]), abs(coef(weak)["traita:x"]))
  expect_equal(fit_at(Inf)$opt$par, fit_at(NULL)$opt$par, tolerance = 1e-9)
})

test_that("Gaussian diagonal integration and partial nonzero-mean priors retain honest likelihood output", {
  set.seed(847)
  n <- 35L
  d <- expand.grid(trait = factor(c("a", "b", "c")), visit = 1:2, unit = factor(seq_len(n)))
  u <- matrix(rnorm(n*3), n, 3)
  d$value <- c(-.2, .3, .6)[as.integer(d$trait)] +
    u[cbind(as.integer(d$unit), as.integer(d$trait))] + rnorm(nrow(d), sd = .4)
  tab <- data.frame(coefficient = "traitb", mean = 1, sd = 2)
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait + indep(0 + trait | unit),
    d, trait = "trait", unit = "unit", control = gllvmTMBcontrol(
      loading_ridge = Inf, fixed_effect_priors = tab, optimizer_passes = 2)))
  expect_false(fit$integrated_gaussian_diag_B)
  single <- suppressWarnings(gllvmTMB(value ~ 0 + trait + indep(0 + trait | unit),
    d[d$visit == 1, ], trait = "trait", unit = "unit", control = gllvmTMBcontrol(
      loading_ridge = Inf, fixed_effect_priors = tab)))
  expect_true(single$integrated_gaussian_diag_B)
  expect_equal(single$objective_components$optimization_nll, single$opt$objective,
               tolerance = 1e-7)
  expect_identical(fit$estimator, "MAP")
  expect_equal(fit$objective_components$fixed_effect_prior_nll,
    -dnorm(coef(fit)["traitb"], 1, 2, log = TRUE), ignore_attr = TRUE)
  expect_equal(fit$sd_report$cov.fixed,
    solve(stats::optimHess(fit$opt$par, fit$tmb_obj$fn, fit$tmb_obj$gr)), tolerance = 1e-6)
  sm <- suppressWarnings(summary(fit))
  expect_equal(sm$header$logLik, -fit$objective_components$likelihood_nll)
  expect_true(sm$header$penalised)
  printed <- capture.output(print(fit))
  expect_true(any(grepl("log L at MAP point", printed)))
  expect_true(any(grepl("local approximate posterior", printed)))
  expect_error(.cv_check_cv_supported(fit), class = "gllvmTMB_fixed_prior_inference_unsupported")
})

test_that("public dispatch refuses unqualified routes and missing responses", {
  dat <- .fixed_prior_fixture()
  p <- data.frame(coefficient="traita",mean=0,sd=2)
  f <- value ~ 0 + trait + latent(0 + trait | unit,d=1,unique=FALSE)
  for(extra in list(list(engine="julia"),list(estimator="mspl"),list(REML=TRUE))) {
    expect_error(do.call(gllvmTMB,c(list(formula=f,data=dat,trait="trait",unit="unit",
      family=binomial(),control=gllvmTMBcontrol(fixed_effect_priors=p)),extra)),
      class="gllvmTMB_fixed_prior_unsupported")
  }
  dat$value[1] <- NA_real_
  expect_error(gllvmTMB(f,dat,trait="trait",unit="unit",family=binomial(),
    control=gllvmTMBcontrol(fixed_effect_priors=p)),class="gllvmTMB_fixed_prior_unsupported")
})

test_that("AGHQ retains the normal prior in its objective", {
  dat <- .fixed_prior_fixture("probit")
  pri <- data.frame(coefficient="traita", mean=.3, sd=2)
  fit <- suppressWarnings(gllvmTMB(value ~ 0 + trait + trait:x +
    latent(0 + trait | unit, d=1, unique=FALSE), dat, trait="trait", unit="unit",
    family=binomial("probit"), control=gllvmTMBcontrol(
      fixed_effect_priors=pri, loading_ridge=.75, aghq=5L,
      aghq_n_adapt=20L, aghq_multistart=FALSE, svd_start=FALSE, n_init=1L)))
  expect_true(fit$aghq$used)
  expect_identical(fit$estimator_provenance$criterion_id, "aghq_plus_normal_priors")
  expect_identical(fit$estimator_provenance$public_estimator, "MAP")
  expect_identical(fit$estimator_provenance$penalty_eval_id, "off")
  expect_true(fit$estimator_provenance$fixed_effect_prior_applied)
  expect_false(any(grepl("public label ML", fit$estimator_provenance$notes, fixed = TRUE)))
  expect_true(fit$estimator_provenance$public_estimator_is_coarse)
  expect_true(any(grepl("MAP fit uses AGHQ", fit$estimator_provenance$notes, fixed = TRUE)))
  obj <- fit$tmb_obj; p <- fit$opt$par
  expect_equal(fit$objective_components$optimization_nll,
    fit$objective_components$likelihood_nll +
      fit$objective_components$fixed_effect_prior_nll +
      fit$objective_components$ridge_penalty, tolerance = 1e-8)
  expect_equal(fit$objective_components$optimizer_reported,
    fit$opt$objective, tolerance = 1e-8)
  expect_equal(fit$objective_components$optimization_nll,
    fit$objective_components$optimizer_reported +
      fit$objective_components$ridge_penalty, tolerance = 1e-8)
  expect_false(is.null(obj$fixed_effect_priors))
  expect_equal(as.numeric(obj$fn(p)-obj$fixed_effect_priors$likelihood_fn(p)),
    unname(-dnorm(p[obj$fixed_effect_priors$indices], .3, 2, log=TRUE)), tolerance=1e-8)
  difference <- obj$gr(p) - obj$fixed_effect_priors$likelihood_gr(p)
  expected <- numeric(length(p))
  expected[obj$fixed_effect_priors$indices] <- (p[obj$fixed_effect_priors$indices] - .3) / 4
  expect_equal(as.numeric(difference), expected, tolerance=1e-8)
  expect_true(all(is.finite(vcov(fit, prior_curvature=TRUE))))
  # Independent per-unit integration of the binary probit likelihood.
  b <- p[names(p) == "b_fix"]; l <- p[names(p) == "theta_rr_B"]
  y <- matrix(dat$value, nrow=3); x <- dat$x[seq(1, nrow(dat), by=3)]
  integrated <- sum(vapply(seq_along(x), function(i) {
    integrand <- function(z) {
      eta <- outer(z, l) + matrix(b[1:3] + b[4:6]*x[i], length(z), 3, byrow=TRUE)
      lp <- pnorm(eta, log.p=TRUE); lq <- pnorm(eta, lower.tail=FALSE, log.p=TRUE)
      dnorm(z)*exp(rowSums(sweep(lp, 2, y[,i], "*") +
                              sweep(lq, 2, 1-y[,i], "*")))
    }
    log(integrate(integrand, -Inf, Inf, rel.tol=1e-9)$value)
  }, numeric(1)))
  expect_lt(abs(-as.numeric(obj$fixed_effect_priors$likelihood_fn(p)) - integrated), 5e-3)
})

test_that("AGHQ assesses steps using the loading-penalized objective", {
  set.seed(871002); n <- 60L
  x <- as.numeric(scale(seq(-2, 2, length.out=n)))/2; z <- rnorm(n)
  dat <- expand.grid(trait=factor(c("a","b","c")), unit=factor(seq_len(n)))
  dat$x <- rep(x, each=3)
  eta <- rep(c(-.3,.1,.4),n) + rep(c(.6,-.4,.3),n)*dat$x +
    rep(c(.5,-.3,.4),n)*rep(z,each=3)
  dat$value <- rbinom(3*n,1,plogis(eta))
  pri <- data.frame(coefficient=c(paste0("trait",letters[1:3]),
                                   paste0("trait",letters[1:3],":x")),mean=0,sd=2)
  fit <- suppressWarnings(gllvmTMB(value~0+trait+trait:x+latent(0+trait|unit,d=1,unique=FALSE),
    dat,trait="trait",unit="unit",family=binomial("logit"),
    control=gllvmTMBcontrol(fixed_effect_priors=pri,loading_ridge=.75,aghq=9L,
      aghq_n_adapt=150L,aghq_multistart=FALSE,svd_start=FALSE,n_init=1L)))
  expect_true(fit$aghq$used)
  expect_true(fit$aghq$converged)
  expect_lt(fit$aghq$grad_max, 0.001)
})

test_that("a nonconverged prior AGHQ fit warns the user", {
  dat <- .fixed_prior_fixture("probit")
  pri <- data.frame(coefficient="traita",mean=0,sd=2)
  seen <- character()
  fit <- withCallingHandlers(gllvmTMB(value~0+trait+trait:x+latent(0+trait|unit,d=1,unique=FALSE),
    dat,trait="trait",unit="unit",family=binomial("probit"),
    control=gllvmTMBcontrol(fixed_effect_priors=pri,loading_ridge=.75,aghq=5L,
      aghq_n_adapt=1L,aghq_multistart=FALSE,svd_start=FALSE,n_init=1L)),
    warning=function(w){seen <<- c(seen,class(w));invokeRestart("muffleWarning")})
  expect_true(fit$aghq$used)
  expect_false(fit$aghq$converged)
  expect_true("gllvmTMB_aghq_not_converged" %in% seen)
})

test_that("a nonconverged AGHQ fit without fixed priors also warns", {
  dat <- .fixed_prior_fixture("probit")
  seen <- character()
  fit <- withCallingHandlers(gllvmTMB(value~0+trait+trait:x+latent(0+trait|unit,d=1,unique=FALSE),
    dat,trait="trait",unit="unit",family=binomial("probit"),
    control=gllvmTMBcontrol(loading_ridge=.75,aghq=5L,aghq_n_adapt=1L,
      aghq_multistart=FALSE,svd_start=FALSE,n_init=1L)),
    warning=function(w){seen <<- c(seen,class(w));invokeRestart("muffleWarning")})
  expect_true(fit$aghq$used)
  expect_false(fit$aghq$converged)
  expect_true("gllvmTMB_aghq_not_converged" %in% seen)
})
