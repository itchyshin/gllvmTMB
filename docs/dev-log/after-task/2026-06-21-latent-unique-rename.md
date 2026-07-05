# After Task: rename `latent(residual=)` → `latent(unique=)` (PR A)

PR: [#518](https://github.com/itchyshin/gllvmTMB/pull/518) ·
branch `claude/latent-unique-rename-20260621` (off `origin/main` 024a48b) ·
author Claude (Ada).

## 1. Goal

PR A of the `latent_*`-only migration (handover
`docs/dev-log/claude-handover-2026-06-21-latent-unique.md`). Rename the ordinary
`latent(..., residual = TRUE/FALSE)` argument — shipped one day earlier in 0.2.0
(#505) — to `latent(..., unique = TRUE/FALSE)`, because `unique` matches
`extract_Sigma(part = "unique")` and the `unique()` keyword grid, and "residual"
misleads above the lowest grouping level. Keep `residual =` working as a
soft-deprecated alias so freshly-written code does not break.

## 2. Implemented

### Mathematical Contract

No change to any model equation, likelihood, parameter transform, family, or TMB
code. This is an R-side **argument + internal-marker rename** with identical
numerics. The semantics the argument selects are unchanged:

- `unique = TRUE` (default) → `Sigma_level = Lambda Lambda^T + Psi` (the diagonal
  trait-specific `Psi` companion is auto-included at this grouping level);
- `unique = FALSE` → `Lambda Lambda^T` only (rank-deficient, rotation-invariant).

What this is **not**: not a change to which families/levels estimate `Psi`, not a
change to the dedup or per-family gates' behaviour, not a phylo/spatial/animal/
kernel change (those `*_latent()` keep their paired `*_unique()` companion — that
is PR B onward).

### Behaviour

- `latent()` formal `residual` → `unique` (`R/brms-sugar.R:492`).
- Parser fold block reads `unique` as canonical and `residual` as a
  soft-deprecated alias routed through a new one-shot warning
  (`.gllvmTMB_warn_latent_residual_alias`); supplying **both** is an error.
- Internal companion marker `.auto_residual` → `.auto_unique` at all 8 code sites
  (`R/brms-sugar.R` emit; `R/fit-multi.R` dedup + per-family gate, ×6; the
  `auto_residual_off_family` local → `auto_unique_off_family`; `R/julia-bridge.R`).
- The bare-`latent()` Psi-default fire-on-use notice now points at
  `latent(..., unique = FALSE)`.

## 3. Files Changed

**Engine / parser (`R/`)**: `brms-sugar.R` (formal, parser block, new alias
helper, Psi-default message), `fit-multi.R` (marker + `auto_unique_off_family`),
`julia-bridge.R` (marker + comment).

**Extractor roxygen + cli messages (`R/`)**: `extractors.R`, `extract-sigma.R`,
`extract-omega.R`, `communality-ci.R`, `profile-derived.R`,
`profile-derived-curves.R`, `unique-keyword.R`.

**Generated docs (`man/`, via `devtools::document()`)**: `latent.Rd`,
`extract_Sigma.Rd`, `extract_communality.Rd`, `extract_ICC_site.Rd`,
`diag_re.Rd`. NAMESPACE unchanged (the alias helper is internal).

**Articles (`vignettes/articles/`)**: `covariance-correlation.Rmd`, `pitfalls.Rmd`,
`morphometrics.Rmd`, `gllvm-vocabulary.Rmd`, `choose-your-model.Rmd`,
`api-keyword-grid.Rmd`.

**Root / contract / status**: `README.md`, `NEWS.md` (new dated entry),
`AGENTS.md` (keyword-grid notes ×2), `CLAUDE.md` (grammar note),
`docs/design/01-formula-grammar.md` (canonical grammar contract),
`data-raw/examples/make-covariance-edge-cases-example.R`.

**Tests (`tests/testthat/`)**: new `test-latent-unique-rename.R`; updated
`test-unique-family-deprecation.R` (marker + opt-out + titles), and
`test-canonical-keywords.R`, `test-extract-sigma.R`, `test-family-gamma.R`,
`test-gllvmTMB-diagnose.R`, `test-joint-sdm-binary-long-wide.R`,
`test-lme4-style-weights.R`, `test-stage2-rr-diag.R` (incidental `residual=` →
`unique=` in fits).

**This report** + a `check-log.md` entry.

## 3a. Decisions and Rejected Alternatives

> **Decision**: argument name = `unique` (not `specific`).
> **Rationale**: matches `extract_Sigma(part = "unique")` and the `unique()`
> keyword; maintainer-confirmed; no extractor rename ⇒ minimal churn.
> **Rejected alternative**: `specific` (cleaner FA term) — would force a parallel
> `part = "unique"` → `"specific"` rename across extractors/tests/docs.
> **Confidence**: high (maintainer decision).

> **Decision**: keep `residual =` as a one-shot soft-deprecated alias.
> **Rationale**: matches the repo's lifecycle convention (`unique()`,
> `meta_known_V` kept as aliases); safe for any code already using the day-old arg.
> **Rejected alternative**: hard-rename (drop `residual=`) — cleaner but breaks
> recently-written code with an error rather than a warning.
> **Confidence**: high (maintainer decision).

> **Decision**: defer `docs/design/2026-06-21-source-specific-latent-psi-fold.md`
> (Stage-A fold spec) to PR B.
> **Rationale**: it is PR B's working spec for the source-specific folds; PR B
> implements them with `unique=`/`.auto_unique` and reconciles the doc there.
> **Rejected alternative**: edit it in PR A — risks confusing a forward-design doc
> that PR B rewrites anyway.
> **Confidence**: medium — recorded in §10 so the staleness is not silent.

## 4. Checks Run

- `devtools::document(quiet = TRUE)` → clean; 5 `man/*.Rd` regenerated; NAMESPACE
  unchanged.
- `devtools::check(document = FALSE, args = "--no-manual", error_on = "never")`
  → `Status: 1 ERROR, 1 WARNING`, `0 NOTES`. Fast suite
  `[ FAIL 1 | WARN 13 | SKIP 745 | PASS 3384 ]`.
  - **ERROR** `test-block-V.R:117` — `could not find function "equalto"`. Proven
    environmental, not branch: `"equalto" %in% getNamespaceExports("glmmTMB")` →
    `FALSE` (glmmTMB 1.1.11 built vs TMB 1.9.17; env has TMB 1.9.21). Fails
    identically on `origin/main`; my diff touches no `meta_V` / `block_V` /
    `equalto` path. Documented in the handover as the known env-only FAIL.
  - **WARNING** — install: `R_ext/Boolean.h:62:36: warning: unknown warning group
    '-Wfixed-enum-extension'` (Apple clang 21 toolchain noise in R's own header;
    documented in memory). Not from package code.
  - All touched surfaces passed: examples OK, `--run-donttest` OK, vignette
    re-build OK, **"checking for code/documentation mismatches ... OK"**, Rd checks
    OK.
- Targeted heavy: `Sys.setenv(GLLVMTMB_HEAVY_TESTS="1", NOT_CRAN="true")` +
  `test_dir(filter = "unique-family-deprecation|latent-unique-rename|extract-sigma|keyword-grid")`
  → all green: `extract-sigma-augmented-unique`, `extract-sigma-spde-base-slope`,
  `extract-sigma-table`, `extract-sigma`, `keyword-grid`, `latent-unique-rename`,
  `m1-3-extract-sigma-mixed-family`, `unique-family-deprecation`. This exercises
  the `.auto_unique` dedup byte-identity and per-family/mixed-family `Sigma`
  extraction.
- CI on #518: `recovery` + `ubuntu-latest (release)` pending at closeout (fresh
  Linux installs glmmTMB against current TMB, so the local env-only `equalto`
  failure is expected to be absent there).

