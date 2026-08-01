# After-task report -- independent spatial helpers

## Task goal

Replace gllvmTMB's formerly inherited R-side spatial helper code with
independently authored mesh, CRS, and fit-specific range helpers. Remove the
sdmTMB code-provenance and required-citation debt while retaining a plain
courtesy acknowledgement. Preserve the existing native TMB spatial likelihood
and defer new spatial model capabilities.

## Mathematical contract

The TMB likelihood, formula grammar, response families, and covariance
parameterisation did not change. `make_mesh()` supplies the sparse observation
projection `A_st` and the finite-element matrices mapped as
`M0 = c0`, `M1 = g1`, and `M2 = g2` to the existing precision

\[
Q(\kappa) = \kappa^4 M_0 + 2\kappa^2 M_1 + M_2.
\]

The engine reports scalar `kappa`, not an anisotropy matrix. The plotting
contract therefore reports the isotropic practical range
`sqrt(8) / kappa`; `H = I` is a model assumption and
`anisotropy_estimated = FALSE`. This change does not add directional
anisotropy, barriers, spatiotemporal fields, or a new random-effect tier.

## Files created or changed

Implementation and package metadata:

- `R/mesh.R`, `R/crs.R`, `R/plot.R`, `R/fit-multi.R`, and `R/imports.R`;
- `DESCRIPTION`, `NAMESPACE`, `NEWS.md`, `AGENTS.md`, and `CLAUDE.md`;
- `dev/verify-sdmtmb-spatial-oracle.R`.

Tests:

- `tests/testthat/test-mesh.R`;
- `tests/testthat/test-utm-conversions.R`;
- `tests/testthat/test-anisotropy.R`;
- `tests/testthat/test-stage4-spde.R`.

Public documentation and generated help:

- `README.md`, `vignettes/gllvmTMB.Rmd`, and `_pkgdown.yml`;
- `man/add_utm_columns.Rd`, `man/get_crs.Rd`,
  `man/gllvmTMB-package.Rd`, `man/make_mesh.Rd`,
  `man/plot_anisotropy.Rd`, and `man/plot.gllvmTMBmesh.Rd`.

Design, provenance, and durable receipts:

- `inst/CITATION` and `inst/COPYRIGHTS`;
- `docs/design/00-vision.md`, `docs/design/01-formula-grammar.md`,
  `docs/design/03-likelihoods.md`, `docs/design/04-random-effects.md`,
  `docs/design/04-sister-package-scope.md`,
  `docs/design/35-validation-debt-register.md`, and
  `docs/design/46-visualization-grammar.md`;
- `docs/dev-log/check-log.md` and `docs/dev-log/decisions.md`;
- `docs/dev-log/artifacts/2026-08-01-sdmtmb-spatial-black-box-oracle.md`;
- `docs/dev-log/research/2026-08-01-independent-spatial-helper-literature.md`;
- `docs/dev-log/plan-actual/2026-08-01-independent-spatial-helpers.md`;
- this report.

`ROADMAP.md` and `docs/dev-log/known-limitations.md` were inspected and did not
require a status change. No other example file used the changed mesh class or
the former anisotropy return contract.

## Implementation and API outcome

`make_mesh()` now returns `gllvmTMBmesh` and uses public fmesher constructors,
`fm_fem(order = 2)`, and `fm_basis()`. Cutoff, deterministic k-means,
validity-first cutoff search, and supplied `fm_mesh_2d` modes all normalize to
one validated object contract. A cutoff-search target is advisory: if an exact
vertex count would yield non-finite FEM entries or projection rows that do not
sum to one, the function returns the closest valid candidate.

Valid legacy `sdmTMBmesh` objects receive a lifecycle warning, are converted to
`gllvmTMBmesh`, and lose `sdm_spatial_id`. The legacy plot method delegates to
the new native method. `add_utm_columns()` and `get_crs()` use `sf`'s public
transformation API and explicit UTM validation. `plot_anisotropy()` returns an
isotropic range circle or its data; `plot_anisotropy2()` draws the same geometry
with base graphics. Non-spatial, delta, spatiotemporal, and `model != 1` inputs
fail explicitly.

Intercept-only and full/independent random-slope fits read `kappa` from the
native report. The reduced-rank latent-slope route estimates the same
`log_kappa_spde` but does not currently duplicate it in `REPORT()`; the helper
therefore reads that fitted value from TMB's retained `parList()` contract.
This is post-fit extraction only and does not change the C++ objective.

## Checks run and exact outcomes

