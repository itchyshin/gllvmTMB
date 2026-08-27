## Design 131 Arc 1: independent parser/data oracles for the response-column
## coefficient foundation. No coefficient likelihood is admitted in this arc,
## so these tests deliberately stop before optimisation.

.coef_foundation_long <- function() {
  data.frame(
    site = factor(rep(paste0("s", 1:4), each = 3)),
    trait = factor(rep(c("sp_a", "sp_b", "sp_c"), times = 4),
                   levels = c("sp_a", "sp_b", "sp_c")),
    latitude = rep(c(-1.5, -0.5, 0.5, 1.5), each = 3),
    value = seq_len(12) / 10,
    stringsAsFactors = FALSE
  )
}

.coef_foundation_wide <- function() {
  data.frame(
    site = factor(paste0("s", 1:4)),
    latitude = c(-1.5, -0.5, 0.5, 1.5),
    sp_a = c(0.1, 0.4, 0.7, 1.0),
    sp_b = c(0.2, 0.5, 0.8, 1.1),
    sp_c = c(0.3, 0.6, 0.9, 1.2),
    stringsAsFactors = FALSE
  )
}

.coef_foundation_column_data <- function() {
  data.frame(
    trait = c("sp_a", "sp_b", "sp_c"),
    pathway = factor(c("C3", "C4", "C3")),
    leaf_area = c(10, 20, 30),
    stringsAsFactors = FALSE
  )
}

test_that("column_data alignment is invariant to metadata row order", {
  long <- .coef_foundation_long()
  meta <- .coef_foundation_column_data()
  trait_levels <- levels(long$trait)
  prepared <- .column_data_prepare(meta, "trait", trait_levels, names(long))
  reversed <- .column_data_prepare(
    meta[3:1, , drop = FALSE], "trait", trait_levels, names(long)
  )

  expect_identical(prepared$trait_levels, trait_levels)
  expect_identical(prepared$variables, c("pathway", "leaf_area"))
  expect_identical(prepared$data$trait, trait_levels)
  expect_identical(prepared$data, reversed$data)
  expect_identical(
    .column_data_join(long, prepared, "trait"),
    .column_data_join(long, reversed, "trait")
  )
})

test_that("column_data rejects every malformed key shape before fitting", {
  long <- .coef_foundation_long()
  meta <- .coef_foundation_column_data()
  trait_levels <- levels(long$trait)
  prepare <- function(x, row_names = names(long)) {
    .column_data_prepare(x, "trait", trait_levels, row_names)
  }

  expect_error(prepare(meta[-3, , drop = FALSE]), "missing|exact",
               class = "gllvmTMB_column_data_invalid")
  extra <- rbind(meta, data.frame(
    trait = "sp_d", pathway = factor("C4"), leaf_area = 40
  ))
  expect_error(prepare(extra), "extra|exact",
               class = "gllvmTMB_column_data_invalid")
  duplicated <- meta
  duplicated$trait[3] <- "sp_b"
  expect_error(prepare(duplicated), "duplicat",
               class = "gllvmTMB_column_data_invalid")
  empty <- meta
  empty$trait[3] <- ""
  expect_error(prepare(empty), "empty",
               class = "gllvmTMB_column_data_invalid")
  missing <- meta
  missing$trait[3] <- NA_character_
  expect_error(prepare(missing), "missing|NA",
               class = "gllvmTMB_column_data_invalid")
  expect_error(prepare(meta, c(names(long), "pathway")), "collid|row",
               class = "gllvmTMB_column_data_invalid")

  internal <- meta
  internal$.y_wide_ <- seq_len(nrow(internal))
  expect_error(prepare(internal), "reserved internal",
               class = "gllvmTMB_column_data_invalid")
  names(internal)[names(internal) == ".y_wide_"] <- ".offset_wide_"
  expect_error(prepare(internal), "reserved internal",
               class = "gllvmTMB_column_data_invalid")
  names(internal)[names(internal) == ".offset_wide_"] <- ".multinom_group_"
  expect_error(prepare(internal), "reserved internal",
               class = "gllvmTMB_column_data_invalid")
  names(internal)[names(internal) == ".multinom_group_"] <- ".multinom_L_"
  expect_error(prepare(internal), "reserved internal",
               class = "gllvmTMB_column_data_invalid")

  reserved <- meta
  reserved$species <- paste0("metadata_", seq_len(nrow(reserved)))
  expect_error(
    gllvmTMB(
      value ~ latitude,
      data = long,
      column_data = reserved,
      trait = "trait", unit = "site", family = gaussian()
    ),
    "grouping|fixed-effect metadata only",
    class = "gllvmTMB_column_data_invalid"
  )
})

