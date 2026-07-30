# Gaussian has no loading-runaway tail — for EITHER engine

Date: 2026-07-30. Author: Claude. Lane: `claude/vgh-pluralism-20260730`.
Evidence: `dev/vgh/gaussian-degeneracy-reachability.{R,csv}` — 36 gaussian Laplace fits,
6 regimes × 6 seeds. Companion to `docs/dev-log/2026-07-30-gaussian-arm-rescope.md`.

## Why this ran before the comparison it was meant to enable

Slice B of the re-scoped gaussian arm asked: *does gaussian VGH show the loading runaway at
Laplace's rate?* Theory predicted yes, because on gaussian the variational bound is tight, so
the KL-to-prior term that protects VA elsewhere contributes nothing.

**That test is vacuous unless gaussian *Laplace* degenerates in the chosen regime.** Otherwise
"VGH lacks the protection" cannot be distinguished from "there is no pathology here to be
protected from". So the regime had to be shown *reachable* first — the lane's own standing
lesson: *"Design the DGP so the gated quantity can reach its threshold."*

It is not reachable. That is the result.

## Result 1 — gaussian Laplace does not exhibit the runaway, in any regime tried

Six regimes, deliberately chosen to attack the things that drive a Heywood runaway: little
data per parameter, an over-specified rank, and weak true signal.

| regime | n | T | d true→fit | λ sd | median rel_frob | median max\|Λ̂\| |
|---|---|---|---|---|---|---|
| heywood-analogue | 60 | 6 | 2→2 | 0.8 | 0.355 | 1.61 |
| wide-small-n | 40 | 20 | 2→2 | 0.8 | 0.374 | 2.08 |
| rank-overspec | 60 | 6 | 1→3 | 0.8 | 0.668 | 1.29 |
| tiny-n-wide | 30 | 15 | 2→3 | 0.5 | 0.655 | 1.35 |
| weak-signal | 60 | 8 | 2→2 | 0.15 | 3.254 | 0.64 |
| weak+overspec | 50 | 12 | 1→4 | 0.15 | 7.937 | 0.76 |

> **🔴 CORRECTED 2026-07-30 after adversarial review — the original headline was WITHDRAWN.**
> It read: *"Max |Λ̂| across all 36 fits = 2.77. The shipped absolute-loading criterion for a
> real runaway is 6 (`loading_absolute_thresh`, merged in #838). Zero fits exceed it."*
> **Both halves were wrong.** The criterion is **binomial-gated** — it lives only inside
> `.gllvmTMB_binomial_prevalence_loading_row()` and that row returns `NULL` unless
> `family_id == 1L` rows exist (`R/diagnose.R:464-471`; gaussian is `0L`). Verified by running
> it: `check_gllvmTMB()` on a gaussian fit returns 13 rows and **no** such row, so there is no
> shipped absolute-loading criterion for gaussian to be "under". And the reviewer produced
> **5 gaussian Laplace fits exceeding 6, max |Λ̂| = 32.64** — and reached **11.42 by nothing
> but multiplying `Y` by 10**, with `check_gllvmTMB()` reporting no new warning. On an identity
> link, "6" is not scale-free. The corrected, scale-free statement follows.

**The scale-free result.** Max \|Λ̂\| across all 36 fits = 2.77 — and in **every** fit the
largest loading sat **below that dataset's own largest trait SD** (max ratio **0.906**, 0 of 36
above 1). Across the reviewer's 23 additional adversarial fits, including deliberately
scale-heterogeneous and t₂-contaminated data, the same bound held (max ratio **0.961**). **In
59 of 59 gaussian fits, loadings track the data's own scale rather than escaping it.**

That is the honest comparator. The original "2.77 versus 6" said only that this simulation's
trait SDs (max 3.053) happened to be below 6.

For contrast, the binomial Heywood arc measured loadings *"running to 24,057× typical"* and
found Laplace degenerate in **50 of 148** paired fits (49 silently). Every fit here converged
(`opt$convergence == 0`, 0 non-convergences). The first regime is the direct analogue of the
binomial cell that degenerates a third of the time; on gaussian it is the *healthiest* cell in
the table.

**Mechanism — now DERIVED, not inferred.** The original text guessed that "the identity link
cannot saturate". The real and provable statement is stronger: the gaussian marginal
log-likelihood is **coercive in Λ**. Since `log|ΛΛ' + diag(ψ)| → ∞` while the quadratic term
stays non-negative, `ll → −∞` as `‖Λ‖ → ∞`, for *any* data. Measured under `Λ → cΛ`:
**−592.8 (c=1) → −800.6 (c=10) → −1352.3 (c=1000)**. A separated logistic does the opposite:
**−6.27 → −9.1e-04 → 0**.

So Λ is **pinned to the data's second moments** by `log|Σ|`. That is simultaneously why the
loading-to-trait-SD bound holds and why no absolute link-scale threshold can be meaningful
here. Note the culprit is *not* an unbounded latent scale — gaussian has one of those too.

**But the likelihood is NOT coercive in ψ**, and that is the live gap: `ψ_j → 0` is the classic
Heywood boundary, and **this search could not see it at all**, because all 36 fits used
`unique = FALSE` — `Σ = ΛΛ' + σ²I`, with no per-trait ψ (`gaussian-degeneracy-reachability.R:43`).
A 9-fit ψ-model spot check (`latent(0 + trait | site, d = k)`, 3 configs × 3 seeds including
n=25/T=12/d 1→4) also found no runaway, max \|Λ̂\| = **2.21**, all converged — but 9 fits is a
spot check, not coverage.

