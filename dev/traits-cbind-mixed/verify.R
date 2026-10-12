## Gate runner for the mixed-family cbind lane (#1494, PR #1495).
## Usage: Rscript --vanilla dev/traits-cbind-mixed/verify.R <engine|wide|methods>
## Prints CBIND_MIXED_<GATE>_PASS only when every check in the gate holds.
##
## Oracle: the pre-existing single-column `weights = trials` route. A mixed
## cbind fit must hand TMB the same y / n_trials / family ids, hence the same
## objective.

args <- commandArgs(trailingOnly = TRUE)
gate <- if (length(args)) args[[1L]] else "engine"
suppressMessages(pkgload::load_all(".", quiet = TRUE))

checks <- 0L
ok <- function(cond, what) {
  if (!isTRUE(cond)) stop("FAILED: ", what, call. = FALSE)
  checks <<- checks + 1L
  cat("  ok:", what, "\n")
}
quiet <- function(expr) suppressMessages(suppressWarnings(expr))
ctl <- gllvmTMBcontrol(se = FALSE, n_init = 1L)

## Wide fixture: two multi-trial binomial traits, one Gaussian with negative
## values, one Poisson count with zeros; one shared latent axis.
make_wide <- function(n = 80L, seed = 1494L) {
  set.seed(seed)
  z <- rnorm(n)
  tr1 <- sample(4:12, n, TRUE); s1 <- rbinom(n, tr1, plogis(-0.2 + 0.9 * z))
  tr2 <- sample(4:12, n, TRUE); s2 <- rbinom(n, tr2, plogis(0.3 + 0.6 * z))
  data.frame(
    id = factor(seq_len(n)),
    s1 = s1, f1 = tr1 - s1, n1 = tr1,
    s2 = s2, f2 = tr2 - s2, n2 = tr2,
    mass = -1 + 0.8 * z + rnorm(n, sd = 0.5),
    count = rpois(n, exp(0.2 + 0.5 * z))
  )
}
## Long twin, unit-major / trait-minor (the order traits() produces).
make_long <- function(w) {
  lv <- c("s1", "s2", "mass", "count")
  out <- do.call(rbind, lapply(seq_len(nrow(w)), function(i) data.frame(
    id = w$id[i], trait = lv,
    value = c(w$s1[i], w$s2[i], w$mass[i], w$count[i]),
    fail  = c(w$f1[i], w$f2[i], 0, 0),
    n     = c(w$n1[i], w$n2[i], 1, 1)
  )))
  out$trait <- factor(out$trait, levels = lv)
  out
}
fams <- function(var = "trait") {
  f <- list(s1 = binomial(), s2 = binomial(), mass = gaussian(), count = poisson())
  attr(f, "family_var") <- var
  f
}
rhs_long <- ~ 0 + trait + latent(0 + trait | id, d = 1, unique = FALSE)
long_fit <- function(lhs, data, ...) {
  fml <- stats::as.formula(paste(lhs, "~ 0 + trait + latent(0 + trait | id, d = 1, unique = FALSE)"))
  quiet(gllvmTMB(fml, data = data, unit = "id", trait = "trait",
                 family = fams(), control = ctl, ...))
}

w <- make_wide(); L <- make_long(w)

if (gate == "engine") {
  cat("G1 engine\n")
  ## T1: mixed cbind == weights route, same TMB inputs and objective.
  fa <- long_fit("cbind(value, fail)", L)
  fb <- long_fit("value", L, weights = L$n)
  ok(isTRUE(all.equal(fa$tmb_data$y, fb$tmb_data$y)), "T1 y identical to weights route")
  ok(isTRUE(all.equal(fa$tmb_data$n_trials, fb$tmb_data$n_trials)), "T1 n_trials identical to weights route")
  ok(all(fa$tmb_data$n_trials[L$trait %in% c("mass", "count")] == 1), "T1 non-binomial rows carry n_trials = 1")
  ok(abs(fa$opt$objective - fb$opt$objective) < 1e-8, "T1 objective equals weights route (1e-8)")
  ok(any(L$value[L$trait == "mass"] < 0) && any(L$value[L$trait == "count"] == 0),
     "T1 fixture really has negative Gaussian values and zero counts")
  ## T2: Gaussian-only cbind(y, 0) == plain y.
  G <- L[L$trait == "mass", ]; G$trait <- droplevels(G$trait)
  gfit <- function(lhs) quiet(gllvmTMB(
    stats::as.formula(paste(lhs, "~ 1 + (1 | id)")),
    data = G, unit = "id", family = gaussian(), control = ctl))
  g1 <- gfit("cbind(value, fail)"); g0 <- gfit("value")
  ok(abs(g1$opt$objective - g0$opt$objective) < 1e-10, "T2 gaussian cbind(y, 0) == plain y (1e-10)")
  ## T5-engine: non-zero second column on a Gaussian row is refused.
  Lbad <- L; Lbad$fail[Lbad$trait == "mass"][1] <- 2
  ok(inherits(tryCatch(long_fit("cbind(value, fail)", Lbad), error = identity),
              "gllvmTMB_cbind_second_column_nonbinomial"),
     "T5 non-zero 2nd column on gaussian row refused (classed)")
  ## Binomial rows still validated: negative failures refused.
  Lneg <- L; Lneg$fail[Lneg$trait == "s1"][1] <- -1
  ok(inherits(tryCatch(long_fit("cbind(value, fail)", Lneg), error = identity), "error"),
     "T5 negative failures on binomial row still refused")
  cat("CBIND_MIXED_ENGINE_PASS (", checks, "checks )\n")
}

