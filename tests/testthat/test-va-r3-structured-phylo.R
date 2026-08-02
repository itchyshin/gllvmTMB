## Design 108 Gate A Stage 7: the STRUCTURED phylogenetic KL (Design 106 s3).
##
## A structured tier differs from an unstructured one in exactly one place --
## its KL -- so every test here is about that one expression. Two of them are
## oracles rather than smoke tests, and they are the point of the file:
##
##   1. the iid REDUCTION. With Ainv = I the structured KL must collapse onto
##      the existing 0.5*(tr(S) + m'm - logdet(S) - d) EXACTLY. This is the
##      Stage 7 analogue of Stage 6's K = 1 byte-identity: it is what proves
##      the general form is the general form, and not merely a formula that
##      runs.
##   2. the DIRECT-ALGEBRA oracle. On a real (small) tree, the whole KL is
##      rebuilt in R from the textbook Gaussian-Gaussian expression with the
##      full prior precision materialised as a dense kron(I_d, Ainv), and the
##      template must match. That form makes no use of Design 106 s3.3's trace
##      collapse, so agreement tests the collapse as well as the KL.
##
## The KL implemented, and where each term comes from:
##
##   Design 106 s3.1 (textbook), with Q_p = Sigma_c^{-1} (x) A^{-1} and
##   Sigma_c = I_d because s3.2's standardized-field convention puts the scale
##   in the loading:
##
##     KL = 0.5*[ tr(Q_p S) + m' Q_p m - n*d - logdet(S) - logdet(Q_p) ]
##
##   with, for a level-factorised q,
##     tr(Q_p S)  = sum_g Ainv_gg * tr(S_g)          (s3.3; only diag(Ainv))
##     m' Q_p m   = sum_c m_.c' Ainv m_.c            (s3.5a; the Laplace block)
##     logdet(S)  = sum_g logdet(S_g)                (free from the Cholesky)
##     logdet(Q_p)= d * logdet(Ainv) = -d*log_det_A  (s3.4; KEPT, not dropped)
##
## Nothing here is exported, no `method=` is added, and the public integration
## fence is untouched -- asserted below.

.va_r3_phylo_fixture <- function(n_tip = 4L, T = 3L, q = 2L, d_struct = 2L,
                                 seed = 21L, diagonal = FALSE) {
  skip_if_not_installed("ape")
  set.seed(seed)
  tree <- ape::rcoal(n_tip)
  species_levels <- sort(tree$tip.label)
  struct <- .va_r3_phylo_structure(tree, species_levels)

  N <- n_tip
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  ## The structured tier's level for an observation is the AUGMENTED NODE of
  ## its species -- 0-based, exactly as the shipped engine's species_aug_id
  ## (R/fit-multi.R:3182). Internal nodes appear in no row at all.
  level_id <- struct$node_of_species[unit]
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  y <- as.numeric(stats::rbinom(N * T, 5L, 0.5))

  spec <- if (diagonal) {
    list(kind = "diagonal", level_id = level_id, structured = TRUE,
         label = "phylo_psi")
  } else {
    list(kind = "dense", dim = d_struct, level_id = level_id,
         structured = TRUE, label = "phylo")
  }
  validated <- .va_r3_validate_data(
    y = y, n_trials = rep(5L, N * T), X = X, unit_id = unit, trait_id = trait,
    q = q, structured = struct$structured, extra_tiers = list(spec)
  )
  layout <- validated$tier_layout
  set.seed(seed + 1L)
  parameters <- .va_r3_default_parameters(validated, 1L)
  parameters$m <- round(stats::rnorm(layout$total_mean), 3)
  parameters$log_L_diag <- round(stats::rnorm(layout$total_mean, 0, 0.25), 3)
  parameters$L_off <- round(stats::rnorm(layout$total_off, 0, 0.3), 3)

  ## Layout arithmetic written out longhand so the oracle is an independent
  ## statement of the packing rather than a restatement of the package's.
  slot <- function(v, k, c, g, which = "m") {
    base <- if (identical(which, "off")) layout$off_offset[k] else layout$m_offset[k]
    v[base + c * layout$n_levels[k] + g + 1L]
  }
  chol_dense <- function(k, g) {
    d <- layout$dim[k]
    L <- matrix(0, d, d)
    for (cc in seq_len(d)) L[cc, cc] <- exp(slot(parameters$log_L_diag, k, cc - 1L, g))
    pos <- 0L
    for (col in seq_len(d)) {
      for (row in seq.int(col + 1L, length.out = d - col)) {
        L[row, col] <- slot(parameters$L_off, k, pos, g, which = "off")
        pos <- pos + 1L
      }
    }
    L
  }
  list(tree = tree, struct = struct, N = N, T = T, q = q, X = X, y = y,
       level_id = level_id, validated = validated, layout = layout,
       parameters = parameters, slot = slot, chol_dense = chol_dense,
       Ainv = as.matrix(struct$structured$Ainv),
       log_det_A = struct$structured$log_det_A)
}

