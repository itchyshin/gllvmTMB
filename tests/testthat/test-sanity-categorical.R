# Tests for the multinomial K-1 contrast pseudo-trait degeneracy row
# (`.gllvmTMB_multinomial_degeneracy_row()`, component
# "multinomial_contrast_degeneracy") added beside the binomial detector row in
# `check_gllvmTMB()`. See R/diagnose.R for the M1/M2/M3 arm definitions.

## Hand-built `gllvmTMB_multi`-classed fixture, mirroring the `mk()` fixtures
## in test-sanity-multi.R. One multinomial response "cat" with `K` categories
## (K - 1 baseline-contrast pseudo-traits, named "cat:B", "cat:C", ...,
## matching expand_multinomial_response()'s "<base>:<category>" convention),
## optionally alongside non-multinomial `extra_traits` (mixed-family) and/or
## an SPDE tier.
mk_mn <- function(
  lam_B = NULL,
  K = 3L,
  extra_traits = NULL,
  use = list(rr_B = TRUE),
  spde = NULL,
  mesh = NULL
) {
  L <- K - 1L
  contrast_labels <- paste0("cat:", LETTERS[2:K])
  n_extra <- length(extra_traits)
  tl <- c(contrast_labels, names(extra_traits))
  n_traits <- length(tl)
  mnK <- c(rep(L, L), rep(0L, n_extra))
  tid <- rep(seq_len(n_traits) - 1L, each = 10L)
  n <- length(tid)

  report <- list(eta = rep(0, n))
  if (!is.null(lam_B)) {
    report$Lambda_B <- lam_B
  }
  if (!is.null(spde)) {
    report$Lambda_spde <- spde$Lambda
    report$kappa <- spde$kappa
  }

  fit <- list(
    fit_health = list(
      convergence = 0L, message = "ok", max_gradient = 0,
      sdreport_ok = TRUE, sdreport_error = NA_character_, pd_hessian = TRUE,
      max_fixed_se = 1, boundary_flags = character(0), selected_restart = 1L
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L, optimizer = "nlminb", objective = 0,
      convergence = 0L, selected = TRUE
    ),
    report = report,
    tmb_data = list(trait_id = tid, multinom_K_per_trait = mnK),
    data = data.frame(trait = factor(tl[tid + 1L], levels = tl)),
    trait_col = "trait", n_traits = n_traits, use = use,
    mesh = mesh
  )
  class(fit) <- "gllvmTMB_multi"
  fit
}

mn_row <- function(fit, ...) {
  chk <- check_gllvmTMB(fit, ...)
  chk[chk$component == "multinomial_contrast_degeneracy", , drop = FALSE]
}

test_that("a fit with no multinomial contrasts has no degeneracy row", {
  ## An ordinary binomial fixture (borrowed shape from test-sanity-multi.R):
  ## multinom_K_per_trait is absent entirely, so the row must not appear.
  tl <- paste0("item", 1:3)
  tid <- rep(0:2, each = 10L)
  fit <- list(
    fit_health = list(
      convergence = 0L, message = "ok", max_gradient = 0,
      sdreport_ok = TRUE, sdreport_error = NA_character_, pd_hessian = TRUE,
      max_fixed_se = 1, boundary_flags = character(0), selected_restart = 1L
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L, optimizer = "nlminb", objective = 0,
      convergence = 0L, selected = TRUE
    ),
    report = list(
      Lambda_B = matrix(c(0.5, 0.4, 0.3), nrow = 3, dimnames = list(tl, "LV1")),
      eta = rep(0, 30L)
    ),
    tmb_data = list(
      y = rep(rep(c(0, 1), 5L), 3L), n_trials = rep(1, 30L),
      is_y_observed = rep(1L, 30L), family_id_vec = rep(1L, 30L),
      link_id_vec = rep(1L, 30L), trait_id = tid
    ),
    data = data.frame(trait = factor(tl[tid + 1L], levels = tl)),
    trait_col = "trait", n_traits = 3L, use = list(rr_B = TRUE)
  )
  class(fit) <- "gllvmTMB_multi"

  expect_null(gllvmTMB:::.gllvmTMB_multinomial_degeneracy_row(fit))
  expect_false(
    "multinomial_contrast_degeneracy" %in% check_gllvmTMB(fit)$component
  )
})