if (gate == "wide") {
  cat("G2 wide\n")
  fa <- long_fit("cbind(value, fail)", L)
  fw <- quiet(gllvmTMB(
    traits(cbind(s1, f1), cbind(s2, f2), mass, count) ~ 1 + latent(1 | id, d = 1, unique = FALSE),
    data = w, unit = "id", control = ctl,
    family = list(s1 = binomial(), s2 = binomial(), mass = gaussian(), count = poisson())))
  ok(identical(levels(fw$data$trait), c("s1", "s2", "mass", "count")), "T3 trait levels in traits() order")
  ok(isTRUE(all.equal(fw$tmb_data$y, fa$tmb_data$y)), "T3 wide y == long y")
  ok(isTRUE(all.equal(fw$tmb_data$n_trials, fa$tmb_data$n_trials)), "T3 wide n_trials == long n_trials")
  ok(abs(fw$opt$objective - fa$opt$objective) < 1e-8, "T3 wide objective == long (1e-8)")
  ## T4: plain 0/1 column under binomial inside a mixed call == Bernoulli.
  w$b <- as.integer(w$s1 > w$f1)
  fb4 <- quiet(gllvmTMB(
    traits(cbind(s2, f2), b, mass) ~ 1 + latent(1 | id, d = 1, unique = FALSE),
    data = w, unit = "id", control = ctl,
    family = list(s2 = binomial(), b = binomial(), mass = gaussian())))
  Lb <- do.call(rbind, lapply(seq_len(nrow(w)), function(i) data.frame(
    id = w$id[i], trait = c("s2", "b", "mass"),
    value = c(w$s2[i], w$b[i], w$mass[i]), n = c(w$n2[i], 1, 1))))
  Lb$trait <- factor(Lb$trait, levels = c("s2", "b", "mass"))
  fl <- list(s2 = binomial(), b = binomial(), mass = gaussian())
  attr(fl, "family_var") <- "trait"
  fb4l <- quiet(gllvmTMB(value ~ 0 + trait + latent(0 + trait | id, d = 1, unique = FALSE),
                         data = Lb, unit = "id", trait = "trait", family = fl,
                         control = ctl, weights = Lb$n))
  ok(all(fb4$tmb_data$n_trials[fb4$data$trait == "b"] == 1), "T4 plain binomial column is Bernoulli (n_trials = 1)")
  ok(abs(fb4$opt$objective - fb4l$opt$objective) < 1e-8, "T4 equals weights-route Bernoulli fit (1e-8)")
  ## T5-wide refusals.
  e1 <- tryCatch(quiet(gllvmTMB(traits(cbind(s1, f1), mass) ~ 1 + latent(1 | id, d = 1),
    data = w, unit = "id", control = ctl,
    family = list(s1 = gaussian(), mass = gaussian()))), error = identity)
  ok(inherits(e1, "gllvmTMB_traits_cbind_family"), "T5 cbind pair with a gaussian family refused")
  e2 <- tryCatch(quiet(gllvmTMB(traits(cbind(s1, f1), mass) ~ 1 + latent(1 | id, d = 1),
    data = w, unit = "id", control = ctl,
    family = list(infected = binomial(), mass = gaussian()))), error = identity)
  ok(inherits(e2, "gllvmTMB_traits_family_names"), "T5 family-list name mismatch refused")
  e3 <- tryCatch(quiet(gllvmTMB(traits(cbind(s1, f1), count) ~ 1 + latent(1 | id, d = 1),
    data = w, unit = "id", control = ctl,
    family = list(s1 = binomial(), count = binomial()))), error = identity)
  ok(inherits(e3, "gllvmTMB_traits_plain_binomial_not_binary"), "T5 non-0/1 plain binomial column refused")
  ## Review findings (G6) -- each must now behave.
  wide_fit <- function(fam, f = traits(cbind(s1, f1), mass, b) ~ 1 +
                         latent(1 | id, d = 1, unique = FALSE)) quiet(gllvmTMB(
    f, data = w, unit = "id", control = ctl, family = fam))
  ref <- wide_fit(list(s1 = binomial(), mass = gaussian(), b = binomial()))
  fv <- list(s1 = binomial(), mass = gaussian(), b = binomial())
  attr(fv, "family_var") <- "trait"
  ok(abs(wide_fit(fv)$opt$objective - ref$opt$objective) < 1e-8,
     "R1 user family_var = 'trait' still gets the Bernoulli fix-up")
  ok(abs(wide_fit(list(s1 = "binomial", mass = "gaussian", b = "binomial"))$opt$objective -
           ref$opt$objective) < 1e-8, "R2 character family names in a list")
  fc <- quiet(gllvmTMB(traits(cbind(s1, f1), b) ~ 1 + latent(1 | id, d = 1, unique = FALSE),
    data = w, unit = "id", control = ctl, family = "binomial"))
  fo <- quiet(gllvmTMB(traits(cbind(s1, f1), b) ~ 1 + latent(1 | id, d = 1, unique = FALSE),
    data = w, unit = "id", control = ctl, family = binomial()))
  ok(abs(fc$opt$objective - fo$opt$objective) < 1e-8, "R2 single character family")
  w$pos <- ifelse(w$count > 0, exp(w$mass), 0)
  e4 <- tryCatch(quiet(gllvmTMB(traits(cbind(s1, f1), pos) ~ 1 + latent(1 | id, d = 1),
    data = w, unit = "id", control = ctl,
    family = list(s1 = binomial(), pos = delta_gamma()))), error = identity)
  ok(!inherits(e4, "error") || !grepl("values must be length 1", conditionMessage(e4)),
     "R3 delta family in the list does not crash the fix-up")
  wneg <- w; wneg$f1[1] <- -2
  e5 <- tryCatch(quiet(gllvmTMB(traits(cbind(s1, f1), mass) ~ 1 + latent(1 | id, d = 1),
    data = wneg, unit = "id", control = ctl,
    family = list(s1 = binomial(), mass = gaussian()))), error = identity)
  ok(inherits(e5, "gllvmTMB_traits_cbind_negative"), "R5 negative pair count refused, not blanked")
  e6 <- tryCatch(quiet(gllvmTMB(traits(cbind(s1, f1), -c(id, f1)) ~ 1 + latent(1 | id, d = 1),
    data = w, unit = "id", control = ctl, family = binomial())), error = identity)
  ok(inherits(e6, "gllvmTMB_traits_cbind_negative_selection"), "R6 negative selection refused")
  cat("CBIND_MIXED_WIDE_PASS (", checks, "checks )\n")
}

