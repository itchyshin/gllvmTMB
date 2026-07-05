# Internal diagnostic mirror of the multivariate engine ids.
# family_to_id() in R/fit-multi.R and the C++ switch remain authoritative.
# Keep this file in lockstep with those runtime encodings.

.valid_family <- c(
  gaussian          = 0L,
  binomial          = 1L,
  poisson           = 2L,
  lognormal         = 3L,
  Gamma             = 4L,
  nbinom2           = 5L,
  tweedie           = 6L,
  Beta              = 7L,
  betabinomial      = 8L,
  student           = 9L,
  truncated_poisson = 10L,
  truncated_nbinom2 = 11L,
  delta_lognormal   = 12L,
  delta_gamma       = 13L,
  ordinal_probit    = 14L,
  nbinom1           = 15L
)

.valid_link <- c(
  logit   = 0L,
  probit  = 1L,
  cloglog = 2L
)
