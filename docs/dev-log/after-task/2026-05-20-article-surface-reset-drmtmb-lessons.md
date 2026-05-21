# After-task: article surface reset and drmTMB lessons sweep

**Date:** 2026-05-20
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230 created; #228 inspected and left open.

## 1. Goal

Stop the broad article-publication loop, hide pages that are not ready enough
for users, and write a plan for making gllvmTMB as careful as drmTMB while
remaining excellent in its own multivariate GLLVM domain.

## 2. Implemented

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
or model parameterisation changed.

The visible pkgdown article dropdown now keeps only a minimal `Core examples`
group and moves draft, technical, validation-dependent, and infrastructure-
blocked pages into a hidden `Under audit` group. The article source files stay
on disk.

Two planning reports were added:

- `docs/dev-log/audits/2026-05-20-article-surface-reset.md`
- `docs/dev-log/audits/2026-05-20-drmtmb-lessons-for-gllvmtmb.md`

`ROADMAP.md` now reopens Phase 1d as an article-surface reset and
infrastructure-first tooling gate.

## 3. Files Changed

- `_pkgdown.yml`: minimal visible article group plus hidden under-audit group.
- `ROADMAP.md`: reset rationale, next small step, Phase 1d rewrite, and #230
  cross-reference.
- `docs/dev-log/audits/2026-05-20-article-surface-reset.md`: article inventory,
  classifications, rendered-HTML review protocol, readiness map, and roadmap
  rewrite shape.
- `docs/dev-log/audits/2026-05-20-drmtmb-lessons-for-gllvmtmb.md`: drmTMB
  comparative sweep, borrow/adapt/surpass plan, and user-first tooling plan.
- `docs/dev-log/check-log.md`: this task log entry.
- `docs/dev-log/team-improvements.md`: durable process lessons for long/wide
  article gates, HTML review, infrastructure-first examples, and drmTMB
  operating-system borrowing.
- `docs/dev-log/after-task/2026-05-20-article-surface-reset-drmtmb-lessons.md`:
  this after-task report.

## 3a. Decisions and Rejected Alternatives

Decision: hide weak pages instead of deleting them. This preserves source
history and cross-reference repair paths while preventing the public site from
presenting drafts as equal to polished examples.

Decision: copy drmTMB's operating system, not its article count. gllvmTMB needs
stricter gates because long/wide data shapes, latent covariance, rotation,
truth recovery, and figure interpretation create more opportunities to
overclaim.

Rejected alternative: continue polishing many articles in parallel. The user
explicitly asked to slow down, plan first, and reveal pages only after rendered
HTML review.

## 4. Checks Run

- `git status --short --branch`
  -> branch `codex/article-audit-2026-05-20`; changed files matched the reset
  scope.