test_that("the augmented node set is READ, never computed as 2N-1", {
  skip_on_cran()
  skip_if_not_installed("ape")
  ## Design 106 s4.2 wrote `n_aug ~ 2N - 1` and s6.4(4) flagged it as needing
  ## verification. It is off by one for the builder this package actually uses:
  ## .gllvm_phylo_tree_precision() drops the ROOT (its parent term is never
  ## assembled), so a rooted bifurcating tree gives 2N - 2, not 2N - 1. That is
  ## the reason nothing in Stage 7 computes a node count -- it reads nrow(Ainv).
  for (n_tip in c(4L, 10L, 50L)) {
    set.seed(n_tip)
    tree <- ape::rcoal(n_tip)
    s <- .va_r3_phylo_structure(tree, sort(tree$tip.label))
    expect_identical(s$n_aug, as.integer(2L * n_tip - 2L))
    expect_identical(s$n_aug, as.integer(nrow(s$structured$Ainv)))
    ## Tips are the LAST rows (internal-first ordering), which is exactly why
    ## the level index may not be base-sniffed; see the refusal test below.
    expect_true(all(s$node_of_species >= s$n_aug - n_tip))
  }
  ## A polytomy reduces the node count, and the code must simply follow it.
  set.seed(4)
  poly <- ape::read.tree(text = "((a:1,b:1,c:1):1,d:2);")
  sp <- .va_r3_phylo_structure(poly, c("a", "b", "c", "d"))
  expect_lt(sp$n_aug, 2L * 4L - 2L)
})

