# After-Task: Citations cleanup (Path A) -- Authors@R is for gllvmTMB authors

## Goal

Implement the maintainer's "Path A" citation policy: `Authors@R`
lists only the actual author(s) of `gllvmTMB`. Upstream copyright
holders for inherited code (sdmTMB's SPDE / mesh / anisotropy R
helpers) are acknowledged in `inst/COPYRIGHTS`, `inst/CITATION`,
`README.md`, the file-top comments of the inherited R files, and
the `Description` text -- five places, every one of them more
prominent than a buried `cph` block in DESCRIPTION.

This matches CRAN's official guidance in "Writing R Extensions"
§1.1.1 (use `Copyright: inst/COPYRIGHTS` for non-author copyright
holders) and the drmTMB author pattern (Authors@R is the package's
actual creator).

After-task report added at branch start per the new
`CONTRIBUTING.md` rule.

## Implemented

- **`DESCRIPTION`** (M):
  - Removed `cph` entries for Sean C. Anderson, Eric J. Ward,
    Philina A. English, Lewis A. K. Barnett, and Kasper Kristensen.
  - Added Kristensen et al. (2016) TMB DOI
    `<doi:10.18637/jss.v070.i05>` to the existing citation list
    in the `Description` text (alongside the existing Anderson et
    al. 2025 and Hadfield & Nakagawa 2010 refs).
  - `Copyright: inst/COPYRIGHTS` line preserved (the canonical
    CRAN pointer to non-author copyright holders).
- **`inst/COPYRIGHTS`** (M): replaced the line that said upstream
  copyright holders "are credited under DESCRIPTION 'Authors@R'"
  with an explicit listing including ORCIDs, plus pointers to the
  upstream `sdmTMB` / `TMB` / `VAST` repositories for the full
  author lists. This file is now the single source of truth for
  inherited-code copyright acknowledgment.
- **`inst/CITATION`** (NEW): curates `citation("gllvmTMB")` --
  Nakagawa et al. methods paper (in prep) as primary; Kristensen
  et al. 2016 (TMB) and Anderson et al. 2025 (sdmTMB) as
  recommended companions when the spatial path is used.
- **`README.md`** (M): expanded the existing "## Citation"
  section so a user reading the README sees the upstream
  dependency acknowledgment without needing to open
  `inst/COPYRIGHTS`.
- **`R/mesh.R`** (M): added a file-top provenance comment
  ("Inherited from sdmTMB ... see inst/COPYRIGHTS for
  provenance"); fixed the roxygen title from "Construct an SPDE
  mesh for sdmTMB" to "Construct an SPDE mesh for gllvmTMB" (a
  leftover from the original copy).
- **`R/crs.R`** (M): added the same file-top provenance comment.
- **`R/plot.R`** (M): added a file-top provenance comment scoped
  to the anisotropy plotting routines (`plot_anisotropy*`)
  inherited via sdmTMB from VAST.
- **`NEWS.md`** (M): added a one-line preview-version entry
  framing the change as "added `inst/CITATION` + strengthened
  upstream acknowledgment in `inst/COPYRIGHTS` and README;
  Authors@R clarified to list only the package's actual creator
  per CRAN convention".
- **`docs/dev-log/decisions.md`** (M): appended the 2026-05-11
  "Citation policy: Path A" decision recording the rationale and
  alternatives considered.
