# After Task: Private shared-range spatial iSDM Gate-A implementation

**Branch**: `codex/isdm-spatial-information-design`
**Date**: `2026-08-12`
**Roles (engaged)**: Ada, Gauss, Noether, Rose

## 1. Goal

Implement the approved private shared-range two-field spatial iSDM contract,
with no public surface change and no fit, simulation, profile, or remote
compute. The route must represent a shared ecological SPDE field and a
GBIF-only SPDE bias field on one mesh/range/rank, while retaining the declared
diagonal ecological residual `Psi`.

## 2. Implemented

The unexported `.gll_isdm_fit(..., spatial = TRUE, mesh = ...)` route now
constructs `spatial_latent(1 + isdm_gbif | cell_id, d = K)` plus
`indep(0 + trait | cell_id)`. The intercept SPDE column is the source-shared
ecological field; its `isdm_gbif` slope is exactly zero for PA rows. The
`indep()` term is the nonspatial `e_cs`, `Psi = diag(psi_s^2)` companion, not
a second spatial field.

The mixed Poisson/log plus PA-cloglog exception remains internal: it requires
the ordinary exact iSDM source/family contract and an identity token created
only by the private helper. Ordinary public augmented spatial slopes still
reject the cloglog route. The no-fit suite asserts the parser map, exact
prepared `Z_spde_lat` source gate, PA eta/NLL invariance, mesh alignment,
forged-token rejection, and existing family-policy fence.

**Mathematical contract.**

`eta^E_cs = alpha_s + x_c beta_s + u_c Lambda_s + e_cs`, where
`e_cs ~ N(0, psi_s^2)`, and `eta^G_cs = eta^E_cs + h_c Gamma_s` only when
`isdm_gbif = 1`. The implementation fixes the shared-range architecture:
one mesh, `kappa`, and rank serve `u` and `h`; it adds neither a second mesh,
range, rank, TMB block, likelihood family, nor public API.

## 3. Files Changed

- `R/isdm-developer-fit.R` — private spatial route, mesh receipt, source map,
  Psi companion, and internal admission token.
- `R/fit-multi.R` — token-gated internal cloglog exception and the exact
  prepared augmented-SPDE design-matrix helper.
- `tests/testthat/test-isdm-spatial-private-contract.R` — deterministic
  no-fit source/map/family/mesh tests.
- `dev/isdm-package-recovery/2026-08-12-spatial-isdm-symbolic-alignment.md`
  — implementation alignment table.
- `docs/dev-log/check-log.md` and this private receipt.

Status-inventory cascade: `README.md`, `NEWS.md`, `ROADMAP.md`, vignettes,
`_pkgdown.yml`, generated Rd, public API, and the validation-debt register are
unchanged because this is an unadvertised private route. Protected G2/Paper 2
records are unchanged.

## 3a. Decisions and Rejected Alternatives

- **Decision**: retain `Psi` as `indep(0 + trait | cell_id)` alongside the
  loadings-only augmented `spatial_latent()` term. **Rationale**: Rose found
  that bare `spatial_latent()` would omit the frozen diagonal residual.
  **Rejected alternative**: `unique = TRUE`, which would create an augmented
  spatial companion rather than the declared nonspatial `e_cs`. **Confidence**:
  high.
- **Decision**: make the actual `Z_spde_lat` constructor a pure helper and
  use it in the PA invariance test. **Rationale**: prevents an oracle from
  drifting away from the engine input. **Rejected alternative**: a separate
  hand-written source-gating oracle. **Confidence**: high.
- **Decision**: use a namespace-private identity token. **Rationale**: a
  Boolean attribute is forgeable through the public `family` input.
  **Rejected alternative**: public opt-in marker. **Confidence**: high.

## 4. Checks Run

