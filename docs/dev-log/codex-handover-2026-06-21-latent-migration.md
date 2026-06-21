# Codex handover — 2026-06-21 — `latent_*`-only migration (Stage A continues)

**From:** Claude (Ada). **To:** the next **Codex** session.
**The repo is authoritative — rehydrate from `git`/`gh` + this note + the plan file,
not from chat memory.** Read `AGENTS.md` first (you parse it natively); then this
note, then `~/.claude/plans/memoized-snuggling-balloon.md` (the staged plan), then
`docs/design/2026-06-21-source-specific-latent-psi-fold.md` (the Stage-A design).

---

## 0. TL;DR

The `latent_*`-only migration advanced two slices today, both as Claude PRs:
- **PR #518 (MERGED)** — renamed `latent(residual=)` → `latent(unique=)` (soft-
  deprecated `residual=` alias kept); internal marker `.auto_residual` →
  `.auto_unique`.
- **PR #519 (OPEN, awaiting maintainer merge)** — folds `phylo_latent()`'s diagonal
  `Psi_phy` by default (`unique = TRUE`); supersedes the red **#516**.

Your job: **(a)** once #519 merges, close #516; **(b)** carry Stage A forward —
`spatial_latent` → `animal_latent` → `kernel_latent` folds, then the augmented
`phylo_latent(1 + x | sp)` fold; **(c)** Stage B hardening (per-family recovery
gates + the deferred docs). You own the **live toolchain** (real fits, full
`R CMD check`, heavy recovery suites, Julia) — use it; that is the Claude↔Codex
division of labour.

---

## 1. Repo state

- **`origin/main` = `c106df4`** (after #518).
- **Merged today:** #511–#515, #517 (earlier), then **#518** (latent unique= rename).
- **OPEN:** **#519** `feat(grammar): fold phylo_latent() … (unique=)` — branch
  `claude/phylo-unique-fold-20260621`, worktree `/private/tmp/gllvmtmb-phylo-unique-fold`.
  CI pending at handover; **maintainer-merge-gated** (grammar change). On merge →
  **close #516** (superseded; its branch `claude/phylo-fold-20260621` /
  worktree `/private/tmp/gllvmtmb-phylofold` can be pruned).
- **Do NOT touch** the dirty `codex/r-bridge-grouped-dispersion` checkout (the main
  working dir) — it predates all of today's merges. Use fresh worktrees off
  `origin/main`.

---

## 2. Hard guards (do not violate)

- **Grammar / engine / likelihood / family / export merges need EXPLICIT per-item
  maintainer "yes merge."** #518 was merged only after the maintainer said so. Each
  source-fold slice below is a grammar change ⇒ same gate. Docs/dev-log/after-task
  are self-mergeable when CI is green.
- **★ Run the FULL `devtools::check()` locally BEFORE every push.** This is the lesson
  of #516: it ran a phylo-only test subset (green) but the full check FAILED because
  the breakages were in `test-kernel-equivalence.R` / `test-canonical-keywords.R` /
  `test-animal-keyword.R` / `test-matrix-animal-nongaussian.R` — OUTSIDE the phylo
  files. A scoped run will lie to you.
- **Never `git add -A`** — stage by name (`git add -u` for tracked + the new files
  explicitly).
- **Do not revert Claude/human changes**; stop for maintainer discussion before
  deletions, API/grammar/likelihood/family changes, or broad article rewrites.
