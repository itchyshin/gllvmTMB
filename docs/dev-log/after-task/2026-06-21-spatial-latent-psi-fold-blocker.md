# After Task: spatial_latent Psi Fold Blocker

Date: 2026-06-21
Agent: Codex / Ada
Branch: `codex/spatial-latent-psi-fold-20260621`
Worktree: `/private/tmp/gllvmtmb-spatial-latent-psi-fold`
Base: `origin/main` at `a16611b`

## Task Goal

Start Stage A after the phylo slice by carrying the `spatial_latent()`
unique-Psi fold forward. The handover required one pre-edit guard:
confirm that the SPDE diagonal engine slot is wired before changing
`R/brms-sugar.R`, `R/fit-multi.R`, tests, or docs.

That guard failed. I stopped before code edits.

## Mathematical Contract

No public R API, formula grammar, likelihood, family, NAMESPACE,
generated Rd, vignette, pkgdown navigation, or exported function
changed in this task.

The target contract for the future fold is:

`spatial_latent(..., d = K, unique = TRUE)` should mean
`Sigma_spde = Lambda_spde Lambda_spde^T + Psi_spde`.

Current engine evidence supports only these alternate branches:

| Component | Current syntax / marker | Engine path | Status |
| --- | --- | --- | --- |
| `Lambda_spde Lambda_spde^T` | `spatial_latent(..., d = K)` / `.spatial_latent` | `spde_lv_k >= 1`, `theta_rr_spde_lv`, `omega_spde_lv` | wired |
| `Psi_spde` | `spatial_unique(...)` / `.spatial_unique` | `spde_lv_k == 0`, `log_tau_spde`, `omega_spde` | wired as an alternate path |
| additive sum | intended future `spatial_latent(unique = TRUE)` | both low-rank and per-trait SPDE fields in one fit | not wired |

This is not the same shape as `phylo_latent()`, where the diagonal
companion can be folded through an existing source-specific companion
path. The SPDE path currently switches between representations.

## Files Created Or Changed

- `docs/dev-log/check-log.md`: recorded the pre-edit blocker and exact
  search patterns.
- `docs/dev-log/after-task/2026-06-21-spatial-latent-psi-fold-blocker.md`:
  this report.
- `docs/dev-log/recovery-checkpoints/2026-06-21-132958-codex-spatial-latent-blocker.md`:
  compact checkpoint for the next agent or maintainer decision.

No R, C++, test, roxygen, generated Rd, vignette, README, NEWS,
ROADMAP, `_pkgdown.yml`, or validation-debt implementation files were
changed.

## Checks Run And Outcomes

- `git fetch --all --prune`: completed before creating the fresh worktree.
- `git status --short --branch` in the mission-control checkout:
  confirmed it is dirty on `codex/r-bridge-grouped-dispersion`; it was
  not touched.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,url`:
  returned `[]`.
- `git log --all --oneline --since="6 hours ago"`: showed recent merged
  latent unique / phylo unique / kickoff commits and no open PR
  collision.
- Pruned clean merged `/private/tmp/gllvmtmb-*` worktrees left by prior
  sessions.
- Created `/private/tmp/gllvmtmb-spatial-latent-psi-fold` from
  `origin/main`.
- `rg -n "spde|spatial_unique|spatial_latent|use_spde|spatial_diag|spde_diag|auto_unique|is_auto_.*psi|auto_unique_off_family" R/fit-multi.R R/brms-sugar.R src/gllvmTMB.cpp tests/testthat`:
  confirmed split SPDE paths and no spatial auto-Psi machinery.
- `rg -n "Sigma_spde|Lambda_spde|log_tau_spde|omega_spde|spatial_latent.*unique|spatial_unique.*latent|spde_lv_k" R/extract-sigma.R R/extract-correlations.R R/output-methods.R R/check-consistency.R tests/testthat`:
  confirmed existing tests mostly prove fit construction, Lambda shape,
  and smoke health, while the extractor states there is no `S_spde`
  unique component.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "spatial_latent OR spatial_unique OR latent unique" --limit 20 --json number,title,url,state`:
  returned broad status/roadmap issues #340, #361, #342, #348, #230,
  #341, #349, and #347; no dedicated spatial-fold blocker issue found.

Attempted two parser probes with `Rscript --vanilla -e
'devtools::load_all(".", compile = FALSE, quiet = TRUE); ...'` for
bare and paired `spatial_latent()`. Both remained silent in
`load_all()` for more than two minutes and were interrupted. No result
from those probes was used as evidence.

Post-rebase closeout after #524 merged:

- rebased the branch onto `origin/main` `04b7523`;
- resolved the append-only `docs/dev-log/check-log.md` conflict by
  keeping both the #523 diagnostic entry and this spatial blocker
  entry;
- `git diff --check` stayed clean;
- attempted full `Rscript --vanilla -e 'devtools::check(args =
  "--no-manual", quiet = TRUE, error_on = "never")'`, but the local
  process manager killed it with exit 137 after about 20 seconds and
  no discoverable `.Rcheck` directory was left.

Not run to completion: RED G1-G4 tests, `devtools::test()`,
`devtools::check()`, `devtools::document()`, pkgdown checks, or article
builds. The engine precondition failed before implementation; the
docs-only branch should use PR CI as the remote gate.

