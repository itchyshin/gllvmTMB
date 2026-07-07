# Claude → Claude handover (2026-07-07)

**You are the next Claude, picking up gllvmTMB.** The big arc of the last two
sessions — the honest `B_lv` interval **and** the full MCMCglmm removal — is
**DONE and merged to `main`**. Your job is the two arcs the maintainer explicitly
queued next. Read this doc + the AGENTS.md rehydrate recipe, then spawn **Rose**
(the mandatory scope-audit lens) before any public claim.

> Context is ephemeral; the repo is authoritative (AGENTS.md). This doc is the map;
> the after-task report and the merged PRs are the territory.

---

## Mission-control summary

| Repo | Branch / main | CI | What shipped this session | Next by leverage |
|---|---|---|---|---|
| **gllvmTMB** | `main` @ `d297738c` | R-CMD-check **green** ✅ · pkgdown **green** ✅ · full-check **red** (known, #723) | (1) honest `B_lv` interval + production coverage; (2) **MCMCglmm removed from every runtime path** (tree + pedigree A⁻¹ native); (3) pkgdown deploy restored | (1) **`*_unique` deprecation** (maintainer directive); (2) full-check mixed-family fix (#723, Codex area); (3) tidy-ups |

---

## Critical context (the "why")

- **gllvmTMB** = multivariate stacked-trait GLLVMs on TMB; sister to `drmTMB`
  (univariate/bivariate). Keep it focused on the stacked-trait long-format model.
- The recent arc was **Design 76's structured × `X_lv`**, RE-SCOPED (maintainer,
  2026-07-06) to the **orthogonal Model A**: predictor informs the *ordinary*
  latent (`latent(…, lv = ~ x)`), phylogeny is a **separate orthogonal**
  `phylo_latent` term; estimand `B_lv = Λ_B·α^T`. Model A composes two existing
  capabilities — **no new TMB likelihood, no grammar change**. That arc is now
  complete + merged.
- **New maintainer direction (2026-07-07, firm, stated 3×):** deprecate the whole
  **`*_unique` series**. Rationale in his words: *"Phylo Latent does everything,
  and that's the only place we need random slopes. We don't need phylo unique."*
  i.e. `*_latent` (with `lv = ~ x` for the varying-effect role) covers what he
  needs; the `*_unique` random-slope machinery is redundant weight.

---

## What was accomplished (all on `main` now)

