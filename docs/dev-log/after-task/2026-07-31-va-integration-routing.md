# After-task — routing `integration = "va"` to the variational engine

**Date:** 2026-07-31 · **Platform:** Claude Code · **Branch:**
`claude/va-routing-20260731` (cut from `claude/va-in-06-20260730` @ `8f7a8fea`) ·
**Worktree:** `/private/tmp/gllvmtmb-va-routing` · **Commit:** `8def9781`

## 1. Goal

Build the translation layer between the formula API and the variational (VA-R3) engine, so
that `gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))` returns a fit instead of
aborting — the VA lane's designated first job
(`docs/dev-log/2026-07-31-integration-routing-brief.md`).

## 2. Implemented

- **The route.** `R/va-routing.R` (new): covstruct selection, refusal guards, the data-aware
  fence call, the engine call, and the fitted-object builder. Branch inserted in
  `gllvmTMB_multi_fit()` after the id vectors, before any TMB data assembly.
- **The fitted object.** `c("gllvmTMB_va", "gllvmTMB")`, carrying `call`, `integration`,
  `eval_method`, `family`, `link`, `q`, `p`, `n`, `fence_limits`, `calibrated = FALSE`,
  `package_version` alongside the engine result.
- **The method surface.** `R/va-methods.R` (new): `print`, `summary`, `print.summary`, `nobs`
  written for real; `logLik`, `confint`, `vcov`, `coef`, `residuals`, `fitted`, `deviance`,
  `df.residual`, `weights` fail loudly. 13 NAMESPACE entries.
- **The fence made reachable.** `gllvmTMB()` could previously only check `engine`; it aborted
  before `q`/`p`/`n`/family/link existed, so those limits were implemented and tested but
  could never fire. The route calls the fence a second time with the real values.
- **`"eva"` unchanged** — still aborts. **Laplace unchanged.**

## 3. Files Changed

`R/va-routing.R` (new) · `R/va-methods.R` (new) · `R/gllvmTMB.R` ·
`R/fit-multi.R` · `NAMESPACE` · `man/gllvmTMB_va-methods.Rd` (new) ·
`man/gllvmTMBcontrol.Rd` · `tests/testthat/test-integration-fence.R` ·
`tests/testthat/test-va-routing-oracle.R` (new).

`src/` and `inst/tmb/` untouched (Design 72 §7). No NEWS, vignette, or README change.

## 3a. Decisions and Rejected Alternatives

- **Class excludes `gllvmTMB_multi`** — Design 85 §10 forbids it, and it would be actively
  wrong: the engine result is a different shape, so `nobs.gllvmTMB_multi` returns `0L` on it.
  Verified.
- **Fail loud on `logLik`/`AIC`/`BIC`** — maintainer decision this session, taken knowing it
  is stricter than the field: **gllvm 2.0.13**, the reference VA package, registers
  `logLik`/`confint`/`vcov`/`anova`/`coef` on its fits. The technical ground is that ELBO
  *bound tightness varies between models*, so ELBO-based IC differences are not comparable.
  Alternatives offered and rejected: gllvm parity, and a renamed `elbo()` accessor.
- **No `AIC`/`BIC` methods.** Both call `logLik()` with no `tryCatch`, so one abort covers
  all three. Duplicating it would be two more registrations to keep in sync.
- **Latent options checked by WHITELIST, not blacklist** — so an option added later fails
  loudly rather than being silently ignored. Verified empirically (§6).
- **`eval_method = "gh"`, explicit and PROVISIONAL** — `default_tier = "jj"` is under review
  and Gate 3 exists to settle GH vs JJ, so the route must not inherit a default being
  measured. Recorded on the fit and shown by `print()`.
- **Work done in a separate worktree** — see §8.

## 4. Checks Run

| Check | Result |
|---|---|
| `test-integration-fence.R` | **34 pass**, 0 fail, 0 skip |
| `test-va-routing-oracle.R` | **31 pass**, 0 fail, 0 skip |
| Full suite, pre-change baseline | 8,237 pass, **0 fail**, 2 warn, 786 skip |
| Full suite, final | **8,264 pass, 0 fail**, 2 warn, 785 skip |
| `tools::checkDocFiles` | clean |
| Real `R CMD INSTALL` + dispatch probe | all 9 fail-loud methods registered and erroring; `AIC`/`BIC` error via `logLik`; `nobs` returns 720 |

The oracle check is the correctness claim: a routed fit is identical to calling
`.approximation_engine_fit()` directly on the same data — loadings and ELBO, `tolerance = 1e-8`.
The tight tolerance is justified because the engine contains **no RNG** (no `set.seed`,
`rnorm`, `runif`, or `sample` in `R/va-r3-proto.R`), so its multi-starts are deterministic.

## 5. Tests of the Tests

- The oracle was deliberately **removed from behind `skip_if_not_heavy()`**. It costs ~50 s
  including the one-off TMB compile; gating the only proof that the layer is correct behind a
  normally-unset variable would mean routine CI never ran it. `skip_on_cran()` kept.
