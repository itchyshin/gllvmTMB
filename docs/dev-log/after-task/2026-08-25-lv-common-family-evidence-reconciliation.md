# After Task: LV common-family evidence reconciliation

**Branch**: `codex/lv-family-evidence-reconcile`
**Base**: `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4` = local `origin/main` at branch creation
**Date**: 2026-08-25
**Roles engaged**: Ada, Gauss, Noether, Fisher, Jason, Emmy, Rose, Grace, Melissa

## 1. Goal

Audit existing predictor-informed latent-variable common-family evidence in
GLLVM.jl without mutating its dirty checkout, issue one required verdict, and
make only the bounded internal gllvmTMB reconciliation that the evidence earns.

## 2. Implemented

The durable receipt returns exactly:

`LV_COMMON_FAMILY_HOLD__RAW_OR_LINEAGE_GAP`

It pins the clean supported GLLVM.jl candidate, distinguishes branch commits
from candidate-ancestral squashes, fixes the estimand at rotation-invariant
`B_lv`, records the family parameterisations and attempt denominators, verifies
the historical Poisson-generator and finite-difference-Hessian repairs, and
confirms the R/candidate endpoint contract. It also freezes—but does not
launch—the smallest missing-evidence raw-retention pre-run.

## 2a. Mathematical Contract

The audited cell is complete-response `latent(..., unique = FALSE)`:

\[
u_i=X_{lv,i}\alpha+e_i,\quad e_i\sim N(0,I_K),\qquad
B_{lv}=\Lambda\alpha^\top,\qquad
\Sigma=\Lambda\Lambda^\top.
\]

`B_lv`, not raw `alpha` or `Lambda`, is the cross-fit target. This audit does
not validate ordinary gllvmTMB `latent()`'s default
`Sigma = Lambda Lambda^T + diag(psi)` contract. No public R API, likelihood,
formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown
navigation changed.

## 3a. Decisions and Rejected Alternatives

Decision: HOLD. Rationale: the source contract and corrected implementation are
present, but no seed-level common-family results, failed-attempt rows, earned
MCSEs, predeclared denominator policy, or retained all-family K=2 driver exist.
REUSABLE was rejected because narrative tables cannot carry the calibration
claim. BLOCKED was rejected because the clean pinned candidate exposes the R
bridge endpoint; the dirty owned checkout is a path hazard, not a mismatch in
the supported candidate. Confidence: high after independent Sol adjudication.

## 4. Files Touched

- `docs/dev-log/plans/2026-08-25-lv-common-family-evidence-reconciliation.md`
- `docs/dev-log/artifacts/methods-superarc/lv-common-family-evidence-reconciliation.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-25-lv-common-family-evidence-reconciliation.md`
- `docs/dev-log/plan-actual/2026-08-25-lv-common-family-evidence-reconciliation.md`
- `docs/dev-log/handover/2026-08-25-lv-common-family-evidence-reconciliation.md`

The ignored Unlazy ledger is
`.unlazy/lv-common-family-reconcile/GATES.md`; it is execution state, not a
committed artifact. No example file changed. Design 73,
`docs/design/35-validation-debt-register.md`, and
`docs/design/61-capability-status.md` remain byte-for-byte unchanged because
HOLD forbids a promotion.

## 5. Checks Run

- `git merge-base --is-ancestor 6c96b758 origin/main` and the same check for
  `2ce6e29f` in GLLVM.jl: both exit 0.
- `git -C <GLLVM.jl> rev-parse origin/main`: exact candidate
  `8c9acc76c5b81e40a228ba11060394cbac5cf13c`.
- `git show origin/main:src/bridge.jl | rg -n 'function bridge_fit|X_lv|lv_effects|confint_lv_effects'`:
  required endpoint/payload markers present.
- Static fixed-string Poisson-generator guard:
  `POISSON_GENERATOR_NEGATIVE_CONTROL_PASS`.
- Static fixed-string finite-difference-stencil guard:
  `FD_HESSIAN_NEGATIVE_CONTROL_PASS`.
- `git diff --name-only -- docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md`:
  no output.
- `git diff --check`: no output.
- Unlazy `--reverify` is the terminal post-commit close gate; its exact result
  belongs in the final lane return because it necessarily postdates this
  committed report.

No R package test/check/render was warranted: package source, tests, examples,
roxygen, vignettes, and public documentation are unchanged. No fit, simulation,
benchmark, Totoro/DRAC job, or GitHub Actions science compute ran.

## 6. Tests of the Tests

No package test was added. The two static guards each include the historical
failure string as a negative control and require the corrected candidate
pattern. Their failed first-pass detector escape is retained in the check log;
the final versions use fixed strings so R cannot reinterpret the source token.

## 7. Roadmap Tick

N/A: no `ROADMAP.md` row changed.

