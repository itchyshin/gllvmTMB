# After-Task: Pat/Rose reference-index audit

## Goal

Maintainer flagged 2026-05-13 ~08:15 MT four issues on the
live pkgdown reference index
(<https://itchyshin.github.io/gllvmTMB/reference/index.html>):

1. `compare_indep_vs_two_U` description says "two-U
   decomposition" -- legacy U notation drift.
2. `suggest_lambda_constraint()` and related galamm-derived
   functions are very useful -- can we revisit?
3. IRT article context -- can we revisit; if IRT fits SDM, can
   we build on it?
4. Reference section needs cleaning up.

Produce a Pat/Rose audit covering all four, with concrete fix
proposals per finding.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-13-pat-rose-reference-index-audit.md`**
  (NEW): the audit doc. Sections:
  - **A**: "two-U decomposition" wording drift -- 7 R/ source
    hits + 3 autogen Rd hits with the canonical replacement
    phrasing ("paired phylogenetic decomposition").
  - **B**: reference index grouping issues -- `sanity_multi`
    miscategorised under "S3 methods"; "Diagnostics and
    loading-tools" mixes two reader-questions; `gllvmTMB_wide`
    still listed in "Top-level entry points" post-PR #65
    soft-deprecation.
  - **C**: galamm-derived loading-tools context
    (`rotate_loadings`, `compare_loadings`,
    `suggest_lambda_constraint`); recommendation to write the
    missing `lambda-constraint` Tier-2 article (resolves 4
    broken inter-article links).
  - **D**: IRT article + joint-SDM connection -- shows the
    structural isomorphism between IRT and binary GLLVM;
    proposes a single Tier-2 `psychometrics-irt` article that
    reframes the same fit for both audiences.
  - **E**: priority-ordered recommendations (2 mechanical fixes
    Claude can do during the Codex pause; 2 article writes for
    maintainer scope decision).
- **`docs/dev-log/after-task/2026-05-13-pat-rose-reference-index-audit.md`**
  (NEW, this file).

The PR does NOT apply any fix. It is a Pat/Rose audit; the
implementation PRs (reference-index grouping + two-U description
fix) come after maintainer ratifies the audit.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-13-pat-rose-reference-index-audit.md`
  (new)
- `docs/dev-log/after-task/2026-05-13-pat-rose-reference-index-audit.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 1 open Claude PR (#70 Codex-pause
  coord-board). #70 does not touch `docs/dev-log/shannon-audits/`
  or `docs/dev-log/after-task/`. Safe.
- `rg -n 'two-U decomposition' R/ man/` -- found 7 R/ source
  hits + 3 autogen Rd hits. Catalogued in Section A.
- `_pkgdown.yml` read top-to-bottom; 8 reference groups
  identified. Issues catalogued in Section B.
- `R/rotate-loadings.R`, `R/suggest-lambda-constraint.R`
  inspected for galamm-style loading-tools (Section C).
- Article inventory: 10 articles on `origin/main` (8 Tier-1 +
  3 Tier-2 with the recent ordinal-probit). `psychometrics-irt`
  and `lambda-constraint` are on Codex's Tier-2 queue per PR
  #41 but not yet ported.

## Tests Of The Tests

This is a Phase 5 prep audit. The "tests" are:

1. If the maintainer ratifies the audit's Section A wording, a
   follow-up R/ roxygen + `devtools::document()` PR replaces
   "two-U decomposition" with "paired phylogenetic
   decomposition" at the 7 source hits. The 3 autogen Rd files
   regenerate accordingly.
2. If Section B's reference grouping fix is ratified, a
   `_pkgdown.yml` edit moves `sanity_multi` to the Diagnostics
   group, splits "Diagnostics and loading-tools" into two
   groups, and drops `gllvmTMB_wide` from "Top-level entry
   points".
3. Section C's lambda-constraint article and Section D's IRT
   article are larger Codex-lane writes; the audit names them
   as missing-article opportunities and waits for maintainer's
   scope call.

## Consistency Audit

```sh
rg -n 'two-U decomposition' R/ man/ 2>&1
```

verdict: 7 R/ hits + 3 Rd hits. All catalogued in Section A
with the proposed replacement.

```sh
rg -n 'sanity_multi\b' R/ _pkgdown.yml
```

verdict: `sanity_multi` is defined in `R/methods-gllvmTMB.R`
(not in a methods-S3 file); referenced in `_pkgdown.yml`
reference group "S3 methods on gllvmTMB_multi fits" (Section
B1 mismatch).

```sh
rg -n 'gllvmTMB_wide' _pkgdown.yml
```

verdict: 1 hit, in "Top-level entry points" group. Should
move to a "Deprecated" group or be dropped (Section B3).

## What Did Not Go Smoothly

Nothing substantive. The audit was bounded by the maintainer's
4 questions; each got its own section with concrete fix
proposals. The hardest decision was the canonical replacement
phrasing for "two-U decomposition": I chose "paired
phylogenetic decomposition" because it (a) matches the post-PR
#53 `phylogenetic-gllvm.Rmd` framing, (b) does not introduce a
new term ("two-S decomposition" reads as a direct rename and
obscures meaning), and (c) is consistent with the
single-component vs paired-decomposition distinction.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- the maintainer's question 1 ("two-U
  should be S") is exactly Pat's lane: prose that uses an
  obsolete notation. The audit catalogues all 7 hits so a
  single Codex (or Claude during pause) PR resolves the drift
  in one pass.
- **Rose (cross-file consistency)** -- the reference grouping
  issues (Section B) are Rose's lane: 8 reference groups with
  3 mismatches (sanity_multi, split-the-group, deprecated
  gllvmTMB_wide).
- **Ada (orchestrator)** -- the audit deliberately does NOT
  apply fixes. Each fix has a distinct shape; maintainer rules
  before implementation.
- **Shannon (coordination)** -- with Codex on pause, the
  reference-index fix lands in Claude's lane. The audit names
  this explicitly so the maintainer can defer or accept.

## Known Limitations

- The audit reads on-disk source + the rendered reference index
  via the maintainer's screenshot. It does not re-render the
  pkgdown site to verify the screenshot's groupings match the
  current `_pkgdown.yml`.
- The "two-U decomposition" replacement phrasing ("paired
  phylogenetic decomposition") is my proposal, not a ratified
  convention. The maintainer can override with a different
  phrasing; the audit's catalog of locations stays valid
  either way.
- The lambda-constraint and IRT articles are Codex-lane
  writes; the audit names them but does not assume Claude
  picks them up during the pause window.

## Next Actions

1. Maintainer reviews / merges the audit. Self-merge eligible:
   audit doc + after-task report under `docs/dev-log/`, no
   source change.
2. Maintainer rules on the "paired phylogenetic decomposition"
   canonical phrasing (or chooses a different one).
3. If ratified, Claude opens a small R/ roxygen + Rd
   regeneration PR fixing the 7 source hits during the Codex
   pause window. Single focused PR.
4. Claude proceeds with the previously-queued navbar PR + the
   reference-grouping fix (Section B) as a bundled
   `_pkgdown.yml` PR after the maintainer ratifies Section B.
5. Lambda-constraint + IRT articles wait for Codex's return
   (~May 17) or maintainer dispatch.