test_that("with Ainv = I the structured KL reduces to the iid KL EXACTLY", {
  skip_on_cran()
  ## THE test of this stage. Two models that are the same model: one declares
  ## the extra tier structured with an identity precision, the other declares
  ## the identical tier unstructured. Same parameters, same data, same layout.
  ## If the general Gaussian-Gaussian form is right, every reported quantity
  ## agrees to the last bit -- not to a tolerance.
  N <- 6L; T <- 3L; q <- 2L; n_extra <- 5L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  set.seed(3)
  y <- as.numeric(stats::rbinom(N * T, 5L, 0.5))
  ## 0-based extra-tier levels, all five used, so the unstructured tier is
  ## admissible and the two declarations really are the same model.
  lev <- rep(c(0L, 1L, 2L, 3L, 4L, 0L), each = T)

  for (kind in c("dense", "diagonal")) {
    spec_common <- if (identical(kind, "dense")) {
      list(kind = "dense", dim = 2L)
    } else {
      list(kind = "diagonal")
    }
    vs <- .va_r3_validate_data(
      y, rep(5L, N * T), X, unit, trait, q,
      structured = list(Ainv = Matrix::Diagonal(n_extra)),
      extra_tiers = list(c(spec_common,
                           list(level_id = lev, structured = TRUE)))
    )
    vu <- .va_r3_validate_data(
      y, rep(5L, N * T), X, unit, trait, q,
      extra_tiers = list(c(spec_common,
                           list(level_id = lev, n_levels = n_extra)))
    )
    expect_identical(vs$tier_layout$structured, c(FALSE, TRUE))
    expect_identical(vu$tier_layout$structured, c(FALSE, FALSE))

    set.seed(9)
    p <- .va_r3_default_parameters(vs, 1L)
    p$m <- stats::rnorm(length(p$m))
    p$log_L_diag <- stats::rnorm(length(p$log_L_diag), 0, 0.2)
    p$L_off <- stats::rnorm(length(p$L_off), 0, 0.3)

    os <- .va_r3_make_objective(vs, H = 15L, parameters = p, eval_method = "gh")
    ou <- .va_r3_make_objective(vu, H = 15L, parameters = p, eval_method = "gh")
    rs <- os$report(os$par)
    ru <- ou$report(ou$par)

    expect_lt(max(abs(rs$kl_by_level - ru$kl_by_level)), 1e-14)
    expect_lt(abs(rs$total_kl - ru$total_kl), 1e-14)
    expect_lt(abs(os$fn(os$par) - ou$fn(ou$par)), 1e-14)
    expect_lt(max(abs(os$gr(os$par) - ou$gr(ou$par))), 1e-14)
    ## log det I = 0, so the tier constant is zero and nothing hides in it.
    expect_identical(as.numeric(rs$kl_const_by_tier), c(0, 0))
  }
})

test_that("the structured KL matches the textbook Gaussian-Gaussian form", {
  skip_on_cran()
  ## The direct-algebra oracle, built the SLOW way on purpose: materialise the
  ## full prior precision Q_p = kron(I_d, Ainv) and the full block-diagonal S,
  ## then evaluate Design 106 s3.1 verbatim
  ##
  ##   KL = 0.5*[ tr(Q_p S) + m' Q_p m - n*d - logdet(S) - logdet(Q_p) ]
  ##
  ## Nothing in this expression uses s3.3's trace collapse or s3.5a's sparse
  ## product, so agreement checks those two derivations as well as the KL.
  ## vec ordering: the template packs coordinate-SLOW, level-FAST, which is
  ## column-major vec() of the n x d mean matrix -- hence kron(I_d, Ainv).
  for (diagonal in c(FALSE, TRUE)) {
    fx <- .va_r3_phylo_fixture(n_tip = 5L, T = 3L, q = 2L, d_struct = 2L,
                               diagonal = diagonal)
    obj <- .va_r3_make_objective(fx$validated, H = 15L,
                                 parameters = fx$parameters,
                                 eval_method = "gh")
    report <- obj$report(obj$par)

    k <- 2L
    n <- fx$layout$n_levels[k]
    d <- fx$layout$dim[k]
    Ainv <- fx$Ainv
    expect_identical(nrow(Ainv), as.integer(n))

    M <- matrix(0, n, d)
    for (c in seq_len(d)) {
      for (g in seq_len(n)) M[g, c] <- fx$slot(fx$parameters$m, k, c - 1L, g - 1L)
    }
    S_full <- matrix(0, n * d, n * d)
    for (g in seq_len(n)) {
      S_g <- if (diagonal) {
        diag(exp(vapply(seq_len(d), function(c)
          fx$slot(fx$parameters$log_L_diag, k, c - 1L, g - 1L), numeric(1)))^2,
          nrow = d)
      } else {
        tcrossprod(fx$chol_dense(k, g - 1L))
      }
      idx <- (seq_len(d) - 1L) * n + g
      S_full[idx, idx] <- S_g
    }
    Q_p <- kronecker(diag(d), Ainv)
    vecM <- as.numeric(M)

    kl_expected <- 0.5 * (
      sum(diag(Q_p %*% S_full)) +
      drop(crossprod(vecM, Q_p %*% vecM)) -
      n * d -
      as.numeric(determinant(S_full, logarithm = TRUE)$modulus) -
      as.numeric(determinant(Q_p, logarithm = TRUE)$modulus)
    )
    expect_equal(as.numeric(report$kl_by_tier[k]), kl_expected,
                 tolerance = 1e-12)
    ## The tier's KL splits as (level-decomposable part) + (tier constant),
    ## and the constant is exactly the -logdet(Q_p) piece: 0.5*d*log_det_A.
    expect_equal(as.numeric(report$kl_const_by_tier[k]),
                 0.5 * d * fx$log_det_A, tolerance = 1e-12)
    expect_equal(
      sum(report$kl_by_level[fx$layout$level_offset[k] + seq_len(n)]) +
        as.numeric(report$kl_const_by_tier[k]),
      kl_expected, tolerance = 1e-12
    )
    ## total_kl really is the sum over tiers, constants included.
    expect_equal(as.numeric(report$total_kl), sum(as.numeric(report$kl_by_tier)),
                 tolerance = 1e-12)

    ## Autodiff over the structured block, not just the value: a wrong
    ## sparse-product transpose would still give the right VALUE on a
    ## symmetric Ainv but the wrong derivative.
    analytic <- as.numeric(obj$gr(obj$par))
    numeric_gr <- vapply(seq_along(obj$par), function(j) {
      h <- 1e-6 * max(1, abs(obj$par[j]))
      plus <- minus <- obj$par
      plus[j] <- plus[j] + h
      minus[j] <- minus[j] - h
      (obj$fn(plus) - obj$fn(minus)) / (2 * h)
    }, numeric(1))
    expect_lt(max(abs(analytic - numeric_gr) / pmax(1, abs(numeric_gr))), 1e-5)
  }
})