test_that("a healthy d = 2 multinomial fit PASSes both M1 and M2", {
  lam <- matrix(
    c(0.8, -0.6, 0.5, 0.4),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam)
  row <- mn_row(fit)

  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "PASS")
  expect_match(row$value, "d=2")
})

test_that("a collapsed contrast fires M1 and not M2", {
  ## One contrast's loading energy collapses to ~1e-12/1e-14 (well below the
  ## 1e-10 floor); the two contrasts remain orthogonal (rho ~ 0), so M2 must
  ## not fire.
  lam <- matrix(
    c(0.8, 1e-6, 0.5, 1e-7),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam)
  row <- mn_row(fit)

  expect_equal(row$status, "WARN")
  expect_match(row$message, "M1")
  expect_false(grepl("M2", row$message))
  expect_match(row$action, "intentionally mapped off, boundary-pinned, or genuinely collapsed")
})

test_that("a railed d = 2 fit fires M2 and not M1", {
  ## The two contrasts load proportionally on the same two-axis tier
  ## (column 2 is exactly 2x column 1), which drives the implied
  ## contrast-level correlation to +-1 without any collapse in magnitude.
  lam <- matrix(
    c(0.8, 1.6, 0.5, 1.0),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam)
  row <- mn_row(fit)

  expect_equal(row$status, "WARN")
  expect_match(row$message, "M2")
  expect_false(grepl("M1", row$message))
  expect_match(row$value, "max_rail_rho=1")
})

test_that("a seed-202-shaped fit (collapse + rail) fires both M1 and M2", {
  lam <- matrix(
    c(0.8, 1.6e-6, 0.5, 1.0e-6),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam)
  row <- mn_row(fit)

  expect_equal(row$status, "WARN")
  expect_match(row$message, "M1")
  expect_match(row$message, "M2")
})

test_that("a healthy d = 1 fit does NOT fire M2 (the row-proportionality suppression)", {
  ## At d = 1 every fit -- healthy or not -- has an implied contrast
  ## correlation of exactly +-1 by row proportionality (one shared loading
  ## column). The HARD PRECONDITION restricts M2 to tiers with rank >= 2, so
  ## this fixture must PASS despite the same rho that would fire M2 at d >= 2.
  lam <- matrix(
    c(0.8, 1.6),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), "LV1")
  )
  fit <- mk_mn(lam)
  row <- mn_row(fit)

  expect_equal(row$status, "PASS")
  expect_match(row$value, "d=1")
  expect_match(row$value, "max_rail_rho=NA")
})

test_that("a huge SPDE loading fires no absolute arm (M1/M2 stay scale-free)", {
  ## Mirrors the binomial row's 6.5e6-vs-66 unit-tier hazard: SPDE loadings
  ## are far outside link-scale units, so they must never trip a fixed
  ## absolute-magnitude threshold. M1 and M2 are themselves scale-free
  ## (a variance floor, and a correlation), so an enormous but orthogonal,
  ## non-collapsed SPDE loading matrix must PASS both.
  lam_spde <- matrix(
    c(6.5e6, 0, 0, 6.5e6 * 0.6),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  loc <- cbind(x = seq(0, 10, length.out = 50), y = seq(0, 10, length.out = 50))
  fit <- mk_mn(
    NULL,
    spde = list(Lambda = lam_spde, kappa = 0.01),
    use = list(spde = TRUE),
    mesh = list(loc_xy = loc)
  )
  row <- mn_row(fit)

  expect_equal(row$status, "PASS")
  expect_false(grepl("M1|M2", row$message))
})

test_that("a collapsed spatial practical range fires M3", {
  lam_spde <- matrix(
    c(6.5e6, 0, 0, 6.5e6 * 0.6),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  loc <- cbind(x = seq(0, 10, length.out = 50), y = seq(0, 10, length.out = 50))
  ## kappa = 4000 -> practical range sqrt(8)/4000 ~ 7.07e-4, and the domain
  ## diameter here is ~14.14 -> ratio ~ 5e-5, inside the labeled evidence
  ## band (7e-5 to 3.4e-4) and well below the default 0.02 threshold.
  fit <- mk_mn(
    NULL,
    spde = list(Lambda = lam_spde, kappa = 4000),
    use = list(spde = TRUE),
    mesh = list(loc_xy = loc)
  )
  row <- mn_row(fit)

  expect_equal(row$status, "WARN")
  expect_match(row$message, "M3")
  expect_match(row$action, "spatial practical range")
})

test_that("M3 is skipped for a block that does not load on the spatial tier, even under a collapsed kappa", {
  ## use$spde = TRUE with a Lambda_spde present, but the multinomial block's
  ## own rows are all-zero -- it does not load on the spatial field, so the
  ## collapsed kappa (4000, same as the M3-fires fixture above) must not add
  ## an M3 finding for this response. The all-zero rows ARE a true-zero
  ## variance, though, and M1 fires on that by design (documented
  ## null-semantics): the row's action text carries the house wording
  ## rather than asserting pathology outright.
  lam_spde <- matrix(
    c(0, 0),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), "LV1")
  )
  loc <- cbind(x = seq(0, 10, length.out = 50), y = seq(0, 10, length.out = 50))
  fit <- mk_mn(
    NULL,
    spde = list(Lambda = lam_spde, kappa = 4000),
    use = list(spde = TRUE),
    mesh = list(loc_xy = loc)
  )
  row <- mn_row(fit)

  expect_equal(row$status, "WARN")
  expect_match(row$message, "M1")
  expect_false(grepl("M3", row$message))
  expect_match(row$action, "intentionally mapped off, boundary-pinned, or genuinely collapsed")
})