if (gate == "methods") {
  cat("G3 methods\n")
  fa <- long_fit("cbind(value, fail)", L)
  set.seed(1)
  sim <- quiet(simulate(fa, nsim = 2))
  ok(NROW(sim) == nrow(L), "T6 simulate() returns one row per observation")
  bin <- L$trait %in% c("s1", "s2")
  ok(all(as.matrix(sim)[bin, ] <= L$n[bin]), "T6 simulated binomial successes <= trials")
  fb <- long_fit("value", L, weights = L$n)
  set.seed(2); rq <- quiet(residuals(fa))
  set.seed(2); rqb <- quiet(residuals(fb))
  ok(nrow(rq) == nrow(L) && all(rq$status == "ok") && all(is.finite(rq$residual)),
     "T6 quantile residuals: one finite 'ok' residual per row")
  ok(identical(as.character(rq$family), c(binomial = "binomial", mass = "gaussian",
       count = "poisson")[ifelse(L$trait %in% c("s1", "s2"), "binomial", as.character(L$trait))] |> unname()),
     "T6 each residual row uses its own trait's family")
  ok(isTRUE(all.equal(rq$residual, rqb$residual)), "T6 residuals identical to weights route")
  ok(abs(mean(rq$residual)) < 0.3 && abs(stats::sd(rq$residual) - 1) < 0.3,
     "T6 quantile residuals approx N(0,1)")
  cat("CBIND_MIXED_METHODS_PASS (", checks, "checks )\n")
}