## 5. Tests of the Tests

- `test-latent-unique-rename.R` (new), **failure-before-fix**: all four cases were
  watched RED on `origin/main` before implementing —
  - `unique = FALSE` → loadings-only (`"rr"` only): RED because `unique` was
    ignored and `residual` defaulted TRUE → `c("rr","diag")`;
  - `unique = TRUE` → companion marked `.auto_unique`: RED because the marker was
    `.auto_residual`;
  - `residual =` alias warns + still works: RED because `residual=FALSE` fired no
    warning;
  - both `unique=` and `residual=` → error: RED because no conflict check existed.
  The alias + conflict cases are also **boundary / negative** tests (a guard's
  rejection paired with the acceptance path).
- Updated `test-unique-family-deprecation.R`: the opt-out assertion now uses
  `unique = FALSE` (the no-warning canonical path) because `residual = FALSE`
  correctly warns post-rename; the `.auto_unique` marker assertion would have
  caught any missed consumer of the renamed marker.

## 6. Consistency Audit (verbatim patterns + verdicts)

- `rg -c "\.auto_residual" R src man` → exit 1 (none). **Verdict**: marker fully
  renamed in all code/generated docs.
- `rg -c "\.auto_unique" R` → `fit-multi.R:6`, `julia-bridge.R:1`,
  `brms-sugar.R:1` (= 8 sites). **Verdict**: one emitter + seven consumers, all on
  the new name.
- `rg -n "residual\s*=\s*(TRUE|FALSE)" R vignettes README.md NEWS.md docs/design man`
  → only `NEWS.md:8` (the rename entry naming the old arg — intentional) and
  `docs/design/2026-06-21-source-specific-latent-psi-fold.md` (Stage-A spec,
  deferred to PR B — see §10). **Verdict**: live API/article/contract surface fully
  migrated.
