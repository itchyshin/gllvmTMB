# VA/EVA comparator smoke receipt

**Scope:** private `dev/va-eva-comparator.R` only.  This is not package API
or an admission result.

## Adapter contract consumed

`R/approximation-engine.R` returns a `gllvmTMB_approximation_result` with
engine-specific `objective_type`, diagnostics, provenance, `score`,
fixed/fitted quantities, and the raw private result. The only numeric score is
engine-specific and signed negative: VA has `negative_elbo_gh`, EVA has
`negative_ell_eva_taylor2`; each is explicitly `direction = "minimize"` and
`model_selection_comparable = FALSE`. VA-R3 is only complete multi-trial
binomial-logit; sealed EVA is only a fixed complete Bernoulli-logit fixture.

## Commands and results

```sh
VA_EVA_COMPARATOR_SMOKE=true Rscript --vanilla dev/va-eva-comparator.R
```

The executable smoke sources the private prototypes plus the revised adapter,
evaluates the sealed fixed EVA `bernoulli` fixture, and asserts all of the
following:

- EVA exposes only `negative_ell_eva_taylor2`, marked `minimize` and not
  model-selection comparable.
- EVA is explicitly unavailable as a fitted result: fitted quantities and
  probabilities are unavailable, while `beta` and `LambdaLambdaT` are empty.
- A supplied precomputed EVA oracle stays reference-only: no fitted gap is
  manufactured from a fixed evaluation.
- A retained VA failure exposes only `negative_elbo_gh`, also marked
  `minimize` and not model-selection comparable.
- Laplace and gllvm remain reference-only `not_run` hooks.

Result:

```text
VA_EVA_COMPARATOR_CONTRACT_SMOKE_PASS
```

```sh
Rscript --vanilla dev/va-eva-engine-spine/check-sealed-sources.R .
```

Passed all sealed EVA byte checks, the clean VA-spine checks, and the prohibited
`2392996b` input-absence checks.

## Explicit boundaries

- VA and EVA expose different signed negative quantities and neither is
  model-selection comparable; the comparator never forms a shared score.
- Exact quantities can be supplied only as precomputed oracle/reference lists;
  no exact-truth function is accepted or called, and EVA has no fitted gap.
- Laplace and gllvm are reference-only, `not_run` hooks. No Laplace/gllvm truth
  computation was called.
- No VA Bernoulli widening, Gate-2/Gate-2R runner, public package file, or
  admission claim was added.
