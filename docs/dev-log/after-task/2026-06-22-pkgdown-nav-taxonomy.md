# After Task: pkgdown navigation taxonomy

## Task Goal

Reorganise the pkgdown article surface after PR #529 so readers see clear
purpose-based navigation: Model Guides, Concepts, Diagnostics & Validation,
and Developer Notes. The change keeps all articles buildable, but stops
presenting under-audit pages as first-stop tutorials.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
or TMB change. This PR changes pkgdown navigation, roadmap prose, and two
article prose/rendering details:

- `covariance-correlation` no longer prints an old wide formula with
  `+ unique(1 | individual)` as first-copy syntax.
- `data-shape-flowchart` uses `\mathrm{...}` rather than `\rm` so pkgdown's
  MathML render does not warn.

The current public model story remains: ordinary `latent()` carries
`Lambda Lambda^T + Psi`; explicit `latent() + unique()` remains
soft-deprecated compatibility syntax only.

## Files Changed

- `_pkgdown.yml`
- `ROADMAP.md`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/data-shape-flowchart.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-pkgdown-nav-taxonomy.md`

## Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,updatedAt,isDraft,url,mergeStateStatus,statusCheckRollup`
  -> PASS before editing shared docs; no open PRs after #529 merged.
- `git log --all --oneline --since="6 hours ago" -- _pkgdown.yml ROADMAP.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints AGENTS.md CLAUDE.md CONTRIBUTING.md docs/design DESCRIPTION inst/COPYRIGHTS`
  -> PASS; only recent article/kernel work from this lane, no competing nav edit.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "pkgdown article navigation" --limit 20 --json number,title,url,state,labels`
  -> found #230 and #347 as relevant open ledgers.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> first run failed because `articles/roadmap` was missing from the index.
  Fixed by listing Roadmap only under Developer validation notes for pkgdown
  index completeness; rerun PASS (`No problems found`).
- `ruby -e 'require "yaml"; y=YAML.load_file("_pkgdown.yml"); h=Hash.new{|hh,k|hh[k]=[]}; (y["articles"]||[]).each{|s| (s["contents"]||[]).each{|c| h[c] << s["title"] }}; dup=h.select{|k,v| v.size>1}; abort("duplicate articles: #{dup.inspect}") unless dup.empty?; files=Dir["vignettes/articles/*.Rmd"].map{|f| File.basename(f,".Rmd")}; listed=h.keys.map{|x| x.sub(%r{^articles/},"")}; missing=(files-listed).sort; extra=(listed-files).sort; abort("missing from article index: #{missing.inspect}") unless missing.empty?; abort("extra in article index: #{extra.inspect}") unless extra.empty?; puts "pkgdown-article-nav-unique-ok"'`
  -> PASS (`pkgdown-article-nav-unique-ok`).
- `Rscript --vanilla -e 'pkgdown::build_home(quiet = FALSE); pkgdown::build_article("gllvmTMB", lazy = FALSE, new_process = FALSE, quiet = FALSE); get("build_articles_index", envir = asNamespace("pkgdown"))(pkg = "."); articles <- c("articles/morphometrics", "articles/gllvm-vocabulary", "articles/fit-diagnostics", "articles/data-shape-flowchart", "articles/cross-package-validation"); for (a in articles) { message("BUILD ", a); pkgdown::build_article(a, lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  -> PASS; rendered home, Get Started, article index, and representative pages
  from each nav group. Initial `data-shape-flowchart` render warned on `\rm`;
  fixed and rerendered cleanly.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/covariance-correlation", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> PASS after removing the stale rendered `+ unique()` wide-formula output.
- `rg -n 'Model Guides|Concepts|Diagnostics &amp; Validation|Developer Notes|Under-audit model drafts|Developer validation notes|First Gaussian morphology model|Plain-English vocabulary|Can I trust this fit\?|Data-shape flowchart|Cross-package validation' pkgdown-site/index.html pkgdown-site/articles/index.html pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/morphometrics.html pkgdown-site/articles/gllvm-vocabulary.html pkgdown-site/articles/fit-diagnostics.html pkgdown-site/articles/data-shape-flowchart.html pkgdown-site/articles/cross-package-validation.html pkgdown-site/articles/covariance-correlation.html`
  -> PASS; rendered nav contains all four top-level article groups and
  Developer Notes headers.
- `rg -n 'latent\(\) \+ unique|latent\([^\n]*\) \+ unique|unique_unit|gllvmTMB_wide\(|Lamdba|depreciat|deprecicat|trait-specific unique variance|why `unique\(\)` matters|loadings-only by default|Use `phylo_latent\(\) \+ phylo_unique|Use `animal_latent\(\) \+ animal_unique|Use `spatial_unique|append `spatial_unique|\+ unique\(1 \| individual\)' README.md vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd ROADMAP.md _pkgdown.yml pkgdown-site/index.html pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/covariance-correlation.html`
  -> PASS with expected compatibility-only hits in README and
  `covariance-correlation`; no `unique_unit`, misspellings, or old first-copy
  `+ unique(1 | individual)` output remained.
