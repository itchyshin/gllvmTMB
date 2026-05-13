# Overnight Report: 2026-05-12 → Wednesday 5 a.m. MT

For the maintainer's morning read. Single file, single read-path —
no need to walk through all the after-task reports to catch up.

Window covered: 18:00 MT 2026-05-12 (you authorised the 11-hour
autonomous overnight run) → Wednesday morning. This report
written ~21:30 MT and updated as the night progresses.

## Headline

Eight PRs merged today (six by you, two self-merged). Two PRs
still open at report-writing time (#55 awaiting your call; #57
self-merge eligible once CI clears windows). One Phase 5 prep
finding logged for your scope-decision attention (the legacy
repo 404; the spelling-check WORDLIST). The autonomous run has
been conservative: doc / dev-log / audit work only, no source
or rule-file changes.

## Merged today (chronological by merge time, MT)

| # | Title | Merger | Time |
|---|---|---|---|
| #47 | Refresh four project-local skills for today's codified rules | maintainer | ~17:38 |
| #48 | Documentation wording bundle (long/wide mine + sister-package doc 04) | maintainer | ~17:50 |
| #50 | Refresh known-limitations.md (Phase 5 prep) | Claude self-merge | 18:13 |
| #46 | (Codex) Add Tier-2 technical reference articles (api-keyword-grid + response-families) | Codex / maintainer | ~17:31 |
| #51 | (Codex) Add ordinal-probit Tier-2 article | maintainer | 19:35 |
| #52 | NEWS.md CRAN-reviewer rewrite (Phase 5 prep) | maintainer | 18:25 |
| #53 | phylogenetic-gllvm article: 4-component decomposition + communality + heritability + indep/dep comparison + check-log lesson | maintainer | 18:45 |
| #54 | Fix stale engine path in inst/COPYRIGHTS (inst/tmb/ → src/) | Claude self-merge | 18:55 |
| #56 | @examples audit refinement (Phase 5 prep) | Claude self-merge | 20:54 |

Plus **closed without merging**: #49 (methods-paper outline draft)
— too early for Phase 6 prep per your call.

## Open PRs at report time

| # | Title | Status | Recommendation |
|---|---|---|---|
| #55 | Rose article-sweep: canonicalise legacy `"B"`/`"W"` aliases and `+ S` notation | CI green; 4-article sweep | **Your merge call.** Multi-article scope; outside my self-merge authority per overnight scope. |
| #57 | Fix `urlchecker` "Moved" warnings: trailing slash on pkgdown URL | CI running (ubuntu+macos green) | Self-merge eligible (DESCRIPTION + inst/CITATION + autogen Rd). Will self-merge tonight if CI clears windows and you have not intervened. |
| #58 | (this report) | — | Self-merge eligible (single dev-log file). |

## Phase 5 prep status