- `gh pr list --repo itchyshin/gllvmTMB --state open --limit 20`
  -> no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate --max-count=20`
  -> no collision with an open PR; recent #228 work is parked on its own
  checkpoint branch.
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> passed: `No problems found.`
- `gh issue list --repo itchyshin/gllvmTMB --state open --limit 40`
  -> only #228 was open before #230 was created.
- `gh issue view 228 --repo itchyshin/gllvmTMB --json number,title,state,labels,updatedAt,url`
  -> #228 remains open.
- `gh issue view 230 --repo itchyshin/gllvmTMB --json number,title,state,labels,updatedAt,url`
  -> #230 is open with `documentation` and `enhancement`.

## 5. Tests of the Tests

No code or tests changed. This task is a documentation, navigation, roadmap,
and planning reset. The relevant verification was `pkgdown::check_pkgdown()`,
which catches broken pkgdown navigation configuration but does not prove that
individual article examples are scientifically ready.

## 6. Consistency Audit

Exact scans:

```sh
rg -n "gllvmTMB\\(|traits\\(|gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|in prep|in preparation|\\bS_B\\b|\\bS_W\\b|\\\\bf S" ROADMAP.md docs/dev-log/audits/2026-05-20-article-surface-reset.md docs/dev-log/audits/2026-05-20-drmtmb-lessons-for-gllvmtmb.md _pkgdown.yml
```

Verdict: new hits are intentional long/wide formula and `check_gllvmTMB()`
planning mentions. Existing ROADMAP historical `in prep`, `gllvmTMB_wide()`,
and `meta_known_V` mentions remain known roadmap/reference inventory and were
not introduced by this reset.

```sh
rg -n "articles/(animal-model|behavioural-syndromes|joint-sdm|phylogenetic-gllvm|functional-biogeography|psychometrics-irt|simulation-recovery-validated|cross-package-validation|choose-your-model|data-shape-flowchart)" README.md vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/pitfalls.Rmd
```

Verdict at the planning checkpoint: README still linked to hidden
`choose-your-model` and `joint-sdm`. This was fixed in the follow-up
implementation slice recorded in
`docs/dev-log/after-task/2026-05-20-public-surface-reset-implementation.md`.

## 7. Roadmap Tick

Phase 1d changed from `Navbar restructure` partly done `█░` 1/2 to
`Article surface reset + roadmap rewrite` reopened `█░░░` 1/4.

## 8. What Did Not Go Smoothly

The first `gh issue create` attempt failed because zsh parsed example formula
text inside command substitution and glob syntax. The issue body was rerun via
stdin; no repository file changed during the failed attempt.

The planning checkpoint initially left README links to hidden pages. The
follow-up implementation slice cleaned the landing page and removed those
routes.

## 9. Team Learning

Ada: Keep article count subordinate to user readiness. The right next move is
not another article; it is the tool chain that makes articles honest.

Pat: A first-time applied user needs one biological question, one model, one
long/wide pair, and one interpretation path. Broad tours are confusing until
the infrastructure is stable.

Darwin: Examples need biological worlds, not arbitrary simulated matrices.
Scenario helpers should speak in traits, species, sites, relatedness, and
environmental gradients.

Florence: Figure-heavy pages must wait for plotting helpers and rendered
figure review. Latent covariance figures can mislead quickly if estimand,
scale, uncertainty, and missing support are not explicit.

Fisher: `pdHess = FALSE` and failed standard errors are uncertainty warnings,
not automatic model death. Public examples must separate point-estimate
interpretation from uncertainty claims.

Grace: `pkgdown::check_pkgdown()` passes the hidden-article navigation, but it
does not inspect rendered article quality. HTML review remains a human gate.

Rose: The repeated failure was process-level: article generation outran
validation and review. Issue #230, the audit files, and this after-task report
make that failure visible instead of leaving it in chat.

Jason: drmTMB's strongest transferable asset is not a specific article. It is
the system: reader-intent navigation, tutorial contract, inventory, readiness
matrix, figure gate, issue ledger, and team-improvement memory.

## 10. Known Limitations and Next Actions

- No article HTML was rendered or shown to the maintainer in this planning
  checkpoint. The follow-up implementation slice rendered the homepage, Get
  Started, visible articles, and roadmap locally; maintainer visual review is
  still pending.
- No article examples were rewritten in this planning checkpoint; the follow-up
  implementation slice applied first-pass safety fixes to the visible pages.
- No site upload, PR, push, or article reveal happened.
- README/home hidden-page routing was cleaned in the follow-up implementation
  slice under #230.
- The Get Started page still needs HTML review.
- #228 diagnostics remain parked until the article/tooling surface has a clear
  public home.

Next actions under #230:

1. Clean the landing page links and status matrix.
2. Turn the article inventory into the maintained source of truth.
3. Define the scenario simulation helper return contract.
4. Start with the safest model surface: morphometrics, rendered HTML review,
   and long/wide equivalence shown explicitly.
5. Split child issues for simulation helpers, extraction tables, plotting
   infrastructure, and diagnostics only when those slices are ready to start.
