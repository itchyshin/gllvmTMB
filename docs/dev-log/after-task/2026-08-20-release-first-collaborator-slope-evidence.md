# After-task report: 0.7 release-first collaborator repair and slope smoke

**Date:** 2026-08-20/21 MDT
**Branch:** `codex/release-slope-evidence-20260820`
**Scope:** collaborator repair closure, one primary-help long/wide example,
retained random-slope fit-health smoke, and an explicit 0.7 MSPL park.

## Task goal

Strengthen the parts of `gllvmTMB` that a collaborator can safely use now:
land the two long-format repairs, give Iwo a self-contained corrected workflow,
make the primary `gllvmTMB()` help visibly cover both data shapes, and retain
rather than promote the random-slope smoke evidence.  No MSPL family,
inference, real-data, or Design 125 expansion belongs in this release-first
arc.

## Mathematical contract

No likelihood, family, formula grammar, or public API was changed in this
branch.  The new help example documents the already-supported equivalence

```text
value ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2
```

and

```text
traits(trait_1, trait_2, trait_3) ~ 1 + env_1 + env_2.
```

The latter is the wide-data-frame shorthand for the former.  The retained
smoke is fit-health / point-recovery evidence only; it does not establish
interval coverage, structured-route recovery, or an MSPL family admission.

## Files changed

- `R/gllvmTMB.R` and generated `man/gllvmTMB.Rd`: one paired long/wide example
  in the primary help topic, using `traits(...)` rather than the soft-deprecated
  matrix wrapper.
- `dev/release-evidence/README.md`, `run-slope-smoke.R`, frozen manifest, raw
  CSV records, and summaries: 12-cell augmented phylogenetic random-slope
  smoke, explicit provenance guard for future runs, and its stop receipt.
- `docs/dev-log/after-task/2026-08-20-release-first-collaborator-slope-evidence.md`:
  this report.

Not changed: `NEWS.md`, `ROADMAP.md`, source likelihood code, family registry,
validation-debt status, articles, pkgdown navigation, and public MSPL claims.

## Checks run

- `devtools::test(filter = "^null-tier-defaults$")` on #1191 before its rebase:
  PASS, 17 expectations.
- #1191 CI run `32376213211`: SUCCESS on exact head
  `ab1a7e8675c9eb7585ed8e574088df4cfe0920dc`; merged as
  `bedf4b8b2d7776ff6f88a65c068f3a2b4ee560b0`.
- #1193 CI was verified on exact head
  `519170862e25e2a37926b59a24e670c9c6f847dc`; merged as
  `379a54472bef95f1e4c3b66c552a6b0acddbc714`.
- `Rscript --vanilla /private/tmp/verify_traits_example.R`: PASS; the exact
  long and wide calls both returned log likelihood `-679.4454`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: PASS, `No problems found`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE); devtools::check_man()'`:
  regenerated `man/gllvmTMB.Rd`; the only reported `checkRd` warning is the
  pre-existing escaped-dollar sign at `man/gllvmTMB.Rd:572`
  (`report$joint_nll_*`), outside the example.
- `git diff --check origin/main...HEAD`: rerun after the review corrections;
  PASS after removing Markdown hard-break whitespace.  The prior report
  incorrectly claimed it passed while that whitespace remained.
- `GLLVMTMB_SLOPE_SMOKE_MAX_CELLS=1 GLLVMTMB_SLOPE_SMOKE_OUTPUT=/private/tmp/slope-source-provenance-smoke.csv Rscript --vanilla dev/release-evidence/run-slope-smoke.R`:
  PASS in 2.18 seconds.  The result records both `source_checkout` and
  `package_path` as `/private/tmp/gllvmtmb-release-slope`, proving that the
  revised runner loads the intended source checkout.
- `rg -n 'gllvmTMB_wide\\(' README.md NEWS.md docs vignettes R/gllvmTMB.R man/gllvmTMB.Rd`:
  intentional compatibility/deprecation and historical references only; no new
  primary wide API was introduced.
