# MSPL CI triad — Profile signature + Wald quick + Bootstrap asymmetry

**Date:** 2026-08-17
**Status:** **SIGNED** (2026-08-17) — triad Confirm under **D-157** new construction (no new D-number). Still **not** a Design number, **not** a pre-registration, **not** permission to run Totoro / flip public `se=TRUE`.
**Author of sign:** cursor/Shinichi-via-chat (“paste Confirm for me”).
**Amends:** `docs/dev-log/research/2026-08-17-mspl-profile-bootstrap-ci-next.md` (#1073)
**Binding:** D-12 (profile = featured/hero CI), D-157 (B1 PARK; new construction), D-149 (pins ≠ public CI; \(Q_0\) if/ever Wald SE), D-97 (drmTMB profile default accepted)

---

## Shinichi paste (this sitting)

> *"try Wald as well though which will be the quickest but our signature error is profile"*

Encoded together with the prior asymmetry thread (bootstrap still in play) and Ranga’s SE split (\(Q_0\) paper target if Wald SE is used; CI calibration remains a separate programme).

---

## Does the brain already record “profile is signature”?

**Yes — under D-12, not under the word “signature”.**

| Source | What it records |
|---|---|
| **D-12** (2026-06-27, accepted) | *"Profile is the featured/hero CI method; Wald only in the easy interior."* Maintainer ask: *"please remember profile as our hero … feature it where Wald does not quite work."* Spans gllvmTMB / drmTMB / freqTLS. Frequentist trio = **Wald / profile / bootstrap**; **profile is foregrounded**. Speed order stated explicitly: **Wald ≪ profile ≪ bootstrap** — Wald is cheapest; profile’s sell is near-bootstrap accuracy at a fraction of bootstrap cost. |
| **D-97** (drmTMB) | Profile route coverage **accepted as drmTMB’s default** (further testing welcome, not blocking). Sister-package proof that “profile as house default” is live doctrine, not aspiration. |
| **Design 68** (gllvmTMB profile CI audit) | Package already puts `method = "profile"` first on `confint()` for `gllvmTMB_multi` — API order matches the brand. |
| **D-157** (2026-08-17) | B1 (Design 118 Wald-shaped binary intervals) **PARKED**. Later intervals = **new construction + new pre-registration**, not Design 118 recalibration. Does **not** repeal D-12; it blocks reusing the failed Wald calibrator. |
| **D-149** / Ranga (#1061/#1062) | If/ever a Wald SE ships, report **\(Q_0\)** (unpenalized observed \(J\) at MSPL \(\tilde\theta\)). \(Q_P\)/\(Q_0\) PD = availability only. **CI calibration ≠ SE availability.** |

This sitting’s phrasing (“signature error is profile”) is therefore a **short label for D-12**, not a new vault decision number. Wald-as-quickest is already inside D-12’s speed ordering; today’s paste restores Wald to the **diagnostic baseline** slot that #1073’s “not Wald-first” wording risked burying.

---

## The triad (new construction roles)

| Method | Role | What it is **not** |
|---|---|---|
| **Profile** | **Signature / primary claim path** (D-12 hero; house brand for uncertainty) | Not “slow Wald”. Not Design 118. Not automatic public `confint` without a new Design + G0. |
| **Wald (\(Q_0\))** | **Quickest baseline / availability check** — one Hessian, \(\pm z\cdot\mathrm{se}\) for many targets at once | Not the brand. Not a calibrated public interval programme (B1 FAIL under D-157). Pins stay D-149 until separate public-`se` G0. |
| **Bootstrap** | **Asymmetry / non-symmetric sampling** arm (percentile; saturation refuse) | Not a repair for Wald undercoverage on the same misspecified centre. Not BCa-by-default (Design 118 A4). |

Speed / cost order (D-12): **Wald (quickest) → profile (signature) → bootstrap (asymmetry / calibration layer).**

### MSPL footnote — profile = signature under a finiteness penalty

**D-12 stands** for ML generally and as the house brand: profile remains the signature / primary claim path; Wald stays the quick baseline.

What does **not** stand is the inference that **profiling rescues coverage under a finiteness penalty**. Kosmidis & Firth (2021) §2.2 state that for binomial-response GLMs the usual regions fail to cover **even when the penalised likelihood is profiled** — the failure is the bounded attainable estimator set, not a quadratic-approximation artefact (see `docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md`, Status **VERIFIED**). So “profile = signature” here means **which instrument we build next**, not “profile of the MSPL penalised tape is already a calibrated CI”.

**Scope fence (do not over-cite):** KF2021 is **binomial-response only**. For Gamma / lognormal / Student / Tweedie / ordinal_probit / delta / hurdle / nbinom the same profile-coverage question is **UNVERIFIED**. Transfer to a latent-variable GLLVM (Laplace marginal) is **AGENT-INFERRED**, not established. An internal uncalibrated profile *computer* (e.g. `#1090` binomial probe) remains allowed under D-149’s computability ≠ coverage split; calling its endpoints confidence intervals does not.

### How this sits next to B1 / Design 118

- B1 failed as a **Wald-shaped calibrated-interval** programme (hold-out G1–G5 FAIL 14/132 = 10.6% under frozen M0).
- D-157: do **not** reopen Design 118; do **not** relaunch Totoro; MSPL-04 stays `blocked`.
- Trying Wald **again as a fast diagnostic** (finite SE? PD \(Q_0\)? rough width?) is allowed and encouraged — that is **availability / triage**, not a second B1 campaign.
- Shipping a **user-facing / register-covered** CI claim still needs a **new Design** whose primary path is **profile**, with Wald and bootstrap named in the triad above.

---

## Recommended G0 (confirm triad)

**Status:** **SIGNED** — 2026-08-17 · author **cursor/Shinichi-via-chat** (“paste Confirm for me”).

**Confirm (exact paste):**

> **Confirm MSPL interval triad for the new construction:** Profile = signature / primary claim path; Wald (\(Q_0\)) = quickest baseline / availability check (not the brand; not Design 118 reopen); Bootstrap = asymmetry / non-symmetric sampling. SE pins stay D-149. No Totoro. No public `se=TRUE` without separate G0.

Recorded under **D-157** new construction + this card SIGNED. **No new vault/repo D-number** (D-12 already heroizes profile; this paste locks the triad roles for the post-B1 path). Poisson \(W\) G0 Status on `main` is **SIGNED — PARK SE doors** (Shinichi *"approve all things in this lane"* / `G1 PARK SE doors`); do **not** invent KEEP / REPLACE. Handover §4 UNSIGNED wording is stale — see open Claude [#1096](https://github.com/itchyshin/gllvmTMB/pull/1096) provenance note. #1077 stays draft/fenced; no public profile intervals; no Design 118 / B1 / Totoro reopen; no public `se=TRUE`. Binomial profile **computability** on `main` (`#1090`) is not a calibrated CI claim.

---

## Non-claims

- Not MSPL-04 unblocked. Not public `se=TRUE` / `vcov` / Wald `confint`.
- Not permission to implement MSPL `confint(method="profile")` on this note alone.
- Not a recalibration of Design 118 α\* / M0–M5.
- Not NEWS `covered`.