test_that("long and wide column metadata prepare to the same stacked rows", {
  skip_if_not_installed("tidyr")
  long <- .coef_foundation_long()
  meta <- .coef_foundation_column_data()
  joined_long <- .column_data_join(
    long,
    .column_data_prepare(meta, "trait", levels(long$trait), names(long)),
    "trait"
  )
  rewrite <- rewrite_traits_lhs(
    traits(sp_a, sp_b, sp_c) ~ 0 + shared(1 + latitude),
    data = .coef_foundation_wide(), column_data = meta
  )

  keep <- c("site", "trait", "latitude", "pathway", "leaf_area")
  expect_identical(joined_long[keep], rewrite$data_long[keep])
})

test_that("wide column metadata uses one explicit synthetic trait key", {
  skip_if_not_installed("tidyr")
  meta <- .coef_foundation_column_data()
  names(meta)[names(meta) == "trait"] <- "species"
  expect_error(
    gllvmTMB(
      traits(sp_a, sp_b, sp_c) ~ latitude,
      data = .coef_foundation_wide(),
      column_data = meta,
      trait = "species", unit = "site", family = gaussian()
    ),
    "synthetic response-column key|Omit.*trait",
    class = "gllvmTMB_traits_custom_trait_unsupported"
  )
})

test_that("shared fixed effects are common while ordinary wide effects stay trait-specific", {
  skip_if_not_installed("tidyr")
  wide <- .coef_foundation_wide()
  ordinary <- rewrite_traits_lhs(
    traits(sp_a, sp_b, sp_c) ~ 1 + latitude, data = wide
  )
  common <- rewrite_traits_lhs(
    traits(sp_a, sp_b, sp_c) ~ 0 + shared(1 + latitude), data = wide
  )
  X_ordinary <- stats::model.matrix(
    stats::delete.response(stats::terms(ordinary$formula_long)),
    ordinary$data_long
  )
  X_common <- stats::model.matrix(
    stats::delete.response(stats::terms(common$formula_long)),
    common$data_long
  )

  expect_equal(ncol(X_ordinary), 6L)
  expect_equal(ncol(X_common), 2L)
  expect_identical(colnames(X_common), c("(Intercept)", "latitude"))
  expect_equal(unname(X_common[, "latitude"]), common$data_long$latitude)
  expect_true(all(grepl("trait", colnames(X_ordinary))))
})

test_that("an existing user-defined shared() transformation is preserved", {
  skip_if_not_installed("tidyr")
  shared <- function(x) x^2
  formula <- traits(sp_a, sp_b, sp_c) ~ shared(latitude)
  environment(formula) <- environment()
  rewrite <- rewrite_traits_lhs(
    formula, data = .coef_foundation_wide(), eval_env = environment(formula)
  )
  rendered <- paste(deparse(rewrite$formula_long), collapse = " ")
  expect_match(rendered, "trait.*shared\\(latitude\\)")
})

test_that("shared has the same common fixed-effect meaning in long preprocessing", {
  data <- .coef_foundation_long()
  rhs <- .shared_rewrite(
    quote(0 + shared(1 + latitude)),
    row_vars = names(data),
    response_vars = "value"
  )
  X <- stats::model.matrix(stats::as.formula(call("~", rhs)), data)

  expect_identical(colnames(X), c("(Intercept)", "latitude"))
  expect_equal(unname(X[, "latitude"]), data$latitude)
  expect_error(
    .shared_rewrite(
      quote(shared(value)), row_vars = names(data), response_vars = "value"
    ), class = "gllvmTMB_shared_invalid"
  )
})