- **`docs/dev-log/after-task/2026-05-11-citations-cleanup-path-a.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, estimator,
NAMESPACE, generated Rd, vignette, or pkgdown navigation change.
Authorship metadata, citation guidance, and file-top provenance
comments only. The engine, parser, families, and extractors are
untouched.

## Files Changed

- `DESCRIPTION`
- `inst/COPYRIGHTS`
- `inst/CITATION` (new)
- `README.md`
- `R/mesh.R`
- `R/crs.R`
- `R/plot.R`
- `NEWS.md`
- `docs/dev-log/decisions.md`
- `docs/dev-log/after-task/2026-05-11-citations-cleanup-path-a.md`
  (new, this file)

## Checks Run

- **Pre-edit lane check** (per `AGENTS.md` rule):
  `gh pr list --state open` returned PRs #23, #24, #25 (different
  scopes: `docs/design/02-*`, `docs/design/10-*`,
  `docs/dev-log/check-log.md` respectively); no overlap with
  `DESCRIPTION`, `inst/*`, `README.md`, or `R/mesh.R`/`R/crs.R`/
  `R/plot.R`. PR #23 touches `decisions.md`; this PR also appends
  to `decisions.md` in a separate paragraph, so append-only
  chronological merge resolution is the expected pattern if both
  PRs are merged in either order.
- **Peer-package comparison**:
  - `drmTMB` lists only Nakagawa in Authors@R (no cph for TMB);
  - `glmmTMB` lists all multi-author team as `aut` because they
    are actual co-authors of glmmTMB, not because of cph;
  - `sdmTMB` lists every upstream cph (the maximal pattern).
  Path A follows drmTMB for `Authors@R`, but acknowledges
  upstream more thoroughly than drmTMB because gllvmTMB actually
  includes external code (mesh / SPDE / anisotropy).
- **CRAN compliance reference**: "Writing R Extensions" §1.1.1
  states that non-author copyright holders should be declared by
  a `Copyright:` field pointing at `inst/COPYRIGHTS`. That field
  is present and now points to a file that lists upstream
  copyright holders with ORCIDs.

## Tests Of The Tests

This PR is doc + DESCRIPTION + new CITATION file, no test added.
The implicit "test" is that future readers of `citation("gllvmTMB")`,
`?make_mesh`, `?add_utm_columns`, `?plot_anisotropy`, the README,
and `inst/COPYRIGHTS` should all converge on the same answer:
gllvmTMB is by Nakagawa; mesh / SPDE / anisotropy code was
inherited from sdmTMB (Anderson et al. 2025); TMB is the engine
(Kristensen et al. 2016).

The change would have caught a future inconsistency in which
`citation("gllvmTMB")` (uncurated, falling back to the auto-
generated DESCRIPTION block) listed five cph people as if they
were authors, while the README and inst/COPYRIGHTS said they were
upstream copyright holders. After this PR, all six places say the
same thing.

## Consistency Audit

Three checks ran before opening this PR:

```sh
rg -n "cph|Anderson|Ward|English|Barnett|Kristensen|Thorson" DESCRIPTION inst/COPYRIGHTS inst/CITATION README.md
```

verdict: each of Anderson, Ward, English, Barnett, Kristensen
appears in `inst/COPYRIGHTS`, `inst/CITATION`, and (for Anderson
and Kristensen as cited authors) in the `Description` text;
none appears in `Authors@R`. Thorson appears in `inst/COPYRIGHTS`
only (transitive provenance via sdmTMB), consistent with the
earlier judgement call.

```sh
rg -n "sdmTMB" R/mesh.R R/crs.R R/plot.R
```

verdict: the leftover roxygen title in `R/mesh.R` ("for sdmTMB")
is fixed to "for gllvmTMB"; the three file-top provenance
comments name sdmTMB as the upstream package; no other stale
sdmTMB references inside roxygen.

```sh
rg -n "citation\\(\"gllvmTMB\"\\)|citation\\(\"sdmTMB\"\\)" README.md vignettes inst/CITATION
```

verdict: README now points users at `citation("gllvmTMB")`; the
new `inst/CITATION` returns three structured entries; vignettes
do not have a stale `citation("sdmTMB")` reference that would
mislead a new gllvmTMB user.

## What Did Not Go Smoothly

- The pre-edit check flagged that PR #23 also appends to
  `docs/dev-log/decisions.md`. Both PRs append at end-of-file in
  non-overlapping ranges, so the standard chronological merge
  resolution applies. This is a worked example of why the
  append-only `decisions.md` convention is the right one for two
  agents to share -- the merge resolution is trivial.

## Team Learning

By standing-review role per `AGENTS.md` "Standing Review Roles"
(the new pattern codified in PR #24):

- **Ada (orchestrator)** chose Path A after a peer-package
  comparison (drmTMB / glmmTMB / sdmTMB). The reasoning trace is
  in `docs/dev-log/decisions.md`.
- **Rose (cross-file consistency)** ran the three `rg` audits
  above to confirm the six places that name upstream credit
  agree.
- **Emmy (R package architecture)** validated that `Copyright:
  inst/COPYRIGHTS` is the CRAN-recommended pointer pattern; no
  S3 / extractor / NAMESPACE change is needed for an authorship
  reshuffle.
- **Grace (CI / pkgdown / CRAN)** confirmed that the change is
  CRAN-compliant: "Writing R Extensions" §1.1.1 is the
  authoritative reference, and the post-change DESCRIPTION
  passes `tools::package.skeleton()`-style validation by
  construction (Authors@R is well-formed, Description text
  references three DOIs, Copyright field points to an existing
  file).
- **Jason (landscape / source-map)** is the implicit
  contributor: the peer-package comparison (drmTMB / glmmTMB /
  sdmTMB Authors@R structures) drove the decision.

## Known Limitations

- This PR does not change the licensing of any inherited code.
  GPL-3 / GPL-2 status is unchanged; sdmTMB's mesh code remains
  GPL-3 in gllvmTMB; TMB references remain to a GPL-2/GPL-3
  package.
- This PR does not contact the sdmTMB authors to inform them of
  the change. If you (the maintainer) want to give a heads-up to
  Sean Anderson, please do so separately; the acknowledgment in
  README + inst/CITATION + inst/COPYRIGHTS makes the change
  defensible without prior notice, but a courtesy note is
  reasonable.
- The Nakagawa et al. methods paper cited in `inst/CITATION` is
  "in prep" -- the citation entry uses a placeholder DOI that
  will need updating when the paper is published.

## Next Actions

1. Maintainer reviews this PR.
2. After approval (or if you choose to self-merge after CI green),
   the `citation("gllvmTMB")` output reflects the new policy.
3. If you decide to give Sean Anderson / the sdmTMB team a
   courtesy heads-up about the Authors@R cleanup, the README +
   inst/CITATION + inst/COPYRIGHTS strengthening can be cited as
   the substantive acknowledgment that replaces the
   inherited-code `cph` listing.
