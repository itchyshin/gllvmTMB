# Ultra Plan — Internal fixed-rho `phylo_coef()` engine

🎯 GOAL

```text
Solo platform: Codex
Deliverable: an internal Gaussian `phylo_coef()` fixed-rho route whose
  `rho = 1` fit is exactly equivalent to the released `phylo_slope()` route,
  while `0 <= rho < 1` uses Design 131's raw-scale-preserving covariance
  mixture; no public API claim is made.
HEADLINE: admit and test the fixed-rho phylogenetic coefficient block without
  changing the warning-free released `*_slope()` APIs.
IN PARALLEL: engine-contract reconnaissance and test-oracle design.
DEFER: estimated rho; exports; extractors; intervals; non-Gaussian families;
  article teaching; animal, kernel, and spatial coefficient engines.
DISCIPLINE: verify=exact fit/object/map/report gates plus independent review;
  compute=local focused tests only, with any recovery campaign separately
  estimated and approved; closure=protected PR, exact-head 3-OS evidence,
  normal merge, and exact-main verification.
```

## Scope and locked mathematics

For the coefficient matrix `B` (response columns by selected intercept/slope
basis), the target block is

```text
B ~ MN(0, K_rho, Sigma_coef)
K_rho = rho K + (1 - rho) diag(K),  0 <= rho <= 1.
```

`K` is the supplied phylogenetic covariance on the response-column levels.
The mixture preserves its supplied marginal scale. Thus `rho = 1` uses `K`
unchanged and must be exactly equivalent to `phylo_slope()` for the no-intercept
basis; `rho = 0` removes only between-column covariance and is IID only when
`diag(K) = I`. The public formula spelling and lifecycle of `phylo_slope()` are
unchanged and warning-free.

**Dense-VCV compatibility convention:** the existing dense legacy
`phylo_slope()` path adds `1e-8 I` before its precision/determinant calculation.
The exact `rho = 1` no-intercept comparator therefore hard-dispatches to that
legacy route and compares its effective conditioned covariance `K0`. The new
raw-scale `K_rho` oracle is applied to the supplied strictly positive-definite
`K` for fixed interior `rho` (including near one) without a ridge. This narrow
internal slice does not claim continuity at the legacy dense-VCV endpoint or
change the released slope implementation. Recon must record tree, sparse, and
dense behavior separately; a public interface waits for a later compatibility
decision if this distinction cannot be eliminated safely.

This plan admits only the internal, fixed numeric `rho` Gaussian point route.
It does not claim a public helper merely because internal formula parsing
already exists.

## Phase-0 receipts

- **Preflight:** `lane_preflight.sh` on 2026-08-27 reported three other active
  Codex lanes. `codex:cross-family-lv-predictor-bridge` currently leases
  `R/fit-multi.R` and `R/gllvmTMB.R`; this plan may not edit either until its
  explicit release receipt. The planning-path lease is
  `codex:phylo-coef-fixed-rho-plan` on this file only.
- **Git state:** fresh isolated worktree `/private/tmp/gllvmTMB-phylo-coef-fixed-rho`
  is on branch `codex/phylo-coef-fixed-rho-plan` at verified main
  `870944744ff090fe8676e853ebc03957204571c0`, the normal merge commit for
  PR #1216. PR #1216's exact-main R-CMD-check `33067429411` succeeded.
- **Repository sweep:** Design 131 and
  `docs/dev-log/after-task/2026-08-26-column-coef-iid-engine.md` establish
  that the IID route is the only fitted coefficient engine. They require the
  fixed-rho phylogenetic successor to begin from fresh main, use a new ledger,
  and prove exact `rho = 1` equivalence before admission.
- **Sister sweep:** a targeted scan of `GLLVM.jl` found no `phylo_coef()` or
  response-column coefficient implementation to port. This is an R/TMB
  extension of the released `phylo_slope()` path, not a twin-port task.
- **Brain sweep:** local `basic-memory search-notes` was run for
  `gllvmTMB phylo_coef fixed rho response-column coefficient`; it did not
  return a load-bearing programme record. Repository Design 131 and the IID
  after-task record therefore remain the technical source of truth.

