# After-Task: Pat applied-user audit (Tier-1 + Tier-2 articles)

## Goal

Pat-role pre-publish sweep of all 11 Tier-1 + Tier-2 articles on
`origin/main`, focused on:

1. Inter-article link integrity (does each `see also` link
   resolve to an article that actually exists?).
2. Wide-format framing in the user's first decision-tree
   stop (`choose-your-model`).
3. Phylogeny advice alignment with the canonical 4-component
   decomposition (per PR #53 rewrite).
4. Any other friction a new applied user would hit on day 1.

Maintainer dispatched this audit 2026-05-13 03:30 MT, pointing at
the live pkgdown URL <https://itchyshin.github.io/gllvmTMB/articles/choose-your-model.html>
as a starting point.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-13-pat-applied-user-audit.md`**
  (NEW): the audit doc. Three substantive friction findings on
  `choose-your-model.Rmd` (F1 wide-format framing, F2 phylogeny
  undersold, F3 heuristic ladder figure), plus the headline
  finding of 6 broken inter-article links across 7 articles.
- **`docs/dev-log/after-task/2026-05-13-pat-applied-user-audit.md`**
  (NEW, this file).

The PR does NOT:

- Apply any of the proposed fixes. The audit is a Phase 5 prep
  document with concrete `Recommended remediation` per finding;
  the actual rewrites belong in follow-up PRs (Codex for the
  article writes; Claude or Codex for the smaller mechanical
  fixes).
- Touch `covariance-correlation.Rmd`. Codex is doing a
  substantive revision of that article (maintainer dispatch
  2026-05-13 03:30 MT); audit deferred pending Codex's PR.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. One new
audit doc + one after-task report under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-13-pat-applied-user-audit.md`
  (new)
- `docs/dev-log/after-task/2026-05-13-pat-applied-user-audit.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 3 open Claude PRs (#55 Rose sweep
  reduced, #59 see-also pointer, #60 legacy-repo removal) +
  open Codex covariance-correlation revision (not yet on
  remote). None touches `docs/dev-log/`. Safe.
- Inter-article link sweep:

  ```sh
  grep -rEoh '\]\(([a-z][a-z0-9-]+)\.html\)' vignettes/articles/
  ```

  Cross-checked the 15 distinct targets against
  `ls vignettes/articles/`. 6 targets missing:
  `corvidae-two-stage`, `cross-package-validation`,
  `lambda-constraint`, `profile-likelihood-ci`,
  `simulation-recovery`, `spde-vs-glmmTMB`. Cataloged the
  source articles for each.
- API-call spot-check: `extract_correlations(tier = "unit")`,
  `extract_ordination(level = "unit")` use canonical argument
  names; `extract_communality(fit, "B")` / `"W"` legacy
  aliases counted (already in PR #55 scope).
- Phylogeny advice cross-check: compared `choose-your-model`
  Section 3 + 6c against the post-PR #53 canonical phylo
  decomposition in `phylogenetic-gllvm.Rmd`. Mismatch
  identified (F2 in audit doc).

## Tests Of The Tests

This is a Phase 5 prep audit. The "test" is whether a new applied
user reading the live pkgdown site can:

1. Click "see also: X" without hitting a 404. (Currently fails
   for 6 link targets across 7 articles.)
2. Read `choose-your-model` Section 1 and understand that they
   can pass wide data directly. (Currently fails; only
   long-format is mentioned.)
3. Read `choose-your-model` Section 3 + 6c, fit the
   recommended model, and have `extract_phylo_signal()` return
   a meaningful three-way decomposition. (Currently fails; the
   3-component fit produces a structurally-zero `C^2_non`.)

After remediation (per the audit doc's Recommended remediation
section), each of these tests should pass.

## Consistency Audit

```sh
grep -rEoh '\]\(([a-z][a-z0-9-]+)\.html\)' vignettes/articles/ \
  | sort -u
```

verdict: 15 distinct internal article references; 6 resolve to
missing articles. The audit doc names each.

```sh
rg -n 'long-format|wide-format|traits\\(' \
   vignettes/articles/choose-your-model.Rmd
```

verdict: choose-your-model uses "long-format" prose without
mentioning `traits(...)` LHS or `gllvmTMB_wide()`. Stale framing
caught in audit F1.

```sh
rg -n 'phylo_latent|phylo_unique|phylo_scalar' \
   vignettes/articles/choose-your-model.Rmd
```

verdict: choose-your-model recommends `phylo_scalar` and
`phylo_latent` but does not mention `phylo_unique` or the
canonical paired `phylo_latent + phylo_unique` decomposition.
Stale advice caught in audit F2.

## What Did Not Go Smoothly

Nothing substantive. The audit was bounded by design: pre-publish
sweep of all 11 articles for Pat-level friction, with concrete
fix recommendations per finding.

The hardest decision was scope: the audit could go deeper into
each article (every code chunk, every prose claim) or stay at
the Pat-level "would a new user be stuck?" depth. I chose the
Pat-level depth because the deeper audit is more naturally
post-Codex-rewrite (covariance-correlation in flight; Tier-2
queue ongoing); a deeper audit now would partially re-do work
that's about to land.

The audit also deliberately did not assign per-link fix shapes
(WRITE vs REMOVE vs DEFER) for 4 of the 6 broken targets.
Those are scope decisions the maintainer should rule on.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- this is exactly Pat's lane: a fresh
  applied user reads the live pkgdown site and gets stuck. The
  audit is the artefact of Pat walking through the articles
  cold.
- **Rose (cross-file consistency)** -- the broken-link finding
  is cross-file consistency at the article level; 6 link
  targets that promise content not delivered.
- **Ada (orchestrator)** -- the audit deliberately stops short
  of applying fixes. The maintainer rules on the
  WRITE-vs-REMOVE-vs-DEFER decision for each missing article;
  the audit provides the inputs to that decision.
- **Shannon (coordination)** -- the audit does not collide with
  Codex's in-flight covariance-correlation revision. Pre-edit
  lane check confirmed.

## Known Limitations

- The audit covers Tier-1 + Tier-2 only. Tier-3 / experimental
  articles in any subdirectory are not in scope.
- The audit does not render each article locally; it reads the
  on-disk `.Rmd` source. The rendered pkgdown HTML might add
  or hide friction (e.g. table-of-contents anchors, syntax
  highlighting) that the source does not show.
- The audit does not verify that the proposed fixes actually
  resolve the friction; that requires applying the fixes and
  re-reading the rendered output, which is in scope for the
  follow-up implementation PRs.
- F2 (phylogeny advice) assumes the post-PR #53
  `phylogenetic-gllvm.Rmd` advice is the canonical form. If
  the maintainer wants a simpler "first pass" for
  `choose-your-model` Section 3 and a deeper version for the
  dedicated phylo article, the audit framing changes.

## Next Actions

1. Maintainer reviews / merges the audit. Self-merge eligible:
   single audit doc + after-task report under
   `docs/dev-log/`, no source / API / NAMESPACE change.
2. Maintainer makes the per-missing-link WRITE / REMOVE /
   DEFER decisions (4 of 6 are scope decisions).
3. Codex's Tier-2 queue (per PR #41) already covers
   `lambda-constraint` and `profile-likelihood-ci`. Those
   can land in their normal Codex queue cadence.
4. F1, F2, F3 (choose-your-model fixes) can be one bounded
   Codex PR or a Claude PR; the changes are small enough to
   pick the cheaper agent. Recommend Codex if F2 needs the
   simulation rerun for new bar heights in F3, otherwise
   Claude.
5. Once `covariance-correlation.Rmd` lands (Codex), the audit
   should be re-run on the post-Codex state; that article's
   audit row is currently deferred.