- `git diff --check`
  -> PASS.

## Consistency Audit

Pat: PASS. First-click navigation is now reader-purpose based rather than one
large Articles bucket. Beginner pages stay under Model Guides and Concepts;
under-audit material is labelled before the reader clicks.

Rose: PASS. The article index has no duplicate slugs, every vignette is indexed
once, stale first-path `unique()` output was removed from the rendered
covariance article, and ROADMAP now matches the four-menu taxonomy.

Grace: PASS. `pkgdown::check_pkgdown()` passes after learning that Roadmap must
remain in the article index. Rendered HTML contains the expected dropdowns.

Noether/Fisher: PASS. No model, equation, likelihood, or inference claim was
expanded. The only covariance wording touched was to replace "trait-specific
unique variance" with "trait-specific diagonal variance" while preserving the
actual extractor component name `part = "unique"`.

Darwin: PASS. Model-guide labels name applied reader questions ("First Gaussian
morphology model", "Joint species distribution model") rather than machinery
alone.

## Tests Of The Tests

No new tests were added because this is a documentation/pkgdown navigation PR.
The duplicate-slug Ruby scan is the regression guard for the article-index
problem, and the rendered HTML scan is the guard for the public navbar labels.
The failed first `pkgdown::check_pkgdown()` run verified that the check catches
a missing vignette-index entry.

## What Did Not Go Smoothly

- The initial plan said Roadmap should be top-nav only, but pkgdown requires
  every vignette to appear in the article index. Resolution: keep Roadmap as a
  top-nav item for readers and list it only under Developer validation notes
  for index completeness.
- Rendering `data-shape-flowchart` exposed pre-existing MathML warnings from
  `\rm`; these were fixed with `\mathrm{...}` because the page is now reachable
  from Developer Notes.
- Rendering `covariance-correlation` exposed a stored fixture formula that
  printed old `+ unique()` syntax; the article now defines and prints the
  current clean wide formula directly.

## Team Learning And Process Improvements

Ada: Split the work correctly: PR #529 landed first, then this branch rebased
onto merged main before editing. That avoided stacking a public navigation PR
on an unmerged accessibility branch.

Pat: The useful unit of navigation is reader intent, not article count. The
top nav should tell readers whether they are fitting a model, learning
vocabulary, checking a fit, or reading maintainer notes.

Rose: A nav-only PR can still reveal stale rendered prose. The rendered
`+ unique()` output in `covariance-correlation` would have survived a source
scan alone because it came from a fixture formula print.

Grace: `pkgdown::check_pkgdown()` is still the cheapest way to catch article
index completeness. Roadmap can be top-nav in the user path, but it must also
be represented in the configured article index.

## Design-Doc Updates

No design docs changed. The current rule is already captured in
`docs/design/10-after-task-protocol.md`: meaningful pkgdown/article changes
need rendered checks, exact stale-wording scans, and an after-task report.

## pkgdown / Documentation Updates

The pkgdown navbar now exposes:

- `Model Guides`
- `Concepts`
- `Diagnostics & Validation`
- `Developer Notes`

The article index mirrors those groups, with Developer Notes split into
under-audit model drafts and validation notes. No article source was deleted.

## Roadmap Tick

Slice 2 "Curated pkgdown nav" updated from the old
`Model guide / Concepts / Methods only` wording to the new
`Model Guides / Concepts / Diagnostics & Validation / Developer Notes`
taxonomy. Status remains in progress because future article promotion still
requires per-page rendered review.

## GitHub Issue Ledger

Relevant open issues inspected:

- #230 "Article surface reset and user-first tooling gate" -- relevant; this
  PR advances the public-surface/navigation part but does not close the issue.
- #347 "[roadmap] Article completion (public learning path)" -- relevant; this
  PR reorganises the visible learning path but does not complete all article
  readiness gates.
- #340 and #349 appeared in broad roadmap search but are not directly changed
  by this navigation-only PR.

No issue was closed or created.

## Known Limitations And Next Actions

- This PR does not delete, retire, or fully rewrite any article.
- Developer Notes exposes under-audit pages as reachable references; each page
  still needs its own Pat/Rose/Fisher rendered review before promotion to
  Model Guides or Concepts.
- Full `devtools::test()` / `devtools::check()` were not rerun because no R
  code, TMB, roxygen, generated Rd, parser, or tests changed. `pkgdown` checks
  and focused renders passed.