- `rg -n "function\(formula, d = 1, unique = TRUE" R/brms-sugar.R` +
  `rg -n "unique = TRUE" man/latent.Rd` → formal and rendered usage agree.
  **Verdict**: function ↔ help-file binding consistent.
- `rg -n "\bS_B\b|\bS_W\b" R` → exit 1 (none). **Verdict**: no legacy S/U notation
  regression (canonical `psi`/`Psi`).

## Rendered-Rd Spot-Check

`man/latent.Rd`: `\usage` = `latent(formula, d = 1, unique = TRUE, common = FALSE)`;
`\item{unique}{...}` present; `Only applies when \code{unique = TRUE}`. No
`\item{residual}` (alias intentionally not advertised in usage; documented in the
`unique` param prose). No garbage `\keyword{}` tokens.

## Convention-Change Cascade (AGENTS.md Rule 10)

Required targets, file-by-file verdict:

1. **Function ↔ help binding**: `latent()` roxygen + `man/latent.Rd` regenerated ✓.
2. **Other `R/` @examples / messages using the convention**: 7 extractor files
   migrated ✓.
3. **Vignette / article chunks**: 6 articles migrated ✓.
4. **Canonical design/root examples**: `00-vision.md` (no `residual=` — N/A),
   `01-formula-grammar.md` ✓, `AGENTS.md` grid ✓, `README.md` Tiny example ✓,
   `CLAUDE.md` ✓, `NEWS.md` entry ✓.
5. **Validation-debt register**: no row references the arg/marker — N/A.

Deferred (recorded, not silent): `docs/design/2026-06-21-source-specific-latent-psi-fold.md`
(Stage-A spec; PR B).

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row chip/progress bar changed (this is a within-grammar
rename ahead of the source-fold roadmap slices).

## 8. What Did Not Go Smoothly

- The parser fold block uses mixed tab+space indentation; the Edit tool's exact
  match was impractical for the 50-line block, so it was rewritten programmatically
  with indentation derived from the file (verified via `cat -te`).
- A bulk `perl` pass on a zsh-quoted variable did not word-split (zsh), and `rg`
  look-behind needs `--pcre2`; both caught immediately (no files were modified on
  the failed pass) and redone with a literal `for`-loop.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Boole (R API / grammar)**: the chosen name `unique` collides visually with the
  `unique()` keyword in one legacy doc string (`latent(..., unique = FALSE) +
  unique(...)`); kept accurate but worth watching when PR B documents the source
  folds — prefer prose that disambiguates arg-vs-keyword.
- **Curie (testing)**: RED-first paid off — the `.auto_unique` assertion is exactly
  the tripwire that would catch a future missed marker consumer; the targeted heavy
  pass confirmed dedup byte-identity without running the full 9.5k-test suite.
- **Rose (consistency)**: the verbatim rg audit separated genuine lowest-level
  "residual" prose (probit implicit residual, Gaussian residual SD) from the arg
  token, so the rename did not over-reach into correct terminology.
- **Grace (CI/repro)**: the only local check failure is an env-only glmmTMB/TMB
  version mismatch; confirmed via `getNamespaceExports` rather than assumed, and CI
  on fresh Linux is the cross-check.

## 10. Known Limitations and Next Actions

- **`docs/design/2026-06-21-source-specific-latent-psi-fold.md` still uses
  `residual=` / `.auto_residual`.** Deliberately deferred to **PR B**, which
  implements the phylo (then spatial/animal/kernel) folds with `unique=` /
  `.auto_unique` and reconciles that spec. Until PR B, that doc describes a marker
  name the code no longer uses — flagged here so it is not mistaken for a live
  contract.
- **Local `test-block-V.R` ERROR is environmental** (glmmTMB built vs older TMB);
  reinstalling glmmTMB from source clears it. Not a branch issue; CI is the
  authority.
- **Next**: PR B — redo the phylo `Psi`-fold (was #516) with `unique=` and fix the
  equivalence cascade (`test-kernel-equivalence.R:203`, `test-canonical-keywords.R`,
  `test-animal-keyword.R`, `test-matrix-animal-nongaussian.R`) by setting the
  *compared* `phylo_latent(...)` to `unique = FALSE`. Run the **full**
  `devtools::check()` before pushing (the gap that produced the red #516).

## GitHub Issue Ledger

- Inspected: `gh issue list --state open` filtered for
  `latent|unique|psi|migration|residual|fold|grammar` → no matching open issue.
  The `latent_*`-only migration is tracked by the plan
  (`~/.claude/plans/memoized-snuggling-balloon.md`) and the handover, not a GitHub
  issue.
- Commented / closed / created: none. **No relevant open issue; no new issue
  created** — a within-grammar argument rename ahead of the source-fold slices.
- #516 (phylo fold, OPEN + red) is **not** touched by PR A; it remains the
  superseded draft that PR B replaces.
