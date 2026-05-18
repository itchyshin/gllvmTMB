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
