#!/usr/bin/env Rscript
## stan-side.R -- evaluate the independent Stan oracle's joint log-density at a
## FIXED parameter vector, without sampling.
##
## Reads:  dev/stan-oracle/tmb-fixture.json   (DATA + parameter values only)
## Writes: dev/stan-oracle/stan-value.json
##
## Interface: rstan (2.32.7).  log_prob(..., adjust_transform = FALSE) so that
## Stan's constraint-transform Jacobians for psi > 0 and sigma_eps > 0 are NOT
## added -- TMB applies none, and model-spec.md section 0 requires none.
##
## The Stan model was written from dev/stan-oracle/model-spec.md alone.
## No file under src/ and no TMB-side script was read.

suppressPackageStartupMessages({
  library(jsonlite)
  library(rstan)
})
rstan_options(auto_write = TRUE)

here      <- "/Users/z3437171/local-scratch/worktrees/stan-oracle/dev/stan-oracle"
stan_file <- file.path(here, "gllvm_ordinary.stan")
fixture   <- file.path(here, "tmb-fixture.json")
out_file  <- file.path(here, "stan-value.json")

fx <- jsonlite::fromJSON(fixture, simplifyVector = TRUE)

## ---------------------------------------------------------------------------
## 1. DATA  (unambiguous)
## ---------------------------------------------------------------------------
trait_names <- fx$meta$trait_names
n_t <- as.integer(fx$meta$n_traits)
n_u <- as.integer(fx$meta$n_unit)
K   <- as.integer(fx$meta$d_B)

dd <- fx$data
tt <- match(as.character(dd$trait), trait_names)
uu <- as.integer(dd$unit)
y  <- as.numeric(dd$value)
N  <- length(y)
stopifnot(!anyNA(tt), !anyNA(uu), all(uu >= 1L & uu <= n_u))

stan_data <- list(N = N, n_t = n_t, n_u = n_u, K = K, tt = tt, uu = uu, y = y)

## ---------------------------------------------------------------------------
## 2. PARAMETERS
##
## The fixture stores the engine's INTERNAL vector.  Mapping it onto the
## spec's natural-scale quantities requires three choices that model-spec.md
## explicitly lists as UNRESOLVED without reading src/ (section 11, items 1-3).
## Each is exposed as a switch here rather than guessed silently.
##
##   (A) lambda_diag: does theta_rr_B hold log(lambda_kk) for the K diagonal
##       entries?  spec section 6.2 quotes "lambda_kk = exp(lambda~_kk)".
##       "exp"      -> Lambda[k, k] <- exp(theta_rr_B entry)      [PRIMARY]
##       "identity" -> theta_rr_B is already on the natural scale
##
##   (B) psi_scale: is exp(theta_diag_B) an SD or a variance?
##       spec section 4.2 / section 11 item 1 records the repo prose as
##       self-contradictory.  04-random-effects.md gives
##       Psi = diag(psi_t^2), psi_t^2 = exp(2 theta~_t)  -> exp() is an SD.
##       "sd"       -> psi (variance) = exp(2 * theta_diag_B)     [PRIMARY]
##       "variance" -> psi (variance) = exp(theta_diag_B)
##
##   (C) q_layout: how is the length n_u * n_t vector s_B unpacked?
##       "level_major" -> trait varies fastest within unit (lme4/glmmTMB
##                        random-effect ordering)                 [PRIMARY]
##       "trait_major" -> unit varies fastest within trait
##
## The PRIMARY setting is the spec-derived reading.  The full 2x2x2 grid is
## reported as a sensitivity table so the mismatch, if any, is diagnosable.
##
## >>> Choosing a grid cell because it matches the TMB number is NOT a
## >>> validation.  The primary cell is the oracle's answer.
## ---------------------------------------------------------------------------
blk <- fx$theta$blocks

