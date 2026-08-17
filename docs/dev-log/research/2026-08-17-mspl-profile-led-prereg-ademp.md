# ADEMP pre-registration draft — profile-led MSPL intervals (Design 125)

**Date:** 2026-08-17  
**Lane:** `claude/lane-mspl-profile-led-ci`  
**Status:** **DRAFT pre-registration** under D-157 + triad Confirm SIGNED. **Not signed.** **Not a campaign launch.**  
**Design id:** **125** — `docs/design/125-mspl-profile-led-intervals.md` (claimed by commit `b68b20b4`; tip may be `ec12d3a9`).  
**Form:** Morris et al. (2019) ADEMP, future tense.  
**Sources:** `LOOP/GOAL.md`, `LOOP/ultra-plan.md`, Design 125 stub, R1 lessons (`2026-08-17-mspl-profile-led-r1-lessons.md`), profile-bootstrap sketch (`2026-08-17-mspl-profile-bootstrap-ci-next.md`), triad card (`2026-08-17-mspl-ci-wald-plus-profile.md`). Negative lessons from Design 118 / B1 are **read-only**; this is **not** Design 118 recalibration.

---

## Sync (S1 → S2)

| Item | State |
|---|---|
| Design stub | `docs/design/125-mspl-profile-led-intervals.md` @ `b68b20b4` |
| This pre-reg | Draft complete under Design **125** (not TBD); aligns §3–§4 estimands / refusal taxonomy |
| Follow-up | S3 (Poisson W UNSIGNED) ∥ S4 Rose fence; numeric L\*/T\* thresholds freeze at Shinichi sign |

---

## Non-claims (load-bearing)

This draft alone does **not**:

1. Recalibrate, amend, or reopen **Design 118** / B1 / Totoro (D-157 PARK).
2. Unlock public `se=TRUE` / `vcov` / user-facing Wald or profile `confint` (needs **separate** G0s; D-148/D-149).
3. Flip register row **MSPL-04** off `blocked`, or write NEWS `covered`.
4. Undraft **#1077** (`fb44d7b5`) or implement live MSPL `confint(method="profile")`.
5. Choose Poisson \(W=\mathrm{diag}(\mu)\) KEEP/REPLACE/PARK (parallel G0 remains UNSIGNED).
6. Authorize Totoro/DRAC compute (D-50 / D-139 / D-157 — separate campaign G0 after this pre-reg is signed).

---

## ADEMP

### A — Aims

1. **Primary.** Pre-register a **profile-primary** interval construction for MSPL point estimates under ordinary binary `latent(q=1)`, such that — inside a named, fit-time-checkable envelope and after typed refusals — nominal 95% intervals achieve frequentist coverage near 0.95 under repeated sampling from the declared DGP grid.
2. **Secondary.** Measure **availability** of the signature (profile) path, **refusal rates** (priced into coverage denominators — see Performance), and the **diagnostic** behaviour of Wald(\(Q_0\)) and bootstrap (asymmetry) arms without promoting either to the brand.
3. **Explicit non-aim.** Not to rehabilitate Design 118’s level-calibrated Wald-shaped / α\* programme; not to treat finite SE pins as calibrated CIs.

### D — Data-generating mechanisms (v1 envelope)

**Family (v1):** complete, unweighted, single-trial **Bernoulli** under `estimator = "mspl"`, links among {logit, probit, cloglog} as already admitted for MSPL **point** estimation (Design 125 §3.1).  
**Ada default:** binary profile-led first; **Poisson stays off the coverage campaign** until the Poisson \(W\) G0 is resolved (point/SE-atom track only).

| Axis | In envelope (proposed) | Outside ⇒ refuse / out of claim |
|---|---|---|
| Family | Bernoulli (logit first for local smoke; probit/cloglog as declared hold-out or later arms) | Poisson, other families, mixed-family, weighted, multi-trial (v1) |
| Structure | ordinary `latent(d = 1, unique = FALSE)` | `d≥2` until a later signed arm; phylo / spatial / kernel tiers |
| Estimands | E1–E2 below | communality, LV-score CIs, cross-family, phylo/spatial params, LRT/AIC |
| Prevalence | both tails on a narrow local grid first; hold-out prevalence reserved for Totoro phase | beyond measured \(m_{\min}\) / \(\pi\) rectangle |
| Scale | small \(n_{\text{site}}\) local smoke → larger \(n\) only after local PASS | beyond measured \(N_{\text{eff}}\) rectangle |