## Consistency Audit

The key consistency problem is source-local:

- `R/fit-multi.R:997-1006` says `spatial_latent()` toggles from the
  per-trait `omega_spde` path used by `spatial_unique()` /
  `spatial_scalar()` to the low-rank `Lambda_spde x omega_spde_lv`
  path.
- `R/fit-multi.R:3495-3497` maps off `log_tau_spde` and `omega_spde`
  under `is_spatial_latent`.
- `R/fit-multi.R:3947-3948` adds either `omega_spde` or
  `omega_spde_lv` to TMB's random vector, not both.
- `src/gllvmTMB.cpp:1352-1412` branches between per-trait SPDE and
  low-rank spatial latent representations.
- `src/gllvmTMB.cpp:1669-1780` adds either the per-trait field or the
  low-rank field to `eta`.
- `R/extract-sigma.R:1158-1163` states that `spatial_latent` has no
  per-trait unique component and no `S_spde`.

This conflicts with treating `spatial_latent() + spatial_unique()` as
evidence for an additive source-specific decomposition. Some tests use
that paired syntax and pass fit-health assertions, but they do not
demonstrate that the diagonal spatial field is present alongside the
low-rank field.

## Tests Of The Tests

No RED-first test was added because the precondition was not met.
The likely future RED test should assert that a paired or folded
`spatial_latent + spatial_unique` fit has both:

1. `spde_lv_k >= 1` with reported `Lambda_spde`; and
2. an estimated per-trait SPDE diagonal companion, visible in the
   random vector, reports, and `extract_Sigma(level = "spde")`.

That test should fail on current `main` before engine work starts.

## What Did Not Go Smoothly

The handover's planned fold recipe assumes the source-specific
diagonal companion can be represented by emitting an auto companion
term and deduplicating explicit terms. That is true for the completed
phylo slice, but the SPDE engine currently branches between per-trait
and low-rank representations. A parser-only fold would silently
advertise `Lambda_spde Lambda_spde^T + Psi_spde` while fitting only
the low-rank path.

`devtools::load_all()` was slow enough in parser probes that I
interrupted rather than use them as evidence. Static source evidence
was sufficient for the pre-edit guard.

## Team Learning And Role Review

Ada enforced the handover's stop condition: confirm the engine slot
before coding. This prevented a shallow copy of the phylo recipe onto
the spatial path.

Boole should review any future syntax decision because `unique=TRUE`
for `spatial_latent()` would otherwise look parallel to `phylo_latent()`
while relying on different engine machinery.

Gauss should review the SPDE likelihood if the maintainer approves an
engine change. The additive path would need both low-rank shared SPDE
fields and per-trait diagonal SPDE fields, with a clear identifiability
choice for shared `kappa`, tau scaling, and loading scale.

Noether should check the symbolic contract before implementation:
`eta_spde(o, t) = sum_k Lambda_spde[t, k] A omega_lv[k](o) +
A omega_diag[t](o)` must match the TMB prior blocks and the extractor's
reported `L`, `S`, and `Sigma`.

Curie should make the first implementation test RED on current `main`
by requiring the diagonal companion to exist in a folded spatial fit,
then add the G1-G4 heavy tests from the handover.

Grace should keep the full `devtools::check()` pre-push guard. No full
check was run here because no implementation was attempted.

Rose should treat this as a status-ledger correction: the validation
debt and docs that describe `spatial_latent + spatial_unique` as a
paired decomposition need reconciliation once the maintainer chooses
whether to implement the engine or defer spatial.

## Design-Doc Updates

No design doc was changed because this task stopped at the pre-edit
checkpoint. If engine work proceeds, update at minimum:

- `docs/design/2026-06-21-source-specific-latent-psi-fold.md`;
- `docs/design/01-formula-grammar.md`;
- `docs/design/35-validation-debt-register.md`;
- any SPDE-specific design note that claims paired
  `spatial_latent + spatial_unique` support.

## Pkgdown / Documentation Updates

None. No user-facing documentation was rebuilt or changed.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed because Stage A spatial did not start.

## GitHub Issue Ledger

Inspected open issues with:

`gh issue list --repo itchyshin/gllvmTMB --state open --search "spatial_latent OR spatial_unique OR latent unique" --limit 20 --json number,title,url,state`

The results were broad status/roadmap issues: #340, #361, #342, #348,
#230, #341, #349, and #347. No dedicated spatial-fold blocker issue was
found. No issue was created or commented because the maintainer
checkpoint is the immediate next action.

## Known Limitations And Next Actions

Known limitation: the current SPDE engine does not expose an additive
low-rank-plus-diagonal source-specific spatial covariance path.

Next action: maintainer decision. Either pause spatial and continue the
Stage A sequence with a source fold whose diagonal companion is wired
(`animal_latent()` or `kernel_latent()`), or explicitly approve an SPDE
engine change before parser work. If approved, begin with a RED test
for additive `Lambda_spde Lambda_spde^T + Psi_spde`, invoke the TMB
likelihood review path, update the design/register docs, and run G1-G4
plus full `devtools::check()` before push.