test_that("column metadata terms stay fixed while row-only wide terms expand", {
  skip_if_not_installed("tidyr")
  rewrite <- rewrite_traits_lhs(
    traits(sp_a, sp_b, sp_c) ~ latitude + latitude:pathway,
    data = .coef_foundation_wide(),
    column_data = .coef_foundation_column_data()
  )
  labels <- attr(stats::terms(rewrite$formula_long), "term.labels")

  expect_true(any(grepl("trait.*latitude|latitude.*trait", labels)))
  expect_true("latitude:pathway" %in% labels)
  expect_false(any(grepl("trait.*pathway|pathway.*trait", labels)))
})

test_that("shared rejects expressions that are not common row-data fixed effects", {
  skip_if_not_installed("tidyr")
  wide <- .coef_foundation_wide()
  meta <- .coef_foundation_column_data()
  expect_error(
    rewrite_traits_lhs(
      traits(sp_a, sp_b, sp_c) ~ shared(offset(latitude)), data = wide
    ), class = "gllvmTMB_shared_invalid"
  )
  expect_error(
    rewrite_traits_lhs(
      traits(sp_a, sp_b, sp_c) ~ shared(latent(1 | site)), data = wide
    ), class = "gllvmTMB_shared_invalid"
  )
  expect_error(
    rewrite_traits_lhs(
      traits(sp_a, sp_b, sp_c) ~ shared(sp_a), data = wide
    ), class = "gllvmTMB_shared_invalid"
  )
  expect_error(
    rewrite_traits_lhs(
      traits(sp_a, sp_b, sp_c) ~ shared(pathway),
      data = wide, column_data = meta
    ), class = "gllvmTMB_shared_invalid"
  )
  expect_error(
    rewrite_traits_lhs(
      traits(sp_a, sp_b, sp_c) ~ latent(shared(1) | site), data = wide
    ), "top-level additive", class = "gllvmTMB_shared_invalid"
  )
  expect_error(
    .parse_column_coef_formula(
      value ~ column_coef(0 + shared(latitude) | trait),
      trait_col = "trait",
      row_vars = c("site", "trait", "latitude", "value"),
      response_vars = "value"
    ), class = "gllvmTMB_column_coef_invalid_syntax"
  )
})

test_that("all coefficient sources preserve intercept and slope bases", {
  calls <- list(
    column = quote(column_coef(BASIS | trait)),
    phylo = quote(phylo_coef(BASIS | trait, tree = tree)),
    animal = quote(animal_coef(BASIS | trait, pedigree = pedigree)),
    kernel = quote(kernel_coef(BASIS | trait, K = K, name = "environment")),
    spatial = quote(spatial_coef(BASIS | trait, mesh = column_mesh))
  )
  bases <- list(
    intercept = list(expr = quote(1), intercept = TRUE,
                     predictors = character(), basis = "(Intercept)"),
    slope = list(expr = quote(0 + latitude), intercept = FALSE,
                 predictors = "latitude", basis = "latitude"),
    both = list(expr = quote(1 + latitude), intercept = TRUE,
                predictors = "latitude",
                basis = c("(Intercept)", "latitude"))
  )

  for (source in names(calls)) {
    for (basis_name in names(bases)) {
      marker <- calls[[source]]
      marker[[2L]][[2L]] <- bases[[basis_name]]$expr
      formula <- call("~", as.name("value"), marker)
      environment(formula) <- environment()
      spec <- .parse_column_coef_formula(
        formula,
        trait_col = "trait",
        row_vars = c("site", "trait", "latitude", "value"),
        response_vars = "value"
      )

      expect_identical(spec$helper, paste0(source, "_coef"))
      expect_identical(
        spec$source,
        if (identical(source, "column")) "iid" else source
      )
      expect_identical(spec$bar, "|")
      expect_true(spec$correlated)
      expect_identical(spec$intercept, bases[[basis_name]]$intercept)
      expect_identical(spec$predictors, bases[[basis_name]]$predictors)
      expect_identical(spec$basis, bases[[basis_name]]$basis)
      expect_identical(spec$group, "trait")
    }
  }
})

test_that("single and double bars retain the written covariance intent", {
  single <- .parse_column_coef_formula(
    value ~ phylo_coef(1 + latitude | trait, tree = tree),
    "trait", c("site", "trait", "latitude", "value"),
    response_vars = "value"
  )
  diagonal <- .parse_column_coef_formula(
    value ~ phylo_coef(1 + latitude || trait, tree = tree),
    "trait", c("site", "trait", "latitude", "value"),
    response_vars = "value"
  )

  expect_identical(single$basis, diagonal$basis)
  expect_identical(single$bar, "|")
  expect_identical(diagonal$bar, "||")
  expect_true(single$correlated)
  expect_false(diagonal$correlated)
})

