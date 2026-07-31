## Admission fence for the opt-in variational integration routes.
##
## `integration = "va"` is a research route. It is admitted only inside the
## region for which evidence exists or is being gathered, and the fence ERRORS
## rather than warns: a warning would let a user keep a fit from outside the
## evidenced region, which is the outcome the fence exists to stop.
##
## The fence takes `integration` as a plain string rather than matching a fixed
## set, so it still guards any route reached by a hand-built control list, not
## only the values `gllvmTMBcontrol()` admits.
##
## The boundaries are not taste. Each is traceable:
##   * `unique = FALSE` -- every VA measurement in this package suppresses Psi.
##     The DEFAULT `latent()` carries diag(psi), for which NO VA evidence
##     exists, so admitting it would advertise an unmeasured model class.
##   * binomial-logit / poisson-log -- poisson-log and gaussian-identity are
##     EXACT under the VA objective and binomial-logit uses 1-D Gauss-Hermite;
##     no other family has an admitted evaluation (Design 104 s4).
##   * `n >= 100` -- a hard error, not a caution. Recomputed from
##     dev/totoro-grid/results/grid.csv, the GH arm's signed scale
##     tr(Sigma_hat)/tr(Sigma_true) is 4.302 at n = 40: fourfold inflation.
##   * `q <= 4`, `p <= 80` -- the grid's own extent. q = 4 is admitted by the
##     2026-07-31 scope freeze and ships only if Gate 3's q = 4 cells pass on
##     their own terms.
##   * `engine = "julia"` -- the bridge implements no variational route at all.
##     R first, Julia next (maintainer, 2026-07-31).
.gllvmTMB_integration_fence_limits <- function() {
  list(
    families = c("binomial", "poisson"),
    links = c(binomial = "logit", poisson = "log"),
    q_max = 4L,
    p_max = 80L,
    n_min = 100L
  )
}

.gllvmTMB_check_integration_fence <- function(integration,
                                              family = NULL,
                                              link = NULL,
                                              q = NULL,
                                              p = NULL,
                                              n = NULL,
                                              unique = FALSE,
                                              engine = "tmb") {
  if (identical(integration, "laplace")) return(invisible(TRUE))
  lim <- .gllvmTMB_integration_fence_limits()

  bad <- function(msg, hint) {
    cli::cli_abort(c(
      "{.code integration = \"{integration}\"} does not admit this model.",
      "x" = msg,
      "i" = hint,
      ">" = "Use {.code integration = \"laplace\"} (the default) for this fit."
    ), call = NULL)
  }

  if (!identical(engine, "tmb")) {
    bad("{.arg engine} = {.val {engine}} has no variational route.",
        "The variational engines are implemented for the native TMB engine only.")
  }
  if (isTRUE(unique)) {
    bad("The model carries a diagonal {.field Psi} ({.code unique = TRUE}).",
        "Every variational measurement in this package suppresses {.field Psi};
         no evidence exists for the Psi-carrying model.")
  }
  if (!is.null(family) && !family %in% lim$families) {
    bad("Family {.val {family}} has no admitted variational evaluation.",
        "Admitted: {.val {lim$families}}.")
  }
  if (!is.null(family) && !is.null(link)) {
    want <- lim$links[[family]]
    if (!is.null(want) && !identical(link, want)) {
      bad("Link {.val {link}} is not admitted for family {.val {family}}.",
          "Admitted link for {.val {family}}: {.val {want}}.")
    }
  }
  if (!is.null(q) && q > lim$q_max) {
    bad("{.arg q} = {q} exceeds the evidenced maximum of {lim$q_max}.",
        "Gate 3 covers q up to {lim$q_max}; beyond that there is no evidence.")
  }
  if (!is.null(p) && p > lim$p_max) {
    bad("{p} responses exceeds the evidenced maximum of {lim$p_max}.",
        "The measurement grid extends to {lim$p_max} responses.")
  }
  if (!is.null(n) && n < lim$n_min) {
    bad("{n} units is below the evidenced minimum of {lim$n_min}.",
        "At n = 40 the quadrature route inflates the recovered covariance
         about fourfold; small n is disqualified, not merely cautioned.")
  }
  invisible(TRUE)
}