After merging current `origin/main` (`cee55a07`) into the implementation
branch, the focused integration command ran:

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-mesh.R"); testthat::test_file("tests/testthat/test-utm-conversions.R"); testthat::test_file("tests/testthat/test-anisotropy.R"); testthat::test_file("tests/testthat/test-stage4-spde.R"); testthat::test_file("tests/testthat/test-spatial-mode-dispatch.R"); testthat::test_file("tests/testthat/test-spatial-orientation.R")'
```

Outcome: 122 assertions passed, with zero failures, warnings, or skips. This
includes real R-to-TMB spatial fits, not only mock objects.

```sh
SDMTMB_ORACLE_LIB=/private/tmp/gllvmtmb-sdmtmb-oracle Rscript --vanilla dev/verify-sdmtmb-spatial-oracle.R
```

Outcome: passed against isolated sdmTMB 1.1.0 and fmesher 0.8.0 at tolerance
`1e-10` for the defined `A_st`, `c0`, `g1`, `g2`, and CRS fixtures. This is a
behavioural comparison, not authorship evidence, and is not a package
dependency or CRAN test.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(reporter = "summary")'
```

Outcome: documentation regenerated; roxygen reported the repository's
existing `AIC.gllvmTMB_multi` and `BIC.gllvmTMB_multi` export notes.
`pkgdown::check_pkgdown()` reported no problems. The full suite reached all
spatial-helper and Stage-4 files green and reported 785 intentional skips and
two unrelated gllvm-comparator warnings. It ended with three failures outside
this lane:

1. the newly merged `lambda-constraint-suggest.Rmd` uses
   `profile_retention`, while `test-article-prescribed-calls.R` allows only
   `varimax_threshold` and `wald_retention`;
2. the known fixed-fixture `funcphylo` spatial recovery fit did not report
   convergence;
3. the pre-existing dispatcher correlation-ellipse vdiffr snapshot differs on
   this machine.

The generated `.new.svg` snapshot was removed; no visual baseline was accepted
or modified. The final no-manual `devtools::check()` returned one error, one
warning, and two notes. The error is the repository-wide test phase above; the
warning and notes are recorded as global check output rather than attributed
to this lane. The matching `docs/dev-log/check-log.md` entry retains the
command and ledger.

## Consistency audit

```sh
rg -n -i 'inherited from sdmTMB|inherits sdmTMB|inherit.*spatial helper|spatial helper.*inherit|sdmTMB.*cite|cite.*sdmTMB|from which gllvmTMB|SPDE inheritance|plot_anisotropy\*.*from sdmTMB' AGENTS.md CLAUDE.md README.md DESCRIPTION NEWS.md R inst vignettes docs/design _pkgdown.yml NAMESPACE man
```

Verdict: no current sdmTMB inheritance or citation-obligation claim remains.
References that describe sdmTMB as a sister package, comparator, historical
inspiration, or temporary legacy class are intentional.

```sh
rg -n 'sdmTMB' DESCRIPTION NAMESPACE inst/CITATION
```

Verdict: sdmTMB is absent from runtime metadata, NAMESPACE, and the formatted
citation entries.

```sh
rg -n 'gllvmTMBmesh|sdmTMBmesh|sqrt\(8\) / kappa|anisotropy_estimated|H = I' R tests/testthat README.md NEWS.md vignettes docs/design man
```

Verdict: the native class, temporary compatibility bridge, range equation, and
isotropy boundary are visible in implementation, tests, public prose, design
records, and generated help.

`git diff --check` passed after removing Markdown hard-break whitespace. The
generated Rd files were spot-checked after `devtools::document()`; titles,
arguments, values, and the Scope section agree with their roxygen sources.

## Tests of the tests

The tests mutate valid objects to prove the validators reject dense,
non-square, explicitly non-finite, dimensionally incompatible, and zero-row-sum matrix
states. They verify k-means reproducibility without changing the caller's RNG,
collinear and malformed coordinate failures, supplied-mesh conflicts, class
migration, removal of `sdm_spatial_id`, metre/kilometre scaling, UTM bounds,
range geometry, ggplot and base-plot returns, and unsupported fit states. The
Stage-4 test independently computes `sqrt(8) / kappa` from a fitted model and
compares it with the plotting data. The oracle runs in a separate library and
compares observable matrices after implementation; it cannot validate source
independence and is not presented as doing so.

## What did not go smoothly

