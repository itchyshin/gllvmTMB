# Reconciliation inventory

Date: 2026-08-28  
Baseline: `origin/main` at `1a3b0d161781468a3e647cb9b717eb1635e20730`  
Status: preparation evidence only; shared surfaces remain protected

This inventory separates working software from wording drift and from missing
scientific evidence. “Shipped” below means behavior exists on the inspected
baseline, not that its broader statistical claim is certified.

| Surface | Classification | Repo evidence | Required reconciliation |
|---|---|---|---|
| Public multi-source fit | SHIPPED / PARTIAL | `R/isdm-sources.R`; `tests/testthat/test-isdm-multisource.R` | Retain the public `isdm_sources()` boundary. Recovery for realistic weak overlap and spatial `n > 2` remains owed. |
| Source-specific observation formula | SHIPPED | `R/isdm-sources.R`; `tests/testthat/test-isdm-source-formula.R` | Requalify named source-masked slopes through the public route. |
| Design 126 baseline and gap list | STALE | `docs/design/126-isdm-prediction-api.md` | Reconcile its pre-#1132 counts and claims after the shared-path lease releases. |
| Design 127 implementation status | STALE + OWED | `docs/design/127-isdm-prediction-map-implementation.md` | Point-map machinery is no longer wholly unimplemented; held-out accuracy and uncertainty remain owed. |
| Design 129 uncertainty boundary | PROTECTED | `docs/design/129-prediction-uncertainty-new-locations.md` | Preserve its negative fixed-only result and no-calibrated-map-interval boundary. |
| ISDM-01 | SHIPPED / PARTIAL | `docs/design/35-validation-debt-register.md` row ISDM-01 | Do not upgrade until public-route point evidence passes. |
| ISDM-02 | SHIPPED / PARTIAL | register row ISDM-02 | Do not generalize the existing first-pass campaign to weak overlap, spatial models, or intervals. |
| ISDM-03 | PROTECTED / PARTIAL | register row ISDM-03 | Training-row SPDE identity is shipped; new-coordinate point accuracy and intervals remain owed. |
| Row-wise source/link prediction | SHIPPED | `tests/testthat/test-isdm-predict.R` mixed-arm regression | Preserve exact arm-specific inverse-link dispatch. |
| SPDE field re-add and training identity | SHIPPED | `tests/testthat/test-isdm-predict.R` #1132 blocks | Treat identity as a deterministic oracle, not held-out accuracy evidence. |
| Unsupported random-slope warning | SHIPPED | `tests/testthat/test-isdm-predict.R` | Preserve the warning/refusal boundary for spatial slopes and other unhandled tiers. |
| Prediction-test tier comment | STALE | `tests/testthat/test-isdm-predict.R` comment preceding #1138 tier tests | Remove the outdated claim that `re_int` is not re-added after the lease releases. |
| Canada-warbler point map | SHIPPED / UNCERTIFIED | `vignettes/articles/isdm-canada-warbler.Rmd` map section | Keep it as executable relative-intensity behavior; do not imply held-out accuracy. |
| Canada-warbler uncertainty warning | PROTECTED | same article uncertainty section | Preserve “no map uncertainty” until calibration passes. |
| E1 fixed-effect Wald coverage | DONE / NARROW | `dev/isdm-intervals/2026-08-18-e1-n600-results.md` | Retain 22,200 fits, 48/48 cells, coverage 0.939--0.959, PD 0.858--0.947 as fixed `trait:env` evidence only. |
| Fixed-only map `se.fit` | RETRACTED | `dev/isdm-intervals/2026-08-18-feasibility-results.md` | Coverage 0.23--0.82 cannot support eta or map intervals. Keep it visible as the negative control. |
| Private G2 evidence | PROTECTED NEGATIVE PROVENANCE | historical `dev/isdm-package-recovery/` private fitters | Never merge or reinterpret it as public-route recovery. |
| Coefficient/API/docs paths | PROTECTED | live `codex:structured-column-coef-family` lease | No edits until released and a new exact-main source candidate is qualified. |

## Highest-risk contradictions

1. Design 127 says the map API is wholly unimplemented, while the article and
   prediction tests exercise an SPDE-backed point map.
2. Designs 126/127 retain pre-#1132 “field absent” language despite exact
   training-row re-add tests.
3. One #1138 test comment still lists `re_int` as unreconstructed after the
   implementation made it reconstructible.
4. The article’s operational version statement can be overread as held-out map
   validation; no such certificate currently exists.
5. The 22,200-fit E1 pass concerns a fixed environmental coefficient, whereas
   the available fixed-only map standard error is demonstrably under-calibrated.