**Local smoke DGP (proposed — freeze numbers at sign):** e.g. \(n_{\text{site}}\in\{40,80\}\), \(T\in\{4,8\}\), \(q=1\), intercept+loading truths in the well-identified interior (anchor \(\pi\approx0.5\)) **and** one near-tail cell. Fresh seeds only; **no** reuse of Design 118 campaign seeds as fitting data.

**Totoro DGP (later, gated):** expanded prevalence × \(n\) hold-out **declared before launch**; independent seeds; not a Design 118 H1∪H2∪H3 reopen.

### E — Estimands (aligned with Design 125 §3.2)

| ID | Estimand | Role |
|---|---|---|
| E1 | Per-trait intercept \(\beta_{0t}\) | Primary coverage target |
| E2 | Per-trait loading \(\Lambda_{t1}\) (sign-anchored); \(d=2\) second column only if a later signed arm admits `d=2` | Primary asymmetry / near-separation target |
| E3 | Wald(\(Q_0\)) SE **availability flags** for E1–E2 | Diagnostic only — **not** a coverage estimand |
| Out | Communality, LV scores as public CI, cross-family, phylo/spatial, `logLik`/AIC/LRT | Explicitly out of v1 |

Each coverage estimand must have a **typed unavailable path** (never a silent Wald fallback that looks calibrated).

### M — Methods (triad construction)

Roles locked by triad Confirm SIGNED under D-157 + D-12 + Design 125 §2:

| Method | Role | Construction (freeze at sign) |
|---|---|---|
| **Profile** | **Signature / primary claim path** | Likelihood-ratio inversion along one coordinate, others profiled. **MSPL fork (G0 — do not silent-pick):** (A) profile penalised MSPL objective; (B) profile unpenalized Laplace at fixed MSPL nuisance point; (C) hybrid only if pre-registered. Fail closed on bracket non-closure / one-sided-only. Do **not** claim ordinary Laplace profile calibration transfers to MSPL. |
| **Wald(\(Q_0\))** | **Quickest baseline / availability** | One unpenalized observed information \(Q_0\) at MSPL \(\tilde\theta\); \(\pm z\cdot\mathrm{se}\). Diagnostic widths and PD triage only — **not** the coverage brand; **not** a second B1 calibrator. |
| **Bootstrap** | **Asymmetry arm** | Default: percentile. Parametric vs unit-cluster nonparametric chosen at sign for the named DGP. **Refuse** on saturated / deep-separation coordinates (Design 118 A1b). BCa ablation-only unless a literature gate clears. Bootstrap is **not** a repair for Wald undercoverage on a misspecified centre. |

**Plumbing fence:** #1077 stays **draft** scaffold until Design 125 + this pre-reg are signed and tests exist; public `confint` remains refused via `.gllvmTMB_mspl_assert_inference`.

### P — Performance measures (with refusal pricing)

#### P1 — Coverage (primary), refusal-priced

Let a **cell** be a (DGP × estimand × method) unit.

- For each replicate, the interval is either **returned** or **refused** (typed reason).
- **Coverage among returned intervals** alone is **insufficient** (Design 118 DEV-11/DEV-12: maps that refuse hard cells can look calibrated on the survivors).

**Pre-registered dual reporting (mandatory):**

1. **Conditional coverage** \(\widehat{\mathrm{cov}}_{\mathrm{ret}}\): among replicates with a returned two-sided interval, fraction containing truth.
2. **Refusal rate** \(\widehat{r}\): fraction refused (by reason code).
3. **Effective coverage** (priced):  
   \[
   \widehat{\mathrm{cov}}_{\mathrm{eff}}
   = (1-\widehat{r})\,\widehat{\mathrm{cov}}_{\mathrm{ret}}
   + \widehat{r}\cdot 0
   \]
   i.e. a refusal counts as **non-coverage for the claim** unless a separate, signed policy redefines refusal as “no claim” **and** reports usability gates separately. **Default for this draft:** refusals **price into** \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\) (fail-closed; blocks DEV-11-style gaming).

Wilson intervals / MCSE reported on both \(\widehat{\mathrm{cov}}_{\mathrm{ret}}\) and \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\).

#### P2 — Availability (profile signature)

Among non–R-SAT replicates: fraction with a **two-sided** profile interval (one-sided bracket success ≠ availability). Target proposed: ≥0.95 on local anchor cells before Totoro.

#### P3 — Refusal rules (typed; fail-closed)

Freeze of Design 125 §4 sketches into measurable rules:

