# G2d deterministic-contract reconciliation

| Axis | Approved plan | Actual | Classification | Consequence |
| --- | --- | --- | --- | --- |
| Scope | Private, six-species, nonspatial known-truth contract work only | Pure helpers, private runner, and private tests changed | pass | public surfaces and adjacent design lanes remain untouched |
| GBIF bias gate | Bias enters GBIF only; survey visits remain cloglog and conditionally independent | Rowwise no-fit oracle demonstrates that changing bias changes only GBIF terms | pass | source-separation contract is executable |
| Shared state | All sources share the ecological cell/species state | Existing event contract and fixture assertions remain exercised without fitting | pass | no separate survey ecological state was introduced |
| Lambda plus Psi | Rank-one `Lambda` with six free diagonal `Psi` coordinates | Rank-one package packing and diagonal perturbation contracts are tested | partial | the actual TMB parameter map/extractor still needs a separately approved fit |
| Ordinary pairing | GBIF and survey visit 1 align exactly in the ordinary fixture | Exact-pair validator applies only to `ordinary`; disconnected and weak-overlap attacks remain valid | pass | adversarial support tests remain meaningful |
| Fitting | No new fit, smoke, retry, profile, or campaign without a separate decision | None run | pass | retained `G2D_SMOKE_HOLD` is unchanged |
| Claims | No recovery or Paper-2 efficacy claim | No numerical recovery output produced | pass | no claim boundary moves |

**Rose reconciliation verdict**: the deterministic contract is strengthened and
its no-fit evidence is complete for this phase. It is not a fitted
implementation completion. One narrowly scoped diagnostic fit is the next
decision gate: inspect the actual six-coordinate `theta_diag_B` map and
`extract_Sigma` reconstruction on a fresh ordinary fixture, with no profile,
smoke, campaign, or remote compute.
