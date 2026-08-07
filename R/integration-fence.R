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
##   * all 18 scalar family/link cells -- Gate E independently checked the
##     arithmetic oracle, compiled objective, and a light fit for every cell at
##     H = 7. Exact and hybrid expectation paths remain in place where the
##     likelihood permits them; the other scalar cells use 1-D Gauss-Hermite.
##     Multinomial is a coupled softmax architecture and is not a scalar cell.
##   * `n >= 100` -- a hard error, not a caution. Recomputed from
##     dev/totoro-grid/results/grid.csv, the GH arm's signed scale
##     tr(Sigma_hat)/tr(Sigma_true) is 4.302 at n = 40: fourfold inflation.
##   * `q <= 2`, `p <= 80` -- the measured extent. The 2026-07-31 scope freeze
##     admitted q = 4 CONDITIONALLY: it ships "only if Gate 3's q = 4 cells pass
##     on their own terms." They did not. Gate 3 (2026-07-31) found every one of
##     va_jj's axis-collapse failures in the single q = 4, p = 8 corner, at rates
##     0.26-0.77 against a 0.05 tolerance, with every lower 2*MCSE bound strictly
##     above the threshold -- four latent axes are not identifiable from eight
##     responses. So the fence stays at the region that DID pass: va_jj clears
##     the full conjunction in 100% of q <= 2 cells under BOTH pre-declared
##     rules (36/36 raw, 34/34 paired-exclusion), across all three truths, both
##     n, and every p.
##     Honest note: q <= 2 is further still from the 5+ latent factors that
##     decisions.md A3 names as the motivating regime. This narrows what we
##     claim, not the gap to that target.
##   * `engine = "julia"` -- the bridge implements no variational route at all.
##     R first, Julia next (maintainer, 2026-07-31).
##   * this is an implementation/light-fit boundary, not a recovery or coverage
##     certificate. Arc 2 keeps each family verdict independent.
.gllvmTMB_integration_fence_limits <- function() {
  links <- c(
    gaussian = "identity",
    binomial = "logit",
    binomial = "probit",
    binomial = "cloglog",
    poisson = "log",
    lognormal = "log",
    Gamma = "log",
    nbinom2 = "log",
    tweedie = "log",
    Beta = "logit",
    betabinomial = "logit",
    student = "identity",
    truncated_poisson = "log",
    truncated_nbinom2 = "log",
    delta_lognormal = "log",
    delta_gamma = "log",
    ordinal_probit = "probit",
    nbinom1 = "log"
  )
  list(
    families = unique(names(links)),
    links = links,
    q_max = 2L,
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
  if (!is.null(family)) {
    fams <- unique(as.character(family))
    bad_f <- setdiff(fams, lim$families)
    if (length(bad_f)) {
      bad("Family {.val {bad_f}} has no admitted variational evaluation.",
          "Admitted: {.val {lim$families}}.")
    }
  }
  if (!is.null(family) && !is.null(link)) {
    fams <- as.character(family)
    links <- as.character(link)
    if (length(links) == 1L && length(fams) > 1L) {
      links <- rep.int(links, length(fams))
    }
    if (length(fams) == 1L && length(links) > 1L) {
      fams <- rep.int(fams, length(links))
    }
    if (length(fams) != length(links)) {
      bad("Family and link vectors have unequal length.",
          "Supply one link per family row, or a single shared link.")
    }
    for (i in seq_along(fams)) {
      want <- unname(lim$links[names(lim$links) == fams[[i]]])
      if (length(want) && !links[[i]] %in% want) {
        bad("Link {.val {links[[i]]}} is not admitted for family {.val {fams[[i]]}}.",
            "Admitted link(s) for {.val {fams[[i]]}}: {.val {want}}.")
      }
    }
  }
  if (!is.null(q) && q > lim$q_max) {
    bad("{.arg q} = {q} exceeds the evidenced maximum of {lim$q_max}.",
        "Gate 3 measured q up to 4, and the recovery gate PASSED only up to
         {lim$q_max}: at q = 4 with few responses, planted axes collapse in
         26-77% of replicates against a 5% tolerance.")
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
