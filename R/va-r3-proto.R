## Research-only Gaussian variational approximation prototype (Design 85).
##
## This file deliberately contains no roxygen export tags and creates no
## gllvmTMB class.  The objective is a quadrature-evaluated ELBO, not a
## marginal likelihood.  It is kept separate from fit_multi() and the shipped
## gllvmTMB TMB template so that the R3 falsification experiment cannot become
## an accidental user-facing fitting route.

.va_r3_theta_length <- function(T, q) {
  T <- as.integer(T)
  q <- as.integer(q)
  as.integer(T * q - q * (q - 1L) / 2L)
}

.va_r3_L_off_length <- function(N, q) {
  as.integer(N * q * (q - 1L) / 2L)
}

.va_r3_best_three_range <- function(objectives) {
  objectives <- sort(as.numeric(objectives))
  if (length(objectives) < 3L || any(!is.finite(objectives))) return(Inf)
  min(vapply(seq_len(length(objectives) - 2L), function(i) {
    objectives[i + 2L] - objectives[i]
  }, numeric(1)))
}

.va_r3_unpack_theta_rr <- function(theta_rr, T, q) {
  T <- as.integer(T)
  q <- as.integer(q)
  expected <- .va_r3_theta_length(T, q)
  if (!is.numeric(theta_rr) || length(theta_rr) != expected ||
      any(!is.finite(theta_rr))) {
    stop("theta_rr must be a finite numeric vector of length ", expected,
         ".", call. = FALSE)
  }
  Lambda <- matrix(0, nrow = T, ncol = q)
  Lambda[cbind(seq_len(q), seq_len(q))] <- theta_rr[seq_len(q)]
  cursor <- q + 1L
  for (j in seq_len(q)) {
    if (j < T) {
      rows <- seq.int(j + 1L, T)
      take <- length(rows)
      Lambda[rows, j] <- theta_rr[cursor:(cursor + take - 1L)]
      cursor <- cursor + take
    }
  }
  Lambda
}

.va_r3_pack_theta_rr <- function(Lambda, q = ncol(Lambda)) {
  if (!is.matrix(Lambda) || !is.numeric(Lambda) || any(!is.finite(Lambda))) {
    stop("Lambda must be a finite numeric matrix.", call. = FALSE)
  }
  T <- nrow(Lambda)
  q <- as.integer(q)
  if (q < 1L || q > T || ncol(Lambda) != q) {
    stop("Lambda must have T rows and q columns with 1 <= q <= T.",
         call. = FALSE)
  }
  upper <- row(Lambda) < col(Lambda)
  if (any(Lambda[upper] != 0)) {
    stop("Lambda's strict upper triangle must be exactly zero.",
         call. = FALSE)
  }
  out <- diag(Lambda)[seq_len(q)]
  for (j in seq_len(q)) {
    if (j < T) out <- c(out, Lambda[seq.int(j + 1L, T), j])
  }
  unname(out)
}

.va_r3_unpack_variational_chol <- function(log_L_diag, L_off, N, q) {
  N <- as.integer(N)
  q <- as.integer(q)
  if (!is.numeric(log_L_diag) || length(log_L_diag) != N * q ||
      any(!is.finite(log_L_diag))) {
    stop("log_L_diag must contain N*q finite entries.", call. = FALSE)
  }
  expected_off <- .va_r3_L_off_length(N, q)
  if (!is.numeric(L_off) || length(L_off) != expected_off ||
      any(!is.finite(L_off))) {
    stop("L_off has the wrong length or contains non-finite entries.",
         call. = FALSE)
  }
  ans <- array(0, dim = c(q, q, N))
  diag_values <- matrix(exp(log_L_diag), nrow = N, ncol = q)
  off_matrix <- matrix(L_off, nrow = N,
                       ncol = q * (q - 1L) / 2L)
  for (i in seq_len(N)) {
    ans[, , i][cbind(seq_len(q), seq_len(q))] <- diag_values[i, ]
    off_pos <- 1L
    for (j in seq_len(q)) {
      if (j < q) {
        rows <- seq.int(j + 1L, q)
        take <- seq.int(off_pos, length.out = length(rows))
        ans[rows, j, i] <- off_matrix[i, take]
        off_pos <- off_pos + length(rows)
      }
    }
  }
  ans
}

## The admitted set was c(15, 25, 61) and the default is 61. Nothing in the rule
## itself requires that: the nodes are built by Golub--Welsch at runtime below, so
## any odd H >= 3 is mathematically fine, and the whitelist was a typo-guard rather
## than a numerical constraint. It was blocking the one measurement that matters for
## GH's cost, because GH is ~75% of fit time (dev/va-speed/08-eval-cost-log.txt) and
## the quadrature loop is LINEAR in H (a single 1-D loop over eta in the template,
## not a tensor product over q), so H is a direct throttle on the dominant cost.
##
## Small orders are admitted here so the accuracy/cost curve can be MEASURED. There
## is a prior, adjacent finding that they may suffice: dev/aghq-scope-cost.md records
## a 7-vs-9-node difference below 1e-4 and concludes "H=7 is already converged" --
## but that is the AGHQ arc, a different engine, so it is a lead, NOT evidence for
## this tier. What makes it plausible here is that this rule's nodes are placed at
## mu +/- sqrt(2v) * z, i.e. adapted to the variational mean and SD, which is the
## regime where Gauss-Hermite converges fastest.
##
## Admitting an order is NOT endorsing it. The default stays 61 until a ladder on
## shared cells shows a smaller order matches it on trace / eta_var / rel_frob.
.va_r3_gh_rule <- function(H = 7L) {
  H <- as.integer(H)
  if (length(H) != 1L || is.na(H) || H < 3L || H %% 2L == 0L) {
    stop("The R3 quadrature order must be a single odd integer H >= 3 ",
         "(previously restricted to 15, 25, or 61; widened so the ",
         "accuracy/cost curve can be measured). Odd orders keep a node at the ",
         "variational mean.", call. = FALSE)
  }
  ## Golub--Welsch for the physicists' Hermite weight exp(-x^2).
  J <- matrix(0, H, H)
  if (H > 1L) {
    off <- sqrt(seq_len(H - 1L) / 2)
    J[cbind(seq_len(H - 1L), 2:H)] <- off
    J[cbind(2:H, seq_len(H - 1L))] <- off
  }
  ee <- eigen(J, symmetric = TRUE)
  ord <- order(ee$values)
  nodes <- unname(ee$values[ord])
  ## The first-eigenvector formula loses the extreme H=61 weights to exact
  ## zero in base eigen().  Evaluate the equivalent physicists' Hermite
  ## polynomial formula instead; at the admitted orders it remains finite.
  hm2 <- rep(1, H)
  hm1 <- 2 * nodes
  if (H > 2L) {
    for (k in 2:(H - 1L)) {
      hk <- 2 * nodes * hm1 - 2 * (k - 1) * hm2
      hm2 <- hm1
      hm1 <- hk
    }
  }
  weights <- 2^(H - 1L) * gamma(H + 1) * sqrt(pi) / (H^2 * hm1^2)
  weights <- weights * sqrt(pi) / sum(weights)
  list(
    nodes = nodes,
    weights = unname(weights),
    order = H,
    convention = "physicists"
  )
}

## `zero_based = TRUE` switches off the 1-vs-0 sniffing, and that is not a
## convenience -- it is a correctness requirement for structured tiers.
##
## The augmented Hadfield precision orders nodes internal-FIRST, tips LAST
## (R/phylo-tree-precision.R), so every tip's 0-based row index is >= 1 and
## <= n_aug - 1. Both arms of the sniff below then match, the 1-based arm wins,
## and every observation is silently attached to the WRONG augmented node --
## a fit that runs and is wrong, which is the exact failure mode this stage is
## most exposed to. Structured callers must therefore say which base they mean.
.va_r3_normalise_index <- function(x, size, name, zero_based = FALSE) {
  if (!is.numeric(x) || any(!is.finite(x)) || any(x != as.integer(x))) {
    stop(name, " must contain finite integer indices.", call. = FALSE)
  }
  x <- as.integer(x)
  if (isTRUE(zero_based)) {
    if (all(x >= 0L & x < size)) return(x)
    stop(name, " must be 0-based indices in 0..", size - 1L,
         " (a structured tier indexes rows of Ainv, which are NOT sniffable ",
         "for base because internal nodes come first).", call. = FALSE)
  }
  if (all(x >= 1L & x <= size)) return(x - 1L)
  if (all(x >= 0L & x < size)) return(x)
  stop(name, " must use either 1..", size, " or 0..", size - 1L,
       " consistently.", call. = FALSE)
}

## Fail-closed separation guard for the binomial-logit branch.
##
## Design 85's Gate 2 and Gate 3 both presuppose "non-separated" fixtures, but
## no code enforced that.  At n_trials = 1 the responses are pure 0/1, which is
## exactly where a separated fixed-effect design drives beta -- and therefore
## the ELBO's optimum -- to infinity while every finite-precision health check
## still reports success.
##
## Scope, stated honestly: this is a detector on the MARGINAL logistic
## regression y ~ X - 1 alone.  It is a sound refusal for complete and
## quasi-complete separation induced by the fixed-effect design (the case the
## Design-85 fixtures can actually produce), and it makes no claim at all about
## the joint (beta, Lambda, m, L) surface.  It is deliberately conservative:
## an extreme but genuinely finite design can trip it, and a refusal is the
## intended outcome in that case.
## Detection is by DIVERGENCE, not by a bare magnitude threshold: the marginal
## IRLS is run twice, once loosely and once four orders tighter.  A finite MLE
## lands on the same coordinate both times; a separated one keeps walking
## outward, because where it stops is set by the tolerance rather than by the
## data.  `eta_limit` is only a backstop for a design that diverges so fast
## both runs stall at the same place.
.va_r3_check_separation <- function(y, n_trials, X, eta_limit = 15,
                                    drift_limit = 1) {
  n <- as.numeric(n_trials)
  proportion <- as.numeric(y) / n
  marginal_eta <- function(maxit, epsilon) {
    fit <- tryCatch(
      suppressWarnings(stats::glm.fit(
        x = X, y = proportion, weights = n, family = stats::binomial(),
        control = stats::glm.control(maxit = maxit, epsilon = epsilon)
      )),
      error = function(e) NULL
    )
    if (is.null(fit) || !all(is.finite(fit$coefficients))) return(NULL)
    list(max_abs_eta = max(abs(drop(X %*% fit$coefficients))),
         converged = isTRUE(fit$converged))
  }
  loose <- marginal_eta(25L, 1e-8)
  tight <- marginal_eta(200L, 1e-12)
  if (is.null(loose) || is.null(tight)) {
    stop("Binomial R3 refuses this design: the marginal logistic regression ",
         "y ~ X - 1 has no finite fit, which indicates separation. Design 85 ",
         "admits only non-separated fixtures.", call. = FALSE)
  }
  drift <- tight$max_abs_eta - loose$max_abs_eta
  if (drift > drift_limit || tight$max_abs_eta > eta_limit) {
    stop("Binomial R3 refuses this design as separated: the marginal logistic ",
         "regression y ~ X - 1 gives max|eta| = ",
         format(loose$max_abs_eta, digits = 6), " at tolerance 1e-8 and ",
         format(tight$max_abs_eta, digits = 6), " at tolerance 1e-12 (drift ",
         format(drift, digits = 6), ", drift limit ", drift_limit,
         ", magnitude limit ", eta_limit,
         "). A coefficient that moves with the tolerance has no finite ",
         "maximum-likelihood value. Design 85 admits only non-separated ",
         "fixtures; this guard reads the marginal design only and is ",
         "deliberately conservative.", call. = FALSE)
  }
  invisible(list(max_abs_eta = tight$max_abs_eta, drift = drift,
                 eta_limit = eta_limit, drift_limit = drift_limit,
                 converged = tight$converged))
}

.va_r3_family_name_to_code <- function(name) {
  switch(as.character(name),
    gaussian_anchor = 0L,
    gaussian = 0L,
    binomial = 1L,
    poisson = 2L,
    lognormal = 3L, gamma = 4L, nbinom2 = 5L, tweedie = 6L,
    beta = 7L, betabinomial = 8L, student = 9L,
    truncated_poisson = 10L, truncated_nbinom2 = 11L,
    delta_lognormal = 12L, delta_gamma = 13L,
    ordinal_probit = 14L, nbinom1 = 15L,
    binomial_probit = 1L, binomial_cloglog = 1L,
    stop("R3 family must be one of the Laplace-aligned scalar families 0:15.",
         call. = FALSE)
  )
}

## Laplace (family_id, link_id) -> VA-R3 family code. Design 110 deliberately
## makes this the identity for scalar families; the function remains as a
## validation boundary for callers that previously used the VA-only enum.
##
## LINK-AWARE, and that is load-bearing rather than tidy. Laplace encodes
## binomial-logit and binomial-PROBIT with the SAME family_id (1), separated
## only by link_id (0 = logit, 1 = probit; R/fit-multi.R:371-374). A link-blind
## map sends both to VA code 1, whose template branch hard-codes the logistic
## softplus -- i.e. it would fit a LOGIT model to PROBIT data and report the fit
## healthy, with no error anywhere in the stack. `lid` is therefore REQUIRED
## with no default: a default would let a caller re-open that trap by omission.
.va_r3_laplace_id_to_code <- function(fid, lid) {
  fid <- as.integer(fid)
  lid <- as.integer(lid)
  if (length(lid) == 1L) lid <- rep.int(lid, length(fid))
  if (length(lid) != length(fid)) {
    stop("family_id and link_id must have the same length.", call. = FALSE)
  }
  ok <- fid %in% 0:15 & lid %in% 0:2 & (fid == 1L | lid == 0L)
  if (any(!ok)) {
    bad <- unique(paste0("(", fid[!ok], ", ", lid[!ok], ")"))
    stop("VA-R3 does not admit Laplace (family_id, link_id) pairs: ",
         paste(bad, collapse = ", "), ".", call. = FALSE)
  }
  as.integer(fid)
}

.va_r3_code_to_name <- function(code) {
  c("gaussian_anchor", "binomial", "poisson", "lognormal", "gamma",
    "nbinom2", "tweedie", "beta", "betabinomial", "student",
    "truncated_poisson", "truncated_nbinom2", "delta_lognormal",
    "delta_gamma", "ordinal_probit", "nbinom1")[as.integer(code) + 1L]
}

## Per-tier structural contract for the VA-R3 engine (Design 108 Gate A
## Stage 6; Design 106 s1).
##
## Every tier gllvmTMB has is one instance of `a_{k,o}' u_{k, g_k(o)}`
## (Design 106 s0's table), so the engine needs only the LOADING SHAPE, and
## there are exactly two of those. They are separate registry rows -- and
## separate code paths in the template -- because they cost different numbers
## of variational parameters per level, and the difference is a theorem rather
## than a tuning choice:
##
##   dense     : the loading spans the whole level block, so the variational
##               block must be a full d x d Cholesky.
##   diagonal  : the loading is sd_j * e_j, so each observation touches ONE
##               coordinate. Design 106 Proposition 2 (Fischer's inequality)
##               says the optimal q is then block diagonal EXACTLY. Restricting
##               to it loses nothing and saves T(T+1)/2 - T numbers per level:
##               2T instead of T + T(T+1)/2, i.e. 52 instead of 377 at T = 26.
##
## Running a diagonal tier through the dense path would still be CORRECT and
## would still converge -- which is precisely why the saving has to be
## structural. `off_per_level` is the field that makes it so.
##
## Fields
##   kind                  : R-side name
##   kind_code             : integer passed to the template as tier_kind
##   loading               : how a_{k,o} is formed
##   loading_par           : which parameter vector carries the loading
##   loading_length        : length that parameter contributes for this tier
##   variational_per_level : d_k + d_k + (off), i.e. means + log-diagonals + off
##   off_per_level         : strict-lower Cholesky entries per level
##   block_diagonal_exact  : whether Proposition 2 applies
.va_r3_tier_registry <- list(
  list(
    kind = "dense",
    kind_code = 0L,
    loading = "Lambda_k(trait, .), packed lower-triangular T x d_k in theta_rr",
    loading_par = "theta_rr",
    loading_length = function(d, T) as.integer(T * d - d * (d - 1L) / 2L),
    variational_per_level = function(d, T) as.integer(2L * d + d * (d - 1L) / 2L),
    off_per_level = function(d, T) as.integer(d * (d - 1L) / 2L),
    block_diagonal_exact = FALSE,
    criterion = paste(
      "Proposition 2 (i) FAILS -- lambda_j has all d_k entries non-zero, so",
      "an observation's loading spans the whole level block. A diagonal q",
      "here is a real restriction, not a free one (Design 106 s1.4, row 2)."
    )
  ),
  list(
    kind = "diagonal",
    kind_code = 1L,
    loading = "sd_{k,j} * e_j, from T per-trait log SDs in log_sd_tier",
    loading_par = "log_sd_tier",
    loading_length = function(d, T) as.integer(T),
    variational_per_level = function(d, T) as.integer(2L * d),
    off_per_level = function(d, T) 0L,
    block_diagonal_exact = TRUE,
    criterion = paste(
      "Proposition 2 applies EXACTLY -- each observation loads on one trait's",
      "field and the prior is trait-independent, so Fischer's inequality makes",
      "the trait-diagonal q optimal. 2T per level rather than T + T(T+1)/2, at",
      "no accuracy cost (Design 106 s1.4 row 1, s4.2)."
    )
  )
)

