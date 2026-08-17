## Fenced LA-MSPL interval scaffolding (D-157 new construction).
##
## Not exported. Not a Design. Not public confint / vcov / se=TRUE.
## Coordinates with the same-sitting triad note:
##   docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md
##
## Roles (Shinichi 2026-08-17; D-12 hero restated as "signature"):
##   Profile  = signature / primary claim path — NOT constructed here
##   Wald Q_0 = quickest baseline / availability check (D-149 pin)
##   Bootstrap = asymmetry — NOT constructed here
##
## This file must never be wired into R/z-confint-gllvmTMB.R.
## Public confint() stays refused by .gllvmTMB_mspl_assert_inference.
## Do not reopen Design 118. Do not call TMB::sdreport(). Do not export.

.gllvmTMB_mspl_ci_triad <- function() {
  list(
    profile = list(
      role = "signature",
      public = FALSE,
      status = "not_constructed",
      doctrine = "D-12 hero / house brand; this sitting: signature error"
    ),
    wald_q0 = list(
      role = "quickest_baseline",
      tape = "Q_0",
      public = FALSE,
      status = "availability_check_only",
      doctrine = "D-12 speed order + D-149 / Ranga paper target"
    ),
    bootstrap = list(
      role = "asymmetry",
      public = FALSE,
      status = "not_constructed",
      doctrine = "non-symmetric sampling; not a Wald-undercoverage repair"
    ),
    binding = c("D-12", "D-157", "D-149", "D-148"),
    design_118 = "parked",
    sibling_triad_note =
      "docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md"
  )
}

.gllvmTMB_mspl_profile_ci_family_ok <- function(fit) {
  fl <- .gllvmTMB_mspl_pin_family_link(fit)
  ok <- (identical(fl$family, "gaussian") && identical(fl$link, "identity")) ||
    (identical(fl$family, "poisson") && identical(fl$link, "log"))
  c(fl, list(ok = isTRUE(ok)))
}

## Internal stub: accept a toy MSPL point fit (gaussian identity or
## poisson log, se=FALSE) and return a fenced scaffold. Profile bounds
## are not computed while Design G0 is open. Optional Wald Q_0 pin is
## the quick check only — never a public interval.
.gllvmTMB_mspl_profile_ci_scaffold <- function(fit, run_wald_q0 = FALSE) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The MSPL profile-CI scaffold requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_profile_ci_input"
    )
  }
  fl <- .gllvmTMB_mspl_profile_ci_family_ok(fit)
  if (!isTRUE(fl$ok)) {
    .gllvmTMB_mspl_abort(
      "The MSPL profile-CI scaffold is fenced to Gaussian identity or Poisson log point fits.",
      "x" = "Resolved family {.val {fl$family}}, link {.val {fl$link}}.",
      "i" = "This is a toy construction stub, not a public interval route.",
      class = "gllvmTMB_mspl_profile_ci_family"
    )
  }

  wald <- list(
    role = "quickest_baseline",
    tape = "Q_0",
    run = isTRUE(run_wald_q0),
    public_interval = FALSE,
    repaired = FALSE
  )
  if (isTRUE(run_wald_q0)) {
    pin <- .gllvmTMB_mspl_curvature_pin(fit)
    wald$pin_status <- pin$penalty_off$status
    wald$hessian_pd <- pin$penalty_off$hessian_pd
    wald$minimum_eigenvalue <- pin$penalty_off$minimum_eigenvalue
    wald$note <- paste(
      "Q_0 availability / paper Wald target (D-149).",
      "Not the signature CI. Non-PD stays typed; no repair."
    )
  } else {
    wald$status <- "not_run"
    wald$note <- paste(
      "Set run_wald_q0=TRUE to attach the existing D-149 Q_0 pin.",
      "That pin is a quick baseline, not a public Wald interval."
    )
  }

  list(
    public_confint = "refused",
    public_vcov = "refused",
    public_se = "refused",
    triad = .gllvmTMB_mspl_ci_triad(),
    family = fl$family,
    link = fl$link,
    se_false_point = is.null(fit$sd_report),
    inference_available = isTRUE(fit$mspl$inference$available),
    inference_calibrated = isTRUE(fit$mspl$inference$calibrated),
    profile = list(
      role = "signature",
      status = "not_constructed",
      public_confint = "refused",
      reason = paste(
        "Design G0 is open; D-157 requires a new construction,",
        "not a Design 118 reopen and not a public profile method on MSPL."
      ),
      objective_fork_unpicked = c(
        "A_penalised_Q_P",
        "B_unpenalized_Q_0_at_mspl_point",
        "C_hybrid"
      )
    ),
    wald_q0 = wald,
    bootstrap = list(
      role = "asymmetry",
      status = "not_constructed",
      public_interval = FALSE
    )
  )
}