- `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-isdm-spatial-private-contract.R", reporter="summary"); testthat::test_file("tests/testthat/test-isdm-contract.R", reporter="summary"); testthat::test_file("tests/testthat/test-augmented-slope-family-policy.R", reporter="summary")'` — PASS. The existing contract file reported three expected CRAN skips.
- `git diff --check` — PASS.
- `rg -n "gllvmTMB_internal_isdm_spatial|isdm_spatial|spatial_latent\\(1 \\+ isdm_gbif" R tests dev` — only the private route/test/alignment references.
- `rg -n "PAPER2_PRIVATE_STOP_HOLD|G2N_LOCAL_PRERUN_HOLD|G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD" docs/dev-log dev/isdm-package-recovery` — retained holds remain explicit; none changed in this diff.
- `rg -n "spatial iSDM|two-field|GBIF-only bias field" README.md ROADMAP.md NEWS.md vignettes _pkgdown.yml` — no public claim found.

No full suite, `devtools::check()`, documentation generation, pkgdown render,
fit, objective build, profile, simulation, timing probe, Totoro, or DRAC run
was run: each is outside this approval.

## 5. Tests of the Tests

The new test is a feature-combination and boundary suite. It couples
mixed-family PA-cloglog admission to augmented SPDE slopes, checks that a
forged public token rejects before TMB construction, and checks malformed mesh
and non-PA branch rejection. The PA perturbation calculation is an independent
observation-NLL oracle but takes its source gate from the exact helper used to
construct `Z_spde_lat`.

## 6. Consistency Audit

- `rg -n "gllvmTMB_internal_isdm_spatial|isdm_spatial|spatial_latent\\(1 \\+ isdm_gbif" R tests dev` — all matches are intentional private implementation or test references.
- `rg -n "PAPER2_PRIVATE_STOP_HOLD|G2N_LOCAL_PRERUN_HOLD|G2K_CALIBRATION_HOLD|G2C_SMOKE_ADMISSION_HOLD" docs/dev-log dev/isdm-package-recovery` — historical nonspatial decisions remain retained and separate.
- `rg -n "spatial iSDM|two-field|GBIF-only bias field" README.md ROADMAP.md NEWS.md vignettes _pkgdown.yml` — no public promotion occurred.

## 7. Roadmap Tick

N/A — this private Gate-A implementation is not a public roadmap capability.

## 7a. GitHub Issue Ledger

Inspected open issues #941, #904, #945, and #946. No issue was changed: this
private, synthetic architecture contract neither resolves nor advertises any
of them; no new issue was created.

## 8. What Did Not Go Smoothly

The first independent scope review caught a missing `Psi` companion, a test
oracle disconnected from the prepared engine input, and a forgeable marker.
All were corrected before closeout. Focused snapshot tests attempted to add
harmless EOF whitespace; it was excluded from the diff.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss/Noether.** Verified the exact source/family route, shared SPDE
parameterisation, ordinary compatibility, and final corrected token/Psi/Z-map
contract. The key watchpoint is that the private exception must never widen the
public augmented-slope admission policy.

**Rose.** Found the three pre-commit scope defects and confirmed their fixes.
The key reusable lesson is that a source-purity oracle must consume the same
prepared matrix as the engine, and “private” needs an enforceable boundary,
not merely a comment or Boolean attribute.

**Ada.** Kept the implementation limited to the private route and no-fit
checks; did not reopen Paper 2, change a public surface, or execute a model.

## 10. Known Limitations And Next Actions

This is only a no-fit implementation receipt. No actual spatial likelihood has
been evaluated, so no numerical admission, recovery, identifiability,
runtime/RSS, or scientific-performance conclusion exists. It does not support
occupancy/detection, count surveys, empirical analysis, absolute abundance,
generic zero inflation, arbitrary sources, public use, or `S=10,000`.

`G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`,
`G2C_SMOKE_ADMISSION_HOLD`, and `PAPER2_PRIVATE_STOP_HOLD` remain unchanged.
Return for explicit Gate B approval before preparing or running any smoke fit.