test_that("mixed multinomial + gaussian: contrast stats ignore the partner trait", {
  ## A gaussian partner trait "g1" shares the same tier with a huge, healthy
  ## loading. The multinomial contrasts on their own are healthy (same as
  ## the "healthy d = 2" fixture above); the partner's scale must not leak
  ## into the multinomial-only M1/M2 statistics.
  lam <- matrix(
    c(0.8, -0.6, 300, 0.5, 0.4, 280),
    nrow = 3,
    dimnames = list(c(paste0("cat:", LETTERS[2:3]), "g1"), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam, extra_traits = list(g1 = 1))
  row <- mn_row(fit)

  expect_equal(row$status, "PASS")
  expect_match(row$value, "^cat@unit")
  expect_false(grepl("g1", row$value))
})

test_that("multinomial_collapse_floor brackets the M1 absolute arm", {
  mk_floor <- function(min_energy) {
    ## column 1 carries the near-zero contrast so rowSums(Lambda^2) for
    ## contrast 2 is exactly min_energy; column 2 keeps both contrasts
    ## orthogonal so M2 never fires here.
    lam <- matrix(
      c(0.8, sqrt(min_energy), 0.5, 0),
      nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
    )
    mk_mn(lam)
  }
  above <- mn_row(mk_floor(2e-10), multinomial_collapse_floor = 1e-10)
  below <- mn_row(mk_floor(0.5e-10), multinomial_collapse_floor = 1e-10)

  expect_equal(above$status, "PASS")
  expect_equal(below$status, "WARN")
})

test_that("multinomial_collapse_rel_thresh is disarmed by default (Inf)", {
  ## Siblings 100x apart in loading ENERGY (rowSums(Lambda^2): 0.64 vs
  ## 0.0064), on ORTHOGONAL directions so M2's rail arm cannot fire and
  ## confound the read -- at a finite rel_thresh (e.g. 0.1) this trips the
  ## sibling arm; at the Inf default it must not, because M1's absolute
  ## floor (1e-10) is nowhere near this scale.
  lam <- matrix(
    c(0.8, 0, 0, 0.08),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam)

  default_row <- mn_row(fit)
  expect_equal(default_row$status, "PASS")

  armed_row <- mn_row(fit, multinomial_collapse_rel_thresh = 0.1)
  expect_equal(armed_row$status, "WARN")
  expect_match(armed_row$message, "M1")
  expect_false(grepl("M2", armed_row$message))
})

# ---------------------------------------------------------------------------
# Tests for the ordinal-probit loading degeneracy row
# (`.gllvmTMB_ordinal_degeneracy_row()`, component "ordinal_liability_loading")
# added beside the binomial and multinomial detector rows in
# `check_gllvmTMB()`. See R/diagnose.R for the O1/O2 arm definitions and the
# detector-S1 mechanism-probe verdict (dev/ordinal-degeneracy/probe-criteria.md)
# that shaped them: category-level separation, not link saturation -- hence
# no flat-fit/saturation arm and no prevalence conjunct.

## Hand-built `gllvmTMB_multi`-classed fixture. `cuts` is a list, one entry
## per ordinal trait, of that trait's FREE cutpoints (tau_2 .. tau_{K-1});
## an empty numeric vector means K = 2 (no free cutpoint, the Hadfield
## convention). `extra_traits` is a named list mapping trait name -> family
## id (0 = gaussian, 1 = binomial) for non-ordinal traits appended after the
## ordinal ones, to probe disjointness against the other detector rows.
mk_ord <- function(
  lam_B = NULL,
  cuts = list(c(0.7, 1.4)),
  extra_traits = NULL,
  use = list(rr_B = TRUE),
  spde = NULL,
  mesh = NULL
) {
  n_ord <- length(cuts)
  ord_labels <- if (n_ord > 0L) paste0("ord", seq_len(n_ord)) else character(0)
  n_extra <- length(extra_traits)
  tl <- c(ord_labels, names(extra_traits))
  n_traits <- length(tl)

  n_cuts_pt <- integer(n_traits)
  off_pt <- integer(n_traits)
  cum <- 0L
  taus_flat <- numeric(0)
  if (n_ord > 0L) {
    for (i in seq_len(n_ord)) {
      ci <- cuts[[i]]
      nk <- length(ci)
      n_cuts_pt[i] <- nk
      off_pt[i] <- cum
      if (nk > 0L) {
        taus_flat <- c(taus_flat, ci)
        cum <- cum + nk
      }
    }
  }

  family_id_ord <- rep(14L, n_ord)
  family_id_extra <- if (n_extra > 0L) as.integer(unlist(extra_traits)) else integer(0)
  family_id_by_trait <- c(family_id_ord, family_id_extra)

  tid <- rep(seq_len(n_traits) - 1L, each = 10L)
  n <- length(tid)
  family_id_vec <- family_id_by_trait[tid + 1L]
  link_id_vec <- rep(0L, n)
  ## Binomial extras (family_id 1) need y/n_trials/is_y_observed for the
  ## binomial row to compute at all; an unremarkable 50/50 split so it PASSes
  ## unless the caller inflates that trait's own loading.
  y <- ifelse(family_id_vec == 1L, rep(c(0, 1), length.out = n), 0)
  n_trials <- rep(1, n)
  is_y_observed <- rep(1L, n)

  report <- list(eta = rep(0, n), ordinal_cutpoints = taus_flat)
  if (!is.null(lam_B)) {
    report$Lambda_B <- lam_B
  }
  if (!is.null(spde)) {
    report$Lambda_spde <- spde$Lambda
    report$kappa <- spde$kappa
  }

  fit <- list(
    fit_health = list(
      convergence = 0L, message = "ok", max_gradient = 0,
      sdreport_ok = TRUE, sdreport_error = NA_character_, pd_hessian = TRUE,
      max_fixed_se = 1, boundary_flags = character(0), selected_restart = 1L
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L, optimizer = "nlminb", objective = 0,
      convergence = 0L, selected = TRUE
    ),
    report = report,
    tmb_data = list(
      trait_id = tid, family_id_vec = family_id_vec, link_id_vec = link_id_vec,
      y = y, n_trials = n_trials, is_y_observed = is_y_observed,
      n_ordinal_cuts_per_trait = n_cuts_pt, ordinal_offset_per_trait = off_pt
    ),
    data = data.frame(trait = factor(tl[tid + 1L], levels = tl)),
    trait_col = "trait", n_traits = n_traits, use = use,
    mesh = mesh
  )
  class(fit) <- "gllvmTMB_multi"
  fit
}

ord_row <- function(fit, ...) {
  chk <- check_gllvmTMB(fit, ...)
  chk[chk$component == "ordinal_liability_loading", , drop = FALSE]
}

test_that("a fit with no ordinal_probit trait has no degeneracy row", {
  fit <- mk_ord(
    lam_B = matrix(0.5, nrow = 1, dimnames = list("g1", "LV1")),
    cuts = list(),
    extra_traits = list(g1 = 0L)
  )

  expect_null(gllvmTMB:::.gllvmTMB_ordinal_degeneracy_row(fit))
  expect_false(
    "ordinal_liability_loading" %in% check_gllvmTMB(fit)$component
  )
})

test_that("a healthy ordinal fit PASSes under calibration-style armed thresholds", {
  lam <- matrix(
    c(0.5, -0.4, 0.6),
    nrow = 3, dimnames = list(paste0("ord", 1:3), "LV1")
  )
  fit <- mk_ord(lam, cuts = list(c(0.7, 1.4), c(0.5, 1.1), c(0.6, 1.3)))
  row <- ord_row(
    fit,
    ordinal_loading_runaway_thresh = 25,
    ordinal_loading_absolute_thresh = 6
  )

  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "PASS")
})