## 7a. Issue Ledger

`gh issue list --state open --search "predictor latent X_lv"` returned no
issue. A broader `"latent variable"` search returned #935, #1161, #943, #941,
#945, #939, #347, and #565. Issue #935 was inspected and concerns the EVA
track, not predictor-informed `X_lv` sister evidence. No relevant open issue;
no new issue created because this lane freezes an approval-gated pre-run rather
than starting a new campaign.

## 8. Consistency Audit

- `rg -ni 'B_lv|raw alpha|raw Lambda' docs/dev-log/artifacts/methods-superarc/lv-common-family-evidence-reconciliation.md`:
  the rotation-invariant target is explicit and raw axes are explicitly
  rejected as cross-fit targets.
- `rg -n 'latent\(\.\.\., unique = FALSE\)|Sigma = Lambda Lambda\^T|diag\(psi\)' docs/dev-log/artifacts/methods-superarc/lv-common-family-evidence-reconciliation.md`:
  the Julia loadings-only cell and the ordinary gllvmTMB `+Psi` exclusion are
  both explicit.
- `rg -n 'native-TMB|masks|mixed families|source tiers|profile/bootstrap|public' docs/dev-log/artifacts/methods-superarc/lv-common-family-evidence-reconciliation.md`:
  hits occur only in explicit exclusions.
- `rg -n 'non-positive-definite Hessian|PD Hessian' docs/dev-log/artifacts/methods-superarc/lv-common-family-evidence-reconciliation.md`:
  no hit; the receipt uses the exact historical `pd_hessian`/successful-inverse
  proxy.
- `git diff --name-only -- R src tests README.md NEWS.md ROADMAP.md vignettes man`:
  no output.

The prose pass is written for a statistical-method developer or future package
auditor: claims name exact commits, scripts, equations, denominators, and
missing artifacts. No reader-surface stale-wording sweep or pkgdown inventory
was needed because no reader surface changed.

## 9. What Did Not Go Smoothly

The plan's twin row remained pending too long and its D-43 classification was
too broad; the adjudicator forced both corrections. The first Unlazy G2 command
used an invalid R escape, its repair initially encountered Git's collapsed
untracked-directory path, and the first Poisson detector repeated the escape
error. The handoff gate also correctly found uncommitted lane files and many
foreign unpushed branches. All failures remain in the check log; none was
relabelled as a pass. An early receipt draft briefly contained a mistyped full
hash, which was removed before scientific review and replaced with the git-show
value.

## 10. Known Residuals

The historical K=1/K=2 common-family calibration tables remain narrative-only.
Any continuation starts a fresh task and first requests an owner decision for
a clean GLLVM.jl worktree at `8c9acc76`. Only then may the frozen four-fit
Poisson/NB2/Gamma/Beta raw-retention pre-run run locally under its 8--20-minute
estimate; it must stop if projected time exceeds 30 minutes. No 500-replicate
rerun, remote compute, status promotion, or public claim is authorized.

## 11. Team Learning

**Jason** separated historical branch commits from the squashed commits that
actually reach the clean candidate and inventoried retained raw artifacts.

**Gauss** verified NB2, Gamma, and Beta dispersion parameterisations and the
finite-difference stencil; shared parameterisations cannot be widened to
grouped/per-trait claims.

**Noether** kept `B_lv` as the rotation-invariant target and caught the need to
name `latent(..., unique = FALSE)` so evidence cannot leak to the default
`+Psi` contract.

**Fisher** treated seed-level rows, every failed attempt, earned MCSE, and a
predeclared denominator policy as claim-bearing requirements; complete
narrative denominators did not override their absence.

**Emmy** confirmed that current gllvmTMB and the clean pinned GLLVM candidate
agree on family keys, `X_lv`, `lv_effects`, score components, and Wald payloads.

**Rose** enforced HOLD-only scope, corrected `pd_hessian` from a positive-
definiteness claim to its actual successful-inverse proxy, and kept the dirty
GLLVM checkout protected.

**Grace** reviewed reproducibility, the local candidate pin, the absent raw
artifacts, the frozen pre-run receipt, and the no-remote/no-compute boundary.

**Ada** integrated the exact verdict and accepted that compatible source code
is necessary but insufficient for reusable calibration evidence.

**Melissa** recorded two adaptive plan corrections and no scope or safety
drift.

## 12. Cross-Product Coverage

This receipt covers only the complete-response, loadings-only
`latent(..., unique = FALSE)` GLLVM bridge cell and the named common-family
shared-dispersion endpoints. It does NOT cover ordinary `latent()` with `+Psi`,
native TMB, response masks, fixed `X + X_lv`, mixed families, grouped/per-trait
dispersion, source tiers, profile/bootstrap inference, public calibration
claims, or any remote/campaign execution.