.va_r3_tier_entry <- function(kind) {
  for (entry in .va_r3_tier_registry) {
    if (identical(entry$kind, kind)) return(entry)
  }
  stop("VA-R3 has no tier-registry entry for kind \"", kind, "\".",
       call. = FALSE)
}

## The shared structured precision (Design 108 Gate A Stage 7; Design 106 s3).
##
## `structured` is FALSE, or a list carrying `Ainv` -- the PRECISION, never the
## covariance. Exactly one precision is admitted per fit and every structured
## tier uses it. That mirrors the shipped Laplace engine, where phylo_rr,
## phylo_diag and phylo_slope all read the single `Ainv_phy_rr` /
## `log_det_A_phy_rr` pair, and it is what `phylo_latent(unique = TRUE)` needs:
## a structured low-rank tier plus a structured diagonal Psi tier over the SAME
## tree. Two different trees in one fit are out of scope for this stage.
##
## `log_det_A` follows the engine's sign convention EXACTLY
## (R/fit-multi.R:3174, 3226): log det A = -log det(A^{-1}). Supply it to skip
## the determinant, which is the right move for a large sparse precision whose
## log-determinant the builder already knows.
.va_r3_structured_precision <- function(structured) {
  if (is.null(structured) || identical(structured, FALSE)) return(NULL)
  if (!is.list(structured) || is.null(structured$Ainv)) {
    stop("`structured` must be FALSE, or a list carrying `Ainv` (the shared ",
         "structured PRECISION). VA-R3 never sees the covariance.",
         call. = FALSE)
  }
  Ainv <- structured$Ainv
  if (!(is.matrix(Ainv) || methods::is(Ainv, "Matrix"))) {
    stop("`structured$Ainv` must be a matrix or a Matrix.", call. = FALSE)
  }
  if (nrow(Ainv) != ncol(Ainv) || nrow(Ainv) < 1L) {
    stop("`structured$Ainv` must be square and non-empty.", call. = FALSE)
  }
  sparse <- methods::as(Matrix::Matrix(Ainv, sparse = TRUE), "CsparseMatrix")
  if (!methods::is(sparse, "generalMatrix")) {
    sparse <- methods::as(sparse, "generalMatrix")
  }
  if (any(!is.finite(sparse@x))) {
    stop("`structured$Ainv` must be finite.", call. = FALSE)
  }
  asymmetry <- max(abs(sparse - Matrix::t(sparse)))
  scale_ainv <- max(abs(sparse@x), 1)
  if (!is.finite(asymmetry) || asymmetry > 1e-8 * scale_ainv) {
    stop("`structured$Ainv` must be symmetric (max asymmetry ",
         format(asymmetry, digits = 3), ").", call. = FALSE)
  }
  diag_Ainv <- as.numeric(Matrix::diag(sparse))
  if (any(!is.finite(diag_Ainv)) || any(diag_Ainv <= 0)) {
    stop("`structured$Ainv` must have a strictly positive diagonal; a ",
         "non-positive entry means a covariance, a sign flip, or a ",
         "mis-aligned matrix was supplied.", call. = FALSE)
  }
  log_det_A <- structured$log_det_A
  if (is.null(log_det_A)) {
    det_ainv <- tryCatch(Matrix::determinant(sparse, logarithm = TRUE),
                         error = function(e) NULL)
    if (is.null(det_ainv) || !identical(as.numeric(det_ainv$sign), 1)) {
      stop("`structured$Ainv` has no usable log-determinant; supply ",
           "`structured$log_det_A` (= log det A = -log det Ainv) directly.",
           call. = FALSE)
    }
    log_det_A <- -as.numeric(det_ainv$modulus)
  }
  log_det_A <- as.numeric(log_det_A)
  if (length(log_det_A) != 1L || !is.finite(log_det_A)) {
    stop("`structured$log_det_A` must be one finite number.", call. = FALSE)
  }
  list(Ainv = sparse, diag_Ainv = diag_Ainv, log_det_A = log_det_A,
       n_levels = as.integer(nrow(sparse)),
       rownames = rownames(sparse))
}

## Build the shared structured precision from a tree, using the SAME builder,
## the same `correlation = TRUE` scaling and the same node ordering the shipped
## Laplace engine uses (R/fit-multi.R:3172-3182). Going through this helper is
## how a caller inherits the engine's convention instead of re-deriving it --
## including the augmented node set, which is tips PLUS internal nodes minus
## the root, so `n_aug` is read off `nrow(Ainv)` and never computed as 2N-1.
##
## Returns the `structured` list the validator wants, plus the species -> node
## map (0-based) that a structured tier's `level_id` must be built from.
.va_r3_phylo_structure <- function(tree, species_levels) {
  if (!inherits(tree, "phylo")) {
    stop("`tree` must be an ape::phylo tree.", call. = FALSE)
  }
  prec <- .gllvm_phylo_tree_precision(tree, correlation = TRUE)
  Ainv <- prec$precision
  node_of_species <- match(as.character(species_levels), rownames(Ainv))
  if (anyNA(node_of_species)) {
    stop("Species levels absent from the tree: ",
         paste(utils::head(species_levels[is.na(node_of_species)], 5L),
               collapse = ", "), ".", call. = FALSE)
  }
  list(
    structured = list(Ainv = Ainv, log_det_A = -prec$log_det_precision),
    n_aug = as.integer(nrow(Ainv)),
    n_tips = length(prec$tip_label),
    node_of_species = as.integer(node_of_species - 1L)
  )
}

## Assemble the tier list. Tier 0 is ALWAYS the ordinary latent tier, built
## here rather than accepted from the caller, so the "tier 0 is dense, has
## dimension q, has N levels, and its level index is unit_id" invariant the
## template checks cannot be violated by a call site. Everything else is an
## EXTRA tier appended after it.
##
## `want_psi` is what `latent(..., unique = TRUE)` means: the paired diagonal
## Psi companion at the same grouping factor (CLAUDE.md's standing grammar
## note; Design 106 s4.2's third tier).
.va_r3_build_tiers <- function(unit_id0, N, T, q, n_obs, extra_tiers = NULL,
                               want_psi = FALSE, structured = NULL) {
  tiers <- list(list(
    kind = "dense", dim = as.integer(q), n_levels = as.integer(N),
    level_id = as.integer(unit_id0), label = "latent", structured = FALSE
  ))
  if (isTRUE(want_psi)) {
    tiers[[length(tiers) + 1L]] <- list(
      kind = "diagonal", dim = as.integer(T), n_levels = as.integer(N),
      level_id = as.integer(unit_id0), label = "psi", structured = FALSE
    )
  }
  if (is.null(extra_tiers)) return(tiers)
  if (!is.list(extra_tiers) || !length(extra_tiers)) {
    stop("extra_tiers must be a non-empty list of tier specifications.",
         call. = FALSE)
  }
  for (idx in seq_along(extra_tiers)) {
    spec <- extra_tiers[[idx]]
    where <- paste0("extra_tiers[[", idx, "]]")
    if (!is.list(spec) || is.null(spec$kind) || is.null(spec$level_id)) {
      stop(where, " must be a list with at least `kind` and `level_id`.",
           call. = FALSE)
    }
    entry <- .va_r3_tier_entry(as.character(spec$kind))
    want_struct <- isTRUE(spec$structured)
    if (want_struct && is.null(structured)) {
      stop(where, ": structured = TRUE, but the fit was given no `structured` ",
           "precision to attach it to.", call. = FALSE)
    }
    dim_k <- if (is.null(spec$dim)) {
      if (identical(entry$kind, "diagonal")) T else q
    } else as.integer(spec$dim)
    if (identical(entry$kind, "diagonal") && !identical(dim_k, as.integer(T))) {
      stop(where, ": a trait-diagonal tier has one field per trait, so dim must be T.",
           call. = FALSE)
    }
    if (dim_k < 1L || dim_k > T) {
      stop(where, ": dim must satisfy 1 <= dim <= T.", call. = FALSE)
    }
    if (length(spec$level_id) != n_obs) {
      stop(where, ": level_id must have one entry per response row.",
           call. = FALSE)
    }
    n_levels <- if (!is.null(spec$n_levels)) {
      as.integer(spec$n_levels)
    } else if (want_struct) {
      ## Read the node count off the matrix. This is the whole reason no
      ## `2 * N - 1` appears anywhere: polytomies, unrooted input and any other
      ## non-bifurcating tree are handled by construction.
      structured$n_levels
    } else {
      length(unique(spec$level_id))
    }
    if (length(n_levels) != 1L || is.na(n_levels) || n_levels < 1L) {
      stop(where, ": n_levels must be a positive integer.", call. = FALSE)
    }
    lv <- .va_r3_normalise_index(spec$level_id, n_levels,
                                 paste0(where, "$level_id"),
                                 zero_based = want_struct)
    if (want_struct) {
      if (!identical(as.integer(n_levels), structured$n_levels)) {
        stop(where, ": a structured tier has one level per row of Ainv (",
             structured$n_levels, "), not ", n_levels, ".", call. = FALSE)
      }
      ## Deliberately NO "every level is used" check here, and the difference
      ## is structural rather than lenient: in the augmented Hadfield
      ## representation the INTERNAL nodes carry no observation at all, by
      ## construction. They are not unused -- they are the conditionally
      ## independent innovations that make Ainv sparse, and the prior informs
      ## every one of them through Ainv's off-diagonals.
    } else if (!identical(sort(unique(lv)), 0:(n_levels - 1L))) {
      ## An unused level would carry a free variational block that no
      ## observation informs. Its optimum is the prior, so it costs nothing in
      ## the objective and everything in diagnosability -- refuse it loudly
      ## rather than let a mis-sized n_levels pass as a converged fit.
      stop(where, ": every one of the ", n_levels,
           " declared levels must be used by at least one row.", call. = FALSE)
    }
    tiers[[length(tiers) + 1L]] <- list(
      kind = entry$kind, dim = dim_k, n_levels = n_levels, level_id = lv,
      label = if (is.null(spec$label)) paste0("tier", idx) else as.character(spec$label),
      structured = want_struct
    )
  }
  tiers
}

## Flat-layout offsets for the ragged tier structure.
##
## Packing decision (Design 108 Stage 6): the variational block is ONE flat
## vector per role -- m, log_L_diag, L_off -- sliced by offsets computed from
## (tier_kind, tier_dim, tier_n_levels), rather than a fixed cap of named
## per-tier parameter slots. A cap would bound K and would be silently wrong
## at K+1; offsets are unbounded, and the template recomputes them from the
## same three vectors so a disagreement fails a length check instead of
## reading across a tier boundary.
##
## Within a tier the order is column-major over (coordinate, level) --
## coordinate slowest, level fastest -- which is exactly as.vector() of the
## pre-Stage-6 N x q matrices. So at K = 1 the flat vector is the old matrix,
## element for element, and obj$par is byte-identical.
.va_r3_tier_layout <- function(tiers, T, N, q, n_obs) {
  K <- length(tiers)
  if (!K) stop("A VA-R3 model needs at least one tier.", call. = FALSE)
  kind <- vapply(tiers, `[[`, character(1L), "kind")
  kind_code <- vapply(kind, function(k) .va_r3_tier_entry(k)$kind_code,
                      integer(1L), USE.NAMES = FALSE)
  dim_k <- vapply(tiers, function(x) as.integer(x$dim), integer(1L))
  n_levels <- vapply(tiers, function(x) as.integer(x$n_levels), integer(1L))
  structured <- vapply(tiers, function(x) isTRUE(x$structured), logical(1L))
  if (!identical(kind_code[1L], 0L) || !identical(dim_k[1L], as.integer(q)) ||
      !identical(n_levels[1L], as.integer(N))) {
    stop("Tier 1 must be the dense ordinary latent tier with dim = q and n_levels = N.",
         call. = FALSE)
  }
  if (structured[1L]) {
    stop("Tier 1 is the ordinary latent tier and must be unstructured; a phylogenetic tier is an EXTRA tier.",
         call. = FALSE)
  }
  per_off <- integer(K)
  per_theta <- integer(K)
  per_sd <- integer(K)
  for (k in seq_len(K)) {
    entry <- .va_r3_tier_entry(kind[k])
    per_off[k] <- entry$off_per_level(dim_k[k], T)
    if (identical(entry$kind, "dense")) {
      per_theta[k] <- entry$loading_length(dim_k[k], T)
    } else {
      per_sd[k] <- entry$loading_length(dim_k[k], T)
    }
  }
  m_size <- n_levels * dim_k
  off_size <- n_levels * per_off
  level_id <- matrix(0L, nrow = n_obs, ncol = K)
  for (k in seq_len(K)) level_id[, k] <- as.integer(tiers[[k]]$level_id)
  storage.mode(level_id) <- "integer"
  list(
    n_tiers = K,
    kind = kind,
    kind_code = kind_code,
    dim = dim_k,
    n_levels = n_levels,
    structured = structured,
    structured_code = as.integer(structured),
    label = vapply(tiers, function(x) as.character(x$label), character(1L)),
    level_id = level_id,
    variational_per_level = 2L * dim_k + per_off,
    off_per_level = per_off,
    loading_length = per_theta + per_sd,
    m_offset = as.integer(cumsum(c(0L, m_size))[seq_len(K)]),
    off_offset = as.integer(cumsum(c(0L, off_size))[seq_len(K)]),
    theta_offset = as.integer(cumsum(c(0L, per_theta))[seq_len(K)]),
    sd_offset = as.integer(cumsum(c(0L, per_sd))[seq_len(K)]),
    level_offset = as.integer(cumsum(c(0L, n_levels))[seq_len(K)]),
    total_mean = as.integer(sum(m_size)),
    total_off = as.integer(sum(off_size)),
    total_theta = as.integer(sum(per_theta)),
    total_sd = as.integer(sum(per_sd)),
    total_levels = as.integer(sum(n_levels)),
    total_variational = as.integer(sum(n_levels * (2L * dim_k + per_off)))
  )
}

