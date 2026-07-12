# gllvmTMB — Codex → Claude handover (2026-07-12)

You are Claude, picking up the documentation-renewal lane in
`/Users/z3437171/Dropbox/Github Local/gllvmTMB`. Read this document and the
repository `AGENTS.md` before editing. The authoritative goal is **documentation
quality before release**, not a 0.5.0 merge, tag, or CRAN submission.

## Goals / mission

Renew the reader-facing gllvmTMB article estate so an applied user sees one
current, honest story. The retained articles must teach the current four-mode
covariance API, keep deprecated compatibility syntax out of the main teaching
path, make grouping roles understandable, and distinguish local verification
from a deployed public site. Shinichi explicitly wants a fresh Claude review
after this Codex loop; release decisions remain his.

## What was accomplished

- Fisher, Rose, and Pat each completed a final 13-article review: **13/13 PASS**
  under each lens. Evidence is in the three final audit files and the batch
  reports under `docs/dev-log/audits/`.
- Internal validation-register identifiers and process-only markers were
  removed from the retained reader pages and regenerated local pkgdown HTML.
- The public teaching grid is now Scalar, Independent, Dependent, and Latent.
  Standalone `unique()`/`*_unique()` is compatibility syntax and is labelled
  deprecated; the current `unique =` argument on latent APIs remains where it
  controls the diagonal Psi companion. Base-R `unique()` calls used to deduplicate
  data are unrelated and remain ordinary R code.
- `phylogenetic-gllvm.Rmd` is now latent-focused. Both worked examples use
  `phylo_latent(..., unique = TRUE)` so the shared Lambda Lambdaᵀ and
  phylogenetic Psi parts can be extracted. The non-phylogenetic comparison uses
  ordinary `latent(..., unique = TRUE)`. No `phylo_dep()` or `phylo_indep()` route
  remains in that article.
- The explicit grouping-argument cascade is complete: 22 executable calls and
  five display-only calls passed. Long calls name `trait` and `unit`; repeated
  designs name `unit_obs`; `cluster` is named in the phylogenetic guide where it
  is a real role; no invented `cluster2` column was added. One commented negative
  example in `pitfalls.Rmd` intentionally retains the package default to teach
  the missing-`site` error and immediately shows the explicit override.
- The stale profile-likelihood rendered page was rebuilt. All 13 retained local
  HTML pages are newer than their Rmd sources.

Read the detailed evidence rather than re-deriving it from chat:

- `docs/dev-log/after-task/2026-07-12-codex-retained-article-renewal.md`
- `docs/dev-log/audits/2026-07-12-final-fisher-13-article-audit.md`
- `docs/dev-log/audits/2026-07-12-final-rose-13-article-audit.md`
- `docs/dev-log/audits/2026-07-12-final-pat-13-article-audit.md`
- `docs/dev-log/audits/2026-07-12-explicit-grouping-argument-cascade.md`
- `docs/dev-log/check-log.md` (latest 2026-07-12 entries)
- `docs/dev-log/decisions.md` (deprecation, latent phylo focus, and renewal rule)

## Current working state

- Branch: `claude/release-0.5.0`.
- The handover bundle is committed as `3b6f4225` and pushed to
  `origin/claude/release-0.5.0` on this same feature branch. Four earlier local
  commits were pushed with it. Do not merge it to `main`.
- The working tree contains a broad, pre-existing WIP estate: the landing gate
  reported **261 uncommitted paths** (246 tracked paths in the diff, plus
  untracked audit/generated files). This is not all attributable to the narrow
  article slice. The complete carried-over manifest is recoverable with:

  ```sh
  git status --short --branch
  git diff --name-only
  git ls-files --others --exclude-standard
  ```

- The specific article/API/audit changes named above are the intended current
  loop. Other dirty R, test, man, generated, deletion, and experimental files
  must not be silently folded into a release claim; inspect and classify them.
- Local pkgdown server used for visual inspection: `http://127.0.0.1:8899/`,
  serving `pkgdown-site/`. The local browser is evidence for this checkout only.
- No merge to `main`, `v0.5.0` tag, CRAN submission, or public GitHub Pages
  deployment has been performed.

## Key decisions and rationale

