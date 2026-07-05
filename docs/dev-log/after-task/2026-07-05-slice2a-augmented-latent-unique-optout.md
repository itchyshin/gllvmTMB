# Slice 2a — augmented latent `unique =` opt-out (#608)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `4d8f7589`
Agent: Claude (implementation authorized by Shinichi — Codex out ~3 days)

## Goal

Build the direct fix for issue #608: the augmented ordinary
`latent(1 + x | unit)` random-regression term silently ignored its fold
argument, so users could not opt out of the Gaussian default per-trait
unique-variance diagonal Psi companion. This is the unstarted "Slice 2" of the
2026-06-12 `unique`-fold arc, scoped here to the opt-out only.

## Decisions applied (Shinichi, 2026-07-05)

1. Unify on `unique =` (not `residual =`); `residual =` becomes a soft-deprecated
   alias.
2. `unique = TRUE` default. Clarification: for non-Gaussian families (except
   overdispersed Poisson) the estimated diagonal is **zero**; the family/link
   latent-scale residual is used instead (binomial-probit 1, binomial-logit
   `pi^2/3`, …, per `link_residual_per_trait()`).
3. Re-home the free intercept–slope correlation into
   `latent(1 + x | unit, unique = TRUE)`.

## What changed

- `R/brms-sugar.R`: new helper `.gllvmTMB_resolve_augmented_unique(e)` resolves
  `unique =` (default TRUE) with `residual =` as a `lifecycle::deprecate_warn`
  alias, validates a literal logical, and errors if both are supplied. The
  augmented `latent` desugar branch now calls it and attaches a
  `.latent_augmented_unique` marker to the emitted `rr()`. `@details` prose added
  to the `latent()` roxygen (regenerated `man/latent.Rd`).
- `R/fit-multi.R`: `diag_B_slope_is_default` now additionally requires the marker
  `!= FALSE`, so `unique = FALSE` suppresses the Gaussian default diagonal.
  Backward-compatible: an unset marker (`NULL`) keeps the old default-on
  behaviour.
- `NEWS.md`: entry with a scope-boundary statement (IN: augmented opt-out;
  PARTIAL/PLANNED: ordinary-latent rename + source-tier defaults).
- `docs/design/35-validation-debt-register.md`: MIX-04/MIX-08 interval-status
  clarifications (separate register-hardening item folded into this session).

Design note: the implementation uses a **marker + the engine's existing
Gaussian-only default**, not the 2026-06-12 brief's "parser appends
`diag(.unique_augmented)`" plan. The marker approach matches decision-2's
clarified per-family semantics (non-Gaussian keeps the estimated diagonal off and
uses the link-specific residual) instead of appending a diagonal for every family
and leaning on downstream identifiability guards. Recorded in
`docs/dev-log/2026-07-05-unique-fold-slice2-608-brief.md` (Resolution section).

## Checks run

```sh
# RED first (TDD): marker unset for unique=FALSE — confirmed NULL.
# GREEN:
NOT_CRAN=true Rscript -e 'pkgload::load_all(); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R")'
#   -> 86 pass / 0 fail / 0 warn / 0 skip (incl. 3 new: marker, deprecated alias, fitted opt-out)
# Parser/grammar regression set:
#   test-augmented-lhs-guard.R 33/0, test-canonical-keywords.R 96/0/3skip,
#   test-formula-grammar-smoke.R 28/0, test-keyword-grid.R 59/0
Rscript -e 'devtools::document(quiet=TRUE)'   # clean, no "documented arg not in usage"
```

Known-DGP recovery (local, Mac, 25 seeds, n_ind=100, n_rep=3, Gaussian): 25/25
converged; recovered vs truth — intercept–slope `rho` trait1 0.433 vs 0.430
(bias +0.003), trait2 −0.113 vs −0.104 (bias −0.009); unique variances coef1
0.463 vs 0.460 (+0.003), coef3 0.155 vs 0.160 (−0.005). The `unique = TRUE`
augmented fit recovers both the free correlation and the per-trait unique
variances.

Not run (deliberate): full `devtools::test()` / `devtools::check()` re-run after
this slice — the baseline was 0/0/0 at `4d8f7589` and this change is localized to
one parser branch + one engine condition with focused + regression coverage
green. A full check belongs in the pre-commit/pre-push gate.

## Review

Self-review of 7 edge cases (backward-compat with unset marker; `&&`
short-circuit safety on `rr_B_slope_idx[1L]`; wide `traits()` path reaching the
resolver; `common = TRUE` aborting before the resolver; resolver edge cases for
NA / length>1 / non-literal / both-args; `deprecate_warn` class): all PASS. The
deprecation-alias and opt-out cases are additionally covered by passing tests. An
independent opus adversarial pass was dispatched; fold its verdict in before the
commit.

## Known limitations / follow-ups

- `unique =` is wired on the ordinary augmented `latent()` only. `phylo_latent()`
  / `spatial_latent()` augmented slope forms do not yet read `unique =` (a
  consistency follow-up, tracked with Slice 2c).
- Slice 2b (unify ordinary intercept-only `latent(residual =)` → `unique =`
  across all forms; large example/test cascade) and Slice 2c (flip source-tier
  defaults `unique = FALSE → TRUE`, breaking) are deferred as separate tested
  slices awaiting maintainer scope confirmation.
- Empirical CI coverage for augmented reaction-norm correlations remains gated
  (register CI-11 / RE-12); a Totoro/DRAC coverage campaign is the claim-bearing
  next step, after a denominator/boundary design gate.
- GitHub issue #608 closure waits for push/PR/merge authority.

## Guards honored

No push/PR/merge. No source-specific `lv = ~ env`. No mixed-family CI claim. No
`pdHess`-as-calibration. No Julia parity. Compute stayed local (Totoro reserved,
currently ~75% lab-loaded; ≤100-core cap noted).