.va_r3_validate_data <- function(y, n_trials, X, unit_id, trait_id, q,
                                 N = NULL, T = NULL,
                                 family = "binomial", link = "logit",
                                 unique = FALSE, psi = FALSE,
                                 structured = FALSE, provider = NULL,
                                 lv = FALSE, missing = FALSE,
                                 gaussian_sd = 1,
                                 is_y_observed = NULL,
                                 family_codes = NULL,
                                 link_ids = NULL,
                                 estimate_gaussian_sd = TRUE,
                                 extra_tiers = NULL,
                                 n_ordinal_cuts_per_trait = NULL,
                                 ordinal_offset_per_trait = NULL,
                                 ordinal_log_increments_start = NULL) {
  link_was_missing <- missing(link)
  if (is.character(family) && length(family) == 1L &&
      family %in% c("binomial_probit", "binomial_cloglog")) {
    implied_link <- if (identical(family, "binomial_probit")) "probit" else "cloglog"
    if (!link_was_missing && !identical(as.character(link), implied_link)) {
      stop("family = \"", family, "\" requires link = \"", implied_link,
           "\".", call. = FALSE)
    }
    link <- implied_link
  }
  if (length(q) != 1L || !is.numeric(q) || !is.finite(q) ||
      q != as.integer(q) || q < 0L || q > 6L) {
    stop("q must be one integer in 0..6.", call. = FALSE)
  }
  q <- as.integer(q)
  if (!is.matrix(X) || !is.numeric(X) || nrow(X) != length(y) ||
      ncol(X) < 1L || any(!is.finite(X))) {
    stop("X must be a finite numeric matrix with one row per response and at least one column.",
         call. = FALSE)
  }
  if (length(unit_id) != length(y) || length(trait_id) != length(y) ||
      length(n_trials) != length(y)) {
    stop("y, n_trials, unit_id, trait_id, and the rows of X must have equal length.",
         call. = FALSE)
  }
  if (is.null(N)) N <- length(unique(unit_id))
  if (is.null(T)) T <- length(unique(trait_id))
  if (length(N) != 1L || length(T) != 1L || !is.finite(N) || !is.finite(T) ||
      N != as.integer(N) || T != as.integer(T) || N < 1L || T < 1L) {
    stop("N and T must be positive integers.", call. = FALSE)
  }
  N <- as.integer(N)
  T <- as.integer(T)
  if (q > T) stop("q must not exceed T.", call. = FALSE)

  if (is.null(is_y_observed)) {
    is_y_observed <- rep.int(1L, length(y))
  } else {
    is_y_observed <- as.integer(is_y_observed)
    if (length(is_y_observed) != length(y) ||
        any(!is_y_observed %in% c(0L, 1L))) {
      stop("is_y_observed must be length nrow(X) with entries in {0, 1}.",
           call. = FALSE)
    }
  }
  observed <- is_y_observed == 1L

  uid <- .va_r3_normalise_index(unit_id, N, "unit_id")
  tid <- .va_r3_normalise_index(trait_id, T, "trait_id")
  cell <- uid * T + tid
  ## Dense Design-107 convention: every unit-trait cell is still exactly one
  ## row; masked responses keep a sentinel y and is_y_observed == 0.
  if (length(y) != N * T || length(unique(cell)) != N * T ||
      !identical(sort(cell), 0:(N * T - 1L))) {
    stop("R3 requires exactly one dense row for every unit-trait cell.",
         call. = FALSE)
  }
  if (qr(X)$rank != ncol(X)) {
    stop("X must have full column rank.", call. = FALSE)
  }
  ## `missing = TRUE` still means mi()/predictor missingness (out of scope).
  ## Response masks travel only through is_y_observed (Design 107).
  ##
  ## Design 108 Gate A Stage 6 lifted the `unique` / `psi` half of this gate.
  ## Stage 7 lifts the `structured` clause, and NOTHING ELSE: a phylogenetic
  ## prior is not a different index, it is a different KL (Design 106 s3), and
  ## that KL is now implemented for a shared `Ainv`. `provider` (an external
  ## covariance provider), `lv` and `missing` stay CLOSED, unchanged.
  ##
  ## `structured = TRUE` on its own is still an error: a structured tier means
  ## nothing without the precision it is structured BY, so the admitted form is
  ## a list carrying `Ainv`.
  if (!is.null(provider) || !identical(lv, FALSE) ||
      !identical(missing, FALSE)) {
    stop("R3 admits no structured provider, lv, or missing-predictor marker.",
         call. = FALSE)
  }
  structured_spec <- .va_r3_structured_precision(structured)
  tier_flag <- function(x, name) {
    if (!is.logical(x) || length(x) != 1L || is.na(x)) {
      stop(name, " must be TRUE or FALSE.", call. = FALSE)
    }
    isTRUE(x)
  }
  ## `unique = TRUE` and `psi = TRUE` request the SAME thing -- the paired
  ## diagonal Psi companion of latent(..., unique = TRUE). They are two spellings
  ## of one tier, not two tiers.
  want_psi <- tier_flag(unique, "unique") || tier_flag(psi, "psi")

  n_obs <- length(y)
  tiers <- .va_r3_build_tiers(uid, N = N, T = T, q = q, n_obs = n_obs,
                              extra_tiers = extra_tiers, want_psi = want_psi,
                              structured = structured_spec)
  tier_layout <- .va_r3_tier_layout(tiers, T = T, N = N, q = q, n_obs = n_obs)
  ## A precision with no tier to consume it means the formula and the tree
  ## disagree about whether there is a phylogenetic term. The shipped engine
  ## aborts on exactly this (R/fit-multi.R:3148-3156) rather than silently
  ## fitting a "phylogenetic" model with no phylogeny in it.
  if (!is.null(structured_spec) && !any(tier_layout$structured)) {
    stop("`structured` supplied a precision, but no tier declares ",
         "structured = TRUE to use it.", call. = FALSE)
  }
  if (!is.null(family_codes)) {
    family_codes <- as.integer(family_codes)
    if (length(family_codes) != n_obs ||
        any(!family_codes %in% 0:15)) {
      stop("family_codes must be length nrow(X) with Laplace scalar ids 0:15.",
           call. = FALSE)
    }
  } else if (is.numeric(family) || is.integer(family)) {
    family_codes <- as.integer(family)
    if (length(family_codes) == 1L) {
      family_codes <- rep.int(family_codes, n_obs)
    }
    if (length(family_codes) != n_obs ||
        any(!family_codes %in% 0:15)) {
      stop("numeric family must be length 1 or nrow(X) with codes in 0:15.",
           call. = FALSE)
    }
  } else {
    fam_chr <- as.character(family)
    if (length(fam_chr) == 1L) {
      family_codes <- rep.int(.va_r3_family_name_to_code(fam_chr), n_obs)
    } else {
      if (length(fam_chr) != n_obs) {
        stop("character family must be length 1 or nrow(X).", call. = FALSE)
      }
      family_codes <- vapply(fam_chr, .va_r3_family_name_to_code, integer(1L),
                             USE.NAMES = FALSE)
    }
  }

  ## Design 110 carries the Laplace link id explicitly. Character `link` remains
  ## an ergonomic alias for hand-built prototype fixtures.
  if (is.null(link_ids)) {
    link_vec <- rep_len(as.character(link), n_obs)
    link_ids <- match(link_vec, c("logit", "probit", "cloglog")) - 1L
    nonbin <- family_codes != 1L
    canonical <- ifelse(family_codes %in% c(0L, 9L), "identity",
                        ifelse(family_codes %in% c(7L, 8L), "logit",
                               ifelse(family_codes == 14L, "probit", "log")))
    link_ids[nonbin] <- 0L
    link_vec[nonbin] <- canonical[nonbin]
  } else {
    link_ids <- as.integer(link_ids)
    if (length(link_ids) == 1L) link_ids <- rep.int(link_ids, n_obs)
    link_vec <- ifelse(family_codes == 1L,
                       c("logit", "probit", "cloglog")[link_ids + 1L],
                       ifelse(family_codes %in% c(0L, 9L), "identity",
                              ifelse(family_codes %in% c(7L, 8L), "logit",
                                     ifelse(family_codes == 14L, "probit", "log"))))
  }
  if (length(link_ids) != n_obs || anyNA(link_ids) || any(!link_ids %in% 0:2) ||
      any(family_codes != 1L & link_ids != 0L)) {
    stop("link_ids must be length nrow(X), use 0:2 for binomial, and 0 otherwise.",
         call. = FALSE)
  }

  if (!is.numeric(y) || any(!is.finite(y)) ||
      !is.numeric(n_trials) || any(!is.finite(n_trials))) {
    stop("R3 data require finite y and n_trials (sentinels allowed on masked rows).",
         call. = FALSE)
  }

  bin_obs <- observed & family_codes %in% c(1L, 8L)
  if (any(bin_obs) &&
      (any(y[bin_obs] != as.integer(y[bin_obs])) ||
       any(n_trials[bin_obs] != as.integer(n_trials[bin_obs])) ||
       any(n_trials[bin_obs] < 1L) ||
       any(y[bin_obs] < 0L) || any(y[bin_obs] > n_trials[bin_obs]))) {
    stop("Binomial R3 data require integer n_trials >= 1 and integer 0 <= y <= n_trials on observed rows.",
         call. = FALSE)
  }
  ## Design 85 separation guard is for pure-binomial designs. Mixed-family
  ## subsets leave trait-dummy columns all-zero on binomial rows and trip the
  ## guard spuriously; Stage 2 keeps the guard on the pure-binomial bit-compat
  ## path only.
  ##
  ## Design 108 Stage 4 extends it to binomial-PROBIT unchanged. Separation is a
  ## property of the DESIGN -- whether a hyperplane perfectly splits the 0/1
  ## responses -- not of the link, so the marginal-logistic detector is the same
  ## detector for probit data. If anything the refusal matters MORE there: the
  ## normal tail is thinner than the logistic one, so a separated probit
  ## likelihood flattens out faster.
  if (any(bin_obs) && all(family_codes[observed] == 1L)) {
    .va_r3_check_separation(y[bin_obs], n_trials[bin_obs], X[bin_obs, , drop = FALSE])
  }
  count_obs <- observed & family_codes %in% c(2L, 5L, 15L)
  if (any(count_obs) &&
      (any(y[count_obs] != as.integer(y[count_obs])) || any(y[count_obs] < 0L))) {
    stop("Count R3 data require finite non-negative integer y on observed rows.",
         call. = FALSE)
  }
  tweedie_obs <- observed & family_codes == 6L
  if (any(tweedie_obs) && any(y[tweedie_obs] < 0))
    stop("Tweedie R3 data require y >= 0.", call. = FALSE)
  delta_obs <- observed & family_codes %in% c(12L, 13L)
  if (any(delta_obs) && any(y[delta_obs] < 0))
    stop("Delta-family R3 data require y >= 0.", call. = FALSE)
  beta_obs <- observed & family_codes == 7L
  if (any(beta_obs) && any(y[beta_obs] <= 0 | y[beta_obs] >= 1))
    stop("Beta R3 data require 0 < y < 1.", call. = FALSE)
  positive_obs <- observed & family_codes %in% c(3L, 4L)
  if (any(positive_obs) && any(y[positive_obs] <= 0))
    stop("Lognormal and Gamma R3 data require y > 0.", call. = FALSE)
  trunc_obs <- observed & family_codes %in% c(10L, 11L)
  if (any(trunc_obs) && any(y[trunc_obs] < 1L | y[trunc_obs] != as.integer(y[trunc_obs])))
    stop("Zero-truncated count R3 data require positive integer y.", call. = FALSE)

  ## Ordinal packing follows the Laplace engine. If metadata are absent, infer K
  ## from the observed categories of each ordinal trait and start all spacings at
  ## one (log increment zero).
  if (is.null(n_ordinal_cuts_per_trait)) n_ordinal_cuts_per_trait <- integer(T)
  if (is.null(ordinal_offset_per_trait)) ordinal_offset_per_trait <- integer(T)
  n_ordinal_cuts_per_trait <- as.integer(n_ordinal_cuts_per_trait)
  ordinal_offset_per_trait <- as.integer(ordinal_offset_per_trait)
  if (length(n_ordinal_cuts_per_trait) != T || length(ordinal_offset_per_trait) != T)
    stop("ordinal metadata vectors must have length T.", call. = FALSE)
  ordinal_traits <- which(vapply(seq_len(T) - 1L, function(t)
    any(observed & tid == t & family_codes == 14L), logical(1L))) - 1L
  if (length(ordinal_traits) && all(n_ordinal_cuts_per_trait[ordinal_traits + 1L] == 0L)) {
    cursor <- 0L
    for (t in ordinal_traits) {
      rows <- observed & tid == t & family_codes == 14L
      K <- max(as.integer(y[rows]))
      if (K < 2L || any(y[rows] < 1L | y[rows] != as.integer(y[rows])))
        stop("ordinal_probit requires integer categories 1..K with K >= 2.", call. = FALSE)
      n_ordinal_cuts_per_trait[t + 1L] <- K - 2L
      ordinal_offset_per_trait[t + 1L] <- cursor
      cursor <- cursor + K - 2L
    }
  }
  n_ord <- sum(n_ordinal_cuts_per_trait)
  if (is.null(ordinal_log_increments_start)) ordinal_log_increments_start <- rep(0, n_ord)
  if (length(ordinal_log_increments_start) != n_ord || any(!is.finite(ordinal_log_increments_start)))
    stop("ordinal_log_increments_start must have sum(K_t - 2) finite entries.", call. = FALSE)

  ## Only binomial and beta-binomial use n_trials.
  n_trials <- as.integer(n_trials)
  n_trials[!(family_codes %in% c(1L, 8L))] <- 1L

  if (!is.numeric(gaussian_sd) || any(!is.finite(gaussian_sd)) ||
      any(gaussian_sd <= 0)) {
    stop("gaussian_sd must be positive and finite (scalar or length T start).",
         call. = FALSE)
  }
  if (length(gaussian_sd) == 1L) {
    log_sigma_start <- rep(log(as.numeric(gaussian_sd)), T)
  } else if (length(gaussian_sd) == T) {
    log_sigma_start <- log(as.numeric(gaussian_sd))
  } else {
    stop("gaussian_sd must be length 1 or T.", call. = FALSE)
  }

  uniq <- unique(family_codes)
  family_name <- if (length(uniq) == 1L) {
    if (uniq == 1L && length(unique(link_ids)) == 1L)
      c("binomial", "binomial_probit", "binomial_cloglog")[unique(link_ids) + 1L]
    else if (uniq == 1L) "mixed_binomial_links"
    else .va_r3_code_to_name(uniq)
  } else {
    "mixed"
  }

  list(
    y = as.numeric(y),
    n_trials = as.integer(n_trials),
    X = unname(X),
    unit_id = uid,
    trait_id = tid,
    is_y_observed = as.integer(is_y_observed),
    N = N,
    T = T,
    q = q,
    tiers = tiers,
    tier_layout = tier_layout,
    structured = structured_spec,
    unique = want_psi,
    family = as.integer(family_codes),
    link_id = as.integer(link_ids),
    family_name = family_name,
    link = if (length(unique(link_vec)) == 1L) link_vec[1L] else link_vec,
    n_ordinal_cuts_per_trait = n_ordinal_cuts_per_trait,
    ordinal_offset_per_trait = ordinal_offset_per_trait,
    ordinal_log_increments_start = as.numeric(ordinal_log_increments_start),
    log_sigma_start = as.numeric(log_sigma_start),
    ## Design 108 default is estimated per-trait SD; oracle / variance-domain
    ## fixtures may pin log_sigma at the start value (pre-Stage-2 DATA_SCALAR).
    estimate_gaussian_sd = isTRUE(estimate_gaussian_sd)
  )
}

.va_r3_find_source <- function(source = NULL) {
  if (!is.null(source)) {
    source <- normalizePath(source, mustWork = TRUE)
    return(source)
  }
  installed <- system.file("tmb", "gllvmTMB_va_r3.cpp", package = "gllvmTMB")
  if (nzchar(installed) && file.exists(installed)) return(installed)
  path <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    candidate <- file.path(path, "inst", "tmb", "gllvmTMB_va_r3.cpp")
    if (file.exists(candidate)) return(normalizePath(candidate, mustWork = TRUE))
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  stop("Cannot find inst/tmb/gllvmTMB_va_r3.cpp; supply `source` explicitly.",
       call. = FALSE)
}

## `framework` and `supernodal` are forwarded to TMB::compile() rather than smuggled through
## `compile_flags`. That distinction is load-bearing: passing "-DTMBAD_FRAMEWORK" as a raw flag
## BYPASSES TMB's own framework plumbing and fails to compile with a wall of redefinition errors
## (`EvalADFunObjectTemplate` redefined, `start_parallel.hpp` expecting CppAD's Forward/Reverse/
## Hessian). Measured 2026-08-03 -- the flag route is not a slower path, it is a broken one.
##
## Both default to NULL, which reproduces the previous behaviour exactly: TMB::compile()'s own
## defaults are `framework = getOption("tmb.ad.framework")` and `supernodal = FALSE`. Nothing
## changes for an existing caller; this only makes the two knobs REACHABLE, which the engine
## knob audit (dev/va-speed/53-ENGINE-KNOB-AUDIT.md) found they were not -- the shipped Laplace
## DLL sets its framework in `src/Makevars` while this runtime-compiled template had no way to
## express one at all.
.va_r3_load_dll <- function(source = NULL, rebuild = FALSE,
                            compile_flags = "-O2",
                            framework = NULL, supernodal = NULL) {
  if (!requireNamespace("TMB", quietly = TRUE)) {
    stop("The research prototype requires TMB.", call. = FALSE)
  }
  source <- .va_r3_find_source(source)
  stamp <- unname(tools::md5sum(source))
  ## Campaign workers may share one PRECOMPILED standalone template. Without
  ## this opt-in path every process builds under its private tempdir, so a
  ## 100-worker Totoro launch would compile the same source 100 times. The
  ## default remains process-local; the environment override changes only the
  ## build/cache location and the checksum suffix still binds it to the source.
  shared_root <- Sys.getenv("GLLVMTMB_VA_R3_BUILD_ROOT", unset = "")
  build_root <- if (nzchar(shared_root)) {
    normalizePath(shared_root, mustWork = FALSE)
  } else {
    tempdir()
  }
  build_dir <- file.path(build_root, paste0("gllvmTMB-va-r3-", stamp))
  cpp <- file.path(build_dir, "gllvmTMB_va_r3.cpp")
  if (!dir.exists(build_dir)) dir.create(build_dir, recursive = TRUE)
  if (!file.exists(cpp) || isTRUE(rebuild)) {
    if (!file.copy(source, cpp, overwrite = TRUE)) {
      stop("Failed to copy the R3 TMB source into its temporary build directory.",
           call. = FALSE)
    }
  }
  dll <- TMB::dynlib(tools::file_path_sans_ext(cpp))
  loaded <- vapply(getLoadedDLLs(), function(x) {
    path <- x[["path"]]
    nzchar(path) && identical(normalizePath(path, mustWork = FALSE),
                              normalizePath(dll, mustWork = FALSE))
  }, logical(1))
  if (!file.exists(dll) || isTRUE(rebuild)) {
    if (any(loaded)) dyn.unload(dll)
    old <- getwd()
    on.exit(setwd(old), add = TRUE)
    setwd(build_dir)
    compile_args <- list(basename(cpp), flags = compile_flags)
    if (!is.null(framework)) compile_args$framework <- framework
    if (!is.null(supernodal)) compile_args$supernodal <- supernodal
    status <- do.call(TMB::compile, compile_args)
    if (length(status) != 1L || is.na(status) || status != 0 ||
        !file.exists(dll)) {
      stop("Compilation of the standalone R3 TMB template failed.",
           call. = FALSE)
    }
    loaded[] <- FALSE
  }
  if (!any(loaded)) dyn.load(dll)
  list(DLL = "gllvmTMB_va_r3", path = dll, source = source, checksum = stamp)
}

