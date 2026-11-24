## Dense Gaussian oracle for the lacertid-size mean geometry. Uses only the
## frozen, response-free design (Brownian A, standardized size, and mask).
## Response values are synthetic zeros; no observed-data fit is attempted.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, dir.exists(args[[1L]]))
coevolution <- normalizePath(args[[1L]], mustWork = TRUE)
design_path <- file.path(
  coevolution,
  "analysis/lacertid-factor-map-20261114/run-01/design-only.rds"
)
stopifnot(file.exists(design_path))
design <- readRDS(design_path)
fields <- c("trunk", "headlength", "headwidth", "headheight",
            "mouthopening", "forelimblength", "hindlimblength")
species <- as.character(design$species)
A <- as.matrix(design$A)
I <- diag(length(species))
dimnames(I) <- list(species, species)
mask <- as.matrix(design$declared_mask)
size <- as.numeric(design$x)
stopifnot(identical(dim(A), c(186L, 186L)),
          identical(dim(mask), c(186L, 7L)), length(size) == 186L,
          all(is.finite(A)), all(is.finite(size)), all(mask %in% c(0, 1)))

Y <- matrix(NA_real_, nrow = length(species), ncol = length(fields),
            dimnames = list(species, fields))
Y[mask != 0] <- 0
dat <- data.frame(species = factor(species, levels = species), Y,
                  check.names = FALSE)
formula <- stats::as.formula(paste0(
  "traits(", paste(fields, collapse = ","),
  ") ~ 1 + kernel_latent(species, K = A, d = 1, name = 'phy', unique = TRUE) + ",
  "kernel_latent(species, K = I, d = 1, name = 'tip', unique = TRUE)"
), env = environment())

captured <- NULL
testthat::test_that("lacertid size slopes match the dense Gaussian oracle", {
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, ...) {
      captured <<- c(list(data = data, parameters = parameters), list(...))
      stop("LACERTID_EXACT_ROUTE_CAPTURE", call. = FALSE)
    },
    .package = "TMB"
  )
  error <- tryCatch({
    gllvmTMB::gllvmTMB(
      formula, data = dat, family = stats::gaussian(), unit = "species",
      cluster = "species", missing = gllvmTMB::miss_control(response = "include"),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE), known_sigma_eps = 0,
      silent = TRUE
    )
    NULL
  }, error = conditionMessage)
  testthat::expect_identical(error, "LACERTID_EXACT_ROUTE_CAPTURE")
})

input <- captured
data <- input$data
n_trait <- length(fields)
observed <- data$exact_eta_index + 1L
trait_id <- data$exact_trait_id
unit_id <- data$exact_unit_id
size_design <- matrix(0, nrow = nrow(data$X_fix), ncol = n_trait)
for (j in seq_len(n_trait)) {
  take <- trait_id == (j - 1L)
  size_design[data$exact_eta_index[take] + 1L, j] <- size[unit_id[take] + 1L]
}
colnames(size_design) <- paste0("size_", fields)
input$data$X_fix <- cbind(data$X_fix, size_design)
beta_size <- c(-0.30, 0.18, 0.24, -0.12, 0.33, -0.21, 0.27)
input$parameters$b_fix <- c(input$parameters$b_fix, beta_size)
obj <- do.call(TMB::MakeADFun, input)
parameters <- obj$env$parList(obj$par)

.unpack_exact_loadings <- function(theta, n_trait, rank) {
  Lambda <- matrix(0, nrow = n_trait, ncol = rank)
  cursor <- 1L
  for (column in seq_len(rank)) {
    Lambda[column, column] <- theta[cursor]
    cursor <- cursor + 1L
  }
  for (column in seq_len(rank)) {
    if (column < n_trait) {
      for (row in seq.int(column + 1L, n_trait)) {
        Lambda[row, column] <- theta[cursor]
        cursor <- cursor + 1L
      }
    }
  }
  Lambda
}
Sigma <- vector("list", 2L)
theta_cursor <- 1L
for (r in seq_len(2L)) {
  packed_n <- n_trait * data$kernel_rank[r] -
    data$kernel_rank[r] * (data$kernel_rank[r] - 1L) / 2L
  theta_idx <- theta_cursor:(theta_cursor + packed_n - 1L)
  Lambda <- .unpack_exact_loadings(
    parameters$theta_rr_kernel[theta_idx], n_trait, data$kernel_rank[r]
  )
  theta_cursor <- theta_cursor + packed_n
  psi_idx <- ((r - 1L) * n_trait + 1L):(r * n_trait)
  Sigma[[r]] <- tcrossprod(Lambda) + diag(parameters$psi_kernel_variance[psi_idx])
}
source(file.path(getwd(), "tests/testthat/helper-paired-exact-oracle.R"))
mean <- drop(input$data$X_fix[observed, , drop = FALSE] %*% parameters$b_fix) +
  input$data$offset_vec[observed]
oracle <- .paper2_marginal_gaussian(
  y = input$data$exact_y,
  unit_id = unit_id + 1L,
  trait_id = trait_id + 1L,
  K_phy = input$data$K_kernel_raw[1L, , ],
  K_tip = input$data$K_kernel_raw[2L, , ],
  Sigma_phy = Sigma[[1L]], Sigma_tip = Sigma[[2L]],
  V_known = input$data$V_known_marginal, mean = mean
)
testthat::expect_equal(obj$fn(obj$par), oracle$nll, tolerance = 1e-8)

upper <- chol(oracle$covariance)
residual <- input$data$exact_y - mean
alpha <- backsolve(upper, forwardsolve(t(upper), residual))
X_observed <- input$data$X_fix[observed, , drop = FALSE]
gradient_dense <- drop(-crossprod(X_observed, alpha))
base_parameters <- obj$env$parList(obj$par)
beta_indices <- rep(NA_integer_, length(base_parameters$b_fix))
for (i in seq_along(obj$par)) {
  perturbed <- obj$par
  perturbed[i] <- perturbed[i] + 1e-5
  changed <- obj$env$parList(perturbed)$b_fix - base_parameters$b_fix
  changed_index <- which(abs(changed) > 1e-10)
  if (length(changed_index) == 1L) beta_indices[changed_index] <- i
}
testthat::expect_true(all(is.finite(beta_indices)))
gradient_native <- obj$gr(obj$par)[beta_indices]
gradient_gap <- max(abs(gradient_native - gradient_dense))
testthat::expect_lt(gradient_gap, 2e-5)

cat(sprintf(paste0(
  "LACERTID_SLOPE_ORACLE=PASS; n=186; traits=7; observed_cells=%d; ",
  "nonzero_trait_slopes=7; objective_gap=%.3g; fixed_mean_gradient_gap=%.3g; ",
  "observed_responses_read=FALSE; optimizer=not_started\n"
), length(input$data$exact_y), abs(obj$fn(obj$par) - oracle$nll), gradient_gap))