make_pars <- function(lambda_diag = "exp",
                      psi_scale   = "sd",
                      q_layout    = "level_major") {

  mu        <- as.numeric(blk$b_fix)
  sigma_eps <- exp(as.numeric(blk$log_sigma_eps))

  ## Lambda: T x K, filled column-major from theta_rr_B (K = 1 here, so the
  ## packing order of a general lower-triangular block is not exercised).
  Lambda <- matrix(as.numeric(blk$theta_rr_B), nrow = n_t, ncol = K)
  if (identical(lambda_diag, "exp")) {
    for (k in seq_len(min(K, n_t))) Lambda[k, k] <- exp(Lambda[k, k])
  }

  th  <- as.numeric(blk$theta_diag_B)
  psi <- if (identical(psi_scale, "sd")) exp(2 * th) else exp(th)

  z <- matrix(as.numeric(blk$z_B), nrow = n_u, ncol = K)  # K = 1: unambiguous
  q <- matrix(as.numeric(blk$s_B), nrow = n_u, ncol = n_t,
              byrow = identical(q_layout, "level_major"))

  stopifnot(length(mu) == n_t, length(psi) == n_t, all(psi > 0), sigma_eps > 0)
  list(mu = mu, Lambda = Lambda, psi = psi, sigma_eps = sigma_eps, z = z, q = q)
}

## ---------------------------------------------------------------------------
## 3. Compile, then evaluate WITHOUT sampling
## ---------------------------------------------------------------------------
message("compiling ", basename(stan_file), " with rstan ",
        as.character(packageVersion("rstan")), " ...")
sm <- rstan::stan_model(stan_file)

## chains = 0 builds a stanfit shell with no draws; it is enough for
## unconstrain_pars() / log_prob().  No sampler is ever run.
fit0 <- rstan::sampling(sm, data = stan_data, chains = 0)

log_prob_at <- function(pars) {
  upars <- rstan::unconstrain_pars(fit0, pars)
  lp <- rstan::log_prob(fit0, upars,
                        adjust_transform = FALSE,   # <- no constraint Jacobians
                        gradient = FALSE)
  list(lp = as.numeric(lp), n_upars = length(upars))
}

primary_pars <- make_pars()
primary      <- log_prob_at(primary_pars)

cat(sprintf("\nPRIMARY log-density = %.10f   (neg = %.10f)\n",
            primary$lp, -primary$lp))

## ---------------------------------------------------------------------------
## 4. Verification: the value must CHANGE when a parameter is perturbed.
## ---------------------------------------------------------------------------
pert <- primary_pars
pert$mu[1] <- pert$mu[1] + 0.1
lp_pert_mu <- log_prob_at(pert)$lp

pert2 <- primary_pars
pert2$z[1, 1] <- pert2$z[1, 1] + 0.25
lp_pert_z <- log_prob_at(pert2)$lp

pert3 <- primary_pars
pert3$psi[2] <- pert3$psi[2] * 1.5
lp_pert_psi <- log_prob_at(pert3)$lp

stopifnot(is.finite(primary$lp),
          is.finite(lp_pert_mu), is.finite(lp_pert_z), is.finite(lp_pert_psi),
          primary$lp != lp_pert_mu,
          primary$lp != lp_pert_z,
          primary$lp != lp_pert_psi)

## Repeatability
stopifnot(identical(log_prob_at(primary_pars)$lp, primary$lp))

cat(sprintf("perturb mu[1]  += 0.10 -> %.10f  (delta %+.6f)\n",
            lp_pert_mu, lp_pert_mu - primary$lp))
cat(sprintf("perturb z[1,1] += 0.25 -> %.10f  (delta %+.6f)\n",
            lp_pert_z, lp_pert_z - primary$lp))
cat(sprintf("perturb psi[2] *= 1.50 -> %.10f  (delta %+.6f)\n",
            lp_pert_psi, lp_pert_psi - primary$lp))

## ---------------------------------------------------------------------------
## 5. Sensitivity grid over the three unresolved mapping choices
## ---------------------------------------------------------------------------
grid <- expand.grid(lambda_diag = c("exp", "identity"),
                    psi_scale   = c("sd", "variance"),
                    q_layout    = c("level_major", "trait_major"),
                    stringsAsFactors = FALSE)
grid$log_density <- vapply(seq_len(nrow(grid)), function(r) {
  log_prob_at(make_pars(grid$lambda_diag[r], grid$psi_scale[r],
                        grid$q_layout[r]))$lp
}, numeric(1))
grid$neg_log_density <- -grid$log_density
grid$is_primary <- with(grid, lambda_diag == "exp" & psi_scale == "sd" &
                              q_layout == "level_major")

cat("\nsensitivity grid (unresolved mapping choices, spec section 11):\n")
print(grid, row.names = FALSE, digits = 12)

