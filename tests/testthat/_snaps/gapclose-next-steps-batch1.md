# get_crs(<empty data frame>) names the fix

    Code
      gllvmTMB::get_crs(data.frame())
    Condition
      Error in `.gllvm_validate_coordinate_names()`:
      ! `dat` must be a non-empty data frame.
      > Pass the data frame that holds your coordinate columns, with at least one row.

# get_crs(<longitude out of range>) names the fix

    Code
      gllvmTMB::get_crs(data.frame(longitude = 200, latitude = 0))
    Condition
      Error in `gllvmTMB::get_crs()`:
      ! Longitude must lie in [-180, 180] and latitude in [-90, 90].
      > Check `ll_names` names the longitude column first and the latitude column second, in that order.

# bare (x | site) random-slope bar-syntax names the fix

    Code
      gllvmTMB:::parse_re_int_call(quote(x | site))
    Condition
      Error in `gllvmTMB:::parse_re_int_call()`:
      ! Bar-syntax `(x | site)` is not yet implemented.
      i Currently only random intercepts `(1 | group)` are supported.
      > There is no supported route for a bare slope-only term; fit separate models, one covariate per group.

# offset() with more than one expression names the fix

    Code
      gllvmTMB:::parse_multi_formula(value ~ offset(a, b))
    Condition
      Error in `walk()`:
      ! `offset()` takes one expression in a long-format formula.
      x Got `offset(a, b)`.
      i The per-trait form `offset(e1, e2, ...)` is wide-format only; in long format each row already names its trait, so one column carries the whole offset.
      > Write `offset(one_column)`, e.g. `offset(log_effort)`.

# student(df = <not > 1>) names the fix

    Code
      gllvmTMB::student(df = 0.5)
    Condition
      Error in `gllvmTMB::student()`:
      ! student(): `df` must be one finite number greater than 1 (got 0.5).
      > Pass e.g. `df = 3`, or omit `df` to estimate it.

# multinomial(link = <non-logit>) names the fix

    Code
      gllvmTMB::multinomial(link = "probit")
    Condition
      Error in `gllvmTMB::multinomial()`:
      ! `multinomial()` supports only the baseline-category logit link.
      > Omit `link` to use the default `"logit"`.

# make_mesh() with a missing cutoff names the fix

    Code
      gllvmTMB::make_mesh(data.frame(x = c(1, 2), y = c(1, 2)), c("x", "y"))
    Condition
      Error in `gllvmTMB::make_mesh()`:
      ! `cutoff` is required for `type = 'cutoff'`.
      > Pass `cutoff` (a minimum vertex separation), or use `type = "kmeans"` or `type = "cutoff_search"` with `n_knots` instead.

# .gllvm_mesh_coordinates(<empty data frame>) names the fix

    Code
      gllvmTMB:::.gllvm_mesh_coordinates(data.frame(), c("x", "y"))
    Condition
      Error in `gllvmTMB:::.gllvm_mesh_coordinates()`:
      ! `data` must be a non-empty data frame.
      > Pass the data frame that holds your coordinate columns, with at least one row.

# gllvmTMBcontrol(aghq = <invalid>) names the fix

    Code
      gllvmTMB::gllvmTMBcontrol(aghq = "bad")
    Condition
      Error in `.gllvmTMB_normalize_aghq()`:
      ! `aghq` must be `FALSE`, "auto", or a single positive integer.
      i `aghq = FALSE` uses the Laplace approximation (the current default).
      i `aghq = "auto"` lets the package choose the node count.
      > Pass `aghq = 9` for a fixed 9-node rule per latent dimension, or omit `aghq` for the default.

# miss_control(engine = <reserved name>) names the fix

    Code
      gllvmTMB::miss_control(engine = "em")
    Condition
      Error in `gllvmTMB::miss_control()`:
      ! `engine = "em"` is a reserved name, not yet supported.
      > Omit `engine` or pass `engine = "laplace"` (the only supported value).

# drop_missing_response_rows() weights-length mismatch names the fix

    Code
      gllvmTMB:::drop_missing_response_rows(value ~ 1, data = data.frame(value = c(1,
        2, NA)), weights = c(1, 2))
    Condition
      Error in `gllvmTMB:::drop_missing_response_rows()`:
      ! `weights` must be a length-3 numeric vector in the long-format API.
      x Got length 2.
      > Pass one weight per row of `data`.

# phylo_indep() with both A and vcv names the fix

    Code
      gllvmTMB::gllvmTMB(value ~ 0 + trait + phylo_indep(x | species, A = A2, vcv = V2),
      data = d, unit = "species")
    Condition
      Error in `rewrite()`:
      ! `phylo_indep()` got both `A` and `vcv`.
      > These are aliases -- supply only one.

# poisson(link = <non-log>) names the fix

    Code
      gllvmTMB::gllvmTMB(value ~ 0 + trait, data = d, family = poisson(link = "identity"),
      unit = "site")
    Condition
      Error in `family_to_id()`:
      ! poisson: only the log link is currently supported.
      > Use `poisson(link = "log")` (the default).

# lognormal() rows with a non-positive response name the fix

    Code
      gllvmTMB::gllvmTMB(value ~ 0 + trait, data = d, family = lognormal(), unit = "site")
    Condition
      Error in `gllvmTMB_multi_fit()`:
      ! Lognormal and Gamma rows: `y` must be strictly positive.
      > Exact zeros need `delta_lognormal()`/`delta_gamma()`, a zero-inflated family, or a count family.

# cbind(successes, failures) with a negative column names the fix

    Code
      gllvmTMB:::.resolve_sparse_phylo_precision(Ainv = matrix(1, 1, 2), levs = "a",
      species_id = 0L)
    Condition
      Error in `gllvmTMB:::.resolve_sparse_phylo_precision()`:
      ! Sparse `phylo_vcv`/`Ainv` must be square.
      > Pass a square matrix with matching row and column names.

# kernel_slope() with a non-square K names the fix

    Code
      gllvmTMB:::.resolve_fixed_column_slope_precision(K = matrix(1, 1, 2), data = data.frame(
        g = factor("a")), group = "g", source_name = "kernel")
    Condition
      Error in `gllvmTMB:::.resolve_fixed_column_slope_precision()`:
      ! `K` for `kernel_slope()` must be a square numeric matrix.
      > Source "kernel" is indexed by 1 response-column level; pass a 1 x 1 numeric matrix.