The first cutoff-search audit exposed a degenerate nominal-knot solution with
non-finite FEM/projection output. The implementation was changed to search on
coordinate scale and rank candidates by validity before knot-count distance.
K-means centres also required an enclosing boundary so every observation had a
valid barycentric projection. The lifecycle warning initially used an invalid
value-deprecation specification and was corrected.

An `air format` call touched unrelated lines in the large fit engine and an
established Stage-4 test. That mechanical noise was reversed immediately and
only the intended hunks were reapplied. The full suite then exposed three
unrelated current-main failures listed above; this lane does not modify their
article, optimizer fixture, dispatcher, or snapshot baseline.

## Team learning and process improvements

**Ada** kept the task in an isolated worktree, merged current `origin/main`
before final verification, and treated repository-wide red results as evidence
rather than permission to widen the lane.

**Jason/Ranga** separated method specification from software comparison. The
curated NotebookLM notebook contains Lindgren-Rue-Lindstrom, fmesher, sf, and
anisotropy sources; sdmTMB was excluded from the source set and introduced only
as a post-implementation executable oracle.

**Curie** forced the contract beyond happy paths: every mesh mode, supplied
meshes, malformed candidates, matrix invariants, the legacy bridge, and a real
TMB fit are now explicit tests. The validity-first knot search is a direct
result of that test pressure.

**Gauss and Noether** enforced the load-bearing boundary: `c0/g1/g2` must map
to the unchanged `M0/M1/M2` precision, and scalar `kappa` cannot justify an
anisotropy ellipse. True anisotropy remains model work.

**Rose** classified every sdmTMB occurrence rather than deleting the package
name indiscriminately. Sister-package scope and courtesy acknowledgement remain;
false inheritance, copyright, required-citation, and bibliography claims do
not.

**Boole and Pat** kept the public explanation actionable: users create a
`gllvmTMBmesh`, legacy objects warn, `return_data` remains useful, and equal
axes are explicitly not an anisotropy estimate.

**Grace** required documentation regeneration, pkgdown validation, focused and
full tests, and a no-manual package check. The global failures prevent a clean
merge claim even though every in-scope gate is green.

The fresh D-43 completion panel initially returned three NOT-DONE findings:
missing explicit non-finite FEM rejection, stale inheritance wording in the
vision note, and a latent-slope/empty-CRS interface gap. Each finding was
repaired and re-reviewed. Curie's test-fidelity reviewer, Rose's provenance
reviewer, and the Gauss/Noether mathematical reviewer then returned DONE with
no remaining P0--P3 finding. Two NOT-DONE verdicts therefore did withhold the
claim until the repairs landed, as required.

## Design and documentation updates

SPA-01 now records the independent public-fmesher implementation, helper and
fit-boundary tests, and the isotropic-only plot contract. Formula, likelihood,
random-effect, sister-package, vision, and visualization notes describe the
same `gllvmTMBmesh` and unchanged engine boundary. `NEWS.md`, README, vignette,
roxygen, generated Rd, pkgdown navigation, CITATION, and COPYRIGHTS were
updated as one cascade. The prose review found no unsupported anisotropy or
sdmTMB citation claim after the final edits.

**Roadmap tick**: N/A; this removes provenance debt and hardens an existing
helper capability without changing a `ROADMAP.md` phase or progress bar.

## GitHub issue ledger

