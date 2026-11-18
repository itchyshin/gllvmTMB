## Deterministic, no-fit G2l design-admission screen.
##
## The G2h fixture validator defines the target regime: a six-species fixture
## with source-gate information and covariate orthogonality adequate for the
## locked GBIF-bias estimand.  This screen is run once before fitting; it does
## not inspect fitted results or recoveries.

g2l_candidate_seeds <- 86201L:87000L
g2l_n_eligible <- 150L

g2l_screen_eligible_seeds <- function(
    fixture_file = file.path(getwd(), "dev", "isdm-package-recovery", "g2h-360cell-fixture.R")) {
  stopifnot(file.exists(fixture_file))
  source(fixture_file, local = TRUE)
  eligible <- vapply(g2l_candidate_seeds, function(seed) {
    !inherits(try(g2h_validate_fixture(g2h_make_fixture(seed = seed)), silent = TRUE), "try-error")
  }, logical(1L))
  stopifnot(sum(eligible) >= g2l_n_eligible)
  list(
    candidate_seeds = g2l_candidate_seeds,
    eligible = eligible,
    eligible_seeds = g2l_candidate_seeds[eligible][seq_len(g2l_n_eligible)],
    rejected_seeds = g2l_candidate_seeds[!eligible]
  )
}