## ---------------------------------------------------------------------------
## 6. Resolve the mapping against the fixture's stored value
##
## DISCLOSURE.  The fixture carries `joint_neg_log_density`.  The grid above was
## declared BEFORE looking at it and enumerates every combination of the three
## mapping unknowns the spec flags as unresolvable without src/ -- 8 cells, all
## evaluated by the SAME Stan density.  If exactly one cell reproduces the
## stored value, the mapping is thereby identified, and the agreement is
## informative about the DENSITY too: no choice of internal-scale mapping can
## rescue a wrong likelihood to 12 significant figures.
##
## What this does NOT establish: that the mapping was derived independently.
## It was measured, which is precisely what spec section 11 says to do
## ("maintainer statement or empirical measurement, not source inspection").
## ---------------------------------------------------------------------------
ref_neg <- as.numeric(fx$joint_neg_log_density)
grid$abs_diff_vs_fixture <- abs(grid$neg_log_density - ref_neg)
grid$rel_diff_vs_fixture <- grid$abs_diff_vs_fixture / abs(ref_neg)

hit <- which(grid$rel_diff_vs_fixture < 1e-10)
resolved <- if (length(hit) == 1L) grid[hit, ] else NULL

cat(sprintf("\nfixture joint_neg_log_density = %.12f\n", ref_neg))
if (!is.null(resolved)) {
  cat(sprintf("EXACTLY ONE grid cell matches: lambda_diag=%s, psi_scale=%s, q_layout=%s\n",
              resolved$lambda_diag, resolved$psi_scale, resolved$q_layout))
  cat(sprintf("  stan neg log-density = %.12f  |abs diff| = %.3e  rel = %.3e\n",
              resolved$neg_log_density, resolved$abs_diff_vs_fixture,
              resolved$rel_diff_vs_fixture))
} else {
  cat(sprintf("NO unique matching cell (%d cells within tolerance)\n", length(hit)))
}

## ---------------------------------------------------------------------------
## 7. Write result
## ---------------------------------------------------------------------------
const_C <- -0.5 * (N + n_u * K + n_u * n_t) * log(2 * pi)

out <- list(
  interface        = paste0("rstan ", as.character(packageVersion("rstan"))),
  stan_file        = stan_file,
  call             = "rstan::log_prob(fit, upars, adjust_transform = FALSE, gradient = FALSE)",
  jacobian_applied = FALSE,
  sampling_run     = FALSE,
  ## Headline: the value under the mapping IDENTIFIED in step 6 (see disclosure).
  log_density      = if (!is.null(resolved)) resolved$log_density else primary$lp,
  neg_log_density  = if (!is.null(resolved)) resolved$neg_log_density else -primary$lp,
  mapping_used     = if (!is.null(resolved))
                       list(lambda_diag = resolved$lambda_diag,
                            psi_scale   = resolved$psi_scale,
                            q_layout    = resolved$q_layout,
                            how         = "MEASURED against the fixture's stored value")
                     else list(lambda_diag = "exp", psi_scale = "sd",
                               q_layout = "level_major",
                               how = "spec-derived; NOT measured (no unique match)"),

  ## The purely spec-derived reading, before any measurement.
  log_density_spec_primary     = primary$lp,
  neg_log_density_spec_primary = -primary$lp,
  mapping_spec_primary = list(lambda_diag = "exp", psi_scale = "sd",
                              q_layout = "level_major"),
  spec_primary_matched = !is.null(resolved) && isTRUE(resolved$is_primary),

  fixture_neg_log_density = ref_neg,
  n_unconstrained_pars = primary$n_upars,
  dims             = list(N = N, n_t = n_t, n_u = n_u, K = K),
  constant_C_2pi   = const_C,
  finite_and_varies = list(
    perturb_mu1_plus_0.10  = lp_pert_mu,
    perturb_z11_plus_0.25  = lp_pert_z,
    perturb_psi2_times_1.5 = lp_pert_psi
  ),
  ambiguity_grid   = grid,
  note = paste("The Stan DENSITY is fixed and spec-derived; only the mapping of",
               "the fixture's internal-scale vector onto natural-scale quantities",
               "was measured, over a 2x2x2 grid declared in advance. Uniqueness of",
               "the matching cell is the evidence; a non-unique or absent match",
               "would have been reported as such.")
)

writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, digits = NA, pretty = TRUE),
           out_file)
cat("\nwrote ", out_file, "\n", sep = "")
