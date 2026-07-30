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

**Max \|Λ̂\| across all 36 fits = 2.77.** The shipped absolute-loading criterion for a real
runaway is **6** (`loading_absolute_thresh`, merged in #838). **Zero fits exceed it.** For
contrast, the binomial Heywood arc measured loadings *"running to 24,057× typical"* and found
Laplace degenerate in **50 of 148** paired fits (49 silently). Every fit here converged
(`opt$convergence == 0`, 0 non-convergences).

The first regime is the direct analogue of the binomial cell that degenerates a third of the
time. On gaussian it is the *healthiest* cell in the table.

**Mechanism, and it is a prediction rather than a measurement (AGENT-INFERRED).** The binomial
runaway is driven by quasi-complete separation: the logistic link **saturates**, so the linear
predictor can run toward ±∞ at essentially no likelihood cost, and the loadings inflate to
carry it. The gaussian identity link **cannot saturate** — squared error penalises large η
directly — so no such flat escape direction exists. If that is the mechanism, gaussian is
*structurally* immune, not merely lucky in these six regimes. Worth an adversarial check
before it is relied on.

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

- **Six regimes, six seeds each.** Absence of a runaway in 36 fits is not proof of structural
  immunity; it is a strong reachability failure. The mechanism in Result 1 is **AGENT-INFERRED**
  and should be treated as a lead until checked.
- **Laplace only.** VGH was deliberately not run — there was no point once the comparator
  showed no pathology. If a harsher gaussian regime is ever found, the comparison becomes live
  again.
- **Single-start.** Consistent with the adversarial wound recorded in the re-scope doc: a
  Laplace fit stuck on a worse optimum could in principle hide a runaway. All 36 reported
  `convergence == 0`, which the brain note warns is *not* evidence of a good optimum
  (`R/gllvmTMB.R:1213-1216`).
- **I did not attempt to induce separation-analogous behaviour by other means** (e.g. extreme
  trait scale heterogeneity, near-collinear traits). A determined search might yet find a
  gaussian runaway.