test_that("the disarmed defaults fire nothing; explicit thresholds arm the arms", {
  ## Both ordinal thresholds ship at Inf. The 2026-08-17 calibration could
  ## not find a value meeting its frozen targets (see
  ## dev/ordinal-degeneracy/pass-criteria-ordinal.md), so the pre-registered
  ## ship-disarmed fallback applies: the row reports its statistics and a
  ## user arms it explicitly if they want the verdict.
  lam <- matrix(
    c(0.5, -0.4, 20),
    nrow = 3, dimnames = list(paste0("ord", 1:3), "LV1")
  )
  fit <- mk_ord(lam, cuts = list(c(0.7, 1.4), c(0.5, 1.1), c(0.6, 1.3)))

  expect_equal(ord_row(fit)$status, "PASS")

  ## Explicitly armed on the SAME fixture, the runaway trait fires.
  armed <- ord_row(fit, ordinal_loading_runaway_thresh = 25)
  expect_equal(armed$status, "WARN")
})

test_that("a single-column runaway fixture fires O1 (armed) and names the right trait", {
  lam <- matrix(
    c(0.5, -0.4, 20),
    nrow = 3, dimnames = list(paste0("ord", 1:3), "LV1")
  )
  fit <- mk_ord(lam, cuts = list(c(0.7, 1.4), c(0.5, 1.1), c(0.6, 1.3)))
  row <- ord_row(
    fit,
    ordinal_loading_runaway_thresh = 25,
    ordinal_loading_absolute_thresh = Inf
  )

  expect_equal(row$status, "WARN")
  expect_match(row$message, "O1")
  expect_false(grepl("O2", row$message))
  expect_match(row$value, "^ord3")
})