**Verdict:** reuse the released response-column slope parameter/data/map route
only for the exact no-intercept `rho = 1` identity. Before code, identify the
specific response-column (not cluster-tier) precision, determinant, augmented
index, random-effect, and Cholesky-map path. Build the fixed interior-rho
coefficient route only after that source map is written and reviewed.

## Route check

The destination is concrete, every implementation slice names files and test
results, and there is no unresolved design alternative: the route is knowable.
The sole dependency is ownership of the two shared routing files, not a
methodological decision.

## Acceptance gates, written before implementation

| Gate | Required evidence |
| --- | --- |
| G1 — source validation | Tree, dense named `vcv`, and sparse source forms preserve current response-column `phylo_slope()` labels, coverage, symmetry, and positive-definiteness errors; permuted labels reorder exactly. |
| G2 — mixture oracle | A pure-R oracle constructs one reordered, symmetrised `K_rho`, its `Q_rho = solve(K_rho)`, and `log|K_rho|` from supplied strictly-PD `K` at `rho = 0` and interior values such as `0.37` and `0.999`. It checks SPD/symmetry and `K -> cK` implies `K_rho -> cK_rho`; it must not interpolate precisions or log determinants. Dense legacy `rho = 1` is instead G3's conditioned `K0` comparator. |
| G3 — exact legacy identity | For both `tree=` and named `vcv=` sources, and both `|`/`||`, no-intercept `phylo_coef(0 + x | trait, rho = 1)` dispatches to the identical released `phylo_slope(x | trait)` data/random/map/parameter route, with no added ridge or jitter. At one common mapped TMB vector compare assembled `K`, objective, gradient, free map, random effect, parameter names, report, then compare independently optimized fits and fitted values. |
| G4 — fixed-rho validation | `rho` is a finite scalar in `[0,1]`; `NULL` and invalid inputs reject clearly, and it remains fixed R data rather than an estimated/transformed TMB parameter. Endpoint and near-one tests prove no interior value is snapped to one. |
| G5 — coefficient-basis extension | For fixed `rho < 1`, `phylo_coef(1 + x | trait)` has an intercept-first design, full/diagonal `Sigma_coef`, the canonical `Q_rho`/log-determinant, and matrix-normal prior `0.5[T log|Sigma_coef| + P log|K_rho| + tr(Sigma_coef^-1 B' Q_rho B)]` (up to shared constants). |
| G6 — recovery and slope preservation | A small known-DGP non-unit-scale fixed-rho intercept/slope fit recovers `Sigma_coef` and source-scale behavior and has finite truth/optimum gradients. Existing `phylo_slope()` tests—both bars plus representative ordinary slope paths when shared sugar changes—remain `expect_no_warning()` and unchanged. Any larger recovery grid gets a separate estimate, smoke, and approval. |
| G7 — internal boundary | Test a private test-only entry explicitly while every public `phylo_coef()` formula call retains the classed pre-engine fence. Scan that markers remain absent from `NAMESPACE`, Rd/reference, pkgdown, NEWS, README, and articles. Any public-formula admission is a stop and a separate public-API plan. |
| G8 — closeout | Focused tests, `pkgdown::check_pkgdown()`, `git diff --check`, Rose plus Gauss/Noether reviews, protected exact-head 3-OS CI, normal merge, and exact-main package check. |

## Slice table

| Slice | Member | Model + effort | Dispatch | Output | Dependency |
| --- | --- | --- | --- | --- | --- |
| Recon | Ada / mechanical scout | Luna low | tiered-cli/enforced when implementation begins | exact call-site and data-contract map | none |
| S1 source-map + symbolic/TDD contract | Noether + Curie | Terra high | native/explicit | response-column-versus-cluster source map, pure-R `K_rho/Q_rho/logdet` oracle, and failing test specification | shared files released |
| S2 R engine routing | Gauss + Emmy | Terra high | native/explicit | minimal R changes in `R/gllvmTMB.R`, `R/fit-multi.R`, and supporting internal helper; hard `rho = 1` legacy dispatch | S1 |
| S3 focused fit gates | Curie | Terra medium | native/explicit | test results for G1–G7 | S2 |
| S4 numerical review | Gauss + Noether | Sol high | native/explicit | independent likelihood/alignment verdict | S3 |
| S5 closeout | Rose + Grace + Melissa | Terra medium | native/explicit | review, after-task, reconciliation, handover | S4 |

