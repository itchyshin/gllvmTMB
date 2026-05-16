---
name: rose-pre-publish-audit
description: Run Rose's narrow pre-publish consistency gate for gllvmTMB README, vignettes, pkgdown navigation, NEWS, roxygen, or Rd changes. Cross-checks claims against the validation-debt register, the README stable-core feature matrix, and the AGENTS.md scope-boundary rule. Phase 0A 2026-05-16 ratified.
---

# Rose Pre-Publish Audit

Use this skill before merging any `gllvmTMB` PR that touches public
prose or reference navigation:

- `README.md`
- `vignettes/**/*.Rmd`
- `_pkgdown.yml`
- `NEWS.md`
- roxygen blocks for exported functions in `R/*.R`
- generated `man/*.Rd`

This is a read-only consistency gate. Do not rewrite prose broadly and
do not implement features. Return pass, warn, or fail with concrete
file references.

## Checks

1. Method-list claims match the source `method = c(...)` or
   `match.arg()` choices. Pay special attention to `fisher-z`,
   `profile`, `wald`, and `bootstrap`.
2. Default-value claims match function formals or source defaults.
3. Function names mentioned in prose or references are exported or
   explicitly marked as internal.
4. The 3 × 5 keyword grid matches the current covariance keyword
   surface (per `docs/design/01-formula-grammar.md`).
5. Argument-name claims match current function signatures, especially
   `unit`, `unit_obs`, `trait`, `cluster`, and `level`. **Long-format
   `gllvmTMB()` calls MUST pass `trait = "..."` explicitly** (Option A
   uniform-naming rule). Wide-format calls (`traits(...)` LHS) do NOT
   take a `trait =` argument.
6. Family lists match exported response-family constructors. **Delta /
   hurdle families in mixed-family fits are `blocked` per
   validation-debt register MIX-10** (latent-scale correlation
   undefined); user-facing prose must not describe this as a current
   capability.
7. **Stale terminology is absent** from new or touched public prose:
   - `trio` framing (obsolete);
   - obsolete keyword aliases (`phylo(`, `gr(`, `meta(`, `block_V(`,
     `phylo_rr(`) presented as primary syntax in user-facing prose;
   - `profile-likelihood default` for correlations
     (`extract_correlations(method = "profile")` is opt-in);
   - unsupported features described as implemented;
   - `diag(U)` / `U_phy` / `U_non` / `\bf S` / `S_B` / `S_W` as math
     notation. **Per `decisions.md` 2026-05-14 notation reversal, the
     canonical math uses `Ψ` / `ψ` (psi)**; the "two-U" / "two-psi"
     task labels remain on function names (`extract_two_psi_via_PIC`)
     per PR #40 logic but never as math notation;
   - **`gllvmTMB_wide(Y, ...)` described as a current API or
     "soft-deprecated"** — it is **REMOVED in 0.2.0** per
     validation-debt register row FG-16; new examples use the
     `traits(...)` LHS;
   - **`meta_known_V` used as the primary keyword name** —
     canonical is `meta_V(value, V = V)` since 0.2.0;
     `meta_known_V` is a deprecated alias.
8. **Validation-debt register cross-check (Phase 0A 2026-05-16).**
   Every "stable" / "covered" claim in user-facing prose maps to a
   row in `docs/design/35-validation-debt-register.md` with status
   `covered`. Every "experimental" claim maps to `partial`. Every
   "planned" / "removed" / "deferred" claim maps to `blocked`. If a
   claim cannot be traced to a register row, it is `FAIL`.
9. **README stable-core feature matrix cross-check.** The "Status of
   supported features" matrix in `README.md` must be consistent with
   the validation-debt register. Specifically:
   - every row labelled `stable` is backed by a register `covered`
     row for the primary advertised regime;
   - every row labelled `experimental` is backed by a register
     `partial` row;
   - every row labelled `planned` is backed by a register `blocked`
     row.
10. **AGENTS.md scope-boundary template applied.** Every new/edited
    NEWS entry, vignette, article, README section, and roxygen
    `@description` advertising a capability must explicitly state
    what is IN, what is PARTIAL, what is PLANNED / REJECTED — with
    register row-ID cross-references (`FG-NN`, `FAM-NN`, `MIX-NN`,
    etc.).
11. **Convention-Change Cascade verification (AGENTS.md Rule #10).**
    If the PR changes any argument signature, keyword default, or
    syntax requirement, verify the cascade was performed: the
    function's roxygen + `man/*.Rd` regenerated, every other
    `@examples` block updated, every vignette / article code chunk
    updated, the canonical examples in `00-vision.md` /
    `AGENTS.md` / `README.md` / `NEWS.md` updated, and the
    validation-debt register row(s) updated. The after-task report
    must enumerate every file touched.

## Suggested Commands

```sh
# Method-list / default-value cross-check
rg -n "method *=|default|fisher-z|profile|wald|bootstrap" R README.md vignettes man

# Keyword surface + naming conventions
rg -n "latent|unique|indep|dep|phylo_|spatial_|meta_V|meta_known_V|trio" README.md vignettes docs R man

# Argument-name surface
rg -n "unit_obs|unit =|trait =|cluster =|level =" README.md vignettes R man

# Long-format gllvmTMB() must have trait = "..." (Option A)
rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design

# Stale notation (canonical: psi / Psi)
rg "\\bS_B\\b|\\bS_W\\b|\\\\bf S" .

# REMOVED / RENAMED APIs in user-facing prose
rg "gllvmTMB_wide" README.md NEWS.md docs vignettes
rg "meta_known_V" README.md NEWS.md docs vignettes

# In-prep citations (engine-specific OK; foundational must cite
# published literature)
rg "in prep|in preparation" docs vignettes
```

## Output

- `PASS`: no inconsistencies found.
- `WARN`: wording is correct but could mislead a named reader.
- `FAIL`: public prose, generated docs, pkgdown navigation, or source
  defaults disagree; OR an advertised claim has no register
  row-ID backing; OR the convention-cascade was incomplete.

For every warning or failure, cite the file and the smallest line span
needed to fix it.
