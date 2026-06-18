# After Task: Behavioural Syndromes Tier 3 Gate

## Goal

Start the biological worked-example article-council block one article at a
time, beginning with `behavioural-syndromes`, without publishing a candidate
article before its reader path, diagnostics, figures, and rendered evidence are
ready.

## Implemented

`vignettes/articles/behavioural-syndromes.Rmd` now has Tier 3 YAML and an
internal article gate. The gate states that this is a candidate Tier 1
biological worked example, but it stays out of public navigation until it has a
runnable wide-format fit, a diagnostic table, a clearer reader path, Florence
figure review, and rendered HTML review. The article-council ledger and ROADMAP
now name the same blockers and replace the coarse row mapping with the specific
rows used by this page: RE-04, RE-09, EXT-05, EXT-06, EXT-18, EXT-25..EXT-27,
DIA-08, and DIA-13.

## Mathematical Contract

No likelihood, formula grammar, simulation, extractor, or plot helper changed.
The article still teaches a two-level Gaussian `latent + unique` decomposition
for between-individual and within-individual covariance:
`latent + unique` at `unit = "individual"` and `latent + unique` at
`unit_obs = "session_id"`. This slice only records the publication gate.

## Files Changed

- `vignettes/articles/behavioural-syndromes.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `ROADMAP.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-behavioural-syndromes-tier3-gate.md`

## Checks Run

- Skill gates read: article-tier audit, Rose pre-publish audit, and
  after-task audit.
- Pre-edit lane check:
  `PATH="/opt/homebrew/bin:$PATH" gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,isDraft,headRefName,updatedAt,url`
  and
  `git log --all --oneline --since="6 hours ago" -- _pkgdown.yml ROADMAP.md vignettes/articles/behavioural-syndromes.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/dashboard docs/design`.
- Live evidence poll:
  `PATH="/opt/homebrew/bin:$PATH" gh pr view 489 --repo itchyshin/gllvmTMB --json number,state,isDraft,headRefOid,mergeStateStatus,statusCheckRollup,url,title`,
  `PATH="/opt/homebrew/bin:$PATH" gh pr view 101 --repo itchyshin/GLLVM.jl --json number,state,isDraft,headRefOid,mergeStateStatus,statusCheckRollup,url,title`,
  `PATH="/opt/homebrew/bin:$PATH" gh run view 27763712855 --repo itchyshin/GLLVM.jl --json status,conclusion,updatedAt,headSha,url,jobs --jq '{status: .status, conclusion: .conclusion, updatedAt: .updatedAt, headSha: .headSha, url: .url, statusCounts: ([.jobs[].status] | group_by(.) | map({(.[0]): length}) | add), conclusionCounts: ([.jobs[].conclusion] | group_by(.) | map({(.[0] // "blank"): length}) | add), failingOrActiveJobs: [.jobs[] | select(.status != "completed" or .conclusion != "success") | {name: .name, status: .status, conclusion: .conclusion, url: .url}]}'`,
  and `git ls-remote origin refs/heads/power-pilot-results`.
- Public-route scan:
  `rg -n "behavioural-syndromes\\.html|\\[.*behavioural.*\\]\\(behavioural-syndromes\\.html\\)" README.md vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd vignettes/articles/model-selection-latent-rank.Rmd vignettes/articles/joint-sdm.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd vignettes/articles/fit-diagnostics.Rmd vignettes/articles/convergence-start-values.Rmd vignettes/articles/pitfalls.Rmd vignettes/articles/missing-data.Rmd vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/troubleshooting-profile.Rmd vignettes/articles/gllvm-vocabulary.Rmd _pkgdown.yml`.
- Stale-wording scan:
  `rg -n "publication-grade|release-ready|bridge complete|scientific coverage passed|coverage passed|fast GLLVM|AI-REML|REML|full parity|complete bridge|profile-likelihood default|genuine bootstrap|meta_known_V|gllvmTMB_wide|trio|\\\\bf S|\\bS_B\\b|\\bS_W\\b|Two-U|two-U|under audit|Preview" vignettes/articles/behavioural-syndromes.Rmd ROADMAP.md docs/dev-log/audits/2026-06-18-article-council-ledger.md`.
- JSON and whitespace:
  `python3 -m json.tool docs/dev-log/dashboard/status.json`,
  `python3 -m json.tool docs/dev-log/dashboard/sweep.json`, and
  `git diff --check`.
- Pkgdown:
  `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  and
  `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`.
- Rendered HTML checks:
  `rg -n "Internal article gate|candidate Tier 1|diagnostic table|wide-format fit|behavioural-syndromes" pkgdown-site/articles/behavioural-syndromes.html pkgdown-site/articles/index.html`
  and
  `sed -n '100,130p' pkgdown-site/articles/index.html`.

## Tests Of The Tests

No package tests were added because this slice changes article metadata and
publication gating only. The meaningful integration check is pkgdown rendering:
it proves the article remains buildable and appears only in the internal article
index, while the public-route scan checks that visible articles do not route
readers to the hidden page.

## Consistency Audit

Rose verdict: PASS for this slice. The public-route scan returned no hits. The
stale-wording scan returned only existing guard text in the ledger and guarded
`publication-grade` caveats in ROADMAP, plus an unrelated existing
`psychometrics-irt` preview ROADMAP row. The live poll did not require a
volatile dashboard-only update: #489 is unchanged, #101 CI remains in progress,
and `power-pilot-results` remains at `1a2aac6`.

## What Did Not Go Smoothly

The validation-register grep showed the old ledger row was too coarse: it cited
RE-12, but this behavioural-syndrome article primarily relies on two-tier
latent/unique rows, extractors, diagnostic rows, and figure helpers. The ledger
now names those rows explicitly.

## Team Learning

Pat and Darwin should treat the article as biologically promising but not yet
reader-ready. Florence is a real gate here: the covariance, ordination,
loading-recovery, and truth-comparison plots need publication-quality review
before the page becomes Tier 1.

## Known Limitations

This does not rewrite the article, add the missing wide-format fit, add
`diagnostic_table()` output, or promote any biological article to public
navigation. `phylogenetic-gllvm` and `animal-model` remain untriaged in this
biological block.

## Next Actions

Continue the biological article council one article at a time. The next safe
choices are either to add the missing wide/diagnostic work to
`behavioural-syndromes` or to run the same internal-gate triage on
`phylogenetic-gllvm`.
