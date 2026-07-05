# Slice 2 brief — fold augmented `*_unique(1 + x | g)` into `latent`, and #608

Date: 2026-07-05 · Author: Claude (gllvmTMB completion arc) · Status: **decision
brief — awaiting maintainer steer on three items before any code.** Continues
the 2026-06-12 psi-fold arc (`2026-06-12-slice1-latent-psi-fold-brief.md`,
`2026-06-12-unique-removal-codereview.md`). Formula-grammar checkpoint — do not
implement without maintainer go.

## Why this note exists

Issue #608 ("augmented `latent(1 + x | unit)` silently ignores `residual =` and
never adds a Psi companion") is not a stray bug. It is the **unstarted Slice 2**
of the `unique`-fold arc. Slice 1 folded ordinary + standalone/paired `unique`
into `latent`'s default Psi; the Slice 1 brief explicitly put augmented
`*_unique(1 + x | g)` **out of scope** ("Slice 2 — it folds into
`latent(1 + x | g)` later"; point 7: "Augmented `unique(1 + x | g)` → unchanged").
So augmented `latent(1 + x | unit)` returning a bare `rr()` and dropping the
fold argument is the documented Slice-1 boundary, and #608 is the request to
build Slice 2.

## The arc, as recovered (evidence)

- **The fold rationale (2026-06-12 code-review).** Psi enters the linear
  predictor additively before the family density (`src/gllvmTMB.cpp:1609-1630`);
  the family then adds its own dispersion. So Psi is the *meaningful residual*
  for Gaussian/lognormal/Gamma, a *legitimate OLRE* for Poisson,
  *unidentifiable* for single-trial binary / ordinal (auto-skipped), and
  *redundant double-dispersion* for nbinom/Beta/Tweedie/betabinom. `unique` is
  therefore essentially Gaussian-meaningful, which is why the family was removed
  and folded into `latent`.
- **`unique = TRUE` is level-general.** Psi can attach at any latent tier (unit,
  unit_obs, cluster, phy, spatial). The source latents already expose it as an
  argument: `spatial_latent(..., unique = FALSE)` / `phylo_latent` — `unique =
  TRUE` keeps both the shared low-rank field `Lambda Lambda^T` and the per-trait
  unique diagonal `Psi`, giving `Sigma = Lambda Lambda^T + diag(Psi)`.
- **`sigma_eps` suppression is a separate lowest-level consequence.** The engine
  auto-suppresses scalar Gaussian `sigma_eps` **only when a Psi diagonal sits at
  the per-row level** (`fit-multi.R:3763-3780`, keyed off `per_row_diag_* +
  family_id`, keyword-agnostic). This matches DECISIONS D-28: "call trait-diagonal
  variance *unique*, not residual; when unique is active at the lowest level,
  `sigma_eps` is suppressed/fixed tiny." Psi at higher tiers does not suppress
  `sigma_eps`. (Correction to an earlier misread: unique is not lowest-level-only;
  only the suppression is.)
- **Argument-naming inconsistency the arc left open:**
  - ordinary `latent(formula, d, residual = TRUE, common = FALSE)` → `residual =`,
    default **ON** (`R/brms-sugar.R:435`);
  - `spatial_latent(..., unique = FALSE)` / phylo → `unique =`, default **OFF**
    (`R/brms-sugar.R:990`).
  The same fold concept has two names and two defaults.
- **The free-correlation capability at stake (code-review decision #1).**
  Augmented `*_unique(1 + x | g)` is the only path giving a *free*
  intercept–slope correlation; the `*_indep` augmented path pins it to 0.
  Removing the `unique` family loses that unless it is re-homed into
  `latent(1 + x | g)`. Slice 2 is that re-homing.

## Decisions required (maintainer) before code

1. **Naming.** For the augmented fold argument, use `unique =` (consistent with
   the source latents and D-28's "unique, not residual"). Open sub-question:
   also alias ordinary `latent()`'s `residual =` to `unique =` so the whole
   family is consistent (with a deprecation path for `residual =`)?
2. **Default.** `unique = TRUE` by default on augmented latent (matching ordinary
   `latent()`'s `residual = TRUE` default) or `unique = FALSE` (matching source
   latents)? The two current defaults disagree; Slice 2 should pick one story.
3. **Free-correlation reaction norm.** Re-home the free intercept–slope
   correlation into `latent(1 + x | unit, unique = TRUE)` (finish Slice 2), or
   keep augmented latent low-rank-only and require an explicit companion term?

## Implementation surface (once decided)

- **Parser** (`R/brms-sugar.R:2684-2723`, the augmented `latent` branch): read
  the fold argument (per decision 1/2); when on, append the augmented diagonal
  companion. The machinery already exists: the augmented `unique(1 + x | g)`
  branch (`:2876-2894`) builds `diag(.unique_augmented = TRUE)`, and the ordinary
  `latent` branch (`:2858-2863`) appends `diag(.latent_psi = TRUE)`. Slice 2
  mirrors that for the augmented `latent` return so it emits
  `rr(.latent_augmented) + diag(.unique_augmented)`.
- **Engine** (`R/fit-multi.R`): already consumes `rr_B_slope` with and without
  `diag_B_slope`; the `sigma_eps` auto-suppression is keyword-agnostic. Verify
  the combined `rr_B_slope + diag_B_slope` path builds and that the free
  intercept–slope correlation lands where decision 3 expects. **No C++ change
  anticipated** (the arc's code-review confirmed the fold is R-side-only; Psi is
  gated by integer flags).
- **Tests (ship with engine):** (a) `latent(1 + x | unit, unique = FALSE)` ==
  current bare-`rr()` augmented fit (byte-identity); (b) `unique = TRUE` adds the
  augmented diagonal and, for Gaussian at the per-row level, suppresses
  `sigma_eps`; (c) free intercept–slope correlation is estimated (not pinned to
  0) under the decision-3 route; (d) the fold arg is honored, not silently
  dropped (the direct #608 regression). Curie signs off.
- **Docs cascade:** grid note (`AGENTS.md` / `CLAUDE.md` /
  `01-formula-grammar.md`), design 55 (structural-slope grammar), register row(s),
  NEWS scope-boundary statement, `decisions.md` entry, and the augmented-latent
  example pages.

## Guards

- Formula-grammar + default-semantics change → maintainer sign-off before merge;
  no push/PR/merge without Shinichi.
- Non-Gaussian augmented `unique = TRUE` inherits the family redundancy story
  (double-dispersion for nbinom/Beta/Tweedie; unidentifiable for single-trial
  binary/ordinal) — keep the existing identifiability guards; do not advertise a
  non-Gaussian augmented Psi as a clean new capability.
- `sigma_eps` suppression stays automatic and lowest-level-only; do not extend it
  to higher tiers.

## Status

Green baseline confirmed at `4d8f7589` (default tests 3947 pass / 0 fail;
`R CMD check` 0/0/0). This brief blocks on decisions 1–3 only; the engine and
parser surface are understood and the fold machinery already exists.

## Resolution (2026-07-05, Shinichi steer + Slice 2a landed)

Maintainer answered the three decisions: **(1) unify on `unique =`**;
**(2) `unique = TRUE` is the default always for GLLVM** — with the key
clarification that for non-Gaussian families (except overdispersed Poisson) the
estimated diagonal is **zero** and the family/link latent-scale residual is used
instead (binomial-probit 1, binomial-logit `pi^2/3`, …, per
`link_residual_per_trait()`); **(3) re-home** the free correlation into
`latent(1 + x | unit, unique = TRUE)`.

**Slice 2a landed** (the augmented-latent opt-out, the direct #608 fix), local
and green:

- Implementation took a **marker approach**, not the brief's original
  "parser appends `diag(.unique_augmented)`" plan. The parser resolves
  `unique =` (default TRUE; `residual =` soft-deprecated alias) and attaches a
  `.latent_augmented_unique` marker; the engine's existing Gaussian-only
  `diag_B_slope_is_default` now also requires the marker `!= FALSE`. This is a
  better fit for decision-2's clarified semantics: the diagonal stays
  Gaussian-only by default (non-Gaussian keeps the estimated bit off and uses
  the link-specific residual), instead of the parser appending a diagonal for
  every family and leaning on downstream identifiability guards.
- The free intercept–slope correlation lives in the always-present `rr_B_slope`
  low-rank block, so decision-3 re-homing is automatic (present under both
  `unique = TRUE` and `unique = FALSE`).
- Evidence: `test-ordinary-latent-random-regression.R` (+3 tests: marker,
  deprecated alias, fitted opt-out), full file 86 pass / 0 fail; parser/grammar
  regression set green; local known-DGP recovery 25/25 converged with bias
  ≤ 0.01 on the intercept–slope correlation and the per-trait unique variances.
  `NEWS.md`, `man/latent.Rd` (@details prose), and register CI-11/RE-12 wording
  updated; `document()` clean.

**Deferred as separate tested slices** (not in 2a): **2b** = unify the ordinary
intercept-only `latent(residual =)` → `unique =` across all forms (a ~large
example/test cascade — re-verify the exact site count before starting); **2c** =
flip the source-tier `phylo_latent()` / `spatial_latent()` default
`unique = FALSE → TRUE` (breaking for existing fits; needs recovery evidence +
NEWS breaking-change note). The full grid / design-55 / `decisions.md` docs
cascade rides with 2b, since that is where the ordinary-`latent` argument name
actually changes.
