## Noether diagnostic 5 (VA double-diagonal, STEP 1): structural.
## Build the tier layout with the harness's OWN extra_tiers spec and compare
## tier 2 ("psi", from unique = TRUE) with tier 4 ("phylo_psi", from
## .d108_va_phylo_tiers). Read-only; no fitting, no compile.
suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))
source("dev/design108-recovery/harness.R")

N0 <- 60L; T0 <- 8L; q0 <- 1L
sim <- simulate_two_tier(N = N0, T = T0, q = q0, seed = 1L, phylo_scale = 1,
                         n_trials = 6L)
dat <- sim$data
unit <- dat$unit; trait <- dat$trait
X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T0))))
sp <- sim$species_levels
phy <- .d108_va_phylo_tiers("augmented", sim$tree, sp, unit, T0, q0)

cat("### extra_tiers as harness.R:228-233 declares them\n")
str(phy$extra_tiers, max.level = 2)

v <- gllvmTMB:::.va_r3_validate_data(
  y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
  q = q0, family = "binomial_probit", link = "probit", unique = TRUE,
  structured = phy$structured, extra_tiers = phy$extra_tiers)
lay <- v$tier_layout
cat("\n### tier_layout\n")
for (nm in c("kind", "dim", "n_levels", "label", "structured",
             "theta_offset", "sd_offset", "mean_offset")) {
  if (!is.null(lay[[nm]])) cat(sprintf("  %-13s : %s\n", nm, paste(lay[[nm]], collapse = " | ")))
}

tiers <- v$tiers %||% NULL
if (is.null(tiers)) {
  ## rebuild the tier list the same way validate_data does, to compare level_id
  tiers <- gllvmTMB:::.va_r3_build_tiers(
    unit_id0 = unit - 1L, N = N0, T = T0, q = q0, n_obs = length(unit),
    extra_tiers = phy$extra_tiers, want_psi = TRUE, structured = phy$structured)
}
cat("\n### tier-by-tier\n")
for (k in seq_along(tiers)) {
  tk <- tiers[[k]]
  cat(sprintf("  tier %d: kind=%-9s dim=%-3d n_levels=%-4d structured=%-5s label=%s\n",
              k, tk$kind, tk$dim, tk$n_levels, tk$structured, tk$label))
}
cat("\n### THE QUESTION: are tiers 2 and 4 the same declaration?\n")
t2 <- tiers[[2]]; t4 <- tiers[[4]]
for (f in c("kind", "dim", "n_levels", "structured")) {
  cat(sprintf("  %-11s tier2=%-9s tier4=%-9s  identical=%s\n", f,
              as.character(t2[[f]]), as.character(t4[[f]]),
              identical(t2[[f]], t4[[f]])))
}
cat(sprintf("  level_id    identical = %s   (max abs diff = %s)\n",
            identical(t2$level_id, t4$level_id),
            format(max(abs(as.integer(t2$level_id) - as.integer(t4$level_id))))))
cat(sprintf("\n  => tiers 2 and 4 are byte-identical declarations: %s\n",
            identical(t2[setdiff(names(t2), "label")], t4[setdiff(names(t4), "label")])))
cat("\nDONE\n")