test_that("the standardized-field convention is the shipped engine's", {
  skip_on_cran()
  ## Design 106 s3.2 claims the VA structured prior is the SAME prior the
  ## Laplace engine writes at src/gllvmTMB.cpp:1166-1174:
  ##
  ##   -log p(g_c) = 0.5*( n*log(2pi) + log_det_A + g_c' Ainv g_c )
  ##
  ## The check: -E_q[log p(U)] must equal the sum of that expression over the d
  ## coordinates, evaluated at g_c = m_.c, plus the trace term the engine has
  ## no counterpart for (it evaluates at a point, not a distribution). Reading
  ## it off the KL, -E_q[log p] = KL - E_q[log q] = KL + 0.5*(logdet(S) +
  ## n*d*(1 + log 2pi)).
  ##
  ## A silent convention mismatch -- an sd^2*A prior, a covariance passed as a
  ## precision, a dropped or sign-flipped log-determinant -- fails here.
  fx <- .va_r3_phylo_fixture(n_tip = 5L, T = 3L, q = 2L, d_struct = 2L)
  obj <- .va_r3_make_objective(fx$validated, H = 15L,
                               parameters = fx$parameters, eval_method = "gh")
  report <- obj$report(obj$par)
  k <- 2L
  n <- fx$layout$n_levels[k]
  d <- fx$layout$dim[k]

  M <- matrix(0, n, d)
  logdet_S <- 0
  trace_term <- 0
  for (g in seq_len(n)) {
    L <- fx$chol_dense(k, g - 1L)
    S_g <- tcrossprod(L)
    logdet_S <- logdet_S + as.numeric(determinant(S_g, logarithm = TRUE)$modulus)
    trace_term <- trace_term + fx$Ainv[g, g] * sum(diag(S_g))
    for (c in seq_len(d)) M[g, c] <- fx$slot(fx$parameters$m, k, c - 1L, g - 1L)
  }

  kl_tier <- as.numeric(report$kl_by_tier[k])
  neg_e_log_p <- kl_tier + 0.5 * (logdet_S + n * d * (1 + log(2 * pi)))

  ## The engine's own expression, one column at a time, plus the trace term
  ## that turns a point evaluation into an expectation.
  engine <- 0
  for (c in seq_len(d)) {
    quad <- drop(crossprod(M[, c], fx$Ainv %*% M[, c]))
    engine <- engine + 0.5 * (n * log(2 * pi) + fx$log_det_A + quad)
  }
  engine <- engine + 0.5 * trace_term
  expect_equal(neg_e_log_p, engine, tolerance = 1e-10)
})

