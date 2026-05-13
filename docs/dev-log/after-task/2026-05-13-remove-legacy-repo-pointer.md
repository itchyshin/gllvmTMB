# After-Task: Remove user-facing legacy-repo pointer

## Goal

`README.md:58` linked to `https://github.com/itchyshin/gllvmTMB-legacy`,
which `urlchecker::url_check()` reports as 404 Not Found. The
legacy repo is private / does not exist at that path, and the
maintainer's decision (2026-05-13 03:45 MT) is to remove the
user-facing pointer entirely.

`NEWS.md` had a parallel "Relationship to the legacy 0.1.x line"
section that mentioned `itchyshin/gllvmTMB-legacy` by name. That
section is reworded to describe a "pre-0.2.0 development line"
without naming the (now-removed) repo URL.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`README.md`** (M, 4-line removal): drops the
  "The legacy repository at [...] preserves the 0.1.x history.
  The current package is a fresh, focused rebuild." paragraph
  that lived between "Preview status" and "Install" sections.
- **`NEWS.md`** (M, 4-line reword): the closing section
  "Relationship to the legacy 0.1.x line" is renamed to
  "Relationship to a pre-0.2.0 development line"; the
  `itchyshin/gllvmTMB-legacy` URL/repo name is dropped; the
  substantive content (re-exported a large surface from sdmTMB;
  exposed single-response paths; users wanting single-response
  models should install sdmTMB or glmmTMB directly) is
  preserved.
- **`docs/dev-log/after-task/2026-05-13-remove-legacy-repo-pointer.md`**
  (NEW, this file).

The PR does NOT:

- Touch durable-record mentions of `gllvmTMB-legacy` in
  `docs/dev-log/decisions.md` (the archive-scope ratification
  entry), `docs/design/04-sister-package-scope.md` (cross-
  reference to the archive decision), or
  `docs/dev-log/after-task/*` (historical reports). Those are
  internal historical records, not user-facing pointers, and
  remain accurate as a name reference.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two
documentation prose changes that remove a dead user-facing
link.

## Files Changed

- `README.md` (M, -4 lines)
- `NEWS.md` (M, -4 lines / +3 lines)
- `docs/dev-log/after-task/2026-05-13-remove-legacy-repo-pointer.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open Claude PRs (#55 Rose article-
  sweep, #59 AGENTS/CLAUDE see-also pointer). Neither touches
  README.md or NEWS.md. Safe.
- `urlchecker::url_check(".")` after the fix:
  - `README.md:58` 404 is gone (the pointer no longer exists
    in the file).
  - Remaining: only the transient
    `man/spde.Rd:158` DOI 403 (doi.org rate-limit; CRAN does
    not fail on DOI 403s; unchanged by this PR).
  - Zero remaining `urlchecker` actionable issues.
- Recursive sweep for `gllvmTMB-legacy` mentions
  (`rg -l 'itchyshin/gllvmTMB-legacy|gllvmTMB-legacy'`):
  - Eliminated from user-facing surface: `README.md`,
    `NEWS.md`.
  - Preserved in durable-record surface:
    `docs/dev-log/decisions.md` (archive-scope ratification),
    `docs/design/04-sister-package-scope.md` (cross-reference),
    `docs/dev-log/after-task/*` (historical reports),
    `docs/dev-log/shannon-audits/*` (audit references). These
    are name-only references, not URL pointers; correct as
    historical records.

## Tests Of The Tests

The "test" is whether `urlchecker::url_check()` no longer
reports the `README.md:58` 404. After this PR:

```
$ Rscript -e 'res <- urlchecker::url_check("."); print(res)'
# zero README 404 (was: ✖ Error: README.md:58:31 404: Not Found)
# only remaining: 1 DOI 403 (transient, doi.org rate-limit)
```

If the legacy repo is ever made public at the same URL or
republished elsewhere, the pointer can be re-added; the
text-block in the previous README version is preserved in
git history (`git show 18a54d6:README.md`).

## Consistency Audit

```sh
rg -n 'gllvmTMB-legacy' README.md NEWS.md
```

verdict: zero hits in either file after the change.

```sh
rg -l 'gllvmTMB-legacy' .
```

verdict: matches are confined to durable historical-record
files in `docs/dev-log/` and `docs/design/` (decisions,
after-task reports, archive-scope cross-references). No
user-facing surface still claims the URL.

## What Did Not Go Smoothly

Nothing. Two small text-block edits + one urlchecker
verification rerun.

The "Relationship to a pre-0.2.0 development line" rename in
NEWS.md was an interpretation choice: the original section
title said "Relationship to the legacy 0.1.x line", which is
true (there is a pre-0.2.0 development line, internally
versioned 0.1.x). Removing the repo URL did not require
removing the section; rewording the title to avoid the
"legacy" framing entirely matches the maintainer's intent
of removing user-facing pointers to the (now-gone) repo while
preserving the substantive content about scope vs the
pre-rewrite line.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user / CRAN reviewer)** -- a CRAN reviewer
  clicking the README's legacy-repo link would have hit
  the 404; removing the pointer prevents that friction.
- **Rose (cross-file consistency)** -- README and NEWS no
  longer reference the dead URL; durable-record files
  preserve the name as historical context.
- **Grace (release readiness)** -- this completes the
  `urlchecker` pre-flight cleanup from PR #57; the only
  remaining urlchecker finding is a transient DOI 403 that
  CRAN tolerates.
- **Ada (orchestrator)** -- bounded fix; no scope-rule
  change.

## Known Limitations

- If the team later decides to publish a public version of
  the legacy / pre-0.2.0 line under a different URL, the
  pointer can be re-added with a one-line README edit.
- The dev-log mentions of `gllvmTMB-legacy` remain accurate
  as a name reference; they are not user-facing. If those
  files are ever surfaced through some other channel (e.g.
  if a future pkgdown nav exposes `docs/dev-log/`), the
  name references would become user-facing and the question
  reopens.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: light-
   touch documentation removal of a dead user-facing pointer,
   no source / API / NAMESPACE change.
2. After merge, `urlchecker::url_check()` is clean for
   user-facing URLs (only a transient DOI 403 remains, which
   CRAN tolerates).
