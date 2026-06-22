# Developer Notes direct-link accessibility labels

## Task goal

Make the Developer Notes pages honest when opened directly from search,
bookmarks, or old links. PR #530 made the navbar clearer; this follow-up
adds page-level labels so under-audit drafts and validation notes do not look
like first-stop tutorials.

## Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
TMB, parser, or pkgdown navigation change. The only model-language edits
replace ambiguous "unique variance" prose with "diagonal Psi variance"; the
`part = "unique"` extractor keyword and explicit `unique()` compatibility
notes remain unchanged.

## Files changed

- `vignettes/articles/data-shape-flowchart.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/animal-model.Rmd`
- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `vignettes/articles/random-slopes-nongaussian.Rmd`
- `vignettes/articles/cross-lineage-coevolution.Rmd`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/ordinal-probit.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `vignettes/articles/cross-package-validation.Rmd`
- `vignettes/articles/simulation-recovery-validated.Rmd`
- `vignettes/articles/simulation-verification.Rmd`
- `vignettes/articles/roadmap.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/troubleshooting-profile.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-developer-notes-direct-link-accessibility.md`

## Checks run

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - PASS: `No problems found`.
- `ruby -e 'require "yaml"; y=YAML.load_file("_pkgdown.yml"); groups=y["articles"].select{|s| ["Under-audit model drafts", "Developer validation notes"].include?(s["title"])}; groups.each{|s| puts "## #{s["title"]}"; s["contents"].each{|slug| f="vignettes/#{slug}.Rmd"; txt=File.read(f); tier=txt[/^tier:.*$/,0]||"MISSING tier"; label=txt.include?("Developer Note -- under audit") || txt.include?("Developer Note -- retire candidate") || txt.include?("Developer validation note") || txt.include?("tier: 2 # rendered roadmap"); puts "#{slug}: #{tier} | label=#{label}" }}'`
  - PASS: every Developer Notes page reported tier metadata and `label=true`.
- `ruby -e 'require "yaml"; y=YAML.load_file("_pkgdown.yml"); groups=y["articles"].select{|s| ["Under-audit model drafts", "Developer validation notes"].include?(s["title"])}; bad=[]; groups.each{|s| s["contents"].each{|slug| f="vignettes/#{slug}.Rmd"; txt=File.read(f); ok=txt.include?("Developer Note -- under audit") || txt.include?("Developer Note -- retire candidate") || txt.include?("Developer validation note") || txt.include?("tier: 2 # rendered roadmap"); bad << slug unless ok }}; abort("missing direct-link labels: #{bad.join(", ")}") unless bad.empty?; puts "developer-notes-direct-link-labels-ok"'`
  - PASS: `developer-notes-direct-link-labels-ok`.
- `Rscript --vanilla -e 'articles <- c("articles/data-shape-flowchart", "articles/animal-model", "articles/stacked-trait-gllvm", "articles/cross-package-validation", "articles/simulation-verification", "articles/covariance-correlation", "articles/troubleshooting-profile"); for (a in articles) { message("BUILD ", a); pkgdown::build_article(a, lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  - PASS: representative pages rendered.
- `rg -n 'Developer Note|under audit|retire candidate|first-stop tutorial|Developer validation note' pkgdown-site/articles/data-shape-flowchart.html pkgdown-site/articles/animal-model.html pkgdown-site/articles/stacked-trait-gllvm.html pkgdown-site/articles/cross-package-validation.html pkgdown-site/articles/simulation-verification.html`
  - PASS: rendered HTML contains the labels.
- `rg -n 'unique-tier|unique variance|unique variances|trait-specific unique|unique-variance|Preview -|Status -|Internal status -|not yet in the public article menu|public article menu|Lamdba|depreciat|deprecicat' README.md vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd ROADMAP.md _pkgdown.yml`
  - PASS: no stale unique-variance prose, misspellings, or old public-menu
    wording remained under the ASCII scan.
- `rg -n 'latent\(\) \+ unique|latent\([^\n]*\) \+ unique|unique_unit|loadings-only by default|\+ unique\(1 \| individual\)' README.md vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd ROADMAP.md _pkgdown.yml`
  - PASS: only expected compatibility notes in README and
    `covariance-correlation.Rmd`.
- `git diff --check`
  - PASS.

## Consistency audit

Pat's reader-path check drove the direct-link labels: every page in the
Developer Notes groups now tells a first-time reader what to read first. Rose's
stale-wording pass removed the obsolete "not yet in the public article menu"
sentence and replaced vague unique-variance prose with diagonal-Psi wording.
Grace's pkgdown check passed, and representative rendered pages show the new
labels in HTML.

## Tests of the tests

No test files were added. The closest executable checks are the YAML-derived
Developer Notes label scan and the rendered-HTML scan. The first would fail if
any Developer Notes slug lacked a direct-link label; the second would fail if
the label did not survive pkgdown rendering on representative pages.

## What did not go smoothly

The initial stale-wording scan from the prior nav work used double quotes around
backtick-heavy patterns and zsh tried to execute command substitutions. This
follow-up uses single-quoted `rg` patterns and records the exact commands.

## Team learning

Pat: direct-link readers need the same status cue as navbar readers. A page can
be buildable and still not be a beginner tutorial.

Rose: "under audit" must live in the page body, not only in `_pkgdown.yml`;
otherwise search traffic bypasses the taxonomy.

Grace: `pkgdown::check_pkgdown()` and focused renders are enough for this
prose-only slice; there were no roxygen, reference-index, parser, or TMB
changes.

Ada: keep article accessibility work in narrow slices. This PR labels direct
links; it does not delete, retire on disk, or rewrite the full article set.

## Design-doc updates

None. The slice follows the article-tier rule and the PR #530 taxonomy; it does
not change grammar, validation status, or capability design.

## pkgdown/documentation updates

All Developer Notes direct-link pages now have page-level status cues. The
Roadmap article carries `tier: 2` metadata because it is a top-nav reference,
not a worked tutorial.

## Roadmap tick

N/A. PR #530 already updated the roadmap taxonomy row. This follow-up tightens
the direct-link wording under the same article-surface reset work and does not
change a roadmap progress chip.

## GitHub issue ledger

- #230 (`Article surface reset and user-first tooling gate`) is relevant and
  remains open. This PR advances direct-link honesty but does not finish the
  full article reset.
- #347 (`[roadmap] Article completion (public learning path)`) is relevant as
  the broader article-completion tracker and remains open.
- No new issue was created; the next actions are already part of #230/#347.

## Known limitations and next actions

- This PR does not rewrite under-audit articles into Tier-1 tutorials.
- This PR does not delete or move any article source file.
- A later article-tier audit should decide which Developer Notes pages become
  public Model Guides, which stay technical references, and which are retired
  from the built site.
