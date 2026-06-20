# unique→Psi cascade spec (de-risked execution map, 2026-06-20)

Output of a 4-agent read-only cascade audit (workflow `wf_4d6ea478-4d9`) over
`origin/main` (`05f700a`). Augments the execution plan
(`2026-06-20-psi-grammar-execution-plan.md`) with the **exact** rule-#10 scope and,
crucially, the decision-gates that make this NOT a mechanical find/replace.

## Scope (≈445 convention usages)

| Area | usages | files | notes |
|---|---|---|---|
| R roxygen `@examples` | 68 | 27 | the real edit surface (drives man/*.Rd) |
| vignettes/articles `.Rmd` | 238 | 30 | largest; several are pedagogical (see D5) |
| README + design (00-vision, 01-formula-grammar) + NEWS + AGENTS/CLAUDE | 66 | 6 | grammar contract + keyword grid |
| generated `man/*.Rd` | 73 | 45 | **auto-regenerated — never hand-edit**; fix roxygen + `document()` |

Usage categories (from the audit):
- **PAIRED-DROP**: explicit `latent(...) + unique(...)` on the same grouping →
  keep plain `latent(...)`, delete the `unique(...)` companion (Psi now default).
- **STANDALONE-INDEP**: a standalone `unique()`/`*_unique()` diagonal →
  `indep()`/`*_indep()`.
- **LATENT-OK**: standalone `latent()`/`*_latent()` → no change.
- **RISK**: do not edit mechanically — see decision-gates.

## ⛔ Decision-gates (must be resolved BEFORE the cascade) — 🔴 maintainer

- **D0 (sequencing, HARD):** No cascade edit is safe until the core
  `residual = TRUE` parser change is LIVE in the same build. Until then,
  `latent()` does NOT carry Psi, so dropping `unique()` companions would remove
  Psi; and after it lands, leaving both risks a double-count / redundancy abort.
  **Core change and cascade move together.**
- **D1 — source-specific `*_latent()` parity:** does `residual = TRUE` apply only
  to ordinary `latent()`, or also to `phylo_latent` / `spatial_latent` /
  `kernel_latent`? The engine change is documented for ordinary `latent()` only.
  Until decided, do NOT convert `phylo_latent`/`spatial_latent`/`kernel_latent`
  examples.
- **D2 — augmented slope-block Psi:** `latent(1 + x | unit, d = K) + unique(1 + x | unit)`
  is an *implemented distinct object* (augmented `Psi_B,aug`,
  `extract_Sigma(level = "unit_slope", part = "unique")`, RE-12 tests). It is NOT
  established that `residual = TRUE` auto-supplies the augmented slope-block Psi.
  Confirm parity before collapsing these pairs; otherwise keep the paired form.
- **D3 — `kernel_unique()` stays compat:** it is the C1 phylo-equivalence gate
  (`kernel_latent + kernel_unique` ≡ `phylo_latent + phylo_unique` to <1e-6;
  Paper-2 "paired kernel_unique Psi deferred"). The latent-auto-Psi change is not
  documented for kernel_* tiers — **leave kernel_unique() as compatibility syntax.**
- **D4 — `phylo_unique()` stays canonical:** per CLAUDE.md, standalone
  `phylo_unique` carries intra-phylogeny diagonal structure (canonical). Whether
  to lead phylo examples with `phylo_indep` vs keep `phylo_unique` is a teaching
  choice — **not** a mechanical standalone→indep swap.
- **D5 — pedagogical articles need rewrites, not swaps:** these teach the OLD
  "`latent()` alone = no Psi" default and BREAK under the new default unless their
  demo fits become `latent(..., residual = FALSE)` (and titles/prose reframe):
  - `covariance-correlation.Rmd` — title *"…when you need `unique()`"*; the whole
    A-vs-B inflation lesson collapses. Highest-risk file.
  - `pitfalls.Rmd` — the "latent()-only inflates the diagonal" pitfall.
  - `morphometrics.Rmd` — the `dep == latent(d = T) standalone` identity.
  - `fit-diagnostics.Rmd` — the explicit "not the full latent()+unique()" example.

## Recommended execution sequence (one dedicated pass)

1. Resolve D1–D5 with the maintainer (and Boole/Noether for D1/D2 engine parity).
2. Implement the core parser/engine change (`brms-sugar.R` latent() auto-Psi +
   `residual`/`common`; `fit-multi.R` `.auto_residual`/`.auto_psi`/`drop_psi`;
   `extract-sigma.R` `part = "psi"`), re-derived against current main; normalise
   `brms-sugar.R` to space indentation. Verify: Gaussian recovery (latent() auto-Psi
   == explicit latent+unique), wide/long byte-identity, RE-12 augmented-Psi parity.
3. Apply the **safe-mechanical** cascade (PAIRED-DROP + STANDALONE-INDEP for
   ordinary tiers only), regenerate `man/*.Rd` via `document()`.
4. Hand-rewrite the D5 pedagogical articles (residual = FALSE + reframed prose).
5. Update 00-vision canonical example, README Tiny example, the 4×5 keyword grid
   (AGENTS/CLAUDE), NEWS (scope-boundary statement), 01-formula-grammar contract,
   and the validation-debt register rows.
6. Verify: `document()` + `test()` + `pkgdown::build_articles(lazy = FALSE)` +
   `check_pkgdown()`; Boole (grammar) + Noether (engine) + Rose (cascade) +
   Pat (one article as applied user) sign-off.

## Honest status

The audit confirms the migration is a **decision-gated dedicated pass**, not an
inline edit. The full per-usage inventory (every file:line + current + recommended
form) is in the workflow result (`wf_4d6ea478-4d9`). The safe-mechanical subset is
large but cannot start until D0 (core change) + D1/D2 (parity) are settled.