| Code | Trigger (fit-time / pre-fit) | Action |
|---|---|---|
| R-SAT | Response-column saturation / separation screen / `infinite_terms` | Refuse coordinate interval; **no** bootstrap fallback |
| R-PIN | Penalty-determined / pinned loading (Design 118 A1b class; attractor proximity if adopted) | Refuse as primary claim; optional secondary measurement only under signed policy |
| R-NAVL | Profile root-finder / path unavailable (no finite two-sided profile CI) | Availability failure; **do not** substitute uncalibrated Wald as “the” CI |
| R-Q0 | \(Q_0\) not PD or SE not finite | Wald arm unavailable; does **not** unblock profile |
| R-FENCE | Public API (`confint` / `vcov` / `se=TRUE`) while MSPL-04 blocked | Keep `.gllvmTMB_mspl_assert_inference`; #1077 stays unexported |
| R-ENV | Outside named envelope (family / structure / scale) | Refuse / no claim |
| R-BOOT-SAT | Bootstrap requested on saturated / R-SAT coordinate | Refuse bootstrap (refinement of R-SAT; Design 118 A1b) |

**Usability floor (G4-analogue):** on well-identified anchors (\(\pi\approx0.5\), largest local \(n\)), refusal rate ≤0.10 — else local gate FAIL even if conditional coverage looks good.

#### P4 — Wald / bootstrap secondary metrics

- Wald(\(Q_0\)): PD rate, finite-SE rate, width ratio vs profile (descriptive; **no** PASS/FAIL coverage brand).
- Bootstrap: coverage among non-refused (priced same way); asymmetry diagnostics (interval skew); saturation refuse rate.

#### P5 — Local-then-Totoro gates

| Gate | Where | Rule (proposed) | On FAIL |
|---|---|---|---|
| **L0** | Local | Plumbing: profile path returns typed success/refuse on toy MSPL fits; #1077 still draft; no public door | Stop; fix docs/scaffold only |
| **L1** | Local | On ≥1 anchor cell, \(n_{\mathrm{rep}}\) small (e.g. 50–100): \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\) not catastrophic (e.g. Wilson not entirely below 0.80); availability ≥0.90; refusal ≤0.15 | Do **not** escalate to Totoro |
| **L2** | Local | Multi-seed interior + one near-tail cell; dual coverage + refusal pricing recorded | Shinichi G0 required before Totoro |
| **T1** | Totoro (after signed G0 + this pre-reg) | Hold-out cells declared in advance; Wilson / PASS-FAIL thresholds frozen **before** launch (numbers filled at sign — placeholder: e.g. PASS if Wilson 90% CI ⊂ [0.90, 0.98] at registered \(n_{\mathrm{rep}}\)) | Campaign FAIL; MSPL-04 stays blocked; no NEWS covered |
| **T2** | Totoro | Availability ≥0.95 on non-refused envelope cells; refusal floor on anchors | Same |

**Hard rule:** no Totoro until L1–L2 recorded **and** Shinichi signs this pre-reg (or a successor) + Design 125 scope G0. No \(n\to2000\) “fix” of Design 118. Design 124-style campaign admission remains a separate gate (Design 125 §3.3).

---

## Claim boundary (reader-facing intent — not shipping text yet)

Inside the named envelope, for estimates that pass refusal rules, profile intervals are the **signature** uncertainty statement for the MSPL estimator; Wald(\(Q_0\)) is a fast diagnostic; bootstrap addresses asymmetry when admissible. Outside the envelope or when refused, **no interval is claimed**. This is **not** asymptotic ML coverage, **not** Design 118 calibration, and **not** a license for public `se=TRUE` from pins alone.

---

## Open G0 items (human)

1. Sign Design **125** scope (binary-first recorded in §3.1; widen only explicitly).
2. Pick MSPL profile fork A/B/C.
3. Freeze L\* / T\* numeric thresholds and \(n_{\mathrm{rep}}\).
4. Undraft #1077 only after Design + this pre-reg + tests — **not-ready** now.
5. Poisson \(W\) KEEP/REPLACE/PARK — leave UNSIGNED; default PARK further SE doors if silent.
6. Separate G0 for public `se=TRUE`.

---

## References (local)

- Morris TP, White IR, Crowther MJ (2019). Using simulation studies to evaluate statistical methods. *Stat Med*.
- Design 125 stub `docs/design/125-mspl-profile-led-intervals.md` (claim `b68b20b4`).
- D-12, D-148, D-149, D-157; triad Confirm SIGNED `2026-08-17-mspl-ci-wald-plus-profile.md`.
- R1 lessons `2026-08-17-mspl-profile-led-r1-lessons.md`.
- Sketch `2026-08-17-mspl-profile-bootstrap-ci-next.md`.
- Design 118 (parked) — negative lessons only; do not edit from this lane for recalibration.