test_that("log_det_A is CARRIED, and shifts the ELBO without touching the gradient", {
  skip_on_cran()
  ## Design 106 s3.4: for a fixed tree logdet(Q_p) is constant in EVERY
  ## parameter, so it could be dropped -- and is kept anyway, so the ELBO sits
  ## on the same absolute scale as the Laplace objective and the Design 104 s7
  ## sign check stays meaningful. Both halves are testable: the objective must
  ## move by exactly 0.5*d*delta, and no derivative may move at all.
  fx <- .va_r3_phylo_fixture(n_tip = 5L, T = 3L, q = 2L, d_struct = 2L)
  base <- .va_r3_make_objective(fx$validated, H = 15L,
                                parameters = fx$parameters, eval_method = "gh")
  shifted_validated <- fx$validated
  delta <- 1.75
  shifted_validated$structured$log_det_A <-
    shifted_validated$structured$log_det_A + delta
  shifted <- .va_r3_make_objective(shifted_validated, H = 15L,
                                   parameters = fx$parameters,
                                   eval_method = "gh")
  d <- fx$layout$dim[2L]
  ## The ELBO is expected_loglik - KL and the constant enters the KL, so the
  ## NEGATIVE ELBO rises by 0.5*d*delta.
  expect_equal(shifted$fn(shifted$par) - base$fn(base$par),
               0.5 * d * delta, tolerance = 1e-10)
  expect_lt(max(abs(shifted$gr(shifted$par) - base$gr(base$par))), 1e-12)
  ## And it is genuinely non-zero for a real tree, i.e. dropping it would have
  ## silently moved the ELBO off the Laplace scale.
  expect_gt(abs(fx$log_det_A), 1e-6)
})

test_that("a structured tier keeps the inner Hessian sparse under profile=", {
  skip_on_cran()
  skip_if_not_installed("ape")
  ## R3's `profile=` route is only linear in N because the inner solve's
  ## Hessian is sparse. An unstructured multi-tier model gives an exactly
  ## per-unit block-diagonal H_vv; a phylogenetic tier COUPLES levels through
  ## Ainv, so the question is whether it merely widens the pattern by Ainv's
  ## own sparsity or densifies the solve. Measure it; do not assume it.
  measure <- function(n_tip, structured) {
    set.seed(31L)
    tree <- ape::rcoal(n_tip)
    levels_sp <- sort(tree$tip.label)
    s <- .va_r3_phylo_structure(tree, levels_sp)
    N <- n_tip; T <- 4L; q <- 2L
    unit <- rep(seq_len(N), each = T)
    trait <- rep(seq_len(T), N)
    X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
    set.seed(5L)
    y <- as.numeric(stats::rpois(N * T, 3))
    spec <- list(kind = "dense", dim = 2L,
                 level_id = s$node_of_species[unit], structured = structured,
                 label = "phylo")
    if (!structured) spec$n_levels <- s$n_aug
    v <- tryCatch(
      .va_r3_validate_data(y, rep(1L, N * T), X, unit, trait, q,
                           family = "poisson", link = "log",
                           structured = if (structured) s$structured else FALSE,
                           extra_tiers = list(spec)),
      error = function(e) e
    )
    if (inherits(v, "error")) return(list(error = conditionMessage(v)))
    o <- .va_r3_make_objective(v, H = 15L,
                               parameters = .va_r3_default_parameters(v, 1L),
                               eval_method = "gh", profile_variational = TRUE)
    o$fn(o$par)
    sp <- o$env$spHess(random = TRUE)
    list(nnz = length(methods::as(sp, "TsparseMatrix")@x),
         dim = nrow(sp), n_aug = s$n_aug)
  }

  ## The unstructured comparator cannot be built at the same node set -- the
  ## internal nodes carry no observation, which the unstructured tier refuses
  ## by design -- so that refusal is itself the first measurement.
  refused <- measure(20L, structured = FALSE)
  expect_true(!is.null(refused$error))
  expect_match(refused$error, "must be used by at least one row")

  a <- measure(20L, structured = TRUE)
  b <- measure(40L, structured = TRUE)
  c40 <- measure(80L, structured = TRUE)
  ## Linear, not quadratic: doubling the tips roughly doubles the stored
  ## entries. A densified solve would grow ~4x per doubling.
  expect_lt(b$nnz / a$nnz, 2.4)
  expect_lt(c40$nnz / b$nnz, 2.4)
  ## And the fill is a small multiple of the dimension, i.e. still sparse.
  expect_lt(c40$nnz / c40$dim, 12)
})

