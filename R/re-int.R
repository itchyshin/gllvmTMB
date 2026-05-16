## Documentation-only stub for the bar-syntax `(1 | group)` random-intercept
## keyword used inside gllvmTMB() formulas. The actual machinery lives in
## the parser (R/parse-multi-formula.R), the engine (R/fit-multi.R), and
## the TMB template (src/gllvmTMB.cpp); this file exists so
## `?re_int` returns real documentation.

#' Generic random intercepts `(1 | group)` (bar syntax)
#'
#' A `gllvmTMB()` formula token, modelled on lme4 / glmmTMB syntax, that
#' adds a per-row random intercept indexed by `group`. For each row `o`,
#' the linear predictor gains `u[group(o)]`, where `u` is a vector of
#' length `nlevels(group)` with i.i.d. prior `u_g ~ N(0, sigma^2)`.
#' Multiple bar terms are allowed, each with its own variance component.
#'
#' ## What is and isn't supported
#'
#' Only the random-intercept form `(1 | group)` is implemented in this
#' release. The natural extensions are not yet available:
#'
#' * `(0 + x | group)` — random slopes (no intercept). **Coming in a
#'   future release.**
#' * `(1 + x | group)` — correlated intercept + slope. **Coming in a
#'   future release.**
#' * `(0 + trait | group)` — trait-specific random intercepts. Use the
#'   existing `unique()` / `latent()` covstructs for that pattern.
#'
#' If you write any of these unsupported forms, `gllvmTMB()` aborts with a
#' message naming the unsupported form rather than silently fitting the
#' wrong model.
#'
#' ## Usage
#'
#' Inside a `gllvmTMB()` formula, alongside any of the existing covstruct
#' terms:
#'
#' ```r
#' # Add a study-level random intercept on top of a latent() block:
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2) +
#'                          (1 | study),
#'                 data  = df,
#'                 trait = "trait",
#'                 unit  = "site")
#'
#' # Two random intercepts (e.g. study + dataset):
#' fit <- gllvmTMB(value ~ 0 + trait + (1 | study) + (1 | dataset),
#'                 data  = df,
#'                 trait = "trait")
#' ```
#'
#' The fitted variance components live at
#' `fit$report$log_sigma_re_int` (one entry per `(1|...)` term, in the
#' order the terms appear in the formula); take `exp()` to get
#' `sigma`. The fitted random-intercept BLUPs live at
#' `fit$tmb_obj$env$parList()$u_re_int`, packed by term in the same
#' order; offsets and per-term lengths are recorded in `fit$re_int`.
#'
#' @param condition Bar expression of the form `1 | group`. The right-hand
#'   side `group` must be the unquoted name of a column in `data`; if the
#'   column is not already a factor it is coerced to one.
#'
#' @return A formula marker; never evaluated as a call. The token is
#'   recognised by [gllvmTMB()]'s formula parser via the parens that wrap
#'   `1 | group`.
#'
#' @name re_int
#' @aliases re_int bar_syntax
#' @keywords internal
NULL
