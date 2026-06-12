# `unique` deprecation — execution-ready migration spec (code + pages)

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Status:** spec for
when Slice 1 is greenlit. No code/grammar/page changed. Builds on
`2026-06-12-latent-psi-fold-design.md`, `…-slice1-…-brief.md`,
`…-unique-deprecation-audit.md`.

**Sequencing reminder:** the page cascade must follow the engine change, not lead
it. Until `latent` carries Ψ by default, dropping `+ unique(...)` from a page
silently strips the residual. **Code (Slice 1) → then pages.**

## A. Code change-surface (Slice 1) — line-level

The desugar layer already maps the keywords (`R/brms-sugar.R` ~1841):

```
latent(0+trait|g, d=K)  -> rr(0+trait|g, d=K)        # shared ΛΛᵀ
unique(0+trait|g)       -> diag(0+trait|g)           # residual Ψ
indep(0+trait|g)        -> diag(0+trait|g, .indep=TRUE)
```

So Slice 1 is small and surgical:
1. **`latent` branch** (`R/brms-sugar.R`): after emitting the `rr` covstruct,
   **also auto-emit a companion `diag` (Ψ) term** by default — gated by the
   existing per-family identifiability guard (the same one that decides whether
   `unique()` is identified; `unique-keyword.R:46` rules + `fit-multi.R:3329` OLRE
   block). Add a `residual = FALSE` arg that suppresses the auto-`diag`.
2. **`unique()` / `diag` branch**: `lifecycle::deprecate_warn`; when the paired
   `latent` already auto-emitted the `diag`, the explicit `unique()` becomes a
   **no-op** → byte-identical fit. A **standalone** `unique()` (no `latent` on that
   grouping) routes to **`indep()`** (`diag(..., .indep=TRUE)`).
3. **`fit-multi.R`**: read the new default; **reuse** existing guards (no new
   identifiability logic). The over-param guard (565–650) is unchanged.
4. **Bare `latent`** (no explicit `residual=`): fire the transition warning
   (clean-break leaning — maintainer lock).
5. `unique-keyword.R` / `man/` / NAMESPACE: deprecate-warn, regenerate, keep
   exports live this cycle.

**Precedent:** the old `rr`/`diag` aliases already use this exact deprecate-warn
pattern (`brms-sugar.R:90`, "Aliases will be dropped at the next minor release").

## B. 🔴 Open scope decisions — these BLOCK execution

1. **Prefixed rows in scope?** Does the fold/deprecation touch
   `phylo_unique` / `animal_unique` / `spatial_unique` (i.e. fold Ψ_phy into
   `phylo_latent`, deprecate `phylo_unique`, etc.), or **only the no-prefix
   `unique`?** `AGENTS.md`/`CLAUDE.md` treat `phylo_latent + phylo_unique` as the
   **canonical** phylogenetic decomposition and standalone `phylo_unique` as a
   *distinct* intra-phylogeny diagonal keyword. **This one decision drives ~40% of
   the page edits.** Default assumption in this spec: **no-prefix `unique` only**;
   prefixed rows LEAVE until separately decided.
2. **`kernel_unique()` (Design 65)** — the generic dense-kernel quartet, a separate
   tier from the source grid. Almost certainly **OUT of scope**; confirm exclude.
3. **Two public pages are conceptual rewrites, not line edits** — both 🔴
   broad-article/grammar (Discussion Checkpoint), land as one reviewed snippet:
   - `covariance-correlation.Rmd` — its title/`VignetteIndexEntry` is literally
     "*when you need `unique()`*"; the whole A-vs-B (latent-only vs latent+unique)
     demonstration must be redesigned (likely `latent()` vs `indep()` to keep a
     contrast).
   - `api-keyword-grid.Rmd` — it documents the 4×5 grid itself; the `unique`
     *column* is being deprecated. Strike or annotate-as-deprecated — a grammar
     change.

## C. Migration rules (the buckets)

- **A — decomposition** `latent(...) + unique(...)` → `latent(...)` (drop `+ unique`).
- **B — augmented** `unique(1 + x | g)` / `*_unique(1 + x | g)` → **LEAVE** (Slice 2).
- **C — extractor** `part = "unique"` → **LEAVE**.
- **D — "uniqueness"/communality** prose → **LEAVE**.
- **standalone** `unique(...)` alone (no `latent` on that grouping) → **`indep(...)`**.
- **prose** naming the keyword → reword to "`latent` carries Ψ by default".

## D. Public-page checklist (priority order)

Apply long+wide byte-identity on every chunk edit (both forms in a chunk change
together).

- **README.md** — A: drop `+ unique(...)` at 95, 160, 173; prose 21 (grid row),
  184–190, 199–201, 215–216; **LEAVE** 250 (augmented B), 252 (extractor C),
  220/253 (augmented prose), 39 (communality D).