test_that("tips-only is admitted too -- and it is the route that densifies", {
  skip_on_cran()
  skip_if_not_installed("ape")
  ## Design 106 s6.4(5) calls tips-only-vs-augmented a genuine open question
  ## for VA. Stage 7 does not decide it by fiat: BOTH routes are reachable,
  ## because the tier's level count is read off nrow(Ainv) and nothing else.
  ## What Stage 7 can settle is the cost side, and it does, by measurement.
  ##
  ## The augmented A^{-1} has ~3 non-zeros per row, so under R3's `profile=`
  ## route the inner Hessian's stored-entry count per coordinate is CONSTANT in
  ## the number of tips. A tips-only A^{-1} is dense, so the same count grows
  ## linearly with the tips -- an O(N^2) inner solve. At the maintainer's
  ## envelope that is the difference between a sparse solve and a dense one.
  measure <- function(n_tip, route) {
    set.seed(31L)
    tree <- ape::rcoal(n_tip)
    sp <- sort(tree$tip.label)
    N <- n_tip; T <- 4L; q <- 2L
    unit <- rep(seq_len(N), each = T)
    trait <- rep(seq_len(T), N)
    X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
    set.seed(5L)
    y <- as.numeric(stats::rpois(N * T, 3))
    if (identical(route, "augmented")) {
      s <- .va_r3_phylo_structure(tree, sp)
      st <- s$structured; lid <- s$node_of_species[unit]
    } else {
      A <- ape::vcv(tree, corr = TRUE)[sp, sp] + diag(1e-8, N)
      st <- list(Ainv = solve(A),
                 log_det_A = as.numeric(determinant(A, logarithm = TRUE)$modulus))
      lid <- unit - 1L
    }
    v <- .va_r3_validate_data(y, rep(1L, N * T), X, unit, trait, q,
                              family = "poisson", link = "log", structured = st,
                              extra_tiers = list(list(kind = "dense", dim = 2L,
                                                      level_id = lid,
                                                      structured = TRUE)))
    o <- .va_r3_make_objective(v, H = 15L,
                               parameters = .va_r3_default_parameters(v, 1L),
                               eval_method = "gh", profile_variational = TRUE)
    o$fn(o$par)
    H <- methods::as(o$env$spHess(random = TRUE), "TsparseMatrix")
    length(H@x) / nrow(H)
  }
  aug <- vapply(c(20L, 40L, 80L), measure, numeric(1), route = "augmented")
  tip <- vapply(c(20L, 40L, 80L), measure, numeric(1), route = "tips_only")
  expect_lt(max(aug) - min(aug), 0.2)      # flat
  expect_gt(tip[3L] / tip[1L], 1.5)        # growing
  expect_gt(tip[3L], 2 * aug[3L])
})