1. **Four-mode reader contract.** Teach Scalar, Independent, Dependent, and
   Latent. Do not restore a five-column grid merely because deprecated aliases
   remain exported. `indep()` is the current standalone diagonal route.
2. **Deprecation is a migration, not deletion.** Do not claim `unique()` has
   been removed while the parser/exports remain live. Keep the current latent
   argument `unique = TRUE/FALSE` distinct from deprecated standalone functions.
3. **Phylogenetic purpose.** The guide’s scientific question is the latent
   phylogenetic covariance decomposition. Use `phylo_latent(..., unique = TRUE)`
   and show shared/unique/total extraction; reserve other covariance helpers for
   separate future references rather than diluting this worked example.
4. **Grouping roles.** Make `trait`, `unit`, and where applicable `unit_obs` /
   `cluster` explicit. Do not invent `cluster2` arguments without a real column
   and a real model role.
5. **Local versus live.** A fresh local render is not evidence that the public
   GitHub Pages site has deployed. The branch must be merged and deployed before
   saying the live site changed.

## Files created or modified in this loop

The reader/API source set includes:

`README.md`, `NEWS.md`, `_pkgdown.yml`, `R/gllvmTMB.R`, `R/kernel-keywords.R`,
`R/brms-sugar.R`, `R/fit-multi.R`, `R/phylo-signal-ci.R`,
`vignettes/articles/api-keyword-grid.Rmd`, `gllvm-vocabulary.Rmd`,
`response-families.Rmd`, `random-regression-reaction-norms.Rmd`,
`convergence-start-values.Rmd`, `behavioural-syndromes.Rmd`,
`fit-diagnostics.Rmd`, `missing-data.Rmd`, `pitfalls.Rmd`,
`pre-fit-response-screening.Rmd`, `profile-likelihood-ci.Rmd`,
`fixed-effect-zero-constraints.Rmd`, `phylogenetic-gllvm.Rmd`,
`morphometrics.Rmd`, and `joint-sdm.Rmd`, plus regenerated files under
`pkgdown-site/` and the relevant generated/reference surfaces.

Evidence and durable records created/updated:

- `docs/dev-log/audits/2026-07-12-retained-articles-batch-a.md`
- `docs/dev-log/audits/2026-07-12-retained-articles-batch-b.md`
- `docs/dev-log/audits/2026-07-12-retained-articles-batch-c.md`
- `docs/dev-log/audits/2026-07-12-final-fisher-13-article-audit.md`
- `docs/dev-log/audits/2026-07-12-final-rose-13-article-audit.md`
- `docs/dev-log/audits/2026-07-12-final-pat-13-article-audit.md`
- `docs/dev-log/audits/2026-07-12-explicit-grouping-argument-cascade.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/decisions.md`
- `docs/dev-log/after-task/2026-07-12-codex-retained-article-renewal.md`
- `docs/dev-log/recovery-checkpoints/2026-07-12-065204-codex-checkpoint.md`
- this handover document.

The exhaustive branch-level manifest is intentionally not duplicated here:
because this checkout began with a large dirty WIP state, use the three git
commands in **Current working state** and classify each path before staging.

## Checks already run

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — PASS, no problems found.
- `git diff --check` — PASS.
- All 13 retained source/render mtime pairs — PASS, rendered HTML newer than Rmd.
- Internal-code scan over `vignettes/articles` and `pkgdown-site/articles` — zero
  DIA/CI/EXT/FAM/FG/MIX/register/validated matches.
- Retained source/render scan for `phylo_dep()` and `phylo_indep()` — zero.
- Rose grouping cascade — 22/22 executable calls, 5/5 display calls; three
  changed articles rendered successfully with zero warning/error/deprecation
  log matches.
- Fisher’s latent phylogenetic fit evidence — all health rows pass; long/wide
  log-likelihood differences were below `4e-10`.

## Next immediate steps for Claude

1. Rehydrate from this file, `AGENTS.md`, and the newest recovery checkpoint;
   run `git status --short --branch`, `git diff --stat`, and inspect the full
   carried-over manifest before editing.
2. Run a fresh Rose pre-publish audit over the changed README/NEWS/reference/
   article surfaces. Treat any newly found internal code as a repeated failure:
   search the whole retained estate, not only the screenshot page.