- **api-keyword-grid.Rmd** — 🔴 grid-table rewrite (see B.3). A: 94, 148, 158;
  standalone→indep: 93, 184; prose: 31, 57, 65, 77–82, 99–103, 127, 166, 176,
  299–306; prefixed (45–47, 207, 222–270) pending B.1.
- **covariance-correlation.Rmd** — 🔴 conceptual rewrite (see B.3). A: 42, 54,
  93, 106–107, 435/437 (two-tier); standalone→indep: 464 (OLRE); prose: 29–31,
  61–72, 215, 336–348, 388–426, 474–477; C: 92, 280–303, 479; title 2/8;
  see-also link 484 (→ `reference/unique.html`).
- **morphometrics.Rmd** — prose/conceptual: 202, 222–238 (identifiability
  callout), 278–282 ("why you need unique" — obsolete), 340–343, 406, 425,
  436–439, 530; C: 240–243; D: 117, 211, 261, 450. **Note:** the primary fit comes
  from `morph$formula_*` in `data-raw/` — the real formula edit is there, not in
  the Rmd.
- **model-selection-latent-rank.Rmd** — standalone→indep: 122 (d=0 baseline),
  157/249–250 (labels); A: 128 (d≥1 candidates); prose: 63, 116, 435.
- **joint-sdm.Rmd** — prose: 177, 350, 555; standalone→indep: 355–356 (prose
  design); D: 338, 383.
- **pitfalls.Rmd** — A/prose: 275, 303; prose: 48, 118, 147, 162, 186, 234;
  standalone→indep: 289–290; D: 205, 220, 285; prefixed 261–266 pending B.1.
- **response-families.Rmd** — A: 83, 100; standalone→indep: 55 (OLRE);
  prose: 158; D: 136.
- **fit-diagnostics.Rmd** — prose: 37 (single hit).
- **convergence-start-values.Rmd** — A: 99, 121; prose: 77, 174, 250; D: 227, 245.
- **lambda-constraint.Rmd** — mostly D (LEAVE 538–914); prose: 753–754, 830–831.
- **gllvmTMB.Rmd** (Get started) — prose only: 50, 104, 106–108, 230; D: 34, 39,
  102, 233. Primary fit from `data-raw/`.

## E. Internal drafts (lower priority; alias keeps them running)

Most volume + the trickiest mixed-tier cases:
- **random-regression-reaction-norms.Rmd** — 🚩 nearly **all LEAVE**: every
  `unique(1+x|...)` / `(0+trait):x` is augmented (B). Only stray prose (40, 511)
  rewords.
- **choose-your-model.Rmd**, **functional-biogeography.Rmd**,
  **phylogenetic-gllvm.Rmd**, **animal-model.Rmd**, **stacked-trait-gllvm.Rmd** —
  mixed A / standalone→indep / B / prefixed-pending. Multi-tier stacks where one
  tier is `latent+unique` (A) and the rest are standalone (indep) — **line-by-line,
  easy to mis-bucket.**
- Low-volume: profile-likelihood-ci, cross-lineage-coevolution (uses
  `kernel_unique` — B.2 out-of-scope), behavioural-syndromes, ordinal-probit,
  mixed-family-extractors, cross-package-validation, gllvm-vocabulary,
  data-shape-flowchart, simulation-*, random-slopes-nongaussian, psychometrics-irt.
- **Zero hits (no action):** troubleshooting-profile, roadmap, missing-data,
  lambda-constraint-suggest.

## F. NEWS.md + reference

- **NEWS.md** — do **not** retroactively rewrite historical entries (they describe
  shipped behaviour). Add **one new** development-version entry announcing the
  deprecation + the migration map.
- **Reference (`man/`)** — `unique` man page gets `lifecycle::deprecate_*`;
  see-also links (`covariance-correlation.Rmd:484`, the `?unique` grid refs) update
  **in lockstep**. Deprecating a public export is 🔴 high-risk.

## G. Mis-bucketing flags (the cases most likely to go wrong)

1. **Augmented-looking-like-decomposition** — `*_unique(1 + x | g)` inside a
   `latent + unique` block (README:250, random-regression-*, etc.) → **B, LEAVE**.
2. **Standalone paired against a *prefixed* latent** — trailing no-prefix
   `unique()` after `animal_latent`/`phylo_latent` (animal-model:252/354,
   phylogenetic-gllvm:135/148/568, covariance-correlation:464, joint-sdm:355,
   pitfalls:289, model-selection:122) has **no matching no-prefix `latent`** at its
   tier → **`indep()`**, not a collapse.
3. **Prefixed-row scope (B.1)** — gates ~40% of prefixed lines.
4. **`kernel_unique` (B.2)** — exclude.
5. **Two conceptual-rewrite pages (B.3)** — maintainer-gated snippets.
6. **`data-raw/` carries the flagship fits** — morphometrics + gllvmTMB.Rmd real
   formulas live in `data-raw/examples/`, outside the page set.
