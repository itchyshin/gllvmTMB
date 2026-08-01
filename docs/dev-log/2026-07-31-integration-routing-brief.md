# Routing brief — connecting `integration=` to the variational engine

**Date:** 2026-07-31. **For:** the next lane, as its first job. **Status:** executable brief, not a
design question. The hard part is already answered; what remains is bounded.

## What exists, and what does not

| piece | state |
|---|---|
| `gllvmTMBcontrol(integration = c("laplace","va","eva"))` | **built**, defaults `"laplace"` |
| the admission fence | **built** — `R/integration-fence.R`, errors not warns, 22 tests |
| `gllvmTMB()` behaviour today | **aborts explicitly** — never silently returns a Laplace fit |
| the engines | **exist** — `.approximation_engine_fit()`, `.va_r3_fit()`, `.eva_fit()` |
| the TMB templates | **exist** — `inst/tmb/gllvmTMB_va_r3.cpp`, `gllvmTMB_eva.cpp`, compiled on demand |
| **the translation layer** | **MISSING. This brief.** |

## The insertion point — verified, not guessed

`.approximation_engine_fit()` wants `(y, n_trials, X, unit_id, trait_id, q, family, link, unique,
eval_method, …)`. Every one of those exists inside `R/fit-multi.R` by **line 2256**:

| engine argument | source in `fit-multi.R` | note |
|---|---|---|
| `X` | `X_fix` — **line 2148** | `stats::model.matrix(parsed$fixed, mf)` |
| `n_trials` | **lines 2192 / 2196** | from `weights`, or `rep(1, length(y))` |
| `trait_id` | **line 2253** | `as.integer(data[[trait]]) - 1L` — already **0-based** |
| `unit_id` | `site_id` — **line 2254** | `as.integer(data[[site]]) - 1L` — already **0-based** |
| `y` | in scope by 2192 | |

`.va_r3_normalise_index()` accepts either 0- or 1-based indexing **provided it is consistent**, so
the 0-based ids pass through unchanged. **Insert the branch immediately after line 2256**, before
any TMB data assembly — the variational route must not build the Laplace objective at all.

`q` comes from the parsed `latent()` term (`d =`); `unique` must be `FALSE` or the fence has already
aborted; `family`/`link` map to `"binomial"`/`"logit"` and `"poisson"`/`"log"`.

## The actual work: the return object

This, not the arguments, is the reason the brief exists. `.approximation_engine_fit()` returns a
research-shaped list; `gllvmTMB()` callers expect a `gllvmTMB_multi`. Decide **explicitly** between:

- **(a) A distinct class**, e.g. `c("gllvmTMB_va", "gllvmTMB")`, with only the methods that are
  honest for it. **Recommended.** It makes every unsupported method a clear error rather than a
  plausible wrong number, and Design 85 §10 already forbids most of what a full `gllvmTMB_multi`
  surface would imply.
- **(b) Fill a `gllvmTMB_multi`** and rely on downstream guards. Cheaper to write, far riskier:
  every extractor becomes a place where an ELBO can be mistaken for a log-likelihood.

**Methods that must FAIL LOUDLY on a variational fit** (Design 85 §10): `logLik`, `AIC`, `BIC`,
`anova`/LRT, model weights, any rank selection by objective value, and any treatment of the inverse
VA Hessian as calibrated uncertainty. **`confint`/`vcov`/`se` must also fail** — `calibrated = FALSE`
holds and 0.6 ships without intervals.

**Methods that should work:** `print`, `summary` (fenced wording), coefficient extraction,
`extract_Sigma_B`-style loading/covariance access, and the fitted values.

## Do these three things, which are already paid for

1. **Call the fence with the real values.** `gllvmTMB()` currently calls
   `.gllvmTMB_check_integration_fence(integration_route, engine = engine)` with only `engine`,
   because `q`/`p`/`n`/`family`/`link` are not yet known at that point. Once routing lands, call it
   **again after parsing** with all of them, so `n >= 100`, `q <= 4`, `p <= 80` and the family/link
   restrictions actually bite. Today they are implemented and tested but not yet reachable from
   `gllvmTMB()`.
2. **Preserve the no-silent-fallback property.** It is the one guarantee this argument currently
   makes. A partly-routed branch that falls through to Laplace on some paths would be worse than
   today's honest abort.
3. **Wire `eval_method`.** `integration = "va"` must map to a definite `eval_method`. **Do not
   default it silently** — the GH-vs-JJ question is what the running Gate 3 campaign exists to
   settle, and `default_tier = "jj"` at `R/va-r3-proto.R:534` is under review. Until the campaign
   reports, either require the caller to be explicit or route to `"gh"` with a comment naming this
   as provisional.

## What NOT to do

- **Do not touch `inst/tmb/*.cpp` or `src/`.** Design 72 §7: TMB/likelihood changes are
  maintainer-discussion + Codex, never a Claude auto-merge. Routing is R-side only.
- **Do not add `"eva"` routing yet** unless the maintainer asks. EVA's degeneracy on this family is
  established as genuine (its own objective scores the runaway 291 nats above the truth), and its
  useful scope is families VA cannot reach — none of which `.eva_fit()` currently supports. Keeping
  `"eva"` as a fenced value that aborts is the honest state.
- **Do not advertise.** No NEWS entry, no vignette, no README line until a validation-register row
  carries VA-vs-LA recovery evidence (Design 72 §7). The Gate 3 campaign is producing exactly that.

## Verification when it lands

`gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))` on an in-fence model returns a fit
whose loadings match `.approximation_engine_fit()` called directly on the same data to numerical
tolerance — that is the whole correctness claim for the routing layer, and it is cheap to assert.
Then: every §10-prohibited method errors; every out-of-fence request errors on the fence; and
`integration = "laplace"` is byte-identical to today's output.

> Related: `R/integration-fence.R` · `R/gllvmTMB.R` (control + abort) ·
> `R/approximation-engine.R:64-78` · `docs/design/85-*` §§10–11 ·
> `docs/dev-log/handover/2026-07-31-claude-handover-va-lane-close.md`
