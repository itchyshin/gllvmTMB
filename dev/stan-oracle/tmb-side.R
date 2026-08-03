## Stan-oracle fixed-parameter likelihood check -- TMB side (Curie).
##
## Target model: ordinary Gaussian, long format, with BOTH a reduced-rank
## latent term and its diagonal companion:
##   value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit)
## i.e. Sigma_unit = Lambda %*% t(Lambda) + diag(psi^2), 3 traits, d = 1.
##
## This script:
##   1. Simulates a tiny fixed-seed dataset (3 traits x 15 units x 2 reps).
##   2. Fits it with gllvmTMB() -- convergence quality does not matter, this
##      run exists only to obtain a valid TMB object with the right
##      data/parameter/map structure.
##   3. Rebuilds a JOINT (non-integrated) TMB::MakeADFun() object from that
##      fit's own tmb_data / tmb_params / tmb_map, with random = NULL --
##      the same move R/eva-proto.R's .eva_make_objective() uses (compare
##      its `TMB::MakeADFun(..., random = NULL)` call).
##   4. Evaluates the joint negative log-density at ONE explicit, hand-chosen
##      theta (not the fitted optimum).
##   5. Verifies: two evaluations at theta are bitwise identical; a
##      perturbed theta gives a different value (rules out a constant/
##      no-op objective silently passing later comparisons).
##   6. Writes theta, the data, and the resulting log-density to
##      tmb-fixture.rds and tmb-fixture.json.
##
## See tmb-side.md for the full parameter dictionary (name, dimension,
## order, scale/transform) and for which terms enter the joint density.

## This script always lives at <pkg_root>/dev/stan-oracle/tmb-side.R inside
## the stan-oracle worktree.
pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-oracle"
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
devtools::load_all(pkg_root, quiet = TRUE)

out_dir <- file.path(pkg_root, "dev", "stan-oracle")
stopifnot(dir.exists(out_dir))

## ---- 1. Simulate a tiny fixed-seed dataset --------------------------------
## Two replicates per (unit, trait) cell so `log_sigma_eps` stays a genuine
## FREE parameter -- with a single replicate per cell, gllvmTMB auto-detects
## that the per-row diagonal `unique()` term already absorbs all row-level
## variance and maps `log_sigma_eps` off (fixes it near zero), which would
## make it disappear from theta. See tmb-side.md sec. "sigma_eps".
set.seed(20260803L)

n_traits <- 3L
n_unit   <- 15L
reps     <- 2L
trait_names <- c("a", "b", "c")

alpha_true   <- c(0.5, -0.3, 0.2)                       # trait intercepts
Lambda_true  <- matrix(c(0.8, 0.6, -0.4), nrow = n_traits, ncol = 1L)  # d = 1
psi_true     <- c(0.3, 0.25, 0.35)                      # diag(psi) SDs
sigma_eps_true <- 0.2                                   # residual SD

f_unit <- rnorm(n_unit)                                 # latent factor, d = 1
delta  <- matrix(rnorm(n_unit * n_traits, sd = rep(psi_true, each = n_unit)),
                  n_unit, n_traits)
eta <- outer(rep(1, n_unit), alpha_true) +
  outer(as.numeric(f_unit), as.numeric(Lambda_true)) +
  delta

rows <- vector("list", n_unit * n_traits * reps)
k <- 1L
for (u in seq_len(n_unit)) {
  for (t in seq_len(n_traits)) {
    for (r in seq_len(reps)) {
      rows[[k]] <- data.frame(
        unit  = u,
        trait = trait_names[t],
        value = eta[u, t] + rnorm(1, sd = sigma_eps_true)
      )
      k <- k + 1L
    }
  }
}
df <- do.call(rbind, rows)
df$trait <- factor(df$trait, levels = trait_names)
stopifnot(nrow(df) == n_unit * n_traits * reps)

## ---- 2. Fit with gllvmTMB() to obtain a valid TMB object ------------------
## Convergence quality does not matter -- only the resulting tmb_data /
## tmb_params / tmb_map structure is used below.
fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit),
  data   = df,
  unit   = "unit",
  family = gaussian(),
  control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 30, eval.max = 40)))
)))
stopifnot(!is.null(fit$tmb_obj))

## ---- 3. Rebuild the JOINT objective: random = NULL ------------------------
## Same data / parameters / map the fit used, same DLL ("gllvmTMB"); only
## `random` changes, from fit$random (the Laplace-integrated block names) to
## NULL, so ALL parameters -- including what were random effects -- become
## "fixed" coordinates of the joint density. This mirrors
## .eva_make_objective()'s `TMB::MakeADFun(..., random = NULL)` in
## R/eva-proto.R.
joint_obj <- TMB::MakeADFun(
  data       = fit$tmb_data,
  parameters = fit$tmb_params,
  map        = fit$tmb_map,
  random     = NULL,
  DLL        = "gllvmTMB",
  silent     = TRUE
)

