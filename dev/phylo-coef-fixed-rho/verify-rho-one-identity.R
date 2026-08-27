devtools::load_all(quiet = TRUE)

make_fixture <- function(seed, use_tree = FALSE) {
  set.seed(seed)
  traits <- paste0("t", seq_len(6L))
  data <- expand.grid(
    unit = factor(paste0("u", seq_len(18L))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  data$x <- stats::rnorm(nrow(data))
  data$z <- stats::rnorm(nrow(data))
  data$value <- 0.2 + stats::rnorm(nrow(data), sd = 0.45)
  d <- seq(0.65, 1.35, length.out = length(traits))
  R <- exp(-abs(outer(seq_along(traits), seq_along(traits), "-")) / 2.5)
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)
  tree <- NULL
  if (use_tree) {
    stopifnot(requireNamespace("ape", quietly = TRUE))
    tree <- ape::rcoal(length(traits))
    tree$tip.label <- traits
  }
  list(data = data, K = K, tree = tree)
}

rewrite_private <- function(formula, data) {
  spec <- gllvmTMB:::.parse_column_coef_formula(
    formula = formula,
    trait_col = "trait",
    row_vars = names(data),
    column_vars = character(),
    response_vars = all.vars(formula[[2L]])
  )
  formula[[3L]] <- gllvmTMB:::.column_coef_rewrite_fixed_phylo(
    formula[[3L]], spec, data = data, envir = environment(formula)
  )
  formula
}

fit_model <- function(fx, formula, private = FALSE) {
  if (private) formula <- rewrite_private(formula, fx$data)
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
}

map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) {
    if (is.null(x)) NULL else as.integer(x)
  })
}

assert_identical_route <- function(coef_fit, slope_fit) {
  common <- slope_fit$opt$par
  stopifnot(
    identical(coef_fit$tmb_data, slope_fit$tmb_data),
    identical(coef_fit$tmb_obj$env$random, slope_fit$tmb_obj$env$random),
    identical(names(coef_fit$opt$par), names(slope_fit$opt$par)),
    identical(map_signature(coef_fit), map_signature(slope_fit)),
    identical(coef_fit$tmb_obj$fn(common), slope_fit$tmb_obj$fn(common)),
    identical(coef_fit$tmb_obj$gr(common), slope_fit$tmb_obj$gr(common)),
    identical(coef_fit$opt$objective, slope_fit$opt$objective),
    identical(coef_fit$opt$par, slope_fit$opt$par),
    identical(coef_fit$report, slope_fit$report),
    identical(suppressMessages(stats::fitted(coef_fit)),
              suppressMessages(stats::fitted(slope_fit)))
  )
}

fx <- make_fixture(13122L)
dense_pairs <- list(
  list(
    value ~ 0 + trait + phylo_coef(0 + x + z | trait, vcv = fx$K, rho = 1),
    value ~ 0 + trait + phylo_slope(x + z | trait, vcv = fx$K)
  ),
  list(
    value ~ 0 + trait + phylo_coef(0 + x + z || trait, vcv = fx$K, rho = 1),
    value ~ 0 + trait + phylo_slope(x + z || trait, vcv = fx$K)
  )
)
for (pair in dense_pairs) {
  assert_identical_route(
    fit_model(fx, pair[[1L]], private = TRUE),
    fit_model(fx, pair[[2L]])
  )
}

fx <- make_fixture(13123L, use_tree = TRUE)
tree_pairs <- list(
  list(
    value ~ 0 + trait + phylo_coef(0 + x | trait, tree = fx$tree, rho = 1),
    value ~ 0 + trait + phylo_slope(x | trait, tree = fx$tree)
  ),
  list(
    value ~ 0 + trait + phylo_coef(0 + x || trait, tree = fx$tree, rho = 1),
    value ~ 0 + trait + phylo_slope(x || trait, tree = fx$tree)
  )
)
for (pair in tree_pairs) {
  assert_identical_route(
    fit_model(fx, pair[[1L]], private = TRUE),
    fit_model(fx, pair[[2L]])
  )
}

cat("PHYLO_COEF_RHO_ONE_IDENTITY_OK\n")