test_that("coefficient sources retain fixed and estimated rho intentions", {
  parse <- function(formula) {
    .parse_column_coef_formula(
      formula, "trait", c("site", "trait", "latitude", "value"),
      response_vars = "value"
    )
  }

  iid <- parse(value ~ column_coef(0 + latitude | trait))
  expect_identical(iid$rho_mode, "none")
  expect_null(iid$rho)
  expect_false(iid$map_range_off)
  expect_error(
    parse(value ~ column_coef(0 + latitude | trait, rho = 0.5)),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )

  for (helper in c("phylo_coef", "animal_coef", "kernel_coef")) {
    omitted_call <- call(
      helper, quote(0 + latitude | trait)
    )
    omitted_formula <- call("~", as.name("value"), omitted_call)
    environment(omitted_formula) <- environment()
    omitted <- parse(omitted_formula)
    expect_identical(omitted$rho_mode, "estimated")
    expect_null(omitted$rho)
    expect_false(omitted$map_range_off)

    fixed_call <- call(
      helper, quote(0 + latitude | trait), rho = 0.25
    )
    fixed_formula <- call("~", as.name("value"), fixed_call)
    environment(fixed_formula) <- environment()
    fixed <- parse(fixed_formula)
    expect_identical(fixed$rho_mode, "fixed")
    expect_identical(fixed$rho, 0.25)
    expect_false(fixed$map_range_off)
  }

  spatial_default <- parse(
    value ~ spatial_coef(0 + latitude | trait, mesh = column_mesh)
  )
  expect_identical(spatial_default$rho_mode, "fixed")
  expect_identical(spatial_default$rho, 1)
  expect_false(spatial_default$map_range_off)

  spatial_estimated <- parse(
    value ~ spatial_coef(
      0 + latitude | trait, mesh = column_mesh, rho = NULL
    )
  )
  expect_identical(spatial_estimated$rho_mode, "estimated")
  expect_null(spatial_estimated$rho)
  expect_false(spatial_estimated$map_range_off)

  spatial_identity <- parse(
    value ~ spatial_coef(0 + latitude | trait, mesh = column_mesh, rho = 0)
  )
  expect_identical(spatial_identity$rho_mode, "fixed")
  expect_identical(spatial_identity$rho, 0)
  expect_true(spatial_identity$map_range_off)

  bad_rhos <- list(-0.01, 1.01, c(0.2, 0.8), NA_real_, "estimated")
  for (rho in bad_rhos) {
    marker <- call(
      "phylo_coef", quote(0 + latitude | trait), rho = rho
    )
    formula <- call("~", as.name("value"), marker)
    environment(formula) <- environment()
    expect_error(parse(formula), class = "gllvmTMB_column_coef_invalid_syntax")
  }
})