- Dispatch was verified under a **real `R CMD INSTALL`**, not `devtools::load_all()`.
  `R/aghq-report.R:176-190` records a CRAN-blocking episode where a method looked registered
  under `load_all()`'s export-all shim and was invisible to real `UseMethod()` dispatch.
- **The oracle's own blind spot is documented in its header**: it proves the two paths compute
  the same thing, not that either reads the formula correctly. A misreading shared by both is
  invisible to it — and that is not hypothetical (§8). Route B now derives its grouping from
  the formula by an independent call-tree walk rather than hardcoding it.

## 6. Consistency Audit

`names(cs$extra)` measured on the selected `rr` covstruct across every latent form, to
confirm the whitelist refuses nothing legitimate:

| form | `extra` | outcome |
|---|---|---|
| `latent(unique = FALSE)` | `[d, lhs_form]` | routes |
| `latent(unique = TRUE)` / bare | `[d, lhs_form]` + `diag` companion | fence rejects on Psi |
| `latent() + unique()` | `[d, lhs_form]` + `diag` companion | fence rejects on Psi |
| `latent(..., lv = ~ x)` | `[d, lv_formula, lhs_form]` | **refused** |
| `indep()` | no `rr` | refused (no latent term) |

Rose independently attacked the whitelist with **9 further forms** and found no over-abort.

## 7. Roadmap Tick

Unblocks the VA half of the 0.6 opt-in story. Makes no accuracy or capability claim: Gate 3
is still running (451/2,160 cells at time of writing) and is what would license one.

## 8. What Did Not Go Smoothly

- **The routing brief was wrong in three places**, each of which changed the work. (i) Its
  "methods that should work" list is registered on `gllvmTMB_multi`, not bare `gllvmTMB`, so
  `print`/`summary` had to be written, not inherited. (ii) Its dangerous-method list was wrong
  in both directions — `logLik`/`vcov` have no defaults and already error, while
  `coef`/`residuals`/`fitted` defaults **succeed silently**. (iii) It never mentions that the
  engine requires a complete crossed design.
- **A hazard the brief did not anticipate.** The Gate 3 campaign's Laplace arm runs a fresh
  `callr::r()` subprocess per fit that calls `devtools::load_all(PKG_DIR)`, and `PKG_DIR` is
  the campaign worktree. Editing `R/` there would let a half-written file be loaded mid-fit,
  and the parse error would be recorded as a genuine fit failure **inside a frozen,
  pre-registered denominator**. All work was therefore done in a separate worktree. This was
  caught before any edit, not after.
- **Rose returned NOT-DONE on the first pass**, with two blocking defects — a latent term at a
  non-unit grouping was silently refitted at the unit level, and `lv = ~x` (constrained
  ordination) was silently fitted unconstrained. Both returned `status = "healthy"` on a
  different model than the user wrote. Her diagnosis: *"a boundary drawn one level too
  shallow."* Fixed as a class (the whitelist and the grouping check), not as two instances.
- **My own bug:** `.va_route_abort()` interpolated cli `{}` in its own frame, so caller
  variables were invisible. Caught by the first test run; fixed with `.envir = parent.frame()`.

## 9. Team Learning

- **Rose:** the oracle-equivalence pattern has a structural blind spot — when the reference
  path is hand-written from the same reading of the input as the path under test, any shared
  misreading passes. That is exactly how the grouping defect survived. Where feasible, derive
  the reference independently; where not, say so in the test header and cover interpretation
  with separate refusal tests.
- **General:** the silent-drop class is not "does it error" but "does it fit the model the
  user wrote". Enumerate what a route *honours* and refuse the complement; do not enumerate
  what to reject.

## 10. Known Limitations And Next Actions

- **The complete-crossed-design requirement is a real scope limit**, and worth surfacing to
  users: `integration = "va"` refuses ragged data, which is the common shape for community /
  JSDM datasets. Gate 3 uses complete designs, so it is unaffected.
- **`gllvmTMBcontrol()` search settings** — `n_init`, `optimizer`, `optArgs`, `start_from`,
  `init_*`, `se` — do not reach the engine and are accepted silently. Recorded in
  `?gllvmTMBcontrol`; they cannot change *which* model is fitted, only how it is searched for.
- **`eval_method` is provisional** and must be revisited when Gate 3 reports.
- **Needs Shinichi:** the estimator (GH vs JJ); the `RMSE_ml` rule R1 vs R2; whether `"eva"`
  stays a fenced value. None is blocked by this work.
- **Not done here:** no NEWS entry, no vignette, no validation-register row. Those wait on
  Gate 3 evidence (Design 72 §7).

> Related: `docs/dev-log/2026-07-31-integration-routing-brief.md` ·
> `docs/dev-log/2026-07-31-gate0-scope-extension-and-s11-departure.md` ·
> `docs/dev-log/2026-07-30-gate3-preregistration.md` ·
> `docs/design/85-highdim-nongaussian-va-formal-contract.md` §§10-11 (READ-ONLY)
