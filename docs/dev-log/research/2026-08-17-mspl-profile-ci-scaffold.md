# MSPL profile-CI scaffold (fenced; public confint still refused)

**Date:** 2026-08-17
**Status:** internal scaffolding only — **not** a Design number, **not** a pre-registration, **not** NEWS `covered`, **not** public `confint`
**Coordinates with:** sibling triad note `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` ([#1075](https://github.com/itchyshin/gllvmTMB/pull/1075); D-12 hero restated as “signature”)
**Also reads:** `#1073` sketch `2026-08-17-mspl-profile-bootstrap-ci-next.md`; `#1090` binomial profile-computability probe on `main`
**Binding:** D-157 (B1 PARK; new construction), D-12 (profile = featured/hero CI), D-149 (\(Q_0\) Wald target if/ever), D-148 (public calibrated intervals withheld)

---

## What this slice is

The triad Confirm is **SIGNED**; this sitting keeps a **fenced stub** so the next construction has a named internal door and a hard public refuse — without implementing a calibrated profile interval and without reopening Design 118.

**Reconcile (post-#1090):** profile *bounds are computable* on `main` for **binomial** via `.gllvmTMB_mspl_profile_feasibility()` (`calibrated = FALSE`, `public_confint = "refused"`). That probe does **not** make this scaffold’s `profile$status = "not_constructed"` stale — this file is a **gaussian/poisson toy** door and still does not construct a claim path. Do not undraft this PR as a public `confint` fence.

| Surface | File | Role |
|---|---|---|
| Internal triad labels | `R/mspl-profile-ci-stub.R` → `.gllvmTMB_mspl_ci_triad()` | Profile = signature; Wald \(Q_0\) = quickest baseline; Bootstrap = asymmetry |
| Internal scaffold | `.gllvmTMB_mspl_profile_ci_scaffold(fit, run_wald_q0=)` | Accepts a toy Gaussian-identity or Poisson-log MSPL **point** fit (`se=FALSE`); returns a list that **refuses** public CI and leaves profile `not_constructed` |
| Wald \(Q_0\) quick check | optional `run_wald_q0=TRUE` | Calls the existing D-149 pin (`.gllvmTMB_mspl_curvature_pin`); labels \(Q_0\) as baseline, never as the signature interval; non-PD stays typed |
| Public `confint` / `vcov` / `se=TRUE` | unchanged | Still `.gllvmTMB_mspl_assert_inference` → `gllvmTMB_mspl_inference_unsupported` |
| Tests | `tests/testthat/test-zz-mspl-profile-ci-stub.R` | Source fence + unexported + toy Gaussian `se=FALSE` still refuses `confint(method=profile/wald)` |

The stub does **not** call `TMB::tmbprofile()`, does **not** call `TMB::sdreport()`, and is **not** wired into `R/z-confint-gllvmTMB.R`. Objective fork A/B/C from the `#1073` sketch stays unpicked. The binomial `#1090` probe on `main` is a separate computability instrument (fork A structurally; not a calibration claim).

---

## Wald \(Q_0\) quick check vs profile signature

This is the operational split the triad note states in doctrine form:

1. **Wald \(Q_0\)** is the **quickest** thing you can run on a toy point fit: one numerical Hessian of the penalty-off tape at \(\tilde\theta\) (already implemented as the D-149 pin). Use it to ask “is the unpenalized observed information even PD / finite?” That is **triage**, not a brand CI. B1 already showed that a Wald-shaped **calibrated-interval** programme fails (D-157).
2. **Profile** is the **signature** construction (D-12 hero). This stub records that role and then **stops**. Inverting a likelihood-ratio along one coordinate for a **calibrated claim** is the future Design’s job; KF2021 (VERIFIED) says profiling the *penalised* binomial tape does not escape finiteness-driven undercoverage — see the triad MSPL footnote.
3. **Bootstrap** stays the asymmetry arm. Not stubbed beyond the role label.

```
toy MSPL fit (gaussian / poisson, se=FALSE)
        │
        ├─ public confint() / vcov()  →  REFUSED (unchanged)
        │
        └─ .gllvmTMB_mspl_profile_ci_scaffold()
                ├─ profile     role=signature     status=not_constructed
                ├─ wald_q0     role=quickest_baseline   optional D-149 pin
                └─ bootstrap   role=asymmetry     status=not_constructed
```

---

## Fence

- No public export. No NEWS covered claim. `MSPL-04` stays `blocked`.
- No Totoro / DRAC. No Design 118 recalibration. No Codex Lane B absorb.
- Toy family fence is **Gaussian identity** or **Poisson log** only — the two point-admitted ordinary cells that can be fitted with `se=FALSE` without touching binary SE (Lane B **PROTECTED**).
- `run_wald_q0=TRUE` is opt-in so default tests do not pay `optimHess` on CI.
- Do **not** extend the `#1090` binomial probe family fence to this stub without evidence (KF2021 is binomial-only; non-binomial profile coverage = UNVERIFIED).

---

## Non-claims

- Not permission to implement `confint(method="profile")` on MSPL.
- Not a coverage campaign. Not a Design number.
- Not a claim that Gaussian Laplace exactness transfers a profile calibration to MSPL.
- Not a claim that `#1090` endpoints are confidence intervals.
- Sibling triad note owns the triad Confirm + MSPL/KF2021 footnote; this file owns the helper contract.
