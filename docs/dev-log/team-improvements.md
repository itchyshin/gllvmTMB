# Team Improvements

This log records improvements to the agent team's operating process. Use it
when a task exposes a better way for Ada, Boole, Gauss, Noether, Darwin,
Florence, Fisher, Pat, Jason, Curie, Emmy, Grace, Rose, or Shannon to work.

This file is for process improvements, not package feature requests. Product,
statistical-design, formula-grammar, likelihood, or validation-policy changes
still belong in roadmap files, design docs, issues, pull requests, or the
validation-debt register.

## 2026-05-18 - drmTMB-Parity Hygiene

- Improvement adopted: copy `drmTMB`'s closure discipline, not its volume.
  Each meaningful `gllvmTMB` slice should still have a check-log entry,
  after-task report, exact checks, known limitations, and a clear next action,
  but the report should stay compact enough that the next agent can use it.
- Improvement adopted: keep the coordination board current when Codex or
  Claude returns after an absence. A stale "agent absent" assumption is itself
  a coordination risk once open PRs are waiting on that agent.
- Improvement adopted: source-of-truth cascades must include process files,
  not only user-facing prose. When the public API status of `traits(...)`,
  `gllvmTMB_wide()`, `meta_V()`, or the keyword grid changes, check
  `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`, `_pkgdown.yml`,
  relevant design docs, `docs/dev-log/known-limitations.md`, the
  validation-debt register, roxygen, generated Rd files, and project-local
  skills before closing the PR.
- Improvement adopted: after-task "Checks Run" sections should list completed
  commands only. Commands that are planned, running, or expected after commit
  belong under "Still to run" or "Next actions".
- Improvement adopted: any prose that says
  `Sigma = Lambda Lambda^T + diag(psi)` must name the tier and reporting
  scale it describes. Unit-tier Gaussian model covariance, phylogenetic
  paired terms, spatial latent-only terms, and mixed-family total
  latent-scale Sigma do not all have the same extractor interpretation.
- Improvement adopted: when a keyword has an equivalence test, that
  test is part of the prose contract. `indep()` is tested as the
  explicit marginal / diagonal path equivalent to standalone `unique()`;
  source-of-truth docs must not call it compound-symmetric just because
  the English name suggests "independent correlations".

## 2026-05-18 - Reader-Path Lessons From drmTMB

- Improvement adopted: first-user pages should get to a copy-runnable fit and
  one interpretation before large status matrices, validation machinery, or
  method caveats. For `gllvmTMB`, the `morphometrics` article is currently the
  strongest Tier-1 template.
- Improvement adopted: pkgdown build success is not enough. Before closing
  README, vignette, roxygen, or `_pkgdown.yml` changes, run a rendered
  reference-index / navigation pass from Pat's perspective: can a new applied
  user find the entry point, the main worked examples, the key extractors, and
  the current syntax without already knowing the package?
- Improvement adopted: technical/status pages are valuable, but they should
  not crowd the first-user path. Keep validation, cross-package checks,
  simulation recovery, and troubleshooting pages discoverable while routing new
  users first through Get Started, Choose Your Model, Morphometrics, Joint SDM,
  Covariance and Correlation, and Common Pitfalls.

## 2026-05-20 - Article Surface Reset And User-First Tooling

- Improvement adopted: public Tier-1 examples must show both the canonical
  long-format `gllvmTMB(value ~ ..., data = df_long, trait = "...")` route and
  the wide data-frame `gllvmTMB(traits(...) ~ ..., data = df_wide)` route,
  unless the article explicitly records why a wide companion is unsupported.
  Codex has repeatedly forgotten this requirement; future article reviews
  should treat it as a publication gate, not an optional polish item.
- Improvement adopted: no new or restored public article should be launched
  from source review alone. Build the HTML, show it to the maintainer, inspect
  examples, wording, truth-vs-fit recovery, scope boundaries, and figures, and
  only then make the page visible.
- Improvement adopted: examples should showcase infrastructure that already
  works. For gllvmTMB, that means scenario simulation helpers, extraction
  tables, plotting helpers, diagnostics, and uncertainty status before broad
  articles.
- Improvement adopted: copy drmTMB's operating system, not its article count:
  reader-intent navigation, tutorial contracts, worked-example inventory,
  readiness matrices, figure gates, issue ledgers, and after-task reports.
- Improvement adopted: Florence leads figure work from the start, not only at
  the end. For plot helpers and figure-heavy articles, she owns the scientific
  visual brief, colourblind-safe palette, rotation/uncertainty caption checks,
  and rendered-HTML verdict. Pat checks reader comprehension, Darwin checks
  biological meaning, Fisher checks uncertainty, Noether checks math captions,
  Grace checks pkgdown/CI risk, and Rose checks stale claims.

## 2026-05-18 - drmTMB Closed-Loop Slice Discipline

- Improvement adopted: copy the loop, not the size of the archive. The
  `drmTMB` pattern is a closed cycle: one small PR, explicit scope wall,
  targeted checks, after-task report, check-log entry, and a visible next
  surface. `gllvmTMB` should avoid broad "fix the docs" lanes that mix
  navigation, articles, engine wording, and validation promises without a
  stop point.
- Improvement adopted: make the README / pkgdown entrance task-shaped. The
  `drmTMB` site routes readers through "Start here", "What can I model now?",
  stable-core boundaries, model guides, tutorials, and developer notes. For
  `gllvmTMB`, the analogous route should separate worked model guides from
  concepts/reference pages and should keep the supported-versus-planned
  status visible before readers reach deep articles.
- Improvement adopted: use readiness matrices before comprehensive simulation
  claims. `drmTMB` does not say a model surface is ready just because one fit
  runs; it records likelihood, parser boundary, extractor, diagnostic,
  interval, and recovery-test status. `gllvmTMB` should use the validation-debt
  register the same way: an advertised feature is only reader-facing when the
  evidence row says what is covered, partial, or blocked.
- Improvement adopted: after-task reports should include "tests of tests" and
  named-reader review, not only a command list. Pat should see whether the
  article or README path is usable; Rose should see stale claims; Grace should
  see CI/pkgdown implications; Curie/Fisher should see whether simulation or
  interval evidence actually supports the claim.
- Improvement adopted: CI pacing is part of the social contract. `drmTMB`
  keeps three-OS checks strict, uses small slices, and lets pkgdown run after
  main checks. `gllvmTMB` should keep one open implementation PR at a time
  when compiled code or formula grammar is involved, and avoid rapid push
  cascades while a 3-OS run is still active.
