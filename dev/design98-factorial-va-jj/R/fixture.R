d98_fixture_truth <- function() {
  list(
    beta = c(-.45, -.10, .30, .05, -.25, .40),
    loading = rbind(
      c(.82, 0),
      c(.18, .68),
      c(-.36, .30),
      c(.46, -.24),
      c(-.20, -.44),
      c(.28, .38)
    ),
    seed = 98001L,
    n_low = 160L,
    n_high = 640L,
    q = 2L
  )
}

d98_with_fixture_rng <- function(code) {
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit(
    {
      do.call(RNGkind, as.list(old_kind))
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    },
    add = TRUE
  )
  force(code)
}

d98_fixture_hash <- function(y) {
  if (!is.matrix(y)) {
    stop("Fixture response must be a matrix")
  }
  d98_sha256_raw(serialize(y, NULL, version = 2))
}

d98_validate_fixture <- function(y, label) {
  if (
    !is.matrix(y) ||
      !is.numeric(y) ||
      any(!is.finite(y)) ||
      !all(y %in% c(0, 1))
  ) {
    stop("Design-98 ", label, " fixture must be finite complete binary data")
  }
  sums <- colSums(y)
  if (any(sums == 0L) || any(sums == nrow(y))) {
    stop("Design-98 ", label, " fixture requires both outcomes in every trait")
  }
  invisible(TRUE)
}

d98_nested_fixture <- function() {
  truth <- d98_fixture_truth()
  d98_with_fixture_rng({
    RNGkind("Mersenne-Twister", "Inversion", "Rejection")
    set.seed(truth$seed)
    u <- matrix(
      stats::rnorm(truth$n_high * truth$q),
      nrow = truth$n_high,
      ncol = truth$q
    )
    probability <- stats::plogis(sweep(
      u %*% t(truth$loading),
      2L,
      truth$beta,
      "+"
    ))
    y_high <- matrix(
      stats::rbinom(
        truth$n_high * length(truth$beta),
        1L,
        as.vector(probability)
      ),
      nrow = truth$n_high,
      ncol = length(truth$beta)
    )
    y_low <- y_high[seq_len(truth$n_low), , drop = FALSE]
    d98_validate_fixture(y_low, "low")
    d98_validate_fixture(y_high, "high")
    list(
      truth = truth,
      u = u,
      probability = probability,
      low = list(label = "low", y = y_low, sha256 = d98_fixture_hash(y_low)),
      high = list(label = "high", y = y_high, sha256 = d98_fixture_hash(y_high))
    )
  })
}

d98_expected_fixture_hashes <- function() {
  c(
    low = "b70f775a83ff09a556d20645a761a0a845776a7718254d8c047fb60293da263b",
    high = "9bcc77c3766a3af61bbdc8d368be4cf41017aa1e5d6b04f4db8c9639feb8610e"
  )
}

d98_assert_fixture_hashes <- function(fixture) {
  expected <- d98_expected_fixture_hashes()
  actual <- c(low = fixture$low$sha256, high = fixture$high$sha256)
  if (!identical(actual, expected)) {
    stop("Design-98 nested fixture SHA-256 mismatch")
  }
  invisible(TRUE)
}