test_that("coefficient parser rejects malformed bases, groups, and sources", {
  parse <- function(formula, column_vars = character()) {
    .parse_column_coef_formula(
      formula,
      trait_col = "trait",
      row_vars = c("site", "trait", "latitude", "pathway", "value"),
      column_vars = column_vars,
      response_vars = "value"
    )
  }

  expect_error(parse(value ~ column_coef(log(latitude) | trait)),
               class = "gllvmTMB_column_coef_invalid_syntax")
  expect_error(parse(value ~ column_coef(latitude:pathway | trait)),
               class = "gllvmTMB_column_coef_invalid_syntax")
  expect_error(parse(value ~ column_coef(0 | trait)),
               class = "gllvmTMB_column_coef_invalid_syntax")
  expect_error(
    parse(value ~ column_coef(0 + pathway | trait), column_vars = "pathway"),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
  expect_error(parse(value ~ column_coef(0 + value | trait)),
               class = "gllvmTMB_column_coef_invalid_syntax")
  expect_error(
    .parse_column_coef_formula(
      value ~ column_coef(0 + `(Intercept)` | trait),
      "trait",
      c("site", "trait", "latitude", "pathway", "value", "(Intercept)"),
      response_vars = "value"
    ),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
  expect_error(parse(value ~ column_coef(0 + latitude | site)),
               class = "gllvmTMB_column_coef_invalid_syntax")
  expect_error(
    parse(value ~ column_coef(0 + latitude | trait) +
      phylo_coef(0 + latitude | trait, tree = tree)),
    class = "gllvmTMB_column_coef_multiple_sources"
  )
  expect_error(
    parse(value ~ I(column_coef(0 + latitude | trait))),
    "top-level additive",
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
})

test_that("fixed rho resolves in the formula environment", {
  rho_fixed <- 0.25
  spec <- .parse_column_coef_formula(
    value ~ phylo_coef(0 + latitude | trait, rho = rho_fixed),
    "trait", c("site", "trait", "latitude", "value"),
    response_vars = "value"
  )
  expect_identical(spec$rho_mode, "fixed")
  expect_identical(spec$rho, 0.25)
})

test_that("column metadata cannot become covariance or grouping data", {
  skip_if_not_installed("tidyr")
  expect_error(
    gllvmTMB(
      traits(sp_a, sp_b, sp_c) ~ latitude + latent(1 | pathway, d = 1),
      data = .coef_foundation_wide(),
      column_data = .coef_foundation_column_data(),
      unit = "site", family = gaussian()
    ),
    "fixed-effect metadata only",
    class = "gllvmTMB_column_data_invalid"
  )
})

test_that("rank overlap rejects saturated coefficients but allows group means", {
  data <- .coef_foundation_long()
  data$pathway <- factor(
    c(sp_a = "C3", sp_b = "C4", sp_c = "C3")[as.character(data$trait)]
  )

  intercept_formula <- value ~ 0 + trait + column_coef(1 | trait)
  intercept_spec <- .parse_column_coef_formula(
    intercept_formula, "trait", names(data), response_vars = "value"
  )
  X_intercept <- stats::model.matrix(~ 0 + trait, data)
  Z_intercept <- stats::model.matrix(~ 0 + trait, data)
  expect_equal(
    qr(cbind(X_intercept, Z_intercept))$rank,
    qr(X_intercept)$rank
  )
  expect_error(
    .column_coef_assert_no_overlap(
      intercept_formula, data, "trait", intercept_spec
    ), class = "gllvmTMB_column_coef_fixed_overlap"
  )

  slope_formula <- value ~ (0 + trait):latitude +
    column_coef(0 + latitude | trait)
  slope_spec <- .parse_column_coef_formula(
    slope_formula, "trait", names(data), response_vars = "value"
  )
  X_slope <- stats::model.matrix(~ 0 + trait:latitude, data)
  Z_slope <- stats::model.matrix(~ 0 + trait, data) * data$latitude
  expect_equal(qr(cbind(X_slope, Z_slope))$rank, qr(X_slope)$rank)
  expect_error(
    .column_coef_assert_no_overlap(slope_formula, data, "trait", slope_spec),
    class = "gllvmTMB_column_coef_fixed_overlap"
  )

  pathway_formula <- value ~ latitude:pathway +
    column_coef(0 + latitude | trait)
  pathway_spec <- .parse_column_coef_formula(
    pathway_formula, "trait", names(data), response_vars = "value"
  )
  X_pathway <- stats::model.matrix(~ latitude:pathway, data)
  expect_gt(qr(cbind(X_pathway, Z_slope))$rank, qr(X_pathway)$rank)
  expect_true(isTRUE(.column_coef_assert_no_overlap(
    pathway_formula, data, "trait", pathway_spec
  )))
})

test_that("wide saturated fixed coefficients fail before the engine fence", {
  skip_if_not_installed("tidyr")
  expect_error(
    gllvmTMB(
      traits(sp_a, sp_b, sp_c) ~ 1 + column_coef(1 | trait),
      data = .coef_foundation_wide(),
      trait = "trait", unit = "site", family = gaussian()
    ), class = "gllvmTMB_column_coef_fixed_overlap"
  )
})

test_that("valid structured coefficient syntax retains the engine fence", {
  expect_error(
    gllvmTMB(
      value ~ latitude + phylo_coef(0 + latitude | trait, rho = 1),
      data = .coef_foundation_long(),
      trait = "trait", unit = "site", family = gaussian()
    ), class = "gllvmTMB_column_coef_engine_not_admitted"
  )
})
