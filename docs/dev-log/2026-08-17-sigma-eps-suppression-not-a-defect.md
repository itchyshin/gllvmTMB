# 2026-08-17 — `sigma_eps` auto-suppression is deliberate, not a silent collapse

**Scope:** issue #1083 (`gllvmTMB_conditional_residual_saturated` warning
gated to `family_id == 0L` only). Recorded here so the next person who
sees a lognormal `sigma_eps` fit to ~1e-3 * sd(y) does not re-discover it
as a bug.

## What #1083 claimed

A lognormal fixture built with `latent(0 + trait | individual, d = 1)`
(default `unique = TRUE`, which adds a diagonal Psi random effect at the
observed unit x trait resolution) fit `sigma_eps` to **0.00064 against a
true 0.4**, residual sd ~0.001, with no warning. The issue read this as
`sigma_eps` silently collapsing toward a degenerate confound, the same
pathology the gaussian-only `gllvmTMB_conditional_residual_saturated`
warning exists to catch, and asked to widen the gate to the continuous
families that share the structure.

## What is actually true

**(a) The fit-time auto-suppression is deliberate and already announced.**
`R/fit-multi.R:5177` — `any_sigma_eps <- any(family_id_vec %in% c(0L, 3L))`
— already treats gaussian (fid 0) and lognormal (fid 3) identically,
because they share one literal `sigma_eps` scalar. When a diagonal random
effect is detected at the per-row (unit x trait) resolution
(`per_row_diag_W || per_row_diag_B`, `R/fit-multi.R:5181-5183`),
`sigma_eps` is not estimated at all — it is fixed and the parameter is
mapped off (`R/fit-multi.R:5197-5210`):

```r
data_sd  <- stats::sd(y)
small_eps <- max(1e-3 * data_sd, 1e-6)
tmb_params$log_sigma_eps <- log(small_eps)
tmb_map$log_sigma_eps    <- factor(NA_integer_)
cli::cli_inform(c(
  "i" = paste0(
    "Auto-suppressing {.code sigma_eps}: ",
    "{.code indep(0 + trait | ", level_lab, ")} is at the per-row level, ",
    "so it already absorbs the observation residual."
  ),
  "*" = "Fixed at {.val {signif(small_eps, 3)}} (~1/1000 of sd(y)) to keep ",
        "the Gaussian density well-defined; the row-level residual ",
        "variance is fully captured by the per-row diagonal term."
))
```

This is a `cli_inform`, printed at fit time, every time this branch
fires. Nothing is silent about it.