**1. Honest `B_lv` interval — the CI trio (PR #720, merged earlier).**
- `profile_ci_lv_effects()` — **hero** method, t-based cutoff (`.qt_threshold`,
  df = n_units − d − 1), analytic-gradient fast path (~9×).
- `bootstrap_ci_lv_effects()` — parametric percentile; also fixed `simulate()`'s
  unconditional RE redraw for `lv_B`/`phylo_rr`/`diag_species` tiers (this also
  repaired `bootstrap_Sigma` under-coverage).
- **REML** for the Gaussian `lv`/Model A path (unbiased variance components).
- Reachable via `extract_lv_effects(type="trait_effect", method="profile"/"bootstrap"/"wald")`.
- **Production coverage PASSED** (Totoro, ≥500 reps/cell, band 0.92–0.98):
  rank-1 Gaussian **0.952 / 0.950 / 0.962** at S=60/100/200. Rank-2 hard cell also
  finished (200/200 tasks; number not yet appended — see Next Steps). Artifacts:
  `docs/dev-log/artifacts/lv-effects-ci-coverage/`. Register row **`LV-09`**
  (maintainer-authorized) records this — **distinct from `LV-08`** (the interacting
  phylo-informed model), which **stays `blocked`**.

**2. MCMCglmm removed from every runtime path (PR #721, merged `d297738c`).**
- **Tree → A⁻¹:** `.gllvm_phylo_tree_precision()` (`R/phylo-tree-precision.R`,
  `ape`+`Matrix`), ported from drmTMB. Validated **byte-identical** to
  `MCMCglmm::inverseA(tree)$Ainv` (max|diff| 2.8e-14, identical sparsity + order).
- **Pedigree → A⁻¹:** `.gllvm_pedigree_precision()` (`R/pedigree-precision.R`,
  `Matrix`-only, Henderson/Quaas). Reproduces `MCMCglmm::inverseA(ped)$Ainv`
  **exactly** (0e+00), including inbreeding; genuinely sparse (unlike drmTMB's dense
  `chol2inv`). `pedigree_to_Ainv_sparse()` now calls it.
- MCMCglmm is now a **Suggests-only test oracle** — **no runtime `requireNamespace`
  guard remains**. Provenance in `inst/COPYRIGHTS`; adopted method (Hadfield &
  Nakagawa 2010 / Henderson 1976 / Quaas 1976) credited in docs.
- **Cross-package finding filed:** gllvmTMB's sparse Quaas pedigree inverse beats
  drmTMB's dense one → back-port issue **itchyshin/drmTMB#740**.

**3. CI cleanup (PR #722, merged; night work).**
- **pkgdown deploy fixed** — was failing on every `main` push since #720 (2 exported
  B_lv CI functions missing from `_pkgdown.yml`); indexed them; verified green.
- **full-check diagnosed** → issue **#723** (see Blockers).

---

## Current working state

- **Working / green:** `main` @ `d297738c`; R-CMD-check green; pkgdown green; the
  full phylo + Model A + pedigree/animal test suites pass locally and on CI.
- **Blocked / red:** `full-check` nightly (issue #723) — a real mixed-family M1
  extractor regression, in Codex's active grouped-dispersion area. NOT this
  session's to blind-fix.
- **Queued (not started):** the `*_unique` deprecation (needs a plan + maintainer
  sign-off); rank-2 coverage append; Design-76/S1 Model-A doc revision (task #14).

---

## Next immediate steps (in priority order)

1. **`*_unique` deprecation — plan first, then execute as its own PR.** This is a
   **grammar change → stop for maintainer sign-off on the plan before broad edits**
   (AGENTS.md high-risk rule). Scope:
   - Deprecate `phylo_unique` / `animal_unique` / `spatial_unique` / `kernel_unique`
     / bare `unique`, **both** forms: the diagonal keyword (already half-deprecated
     → `*_indep`) **and** the augmented random-slope form (`*_unique(1 + x | grp)`).
   - Surface: parser, the ~10 `*_unique*` test files, roxygen/keyword-grid docs
     (`R/gllvmTMB.R` table, `R/animal-keyword.R`), NEWS, the validation-debt register.
   - **HONESTY CHECK you must do, not assume:** is `phylo_latent(…, lv = ~ x)` a
     clean migration target for current `phylo_unique(1 + x | sp)` users? They are
     parameterized differently — latent loadings `Λ·α` vs an intercept/slope `Σ_b`
     covariance. Confirm the modeling equivalence (or state the gap) **before**
     advertising the swap. Use `lifecycle::deprecate_soft()` (see the `lifecycle`
     skill), not hard removal, for the first pass.
   - **Division of labour:** Claude plans + drafts the deprecation edits + docs;
     **Codex** runs the live heavy `*_unique` tests to confirm nothing breaks.

2. **full-check mixed-family fix (issue #723) — Codex/maintainer domain.** ~27 heavy
   failures clustered in `test-m1-4-extract-correlations-mixed-family.R` (+ m1-3,
   m1-5, m1-8) + a **56,000× `theta_diag_B` warning flood** (the OLRE guard at
   `R/fit-multi.R:4194` — emitting it that many times is itself a bug, likely
   per-iteration in a loop). It's in the `codex/r-bridge-grouped-dispersion` /
   `interval_status` arc. Don't blind-patch; coordinate.

3. **Append the rank-2 coverage number** to
   `docs/dev-log/artifacts/lv-effects-ci-coverage/` + Design 76 §Implementation.
   The cell finished on Totoro (`~/gllvmtmb_work/gllvmTMB/results/lv-effects-ci-coverage/gauss-S200-K2-hard/`,
   200/200 tasks). Pull it (see Gotchas re: the merge-guard net) and record. Bonus.

4. **Task #14 — revise design docs to Model A.** `docs/design/76-…` §1/§4 + the S1
   alignment doc still describe the *deferred interacting* model; add a Model-A
   framing pass so a reader isn't misled. Low-risk docs.

---

## Key decisions & rationale

- **Model A (orthogonal), not the interacting model.** Verified from GLLVM.jl; it
  composes existing R capabilities, no HIGH-RISK likelihood slice. `LV-08`
  (interacting) stays `blocked`; `LV-09` (orthogonal Model A) is the delivered row.
- **Tips-last node ordering in the tree builder.** The native builder is
  mathematically correct either way (marginal + log-det invariant), but MCMCglmm
  put tips last, and the different order perturbs TMB's sparse-Cholesky path enough
  to tip fragile fits. Ordering it tips-last (`R/phylo-tree-precision.R`, guard test
  added) makes it a numerical drop-in.
- **Robust fixtures for the `phylo_unique` guard tests.** The `n_lhs_cols=1` abort
  guards built knife-edge `n_sp=10` binomial fits that flip pass/fail on 1e-14
  numerical noise across platforms; pointed them at the robust `n_sp=60` fixture
  (they only need a converged fit to corrupt). Zero coverage loss. (These tests die
  in the `*_unique` deprecation anyway.)

---

## Gotchas / failed approaches (save yourself the time)

- **The merge guard blocks engine merges without an explicit *typed* directive.**
  Auto-mode denied merging PR #721 on garbled voice; the maintainer typing
  **"deal with 721"** was the clear authorization it needed. Docs/CI-only merges
  (PR #722) were allowed. So: engine PRs wait for a typed maintainer go.
- **zsh `status` is a read-only variable.** A `status=$(…)` in a Bash-tool script
  errors in this shell; use `st=`. Also `[ "$a" \> "$b" ]` string-compare warns in
  zsh. Bit me twice on CI-watch scripts.
- **Byte-identical ≠ bit-identical for knife-edge fits.** Even a 2.8e-14 Ainv
  difference (from a legitimately different algorithm) can flip a fragile small-n
  binomial fit on Linux. Don't chase it in the builder — make the *test* robust.
- **CI catches what filtered local runs miss.** The tips-first regression + the
  logit flake only showed on the full `R CMD check` (`GLLVMTMB_HEAVY_TESTS=1`), not
  my narrow local filters. Run the heavy gate before claiming green.
- **Totoro reads got caught in the merge-guard's conservative net** right after a
  denied merge — unrelated read-only `ssh` was refused. If it happens, wait a beat
  or simplify the command.

## Blockers / open questions for the maintainer

- 🔴 **`*_unique` deprecation plan** needs your sign-off before broad edits (grammar
  change). Especially: is `phylo_latent(lv=~x)` an acceptable migration story for
  `phylo_unique(1+x|sp)` users, or do we keep a note that they're different objects?
- 🟡 **full-check (#723)** is in Codex's active area — who lands the mixed-family fix?

---

## Files created / modified this session (`10bbed42..d297738c`, 26 files)

**Engine (new):** `R/phylo-tree-precision.R`, `R/pedigree-precision.R`
**Engine (edited):** `R/fit-multi.R` (tree A⁻¹ swap + tips-last), `R/animal-keyword.R`
(pedigree swap), `R/gllvmTMB.R` + `R/brms-sugar.R` (stale-MCMCglmm doc fixes)
**Tests:** `test-pedigree-precision.R`, `test-phylo-tree-precision.R` (new);
`test-phylo-unique-slope-{gaussian,binomial-probit,binomial-logit}.R` (robust fixtures)
**Docs/meta:** `_pkgdown.yml`, `inst/COPYRIGHTS`, `NEWS.md`,
`docs/design/35-validation-debt-register.md` (LV-09),
`docs/design/76-structured-xlv-phylo.md`,
`docs/dev-log/after-task/2026-07-06-blv-honest-interval.md`,
`docs/dev-log/artifacts/lv-effects-ci-coverage/*`, `man/*.Rd`
(B_lv CI trio files — `R/profile-derived.R`, `R/bootstrap-lv-effects.R`,
`R/lv-predictor.R`, `R/extractors.R`, `R/methods-gllvmTMB.R` — landed earlier in #720.)
**Plus this handover:** `docs/dev-log/handover/2026-07-07-claude-handover.md` + the
`CLAUDE.md` pointer refresh.

**Never stage:** `scratchpad_enum_results.txt` (untracked repo-root cruft) and any
`/private/tmp/.../scratchpad/*`.

---

## How to resume (next Claude)

Rehydrate (from AGENTS.md — the repo is authoritative):

```sh
cd "<repo root>"
git status --short --branch
git log --oneline -8
# read: this doc, the newest docs/dev-log/check-log.md entry, and
#       docs/dev-log/after-task/2026-07-06-blv-honest-interval.md
```

Then, **before any public claim, spawn Rose** (the scope-audit lens — no
over-claiming; keep `LV-08` blocked; `LV-09` is the orthogonal Model A).
Claude plans/refactors/writes prose + runs logic/CI checks; hand **live heavy R/TMB
runs** (`R CMD check`, heavy `*_unique` tests, Totoro sims) to **Codex**.

### One-command resume (paste in your authenticated terminal, from repo root)

Interactive (you steer):
```
claude "Rehydrate from docs/dev-log/handover/2026-07-07-claude-handover.md + the AGENTS.md rehydrate recipe, spawn Rose, then start Next Immediate Step 1: draft the *_unique deprecation plan for maintainer sign-off (do NOT edit grammar before sign-off)."
```

Autonomous, clean context (hands-off; keep it to the safe docs steps):
```
claude -p "Rehydrate from docs/dev-log/handover/2026-07-07-claude-handover.md, then do Next Immediate Steps 3 and 4 (append rank-2 coverage; Model-A doc revision). Do NOT touch grammar or *_unique code without maintainer sign-off." --max-budget-usd 5
```