## Result 2 — both research degeneracy metrics FALSE-POSITIVE at small true Λ

The two definitions in circulation disagreed here, and the reason is worth recording because
it would have been read as a positive finding.

- `rel_frob > 10` → **1 of 36** flagged
- `atten_F` outside [0.2, 2] → **8 of 36** flagged

But the flagged fits have **smaller loadings than the unflagged ones**:

| | median max\|Λ̂\| | median atten_F | median rel_frob |
|---|---|---|---|
| flagged by `atten_F` | **0.83** | 3.44 | 6.33 |
| not flagged | **1.44** | 1.16 | 0.57 |

A runaway means loadings *exploding*. These are roughly **half** the magnitude of the healthy
fits. And the effect tracks the true loading scale monotonically, not the pathology:

| λ sd (truth) | median atten_F |
|---|---|
| 0.15 | 1.96 · 3.92 |
| 0.50 | 1.16 |
| 0.80 | 1.03 · 1.11 · 1.28 |

**Both metrics are normalised by the truth's magnitude** — `rel_frob` by `‖Σ_true‖_F` and
`atten_F` by `trace(Σ_true)` — so a near-null true factor structure inflates the ratio while
the fit itself stays small. What those 8 cells show is ordinary over-fitting of a negligible
factor structure, **not** the separation-driven runaway the Heywood gate targets.

This is the lane's own standing discipline biting in an unexpected place: *"sweep the
heterogeneity of whatever sits in a ratio's denominator; homogeneous truth flatters a ratio
every time."* Here the denominator problem is **magnitude**, not heterogeneity — and it
flatters in the opposite direction, manufacturing degeneracy rather than hiding it.

**Diagnostic rule that falls out:** when a ratio metric flags degeneracy, check the *absolute*
loading magnitude. If it is not elevated, the flag is a denominator artifact.

> **Scope guard — this is NOT a finding about the shipped gate.** `check_gllvmTMB()`'s
> statistics (`loading_runaway_thresh`, `loading_absolute_thresh` on `max_loading_unit`) do not
> use `Σ_true` at all — they cannot, since truth is unavailable at diagnosis time. They compare
> loadings against *typical loadings* and against an absolute bound. The false-positive
> behaviour above belongs to the **research recovery metrics** used in simulation studies
> (`dev/vgh/phase0-matched-recovery.R:88-100` and its four independent re-definitions), not to
> anything users run. No change to the merged gate is implied or requested.

## What this does to the lane

**Slice B converts from a comparison to a documented negative result**, and the strategic
conclusion gets *stronger* rather than weaker.

The re-scope doc argued the pluralist "both engines plus an honest gate" route is a
non-gaussian proposition because VGH loses its protective mechanism on gaussian. The better
argument is now available: **there is no gaussian failure for the two engines to differ on.**
Laplace's catastrophic-and-silent tail — the entire motivation for a second engine — is a
property of families whose link saturates. On gaussian, one engine suffices.

Combined with the re-scope's other finding (both engines optimise the same objective on
gaussian, so they share an MLE), the gaussian picture is now complete and negative:

| question | gaussian answer |
|---|---|
| Which engine is more accurate? | **Not well-posed** — same exact objective, same MLE. |
| Which engine has the safer tail? | **Neither has a tail.** 0/36 runaways; max \|Λ̂\| 2.77 vs a threshold of 6. |
| What does VGH buy on gaussian? | **Speed only**, regime-specific (large m, large n), and confounded by interpreted R against compiled C++. |

**Recommendation unchanged and now better supported:** do not build VGH properly *for
gaussian*. Build it where the bound is loose and the tail is real — binomial and Poisson.

## Limits of this result

- **The 36 fits are NOT 36 independent draws.** `sim()` seeds on `20260730 + 1000 * seed` with
  **no dependence on the regime** (`gaussian-degeneracy-reachability.R:29`), so all six regimes
  at a given seed index run on the *same* `N(0,1)` stream. Verified: `heywood-analogue` seed 1
  and `rank-overspec` seed 1 have byte-identical `Λ[,1]`, and `weak-signal`'s Λ is that same
  stream scaled by 0.15/0.8. So this is **6 independent streams reused six ways**, not 36
  independent cells. A design defect in my script; the reachability conclusion is unaffected
  (a runaway would show on any stream) but the effective replication is a sixth of what the
  cell count suggests.
- **`ψ_j → 0` was structurally unreachable.** All 36 fits used `unique = FALSE`, so there is no
  per-trait ψ to collapse — and ψ→0 is what *defines* a classic Heywood case. The 9-fit ψ-model
  spot check found nothing, but the main search could not have.
- **Absence in 59 fits is not proof of structural immunity.** The coercivity argument in
  Result 1 *is* now derived rather than inferred, and it does bound Λ — but it says nothing
  about ψ.
- **Laplace only.** VGH was deliberately not run once the comparator showed no pathology. If a
  gaussian regime with a genuine runaway is found, the engine comparison becomes live again.
- **Single-start.** All 36 reported `convergence == 0`, which the brain note warns is *not*
  evidence of a good optimum (`R/gllvmTMB.R:1213-1216`).
- **What the adversarial pass DID find, so it is not re-attempted blindly:** trait-scale
  heterogeneity (two traits at SD 20/30 against one shared `sigma_eps`) and t₂-contaminated
  errors both push raw \|Λ̂\| past 6 — up to 32.64 — **without producing a runaway**, because the
  loading-to-trait-SD ratio stays under 1. Those are scale effects, not pathologies.