- **Never self-promote a validation-debt register row** (Design 35) — maintainer-gated.
- Commit trailer: `Co-Authored-By: <your Codex identity>` (Claude used
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`).
- **Surface at every stopping point**: open-PR links, after-task paths, and 🔴
  **Needs you:** blockers. The maintainer does not browse PRs unprompted.

### Heavy-test gate
Heavy recovery/equivalence tests are behind `GLLVMTMB_HEAVY_TESTS=1`
(`tests/testthat/setup.R`). To reproduce locally:
`Sys.setenv(GLLVMTMB_HEAVY_TESTS="1", NOT_CRAN="true")` then
`devtools::load_all(".")` + `testthat::test_dir("tests/testthat")` (or
`test_file(...)`). `skip_on_cran()` needs `NOT_CRAN=true`.

### Environment caveat (so you don't chase a ghost)
Local `devtools::check()` shows **1 ERROR + 1 WARNING that are NOT branch issues**:
`test-block-V.R:117` fails with `could not find function "equalto"` because the
installed `glmmTMB` (1.1.11) was built against TMB 1.9.17 while the env has 1.9.21
(`"equalto" %in% getNamespaceExports("glmmTMB")` → FALSE) — reinstall glmmTMB from
source to clear it. The WARNING is Apple-clang `R_ext/Boolean.h`
`-Wfixed-enum-extension` header noise. Both are identical on `origin/main`. On fresh
Linux CI they are absent.

---

## 3. ★ Canonical Ψ model (internalise before touching any fold)

`Sigma_level = Lambda Lambda^T + Psi` (Greek **Psi/psi**). The diagonal companion
**Psi = specific(residual) part + distribution(overdispersion) part**:
- **Gaussian & Poisson**: overdispersion part = 0 ⇒ Psi is the specific term ⇒ the
  families where the companion is genuinely needed.
- **Other non-Gaussian** (NB1/NB2, Beta, Gamma, GP-1, lognormal, Tweedie, Student-t):
  the family's own dispersion already carries it ⇒ an explicit Psi at the residual
  level double-counts; it IS identified/estimated at the non-residual levels (unit,
  cluster, cluster2, phylo).
- **Single-trial binary**: Psi unidentified ⇒ auto-skip (the #509 fix).

Grammar: `unique = TRUE` (default on ordinary `latent()` and now `phylo_latent()`)
carries Psi; `unique = FALSE` = loadings-only. `unique()` / `*_unique()` are
soft-deprecated compatibility syntax. `residual=` is a soft-deprecated alias of
`latent(unique=)` only (it never existed on the `*_latent()` keywords).

---

## 4. The source-fold recipe (reuse from #518/#519, do NOT reinvent)

Each `*_latent()` fold slice is the SAME three-part change. The phylo slice (#519)
is the worked reference; the diff lives on `origin/main` after #519 merges, and the
mechanics are:

**(a) Rewriter — `R/brms-sugar.R`**, a block right after the ordinary-`latent` fold
(search `if (identical(fn, "latent"))` → the next sibling `if (identical(fn,
"<source>_latent"))`):
- read `unique` (default TRUE), validate literal logical, drop it from the call;
- `unique = FALSE` → return the loadings-only rewrite (`*_rr` / `spde`) alone;
- else emit `<loadings-rr> + <companion>` where the companion carries the source
  marker **and** `.auto_unique = TRUE`, sharing the same structure via
  `.pass_through_extras(e, c(<keep-args>))`. Add `unique = TRUE` to the keyword's
  formal + a roxygen `@param unique`.
- **Guard**: augmented `*_latent(1 + x | g)` is returned EARLIER (the `.latent_slope`
  block) — the fold must only see the intercept-only form.

| source   | companion emitted by `*_latent(unique = TRUE)` |
|----------|-----------------------------------------------|
| phylo (done #519) | `phylo_rr(sp,…) + phylo_rr(sp, .phylo_unique=TRUE, .auto_unique=TRUE, [tree/vcv])` |
| spatial  | `spde(coords,…) + spde(coords, .spatial_unique=TRUE, .auto_unique=TRUE)` — **confirm the spde-unique marker name first** |
| animal   | `phylo_rr(id, vcv=A) + phylo_rr(id, .phylo_unique=TRUE, .auto_unique=TRUE, vcv=A)` (animal routes through the phylo engine with a pedigree-derived A) |
| kernel   | `phylo_rr(unit, .kernel_name, .kernel_mode,…) + phylo_rr(unit, .phylo_unique=TRUE, .auto_unique=TRUE, .kernel_name, .kernel_mode)` |

**(b) Dedup — `R/fit-multi.R`** (beside `is_auto_phylo_psi`, ~line 345): add an
`is_auto_<source>_psi` predicate; an explicit `*_unique()` at the same grouping
supersedes the auto-companion (drop it) → byte-identical to the explicit pair; and
extend the `auto_unique_off_family` (ordinal/delta) gate to drop the source
companion too. (For spatial the companion is `kind == "spde"`, not `phylo_rr`.)

**(c) Equivalence cascade — the #516 trap.** A source fold flips the default meaning
of bare `*_latent()`, which breaks every test asserting `bare *_latent ≡ <a
non-folding form>`. Find them, then set the COMPARED `*_latent(...)` to
`unique = FALSE`. For phylo these were `test-kernel-equivalence.R:159`,
`test-canonical-keywords.R:458`, `test-animal-keyword.R:182`,
`test-matrix-animal-nongaussian.R:319/407`. **Empirical loop:** implement → run the
candidate files under `GLLVMTMB_HEAVY_TESTS=1` → fix exactly what breaks → then the
FULL check.

**(d) Gates per slice** (you run these for real — your lane):
- **G1 byte-identity**: `*_latent(unique=TRUE)` ≡ `*_latent(unique=FALSE) +
  *_unique()` (`logLik` + `extract_Sigma` Δ < 1e-6) across the wired families.
- **G2 per-family + per-level recovery** of `Sigma_<src> = LL^T + Psi` (unit /
  cluster, + cluster2 where applicable) under `GLLVMTMB_HEAVY_TESTS=1`.
- **G3** `unique = FALSE` returns the loadings-only submodel.
- **G4** an explicit `*_unique()` still fits + warns (compat preserved until Stage E).

**(e) Per slice also**: roxygen `@param` + regenerated `man/*.Rd`, the
`01-formula-grammar.md` pairing-rule note, a NEWS entry, after-task report +
check-log, and **the FULL check before push**. New tests RED-first.

---

## 5. Detailed plan (staged; verification-gated; removal LAST)

### Stage A — source-specific Ψ-folds (in progress)
1. **phylo** — ✅ #519 (open). Close #516 on merge.
2. **spatial_latent** — next. SPDE/GMRF companion (`spde`, `.spatial_unique`,
   `.auto_unique`). Confirm the spde-unique marker + the `use_spatial_diag` engine
   slot exist (grep `spde`, `spatial_unique`, `use_spde` in `R/fit-multi.R` /
   `src/gllvmTMB.cpp`). Gates G1–G4 with a spatial DGP (mesh fixture).
3. **animal_latent** — routes through the phylo engine with a pedigree→A. The
   companion is a `phylo_rr(.phylo_unique, .auto_unique, vcv=A)`. Reuse the
   `animal_*` ↔ `phylo_*` byte-equivalence fixtures (`test-animal-keyword.R`,
   `test-matrix-animal-nongaussian.R`).
4. **kernel_latent** — Design-65 dense-kernel quartet; companion carries
   `.kernel_name` + `.kernel_mode`. Keep C1 phylo-equivalence < 1e-6.
5. **slice 1b** — augmented `phylo_latent(1 + x | sp)` fold (the intercept-only
   guard currently keeps explicit `phylo_unique` for augmented slopes).

### Stage B — hardening / docs (parallel to A; some deferred from #519)
- **B0 (deferred from #519):** bare-`phylo_latent` fire-on-use warning (mirror
  `.gllvmTMB_warn_latent_default_psi`); AGENTS.md + CLAUDE.md keyword-grid note
  ("`phylo_latent + phylo_unique` canonical" → "or bare `phylo_latent()`, which now
  folds Psi"); validation-debt register row for the phylo fold.
- **B1:** unit-level `latent(d≥1) + Psi` split-recovery gates for Poisson/NB2/Gamma/
  Beta/ordinal (today only Gaussian byte-identity + binary are deeply split-tested).
- **B2:** mixed ordinal/delta per-trait B-tier Psi skip (currently all-or-nothing).
- **B3:** document `latent()`/`*_latent()` per-family + per-level Psi behaviour
  (roxygen + man + grammar contract).

### Stage C — deprecation messaging
Standalone `*_unique()` → `*_indep()` (NOT `latent()`); ensure every deprecation
warning routes standalone → `*_indep()`. Demote `unique()` to a deprecated-alias note
in the api-keyword-grid article (gated on B3).

### Stage D — article / navigation reorg (downstream)
7-section taxonomy; `lambda` public; ordinal-probit → response-families + delete;
`_pkgdown.yml` restructure. Most `unique()`→`indep()` article wording already done
(#505/#508/#513).

### Stage E — removal of `*_unique()` (LAST)
Only after all four source folds + G1–G3 per source are green: flip soft-deprecation
to removal, source-by-source, each gated by its byte-identity + recovery evidence.

---

## 6. Worktrees & resume

- **PR #519 (open):** `/private/tmp/gllvmtmb-phylo-unique-fold` @ `91d2d71`
  (branch `claude/phylo-unique-fold-20260621`). After merge, prune it.
- **PR #518 (merged):** `/private/tmp/gllvmtmb-latent-unique` — prune.
- **#516 (superseded):** `/private/tmp/gllvmtmb-phylofold` — prune after closing #516.
- **New work:** `git worktree add /private/tmp/gllvmtmb-<slice> origin/main -b
  codex/<slice>-<date>` (off the post-#519 `main`).

Rehydrate: `git fetch`; confirm `origin/main` and `gh pr list`/`gh pr view 519`;
read the newest `docs/dev-log/check-log.md` entry + this note + the plan file.

---

## 7. First actions for the Codex session

1. `git fetch`. Confirm `origin/main` (= `c106df4`, or later if #519 merged) and
   `gh pr view 519` state.
2. If #519 is merged: **`gh issue close 516`** (superseded; reference #519) and prune
   the merged worktrees. If not merged: leave it; do not self-merge (grammar-gated).
3. Pick the next Stage-A slice (**spatial_latent**) — but first **confirm the spde
   unique-companion marker + engine slot exist** (grep `spde`/`spatial_unique`/
   `use_spde*` in `R/fit-multi.R` and `src/gllvmTMB.cpp`); if the spatial diagonal
   slot is not wired, raise it with the maintainer before coding.
4. Follow the §4 recipe; write RED-first tests; run G1–G4 for real under
   `GLLVMTMB_HEAVY_TESTS=1`; **run the FULL `devtools::check()` before pushing**;
   open one focused PR; surface it (grammar ⇒ maintainer-merge-gated).
5. After-task report + check-log per `docs/design/10-after-task-protocol.md`.

---

## 8. Pointers

- **Plan:** `~/.claude/plans/memoized-snuggling-balloon.md` (full staged migration).
- **Design:** `docs/design/2026-06-21-source-specific-latent-psi-fold.md` (Stage-A
  mechanics — note: it still uses the pre-#518 `residual=`/`.auto_residual` spelling;
  read it as the algorithm, but emit `unique=`/`.auto_unique`).
- **After-task (today):** `docs/dev-log/after-task/2026-06-21-latent-unique-rename.md`
  (#518), `docs/dev-log/after-task/2026-06-21-phylo-latent-unique-fold.md` (#519).
- **Family-id map** (`R/fit-multi.R`): 0=gaussian, 1=binomial, 2=poisson, 4=Gamma,
  5=nbinom2, 7=Beta, 12/13=delta_*, 14=ordinal_probit, 15=nbinom1.
- **Grammar contract:** `docs/design/01-formula-grammar.md`. **Scope:**
  `docs/design/04-sister-package-scope.md`.