**Fan-out budget:** one mechanical scout, up to four Terra slices, and one
Sol numerical verdict; no `ultra`-effort child. **SCOUT SUITABILITY:** yes,
for the read-only call-site map. **Estimated wall time:** 2–4 hours of local
development after the shared-path release; it needs a fresh continuation
context for implementation. Focused package fits are expected under 30 minutes;
do not begin a claim-bearing recovery campaign without a measured smoke and
explicit approval.

## Coordination and authority

The plan is ready, but implementation is **BLOCKED** until the cross-family LV
lane releases `R/fit-multi.R` and `R/gllvmTMB.R`. Once that receipt arrives,
claim the exact implementation/test paths, create the Unlazy ledger before
editing, complete S1's source-map check, and start test-first. If S1 cannot
identify a response-column slope route that can be reused byte-for-byte at
`rho = 1`, stop rather than weakening G3 or accidentally using a cluster-tier
phylogenetic random effect.

PRE-AUTHORISED AFTER G0: scoped edits, routine local commands, focused tests,
checkpoints, local commits, `pkgdown::check_pkgdown()`, and the named review
gates. OPTIONAL REMOTE AUTHORITY: push one reviewed branch and create one
narrow PR after the owner confirms the frozen candidate. MUST STOP: merge or
public capability claim; any article/export/lifecycle change; estimated rho;
campaign compute above 30 minutes; new ownership conflict; or a failed exact
equivalence gate.

## Plan review request

Rose must verify that the plan preserves the internal/public boundary and that
every acceptance gate has evidence. Gauss/Noether must confirm the raw-scale
mixture and the exact `rho = 1` comparator before implementation begins.

## Explicit deferrals

- Estimated `rho` and all TMB parameterisation changes needed for it.
- Public exports, roxygen/Rd, extractors, NEWS, and `where-does-the-tree-go`.
- Animal, kernel, and spatial coefficient engines. The maintainer has
  explicitly prioritised only `column_coef()` and `phylo_coef()` for the
  foreseeable programme; these three helpers require a new decision and a
  separate plan before any work resumes.
- Any soft deprecation of `*_slope()`.

## Final public article cascade (maintainer-approved, after both phylo engines)

The public article work is a final, separate arc after fixed- and estimated-
`rho` `phylo_coef()` have passed their recovery, extractor, long/wide parity,
and release gates. It is not permission to advertise the internal fixed-rho
route.

1. **`where-does-the-tree-go.Rmd` — Tier 1 worked example.** Replace the
   response-column-slope teaching only after the exported `phylo_coef()` API is
   earned. Show both a canonical long call and a `traits(...)` wide-data-frame
   call, use a coefficient basis with the agreed intercept/slope semantics,
   explain `rho`, and retain the distinction between fixed column metadata
   interactions and random coefficient deviations.
2. **`api-keyword-grid.Rmd` — Tier 2 reference boundary.** Keep the 5 × 3
   source-by-trait-covariance grid unchanged. Update its outside-the-grid
   response-column section to distinguish the retained `*_slope()` APIs from
   the admitted `column_coef()` / `phylo_coef()` coefficient bases, with a
   direct link to the Tier-1 tree-placement example.
3. **Protect `phylogenetic-gllvm.Rmd`.** This Tier-1 article already has a
   coherent, runnable long/wide `phylo_latent(..., unique = TRUE)`
   trait-covariance story. The maintainer decided on 2026-08-27 that it does not
   need a coefficient bridge now. Verify it remains internally consistent, but
   do not edit or render it merely to mention `phylo_coef()`. Reopen that choice
   only if the landed public API creates a concrete contradiction.

Before publishing, run the article-tier and prose reviews, render every article
actually changed with `pkgdown::build_articles(lazy = FALSE)`, inspect rendered
HTML at desktop and mobile widths, run `pkgdown::check_pkgdown()`, and scan every
reader-facing surface for stale claims. Confirm separately that
`phylogenetic-gllvm.Rmd` is unchanged. The rendered public site must be checked
after the normal protected merge; no article is updated in the fixed-rho
internal PR.
