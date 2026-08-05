# VA integration surface — what is already wired, and what it admits

**Date:** 2026-08-05 · **Status:** READ-ONLY architecture survey (Emmy). No code touched.
**Why this exists:** a session set out to "give VA a front door" and discovered the front door is
already built. This records the actual surface so nobody proposes building it again.

## 🔴 The correction

**VA is not pre-integration.** `gllvmTMBcontrol(integration = "va")` already exists
(`R/gllvmTMB.R:1487`), is wired end-to-end from `gllvmTMB()` into `.va_r3_fit()`, is fenced,
is documented, and has a dedicated test suite (`tests/testthat/test-integration-fence.R` plus
~10 `test-va-*.R` files).

Statements of the form *"VA has no user-facing entry point"* or *"there is no way to produce a
`gllvmTMB_va` object"* are **false**. They were made earlier in this lane on the basis of
`grep -c va_r3 NAMESPACE` = 0, which measures whether the **prototype fitter** is exported — a
different question from whether the **route** is reachable.

## 1. Dispatch point

`R/fit-multi.R:2270-2278`, inside `gllvmTMB_multi_fit()` (`R/fit-multi.R:333`):

```r
integration_route <- control$integration %||% "laplace"
if (!identical(integration_route, "laplace")) {
  ...
  return(.gllvmTMB_va_route(parsed = parsed, y = y, ...))
}
```

The maintainer's own comment names it: *"Every engine input now exists in the right form, and
nothing of the Laplace objective has been assembled yet."*

## 2. What the parser hands over

Straight pass-through to `.va_r3_fit()`: `y`, `n_trials`, `X_fix`, `site_id` (unit, 0-based),
`trait_id`, `n_sites`/`n_traits`, `is_y_observed` (`R/va-routing.R:143-149`, call at `:366-377`).

Derived in the translation layer: `q` from the matched `rr` covstruct's `$extra$d`
(`R/va-routing.R:169`); `family`/`link` from per-row Laplace codes via `.va_route_family_link()`
(`:47-104`); `unique`/`psi` inferred from a companion `diag()` sharing the latent's group
(`:226-229`); `eval_method` inferred from family purity, **not a user input** (`:350-354`).

Absent entirely — no formula-grammar analog: `H`, `n_starts`, `optimizer`, `control`,
`collapse_variational_cov`, `profile_variational`, and the rest of the engine's tuning surface.
`R/va-routing.R:356-364` documents that `gllvmTMBcontrol()`'s own search settings (`n_init`,
`optimizer`, `optArgs`, `start_from`, `se`) **silently do not reach this route**.

## 3. What the route admits — a whitelist, not a blacklist

Public fence (`R/integration-fence.R:46-56`): families `binomial`, `poisson`, `gaussian`, one link
each; `q_max = 2`; `p_max = 80`; `n_min = 100`; `unique` must be `FALSE`.

Translation whitelist (`R/va-routing.R:203-250`): **exactly one** ordinary `rr`-kind covstruct, at
the unit grouping, honouring only `d`. Anything else **aborts** with "the variational route cannot
represent" — it is never silently dropped.

Refused: `latent(unique=TRUE)` · constrained ordination `lv = ~x` · `dep()` · augmented
`latent(1+x|g)` · all `phylo_*`/`spatial_*`/`animal_*`/`kernel_*` · `meta_V()` · multiple latent
blocks or non-unit groupings · ordinary `(1|group)` beyond the Psi companion · offsets · non-uniform
weights · REML · `lambda_constraint`/`Xcoef_fixed` · missing predictors · zero-inflation and
delta/hurdle families · ragged designs.

Engine registry (`R/va-r3-proto.R:1160-1258`) has five families; the public fence admits three.
`nbinom2` is "template-admitted but not on the public fence" (`R/va-routing.R:266-272`), and
`binomial_probit` is **deliberately absent** — *"implementing a family is not evidence about it."*

`traits()` wide-format LHS is fine: it desugars in `gllvmTMB()` before the dispatch point.

## 4. The result object and its methods

`.va_r3_fit()` returns a raw list with `research_only = TRUE` hard-coded at both return paths
(`R/va-r3-proto.R:2256`, `:2474`). `.approximation_engine_result()` (`R/approximation-engine.R:43-62`)
re-stamps `research_only = TRUE` and classes it `gllvmTMB_approximation_result`.
`.va_route_build_fit()` (`R/va-routing.R:417-434`) grafts on `call`, `integration`, `eval_method`,
`family`, `link`, `q`, `p`, `n`, `fence_limits`, **`calibrated = FALSE`**, `package_version` and
reclasses to `c("gllvmTMB_va", "gllvmTMB")` — **without removing the research-shaped fields**, so a
public VA fit still literally carries `$research_only = TRUE` and `$engine_result`.

