# Scalar-collapse → three modes {indep, dep, latent} — gllvmTMB (2026-07-12)

**Author:** Claude (opus-4.8) · **Branch:** `claude/release-0.5.0`
**Arc:** the top next slice of the covariance-mode-taxonomy campaign (Design 79
§5.1), Shinichi-approved. Follows `2026-07-12-scalar-keyword-tested-tier.md`.

## Scope

Collapse the covariance grid from a four-column {scalar, indep, dep, latent}
layout to **three modes {indep, dep, latent}**, with the one-shared-variance
("scalar") case becoming the parsimony **modifier `common = TRUE`** on any
`indep` term. Soft-deprecate the whole `scalar()` / `*_scalar()` keyword family
(warn-once + rewrite, kept working). Reframe Design 79, the capability widget,
the `api-keyword-grid` article, and NEWS to the three-mode story. No new engine
— `common = TRUE` routes to each source's existing `*_scalar` engine.

Maintainer decision this session: **(a) warn-once + rewrite**, implement now,
strip the scalar column from the widget.

## Outcome

- **`common = TRUE` on the four structured `*_indep()`** (`phylo_indep`,
  `animal_indep`, `spatial_indep`, `kernel_indep`) — new named arg (default
  `FALSE`). `common = TRUE` desugars **byte-identically** to the corresponding
  `*_scalar()` engine call (verified, table below). Intercept-only; the
  shared-variance random slope (former `scalar(1 + x | g)`) errors with a
  "later slice" message. `R/brms-sugar.R`, `R/animal-keyword.R`,
  `R/kernel-keywords.R`.

  | canonical | routes to |
  |---|---|
  | `phylo_indep(0+trait\|sp, common=TRUE)` | `phylo(sp)` |
  | `animal_indep(0+trait\|id, common=TRUE)` | `phylo(id, vcv=A)` |
  | `spatial_indep(0+trait\|coords, common=TRUE)` | `spde(form, .spatial_scalar=TRUE)` |
  | `kernel_indep(unit, K, common=TRUE)` | `phylo_rr(unit, .indep, .kernel_mode="scalar")` |

- **Scalar family soft-deprecated** — `scalar()`, `phylo_scalar()`,
  `animal_scalar()`, `spatial_scalar()`, `kernel_scalar()` now emit a one-time
  per-session warning steering to `*_indep(common = TRUE)` and keep working
  (rewrite unchanged). New helper `.gllvmTMB_warn_scalar_family_deprecated()`,
  mirroring the unique-family one; keyed in `.gllvmTMB_deprecation_seen`,
  silenced by `options(gllvmTMB.quiet_grammar_notes = TRUE)`.
- **Docs reframed to three modes:** Design 79 §5 (new §5.1 scalar-collapse
  table + routing), the capability widget (Scalar **column removed**, folded into
  the `indep` header as "+ scalar via `common = TRUE`"; redeployed to the same
  artifact URL), `api-keyword-grid.Rmd` (scalar keywords marked soft-deprecated;
  source syntax blocks lead with `*_indep(common = TRUE)`), and NEWS (New +
  Changed + Deprecated bullets).

## Checks run

- **Desugar byte-identity:** all four `*_indep(common=TRUE)` produce a
  `deparse`-identical engine call to the matching `*_scalar()` (silenced). `none`
  `indep(common=TRUE)` ≡ `scalar()`. `common=FALSE` path unchanged (still the
  per-trait `.indep` engine).
- **Deprecation UX:** all five `*_scalar()` keywords warn once
  ("soft-deprecated … 0.5.0"); the canonical `*_indep(common=TRUE)` spelling is
  silent. Augmented `common=TRUE` errors with "intercept-only".
- **New test file** `tests/testthat/test-scalar-family-collapse.R` — **19 pass /
  0 fail**, incl. a real-fit `logLik` equivalence `indep(common=TRUE)` == `scalar()`
  to 1e-8.
- **Regression sweep** (grammar/keyword/desugar files):
  `test-canonical-keywords` 116/0, `test-unique-family-deprecation` 23/0,
  `test-kernel-equivalence` 38/0, `test-formula-grammar-smoke` 28/0,
  `test-phylo/spatial-mode-dispatch`, `test-kernel-recovery` — no failures.
- **Full non-heavy `devtools::test()`:** **4519 pass / 0 fail / 951 skip**
  (heavy recovery), 1 warning. **Correction:** that summary command summed only
  the `failed` column, not `error`; a later `--as-cran` run surfaced **1 errored
  test** it had hidden — `test-predictive-diagnostics.R:496`, a stale rootogram
  regexp from sibling commit `4dfd2e2b` (unrelated to the scalar-collapse; the
  guard message gained "NB1" and the test was not updated). Fixed separately.
  The scalar-collapse surfaces are clean: every `*_scalar()`-calling test file is
  `WARN=0`/`ERROR=0` run individually, and `test-scalar-family-collapse.R` is
  19 pass / 0 fail / 0 error.
- **`devtools::document()`** — clean; `common` documented on the four indep Rd
  pages (`man/phylo_indep.Rd`, `man/spatial_indep.Rd`, `man/animal_indep.Rd`,
  `man/kernel_latent.Rd`). No spurious NAMESPACE churn (markers, not new exports).

Not run this arc: full `R CMD check --as-cran` (release gate, Shinichi's) and the
heavy recovery tests (`GLLVMTMB_HEAVY_TESTS=1`) — byte-identical routing makes a
fresh heavy recovery run redundant for the scalar sub-case.

## Working-tree classification

To be committed this arc: `R/brms-sugar.R`, `R/animal-keyword.R`,
`R/kernel-keywords.R`, `man/{phylo_indep,spatial_indep,animal_indep,kernel_latent}.Rd`,
`NEWS.md`, `docs/design/79-covariance-mode-taxonomy.md`,
`docs/dev-log/capability-surface.html`, `vignettes/articles/api-keyword-grid.Rmd`,
`tests/testthat/test-scalar-family-collapse.R`, this report.
Pre-existing held files untouched (`.Rbuildignore`, `.github/workflows/pkgdown.yaml`,
`CONTRIBUTING.md`, `ROADMAP.md` — **CARRIED-OVER**, Shinichi's disposition).

## Follow-up (precise next steps)

1. **Spatial `indep(1+x)` block-diagonal** (Design 79 §7.2, step 2) — re-flip the
   `R/brms-sugar.R` parser TODO, migrate the two spatial slope test files to the
   per-trait contract, verify with INLA (CI / a machine with INLA).
2. **`||` uncorrelated syntax + `dep(1+x||g)`** — the remaining Axis-2 build; `||`
   is not free two-term sugar (parser refuses slope-only terms).
3. **Shared-variance random slope** (former `scalar(1+x|g)`) — currently errors
   under `common=TRUE`; route to the `*_unique` augmented engine when built.
4. **Full gate:** `--as-cran` + full `devtools::test()` on the final tree.
5. Merge / `v0.5.0` tag / CRAN — Shinichi. Draft the drmTMB `|`/`||` coordination
   issue.