theta_names <- names(joint_obj$par)
theta_counts <- as.integer(table(theta_names)[c("b_fix", "log_sigma_eps", "theta_rr_B",
                                                 "z_B", "theta_diag_B", "s_B")])
stopifnot(identical(
  theta_counts,
  c(3L, 1L, 3L, n_unit, n_traits, n_unit * n_traits)
))

## ---- 4. One explicit, hand-chosen theta (NOT the fitted optimum) ----------
## Values below were generated once with `set.seed(42)`/`set.seed(43)` +
## rnorm() and then hardcoded as literals, so theta is a fixed, written-down
## vector, not something recomputed (and potentially silently changed) on
## every run. Order and scale are documented in tmb-side.md.
b_fix_theta         <- c(0.5, -0.3, 0.2)                 # natural scale
log_sigma_eps_theta <- log(0.25)                         # log-SD
theta_rr_B_theta    <- c(0.8, 0.6, -0.4)                 # unconstrained Lambda
z_B_theta <- c(
  1.097, -0.452, 0.291, 0.506, 0.323, -0.085, 1.209, -0.076, 1.615,
  -0.05, 1.044, 1.829, -1.111, -0.223, -0.107
)                                                          # N(0,1) latent scores
theta_diag_B_theta  <- log(c(0.3, 0.25, 0.35))            # log-SD of Psi
s_B_theta <- c(
  -0.011, -0.472, -0.146, 0.14, -0.271, -0.083, 0.116, -0.018, -0.206,
  -0.572, 0.541, -0.29, -0.106, 0.332, 0.17, 0.619, 0.441, -0.495, 0.061,
  -0.216, -0.048, 0.22, -0.109, -0.003, 0.175, -0.088, -0.418, -0.026,
  -0.206, -0.233, 0.523, 0.137, -0.035, 0.503, -0.348, -0.012, 0.327,
  0.454, 0.266, 0.094, 0.565, -0.124, -0.274, 0.165, -0.243
)                                                          # N(0, psi_t) draws

theta <- numeric(length(joint_obj$par))
theta[theta_names == "b_fix"]         <- b_fix_theta
theta[theta_names == "log_sigma_eps"] <- log_sigma_eps_theta
theta[theta_names == "theta_rr_B"]    <- theta_rr_B_theta
theta[theta_names == "z_B"]           <- z_B_theta
theta[theta_names == "theta_diag_B"]  <- theta_diag_B_theta
theta[theta_names == "s_B"]           <- s_B_theta
stopifnot(all(is.finite(theta)), length(theta) == length(joint_obj$par))

## ---- 5. Verify: reproducible + sensitive (not a constant function) -------
nll_1 <- joint_obj$fn(theta)
nll_2 <- joint_obj$fn(theta)
stopifnot(identical(nll_1, nll_2))               # bitwise identical

theta_perturbed <- theta
theta_perturbed[1L] <- theta_perturbed[1L] + 0.1  # perturb b_fix[1]
nll_perturbed <- joint_obj$fn(theta_perturbed)
stopifnot(is.finite(nll_perturbed), !identical(nll_perturbed, nll_1))

cat(sprintf(
  "joint nll(theta) = %.10f   (identical repeat: %s; perturbed differs by %.6f)\n",
  nll_1, identical(nll_1, nll_2), nll_perturbed - nll_1
))

## ---- 6. Write theta, data, and the log-density to rds + json -------------
fixture <- list(
  meta = list(
    formula   = "value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit)",
    family    = "gaussian",
    n_traits  = n_traits,
    n_unit    = n_unit,
    reps      = reps,
    d_B       = 1L,
    trait_names = trait_names,
    dll       = "gllvmTMB",
    random    = NULL,   # joint density: no random-effect block integrated out
    seed      = 20260803L,
    package_version = as.character(utils::packageVersion("gllvmTMB"))
  ),
  data = df,
  theta = list(
    names  = theta_names,
    values = theta,
    blocks = list(
      b_fix         = b_fix_theta,
      log_sigma_eps = log_sigma_eps_theta,
      theta_rr_B    = theta_rr_B_theta,
      z_B           = z_B_theta,
      theta_diag_B  = theta_diag_B_theta,
      s_B           = s_B_theta
    )
  ),
  joint_neg_log_density = nll_1,
  checks = list(
    repeat_identical       = identical(nll_1, nll_2),
    perturbed_value        = nll_perturbed,
    perturbed_differs      = !identical(nll_perturbed, nll_1)
  )
)

saveRDS(fixture, file.path(out_dir, "tmb-fixture.rds"))

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite is required to write tmb-fixture.json.", call. = FALSE)
}
jsonlite::write_json(
  fixture, file.path(out_dir, "tmb-fixture.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null"
)

cat("Wrote:\n  ", file.path(out_dir, "tmb-fixture.rds"), "\n  ",
    file.path(out_dir, "tmb-fixture.json"), "\n")