.va_r3_source_commit <- function(source) {
  root <- dirname(dirname(dirname(normalizePath(source, mustWork = FALSE))))
  relative <- tryCatch(
    sub(paste0("^", normalizePath(root, mustWork = FALSE), "/"), "",
        normalizePath(source, mustWork = FALSE)),
    error = function(e) source
  )
  tracked <- suppressWarnings(tryCatch(
    system2("git", c("-C", shQuote(root), "ls-files", "--error-unmatch",
                     shQuote(relative)), stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  ))
  clean <- suppressWarnings(tryCatch(
    system2("git", c("-C", shQuote(root), "diff", "--quiet", "HEAD", "--",
                     shQuote(relative)), stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  ))
  if (!identical(tracked, 0L) || !identical(clean, 0L)) return(NA_character_)
  out <- suppressWarnings(tryCatch(
    system2("git", c("-C", shQuote(root), "rev-parse", "HEAD"),
            stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  ))
  if (length(out) == 1L && grepl("^[0-9a-f]{40}$", out)) out else NA_character_
}

## Rotate a T x q loadings matrix Lambda (from an eigendecomposition, hence
## generally dense) into the lower-triangular form .va_r3_pack_theta_rr()
## requires, without changing Lambda %*% t(Lambda).  Factor loadings are only
## identified up to a right-orthogonal rotation, so this picks the rotation Q
## (q x q) that makes the top q x q block lower triangular: an LQ
## decomposition of that block, obtained via the QR decomposition of its
## transpose (t(L1) = Q1 R1 => L1 = t(R1) %*% t(Q1) => L1 %*% Q1 = t(R1),
## lower triangular; Q1 is a legitimate rotation because it is orthogonal).
## Below-block rows automatically satisfy the packer's zero-pattern
## regardless of rotation.  QR leaves a strict-upper block that is
## numerically ~0 rather than exactly 0, so it is hard-zeroed afterwards
## (after checking it really is negligible).
.va_r3_rotate_to_lower_triangular <- function(Lambda, q) {
  L1 <- Lambda[seq_len(q), seq_len(q), drop = FALSE]
  Q1 <- qr.Q(qr(t(L1)))
  rotated <- Lambda %*% Q1
  upper <- row(rotated) < col(rotated)
  if (any(upper) && max(abs(rotated[upper])) > 1e-6) return(NULL)
  rotated[upper] <- 0
  rotated
}

## Factor-analytic warm start for the loadings: eigendecompose the
## correlation of the link-scale residuals (response pseudo-data minus the
## fixed-effect contribution already estimated in beta) and take the first q
## eigenvectors, scaled by sqrt(eigenvalue), as Lambda.  This mirrors gllvm's
## starting.val = "res".  Returns NULL (caller falls back to the constant
## start) on any degeneracy: too few units, non-finite correlations, a
## non-finite eigendecomposition, or a rotation that fails the lower-triangle
## check above.
## Link-scale pseudo-responses for warm starts (Design 108: per-row family).
.va_r3_link_pseudo <- function(y, n_trials, family_codes, link_ids = NULL) {
  fam <- as.integer(family_codes)
  if (is.null(link_ids)) link_ids <- rep.int(0L, length(fam))
  out <- as.numeric(y)
  bin <- fam == 1L
  if (any(bin)) {
    prop <- pmin(pmax((y[bin] + 0.5) / (n_trials[bin] + 1), 1e-6), 1 - 1e-6)
    ids <- as.integer(link_ids[bin])
    out[bin] <- ifelse(ids == 1L, stats::qnorm(prop),
                       ifelse(ids == 2L, log(-log1p(-prop)), stats::qlogis(prop)))
  }
  log_link <- fam %in% c(2L, 3L, 4L, 5L, 6L, 10L, 11L, 12L, 13L, 15L)
  if (any(log_link)) out[log_link] <- log(y[log_link] + 0.5)
  beta_link <- fam %in% c(7L, 8L)
  if (any(beta_link)) {
    prop <- ifelse(fam[beta_link] == 8L,
                   (y[beta_link] + 0.5) / (n_trials[beta_link] + 1),
                   y[beta_link])
    out[beta_link] <- stats::qlogis(pmin(pmax(prop, 1e-6), 1 - 1e-6))
  }
  ord <- fam == 14L
  if (any(ord)) out[ord] <- stats::qnorm((rank(y[ord], ties.method = "average") - 0.5) / sum(ord))
  out
}

.va_r3_warm_theta_rr <- function(data, beta) {
  N <- data$N
  T <- data$T
  q <- data$q
  if (N < 2L) return(NULL)
  eta_fixed <- as.numeric(data$X %*% beta)
  pseudo <- .va_r3_link_pseudo(data$y, data$n_trials, data$family, data$link_id)
  resid <- pseudo - eta_fixed
  Z <- matrix(NA_real_, nrow = N, ncol = T)
  Z[cbind(data$unit_id + 1L, data$trait_id + 1L)] <- resid
  if (anyNA(Z) || !all(is.finite(Z))) return(NULL)
  cor_Z <- tryCatch(stats::cor(Z), error = function(e) NULL)
  if (is.null(cor_Z) || !all(is.finite(cor_Z))) return(NULL)
  eig <- tryCatch(eigen(cor_Z, symmetric = TRUE), error = function(e) NULL)
  if (is.null(eig) || !all(is.finite(eig$values)) || !all(is.finite(eig$vectors))) {
    return(NULL)
  }
  Lambda <- eig$vectors[, seq_len(q), drop = FALSE] %*%
    diag(sqrt(pmax(eig$values[seq_len(q)], 0)), nrow = q, ncol = q)
  Lambda <- tryCatch(.va_r3_rotate_to_lower_triangular(Lambda, q),
                     error = function(e) NULL)
  if (is.null(Lambda) || !all(is.finite(Lambda))) return(NULL)
  theta_rr <- tryCatch(.va_r3_pack_theta_rr(Lambda, q), error = function(e) NULL)
  if (is.null(theta_rr) ||
      length(theta_rr) != .va_r3_theta_length(T, q) ||
      !all(is.finite(theta_rr))) {
    return(NULL)
  }
  theta_rr
}

.va_r3_default_parameters <- function(data, start_id = 1L) {
  N <- data$N
  T <- data$T
  q <- data$q
  p <- ncol(data$X)
  start_id <- as.integer(start_id)
  beta <- rep(0, p)
  pseudo <- .va_r3_link_pseudo(data$y, data$n_trials, data$family, data$link_id)
  beta_fit <- tryCatch(stats::lm.fit(data$X, pseudo)$coefficients,
                       error = function(e) rep(0, p))
  if (length(beta_fit) == p && all(is.finite(beta_fit))) beta <- unname(beta_fit)

  ## Start 1 = the factor-analytic warm start (data-driven loadings).  Starts
  ## 2-4 add the pre-existing jitter pattern on top of that same warm base,
  ## rather than replacing it, so the 4-start agreement gate still probes
  ## genuinely different starting points.  A degenerate/non-finite warm start
  ## falls back to the original constant-diagonal start for all four starts.
  theta_rr <- .va_r3_warm_theta_rr(data, beta)
  if (is.null(theta_rr)) {
    theta_rr <- rep(0, .va_r3_theta_length(T, q))
    theta_rr[seq_len(q)] <- c(0.10, -0.10, 0.20, -0.20)[1L] *
      rep(c(1, -1), length.out = q)
  }
  ## Extra DENSE tiers append their own packed loadings after tier 1's. There
  ## is no residual-correlation warm start for them (the residual correlation
  ## the warm start reads is not attributable to a tier), so they take the same
  ## constant alternating-diagonal start the tier-1 fallback uses.
  layout <- data$tier_layout
  if (!is.null(layout) && layout$n_tiers > 1L) {
    for (k in seq.int(2L, layout$n_tiers)) {
      if (identical(layout$kind_code[k], 0L)) {
        extra <- rep(0, layout$loading_length[k])
        d_k <- layout$dim[k]
        extra[seq_len(d_k)] <- 0.10 * rep(c(1, -1), length.out = d_k)
        theta_rr <- c(theta_rr, extra)
      }
    }
  }
  if (start_id > 1L) {
    diagonal_scale <- c(0.10, -0.10, 0.20, -0.20)[start_id]
    theta_rr[seq_len(q)] <- theta_rr[seq_len(q)] +
      diagonal_scale * rep(c(1, -1), length.out = q)
    if (length(theta_rr) > q) {
      k <- seq_len(length(theta_rr) - q)
      theta_rr[-seq_len(q)] <- theta_rr[-seq_len(q)] + (0.01 * start_id) * sin(k)
    }
  }
  ## The variational block is flat and tier-major. At K = 1 these have length
  ## N*q, N*q and N*q(q-1)/2, i.e. exactly as.vector() of the pre-Stage-6
  ## matrices, so every start below is numerically the same start it was.
  n_mean <- if (is.null(layout)) as.integer(N * q) else layout$total_mean
  n_off <- if (is.null(layout)) {
    as.integer(N * q * (q - 1L) / 2L)
  } else layout$total_off
  n_sd <- if (is.null(layout)) 0L else layout$total_sd
  m <- rep(0, n_mean)
  log_L_diag <- rep(0, n_mean)
  L_off <- rep(0, n_off)
  ## Trait-diagonal tiers start at sd = 0.3, the same order of magnitude as the
  ## constant loading start above; exp(0) = 1 would start Psi dominating the
  ## loadings it is meant to complement.
  log_sd_tier <- rep(log(0.3), n_sd)
  if (start_id > 1L) {
    m[] <- c(0.01, 0.02, 0.015)[start_id - 1L] *
      sin(seq_len(length(m)) + start_id)
    log_L_diag[] <- c(-0.025, 0.025, -0.04)[start_id - 1L]
    if (length(L_off)) {
      L_off[] <- c(0.005, 0.01, 0.0075)[start_id - 1L] *
        cos(seq_len(length(L_off)) + start_id)
    }
    if (length(log_sd_tier)) {
      log_sd_tier <- log_sd_tier + c(0.05, -0.05, 0.10)[start_id - 1L] *
        cos(seq_len(length(log_sd_tier)) + start_id)
    }
  }
  list(
    beta = beta,
    theta_rr = theta_rr,
    log_sd_tier = log_sd_tier,
    m = m,
    log_L_diag = log_L_diag,
    L_off = L_off,
    log_sigma = if (!is.null(data$log_sigma_start)) {
      as.numeric(data$log_sigma_start)
    } else {
      rep(0, T)
    },
    log_sigma_lognormal = rep(0, T),
    log_phi_gamma = rep(0, T),
    log_phi_nbinom2 = rep(0, T),
    log_phi_tweedie = rep(0, T),
    logit_p_tweedie = rep(0, T),
    log_phi_beta = rep(1, T),
    log_phi_betabinom = rep(1, T),
    log_sigma_student = rep(0, T),
    log_df_student = rep(log(4), T),
    log_phi_truncnb2 = rep(0, T),
    log_sigma_lognormal_delta = rep(0, T),
    log_phi_gamma_delta = rep(0, T),
    ordinal_log_increments = data$ordinal_log_increments_start %||% numeric(0),
    log_phi_nbinom1 = rep(0, T)
  )
}

## Per-family evaluation contract for the VA-R3 engine.
##
## The VA objective needs E[log p(y | eta)] with eta ~ N(mu, v). For every
## family whose likelihood enters through a SCALAR linear predictor that is a
## one-dimensional integral, so a family is specified here by which evaluation
## tiers the template implements for it and which one `eval_method = "auto"`
## resolves to. Adding a family is a registry entry plus a template branch,
## not a new dispatch rule.
##
## Fields
##   family       : R-side name accepted by .va_r3_validate_data()
##   family_code  : integer passed to the template as DATA_IVECTOR(family) entries
##   link         : the single link this family admits
##   tiers        : evaluation tiers the template implements for it
##   default_tier : what eval_method = "auto" resolves to
##   expectation  : how E[log p(y|eta)] is obtained under default_tier --
##                  "exact" (closed form), "quadrature" (Gauss-Hermite), or
##                  "bound" (a variational bound, deliberately not an equality)
.va_r3_registry_row <- function(family, family_code, link, link_id = 0L,
                                expectation = "quadrature", tiers = "gh",
                                optimizer_by_tier = NULL) {
  if (is.null(optimizer_by_tier)) {
    optimizer_by_tier <- stats::setNames(rep(list("nlminb"), length(tiers)), tiers)
  }
  if (!identical(sort(names(optimizer_by_tier)), sort(tiers)) ||
      any(!unlist(optimizer_by_tier, use.names = FALSE) %in% c("nlminb", "lbfgsb"))) {
    stop("optimizer_by_tier must name every declared evaluation tier with nlminb or lbfgsb.",
         call. = FALSE)
  }
  list(family = family, family_code = as.integer(family_code), link = link,
       link_id = as.integer(link_id), tiers = tiers, default_tier = "gh",
       expectation = expectation, optimizer_by_tier = optimizer_by_tier)
}

.va_r3_family_registry <- list(
  ## Preserve the measured pre-Design-110 routes, then add the one new route
  ## earned by Gate E. These choices alter optimisation only, never the model.
  .va_r3_registry_row(
    "gaussian_anchor", 0L, "identity", expectation = "exact",
    optimizer_by_tier = list(gh = "lbfgsb")
  ),
  .va_r3_registry_row(
    "binomial", 1L, "logit", 0L, tiers = c("gh", "jj"),
    optimizer_by_tier = list(gh = "nlminb", jj = "lbfgsb")
  ),
  .va_r3_registry_row("binomial_probit", 1L, "probit", 1L,
                      tiers = c("gh", "ac", "ac2")),
  .va_r3_registry_row("binomial_cloglog", 1L, "cloglog", 2L),
  .va_r3_registry_row("poisson", 2L, "log", expectation = "exact"),
  .va_r3_registry_row("lognormal", 3L, "log", expectation = "exact"),
  .va_r3_registry_row("gamma", 4L, "log", expectation = "exact"),
  ## Gate-E known-DGP H7 fixture: nlminb returned three small-gradient starts
  ## whose objectives differed by 0.002; L-BFGS-B agreed to the 1e-6 gate.
  .va_r3_registry_row("nbinom2", 5L, "log",
                      optimizer_by_tier = list(gh = "lbfgsb")),
  .va_r3_registry_row("tweedie", 6L, "log"),
  .va_r3_registry_row("beta", 7L, "logit"),
  .va_r3_registry_row("betabinomial", 8L, "logit"),
  .va_r3_registry_row("student", 9L, "identity"),
  .va_r3_registry_row("truncated_poisson", 10L, "log"),
  .va_r3_registry_row("truncated_nbinom2", 11L, "log"),
  .va_r3_registry_row("delta_lognormal", 12L, "log", expectation = "hybrid"),
  .va_r3_registry_row("delta_gamma", 13L, "log", expectation = "hybrid"),
  .va_r3_registry_row("ordinal_probit", 14L, "probit"),
  .va_r3_registry_row("nbinom1", 15L, "log")
)

.va_r3_family_entry <- function(family_code, link_id = 0L) {
  for (entry in .va_r3_family_registry) {
    if (identical(entry$family_code, as.integer(family_code)) &&
        identical(entry$link_id, as.integer(link_id))) return(entry)
  }
  stop("VA-R3 has no registry entry for family/link id (", family_code, ", ",
       link_id, ").",
       call. = FALSE)
}

.va_r3_resolve_eval_method <- function(eval_method = c("auto", "jj", "gh", "ac", "ac2"),
                                       family, link_id = NULL) {
  eval_method <- match.arg(eval_method)
  if (is.null(link_id)) link_id <- rep.int(0L, length(family))
  cells <- unique(cbind(family = as.integer(family), link = as.integer(link_id)))
  ## Design 108 Stage 2: mixed-family fits always use GH; JJ is binomial-only.
  ## Albert-Chib (and its "ac2" curvature-corrected sibling) is likewise
  ## single-family only -- `eval_method` is one global scalar in the
  ## template, so a mixed fit cannot ask for a probit-specific evaluator on
  ## some rows and quadrature on others.
  if (nrow(cells) > 1L) {
    if (identical(eval_method, "jj")) {
      stop("eval_method = \"jj\" is only defined for pure-binomial VA fits.",
           call. = FALSE)
    }
    if (identical(eval_method, "ac")) {
      stop("eval_method = \"ac\" is only defined for pure binomial-probit VA fits.",
           call. = FALSE)
    }
    if (identical(eval_method, "ac2")) {
      stop("eval_method = \"ac2\" is only defined for pure binomial-probit VA fits.",
           call. = FALSE)
    }
    return("gh")
  }
  entry <- .va_r3_family_entry(cells[1L, 1L], cells[1L, 2L])
  if (identical(eval_method, "auto")) return(entry$default_tier)
  if (!eval_method %in% entry$tiers) {
    stop(sprintf(
      "eval_method = \"%s\" is not implemented for the %s family; available: %s.",
      eval_method, entry$family, paste(entry$tiers, collapse = ", ")),
      call. = FALSE)
  }
  eval_method
}

## The tier -> template-code map. This was a BOOLEAN collapse
## (`if (jj) 1L else 0L`) while only two tiers existed; with a third it must be
## an exhaustive switch. The failure mode a boolean collapse produces here is the
## worst kind available: an unrecognised tier maps silently to 0L and the fit
## runs Gauss-Hermite while reporting the tier that was asked for -- a wrong
## answer with no error. `switch` without a default errors instead.
.va_r3_eval_method_code <- function(eval_method = c("auto", "jj", "gh", "ac", "ac2"),
                                    family, link_id = NULL) {
  resolved <- .va_r3_resolve_eval_method(eval_method, family, link_id)
  code <- switch(resolved, gh = 0L, jj = 1L, ac = 2L, ac2 = 3L)
  if (is.null(code)) {
    stop("VA-R3 has no template code for eval_method = \"", resolved, "\".",
         call. = FALSE)
  }
  code
}

## Same exhaustiveness requirement, and the same reason: mislabelling the
## objective would license comparing values across tiers that do not compute the
## same quantity. GH and AC differ by a strict bound gap, not by numerical noise.
##
## "ac2" is deliberately labelled "APPROX_AC2", NOT "ELBO_AC2": gh/jj/ac all
## produce a genuine ELBO (a certified lower bound on log p(y) -- gh and jj by
## the standard variational-inequality argument, ac by the Albert-Chib
## data-augmentation argument, dev/va-speed/ALBERT-CHIB-DERIVATION.md). ac2
## plugs the exact curvature into a plain delta-method Taylor expansion
## (inst/tmb/gllvmTMB_va_r3.cpp, va_r3_probit_ac2_expectation) with no such
## argument behind it, so its error is unsigned -- calling it an ELBO would
## be a false claim, not a labelling nicety. Precedent for a non-ELBO
## objective_type in this codebase: R/eva-proto.R's unrelated Design-86
## engine reports "EVA_TAYLOR2" for the same reason (also a Taylor
## expansion, also not a proven bound).
.va_r3_objective_type <- function(resolved_eval_method) {
  type <- switch(resolved_eval_method,
                 gh = "ELBO_GH", jj = "ELBO_JJ", ac = "ELBO_AC", ac2 = "APPROX_AC2")
  if (is.null(type)) {
    stop("VA-R3 has no objective label for eval_method = \"",
         resolved_eval_method, "\".", call. = FALSE)
  }
  type
}

## Two-stage warm-started GH fit: land cheaply on the Albert-Chib closed form, then
## let Gauss-Hermite polish from there.
##
## WHY THIS EXISTS. AC and GH optimise DIFFERENT objectives -- AC is a strict lower
## bound on GH -- and each alone is unsatisfactory for a different reason:
##   * GH is the more accurate tier but expensive (measured ~15.5x the per-evaluation
##     cost of AC at N=250/T=20, and ~139 outer iterations).
##   * AC is cheap and lands close, but COLLAPSES a real diagonal-psi variance at low
##     n_trials -- 2.2e-04 against a planted 0.6 at n_trials=6, where GH recovers
##     0.56. That is disqualifying on its own for variance-component work.
## Because this route ENDS on GH, it inherits GH's objective, GH's optimum and GH's
## variance recovery. AC is used only to choose a starting point, which cannot change
## what is being optimised.
##
## MEASURED (5 seeds, N=100, T=10, q=1, n_trials=6, dev/va-speed/13-warmstart-gh.R):
##   GH cold  rel_frob 0.24412, 138.6 outer iterations
##   GH warm  rel_frob 0.24603,  36.8 outer iterations
## Same optimum -- per-seed objectives agree to 4-5 significant figures -- at 3.8x
## fewer iterations; per seed the reduction ranged 2.4x to 7.1x. The implied
## whole-fit gain (~3x) is ARITHMETIC from those two measured quantities and is NOT
## an end-to-end timing; do not quote it as one until it is measured serially.
##
## Returns the GH fit, with the AC stage attached as `warm_start` for auditing.
.va_r3_fit_warm <- function(..., H = 7L, control = NULL) {
  dots <- list(...)
  if (!is.null(dots$eval_method) && !identical(dots$eval_method, "gh")) {
    stop("`.va_r3_fit_warm()` always finishes on the GH tier; ",
         "eval_method must be \"gh\" or absent.", call. = FALSE)
  }
  ## Stage 1 -- the cheap landing. n_starts is forced to 1: multi-start on the AC
  ## stage buys nothing, because only its ARGMAX is used and stage 2 re-optimises
  ## a different objective from there anyway.
  ac_args <- dots
  ac_args$eval_method <- "ac"
  ac_args$n_starts <- 1L
  ac_args$H <- H
  ac_args$control <- control
  ac <- do.call(.va_r3_fit, ac_args)
  if (is.null(ac) || is.null(ac$best$par)) return(do.call(.va_r3_fit, dots))

  ## Stage 2 -- polish on GH, started from the AC optimum. Build the GH objective
  ## directly so the AC parameter vector can be handed in as the start.
  vd <- do.call(.va_r3_validate_data,
                dots[intersect(names(dots), names(formals(.va_r3_validate_data)))])
  obj <- .va_r3_make_objective(vd, H = H, eval_method = "gh")

  ## A silent length/name mismatch here would optimise the wrong coordinates while
  ## reporting success, so it fails loudly instead.
  if (!identical(length(obj$par), length(ac$best$par)) ||
      !identical(names(obj$par), names(ac$best$par))) {
    stop("warm start aborted: the AC and GH parameter vectors do not match ",
         "(lengths ", length(ac$best$par), " vs ", length(obj$par), "). ",
         "Transplanting them would optimise the wrong coordinates.", call. = FALSE)
  }
  ## Reset the variance tier off the boundary before handing the vector to GH.
  ##
  ## WHY: AC collapses a real psi at low `n_trials` (claims 13/22). Ending on GH
  ## does NOT undo that, because stage 2 STARTS from AC's `log_sd_tier`, and psi
  ## is parameterised on the log scale, where
  ##     d f / d(log sigma) = (d f / d sigma) * sigma
  ## so the gradient is scaled by sigma itself. At sigma ~ 1e-4 that direction is
  ## numerically flat and `nlminb`, a LOCAL optimiser, cannot climb back out.
  ## psi -> 0 is an attracting boundary, and the route inherited it.
  ##
  ## Measured (N=100 T=10 q=1 n_trials=6, psi=0.6 planted, 3 seeds, interleaved,
  ## on a quiet machine -- dev/va-speed/26-warm-reset-probe.R):
  ##   without reset  psi = 0.0001 / 0.2427 / 0.0000, objective 19-52 nats WORSE
  ##   with reset     psi = 0.6207 / 0.5023 / 0.5074, matching cold GH to 4-5 s.f.
  ##                  on objective AND rel_frob, still 12.3x faster than cold.
  ## The warm loadings, fixed effects and variational block are all KEPT -- only
  ## the tier SDs are returned to the ordinary default start.
  start <- ac$best$par
  sd_idx <- which(names(start) == "log_sd_tier")
  if (length(sd_idx)) start[sd_idx] <- log(0.3)
  ctl <- if (is.null(control)) list(eval.max = 800L, iter.max = 400L) else control
  fit <- stats::nlminb(start = start, objective = obj$fn,
                       gradient = obj$gr, control = ctl)
  list(best = list(par = fit$par, objective = fit$objective,
                   convergence = fit$convergence, iterations = fit$iterations,
                   evaluations = fit$evaluations, message = fit$message),
       objective_type = "ELBO_GH",
       route = "ac_warm_start",
       warm_start = list(objective = ac$best$objective,
                         iterations = ac$best$iterations,
                         status = ac$status))
}

## Latent-variable posterior summary from a fitted parameter vector.
##
## The variational posterior q(z_i) = N(m_i, L_i L_i') is ESTIMATED, so its
## per-unit spread is already computed at the optimum and needs only to be
## read out -- unlike beta and the loadings, which are point-estimated and
## carry no variational distribution at all.
##
## Two honesty constraints are baked into the return value:
##   * `uncertainty_basis` records that these are VARIATIONAL posterior SDs,
##     conditional on the point estimates of beta and theta_rr. They are not
##     Wald standard errors and they do not propagate loading uncertainty.
##   * `calibrated = FALSE` until a coverage study says otherwise. Variational
##     posteriors are known to understate spread; the size of that understatement
##     here is unmeasured, so nothing downstream may quote these as intervals.
## The list(scores=, se=) shape matches the existing getLV(se = TRUE) contract
## in R/output-methods.R so this can be wired to that surface without a new API.
.va_r3_latent_posterior <- function(par, N, q) {
  N <- as.integer(N)
  q <- as.integer(q)
  nm <- names(par)
  if (is.null(nm)) {
    stop("par must carry TMB parameter names to read the variational block.",
         call. = FALSE)
  }
  ## Stage 6: the variational block is flat and TIER-MAJOR, and tier 1 is the
  ## ordinary latent tier by construction, so tier 1's coordinates are the
  ## leading N*q (and N*q(q-1)/2) entries of each group. Taking the head is
  ## therefore exact, not a heuristic -- and at K = 1 it is the whole vector.
  take <- function(what, n) {
    v <- unname(par[nm == what])
    if (length(v) < n) {
      stop("par's `", what, "` block is shorter than the latent tier requires.",
           call. = FALSE)
    }
    v[seq_len(n)]
  }
  scores <- matrix(take("m", N * q), nrow = N, ncol = q)
  chol_factors <- .va_r3_unpack_variational_chol(
    take("log_L_diag", N * q), take("L_off", N * q * (q - 1L) / 2L), N, q
  )
  se <- matrix(NA_real_, nrow = N, ncol = q)
  for (i in seq_len(N)) {
    L_i <- matrix(chol_factors[, , i], nrow = q, ncol = q)
    ## pmax(., 0) mirrors .getLV_se(); a Cholesky product cannot be negative
    ## on the diagonal except through floating-point error.
    se[i, ] <- sqrt(pmax(diag(L_i %*% t(L_i)), 0))
  }
  list(
    scores = scores,
    se = se,
    uncertainty_basis = "variational posterior, conditional on point estimates of beta and theta_rr",
    calibrated = FALSE
  )
}

## Observed information for the FIXED parameters (beta, theta_rr).
##
## Unlike the latent block above, beta and theta_rr have no variational
## distribution -- they are maximised, so an SE has to come from curvature.
## Two are computed, and the difference between them matters:
##
##   se_conditional : from H_ff alone, holding the variational coordinates at
##                    their optimum. This is what a naive optimHess over the
##                    fixed block gives. It IGNORES the fact that m and the
##                    Cholesky would re-optimise as beta and theta_rr move, so
##                    it overstates curvature and is expected ANTI-CONSERVATIVE.
##   se_profile     : the Schur complement H_ff - H_fv H_vv^-1 H_vf, i.e. the
##                    curvature of the objective with the variational block
##                    profiled out. This is the correct observed information
##                    for the fixed parameters and is the one to prefer.
##
## Conventions follow the package (R/extractors.R returns a status code; the
## confint surface carries a pd_hessian column) and GLLVM.jl/src/confint.jl
## (PD check, NA rather than a number when the Hessian is not usable).
##
## Neither SE is calibrated. Variational posteriors understate spread, and the
## size of that understatement here is unmeasured, so `calibrated` stays FALSE
## until a coverage study fills it in.
## L-BFGS-B's relative-tolerance control. optim() expresses it as factr, a
## MULTIPLE of machine epsilon, so this is the translation of nlminb-grade
## tolerance. Passing optim's DEFAULT factr instead is catastrophic and silent:
## measured at N=1600 it terminated in 24 MILLISECONDS at an objective 125-151
## worse than nlminb's, in 3 of 3 replicates, while reporting convergence = 0.
## With this value it reached nlminb's objective to <= 1e-4 in all 3, between
## 17.7x and 37.7x faster. Never let this default.
.VA_R3_LBFGSB_FACTR <- 1e-12 / .Machine$double.eps

## The primary optimiser. nlminb (PORT) is the default and remains the
## reference; "lbfgsb" is the measured-faster alternative. Both minimise the
## same objective from the same start, so this is a route choice, not a model
## choice. Automatic use remains per-cell: Gaussian GH and binomial-JJ retain
## their measured routes, and Design-110 Gate E adds NB2 GH after nlminb failed
## the cross-start objective-agreement gate while L-BFGS-B passed.
## Resolve optimizer = "auto" from the registry, per FAMILY and per TIER.
##
## Which optimiser wins is not a property of the family alone -- binomial splits
## in opposite directions across its two tiers (jj 2.54x toward lbfgsb, gh 0.57x
## toward nlminb), so resolving per family would have slowed the accurate tier
## down. Each registry row therefore carries optimizer_by_tier, and "auto" reads
## it after eval_method has itself been resolved.
##
## The routing is deliberately conservative: lbfgsb is chosen only where direct
## evidence supports it. Unbenchmarked Design-110 cells, Poisson, and
## binomial-GH keep nlminb. NB2 is the exception earned by Gate E: this is an
## agreement repair, not a blanket speed preference.
.va_r3_resolve_optimizer <- function(optimizer = c("auto", "nlminb", "lbfgsb"),
                                     family, resolved_eval_method, link_id = NULL) {
  optimizer <- match.arg(optimizer)
  if (!identical(optimizer, "auto")) return(optimizer)
  if (is.null(link_id)) link_id <- rep.int(0L, length(family))
  cells <- unique(cbind(family = as.integer(family), link = as.integer(link_id)))
  if (nrow(cells) > 1L) {
    ## Mixed-family fits use GH; keep the reference GH optimiser.
    return("nlminb")
  }
  entry <- .va_r3_family_entry(cells[1L, 1L], cells[1L, 2L])
  choice <- entry$optimizer_by_tier[[resolved_eval_method]]
  ## A tier with no declared route falls back to the reference optimiser rather
  ## than guessing; a new tier must opt in explicitly.
  if (is.null(choice)) "nlminb" else choice
}

.va_r3_run_primary <- function(optimizer, obj, start, control) {
  if (identical(optimizer, "nlminb")) {
    return(stats::nlminb(start, obj$fn, obj$gr, control = control))
  }
  maxit <- control$iter.max %||% control$eval.max %||% 2000L
  fit <- stats::optim(start, obj$fn, obj$gr, method = "L-BFGS-B",
                      control = list(maxit = maxit,
                                     factr = .VA_R3_LBFGSB_FACTR))
  ## Normalise onto nlminb's return shape so every downstream health gate,
  ## polish step and diagnostic reads the same fields regardless of route.
  list(par = fit$par, objective = fit$value, convergence = fit$convergence,
       message = fit$message, evaluations = fit$counts,
       iterations = NA_integer_)
}

## Positions of each unit's variational coordinates within the parameter vector.
##
## The variational block is stored as three column-major matrices -- m (N x q),
## log_L_diag (N x q) and L_off (N x q(q-1)/2) -- so a single unit's k = 2q +
## q(q-1)/2 coordinates are SCATTERED through the vector, not contiguous.
## Returns an N x k matrix of absolute positions, column c being the c-th
## within-unit coordinate for every unit.
.va_r3_variational_index_map <- function(par_names, N, q) {
  N <- as.integer(N)
  q <- as.integer(q)
  n_off <- as.integer(q * (q - 1L) / 2L)
  columns <- list()
  for (group in c("m", "log_L_diag", "L_off")) {
    idx <- which(par_names == group)
    n_col <- if (identical(group, "L_off")) n_off else q
    if (!length(idx)) {
      if (n_col > 0L) {
        stop("variational group ", group, " is absent from par.", call. = FALSE)
      }
      next
    }
    if (length(idx) != N * n_col) {
      stop("variational group ", group, " has an unexpected length.", call. = FALSE)
    }
    for (j in seq_len(n_col)) {
      columns[[length(columns) + 1L]] <- idx[(j - 1L) * N + seq_len(N)]
    }
  }
  if (!length(columns)) return(matrix(integer(), nrow = N, ncol = 0L))
  do.call(cbind, columns)
}

## Hessian blocks WITHOUT forming the dense Hessian.
##
## Two structural facts make this O(N) in memory and O(1) in gradient calls:
##
##  * Units are conditionally independent given the fixed parameters, so H_vv is
##    EXACTLY block diagonal -- N blocks of k x k. Differencing the gradient
##    along "within-unit coordinate j of EVERY unit at once" therefore returns
##    column j of every block simultaneously, with no cross-unit contamination.
##    That is 2k gradient calls for the whole of H_vv, independent of N.
##  * H_fv has only length(fixed) rows, so differencing along each fixed
##    coordinate gives it in 2 * length(fixed) calls and it stays small.
##
## At n = 5397, q = 2 this replaces a 27,002^2 dense Hessian (~5.8 GB) with
## ~44 gradient evaluations and a few MB.
.va_r3_hessian_blocks <- function(objective, par, fixed_idx, index_map,
                                  step = 1e-5) {
  gradient <- function(p) objective$gr(p)
  central <- function(direction) {
    up <- par; down <- par
    up[direction] <- up[direction] + step
    down[direction] <- down[direction] - step
    (as.numeric(gradient(up)) - as.numeric(gradient(down))) / (2 * step)
  }

  ## Columns of H at the fixed coordinates: gives H_ff and H_fv in one sweep.
  n_fixed <- length(fixed_idx)
  fixed_columns <- vapply(fixed_idx, function(i) central(i),
                          numeric(length(par)))
  H_ff <- fixed_columns[fixed_idx, , drop = FALSE]
  ## Symmetrise: central differences of an exact gradient are symmetric only up
  ## to truncation error, and the Schur complement below needs symmetry.
  H_ff <- (H_ff + t(H_ff)) / 2

  k <- ncol(index_map)
  N <- nrow(index_map)
  blocks <- array(0, dim = c(k, k, N))
  for (j in seq_len(k)) {
    delta <- central(index_map[, j])
    for (c in seq_len(k)) {
      blocks[c, j, ] <- delta[index_map[, c]]
    }
  }
  ## Symmetrise each block for the same reason.
  for (i in seq_len(N)) {
    blocks[, , i] <- (blocks[, , i] + t(blocks[, , i])) / 2
  }

  list(H_ff = H_ff, fixed_columns = fixed_columns, blocks = blocks,
       n_fixed = n_fixed, k = k, N = N)
}

## Block-structured route: same Schur complement, without the dense Hessian.
## Use this whenever the variational block is large; it is O(N) in memory and
## uses ~2*(n_fixed + k) gradient calls regardless of N.
.va_r3_global_parameter_names <- c(
  "beta", "theta_rr", "log_sd_tier", "log_sigma",
  "log_sigma_lognormal", "log_phi_gamma", "log_phi_nbinom2",
  "log_phi_tweedie", "logit_p_tweedie", "log_phi_beta",
  "log_phi_betabinom", "log_sigma_student", "log_df_student",
  "log_phi_truncnb2", "log_sigma_lognormal_delta", "log_phi_gamma_delta",
  "ordinal_log_increments", "log_phi_nbinom1"
)

.va_r3_fixed_information_blocked <- function(objective, par, N, q) {
  fail <- function(status) {
    list(se_conditional = NULL, se_profile = NULL, pd_hessian = FALSE,
         calibrated = FALSE, status = status, route = "blocked")
  }
  if (.va_r3_multi_tier(objective)) return(fail(.VA_R3_MULTI_TIER_SE_STATUS))
  nm <- names(par)
  if (is.null(nm)) return(fail("va_unnamed_par_no_fixed_se"))
  ## The fixed block is every parameter that is NOT part of the variational
  ## family (m, log_L_diag, L_off): beta and theta_rr as before, PLUS the
  ## variance/dispersion loadings log_sigma (Gaussian residual SD) and
  ## log_sd_tier (diagonal-tier loading SD, R/va-r3-proto.R's tier registry
  ## kind_code 1L) -- both are global loadings, exactly like theta_rr, not
  ## per-unit variational coordinates, so they belong in H_ff/H_fv, not H_vv.
  ## Before this change they sat in neither block and were silently held at
  ## their fitted value with no correlation to beta/theta_rr captured, which
  ## is why no VA-Wald route could produce an interval for a variance
  ## component (campaign design doc, flaw #21). `%in%` is a no-op for a name
  ## absent from `nm` (e.g. log_sd_tier when there is no diagonal tier, or
  ## log_sigma when no trait is Gaussian), so this is additive: fits without
  ## either parameter see fixed_idx unchanged.
  fixed_idx <- which(nm %in% .va_r3_global_parameter_names)
  if (!length(fixed_idx)) return(fail("va_no_fixed_block_no_fixed_se"))

  index_map <- tryCatch(.va_r3_variational_index_map(nm, N, q),
                        error = function(e) NULL)
  if (is.null(index_map) || !ncol(index_map)) {
    return(fail("va_variational_layout_unrecognised"))
  }

  parts <- tryCatch(
    .va_r3_hessian_blocks(objective, par, fixed_idx, index_map),
    error = function(e) NULL
  )
  if (is.null(parts)) return(fail("va_hessian_error_no_fixed_se"))

  se_from <- function(info) {
    ok <- tryCatch({ chol(info); TRUE }, error = function(e) FALSE)
    if (!ok) return(NULL)
    covariance <- tryCatch(solve(info), error = function(e) NULL)
    if (is.null(covariance)) return(NULL)
    d <- diag(covariance)
    if (any(!is.finite(d)) || any(d < 0)) return(NULL)
    stats::setNames(sqrt(d), nm[fixed_idx])
  }

  se_conditional <- se_from(parts$H_ff)

  ## Schur complement accumulated one unit at a time:
  ##   H_ff - sum_i H_fv,i B_i^{-1} H_fv,i'
  ## H_fv,i is n_fixed x k, read out of the fixed columns at unit i's positions.
  correction <- matrix(0, parts$n_fixed, parts$n_fixed)
  singular <- FALSE
  for (i in seq_len(parts$N)) {
    H_fv_i <- parts$fixed_columns[index_map[i, ], , drop = FALSE]  # k x n_fixed
    solved <- tryCatch(solve(parts$blocks[, , i], H_fv_i), error = function(e) NULL)
    if (is.null(solved)) { singular <- TRUE; break }
    correction <- correction + crossprod(H_fv_i, solved)
  }

  se_profile <- NULL
  profile_status <- "ok"
  if (singular) {
    profile_status <- "va_singular_variational_block"
  } else {
    schur <- parts$H_ff - correction
    schur <- (schur + t(schur)) / 2
    se_profile <- se_from(schur)
    if (is.null(se_profile)) profile_status <- "va_non_pd_profile_information"
  }

  list(
    se_conditional = se_conditional,
    se_profile = se_profile,
    pd_hessian = !is.null(se_profile),
    calibrated = FALSE,
    route = "blocked",
    status = if (is.null(se_conditional)) {
      "va_non_pd_fixed_information_no_fixed_se"
    } else profile_status,
    basis = paste(
      "observed information of the negative ELBO via block-diagonal Schur;",
      "se_profile marginalises the variational block, se_conditional does not"
    )
  )
}

## Fail-closed marker for the one thing Stage 6 does NOT generalise.
##
## H_vv is block diagonal by unit only while a unit's observations touch a
## single tier. With a second tier the blocks are the CONNECTED COMPONENTS of
## the tier-level incidence graph -- for a Psi companion at the same grouping
## that is still the unit, but for a `cluster` tier it is not, and nothing in
## the parameter names distinguishes the two cases. Returning a Schur
## complement built on the wrong partition would be a number, not an error,
## so the multi-tier case refuses instead. Design 108 Stage 14 owns this
## surface; no VA parameter interval is admitted here in any event.
.VA_R3_MULTI_TIER_SE_STATUS <- "va_multi_tier_fixed_information_unsupported"

.va_r3_multi_tier <- function(objective) {
  layout <- attr(objective, "va_r3_tiers")
  !is.null(layout) && isTRUE(layout$n_tiers > 1L)
}

## Recover N and q from the parameter layout alone.
##   length(m) = length(log_L_diag) = N*q ;  length(L_off) = N*q(q-1)/2
## so q = 2*n_off/n_m + 1 and N = n_m/q. q = 1 is the n_off == 0 case.
##
## VALID FOR ONE TIER ONLY. At K > 1 the group lengths are sums over tiers and
## this arithmetic returns a plausible-looking wrong answer, which is why every
## caller goes through .va_r3_multi_tier() first.
.va_r3_infer_dims <- function(par_names) {
  n_m <- sum(par_names == "m")
  n_off <- sum(par_names == "L_off")
  if (!n_m) return(NULL)
  q <- as.integer(round(2 * n_off / n_m + 1))
  if (q < 1L) return(NULL)
  N <- n_m / q
  if (N != as.integer(N)) return(NULL)
  list(N = as.integer(N), q = q)
}

## Single entry point. Routes to the block-diagonal Schur by default, which is
## exact (verified against the dense route to 1.5e-10 relative) and O(N) in
## memory, so there is no scale at which this silently falls back to the
## anti-conservative conditional SE. route = "dense" forces the original path
## and exists to keep that cross-check runnable.
## max_variational is accepted and IGNORED. It used to bound the dense Schur
## complement; the blocked route removed the limitation it guarded, so the
## argument is vestigial. It is kept because callers written against the old
## signature exist -- dropping it turned a running two-hour job's SE step into
## an "unused argument" error after the fit had already succeeded.
.va_r3_fixed_information <- function(objective, par,
                                     route = c("auto", "blocked", "dense"),
                                     max_variational = NULL) {
  route <- match.arg(route)
  if (.va_r3_multi_tier(objective)) {
    return(list(
      se_conditional = NULL, se_profile = NULL, pd_hessian = FALSE,
      calibrated = FALSE, route = route,
      status = .VA_R3_MULTI_TIER_SE_STATUS,
      basis = paste(
        "refused: the per-unit block-diagonal partition H_vv relies on does not",
        "hold once a second tier shares observations with the first, and the",
        "parameter names cannot tell the safe case from the unsafe one"
      )
    ))
  }
  nm <- names(par)
  if (!is.null(nm) && !identical(route, "dense")) {
    dims <- .va_r3_infer_dims(nm)
    if (!is.null(dims)) {
      return(.va_r3_fixed_information_blocked(objective, par,
                                              N = dims$N, q = dims$q))
    }
    if (identical(route, "blocked")) {
      return(list(se_conditional = NULL, se_profile = NULL, pd_hessian = FALSE,
                  calibrated = FALSE, route = "blocked",
                  status = "va_variational_layout_unrecognised"))
    }
  }
  fail <- function(status) {
    list(se_conditional = NULL, se_profile = NULL, pd_hessian = FALSE,
         calibrated = FALSE, status = status, route = "dense")
  }
  if (is.null(nm)) return(fail("va_unnamed_par_no_fixed_se"))
  ## See the identical extension (and its rationale) in
  ## .va_r3_fixed_information_blocked() above: log_sigma/log_sd_tier are
  ## global loadings, not variational coordinates, so they join beta/theta_rr
  ## in the fixed block rather than sitting outside both blocks.
  fixed_idx <- which(nm %in% .va_r3_global_parameter_names)
  var_idx <- which(nm %in% c("m", "log_L_diag", "L_off"))
  if (!length(fixed_idx)) return(fail("va_no_fixed_block_no_fixed_se"))

  hessian <- tryCatch(objective$he(par), error = function(e) NULL)
  if (is.null(hessian) || !all(is.finite(hessian))) {
    return(fail("va_hessian_error_no_fixed_se"))
  }

  ## sqrt of the diagonal of the inverse, guarded on positive-definiteness.
  se_from <- function(info) {
    ok <- tryCatch({
      chol(info)
      TRUE
    }, error = function(e) FALSE)
    if (!ok) return(NULL)
    covariance <- tryCatch(solve(info), error = function(e) NULL)
    if (is.null(covariance)) return(NULL)
    diagonal <- diag(covariance)
    if (any(!is.finite(diagonal)) || any(diagonal < 0)) return(NULL)
    stats::setNames(sqrt(diagonal), nm[fixed_idx])
  }

  H_ff <- hessian[fixed_idx, fixed_idx, drop = FALSE]
  se_conditional <- se_from(H_ff)

  ## The Schur complement needs H_vv inverted. H_vv is block diagonal by unit,
  ## so this is far cheaper than it looks -- but the dense solve below is not,
  ## which is why it is size-guarded. Exploiting the block structure is the
  ## scaling path when this is needed at large n.
  se_profile <- NULL
  profile_status <- "ok"
  if (!length(var_idx)) {
    profile_status <- "va_no_variational_block"
  } else {
    H_fv <- hessian[fixed_idx, var_idx, drop = FALSE]
    H_vv <- hessian[var_idx, var_idx, drop = FALSE]
    schur <- tryCatch(H_ff - H_fv %*% solve(H_vv, t(H_fv)),
                      error = function(e) NULL)
    if (is.null(schur)) {
      profile_status <- "va_singular_variational_block"
    } else {
      se_profile <- se_from(schur)
      if (is.null(se_profile)) profile_status <- "va_non_pd_profile_information"
    }
  }

  list(
    se_conditional = se_conditional,
    se_profile = se_profile,
    pd_hessian = !is.null(se_profile),
    ## FALSE means "not certified for general use", which remains true: the
    ## coverage evidence below covers one DGP and two sample sizes. It is
    ## recorded here so the numbers travel with the caveat rather than being
    ## re-derived, or quietly forgotten, by a later reader.
    calibrated = FALSE,
    calibration_evidence = paste(
      "beta only, binomial-logit, q=2, p=8, n in {150,400}, 25 seeds",
      "(MCSE 0.015; dev/va-se-calibration.R):",
      "se_profile covers 0.935-0.950 against nominal 0.95 in every cell;",
      "se_conditional under-covers in every cell (0.885-0.910).",
      "Latent-score SDs are NOT calibrated. Nothing else is tested."
    ),
    route = "dense",
    status = if (is.null(se_conditional)) {
      "va_non_pd_fixed_information_no_fixed_se"
    } else profile_status,
    basis = paste(
      "observed information of the negative ELBO (dense route);",
      "se_profile marginalises the variational block, se_conditional does not"
    )
  )
}

## The variational block, by parameter name. `profile=` takes NAMES, which is
## why Stage 6's flattening of these three from PARAMETER_MATRIX to
## PARAMETER_VECTOR matters here: a name selects the whole block either way,
## but the flat layout is the one TMB's inner solver indexes contiguously.
.va_r3_variational_names <- c("m", "log_L_diag", "L_off")

## Is the A_i collapse admissible for THIS fit?
##
## Under Albert-Chib the stationarity condition dE/dv = -n/2 makes the
## variational covariance data-independent, so every unit's A_i is the same
## matrix: A_i A_i' = (I_q + sum_j N_ij lambda_j lambda_j')^-1. The closed form
## is published (see dev/va-speed/21-WHY-GLLVM-IS-FAST.md, "Prior art"); what is
## ours is implementing it.
##
## THE POINT OF THIS FUNCTION IS TO REFUSE. The derivation's own scope caveat
## (dev/va-speed/ALBERT-CHIB-DERIVATION.md, s4.1) is narrow -- complete data,
## constant n_ij, a pure-probit trait set, and the UNSTRUCTURED SINGLE-TIER KL --
## while `m`/`log_L_diag`/`L_off` are declared unconditionally and shared by every
## eval_method (inst/tmb/gllvmTMB_va_r3.cpp:417-419). Collapsing them globally
## would silently change the publicly reachable "gh"/"jj" routes, where this
## identity has never been derived: a fit that returns, converges, and is wrong.
## So the default is the per-unit block and every condition must be met to leave it.
.va_r3_collapse_gate <- function(validated, layout, eval_method_code) {
  no <- function(why) list(ok = FALSE, reason = why)
  if (!identical(as.integer(eval_method_code), 2L))
    return(no("eval_method is not Albert-Chib (the identity is derived for AC only)"))
  if (!all(as.integer(validated$family) == 1L &
           as.integer(validated$link_id) == 1L))
    return(no("not every row is binomial-probit (family/link 1/1)"))
  if (!all(as.integer(validated$is_y_observed) == 1L))
    return(no("data are incomplete; A_i is then constant only within a missingness pattern"))
  ntr <- validated$n_trials
  if (is.null(ntr) || length(unique(as.numeric(ntr))) != 1L)
    return(no("n_trials varies across cells, which breaks constancy across units"))
  if (!identical(as.integer(layout$n_tiers), 1L))
    return(no("more than one tier; the structured/diagonal KL differs and the fixed point is UNVERIFIED there"))
  if (!identical(as.integer(layout$kind_code[1L]), 0L))
    return(no("the single tier is not the dense unstructured tier"))
  list(ok = TRUE, reason = "AC, complete, constant n_trials, single dense tier")
}

.va_r3_fixed_family_parameter <- function(x, T, name, lower, upper = Inf) {
  if (is.null(x)) return(rep(NA_real_, T))
  if (!is.numeric(x)) {
    stop(name, " must have length T and contain NA or finite numeric values in (",
         lower, ", ", upper, ").", call. = FALSE)
  }
  x <- as.numeric(x)
  if (length(x) != T || any(is.nan(x)) || any(!is.na(x) &
      (!is.finite(x) | x <= lower | x >= upper))) {
    stop(name, " must have length T and contain NA or finite values in (",
         lower, ", ", upper, ").", call. = FALSE)
  }
  x
}

.va_r3_make_objective <- function(validated, H = 7L, source = NULL,
                                  rebuild = FALSE, parameters = NULL,
                                  fixed_global = NULL, silent = TRUE,
                                  eval_method = c("auto", "jj", "gh", "ac", "ac2"),
                                  match_laplace_residual_sd = FALSE,
                                  profile_variational = FALSE,
                                  collapse_variational_cov = FALSE,
                                  inner_control = NULL,
                                  ac2_threshold = 1.0,
                                  fixed_tweedie_power = NULL,
                                  fixed_student_df = NULL) {
  if (validated$q == 0L) {
    stop("q = 0 is not applicable and must not construct an R3 objective.",
         call. = FALSE)
  }
  eval_method <- match.arg(eval_method)
  eval_method_code <- .va_r3_eval_method_code(eval_method, validated$family,
                                               validated$link_id)
  ## Runtime dial for "ac2"'s expansion/quadrature switch point
  ## (inst/tmb/gllvmTMB_va_r3.cpp, va_r3_probit_ac2_expectation): a
  ## DATA_SCALAR, not a compile-time constant, so a sweep over threshold
  ## values needs no rebuild. Read unconditionally by the template
  ## regardless of eval_method (inert when eval_method != "ac2"), so it must
  ## always be a single finite positive number.
  if (!is.numeric(ac2_threshold) || length(ac2_threshold) != 1L ||
      !is.finite(ac2_threshold) || ac2_threshold <= 0) {
    stop("ac2_threshold must be a single finite positive number.", call. = FALSE)
  }
  rule <- .va_r3_gh_rule(H)
  dll <- .va_r3_load_dll(source, rebuild = rebuild)
  if (is.null(parameters)) parameters <- .va_r3_default_parameters(validated, 1L)
  ## Preserve the old prototype NB2 name as an input alias only; the TMB schema
  ## itself is Laplace-aligned from Design 110 onward.
  if (is.null(parameters$log_phi_nbinom2) && !is.null(parameters$log_phi))
    parameters$log_phi_nbinom2 <- parameters$log_phi
  parameters$log_phi <- NULL
  if (is.null(parameters$log_sigma)) {
    parameters$log_sigma <- if (!is.null(validated$log_sigma_start)) {
      as.numeric(validated$log_sigma_start)
    } else {
      rep(0, validated$T)
    }
  }
  family_parameter_defaults <- list(
    log_sigma_lognormal = rep(0, validated$T),
    log_phi_gamma = rep(0, validated$T),
    log_phi_nbinom2 = rep(0, validated$T),
    log_phi_tweedie = rep(0, validated$T),
    logit_p_tweedie = rep(0, validated$T),
    log_phi_beta = rep(1, validated$T),
    log_phi_betabinom = rep(1, validated$T),
    log_sigma_student = rep(0, validated$T),
    log_df_student = rep(log(4), validated$T),
    log_phi_truncnb2 = rep(0, validated$T),
    log_sigma_lognormal_delta = rep(0, validated$T),
    log_phi_gamma_delta = rep(0, validated$T),
    ordinal_log_increments = validated$ordinal_log_increments_start %||% numeric(0),
    log_phi_nbinom1 = rep(0, validated$T)
  )
  for (nm in names(family_parameter_defaults))
    if (is.null(parameters[[nm]])) parameters[[nm]] <- family_parameter_defaults[[nm]]
  fixed_tweedie_power <- .va_r3_fixed_family_parameter(
    fixed_tweedie_power, validated$T, "fixed_tweedie_power", 1, 2
  )
  fixed_student_df <- .va_r3_fixed_family_parameter(
    fixed_student_df, validated$T, "fixed_student_df", 1
  )
  parameters$logit_p_tweedie[!is.na(fixed_tweedie_power)] <-
    stats::qlogis(fixed_tweedie_power[!is.na(fixed_tweedie_power)] - 1)
  parameters$log_df_student[!is.na(fixed_student_df)] <-
    log(fixed_student_df[!is.na(fixed_student_df)] - 1)
  ## Stage 6 turned the three variational PARAMETER_MATRIXes into flat
  ## PARAMETER_VECTORs. as.numeric() of an N x q matrix is column-major, which
  ## is byte-for-byte the layout the matrix already had, so hand-built
  ## parameter lists written against the pre-Stage-6 signature keep working and
  ## keep producing the identical par vector.
  layout <- validated$tier_layout
  if (is.null(layout)) {
    stop("validated data carry no tier layout; rebuild with .va_r3_validate_data().",
         call. = FALSE)
  }
  parameters$m <- as.numeric(parameters$m)
  parameters$log_L_diag <- as.numeric(parameters$log_L_diag)
  parameters$L_off <- as.numeric(parameters$L_off)
  if (is.null(parameters$log_sd_tier)) {
    parameters$log_sd_tier <- rep(log(0.3), layout$total_sd)
  }
  parameters$log_sd_tier <- as.numeric(parameters$log_sd_tier)
  expected <- c(m = layout$total_mean, log_L_diag = layout$total_mean,
                L_off = layout$total_off, theta_rr = layout$total_theta,
                log_sd_tier = layout$total_sd)
  for (nm in names(expected)) {
    if (length(parameters[[nm]]) != expected[[nm]]) {
      stop("parameter `", nm, "` must have length ", expected[[nm]],
           " for this tier layout, not ", length(parameters[[nm]]), ".",
           call. = FALSE)
    }
  }
  tmb_data <- validated[c("y", "n_trials", "X", "unit_id", "trait_id",
                          "is_y_observed", "family", "link_id",
                          "n_ordinal_cuts_per_trait", "ordinal_offset_per_trait",
                          "N", "T", "q")]
  tmb_data$gh_nodes <- rule$nodes
  tmb_data$gh_weights <- rule$weights
  tmb_data$eval_method <- eval_method_code
  tmb_data$ac2_threshold <- as.numeric(ac2_threshold)
  tmb_data$n_tiers <- layout$n_tiers
  tmb_data$tier_kind <- layout$kind_code
  tmb_data$tier_dim <- layout$dim
  tmb_data$tier_n_levels <- layout$n_levels
  tmb_data$level_id <- layout$level_id
  ## Stage 7. When no tier is structured the template never reads these, so the
  ## placeholder is a 1x1 empty sparse matrix -- it exists to satisfy
  ## DATA_SPARSE_MATRIX, not to be used. The pre-Stage-7 tape is unchanged
  ## because `tier_structured` gates the whole structured block behind an
  ## ordinary C++ `if` on DATA, which lays down no AD nodes.
  tmb_data$tier_structured <- layout$structured_code
  structured <- validated$structured
  if (is.null(structured)) {
    tmb_data$Ainv_struct <- Matrix::sparseMatrix(
      i = integer(0), j = integer(0), x = numeric(0), dims = c(1L, 1L)
    )
    tmb_data$diag_Ainv_struct <- 0
    tmb_data$log_det_A_struct <- 0
  } else {
    tmb_data$Ainv_struct <- structured$Ainv
    tmb_data$diag_Ainv_struct <- structured$diag_Ainv
    tmb_data$log_det_A_struct <- structured$log_det_A
  }
  ## Every per-trait family parameter is free only for traits using that family.
  map <- list()
  fam <- as.integer(validated$family)
  tid <- as.integer(validated$trait_id)
  family_trait <- function(code) vapply(seq_len(validated$T) - 1L, function(t)
    any(fam[tid == t] == code), logical(1L))
  sigma_free <- family_trait(0L)
  if (!isTRUE(validated$estimate_gaussian_sd)) {
    sigma_free[] <- FALSE
  }
  match_laplace_residual_sd <- isTRUE(match_laplace_residual_sd)
  if (match_laplace_residual_sd && any(family_trait(0L)) && any(family_trait(3L))) {
    stop("match_laplace_residual_sd cannot yet tie Gaussian and lognormal scales across separate VA parameter vectors; use a pure-family comparator.",
         call. = FALSE)
  }
  if (!all(sigma_free) || match_laplace_residual_sd) {
    sigma_index <- if (match_laplace_residual_sd) {
      rep.int(1L, length(sigma_free))
    } else {
      seq_along(sigma_free)
    }
    map$log_sigma <- factor(ifelse(sigma_free, sigma_index, NA_integer_))
  }
  param_family <- c(log_sigma_lognormal = 3L, log_phi_gamma = 4L,
                    log_phi_nbinom2 = 5L, log_phi_tweedie = 6L,
                    logit_p_tweedie = 6L, log_phi_beta = 7L,
                    log_phi_betabinom = 8L, log_sigma_student = 9L,
                    log_df_student = 9L, log_phi_truncnb2 = 11L,
                    log_sigma_lognormal_delta = 12L,
                    log_phi_gamma_delta = 13L, log_phi_nbinom1 = 15L)
  for (nm in names(param_family)) {
    free <- family_trait(unname(param_family[[nm]]))
    if (identical(nm, "logit_p_tweedie"))
      free[!is.na(fixed_tweedie_power)] <- FALSE
    if (identical(nm, "log_df_student"))
      free[!is.na(fixed_student_df)] <- FALSE
    index <- if (match_laplace_residual_sd && identical(nm, "log_sigma_lognormal")) {
      rep.int(1L, length(free))
    } else {
      seq_along(free)
    }
    if (!all(free) || (match_laplace_residual_sd && identical(nm, "log_sigma_lognormal"))) {
      map[[nm]] <- factor(ifelse(free, index, NA_integer_))
    }
  }
  if (!any(fam == 14L) && length(parameters$ordinal_log_increments))
    map$ordinal_log_increments <- factor(rep(NA_integer_, length(parameters$ordinal_log_increments)))

  ## The A_i collapse, expressed as parameter SHARING rather than as a rewritten
  ## template. Every unit's variational covariance is tied to one common value
  ## per coordinate via TMB's `map`, so the free parameter count for the block
  ## drops from N*q to q while the parameter VECTOR keeps its length -- which is
  ## why none of the seven downstream consumers of `log_L_diag`/`L_off`, nor the
  ## template's own size checks, need to change.
  ##
  ## This enforces the STRUCTURE the closed form proves (A_i identical across
  ## units) and lets the optimiser find the common value, rather than hard-coding
  ## a formula whose scope conditions are narrow. The variational MEANS `m` stay
  ## per-unit: they carry each unit's latent position and do not collapse.
  ##
  ## Layout contract: entry (tier k, level g, coordinate c) sits at
  ## offset_k + c*n_levels_k + g, so at K = 1 the vector is coordinate-major and
  ## `rep(coord, each = n_levels)` ties all units within a coordinate.
  collapse_variational_cov <- isTRUE(collapse_variational_cov)
  collapse_applied <- FALSE
  collapse_note <- if (collapse_variational_cov) "" else "not requested"
  if (collapse_variational_cov) {
    gate <- .va_r3_collapse_gate(validated, layout, eval_method_code)
    collapse_note <- gate$reason
    if (isTRUE(gate$ok)) {
      n_lev <- as.integer(layout$n_levels[1L])
      d1 <- as.integer(layout$dim[1L])
      map$log_L_diag <- factor(rep(seq_len(d1), each = n_lev))
      n_off1 <- as.integer(d1 * (d1 - 1L) / 2L)
      if (n_off1 > 0L) map$L_off <- factor(rep(seq_len(n_off1), each = n_lev))
      collapse_applied <- TRUE
    }
  }

  if (!is.null(fixed_global)) {
    if (!is.list(fixed_global) ||
        !identical(sort(names(fixed_global)), c("beta", "theta_rr"))) {
      stop("fixed_global must be a named list containing exactly beta and theta_rr.",
           call. = FALSE)
    }
    ## fixed_global's contract is "hold the GLOBAL parameters at known values".
    ## Once a second tier exists there are global parameters it does not name --
    ## the extra tiers' loadings and log_sd_tier -- so honouring it as written
    ## would fix some of them and leave the rest free, i.e. fit a different
    ## model than the caller asked for while reporting success. Refuse instead.
    if (layout$n_tiers > 1L) {
      stop("fixed_global is defined for the single-tier model only; a multi-tier fit has global parameters it does not name (extra tier loadings, log_sd_tier).",
           call. = FALSE)
    }
    if (length(fixed_global$beta) != ncol(validated$X) ||
        any(!is.finite(fixed_global$beta))) {
      stop("fixed_global$beta has the wrong length or non-finite entries.",
           call. = FALSE)
    }
    ## Unpacking is also an exact validation of the live theta length.
    .va_r3_unpack_theta_rr(fixed_global$theta_rr, validated$T, validated$q)
    parameters$beta <- as.numeric(fixed_global$beta)
    parameters$theta_rr <- as.numeric(fixed_global$theta_rr)
    map$beta <- factor(rep(NA_integer_, length(parameters$beta)))
    map$theta_rr <- factor(rep(NA_integer_, length(parameters$theta_rr)))
  }
  if (!length(map)) map <- NULL
  ## profile_variational = FALSE is the shipped route and reproduces the joint
  ## `random = NULL` objective byte for byte. TRUE hands the variational block
  ## to TMB's inner Newton solver via `profile=`, which appends the named
  ## parameters to `random` WITH THE LAPLACE APPROXIMATION DISABLED -- no
  ## -1/2 log det H term is added, so the outer objective is the EXACT profile
  ## min_{m,L} ELBO(fixed, m, L), not a Laplace approximation of the ELBO.
  ## `random=` alone would be mathematically wrong here: the variational
  ## coordinates are optimisation variables of a deterministic bound, not
  ## latent random variables to integrate over.
  profile_variational <- isTRUE(profile_variational)
  obj <- if (profile_variational) {
    args <- list(
      data = tmb_data, parameters = parameters, map = map,
      profile = .va_r3_variational_names,
      DLL = dll$DLL, silent = silent
    )
    if (!is.null(inner_control)) args$inner.control <- inner_control
    do.call(TMB::MakeADFun, args)
  } else {
    TMB::MakeADFun(
      data = tmb_data,
      parameters = parameters,
      map = map,
      random = NULL,
      DLL = dll$DLL,
      silent = silent
    )
  }
  attr(obj, "va_r3_profiled") <- profile_variational
  attr(obj, "va_r3_match_laplace_residual_sd") <- match_laplace_residual_sd
  ## Report whether the collapse actually fired and, when it did not, WHY. A
  ## silently-refused gate would look identical to a collapse that worked, which
  ## is exactly how an unverified speed claim gets made.
  attr(obj, "va_r3_collapsed") <- collapse_applied
  attr(obj, "va_r3_collapse_note") <- collapse_note
  attr(obj, "va_r3_dll") <- dll
  attr(obj, "va_r3_quadrature") <- rule
  ## Carried so downstream machinery can ASK the objective what its variational
  ## layout is instead of inferring it from parameter-name counts -- which is
  ## exactly the inference that becomes silently wrong at K > 1.
  attr(obj, "va_r3_tiers") <- layout
  obj
}

## Two gradient thresholds with DIFFERENT jobs. They were the same bare literal
## (1e-4) in four places, which is how the health gate came to be calibrated by
## accident.
##
## The HEALTH bar decides whether a start reached the optimum. Its companion
## criterion is objective agreement to `agreement_tolerance` (1e-6) across starts,
## so the defensible bar is the one that admits every point whose objective is
## within 1e-6 of optimal and rejects every point that is not. Measured directly
## (dev/va-speed/45-gradient-vs-objective-gap.R: walk away from a converged par*
## along random directions, record max|gradient| against the objective gap):
##
##   n_obs   admissible max|g|        must-reject max|g|      safe window
##     400   [8.43e-05, 1.13e-02]     [2.01e-02, 170]         (0.0113, 0.0201)
##    1200   [9.72e-05, 9.57e-03]     [1.38e-02, 138]         (0.0096, 0.0138)
##    3200   [2.28e-04, 7.79e-03]     [1.34e-02, 343]         (0.0078, 0.0134)
##
## Two things follow, and the second contradicts the obvious diagnosis. First, the
## old 1e-4 bar was ~130-200x TOO TIGHT -- which is why the 2026-08-03 Step-0 pilot
## got 0/30 healthy fits at n=150 and n=400 while all four starts agreed to 6+
## significant figures. Second, the safe window BARELY MOVES with n_obs, and if
## anything tightens (0.0201 -> 0.0134 over an 8x n range), so making the bar
## relative or N-scaled -- the intuitive fix for "an absolute bar on an extensive
## quantity" -- would scale it the WRONG WAY. A single looser constant is correct.
##
## 5e-3 is chosen to sit below the must-reject floor with margin (2.7x below the
## smallest gradient ever seen with an objective gap >= 1e-6, which is 1.34e-02)
## while still admitting every genuinely-converged start observed across
## n in {50,150,400} x 3 seeds x 4 starts -- the largest of which is 4.97e-03.
## A tighter 1e-3 was tried first and rejected: it left the primary cells at 4/4
## but took n=50 seed 20260803 (gradients 1.99e-03..4.97e-03, all with objective
## gaps under 1e-6, i.e. genuinely converged) from 4/4 to 0/4, losing the cell
## entirely. Erring toward admission is the safer error here BECAUSE the gate does
## not rest on this criterion alone: `agreement_tolerance` independently requires
## the best three objectives to agree to 1e-6, so a start that slips past a
## slightly loose gradient bar is still caught if it is actually at a different
## optimum. The gradient bar's job is to exclude divergence, not to certify
## convergence on its own.
.VA_R3_HEALTH_GRADIENT_TOL <- 5e-3

## The POLISH target is an effort knob, not a verdict: how hard to push before
## giving up. It stays STRICTER than the health bar on purpose -- polishing past
## the bar is cheap and produces better fits, so it must not be relaxed merely
## because the health bar was found to be miscalibrated.
.VA_R3_POLISH_GRADIENT_TARGET <- 1e-4

.va_r3_fit <- function(y, n_trials, X, unit_id, trait_id, q,
                       N = NULL, T = NULL,
                       family = c("binomial", "poisson", "gaussian_anchor",
                                  "nbinom2", "binomial_probit"),
                       link = NULL,
                       unique = FALSE, psi = FALSE, structured = FALSE,
                       provider = NULL, lv = FALSE, missing = FALSE,
                       gaussian_sd = 1, H = 7L,
                       rank_source = c("fixed_fixture", "ml_bic"),
                       fixed_global = NULL, source = NULL, rebuild = FALSE,
                       control = list(eval.max = 2000L, iter.max = 2000L),
                       silent = TRUE, eval_method = c("auto", "jj", "gh", "ac", "ac2"),
                       match_laplace_residual_sd = FALSE,
                       collapse_variational_cov = FALSE,
                       n_starts = 4L,
                       optimizer = c("auto", "nlminb", "lbfgsb"),
                       is_y_observed = NULL,
                       family_codes = NULL,
                       link_ids = NULL,
                       estimate_gaussian_sd = TRUE,
                       extra_tiers = NULL,
                       n_ordinal_cuts_per_trait = NULL,
                       ordinal_offset_per_trait = NULL,
                       ordinal_log_increments_start = NULL,
                       fixed_tweedie_power = NULL,
                       fixed_student_df = NULL,
                       profile_variational = FALSE,
                       inner_control = NULL,
                       ac2_threshold = 1.0) {
  family_choices <- unique(vapply(.va_r3_family_registry, `[[`, character(1L), "family"))
  family_choices <- c(family_choices, "gaussian")
  if (is.null(family_codes)) {
    if (length(family) == 1L) {
      family <- match.arg(family, family_choices)
    } else if (identical(unname(as.character(family)),
                         c("binomial", "poisson", "gaussian_anchor", "nbinom2",
                           "binomial_probit"))) {
      ## Default formal value — match.arg() would return the first choice.
      family <- "binomial"
    }
  }
  if (is.null(link)) {
    link <- if (!is.null(family_codes) || length(family) > 1L) {
      ## Per-row links filled inside validate_data from family codes when needed.
      "logit"
    } else {
      switch(family[1L],
             gaussian_anchor = "identity",
             gaussian = "identity",
             poisson = "log",
             nbinom2 = "log",
             binomial_probit = "probit",
             binomial_cloglog = "cloglog",
             "logit")
    }
  }
  if (is.null(link_ids) && !is.null(family_codes) && length(link) == 1L)
    link_ids <- rep.int(if (identical(link, "probit") && all(family_codes == 1L)) 1L else
                          if (identical(link, "cloglog") && all(family_codes == 1L)) 2L else 0L,
                        length(family_codes))
  rank_source <- match.arg(rank_source)
  eval_method <- match.arg(eval_method)
  optimizer <- match.arg(optimizer)
  ## Resolved below, once validated$family and the eval tier are both known.
  validated <- .va_r3_validate_data(
    y, n_trials, X, unit_id, trait_id, q, N, T, family, link,
    unique, psi, structured, provider, lv, missing, gaussian_sd,
    is_y_observed = is_y_observed, family_codes = family_codes, link_ids = link_ids,
    estimate_gaussian_sd = estimate_gaussian_sd, extra_tiers = extra_tiers,
    n_ordinal_cuts_per_trait = n_ordinal_cuts_per_trait,
    ordinal_offset_per_trait = ordinal_offset_per_trait,
    ordinal_log_increments_start = ordinal_log_increments_start
  )
  ## Validate and resolve eval_method against the family up front, before any
  ## objective is constructed, so a mismatched request fails closed for every
  ## start. Everything downstream reports the RESOLVED bound, not the request,
  ## so an "auto" fit never mislabels which bound it actually evaluated.
  resolved_eval_method <- .va_r3_resolve_eval_method(eval_method, validated$family,
                                                      validated$link_id)
  optimizer <- .va_r3_resolve_optimizer(optimizer, validated$family,
                                        resolved_eval_method, validated$link_id)
  if (validated$q == 0L) {
    return(list(
      status = "not_applicable_rank_zero",
      reason = if (rank_source == "ml_bic") {
        "ML/BIC selected rank zero; there is no latent posterior to approximate."
      } else {
        "The fixed research fixture has rank zero; there is no latent posterior to approximate."
      },
      research_only = TRUE,
      objective_type = .va_r3_objective_type(resolved_eval_method),
      rank_source = rank_source,
      family = switch(family, gaussian_anchor = "gaussian", poisson = "poisson",
                      nbinom2 = "nbinom2", binomial_probit = "binomial_probit",
                      "binomial"),
      link = link,
      unique = FALSE,
      eval_method = resolved_eval_method,
      quadrature = NULL,
      source_commit = NA_character_,
      objective_constructed = FALSE
    ))
  }
  rule <- .va_r3_gh_rule(H)
  ## n_starts is the multi-start agreement gate's width. The DEFAULT STAYS 4 --
  ## this exposes the knob, it does not weaken the gate. Measured cost of the
  ## gate: 3.33x at N=200 and 3.93-4.45x at N=400, with objectives agreeing to
  ## <6e-9 across starts and full parameter vectors to max|dpar| 1.98e-05, so
  ## n_starts = 1 reproduces the same optimum at a quarter of the cost and is
  ## the right setting for benchmarking and for the large-n path.
  ##
  ## Below 3 the gate cannot pass AT ALL -- admitted requires
  ## length(healthy_id) >= 3L (see the health block below) -- so n_starts = 2
  ## would silently force status = failed_health_gate rather than speed anything
  ## up. Values of 2 are therefore rejected outright; 1 is allowed because it is
  ## an explicit, visible opt-out of the gate rather than a silent breakage.
  ## The upper bound is 4 because .va_r3_default_parameters() indexes a
  ## four-entry jitter table by start_id; a fifth start would silently index NA
  ## and produce a non-finite starting vector.
  n_starts <- as.integer(n_starts)
  if (length(n_starts) != 1L || is.na(n_starts) || n_starts < 1L ||
      n_starts == 2L || n_starts > 4L) {
    stop("n_starts must be 1 (gate explicitly bypassed), or 3 or 4 (the gate needs three healthy starts; the jitter table defines four).",
         call. = FALSE)
  }
  starts <- lapply(seq_len(n_starts),
                   function(k) .va_r3_default_parameters(validated, k))
  if (!is.null(fixed_global)) {
    if (!is.list(fixed_global) ||
        !identical(sort(names(fixed_global)), c("beta", "theta_rr"))) {
      stop("fixed_global must be a named list containing exactly beta and theta_rr.",
           call. = FALSE)
    }
    ## Refuse here as well as in .va_r3_make_objective(): overwriting theta_rr
    ## below with a single-tier vector would otherwise reach the objective as a
    ## length mismatch, reported against the wrong cause.
    if (validated$tier_layout$n_tiers > 1L) {
      stop("fixed_global is defined for the single-tier model only; a multi-tier fit has global parameters it does not name (extra tier loadings, log_sd_tier).",
           call. = FALSE)
    }
    if (length(fixed_global$beta) != ncol(validated$X) ||
        any(!is.finite(fixed_global$beta))) {
      stop("fixed_global$beta has the wrong length or non-finite entries.",
           call. = FALSE)
    }
    .va_r3_unpack_theta_rr(fixed_global$theta_rr, validated$T, validated$q)
    for (k in seq_along(starts)) {
      starts[[k]]$beta <- as.numeric(fixed_global$beta)
      starts[[k]]$theta_rr <- as.numeric(fixed_global$theta_rr)
    }
  }
  profile_variational <- isTRUE(profile_variational)
  fits <- vector("list", length(starts))
  objects <- vector("list", length(starts))
  for (k in seq_along(starts)) {
    obj <- .va_r3_make_objective(
      validated, H = H, source = source, rebuild = rebuild && k == 1L,
      parameters = starts[[k]], fixed_global = fixed_global, silent = silent,
      eval_method = eval_method,
      match_laplace_residual_sd = match_laplace_residual_sd,
      profile_variational = profile_variational,
      collapse_variational_cov = collapse_variational_cov,
      inner_control = inner_control,
      ac2_threshold = ac2_threshold,
      fixed_tweedie_power = fixed_tweedie_power,
      fixed_student_df = fixed_student_df
    )
    objects[[k]] <- obj
    opt <- tryCatch(
      .va_r3_run_primary(optimizer, obj, obj$par, control),
      error = function(e) structure(list(message = conditionMessage(e)),
                                    class = "va_r3_optimizer_error")
    )
    if (inherits(opt, "va_r3_optimizer_error")) {
      fits[[k]] <- list(start = k, convergence = NA_integer_,
                        objective = NA_real_, max_abs_gradient = Inf,
                        finite_parameters = FALSE, healthy = FALSE,
                        message = opt$message)
      next
    }
    polish_passes <- 0L
    for (polish in seq_len(2L)) {
      current_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
      if (all(is.finite(current_gradient)) &&
          max(abs(current_gradient)) < .VA_R3_POLISH_GRADIENT_TARGET) break
      candidate <- tryCatch(
        stats::nlminb(opt$par, obj$fn, obj$gr, control = control),
        error = function(e) NULL
      )
      if (is.null(candidate) || !is.finite(candidate$objective) ||
          candidate$objective > opt$objective + 1e-8) break
      opt <- candidate
      polish_passes <- polish
    }
    polish_optimizer <- "nlminb_only"
    post_nlminb_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
    if (!all(is.finite(post_nlminb_gradient)) ||
        max(abs(post_nlminb_gradient)) >= .VA_R3_POLISH_GRADIENT_TARGET) {
      ## L-BFGS-B, not BFGS: BFGS carries a dense inverse-Hessian over the whole
      ## parameter vector, which here includes N*(2q + q(q-1)/2) variational
      ## coordinates, so its cost grows with n while L-BFGS-B's limited memory
      ## stays flat. factr is L-BFGS-B's relative-tolerance control and
      ## 1e-12 / .Machine$double.eps is the translation of BFGS's reltol = 1e-12.
      lbfgsb <- tryCatch(
        stats::optim(opt$par, obj$fn, obj$gr, method = "L-BFGS-B",
                     control = list(maxit = 500L,
                                    factr = 1e-12 / .Machine$double.eps)),
        error = function(e) NULL
      )
      if (!is.null(lbfgsb) && identical(lbfgsb$convergence, 0L) &&
          is.finite(lbfgsb$value) && lbfgsb$value <= opt$objective + 1e-8) {
        opt <- list(
          par = lbfgsb$par, objective = lbfgsb$value,
          convergence = lbfgsb$convergence, message = lbfgsb$message,
          evaluations = lbfgsb$counts, iterations = NA_integer_
        )
        polish_optimizer <- "nlminb_then_lbfgsb"
      }
    }
    gradient <- tryCatch(obj$gr(opt$par), error = function(e) rep(NA_real_, length(opt$par)))
    finite_parameters <- all(is.finite(opt$par))
    max_abs_gradient <- if (length(gradient) && all(is.finite(gradient))) {
      max(abs(gradient))
    } else Inf
    healthy <- identical(opt$convergence, 0L) && is.finite(opt$objective) &&
      finite_parameters && max_abs_gradient < .VA_R3_HEALTH_GRADIENT_TOL
    ## `par` is contractually the FULL parameter vector, variational block
    ## included -- report(), the latent read-out, and every test read it that
    ## way. Under profile_variational the outer optimiser only ever sees the
    ## global block, so re-evaluate at the reported point and take TMB's
    ## last.par, which is the outer point plus the inner solve that produced
    ## the reported objective. Layout and names match the joint object's par
    ## exactly (verified in test-va-r3-profile.R), so nothing downstream has to
    ## know which route produced it.
    outer_par <- opt$par
    if (profile_variational) {
      full_par <- tryCatch({
        obj$fn(opt$par)
        obj$env$last.par
      }, error = function(e) rep(NA_real_, length(obj$env$par)))
      finite_parameters <- finite_parameters && all(is.finite(full_par))
      healthy <- healthy && all(is.finite(full_par))
    } else {
      full_par <- opt$par
    }
    fits[[k]] <- list(
      start = k,
      convergence = opt$convergence,
      objective = unname(opt$objective),
      max_abs_gradient = max_abs_gradient,
      finite_parameters = finite_parameters,
      healthy = healthy,
      message = opt$message,
      par = full_par,
      evaluations = opt$evaluations,
      iterations = opt$iterations,
      polish_passes = polish_passes,
      polish_optimizer = polish_optimizer
    )
    if (profile_variational) fits[[k]]$outer_par <- outer_par
  }
  healthy_id <- which(vapply(fits, `[[`, logical(1), "healthy"))
  objectives <- vapply(fits, `[[`, numeric(1), "objective")
  agreement_range <- Inf
  if (length(healthy_id) >= 3L) {
    agreement_range <- .va_r3_best_three_range(objectives[healthy_id])
  }
  ## n_starts = 1 may reach the same optimum, but it cannot pass the
  ## three-start agreement gate — status stays failed_health_gate so the
  ## bypass is visible (see test-va-r3-prototype.R).
  agreement <- length(healthy_id) >= 3L && agreement_range <= 1e-6
  admitted <- length(healthy_id) >= 3L && agreement
  best_id <- if (length(healthy_id)) {
    healthy_id[which.min(objectives[healthy_id])]
  } else if (any(is.finite(objectives))) {
    which.min(objectives)
  } else {
    NA_integer_
  }
  best <- if (!is.na(best_id)) fits[[best_id]] else NULL
  best_report <- if (!is.na(best_id)) {
    tryCatch(objects[[best_id]]$report(best$par), error = function(e) {
      list(report_error = conditionMessage(e))
    })
  } else NULL
  max_projected_variance <- if (is.list(best_report) &&
      !is.null(best_report$v_by_obs) &&
      all(is.finite(best_report$v_by_obs))) {
    max(best_report$v_by_obs)
  } else Inf
  variance_domain_ok <- max_projected_variance <= 4
  admitted <- admitted && variance_domain_ok
  dll <- attr(objects[[1L]], "va_r3_dll")
  ## The variational block is already in best$par -- read it out rather than
  ## discarding per-unit posterior spread the fit has genuinely estimated.
  latent <- if (!is.null(best) && !is.null(best$par)) {
    tryCatch(
      .va_r3_latent_posterior(best$par, validated$N, validated$q),
      error = function(e) list(scores = NULL, se = NULL,
                               error = conditionMessage(e))
    )
  } else NULL

  list(
    status = if (admitted) {
      "healthy"
    } else if (!variance_domain_ok) {
      "failed_variance_domain"
    } else {
      "failed_health_gate"
    },
    research_only = TRUE,
    objective_type = .va_r3_objective_type(resolved_eval_method),
    rank_source = rank_source,
    family = validated$family_name,
    link = validated$link,
    unique = isTRUE(validated$unique),
    tiers = list(
      n_tiers = validated$tier_layout$n_tiers,
      kind = validated$tier_layout$kind,
      label = validated$tier_layout$label,
      dim = validated$tier_layout$dim,
      n_levels = validated$tier_layout$n_levels,
      structured = validated$tier_layout$structured,
      variational_per_level = validated$tier_layout$variational_per_level,
      total_variational = validated$tier_layout$total_variational
    ),
    structured = if (is.null(validated$structured)) NULL else list(
      n_levels = validated$structured$n_levels,
      log_det_A = validated$structured$log_det_A,
      nnz = length(validated$structured$Ainv@x)
    ),
    q = validated$q,
    eval_method = resolved_eval_method,
    quadrature = list(order = rule$order, convention = rule$convention,
                      nodes = rule$nodes, weights = rule$weights),
    source_commit = .va_r3_source_commit(dll$source),
    source_checksum = dll$checksum,
    fixed_global = !is.null(fixed_global),
    optimizer = optimizer,
    match_laplace_residual_sd = isTRUE(match_laplace_residual_sd),
    fixed_family_parameters = list(
      tweedie_power = fixed_tweedie_power,
      student_df = fixed_student_df
    ),
    profile_variational = profile_variational,
    starts = fits,
    health = list(
      admitted = admitted,
      healthy_starts = length(healthy_id),
      attempted_starts = length(starts),
      minimum_healthy_starts = 3L,
      all_starts_healthy = length(healthy_id) == length(starts),
      objective_agreement = agreement,
      best_three_objective_range = agreement_range,
      gradient_tolerance = .VA_R3_HEALTH_GRADIENT_TOL,
      agreement_tolerance = 1e-6,
      max_projected_variance = max_projected_variance,
      projected_variance_limit = 4,
      variance_domain_ok = variance_domain_ok
    ),
    best = best,
    latent = latent,
    report = best_report,
    objective = if (!is.na(best_id)) objects[[best_id]] else NULL
  )
}