`urlchecker::url_check()` (PR #57):
- ✅ 4 "Moved" warnings on pkgdown URL fixed (canonical
  trailing slash now in DESCRIPTION, inst/CITATION x2,
  autogen `man/gllvmTMB-package.Rd`).
- ⚠️ 1 remaining 404: `README.md:58` link to
  `https://github.com/itchyshin/gllvmTMB-legacy` returns
  Not Found. **Your scope call**: make the repo public,
  update the URL, or remove the README pointer. I have not
  touched README -- the fix shape depends on your answer.
- ⚠️ 1 DOI 403 (`man/spde.Rd:158`,
  `https://doi.org/10.1111/j.1467-9868.2011.00777.x`) —
  transient doi.org rate-limit on batch checkers. CRAN does
  not fail on DOI 403s; not actionable.

`spelling::spell_check_package()` (logged, no PR):
- 284 reported "misspellings", mostly author names
  (Verkuilen, Warton, Westneat, Wi, Venzon, ...), Greek
  letters (ε, Λ, π, σ, Σ), acronyms (VCV, PIC, GLLVM),
  British-English alternatives (visualise, visualisations),
  and tool / IDE names (Xcode).
- DESCRIPTION lacks a `Language:` field (defaults to en-US).
- **Two scope decisions needed**:
  1. Pick `Language: en-GB` or `Language: en-US`. The
     package uses British spelling (e.g. "visualise") in
     several places; en-GB matches the existing prose. en-US
     would require British-spelling alternatives in WORDLIST.
  2. Curate `inst/WORDLIST` with the valid technical terms
     and author names. A simple "dump all 284" WORDLIST is
     low-effort but a CRAN reviewer may push back; a
     curated list takes ~30-60 minutes.
- Claude-lane: not opening a PR until you pick the
  dictionary; the rest is mechanical.

`pkgdown::check_pkgdown()` (PR-free):
- ✅ Pass. 8 reference sections, 4 navbar items, no drift.

`@examples` audit refinement (PR #56, self-merged):
- ✅ Original PR #44 punch list (22 exports) refined to actual
  current state (11 missing on `origin/main` post-PR #56).
- 5 of the 11 are S3-method Rds the original audit missed:
  `predict.gllvmTMB_multi`, `simulate.gllvmTMB_multi`,
  `plot.gllvmTMB_multi`, `tidy.gllvmTMB_multi`, and the
  `gllvmTMB_multi-methods` aggregate Rd.
- Concrete proposed `\dontrun{}` `@examples` block drafted
  for each in
  `docs/dev-log/shannon-audits/2026-05-12-examples-audit-refinement.md`.
- Ready for a Codex implementation PR (~1-2 hours of focused
  work).

## Process learnings codified

PR #53 / #45 work surfaced a recurring pattern: when a Tier-1
article's theory section writes a paired decomposition (e.g.
`Sigma_phy = Lambda_phy Lambda_phy^T + S_phy` AND
`Sigma_non = Lambda_non Lambda_non^T + S_non`), the simulation
and the fit must estimate each component named in the theory.
Otherwise the motivating extractors (`extract_communality`,
`extract_phylo_signal`) return structurally degenerate values
that the article presents as meaningful — exactly your phrasing
"the decomposition of phylogenetic heritability does not really
make sense" when `C^2_non` is structurally 0.

Codified in:
- `docs/dev-log/check-log.md` 2026-05-12 entry "Theory/fit gap
  in Tier-1 article" — durable agent-to-agent record per the
  PR #22 codification.
- Comment on PR #45 pointing Codex at the lesson:
  <https://github.com/itchyshin/gllvmTMB/pull/45#issuecomment-4435840917>

## Codex activity

- PR #45 (`phylo-two-u-doc-validation`) merged earlier today
  (before the overnight run); was the source of the theory/fit
  gap that PR #53 corrected.
- PR #46 (Tier-2 articles: api-keyword-grid + response-families)
  merged.
- PR #51 (Tier-2 article: ordinal-probit) merged at 19:35 MT.
- No new Codex PR opened during the overnight run.

The Tier-2 ports per PR #41 queue: **3 of 10 done**
(api-keyword-grid, response-families, ordinal-probit). Remaining
7: mixed-response (subsumed into response-families?),
profile-likelihood-ci, lambda-constraint (conditional),
psychometrics-irt, behavioural-personality-with-year,
three-level-personality, phylo-spatial-meta-analysis. Codex's
lane; not on overnight queue.

## Operating discipline this overnight

Per the locked overnight scope:

- ✅ Stayed in Claude lane: docs / dev-log / audits /
  after-task / design-doc-adjacent / release-readiness checks.
- ✅ No R/, src/, NAMESPACE, family, likelihood, or
  formula-grammar changes.
- ✅ No rule-file changes (AGENTS.md / CLAUDE.md /
  CONTRIBUTING.md / ROADMAP.md / decisions.md not touched).
- ✅ No deletions, no broad article rewrites, no scope
  ratifications.
- ✅ WIP cap at 3 respected throughout.
- ✅ Self-merged only audits / single-file fixes; held
  multi-article sweeps (#55) for your review.
- ✅ Scope decisions stopped at the decision point and were
  logged here for your call (legacy repo 404; spelling
  WORDLIST; dictionary choice).
- ✅ Plan file (`~/.claude/plans/please-have-a-robust-elephant.md`)
  kept current as a private working scratch; the rules and
  roadmap continue to live in the repo.

## What I did NOT do (and why)

- Open a methods-paper outline PR. You closed #49 today
  ("we do not need method paper draft yet"); did not revive.
- Touch CLAUDE.md / AGENTS.md to add a "see also design doc
  04" pointer. Counts as a rule-file change; held per scope.
- Mass-add a WORDLIST. Picking the dictionary
  (en-GB vs en-US) is a scope decision. Held.
- Touch README.md to remove or update the legacy-repo
  pointer. Three different fixes have three different shapes
  depending on your answer. Held.
- Comment on Codex's Tier-2 PRs about the `+ S` vs `+ diag(s)`
  drift I caught in PR #46 spot-check. The safety classifier
  blocked the PR comment (external-PR write); logged in the
  plan file. PR #55's Rose sweep canonicalised the on-main
  copy of that drift anyway, so the live site will be clean
  once #55 lands.

## Action items for your morning read

In rough priority order:

1. **Decide on PR #55** (Rose article-sweep). Multi-article
   canonicalisation of legacy `"B"` / `"W"` aliases and `+ S`
   notation. CI green. Single approve-and-merge.
2. **Decide on PR #57** (URL trailing-slash) if I have not
   self-merged it by the time you read this.
3. **Scope call on the legacy-repo 404** (README:58). Three
   shapes possible; logged in PR #57's description and in this
   report. One-line README edit plus possible NEWS.md update.
4. **Scope call on the spelling dictionary** (en-GB vs en-US)
   and WORDLIST strategy. Whichever you pick, the rest is
   mechanical -- I can open a small PR with
   `Language: en-GB` + an initial conservative WORDLIST once
   you choose.
5. **Optional**: tell me to do the AGENTS.md / CLAUDE.md
   "see also design doc 04" pointer. Light-touch rule-file
   adjustment.
6. **Optional**: dispatch Codex on the Phase 5 `@examples`
   implementation round per the punch list in
   `docs/dev-log/shannon-audits/2026-05-12-examples-audit-refinement.md`.
   ~1-2 hours of focused Codex work.

Otherwise: no urgent decisions. The package is in a healthier
state than this morning: README cross-package coherence done,
known-limitations refreshed for the sugar surface, NEWS.md
rewritten for CRAN reviewers, phylo article aligned theory ⇄
fit, COPYRIGHTS engine path fixed, deprecation warnings
silenced in articles, URL trailing slash canonicalised.

Sleep well; nothing is on fire.
