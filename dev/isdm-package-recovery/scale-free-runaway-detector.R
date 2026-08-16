## Scale-free runaway detector for SPDE latent-slope fits -- pure contract.
## Prototype (dev/ only; R/ integration is a separately reviewed slice).
##
## Mechanism basis (2026-08-15 classification + 5,600-fit corpus): the runaway
## is a whole-block scale ray -- kappa and the loading blocks blow up together
## while the likelihood degenerates. Absolute loading thresholds cannot police
## it (the true loading norm sits AT the shipped threshold; #851 class). The
## gauge-invariant coordinates are:
##   amp   = ||lambda_block|| * sd_field(kappa)  (link-scale field SD)
##   range = sqrt(8) / kappa                     (vs the design's own mesh cutoff)
## Verdict: RUNAWAY iff  amp > amp_absurd  OR  (range < mesh_cutoff AND
## amp > amp_floor). The floor keeps collapsed blocks (amp ~ 0) from being
## flagged for a meaningless kappa.

.sfr_fail <- function(msg) stop(msg, call. = FALSE)

sfr_check <- function(log_kappa, lambda_blocks, mesh_cutoff,
                      sd_field = NULL,
                      amp_absurd = 3, amp_floor = 0.1) {
  if (!is.numeric(log_kappa) || length(log_kappa) != 1L || !is.finite(log_kappa))
    .sfr_fail("log_kappa must be one finite number")
  if (!is.list(lambda_blocks) || is.null(names(lambda_blocks)) ||
      any(!nzchar(names(lambda_blocks))))
    .sfr_fail("lambda_blocks must be a named list of loading vectors")
  if (!is.numeric(mesh_cutoff) || length(mesh_cutoff) != 1L ||
      !is.finite(mesh_cutoff) || mesh_cutoff <= 0)
    .sfr_fail("mesh_cutoff must be one positive number")
  kappa <- exp(log_kappa)
  ## sd_field: exact per-design value if supplied (sqrt(mean diag(A Q^-1 A')));
  ## otherwise the continuum Matern nu=1 d=2 approximation (measured within
  ## ~6% in the interior on the reference design).
  sdf <- if (!is.null(sd_field)) {
    if (!is.numeric(sd_field) || length(sd_field) != 1L || !is.finite(sd_field) ||
        sd_field <= 0) .sfr_fail("sd_field must be one positive number")
    sd_field
  } else 1 / (sqrt(4 * pi) * kappa)
  amps <- vapply(lambda_blocks, function(l) {
    if (!is.numeric(l) || !length(l) || any(!is.finite(l)))
      .sfr_fail("each loading block must be a finite numeric vector")
    sqrt(sum(l^2)) * sdf
  }, numeric(1))
  rng <- sqrt(8) / kappa
  under_resolved <- rng < mesh_cutoff
  by_amp   <- amps > amp_absurd
  by_range <- under_resolved & amps > amp_floor
  flagged  <- by_amp | by_range
  reason <- ifelse(by_amp & by_range, "absurd_amplitude_and_under_resolved",
            ifelse(by_amp, "absurd_link_scale_amplitude",
            ifelse(by_range, "range_below_mesh_resolution_with_amplitude", "ok")))
  list(
    schema = "SCALE_FREE_RUNAWAY_CHECK_V1",
    runaway = any(flagged),
    range = rng, under_resolved = under_resolved,
    amplitudes = amps, flagged = flagged,
    reason = stats::setNames(reason, names(lambda_blocks)),
    thresholds = c(amp_absurd = amp_absurd, amp_floor = amp_floor,
                   mesh_cutoff = mesh_cutoff))
}
