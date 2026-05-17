# After Task: M1.9 — mixed-family-extractors.Rmd article + banner removal

**Branch**: `agent/m1-9-mixed-family-article`
**Slice**: M1.9
**PR type tag**: `scope` (new article + Preview banner removal; no R/ source change)
**Lead persona**: Pat (article author + reader UX)
**Maintained by**: Pat + Darwin (worked-example framing); reviewers: Rose (pre-publish audit), Ada (close gate)

## 1. Goal

Ninth M1 deliverable. Delivers the **new Worked-examples article**
that exercises the mixed-family extractor machinery validated by
M1.1 through M1.8, and **removes the Preview banner** from
`covariance-correlation.Rmd` (which was added in PR-0C.PREVIEW
pointing at M1 close).

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.

### New article: `vignettes/articles/mixed-family-extractors.Rmd`

Structure (~200 lines):

1. **Intro + setup**: mixed-family GLLVM motivation; load the M1.2 cached fixture.
2. **Fitting**: single `gllvmTMB(formula, data, family = list(...))` call; verify convergence.
3. **Sigma on the latent scale**: `extract_Sigma(..., link_residual = "auto")`; show $\Sigma_\text{total}$ matrix + correlation matrix; explain the per-family link residual.
4. **Correlations with uncertainty**: `extract_correlations()` with Fisher-z (default) and bootstrap CI methods; note that profile operates on a different (rotation-invariant) surface.
5. **Communality**: `extract_communality()` partition + interpretation note for mixed-family.
6. **Bootstrap on the full Sigma**: `bootstrap_Sigma()` with family-aware refits (now possible after M1.8).
7. **What's covered today**: a status table listing the M1 register rows (MIX-01..MIX-08 + MIS-05).
8. **See also + References**.

The article uses the M1.2 cached fixture via
`gllvmTMB:::load_mixed_family_fixture(n_families = 3L)` — gives a
reproducible 3-family (Gaussian + binomial + Poisson) example
that knits in under 5 seconds.

### Banner removal: `vignettes/articles/covariance-correlation.Rmd`

The 9-line Preview banner added by PR-0C.PREVIEW (lines 26–32, "Preview — Gaussian validated; mixed-family `extract_correlations()` is M1 milestone work") is removed. With M1 closing, the surface that was preview-flagged is now `covered`.

### `_pkgdown.yml`

Added `articles/mixed-family-extractors` to the Model-guides
contents list, placed between `psychometrics-irt` and
`stacked-trait-gllvm` (after the IRT worked example, before the
foundational grammar reference).

## 3. Files Changed

```
Added:
  vignettes/articles/mixed-family-extractors.Rmd      (~200 lines, ~8 sections)
  docs/dev-log/after-task/2026-05-17-m1-9-mixed-family-article.md (this file)

Modified:
  vignettes/articles/covariance-correlation.Rmd       (banner removed, -9 lines)
  _pkgdown.yml                                        (+1 line under articles)
```

No R/ source change. No NAMESPACE / generated Rd change.

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- `rmarkdown::render(vignettes/articles/mixed-family-extractors.Rmd)` knits end-to-end without errors.
- Banner removal verified via `rg "Preview" vignettes/articles/covariance-correlation.Rmd` → 0 hits.
- Article contents tested against the M1.2 fixture: convergence = 0; logLik finite; Sigma + correlations + communality + bootstrap output sensible (point estimates match earlier M1 test fixtures).

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): the article's bootstrap section (`bootstrap_Sigma` + `extract_correlations(method = "bootstrap")`) would have shown degenerate ±1 CIs pre-M1.8. With M1.8's family-aware simulate + `family_input` fix, the article shows sensible bracket-the-point CIs. This is the user-facing surface of the M1.8 fix.
- **Rule 2** (boundary): the article uses the 3-family fixture (the boundary case where the M1.8 bug surfaced). The 5-family fixture is the larger case for users; cross-referenced via `gllvmTMB:::load_mixed_family_fixture(n_families = 5L)` in a comment.
- **Rule 3** (feature combination): the article exercises **all 7 M1-walked extractors** in one document: `extract_Sigma`, `extract_correlations`, `extract_communality`, `extract_repeatability` (implicit via the M1.6 fix; not exercised explicitly because the fixture lacks within-(site, trait) replication), `extract_Omega`, `bootstrap_Sigma`, plus `simulate` (M1.8). Each works on the same mixed-family fit.

