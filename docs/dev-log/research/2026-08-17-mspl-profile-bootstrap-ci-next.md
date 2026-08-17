# MSPL intervals next — profile + bootstrap construction (sketch)

**Date:** 2026-08-17
**Status:** research sketch only — **not** a Design number, **not** a pre-registration, **not** permission to run Totoro
**Closes the “is SE-first OK?” question for intervals:** **re-aim**
**Binding decisions:** D-157 (B1 PARKED), D-149 (pins ≠ public intervals), D-148 (public calibrated intervals withheld), **D-12** (profile = featured/hero CI)
**Triad amendment (same day):** `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` — Profile = signature; Wald (\(Q_0\)) = quickest baseline; Bootstrap = asymmetry

---

## Verdict (one paragraph)

The **SE-first path is OK as availability plumbing** (internal \(Q_P\)/\(Q_0\) pins under D-149; Ranga+papers say eventual Wald reporting target = \(Q_0\) at MSPL \(\tilde\theta\)). It is **not** the brand for **public confidence intervals**. B1 (Design 118) already showed that calibrated **Wald-shaped** binary intervals fail the hold-out gate (G1–G5 FAIL 14/132 = 10.6% PASS under frozen M0). Shinichi’s asymmetry point matches house doctrine (**D-12**: profile = featured/hero CI) and the papers: sampling distributions for loadings / intercepts under separation and Laplace error are often **non-symmetric**, so **profile** (likelihood-ratio inversion) is the **signature / primary claim path**, **bootstrap** covers asymmetry / non-symmetric sampling, and **Wald** remains the **quickest baseline / availability check** (D-12 speed order: Wald ≪ profile ≪ bootstrap) — try it, but do not treat it as the house error. D-157 already requires any later interval work to be a **new construction + new pre-registration**, not Design 118 recalibration and not \(n\to 2000\).

---

## What is OK vs what is not

| Track | Status | Role |
|---|---|---|
| Internal \(Q_P\) + \(Q_0\) pins | **Keep** (D-149) | Availability / PD / finite-SE diagnostics at \(\tilde\theta\); never repair non-PD |
| Wald (\(Q_0\)) as **quick diagnostic** | **In triad** — not the brand | Fastest baseline / triage; same \(Q_0\) object as paper SE if/ever; **not** a second B1 calibrator |
| Paper Wald target \(Q_0\) | **Deferred reporting object** | If/when a Wald SE ships, report unpenalized observed \(J\) at MSPL \(\tilde\theta\); \(Q_P\) is companion only |
| Public `se=TRUE` / `vcov` / Wald `confint` | **Withheld** — needs Shinichi G0 | Pins alone do not unlock |
| Design 118 / B1 recalibration / second campaign | **PARKED** (D-157) | MSPL-04 stays `blocked`; no Totoro relaunch |
| **New** profile + Wald-diag + bootstrap CI programme | **Recommended next interval path** | Profile = signature (D-12); needs G0 on triad + scope before any Design number or campaign |

---

## Estimands (sketch — freeze under a future Design)

Start narrow; do not inherit Design 118’s full grid by default.

1. **Scalar fixed effects** on the linear predictor (trait intercepts; optionally one slope) under ordinary `latent(q=1)` binary and/or Poisson point-admitted regimes.
2. **Single loading** \(\lambda_{j1}\) (sign-anchored) — the object most prone to asymmetric sampling under near-separation.
3. **Explicitly out of v1:** nonlinear derived quantities (correlation / communality profile), mixed-family blocks, phylo/spatial tiers, public sandwich / Godambe.

Each estimand needs a typed unavailable path (non-PD \(Q_0\), bracket non-closure, saturated column) — never a silent Wald fallback that looks calibrated.

---

## Profile vs Wald vs bootstrap (construction sketch)

### Profile (signature / primary claim path — D-12)

- Invert a **likelihood-ratio** (or penalised-LR, if the Design chooses that and pre-registers the cutoff) along one coordinate, others profiled.
- **Why signature:** asymmetry-respecting; transformation-equivariant; cheaper than bootstrap when brackets close; matches maintainer D-12 “profile as hero where Wald is suspect” / “signature error is profile” doctrine.
- **MSPL-specific fork to decide under G0 (do not silently pick):**
  - **A.** Profile the **penalised** MSPL objective (what Design 118 used as base).
  - **B.** Profile the **unpenalized** Laplace objective at a **fixed** MSPL point for nuisance coordinates (closer to \(Q_0\) philosophy).
  - **C.** Hybrid: penalised for location, unpenalized for cutoff — only if pre-registered.
- Reuse existing package profile machinery where safe (`R/profile-ci.R` family), but **do not** claim ordinary Laplace profile calibration transfers to MSPL.
- Fail closed when brackets do not close (Design 118 Phase A: one-sided bracket failures were common).

### Wald (\(Q_0\)) — quickest baseline (not the brand)

- One Hessian at MSPL \(\tilde\theta\); \(\pm z\cdot\mathrm{se}\) for many targets at once (D-12: Wald is cheapest).
- **Use for:** availability / triage / rough width next to profile brackets — “try Wald as well.”
- **Do not use for:** a Design 118-style calibrated public-interval campaign (D-157 PARK). Public Wald `confint` still needs separate G0; CI calibration ≠ SE availability (Ranga).

