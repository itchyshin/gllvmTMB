# After-Task: Tier-2 reference article salvage audit (PR #37 queue item #2)

## Goal

Produce the audit doc that PR #37's dispatch queue item #2 names:
a verdict per legacy `gllvmTMB-legacy/vignettes/articles/`
candidate article, sorted into "port to Tier-2", "port to
internal `docs/`", or "leave archived." The audit is the
next-Codex-dispatch input for after the in-flight sweep (PR #39)
and the phylo doc-validation lane (item #1) settle.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-12-tier2-article-salvage-audit.md`**
  (NEW). Sections:
  - Methodology (legacy candidates minus already-current minus
    item-#1 minus already-archived = 15 candidates).
  - Dispatch queue: ten Tier-2 port candidates ranked by
    leverage (api-keyword-grid #1, response-families #2,
    ordinal-probit #3, mixed-response #4, profile-likelihood-ci
    #5, lambda-constraint #6 conditional, psychometrics-irt #7,
    behavioural-personality-with-year #8, three-level-personality
    #9, phylo-spatial-meta-analysis #10).
  - One internal-docs port (`tests.Rmd` -> `docs/design/`).
  - Three archived (`spde-vs-glmmTMB`, `random-slopes-personality-plasticity`,
    `corvidae-two-stage`).
  - Implementation reminders (long+wide framing, S/s notation,
    sugar-permitting wide RHS).
  - Shannon checklist with one open drift note (PR #39 scope
    expansion; revert in flight).
- **`docs/dev-log/after-task/2026-05-12-tier2-article-salvage-audit.md`**
  (NEW, this file).

The audit does NOT:
- Start any article port (each port is a separate Codex PR after
  item #1 lands).
- Modify any source / R / NAMESPACE / Rd / vignette / pkgdown
  navigation.
- Pre-judge the maintainer's call on PR #39's scope expansion
  (the queue's "sugar caveat" notes accommodate either outcome).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-12-tier2-article-salvage-audit.md`
  (new)
- `docs/dev-log/after-task/2026-05-12-tier2-article-salvage-audit.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open PRs (#39 Codex sweep, #40 Claude
  naming convention). Neither touches `docs/dev-log/shannon-audits/`.
  Safe.
- Legacy article enumeration:
  ```sh
  ls /Users/z3437171/Dropbox/Github\ Local/gllvmTMB-legacy/vignettes/articles/
  ```
  returned 29 `.Rmd` candidates. After subtracting the 7
  already-in-current articles, the 3 item-#1 phylo articles,
  and the 4 PR #38-archived articles, **15 remained**. All 15
  appear in the queue or the archive section above.
- Title scan via `head -10 <file>.Rmd | grep title:` confirmed
  each article's framing matched its title in the verdict.

## Tests Of The Tests

No new behavioural test. The implicit "test" of the audit is
whether the dispatch queue order matches user-leverage when
Codex starts porting:

- if `api-keyword-grid.Rmd` (queue position 1) lands first and
  shows real user uptake (issues / questions / discussions
  referencing it), the priority order is validated;
- if `psychometrics-irt.Rmd` (queue position 7) lands much
  later and is the article most users reference, the priority
  order was wrong and the audit can be amended.

The audit is rebuttal-friendly: each verdict has a stated
rationale and a "port notes" sub-bullet, so when Codex
disagrees during the actual port (because Boole / Gauss / Pat /
Darwin review surfaces an issue), the disagreement is
specific.

## Consistency Audit

```sh
rg -n "api-keyword-grid|response-families|ordinal-probit|mixed-response|profile-likelihood-ci|lambda-constraint" docs/dev-log/decisions.md docs/dev-log/shannon-audits/
```

verdict: the six Codex-flagged Tier-2 candidates from the legacy
excavation map (PR #35 comment) all appear in this audit's
queue; positions 1-6 of the dispatch queue match Codex's flag
list. Consistent.

```sh
rg -n "lambda_constraint|suggest_lambda_constraint" R/
```

verdict (not run inline; placeholder for the port PR): the
audit's "lambda_constraint API match" check is deferred to the
porting PR. The current `R/` contains `R/lambda-constraint.R`
and `R/suggest-lambda-constraint.R`, so the file-level support
is present; whether the API matches the legacy article's calls
is for Boole + Gauss to verify at port time.

```sh
rg -n "random_slope|phylo_slope" R/
```

verdict (not run inline; the audit verdict is "leave archived
until feature lands"): the current `R/phylo-slope.R` has a
keyword definition, but the user-facing random-slope grammar
is not yet wired in (per `README.md` "Current boundaries").
When that wires up, `random-slopes-personality-plasticity.Rmd`
re-enters the queue.

## What Did Not Go Smoothly

Nothing significant. The audit took ~30 minutes of legacy-repo
scan + verdict assignment. Codex's prior "adapt next" list (PR
#35 comment) accelerated the work substantially -- 6 of the 10
Tier-2 ports were already named there; this audit adds the
remaining 4, the internal-docs port, and the 3 archive entries.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Shannon (cross-team coordination)** -- this audit is the
  "Claude proposes / Codex implements" pattern at full
  expression: Codex's legacy excavation produced the source
  evidence; Claude translates into a sequenced queue with
  verdicts; the maintainer ratifies (or amends) the queue; Codex
  implements one PR per row. Four roles, four artefacts, all
  durable.
- **Ada (orchestrator)** -- pre-staging this audit while PR #39
  is still in flight respects the user's "you have a lot of
  work to do" instruction from earlier today and the project's
  "parallel where lanes are disjoint" rule. The audit doc lives
  in a Codex-free directory (`docs/dev-log/shannon-audits/`);
  no risk of collision.
- **Pat (applied user)** -- the queue order is leverage-based:
  the 3 x 5 keyword grid (#1) and 15-family compendium (#2) are
  the highest-traffic Tier-2 references; the niche applied
  demos (#7-#9) come later.
- **Darwin (ecology/evolution audience)** -- behavioural
  designs (#8, #9) and the future phylo-spatial-meta article
  (#10) are the biology audience hooks; queued but not at the
  top so the syntax / family / CI references land first.
- **Rose (cross-file consistency)** -- the audit confirms each
  Tier-2 port will use S/s math notation (per PR #40 naming
  convention) and the PR #14 long+wide pattern. No drift between
  this audit and the other in-flight scope records.

## Known Limitations

- The audit verdicts are advisory. Each port PR re-verifies
  whether the legacy article's API actually matches current
  code; Boole / Gauss can override a verdict at port time if
  the underlying code path has changed.
- The lambda-constraint verdict (#6) is conditional pending
  a quick API check; the audit assumes the file-level support
  is present (it is) but the API surface may have drifted.
- The order in positions 7-9 is a judgement call; if the
  maintainer's methods paper or downstream user feedback
  reprioritises (e.g., a psychometrics user lands and asks for
  the IRT article), the order can be amended.
- The audit does NOT cover the legacy `inst/extdata/` data
  files or `dev/` design notes -- those are scope for a future
  audit if Codex's port of an article needs a data shim or a
  legacy design-doc translation. The current scope is articles
  only.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: read-only
   audit + after-task in `docs/dev-log/`.
2. After PR #39 + #40 land, the maintainer dispatches Codex to
   item #1 (phylo / two-U doc-validation, from PR #37 queue).
3. After item #1 lands, the maintainer dispatches Codex to this
   audit's Tier-2 queue starting with `api-keyword-grid.Rmd`.
4. Each port PR follows the per-port discipline named in the
   "Implementation reminders" section: long+wide framing, S/s
   notation, after-task at branch start, Rose pre-publish gate.