| S3 surface | count | behaviour |
|---|---:|---|
| `print`, `summary`, `nobs` | 3 | **work** (summary is point estimates only, no SE column) |
| `logLik`, `confint`, `vcov`, `coef`, `residuals`, `fitted`, `deviance`, `df.residual`, `weights` | 9 | **refuse deliberately** via `.va_not_defined()` with a reasoned `cli_abort` |
| `AIC`, `BIC` | 2 | break transitively (they call `logLik()` with no `tryCatch`) |
| `predict` | 1 | **no method exists at all** — no `predict.gllvmTMB_va`, no `predict.gllvmTMB` |
| `getLV`, `getLoadings`, `extract_loadings`, `extract_ordination` | 4 | ⚠ break **ungracefully** — unguarded access to `fit$tmb_obj`, `fit$data`, `fit$trait_col`, none of which exist on a VA fit. Fails by undefined-field access, not a clear message |
| ~24 `extract_*` / diagnostic / bootstrap functions | ~24 | break **cleanly** via a shared `!inherits(fit, "gllvmTMB_multi")` guard |

**Nothing was found that silently returns wrong output.** The design leans hard on fail-loud. The
one soft spot is the `getLV`/`extract_ordination` family — a candidate for a cheap guard.

## 5. Precedent — the pattern is already the house pattern

The VA route *is* the precedent: a `gllvmTMBcontrol()` knob; a two-stage hard-fail fence
(`.gllvmTMB_check_integration_fence()`, called early at `R/gllvmTMB.R:516-518` and late at
`R/va-routing.R:260-265`) that **errors, never warns**; a structurally disjoint result class that
does not inherit `gllvmTMB_multi`; and a permanent `calibrated = FALSE`. `aghq` is a second instance
of the same pattern and is declared mutually exclusive with `integration = "va"`
(`tests/testthat/test-integration-fence.R:46`).

`ci_method` (`R/gllvmTMB.R:490`) is a top-level argument, but it selects a post-fit *inference
procedure* on an already-chosen estimator — a different job, not a precedent for an estimator switch.

`lifecycle::badge()` is used widely for experimental/deprecated *functions* but is **not** applied to
the `integration` parameter's docs. An available, unused convention.

## 6. Recommendation — keep the knob; do not add `method=`

**Retain the `gllvmTMBcontrol(integration = "va")` shape.** A top-level
`method = c("laplace", "va")` argument would present VA as a coequal alternative across the whole
formula grammar, when the real surface is a whitelist of exactly one covstruct, three families, and
~11 deliberately-refusing generics. A separate exported function would duplicate the parsing that
`.gllvmTMB_va_route()` already reuses wholesale.

**What "promotion" can and cannot mean.** Design 85 closed **NO-GO** on 2026-07-20
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:1-9`): the prototype stays internal and
outside the shipped method surface, and the decision must not be reopened *"without a genuinely new
evidence source and a separately approved contract."* The `integration="va"` route post-dates that
and cites later evidence (Gate 3 2026-07-31; Designs 107/108) for the narrow region it admits.
`docs/design/va-capability-worklist.md:8-11` (2026-08-03) states the current position:
**"gllvmTMB 0.6 ships Laplace-only; the VA route is a fenced research spike."**

So lifting the research-only framing — enabling `predict`, `vcov`, intervals — is a **statistical
evidence** question, not an architecture question. It is exactly what Arc B's route-selection
campaign exists to answer.

## 7. Cheap follow-ups this survey surfaced

1. Add a `!inherits(fit, "gllvmTMB_multi")` guard to `getLV`/`getLoadings`/`extract_loadings`/
   `extract_ordination` so a VA fit gets a clear message instead of an undefined-field error.
2. Add a `predict.gllvmTMB_va` that refuses via `.va_not_defined()`, matching the other nine, rather
   than falling through to "no applicable method".
3. Consider `lifecycle::badge("experimental")` on the `integration` parameter's documentation.
4. Strip or rename the leftover `$research_only` / `$engine_result` fields on the public VA object,
   or document that they are internal.

None of these are blocking; all are small and reduce reader confusion.

---
*Survey performed read-only by a sub-agent; every claim above carries a `file:line` in the source it
was read from. Transcribed into the repo by Ada because the surveying agent had no write capability.*