### Bootstrap (fallback / co-primary for asymmetry)

| Flavour | Use | Fence |
|---|---|---|
| **Parametric** | Resimulate \(y\) from fitted MSPL mean/structure; refit MSPL | Prefer when units are exchangeable under the DGP the Design names |
| **Nonparametric** (unit/cluster) | Resample grouping level; refit | Prefer when overdispersion / misspecification is the threat |
| **Percentile** | Default asymmetric interval | Refuse on **saturated** coordinates (Phase A A1b: atomic resample → needle CI) |
| **BCa** | Ablation only unless literature gate clears | Design 118 A4: standard acceleration routes blocked (no per-unit score); do not default |

Bootstrap is **not** a repair for Wald undercoverage on the same misspecified centre. Separation / saturation must refuse or flag, not “more B.”

---

## What B1 taught us not to repeat

From #1040 (official hold-out) + D-157 + Phase A adjudication:

1. **Do not recalibrate Design 118** (α\*, M0–M5 ladder, same grid) hoping coverage climbs — G1 was 10.6%; \(n\to 2000\) cannot hit 90% even in the optimistic flip.
2. **Do not treat train-only PASS rates as the gate** — hold-out was sealed for a reason; B1’s lesson is the sealed gate failed.
3. **Do not promote Wald SE because pins are finite** — D-149; KF2021 undercoverage warning; B1 FAIL fits that warning.
4. **Do not use bootstrap on saturated / deep-separation coordinates** — Phase A A1b: intrinsic pin + bootstrap inconsistency; fence first (`screen_control(separation=…)`, sensitivity tiers).
5. **Do not open Totoro/DRAC without a new pre-registration** and Shinichi G0 — D-50 / D-139 / D-157.
6. **Do not absorb Codex Lane B** into a Cursor “fix Wald” branch — Lane B historically owns binary interval feasibility; coordinate, do not overwrite.
7. **Do not claim NEWS `covered` or public `confint` from a sketch** — this file is not a Design.

---

## Relationship to \(Q_0\) / \(Q_P\) pins

```
        ┌─────────────────────────────┐
        │ Internal pin (D-149)        │
        │ Q_P  — availability         │
        │ Q_0  — paper Wald target    │
        │   (if SE ever ships)        │
        └─────────────┬───────────────┘
                      │ does NOT unlock
                      ▼
        ┌─────────────────────────────┐
        │ Public Wald se / vcov       │  ← still needs separate G0
        └─────────────┬───────────────┘
                      │ B1 showed Wald CI
                      │ calibration is hard
                      ▼
        ┌─────────────────────────────┐
        │ NEW triad (D-157 construct) │
        │ Profile = signature         │
        │ Wald(Q_0) = quick baseline  │
        │ Bootstrap = asymmetry       │
        │ → future Design + pre-reg   │
        └─────────────────────────────┘
```

Pins remain useful: PD/\(Q_0\) availability is the **Wald baseline** and a **precondition** for “profile is even worth attempting,” not a substitute for coverage evidence. CI calibration stays a **separate programme** from SE availability (Ranga synthesis #1061/#1062). See `2026-08-17-mspl-ci-wald-plus-profile.md`.

---

## Fence vs Lane B

| Surface | Owner | Rule |
|---|---|---|
| Public MSPL `se` / `vcov` / `confint` | Withheld on `main` | No flip without Shinichi G0 |
| Internal SE pins (Bernoulli / Gaussian / Poisson) | Cursor historical; on `main` | Availability only |
| Binary interval feasibility (historical Lane B) | Codex `codex/lane-b-mspl-interval-feasibility` | **PROTECTED** — classify / coordinate; do not mutate from a Cursor point/SE lane |
| Design 118 / B1 artifacts | PARKED (D-157) | Read-only lessons; no second campaign |
| This sketch → future Design N | Unassigned until G0 | Docs-only until scope paste |

---

## Recommended G0 options (for Shinichi)

**Preferred paste (triad confirmation):**

> Confirm MSPL interval triad for the new construction: Profile = signature / primary claim path; Wald (\(Q_0\)) = quickest baseline / availability check (not the brand; not Design 118 reopen); Bootstrap = asymmetry / non-symmetric sampling. SE pins stay D-149. No Totoro. No public `se=TRUE` without separate G0.

Still available if he refuses the triad:

1. **Profile-first Design only** — new Design; estimands = intercept + one loading; family = binomial-logit ordinary `q=1`; bootstrap = nonparametric fallback with saturation refuse; Wald diagnostic allowed but not branded; Lane B consulted before any binary campaign.
2. **Bootstrap-first Design** — same estimands; parametric bootstrap primary; profile as co-primary; Wald still quickest diagnostic only.
3. **Park intervals entirely** — keep point admits + D-149 pins; no new Design until Poisson \(W_*\) / other point work clears; SE/CI public stays withheld.

**Hard stops regardless of pick:** no Totoro; no Design 118 reopen; no public `se=TRUE`.

---

## Non-claims

- Not a capability claim. Not MSPL-04 unblocked. Not Lane B closed.
- Not permission to implement `confint(method="profile")` on MSPL fits.
- Not a drmTMB port brief (drmTMB keeps its own pre-reg under Design 225 discipline).
