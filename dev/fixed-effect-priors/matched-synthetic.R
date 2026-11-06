# Exact physical-coordinate comparison. Run from the repository root.
pkgload::load_all(quiet = TRUE, compile = FALSE)
set.seed(846)
n <- 60L
x <- as.numeric(scale(seq(-2, 2, length.out = n))) / 2
z <- rnorm(n)
dat <- expand.grid(trait = factor(c("a", "b", "c")), unit = factor(seq_len(n)))
dat$x <- rep(x, each = 3)
eta <- rep(c(-.3, .1, .4), n) + rep(c(.6, -.4, .3), n)*dat$x +
  rep(c(.5, -.3, .4), n)*rep(z, each = 3)
dat$value <- rbinom(nrow(dat), 1, plogis(eta))
X <- model.matrix(~ 0 + trait + trait:x, dat)
prior <- data.frame(coefficient = colnames(X), mean = 0, sd = 10)
native <- suppressWarnings(gllvmTMB(
  value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE),
  dat, trait = "trait", unit = "unit", family = binomial(),
  control = gllvmTMBcontrol(fixed_effect_priors = prior, loading_ridge = .75,
                            svd_start = FALSE, n_init = 1L, se = FALSE)))
glmm_prior <- data.frame(prior = c(rep("normal(0,10)", ncol(X)), "normal(0,0.75)"),
                         class = c(rep("fixef", ncol(X)), "ranef"),
                         coef = c(colnames(X), "unit"))
make <- function(priors) {
  s <- glmmTMB::glmmTMB(value ~ 0 + trait + trait:x + rr(0 + trait | unit, d = 1),
    dat, family = binomial(), priors = priors, doFit = FALSE)
  TMB::MakeADFun(s$data.tmb, s$parameters, map = s$mapArg, random = s$randomArg,
                 DLL = "glmmTMB", silent = TRUE)
}
off <- make(NULL)
on <- make(glmm_prior)
bi <- which(names(native$opt$par) == "b_fix")
li <- which(names(native$opt$par) == "theta_rr_B")
gb <- which(names(on$par) == "beta")
gl <- which(names(on$par) == "theta")
stopifnot(length(bi) == length(gb), length(li) == length(gl), length(li) == 3)
constant <- length(li)*log(.75*sqrt(2*pi))
to_glmm <- function(p) {q <- on$par; q[gb] <- p[bi]; q[gl] <- p[li]; q}
native_fn <- function(p) as.numeric(native$tmb_obj$fn(p)) + sum(p[li]^2)/(2*.75^2)
native_gr <- function(p) gllvmTMB:::.gllvmTMB_penalised_gradient(native$tmb_obj, p, .75)
fixed <- do.call(rbind, lapply(c(0, .2, -.6), function(shift) {
  p <- native$opt$par
  p[bi] <- shift + seq_along(bi)/10
  p[li] <- c(.4, -.3, .7) + shift
  q <- to_glmm(p)
  ng <- native_gr(p)
  gg <- as.numeric(on$gr(q))
  data.frame(shift = shift,
    likelihood_difference = as.numeric(native$tmb_obj$fixed_effect_priors$likelihood_fn(p) - off$fn(q)),
    adjusted_objective_difference = native_fn(p) + constant - as.numeric(on$fn(q)),
    max_gradient_difference = max(abs(ng[bi] - gg[gb]), abs(ng[li] - gg[gl])))
}))
write.csv(fixed, "dev/fixed-effect-priors/results/matched-fixed.csv", row.names = FALSE)
print(fixed)
stopifnot(max(abs(fixed$likelihood_difference)) < 1e-5,
          max(abs(fixed$adjusted_objective_difference)) < 1e-5,
          max(abs(fixed$max_gradient_difference)) < 1e-4)
# Both optimizers receive the same distinct physical starts.
fitted <- do.call(rbind, lapply(c(0, .4, -.4), function(shift) {
  p <- native$opt$par
  p[bi] <- shift
  p[li] <- c(.6, -.4, .5) + shift
  nr <- nlminb(p, native_fn, native_gr, control = list(iter.max = 1000, eval.max = 1500))
  gr <- nlminb(to_glmm(p), on$fn, on$gr, control = list(iter.max = 1000, eval.max = 1500))
  Sn <- tcrossprod(nr$par[li]); Sg <- tcrossprod(gr$par[gl])
  data.frame(start_shift = shift, native_code = nr$convergence, glmm_code = gr$convergence,
    adjusted_objective_difference = nr$objective + constant - gr$objective,
    max_beta_difference = max(abs(nr$par[bi] - gr$par[gb])),
    max_covariance_difference = max(abs(Sn - Sg)),
    native_gradient = max(abs(native_gr(nr$par))), glmm_gradient = max(abs(on$gr(gr$par))))
}))
write.csv(fitted, "dev/fixed-effect-priors/results/matched-fitted.csv", row.names = FALSE)
writeLines(capture.output(sessionInfo()), "dev/fixed-effect-priors/results/matched-session.txt")
print(fitted)
stopifnot(all(fitted$native_code==0),all(fitted$glmm_code==0),
          max(abs(fitted$adjusted_objective_difference))<1e-5,
          max(fitted$max_beta_difference)<1e-5,
          max(fitted$max_covariance_difference)<1e-5,
          max(fitted$native_gradient)<.001,max(fitted$glmm_gradient)<.001)
cat("MATCHED_SYNTHETIC_PASS\n")
