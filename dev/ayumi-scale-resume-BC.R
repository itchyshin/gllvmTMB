## Resume arms B and C of the Ayumi-scale second opinion.
##
## The original driver completed arm A (Laplace) at n=5397 and then stopped
## before the VA arms ran. Arm A's result is already on disk; this script runs
## only B (VA, JJ bound) and C (VA, Gauss-Hermite) on the SAME simulated data
## (same seed) so the three arms remain comparable.

root <- "/private/tmp/gllvmtmb-va-wiring-20260726"
suppressMessages(devtools::load_all(root, quiet = TRUE))
source(file.path(root, "dev", "ayumi-scale-second-opinion-helpers.R"), local = FALSE)

N_FULL <- 5397L; Tt <- 20L; Q <- 2L; SEED_FULL <- 20260727L
OUT <- file.path(root, "dev", "ayumi-scale-resume-BC-results.csv")

say <- function(...) { cat(sprintf(...)); flush(stdout()) }
say("Ayumi-scale resume: arms B and C only, n=%d T=%d q=%d seed=%d\n",
    N_FULL, Tt, Q, SEED_FULL)

sim <- simulate_bernoulli_ayumi(N_FULL, Tt, Q, seed = SEED_FULL)
say("simulated: %d x %d\n", nrow(sim$Y), ncol(sim$Y))

rows <- list()
record <- function(arm, stage, ok, secs, note) {
  rows[[length(rows) + 1L]] <<- data.frame(
    arm = arm, stage = stage, ok = ok, elapsed_s = round(secs, 1),
    note = note, stringsAsFactors = FALSE
  )
  utils::write.csv(do.call(rbind, rows), OUT, row.names = FALSE)
  say("[%s/%s] ok=%s %.1fs %s\n", arm, stage, ok, secs, note)
}

for (arm in c("B", "C")) {
  em <- if (arm == "B") "jj" else "gh"

  t0 <- proc.time()[["elapsed"]]
  pt <- fit_arm_VA_point(root, sim, eval_method = em, H = 15L)
  t_pt <- proc.time()[["elapsed"]] - t0

  if (!isTRUE(pt$ok)) {
    record(arm, "fit", FALSE, t_pt, paste("FAILED:", pt$error_message %||% "unknown"))
    next
  }
  note <- sprintf("rel_frob=%.4f atten=%.4f grad=%.2e",
                  rel_frobenius(pt$Sigma_hat, sim$Sigma_true),
                  attenuation_ratio(pt$Sigma_hat, sim$Sigma_true),
                  pt$grad_max %||% NA_real_)
  record(arm, "fit", TRUE, t_pt, note)

  ## The SE step is the one expected to degrade: .va_r3_fixed_information()
  ## guards the dense Schur complement at max_variational = 6000, and the
  ## variational block here is 5397*5 = 26,985. Record WHICH SE came back.
  t0 <- proc.time()[["elapsed"]]
  se <- fit_arm_VA_se(root, sim, eval_method = em, best_par = pt$best_par, H = 15L)
  t_se <- proc.time()[["elapsed"]] - t0

  se_note <- if (isTRUE(se$ok)) {
    sprintf("status=%s profile_se=%s conditional_se=%s",
            se$status %||% NA_character_,
            if (is.null(se$beta_se_profile)) "NULL" else "present",
            if (is.null(se$beta_se_conditional)) "NULL" else "present")
  } else paste("FAILED:", se$error_message %||% "unknown")
  record(arm, "se", isTRUE(se$ok), t_se, se_note)
}

say("\nDONE. Results: %s\n", OUT)
print(do.call(rbind, rows))