- `rg -n 'traits\\(trait_1, trait_2, trait_3\\)|site_species' R/gllvmTMB.R man/gllvmTMB.Rd dev/release-evidence`:
  PASS; source and generated help carry the paired example consistently.
- `rg -n 'MSPL|Totoro|DRAC|smoke_pass|n_healthy' dev/release-evidence`:
  PASS; the retained packet states `smoke_pass = FALSE`, no remote run, and the
  experimental/parked boundary.

## Consistency audit and tests of the tests

The temporary verifier exercised the exact copied help calls, not a nearby
fixture, and asserted equality of the two fitted log likelihoods.  The raw
smoke CSV retains all 12 attempts and records five unhealthy cells rather than
dropping them.  Its summary is `n_healthy = 7`, `smoke_pass = FALSE`, p90
15.4482 seconds, and total 98.0146 seconds; that fails the pre-registered
all-healthy local-smoke gate.  The legacy smoke did not prove that its stamped
revision was the loaded package; its code provenance is unverified and no
release or promotion claim rests on it.

## What did not go smoothly

The full smoke initially met an approximately 30-second desktop execution
wrapper ceiling during retry chunks.  The retained complete result nevertheless
exists and was validated from its CSV summary; no additional remote run was
started.  GitHub API rate limiting temporarily prevented status polling, so
#1191 was merged only after a later direct check confirmed both the exact SHA
and SUCCESS result.  The original smoke runner stamped `git HEAD` while using
an installed package namespace; the revised runner loads and records its source
checkout, but the legacy run is deliberately downgraded rather than rerun.
`check-log.md` is currently present in 226 foreign refs; the lane check forbids
a blind append.

## Team learning

- **Boole:** the useful roxygen scope is the primary `gllvmTMB()` help topic,
  not every extractor or keyword Rd page.  The code example must demonstrate
  actual long/wide equivalence, not merely name both formats.
- **Curie:** a smoke gate is informative only when every attempted fit, its
  health fields, and its code provenance are retained.  The 7/12 result closes
  the remote-compute gate; it is not a reason to cherry-pick the seven passing
  families.
- **Rose:** concurrent-lane risk is material.  The unique after-task report is
  safe, but the shared check-log must be merge-and-retry coordinated rather
  than overwritten.
- **Grace:** exact-head CI was checked before the #1191 merge; a green result
  from an earlier commit would not have been sufficient.

## Design and pkgdown updates

No design-document or validation-debt row changed: the work makes an existing
wide interface easier to find and records a non-promotion result.  Generated
Rd is synchronised with roxygen; `pkgdown::check_pkgdown()` passed.  No article
was changed because tutorials already contain paired examples.

## Roadmap tick

**Roadmap tick:** N/A — no `ROADMAP.md` row changed.  The operational release
priority and MSPL park are recorded in Mission Control, not represented as a
new package capability.

## GitHub issue ledger

- PR #1193: merged trait-column parser repair.
- PR #1191: merged optional `unit_obs` / `cluster` default repair after exact
  successful CI.
- Issue #1187: inspected and commented with the narrow maintainer scope
  decision (primary `gllvmTMB()` help only; no mass `man/` rewrite).
- `iwogross/terrapin-systematic-map#1`: posted the approved educational reply
  after both repairs merged.
- No new issue created: the smoke has an explicit retained stop receipt and
  future MSPL fixed-effect-separation work already requires a separate approved
  methods arc.

## Known limitations and next actions

Do not launch Totoro or DRAC from this evidence.  Do not promote MSPL,
admit families, or make coverage claims.  Push this branch, obtain an
independent documentation/evidence review and CI on its rebased head, then
merge.  Resolve the shared `check-log.md` collision by re-reading the newest
main version and appending a unique dated entry during the final merge retry;
preserve every competing entry.