**(b) The exact arithmetic behind the "0.00064" number.** Reproducing the
issue's fixture shape (`n_ind = 36`, `Tn = 2`, `latent(0 + trait |
individual, d = 1)`, `family = lognormal()`, true `sigma = 0.4`):

```
sd(y) = 0.708883
small_eps = max(1e-3 * sd(y), 1e-6) = 0.000708883
fit$report$sigma_eps = 0.000708883
```

Match to 6 significant figures. `sigma_eps` is not an estimate that
collapsed — it is `1e-3 * sd(y)`, deterministically, by construction. The
issue's fixture (a different seed) produced `sd(y) ~ 0.64`, giving the
same formula's `0.00064`. **This is what an observer mistakes for a
collapsed estimate**: the number looks like a degenerate MLE because it
is tiny relative to the true 0.4, but it was never estimated — it was
fixed on purpose so the Gaussian/lognormal density stays well-defined
while the diagonal Psi term does the real work of absorbing the row-level
residual.

Shinichi caught the original framing from exactly this observation: that
`sigma_eps` is usually mapped off under this structure, not estimated —
which is the tell that the "silent collapse" read was wrong.

**(c) The real gap was narrower: residuals()-time inconsistency.**
Independently of the fit-time suppression above, `residuals(fit, type =
"randomized_quantile")` / `predictive_check()` carries its own warning,
`gllvmTMB_conditional_residual_saturated`
(`R/predictive-diagnostics.R:412-436`), which exists to tell the user
that the resulting exact-CDF residuals are uninformative (they collapse
toward zero because the diagonal RE already absorbed the observation).
That warning's gate checked `family_id == 0L` only — so a gaussian fit
under this structure warned at residuals-time, but an identically
auto-suppressed lognormal fit did not, even though the exact same
`per_row_diag` structural condition and the exact same `sigma_eps`
mechanism applied to both. Confirmed empirically: on the lognormal
fixture above, `residuals()` produced no warning while `sd(residual) ~
0.0018` (collapsed, uninformative) — the precise pathology the warning
exists to flag.

**Fix landed:** widen `R/predictive-diagnostics.R:423` from
`family_id == 0L` to `family_id %in% c(0L, 3L)`, matching the pre-existing
`any_sigma_eps` fit-time gate exactly. This is not a new judgment call —
it makes the residuals-time diagnostic consistent with a decision the
package already made. Message text kept unchanged (both families share
the literal `sigma_eps` field, so no per-family parameter naming is
needed for this pair, unlike a Gamma/Beta/student extension would need).

Test coverage: `tests/testthat/test-saturated-residual-lognormal.R` —
a saturating lognormal fixture (`unique = TRUE`, default) asserts the
warning fires; a non-saturating control (`unique = FALSE`, no diagonal
Psi at all, `object$use$diag_B` / `object$use$diag_W` both `FALSE`)
asserts it does not. The saturating-fixture test was verified to FAIL
against the pre-fix gate (stashed the fix, re-ran the test file,
`expect_warning(..., class = "gllvmTMB_conditional_residual_saturated")`
failed with "did not throw a warning" as expected; the non-saturating
control still passed) before the fix was restored.

## What remains open: Gamma, Beta, student

These three continuous families (fid 4, 7, 9) have **no** analogous
auto-suppression mechanism at all. `any_sigma_eps` at `R/fit-multi.R:5177`
excludes them; their dispersion parameters (`phi_gamma`, `phi_beta`,
`sigma_student`) are left fully free under the identical per-row-diagonal
structure. This is deliberately NOT touched here.

**Why it is plausible in theory.** The same unbounded-likelihood
direction that motivates gaussian/lognormal's suppression is present
mathematically for these families too: Gamma's density at an exact
per-row fit (`mu_i = y_i` for every row) diverges as `shape -> infinity`
by the same Stirling argument that makes a Gaussian/lognormal density
diverge as `sigma -> 0`; Student-t is a location-scale family with the
same continuous-density-at-a-point behaviour as Gaussian; Beta's
precision parameter plays the analogous role to Gamma's shape.

**Why it is not yet established in practice.** Single-seed reproductions
on the identical fixture shape did NOT show any of the three walking into
that degenerate direction:

| family  | dispersion param | fitted value | true value | diag RE (log-sd) |
|---------|-------------------|--------------|------------|-------------------|
| Gamma   | `phi_gamma`       | 6.1 / 9.8    | 6          | ~ -13.0 / -10.4 (collapsed toward 0, i.e. essentially unused) |
| student | `sigma_student`   | 0.47 / 0.51  | 0.4        | ~ -2.96 / -2.92   |
| Beta    | `phi_beta`        | 15.9 / 27.5  | (~20 target) | ~ -9.65 / -10.3 (collapsed toward 0) |

In each case the optimiser found a well-behaved, non-degenerate local
optimum instead of the theoretically-available unbounded direction. This
is consistent with, not contradictory to, this repo's well-documented
pattern that Laplace/nlminb do not reliably walk into a known-unbounded
direction within default iterations from a single random start (see the
VGH/Laplace silent-divergence findings elsewhere in the dev log).
**Absence of evidence in one seed is not evidence of absence.**

**What would settle it.** A multi-seed (and ideally multi-`n`, multi-`d`)
campaign that deliberately tries to provoke the degenerate direction for
each of Gamma, Beta, and student under the per-row-diagonal structure —
e.g. more extreme starting values, larger `n_ind`, or a profile-likelihood
sweep in the dispersion parameter with the diagonal RE's variance forced
large — before deciding whether these families need (a) an analogous
fit-time auto-suppression parallel to `sigma_eps`'s, (b) a residuals-time
warning without a fit-time fix, or (c) nothing, because the direction
turns out not to be practically reachable by the optimiser at any
plausible starting point. Do not widen the gate to these three without
that evidence or an explicit maintainer decision.

## Provenance

The original issue framing came from a fixture-construction workaround
built during the exact-residuals work (#1082's brown -> green residual
programme). Shinichi caught the error from the observation that
`sigma_eps` is usually mapped off under this structure — the tell that
the fixture was demonstrating deliberate suppression, not a silent
collapse.
