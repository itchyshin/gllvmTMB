# gllvmTMB(REML = <non-logical>) names the fix

    Code
      gllvmTMB::gllvmTMB(value ~ 0 + trait, data = df, REML = "x")
    Condition
      Error in `gllvmTMB::gllvmTMB()`:
      ! `REML` must be a single `TRUE` or `FALSE` value.
      > Pass `REML = TRUE` or `REML = FALSE`.

# gllvmTMBcontrol(se = <non-logical>) names the fix

    Code
      gllvmTMB::gllvmTMBcontrol(se = "x")
    Condition
      Error in `gllvmTMB::gllvmTMBcontrol()`:
      ! `se` must be a single `TRUE` or `FALSE` value.
      > Pass `se = TRUE` or `se = FALSE` to `gllvmTMBcontrol()`.

# (1 | a + b) names how to build a combined grouping column

    Code
      gllvmTMB:::parse_re_int_call(quote(1 | a + b))
    Condition
      Error in `gllvmTMB:::parse_re_int_call()`:
      ! Right-hand side of `(1 | group)` must be a single column name.
      > Build a combined column first, e.g. `interaction(a, b)` or `paste(a, b)`, and group by that column instead.

# isdm_source() with a non-family object names the fix

    Code
      gllvmTMB::isdm_source("notafamily", ~x)
    Condition
      Error in `gllvmTMB::isdm_source()`:
      ! `family` must be an R <family> object.
      > Pass a family constructor, e.g. `poisson(link = "log")` or `binomial("cloglog")`.

# isdm_sources() with duplicate source names names the fix

    Code
      gllvmTMB::isdm_sources(a = poisson(), a = poisson())
    Condition
      Error in `gllvmTMB::isdm_sources()`:
      ! Source names must be unique; "a" is declared twice.
      > Rename one of the `isdm_sources()` arguments so every source has a distinct name.

# multinomial() with a multi-column response names the fix

    Code
      gllvmTMB::gllvmTMB(cbind(a, b) ~ 0 + trait, data = df, family = gllvmTMB::multinomial(),
      unit = "site")
    Condition
      Error in `expand_multinomial_response()`:
      ! multinomial(): the response must be a single categorical variable on the formula LHS.
      > Write the formula as `category ~ ...`, where `category` is a factor.