test_that("Stage 7 refuses the structured declarations it cannot honour", {
  skip_on_cran()
  N <- 5L; T <- 3L; q <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  set.seed(2)
  y <- as.numeric(stats::rbinom(N * T, 4L, 0.5))
  lev0 <- rep(seq_len(N) - 1L, each = T)
  call_it <- function(...) {
    .va_r3_validate_data(y, rep(4L, N * T), X, unit, trait, q, ...)
  }
  ok_Ainv <- Matrix::Diagonal(N)

  ## `structured = TRUE` alone carries no precision and stays refused.
  expect_error(call_it(structured = TRUE), "must be FALSE, or a list")
  ## A covariance passed where a precision belongs, detected by the diagonal.
  bad <- ok_Ainv
  Matrix::diag(bad) <- c(1, 1, 1, 1, -1)
  expect_error(
    call_it(structured = list(Ainv = bad),
            extra_tiers = list(list(kind = "dense", dim = 1L,
                                    level_id = lev0, structured = TRUE))),
    "strictly positive diagonal"
  )
  ## Asymmetric precision.
  asym <- as.matrix(ok_Ainv); asym[1, 2] <- 0.5
  expect_error(
    call_it(structured = list(Ainv = asym),
            extra_tiers = list(list(kind = "dense", dim = 1L,
                                    level_id = lev0, structured = TRUE))),
    "must be symmetric"
  )
  ## A precision with nothing to consume it -- the engine aborts on this too
  ## (R/fit-multi.R:3148), because the formula and the tree then disagree.
  expect_error(call_it(structured = list(Ainv = ok_Ainv)),
               "no tier declares")
  ## structured = TRUE with no precision on the call.
  expect_error(
    call_it(extra_tiers = list(list(kind = "dense", dim = 1L,
                                    level_id = lev0, structured = TRUE))),
    "no `structured` precision"
  )
  ## Level count must be nrow(Ainv), not the number of USED levels.
  expect_error(
    call_it(structured = list(Ainv = Matrix::Diagonal(N + 2L)),
            extra_tiers = list(list(kind = "dense", dim = 1L, n_levels = N,
                                    level_id = lev0, structured = TRUE))),
    "one level per row of Ainv"
  )
  ## Tier 1 is the ordinary latent tier and may never be structured. There is
  ## no call-site spelling that makes it so; the layout refuses directly.
  tiers <- .va_r3_build_tiers(lev0, N = N, T = T, q = q, n_obs = N * T)
  tiers[[1L]]$structured <- TRUE
  expect_error(.va_r3_tier_layout(tiers, T = T, N = N, q = q, n_obs = N * T),
               "must be unstructured")
  ## `provider`, `lv` and `missing` are UNTOUCHED by this stage.
  expect_error(call_it(provider = list()), "no structured provider")
  expect_error(call_it(lv = TRUE), "no structured provider")
  expect_error(call_it(missing = TRUE), "no structured provider")
})

test_that("a structured level index must be 0-based, not sniffed", {
  skip_on_cran()
  skip_if_not_installed("ape")
  ## The augmented precision orders internal nodes FIRST and tips LAST, so
  ## every tip's 0-based row index is >= 1: the usual 1-vs-0 sniff matches its
  ## 1-based arm and silently attaches every observation to the wrong node.
  ## That is a fit that runs and is wrong, so the sniff is switched off and a
  ## 1-based index is an error rather than a reinterpretation.
  set.seed(8)
  tree <- ape::rcoal(6L)
  s <- .va_r3_phylo_structure(tree, sort(tree$tip.label))
  N <- 6L; T <- 3L; q <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  set.seed(6)
  y <- as.numeric(stats::rbinom(N * T, 4L, 0.5))
  one_based <- s$node_of_species[unit] + 1L
  expect_true(all(one_based >= 1L & one_based <= s$n_aug))  # the trap
  expect_error(
    .va_r3_validate_data(y, rep(4L, N * T), X, unit, trait, q,
                         structured = s$structured,
                         extra_tiers = list(list(kind = "dense", dim = 1L,
                                                 level_id = one_based,
                                                 structured = TRUE))),
    "must be 0-based"
  )
})

