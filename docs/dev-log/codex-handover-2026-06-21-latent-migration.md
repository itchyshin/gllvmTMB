# Codex-team handover — 2026-06-21 — `latent_*`-only migration

**From:** the Claude team (Ada, with Boole / Gauss / Noether / Curie / Grace / Rose
perspectives). **To:** the Codex team.
**The repository is authoritative.** Rehydrate from `git` / `gh` + this note + the
plan file, never from chat memory. Read in this order:

1. `AGENTS.md` (source of truth — you parse it natively) and `CLAUDE.md`.
2. **This note.**
3. `~/.claude/plans/memoized-snuggling-balloon.md` — the full staged migration plan.
4. `docs/design/2026-06-21-source-specific-latent-psi-fold.md` — Stage-A design.
5. `docs/design/01-formula-grammar.md` — the canonical grammar contract.

Today's two after-task reports are the detailed record of what shipped:
`docs/dev-log/after-task/2026-06-21-latent-unique-rename.md` (#518) and
`docs/dev-log/after-task/2026-06-21-phylo-latent-unique-fold.md` (#519).

---

## 0. TL;DR

`gllvmTMB` is moving to a **`latent_*`-only grammar**: ordinary `latent()` and each
source-specific `*_latent()` should carry their diagonal `Psi` companion by default,
so the paired `*_latent() + *_unique()` collapses to a single `*_latent()`, and the
`*_unique()` keywords can eventually be removed. The Claude team did the first two
slices today:

- **PR #518 — MERGED.** Renamed the `latent(residual = …)` argument →
  `latent(unique = …)` (with `residual =` kept as a soft-deprecated alias); renamed
  the internal companion marker `.auto_residual` → `.auto_unique` everywhere.
- **PR #519 — MERGED** (`origin/main` now `f200b62`). Folds `phylo_latent()`'s
  diagonal `Psi_phy` by default (`unique = TRUE`); superseded and closed **#516**.

**Your mandate:** carry the migration forward — the remaining Stage-A source folds
(`spatial_latent` → `animal_latent` → `kernel_latent`, then augmented
`phylo_latent(1 + x | sp)`), then Stage B hardening, C deprecation messaging, D
article reorg, and finally E removal. You own the **live R/TMB + Julia toolchain**
(real fits, full `R CMD check`, heavy recovery suites) — that is the Claude↔Codex
division of labour, and these slices need real fits to verify.

---

## 1. Project context (for a fresh team)

`gllvmTMB` fits multivariate **stacked-trait, long-format GLLVMs** with phylogenetic
and spatial extensions (Template Model Builder backend). One row per `(unit, trait)`.
Sister-package boundaries: single-response → `glmmTMB`; spatial single-response →
`sdmTMB`; up-to-bivariate distributional regression → `drmTMB`. See
`docs/design/04-sister-package-scope.md`.

The covariance grammar is the **4×5 keyword grid** (correlation × mode):
`scalar` / `unique` / `indep` / `dep` / `latent`, with `phylo_*`, `spatial_*`,
`animal_*` rows, plus the Design-65 generic `kernel_*` quartet. The decomposition at
each grouping level is `Sigma_level = Lambda Lambda^T + Psi`. The migration is about
folding `Psi` into the `*_latent()` keywords by default.

---

## 2. Current repository state

- **`origin/main` = `f200b62`** (after #518 and #519 merged).
- **Merged today:** #511–#515, #517 (loops/docs/design), **#518** (latent `unique=`
  rename), then **#519** (phylo_latent `unique=` fold).
- **#519 — MERGED.** `feat(grammar): fold phylo_latent() … (unique=)` landed on
  `main`; the **phylo slice of Stage A is complete**.
- **#516 — CLOSED** (superseded by #519). Old branch `claude/phylo-fold-20260621`,
  worktree `/private/tmp/gllvmtmb-phylofold` — safe to prune.
- **DO NOT TOUCH** the dirty `codex/r-bridge-grouped-dispersion` checkout (the main
  working directory). It predates all of today's merges. Always branch new work from
  fresh worktrees off `origin/main`.

---

## 3. Operating contract — hard guards (do not violate)

1. **Grammar / engine / likelihood / family / export merges to shared `main` need
   EXPLICIT per-item maintainer "yes merge."** #518 merged only after the maintainer
   said so. Every source-fold slice below is a grammar change ⇒ same gate. Docs /
   dev-log / after-task / design notes are self-mergeable when CI is green.
2. **★ Run the FULL `devtools::check()` locally BEFORE every push.** This is the
   lesson of #516: a phylo-only test subset was green, but the full check FAILED
   because the breakages lived in `test-kernel-equivalence.R` /
   `test-canonical-keywords.R` / `test-animal-keyword.R` /
   `test-matrix-animal-nongaussian.R` — OUTSIDE the phylo files. A scoped run lies.
3. **Never `git add -A`.** Stage by name (`git add -u` for tracked + new files
   explicitly).
4. **Do not revert Claude/human changes.** Stop for maintainer discussion before
   deletions, API/grammar/likelihood/family changes, or broad article rewrites.
5. **Never self-promote a validation-debt register row** (Design 35) — maintainer
   decision.
6. **One open PR at a time** where practical (the 2026-05-10 cancel-cascade lesson);
   keep PRs small and focused.
7. **Surface at every stopping point** (in chat / on the PR): open-PR links,
   after-task paths, and 🔴 **Needs you:** blockers. The maintainer does not browse
   PRs unprompted.
8. **Every meaningful change** appends to `docs/dev-log/check-log.md`; every completed
   slice leaves an after-task report (`docs/design/10-after-task-protocol.md`).
9. Commit trailer: your Codex identity (Claude used
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`).

### Heavy-test gate
Heavy recovery / equivalence tests sit behind `GLLVMTMB_HEAVY_TESTS=1`
(`tests/testthat/setup.R`). Reproduce locally with
`Sys.setenv(GLLVMTMB_HEAVY_TESTS="1", NOT_CRAN="true")`, then
`devtools::load_all(".")` + `testthat::test_dir("tests/testthat")` (or `test_file`).
`skip_on_cran()` needs `NOT_CRAN=true`.

### Environment caveat (do not chase this ghost)
Local `devtools::check()` reports **1 ERROR + 1 WARNING that are NOT branch issues**:
- ERROR `test-block-V.R:117` — `could not find function "equalto"`. The installed
  `glmmTMB` (1.1.11) was built against TMB 1.9.17 while the env has 1.9.21
  (`"equalto" %in% getNamespaceExports("glmmTMB")` → FALSE). **Reinstall glmmTMB from
  source** to clear it. Touches no migration code.
- WARNING — Apple-clang `R_ext/Boolean.h` `-Wfixed-enum-extension` header noise.

Both are identical on `origin/main` and absent on fresh-Linux CI. Treat any check
result as clean if these are the only two items and `0 NOTES`.

---

## 4. ★ Canonical Ψ model (internalise before touching any fold)

`Sigma_level = Lambda Lambda^T + Psi`. The diagonal companion
**Psi = specific (residual) part + distribution (overdispersion) part**:

- **Gaussian & Poisson** — overdispersion part = 0 ⇒ `Psi` is the specific term ⇒ the
  families where the companion is genuinely needed.
- **Other non-Gaussian** (NB1/NB2, Beta, Gamma, GP-1, lognormal, Tweedie, Student-t)
  — the family's own dispersion already carries the overdispersion ⇒ an explicit `Psi`
  at the **residual** level double-counts; but `Psi` IS identified and estimated at
  the **non-residual** levels (unit, cluster, cluster2, phylo). "non-Gaussian is the
  key."
- **Single-trial binary** — `Psi` is unidentified ⇒ auto-skip (the #509 fix).

Grammar consequence: `unique = TRUE` (default on `latent()` and now `phylo_latent()`)
carries `Psi`; `unique = FALSE` = loadings-only (rank-deficient, rotation-invariant).
`unique()` / `*_unique()` are soft-deprecated compatibility syntax. `residual =` is a
soft-deprecated alias of `latent(unique=)` **only** (it never existed on the
`*_latent()` keywords, so do not add it there).

---

## 5. The source-fold recipe (the core "how" — reuse #518/#519, do not reinvent)

Every `*_latent()` fold slice is the SAME shape. The phylo slice (#519) is the worked
reference; after it merges, `git show` its diff for the exact code.

**(a) Rewriter — `R/brms-sugar.R`.** Add a block right after the ordinary-`latent`
fold (search `if (identical(fn, "latent"))`; the phylo block is the next sibling
`if (identical(fn, "<source>_latent"))`):
- read `unique` (default `TRUE`), validate it is a literal logical scalar, drop it
  from the rewritten call;
- `unique = FALSE` → return the loadings-only rewrite (`*_rr` / `spde`) alone;
- else emit `<loadings-rr> + <companion>`, where the companion carries the source
  marker **and** `.auto_unique = TRUE`, sharing structure via
  `.pass_through_extras(e, c(<keep-args>))`;
- add `unique = TRUE` to the keyword's formal + a roxygen `@param unique`;
- **guard**: augmented `*_latent(1 + x | g)` is returned EARLIER (the `.latent_slope`
  block) — the fold must see only the intercept-only form.

| source | companion emitted by `*_latent(unique = TRUE)` |
|---|---|
| phylo (done, #519) | `phylo_rr(sp,…) + phylo_rr(sp, .phylo_unique=TRUE, .auto_unique=TRUE, [tree/vcv])` |
| spatial (next) | `spde(coords,…) + spde(coords, .spatial_unique=TRUE, .auto_unique=TRUE)` — **confirm the spde-unique marker name + engine slot first** |
| animal | `phylo_rr(id, vcv=A) + phylo_rr(id, .phylo_unique=TRUE, .auto_unique=TRUE, vcv=A)` (animal routes through the phylo engine with a pedigree→A) |
| kernel | `phylo_rr(unit, .kernel_name, .kernel_mode,…) + phylo_rr(unit, .phylo_unique=TRUE, .auto_unique=TRUE, .kernel_name, .kernel_mode)` |

**(b) Dedup — `R/fit-multi.R`** (beside `is_auto_phylo_psi`, ~line 345): add an
`is_auto_<source>_psi` predicate; an explicit `*_unique()` at the same grouping
supersedes the auto-companion (drop it) → byte-identical to the explicit pair, and
avoids the `>1 *_unique` abort; extend the `auto_unique_off_family` (ordinal/delta)
gate to drop the source companion too. (Spatial's companion is `kind == "spde"`, not
`phylo_rr`.)

**(c) Equivalence cascade — the #516 trap.** Flipping the default meaning of bare
`*_latent()` breaks every test asserting `bare *_latent ≡ <a non-folding form>`. Fix
by setting the COMPARED `*_latent(...)` to `unique = FALSE` (loadings-only ≡
loadings-only). For phylo these were `test-kernel-equivalence.R:159`,
`test-canonical-keywords.R:458`, `test-animal-keyword.R:182`,
`test-matrix-animal-nongaussian.R:319/407`. **Empirical loop:** implement → run the
candidate files under `GLLVMTMB_HEAVY_TESTS=1` → fix exactly what breaks → then the
FULL check.

**(d) Gates per slice (you run these for real):**
- **G1 byte-identity** — `*_latent(unique=TRUE)` ≡ `*_latent(unique=FALSE) +
  *_unique()` (`logLik` + `extract_Sigma` Δ < 1e-6) across the wired families.
- **G2 per-family + per-level recovery** of `Sigma_<src> = LL^T + Psi` (unit /
  cluster, + cluster2 where applicable) under `GLLVMTMB_HEAVY_TESTS=1`.
- **G3** `unique = FALSE` returns the loadings-only submodel.
- **G4** an explicit `*_unique()` still fits + warns (compat preserved until Stage E).

**(e) Per slice also:** roxygen `@param` + regenerated `man/*.Rd`; the
`01-formula-grammar.md` pairing-rule note; a NEWS entry; after-task + check-log;
RED-first tests; **the FULL check before push**.

---

## 6. Detailed plan (staged; verification-gated; removal LAST)

### Stage A — source-specific Ψ-folds (IN PROGRESS)
1. **phylo** — ✅ #519 (MERGED; #516 closed).
2. **spatial_latent** — **next.** SPDE/GMRF companion. **Before coding, confirm** the
   spatial diagonal slot is wired: grep `spde`, `spatial_unique`, `use_spde*`,
   `spatial_diag` in `R/fit-multi.R` and `src/gllvmTMB.cpp`. If the slot does not
   exist, raise it with the maintainer — do not invent engine structure silently.
   Gates G1–G4 with a mesh fixture.
3. **animal_latent** — routes through the phylo engine with a pedigree→A; companion is
   `phylo_rr(.phylo_unique, .auto_unique, vcv=A)`. Reuse the `animal_*` ↔ `phylo_*`
   byte-equivalence fixtures.
4. **kernel_latent** — Design-65 dense-kernel quartet; companion carries
   `.kernel_name` + `.kernel_mode`. Keep C1 phylo-equivalence < 1e-6.
5. **slice 1b** — augmented `phylo_latent(1 + x | sp)` fold (currently the
   intercept-only guard keeps explicit `phylo_unique` for augmented slopes).

### Stage B — hardening / docs (parallel; some deferred from #519)
- **B0 (deferred from #519):** bare-`phylo_latent` fire-on-use warning (mirror
  `.gllvmTMB_warn_latent_default_psi` in `R/brms-sugar.R`); the AGENTS.md + CLAUDE.md
  keyword-grid note (`phylo_latent + phylo_unique` is canonical → "or bare
  `phylo_latent()`, which now folds `Psi`"); the validation-debt register row.
- **B1:** unit-level `latent(d≥1) + Psi` split-recovery gates for Poisson / NB2 /
  Gamma / Beta / ordinal (today only Gaussian byte-identity + binary are deeply
  split-tested).
- **B2:** mixed ordinal/delta per-trait B-tier `Psi` skip (currently all-or-nothing).
- **B3:** document per-family + per-level `Psi` behaviour (roxygen + man + grammar
  contract).

### Stage C — deprecation messaging
Standalone `*_unique()` → `*_indep()` (NOT `latent()`); route every standalone
deprecation warning to `*_indep()`. Demote `unique()` to a deprecated-alias note in
the api-keyword-grid article (gated on B3).

### Stage D — article / navigation reorg (downstream)
7-section taxonomy; `lambda` public; ordinal-probit → response-families + delete;
`_pkgdown.yml` restructure. Most `unique()`→`indep()` article wording is already done
(#505/#508/#513).

### Stage E — removal of `*_unique()` (LAST)
Only after all four source folds + G1–G3 per source are green: flip soft-deprecation
to removal, source-by-source, each gated by its byte-identity + recovery evidence.

---

## 7. Team role map (Codex roster ↔ migration work)

The Codex `.codex/agents/*.toml` mirror the standing-review roles. For each fold
slice, dispatch bounded tasks:

- **Ada** — orchestrate the slice; enforce the after-task + full-check discipline;
  own the merge surface to the maintainer.
- **Boole** — the rewriter (`R/brms-sugar.R`): is the `unique=` parsing + the
  companion emission memorable and consistent with the phylo slice? Watch the
  arg/keyword name collision (`*_latent(unique=…)` vs the `*_unique()` keyword) for
  the Stage-D docs.
- **Gauss + Noether** — the engine + math: does the companion route to the correct
  diagonal slot; is the byte-identity (logLik + `extract_Sigma`) exact; no
  double-count, no lost `Psi`. Required on every fold (TMB-likelihood-adjacent).
- **Curie** — the tests: RED-first; G1–G4; the empirical equivalence-cascade loop;
  per-family recovery seeds (deterministic).
- **Grace** — CI / pkgdown / repro: the FULL local check before push; the
  glmmTMB/TMB env caveat; 3-OS only pre-release.
- **Rose** — cross-file consistency before the PR: the convention-change cascade
  (roxygen ↔ man, grammar contract, NEWS, AGENTS/CLAUDE grid), stale-wording scans.
- **Pat / Darwin** — when a slice touches user-facing prose/examples (Stage D), the
  applied-reader path and biological framing.

Keep dispatch bounded — launch a role for a specific question, not continuously.

---

## 8. Worktrees & resume

- **#519 (merged):** `/private/tmp/gllvmtmb-phylo-unique-fold` — prune.
- **#518 (merged):** `/private/tmp/gllvmtmb-latent-unique` — prune.
- **#516 (superseded):** `/private/tmp/gllvmtmb-phylofold` — prune after closing #516.
- **New work:** `git worktree add /private/tmp/gllvmtmb-<slice> origin/main -b
  codex/<slice>-<date>` (off the post-#519 `main`).

Rehydrate: `git fetch`; confirm `origin/main` + `gh pr list` / `gh pr view 519`; read
the newest `check-log.md` entry, this note, and the plan file.

---

## 9. First actions for the Codex team

1. `git fetch`. Confirm `origin/main` = `f200b62` (or later) and `gh pr list`.
2. #519 is merged and #516 is already closed — just prune the merged worktrees
   (`/private/tmp/gllvmtmb-phylo-unique-fold`, `-latent-unique`, `-phylofold`).
3. Start the **spatial_latent** slice — but FIRST confirm the spatial diagonal engine
   slot exists (§6.A.2). If not wired, raise with the maintainer before coding.
4. Follow the §5 recipe; RED-first tests; run G1–G4 for real under
   `GLLVMTMB_HEAVY_TESTS=1`; **run the FULL `devtools::check()` before pushing**; open
   one focused PR; surface it (grammar ⇒ maintainer-merge-gated).
5. After-task report + check-log per `docs/design/10-after-task-protocol.md`; assign
   the §7 review roles.

---

## 10. Pointers

- **Plan:** `~/.claude/plans/memoized-snuggling-balloon.md`.
- **Stage-A design:** `docs/design/2026-06-21-source-specific-latent-psi-fold.md`
  (read it as the algorithm; it still uses the pre-#518 `residual=`/`.auto_residual`
  spelling — emit `unique=`/`.auto_unique`).
- **Today's after-tasks:** `…/after-task/2026-06-21-latent-unique-rename.md` (#518),
  `…/after-task/2026-06-21-phylo-latent-unique-fold.md` (#519).
- **Grammar contract:** `docs/design/01-formula-grammar.md`. **Scope:**
  `docs/design/04-sister-package-scope.md`. **Family registry:**
  `docs/design/02-family-registry.md`. **Likelihoods:** `docs/design/03-likelihoods.md`.
- **Family-id map** (`R/fit-multi.R`): 0=gaussian, 1=binomial, 2=poisson, 4=Gamma,
  5=nbinom2, 7=Beta, 12/13=delta_*, 14=ordinal_probit, 15=nbinom1.
- **Key files:** `R/brms-sugar.R` (parser/rewriter), `R/fit-multi.R` (dedup, gates,
  engine wiring), `src/gllvmTMB.cpp` (TMB), `R/extract-sigma.R` (Σ assembly).
- **Validation command set:** `pkgdown::check_pkgdown()`,
  `devtools::test(filter=…)`, `devtools::document()`,
  `devtools::check(args="--no-manual")`, `git diff --check`.