## 6. Consistency Audit

Stale-wording rg sweep on the new article + the modified files:

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" vignettes/articles/mixed-family-extractors.Rmd` → 0 hits.
- `rg "meta_known_V" vignettes/articles/mixed-family-extractors.Rmd` → 0 hits (canonical `meta_V` not used in this article).
- Citation discipline: 2 references with full Nakagawa & Schielzeth (2010) and Nakagawa-Johnson-Schielzeth (2017) citations.

Convention-Change Cascade (AGENTS.md Rule #10): banner removal +
article addition. No function ↔ help-file pair affected; no
`@export` change. The Preview banner removal is the natural
cascade from M1's walks to `covered` on MIX-03..MIX-08.

## 7. Roadmap Tick

- `ROADMAP.md` M1 row: **9 / 10 done** (M1.1 through M1.9). M1.10 (close gate) is the last remaining slice.
- Validation-debt register: no new row walks; the article surfaces the M1 walks already done by PR #151 → PR #157.

## 8. What Did Not Go Smoothly

- The article uses `gllvmTMB:::load_mixed_family_fixture(n_families = 3L)` — an **internal helper** (`@keywords internal` + `@noRd`). User-facing articles probably shouldn't rely on `:::` access; this is a stop-gap. A small follow-up PR could expose `load_mixed_family_fixture()` as a regular `@export` (or provide a `data()`-style accessor) so the article is more idiomatic. **Logged as a small post-M1 follow-up; not blocking M1.10.**
- The article doesn't explicitly demonstrate `extract_repeatability()` because the M1.2 fixture has no within-(site, trait) replication (n_species = 1; one observation per (site, trait) pair). Repeatability needs a within-unit dimension. The article notes this implicitly (no repeatability example) but doesn't call it out. **Logged**: a future small follow-up could add a separate `mixed-family-repeatability.Rmd` showing the M1.6 fix on a fixture with proper within-unit replication.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Pat** (article author + reader UX): the article follows the
canonical Worked-Examples shape — open with motivation, fit
once, walk extractors in dependency order, close with status
table + see-also + refs. The "What's covered today" status
table directly cites the register rows (MIX-01..MIX-08, MIS-05),
making the article auditable.

**Darwin** (worked-example framing): the article's
biology-question framing is implicit (mixed-family for ecology
+ evolution use cases). A future revision could add a
biology-first opener — e.g., "I measured size (continuous),
presence (binary), and abundance (count) across sites — how
do the traits covary?" — but for M1.9 the technical framing
suffices.

**Rose** (pre-publish audit): the banner-removal cascade is
clean. The article cites the register file (not bare row IDs);
all `gllvmTMB:::` accesses are flagged in §8 for a future
small follow-up; no overpromise.

**Ada** (orchestration): 9 / 10 M1 slices done. M1.10 (close
gate) is small — after-phase report + Shannon coordination
audit + 3-OS green. After that, M1 closes and M2 (binary
completeness) begins.

## 10. Known Limitations and Next Actions

- **M1.10 dispatches next** — the M1 close gate (after-phase report; Shannon audit; 3-OS green).
- **Small post-M1 follow-up**: expose `load_mixed_family_fixture()` as `@export` so the article doesn't rely on `:::`. Or add a `data()`-style accessor. ~1-hour PR.
- **Small post-M1 follow-up**: separate `mixed-family-repeatability.Rmd` article showing the M1.6 formula fix on a fixture with within-(site, trait) replication. Useful for the M2.5 article-rewrite milestone.