test_that("an absolute-magnitude fixture fires O2 under an explicit threshold", {
  ## All three loadings are similar in magnitude (relative_loading stays
  ## near 1), but the common magnitude itself clears the absolute threshold.
  lam <- matrix(
    c(7, 6.5, 7.2),
    nrow = 3, dimnames = list(paste0("ord", 1:3), "LV1")
  )
  fit <- mk_ord(lam, cuts = list(c(0.7, 1.4), c(0.5, 1.1), c(0.6, 1.3)))
  row <- ord_row(
    fit,
    ordinal_loading_runaway_thresh = 25,
    ordinal_loading_absolute_thresh = 6
  )

  expect_equal(row$status, "WARN")
  expect_match(row$message, "O2")
  expect_false(grepl("O1", row$message))
})

test_that("ordinal_loading_runaway_thresh brackets the O1 arm", {
  lam <- matrix(
    c(0.5, -0.4, 15),
    nrow = 3, dimnames = list(paste0("ord", 1:3), "LV1")
  )
  fit <- mk_ord(lam, cuts = list(c(0.7, 1.4), c(0.5, 1.1), c(0.6, 1.3)))

  ## relative_loading for ord3 is 15 / 0.5 = 30.
  below <- ord_row(
    fit, ordinal_loading_runaway_thresh = 40,
    ordinal_loading_absolute_thresh = Inf
  )
  above <- ord_row(
    fit, ordinal_loading_runaway_thresh = 25,
    ordinal_loading_absolute_thresh = Inf
  )

  expect_equal(below$status, "PASS")
  expect_equal(above$status, "WARN")
  expect_match(above$message, "O1")
})

test_that("ordinal_loading_absolute_thresh brackets the O2 arm", {
  lam <- matrix(6, nrow = 1, dimnames = list("ord1", "LV1"))
  fit <- mk_ord(lam, cuts = list(c(0.7, 1.4)))

  below <- ord_row(
    fit, ordinal_loading_runaway_thresh = Inf,
    ordinal_loading_absolute_thresh = 6.5
  )
  above <- ord_row(
    fit, ordinal_loading_runaway_thresh = Inf,
    ordinal_loading_absolute_thresh = 6
  )

  expect_equal(below$status, "PASS")
  expect_equal(above$status, "WARN")
  expect_match(above$message, "O2")
})