test_that("a structured phylogenetic tier fits and is reported as structured", {
  skip_on_cran()
  skip_if_not_installed("ape")
  ## Not an oracle -- a liveness check. The tier has to survive an actual
  ## optimisation, including the internal nodes that no observation touches.
  set.seed(17)
  n_tip <- 24L; T <- 4L; q <- 1L
  tree <- ape::rcoal(n_tip)
  levels_sp <- sort(tree$tip.label)
  s <- .va_r3_phylo_structure(tree, levels_sp)
  unit <- rep(seq_len(n_tip), each = T)
  trait <- rep(seq_len(T), n_tip)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  y <- stats::rnorm(n_tip * T, mean = rep(c(-0.4, 0, 0.4, 0.2), n_tip), sd = 0.7)
  fit <- .va_r3_fit(
    y = y, n_trials = rep(1L, n_tip * T), X = X, unit_id = unit,
    trait_id = trait, q = q, family = "gaussian_anchor", link = "identity",
    structured = s$structured,
    extra_tiers = list(list(kind = "dense", dim = 1L,
                            level_id = s$node_of_species[unit],
                            structured = TRUE, label = "phylo")),
    H = 15L, n_starts = 1L, optimizer = "nlminb"
  )
  expect_identical(fit$tiers$structured, c(FALSE, TRUE))
  expect_identical(fit$tiers$n_levels[2L], s$n_aug)
  expect_identical(fit$structured$n_levels, s$n_aug)
  expect_true(is.finite(fit$best$objective))
  expect_lt(fit$best$max_abs_gradient, 1e-4)
  ## n_starts = 1 deliberately bypasses the three-start agreement gate, so the
  ## honest status is failed_health_gate, not healthy (see Stage 6's test).
  expect_identical(fit$status, "failed_health_gate")
  ## The tier costs what the AUGMENTED node count says, not the species count.
  expect_identical(fit$tiers$total_variational,
                   as.integer(n_tip * (2L * q + q * (q - 1L) / 2L) +
                                s$n_aug * (2L * 1L + 0L)))
})

test_that("Stage 7 does NOT open the public route to a structured VA fit", {
  skip_on_cran()
  ## The prototype admits a structured tier. The public integration fence does
  ## not, and this stage did not touch it: there is no VA recovery evidence for
  ## a phylogenetic model, and the fence is where that evidence gate lives.
  skip_if_not_installed("ape")
  set.seed(4L)
  n_site <- 120L; p <- 6L
  tree <- ape::rcoal(n_site)
  df <- expand.grid(trait = factor(seq_len(p)),
                    site = factor(tree$tip.label))
  df$y <- stats::rbinom(nrow(df), 1L, 0.5)
  ## A phylogenetic term is refused by R/va-routing.R BEFORE the engine is
  ## reached -- the message is the "would be dropped rather than fitted" one --
  ## and Stage 7 did not touch that file. Behavioural, not a grep: a grep would
  ## keep passing if the refusal were bypassed by a different code path.
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE) +
        phylo_latent(0 + trait | site, d = 1L, unique = FALSE),
      data = df, family = stats::binomial(), unit = "site",
      phylo_tree = tree,
      control = gllvmTMBcontrol(integration = "va")
    ),
    "variational"
  )
  ## And the regime string the adapter advertises names the SPDE exclusion
  ## explicitly rather than claiming structured priors wholesale.
  regime <- .approximation_engine_regime("va_r3")
  expect_match(regime$covariance, "structured prior")
  expect_match(regime$covariance, "no SPDE")
})
