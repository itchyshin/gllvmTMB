# Melissa reconciliation — release-complete interval calibration

Date: 2026-08-25
Branch: `codex/interval-calibration-release`
Planned base: `f5ba7bdb2e454f3d3cda34936f0bb9b746459e68`
Upstream base recorded at start: `origin/main` `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`

## Plan versus actual on six axes

| Axis | Planned | Actual | Melissa assessment |
| --- | --- | --- | --- |
| Scope | Give every CI-08--CI-15 public interval route an exact estimand, evidence pointer, denominator, and terminal status; add no API, likelihood, C++, formula-grammar, LV, MSPL, prediction, or missing-data work. | The 19-row route census covers CI-08 through CI-15 once by route identity. The implementation stayed in the approved interval paths plus the exact CI-08 status predicate and reader boundary. No public signature, likelihood, C++, grammar, LV, MSPL, prediction, or missing-data route was added. | On scope. |
| Evidence and verification | Build pure packet tests, retain all attempts, recompute target evidence independently, use `coverage >= 0.94` and `coverage - 2 MCSE >= 0.94`, then obtain an independent D-43 verdict. | Packet tests and negative controls passed. The 150,019-row all-attempt ledger retains 85,000 infrastructure-excluded rows, 55,000 canonical science rows, one excluded duplicate, 10,000 provenance failures, and 18 CI-10 cost-preflight rows. A clean replay reproduced the 18-row target CSV byte-for-byte. The exact 19-route/state oracle rejects arbitrary route renames, status drift, and any certified row that drops the frozen DGP or conditional on eligible fits boundary. The D-43 panel certified only three exact CI-13 tested regimes. | Stronger than route-availability evidence; no failed attempt disappeared. |
| Compute routing | Estimate every fit/simulation; run only bounded local smoke before approval; after explicit approval run five sequential Totoro waves and one Fir/DRAC CI-10 cost array; never use GitHub Actions for science compute. | Every run had a written estimate. The first Totoro deployment failed because `assertthat` was absent; all 85,000 attempts were retained as infrastructure-excluded. The corrected Totoro r2 sequence completed PVT-02, CI-09, and CI-13, stopped CI-14 at the frozen-source guard, and did not start CI-15. The approved 18-task Fir cost preflight completed; all base fits failed before bootstrap. No GitHub Actions science compute ran. | On routing, with one retained deployment incident and correct fail-closed stops. |
| Model and review routing | Fisher owns estimands/calibration, Noether profile math, Grace reproducibility, Rose claim boundaries; use a fresh D-43 completion panel. | Noether blocked PVT-02 promotion and CI-09's unidentified design. Grace replayed evidence from a clean path. Rose then showed that the PVT mechanism defect also invalidates the historical `n=150` exact-profile labels and required a non-vacuous route/state oracle. The first post-Rose Terra reviews passed, but a fresh Sol-high review withheld because CI-13's public wording omitted its fixed truth-parameter regime and eligible-fit condition. After that repair passed at `7cff7e16`, Rose found one final release-matrix omission: `unrotated`. A red-first regression test and verifier repair restored the fence. Exact-SHA Terra statistical, Terra release, and Sol-high rebinds passed at `c86968ab9d69cd88f06e8892b4c00f451edd3691`; Rose's exact-SHA closure review and Grace's reproducibility review also passed. | On plan; independent review materially narrowed both new and inherited claims. |
| Public claims | Restrict the historical CI-08 certificate to exact `n_units=150`, `d=1/2` cells; promote only exact cells that clear all gates; keep all other routes limited, blocked, or refused. | New mechanism evidence forced a fail-closed deviation: CI-08 is `route-only` in every cell because neither historical nor PVT endpoints retain exact constrained-refit fidelity. CI-09, CI-14, and CI-15 are blocked; CI-10 stays limited/blocked; CI-11/12 remain refused. CI-13 certifies only structurally free strict-lower symmetric-Wald targets in `(150,2)`, `(400,1)`, and `(400,2)` native pinned unrotated regimes, for one frozen DGP, conditional on eligible fits. Other truth-parameter values do not inherit the result. | Stronger than plan: the programme withdrew an inherited claim when its mechanism could not meet the approved exact-profile contract and narrowed the surviving certificate to the actually tested regime. |
| Landing and handoff | Run focused and ordinary tests, affected documentation checks, Unlazy `--reverify`, Rose/Grace closure review, after-task validation, handoff gate, and narrow local commits; do not push or merge. | Focused tests passed. A monolithic ordinary run exceeded its 12--25 minute estimate and was stopped; the same 523 configured ordinary files then passed in deterministic shards. `pkgdown::check_pkgdown()` and both affected article renders passed. Closure documents and the pre-write handoff gate are complete; final review, Unlazy reverify, after-task validation, and the closure commit are recorded only after they actually pass. No push, PR, merge, or release is performed. | On plan after an estimate-compliant test-suite reroute. |

## Material deviations and what they mean

The first Totoro archive is not erased or relabelled as science. It remains a
338,350,080-byte invalid-deployment archive with SHA-256
`0402b3e1484f56c92fa40cf362c4bb30b5c1de7feba221250261ad907d89c396`.
The corrected r2 archive and Fir archive are separately checksummed, so the
repair does not rewrite operational history.

PVT-02 mechanically cleared both numerical target gates, but the production
penalty-profile implementation accepts target mismatch and can interpolate
over failed refits. The plan asked for an exact likelihood-ratio profile with
every nuisance parameter reoptimised. The retained endpoints cannot establish
that stronger contract. Rose showed that the historical `n=150,d=1/2`
campaigns used the same mechanism and retained the same insufficient endpoint
detail. All total-variance profile rows therefore fail closed to `route-only`;
the former exact-cell labels are withdrawn.

CI-09's extreme coverage is not treated as a clean negative calibration result.
With one Gaussian pair per unit and a free residual variance, the frozen DGP
identifies total covariance rather than the separately scored unit-tier
correlation. This is a design block, not evidence against Fisher-z intervals in
a correctly identified experiment.

The shared NEWS, validation-debt register, and check log remained under the live
`codex:lv-mixed-family-g0` lease during most of closure. This lane did not
bypass or revert that owner. The LV lane released those exact paths, after which
this lane claimed them and made the interval-only truth-cascade integration.

## Melissa verdict

**ON PLAN, WITH HONEST TERMINAL BLOCKS.** The programme delivered a status and
evidence trail for every in-scope public route. It did not convert a numerical
pass into a certificate when the estimand or profile contract was not proven,
and it preserved every failed operational and scientific attempt in the
denominator record.