test_that("a huge SPDE-only loading fires no absolute arm (unit-tier rule)", {
  ## Lambda_B is absent for this trait -- only the spatial tier loads --
  ## so max_loading_unit is NA (no unit-tier entry exists) and O2 can never
  ## fire from it, mirroring the binomial row's 6.5e6-vs-66 unit-tier hazard.
  lam_spde <- matrix(6.5e6, nrow = 1, dimnames = list("ord1", "LV1"))
  fit <- mk_ord(
    NULL, cuts = list(c(0.7, 1.4)),
    spde = list(Lambda = lam_spde, kappa = 0.01)
  )
  row <- ord_row(
    fit,
    ordinal_loading_runaway_thresh = 25,
    ordinal_loading_absolute_thresh = 6
  )

  expect_equal(row$status, "PASS")
  expect_match(row$value, "max_loading_unit=NA")
})

test_that("disjointness vs the binomial row: gaussian + ordinal + binomial, no masking", {
  ## The gaussian trait carries a huge loading (300) that must not leak into
  ## the ordinal trait's family-scoped typical/spread, and the ordinal
  ## trait's own runaway must not be masked by (or leak into) the binomial
  ## row, which screens only its own family's rows.
  lam <- matrix(
    c(0.5, 300, 0.4),
    nrow = 3, dimnames = list(c("ord1", "g1", "b1"), "LV1")
  )
  fit <- mk_ord(
    lam, cuts = list(c(0.7, 1.4)),
    extra_traits = list(g1 = 0L, b1 = 1L)
  )
  chk <- check_gllvmTMB(
    fit,
    loading_runaway_thresh = 25, loading_absolute_thresh = 6,
    ordinal_loading_runaway_thresh = 25, ordinal_loading_absolute_thresh = 6
  )
  ord <- chk[chk$component == "ordinal_liability_loading", , drop = FALSE]
  bin <- chk[chk$component == "binomial_prevalence_loading", , drop = FALSE]

  ## Neither family's screen is disturbed by the gaussian trait's scale.
  expect_equal(ord$status, "PASS")
  expect_equal(bin$status, "PASS")
  expect_false("multinomial_contrast_degeneracy" %in% chk$component)

  ## Now make the ordinal trait itself runaway: the binomial row must stay
  ## clean, proving the ordinal arm does not leak into it either.
  lam2 <- lam
  lam2["ord1", ] <- 20
  fit2 <- mk_ord(
    lam2, cuts = list(c(0.7, 1.4)),
    extra_traits = list(g1 = 0L, b1 = 1L)
  )
  chk2 <- check_gllvmTMB(
    fit2,
    loading_runaway_thresh = 25, loading_absolute_thresh = 6,
    ordinal_loading_runaway_thresh = 25, ordinal_loading_absolute_thresh = 6
  )
  expect_equal(
    chk2$status[chk2$component == "ordinal_liability_loading"], "WARN"
  )
  expect_equal(
    chk2$status[chk2$component == "binomial_prevalence_loading"], "PASS"
  )
})

test_that("a K = 2 ordinal trait's cutpoint span is NA, not an error", {
  span <- gllvmTMB:::.gllvmTMB_ordinal_cutpoint_span_by_trait(
    mk_ord(cuts = list(numeric(0))), ids = 1L
  )
  expect_true(is.na(span[["1"]]))

  ## Wired into the row without erroring, and without blocking O1/O2 from
  ## still firing on the SAME fixture when a runaway loading is present.
  lam <- matrix(20, nrow = 1, dimnames = list("ord1", "LV1"))
  fit <- mk_ord(lam, cuts = list(numeric(0)))
  row <- ord_row(
    fit,
    ordinal_loading_runaway_thresh = Inf,
    ordinal_loading_absolute_thresh = 6
  )

  expect_equal(row$status, "WARN")
  expect_match(row$value, "cutpoint_span=NA")
})

test_that("multinomial_rail_thresh brackets the M2 arm", {
  ## Two unit-norm contrast rows separated by angle 0.1 rad give an exact
  ## rho = cos(0.1) = 0.995004..., independent of magnitude. Bracket the
  ## threshold on the SAME fixture, the house convention used for
  ## psi_rel_thresh in test-sanity-multi.R.
  lam <- matrix(
    c(1, cos(0.1), 0, sin(0.1)),
    nrow = 2, dimnames = list(paste0("cat:", LETTERS[2:3]), c("LV1", "LV2"))
  )
  fit <- mk_mn(lam)

  below <- mn_row(fit, multinomial_rail_thresh = 0.99)
  above <- mn_row(fit, multinomial_rail_thresh = 0.999)

  expect_equal(below$status, "WARN")
  expect_match(below$message, "M2")
  expect_equal(above$status, "PASS")
})