3. Inspect the 13 local pages visually, including mobile width and responsive
   tables/figures. The current local link for the user is:
   [phylogenetic covariance among traits](http://127.0.0.1:8899/articles/phylogenetic-gllvm.html)
   and the keyword grid is:
   [formula keyword grid](http://127.0.0.1:8899/articles/api-keyword-grid.html).
4. Resolve the dirty-tree classification: stage only the intended article-renewal
   slice, keep unrelated WIP explicit, and update this handover if the scope
   changes. Do not use `git add -A`.
5. Run `pkgdown::check_pkgdown()` and a forced article render after any edit.
   If release work is later authorized, run the full `--as-cran` gate then; it is
   not a prerequisite for this handover and release remains paused.
6. Return the disposition/approval question to Shinichi before any merge, tag,
   or CRAN submission. Fresh Claude eyes are the point of this handover.

## Blockers / open questions

- The broad dirty WIP tree must be classified before a clean PR can be claimed.
- The local site is current for this checkout; the public GitHub Pages URL may
  remain stale until merge/deployment.
- Shinichi must decide which remaining article dispositions belong in the final
  release PR. Do not infer that approval from the local 13/13 review alone.

## Gotchas / failed approaches

- A source edit can leave a stale rendered HTML page; always rebuild and compare
  source/render mtimes.
- Internal validation codes can survive in generated pages even after source
  prose changes; scan both Rmd and generated HTML.
- The standalone `unique()` deprecation must not be confused with base-R data
  deduplication or the current `latent(..., unique = TRUE)` argument.
- The `pitfalls.Rmd` commented mismatch is intentional teaching content, not a
  missing grouping argument to repair.
- Do not infer that the local server proves deployment to
  `itchyshin.github.io`.

## How to resume

From the repository root in an authenticated Claude terminal, paste exactly:

```sh
claude "Rehydrate from docs/dev-log/handover/2026-07-12-claude-handover.md + the AGENTS.md snapshot, then continue with the Next Immediate Steps."
```

Claude should spawn the mandatory Rose lens before making a public-facing
completion claim. Codex owns live R/TMB fits, rendering, and package checks;
Claude owns the fresh prose/refactor review and coordination in this next
sequential session.

## Landing State

| Artefact | State at handover | What the next session must do |
|---|---|---|
| `claude/release-0.5.0` branch | `3b6f4225` pushed; branch remains a feature/WIP branch | Verify the branch tip before relying on origin |
| Retained article source + local pkgdown HTML | Reworked and locally verified | Fresh-eye review; rebuild after any edits |
| Fisher/Rose/Pat audits | Written; all 13/13 PASS | Treat as evidence, not a substitute for Claude’s fresh review |
| Broad pre-existing dirty WIP | **CARRIED-OVER**; 261 paths at landing gate | Classify with git status/diff; do not silently stage unrelated files |
| `main`, `v0.5.0`, CRAN | Untouched | Shinichi decides later |

## Mission control

| Lane | Current truth | Next owner | Gate |
|---|---|---|---|
| Article prose and examples | 13 retained pages reviewed and rendered locally | Claude + Rose | Fresh pre-publish audit |
| API/deprecation story | Four-mode teaching surface; deprecated aliases fenced | Claude | Whole-estate stale scan |
| Phylogenetic guide | Latent-focused Lambda/Psi split, honest recovery limits | Claude + Shinichi | Reader approval |
| Generated site | Local HTML fresh; public deployment not claimed | Claude/Grace later | pkgdown check + deployment |
| Branch/PR | Feature branch with carried-over dirty WIP; no merge | Claude + Shinichi | Scope classification, then PR review |
| Release | Paused | Shinichi | Explicit release call only |

**Forwardable note:** gllvmTMB docs renewal is locally verified and the 13
retained pages passed Fisher/Rose/Pat review, including the latent-focused
phylogenetic rewrite and explicit grouping-argument cascade. The branch still
has broad carried-over WIP; Claude must rehydrate from this handover, inspect
the dirty manifest, run a fresh Rose audit, and keep 0.5.0 merge/tag/CRAN work
paused until Shinichi decides.