- Created drmTMB issue
  [#881](https://github.com/itchyshin/drmTMB/issues/881), *Plan mesh/SPDE
  spatial Gaussian intercept with an explicit mesh contract*.
- The issue explicitly defers range/anisotropy/barriers, slopes,
  direct-SD/corpair, non-Gaussian meshes, interval/coverage claims, and reuse of
  gllvmTMB code without a separate provenance decision.
- No gllvmTMB issue was closed. The three current-main full-suite failures are
  external lane blockers and are recorded here and in the check log rather
  than silently repaired in this PR.

## Known limitations and next actions

The helper rewrite does not establish coverage, recovery breadth, directional
anisotropy, or spatiotemporal support. The legacy class bridge needs a later
removal decision. The developer oracle must remain isolated and non-CRAN.

All in-scope focused, integration, documentation, pkgdown, and behavioural
oracle gates are green. Repository-wide tests are not green because of the
three unrelated failures above. Therefore the code-debt-removal claim is
supported for this branch, but the branch must not be described as globally
merge-ready until current main's article policy, fixed-fixture convergence, and
visual snapshot gates are resolved or formally adjudicated. The recovery
checkpoint names the exact resume command and remaining gate.

## Post-plan integration closure

The maintainer subsequently authorised the recommended integration work. The
three package-wide blockers above are now resolved rather than waived:

1. The article guard now distinguishes actual `match.arg()` choice vectors from
   functions that validate a larger custom set.
2. The functional-phylogeography test now enforces the scale-free optimizer and
   scaled-gradient criterion it claimed. The fitted spatial direction and
   correlation recovery remain explicit assertions.
3. The ellipse snapshot's four `0.01` coordinate changes were accepted only
   after side-by-side rendering showed no visible geometry, label, colour, or
   layout change.

The Rose walk-around also removed a fictitious `some` package dependency from
a quoted namespace-parser fixture without weakening that test. Current
`origin/main` at `bb9eb75e`, including the independently completed AGHQ ridge
work, was merged in `1ca93ec8`. The combined AGHQ/spatial focused suite,
`pkgdown::check_pkgdown()`, the isolated sdmTMB oracle at `1e-10`, and
`git diff --check` passed. A retained full no-manual check on the combined tree
returned zero errors; after the quoted-fixture repair, a dependency-focused
check returned zero errors and zero warnings, with only the environment's clock
and `xcrun_db` notes.

This supersedes the earlier merge-readiness withholding. The branch is ready
for a draft pull request and networked three-OS CI; it still must not be merged
unless those required checks pass.

Rose's final pre-publish gate is PASS after the public scope statements were
linked to SPA-01 and FG-13. Shannon's coordination gate is WARN because the
open handover PR #881 is now stale and conflicting; the new integration PR will
supersede it instead of merging its obsolete red-main wording.

# Protocol-validated closeout addendum

## 1. Goal

Replace the inherited R-side spatial helpers with an independently authored
literature/fmesher implementation while leaving the TMB likelihood unchanged.

## 2. Implemented

Independent mesh, CRS, compatibility, isotropic-range plotting, tests,
documentation, provenance migration, black-box oracle, and package-wide gate
repairs are implemented on `codex/spatial-independent-helpers`.

## 3a. Decisions and Rejected Alternatives

New objects use `gllvmTMBmesh`; legacy objects warn through a temporary bridge.
True anisotropy was rejected for this arc because the engine estimates scalar
`kappa`, not `H`. Copying sdmTMB or importing it at runtime was rejected.

## 4. Files Touched

The complete implementation, test, documentation, generated-help, provenance,
and receipt inventory is recorded under the earlier “Files created or changed”
heading. The integration continuation additionally changed three baseline test
files and their paired SVG snapshot.

## 5. Checks Run

Focused and package-wide tests, retained `devtools::check()`, documentation,
pkgdown, the isolated sdmTMB oracle, stale-provenance scans, and
`git diff --check` were run. Exact commands and outcomes are recorded above and
in `docs/dev-log/check-log.md`.

## 6. Tests of the Tests

Failure-before-fix evidence covered the article choice guard, the raw-versus-
scaled gradient boundary, non-finite FEM matrices, empty CRS data, latent-slope
range extraction, and the visual snapshot. The tests fail on their intended
defects and pass after the narrow repairs.

## 7a. Issue Ledger

drmTMB issue #881 records future mesh/SPDE work. No gllvmTMB issue was silently
closed; PR publication and CI are recorded separately from this report.

## 8. Consistency Audit

The formula grammar, TMB `A_proj/M0/M1/M2` interface, help, README, vignette,
pkgdown index, citation, copyright, design records, and validation register were
checked for agreement. The AGHQ/main merge retained both routing paths.

## 9. What Did Not Go Smoothly

The first closeout found three unrelated red tests, the first D-43 panel found
three additional omissions, and the final package check exposed a fictitious
`some` dependency. Each was diagnosed and repaired rather than waived.

## 10. Known Residuals

The compatibility bridge needs a later lifecycle decision. Local checks retain
clock-verification and macOS `xcrun_db` notes. Networked three-OS CI remains the
external merge gate.

## 11. Team Learning

Literature-first implementation plus a post-hoc executable oracle cleanly
separated specification from comparison. Scale-free recovery evidence was more
informative than a raw-gradient threshold at the same optimum.

## 12. Cross-Product Coverage

This arc covers R-side mesh construction, projection/FEM matrices, CRS,
isotropic range plotting, legacy normalization, current spatial fit ingestion,
and their documentation. It does NOT cover directional anisotropy,
spatiotemporal fields, barriers, new spatial likelihoods, interval calibration,
heavy recovery grids, or drmTMB implementation.
