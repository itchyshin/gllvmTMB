# After Task: Fresh iJSDM response-information campaign

**Branch**: `codex/isdm-response-information-20260901`
**Date**: 2026-09-01
**Roles (engaged)**: Ada, Curie, Fisher, Grace, Rose

## 1. Goal

Run a fresh, bounded nonspatial paired baseline-versus-`rep3` recovery study,
with the baseline data preserved byte-for-byte inside the `rep3` arm, and
record an honest internal result without a public capability claim.

## 2. Implemented

The campaign harness, frozen 800-identity plan, worker receipts, independent
raw-record scorer, and 45 focused tests are present under
`dev/isdm-requalification/response-information/` and
`tests/testthat/test-isdm-response-information-*.R`. Totoro and Tamia
qualifications passed. Tamia retained 800/800 terminal worker receipts; the
independent scorer classified the study as `EVIDENCE_INCOMPLETE`, because only
398/400 paired observations meet the predeclared numerical-success rule.

## 3. Files Changed

- Campaign implementation, frozen CSV/RDS plans, compute launchers, verifiers,
  symbolic contract, results, and compact evidence records:
  `dev/isdm-requalification/response-information/`.
- Focused contract, fixture, record, recomputation, classifier, and runner
  tests: `tests/testthat/test-isdm-response-information-*.R`.
- Acceptance ledger: `.unlazy/ijsdm-response-information-GATES.md`.
- Internal scope record: `docs/design/35-validation-debt-register.md`
  (`ISDM-RESP-INFO`).
- Closure records: `docs/dev-log/check-log.md` and this report.

No `R/`, `src/`, `man/`, `vignettes/`, `README.md`, `NEWS.md`, `ROADMAP.md`,
`_pkgdown.yml`, or generated documentation file changed. No examples changed.

## 3a. Decisions and Rejected Alternatives

The first Tamia pilot launcher incorrectly used Slurm array positions as
scientific task IDs. Its 16 terminal records remain retained: two were intended
pilot identities and fourteen were valid extra identities. The approved repair
ran only the 14 missing intended pilot identities, then ran exactly the 770
unstarted identities. It neither reran nor replaced a retained identity.

The frozen 0.01 gradient rule was retained after the study began. The two
finite, convergence-zero, positive-Hessian `rep3` fits above that threshold
are evidence-incomplete records, not eligible successes and not a scientific
null result.

## 4. Checks Run

- `Rscript --vanilla dev/isdm-requalification/response-information/verify-contract.R` — passed.
- `Rscript --vanilla dev/isdm-requalification/response-information/verify-tests.R` — 45 pass, 0 fail/warn/skip.
- `Rscript --vanilla dev/isdm-requalification/response-information/verify-wording.R` — passed.
- Tamia `verify-study.R` against the frozen 800-row plan — passed; 800/800 terminal records.
- `git diff --check origin/main...HEAD` — passed.
- `rg -n -i 'response information|response-information|baseline.*rep3|rep3.*baseline' README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes R man` — expected no matches; no public package or documentation claim added.

## 5. Tests of the Tests

The pilot mapping test is failure-before-fix: it catches the real array-index
mistake by mapping index 3 to frozen task ID 101 rather than task ID 3. Record
reader tests reject missing/non-worker terminal receipts, exercising the
retained-pilot boundary. Existing fixture tests assert byte-identical baseline
nesting and disjoint added response streams.

## 6. Consistency Audit

The public-scope search in §4 found no new reader-facing claim. Internal
searches show `EVIDENCE_INCOMPLETE` in the classifier, plan, results, ledger,
and register; the terms agree on its meaning. The branch adds no formula,
likelihood, family, extractor, argument, default, roxygen, or syntax change,
so the convention-change cascade and rendered-Rd checks are N/A.

## 7. Roadmap Tick

**Roadmap tick**: N/A. This internal evidence campaign does not change a public
roadmap row.

## 7a. GitHub Issue Ledger

Inspected [#943](https://github.com/itchyshin/gllvmTMB/issues/943), the
umbrella integrated-GLLVM simulation issue. It asks for a broader
misspecification and arm-comparison study, which this paired nonspatial
response-information experiment deliberately does not address. No issue was
commented on, closed, or created.

## 8. What Did Not Go Smoothly

The original 16-position pilot array was mapped incorrectly. The repair was
made transparent, additive, and denominator-conserving: all 16 records were
kept, and only the 14 missing intended IDs were subsequently run. A later
bulk transfer stopped at 143 remote records; raw records remain safely on
Tamia and the independent scorer was run there, with only its compact summary
copied locally. The study result itself is incomplete because two otherwise
healthy `rep3` fits narrowly miss the gradient gate.

## 9. Team Learning

**Ada:** run an explicit array-position-to-frozen-ID mapper and test it before
any retained array, rather than equating scheduler indices with scientific IDs.

**Curie:** preserve every terminal record and distinguish numerical
availability from scientific outcome; 398/400 scoreable pairs cannot be
quietly summarized as a 400-pair recovery result.

**Fisher:** a frozen numerical gate applies even when the two misses are
small; `EVIDENCE_INCOMPLETE` prevents an unavailable contrast becoming
`MIXED_OR_NULL`.

**Grace:** remote raw evidence belongs on `/project`; compact checksummed
summaries are sufficient for Git provenance and avoid importing a bulky archive.

**Rose:** evidence, ledger, plan, register, and check log must tell the same
story about the recovery amendment and its no-public-claim boundary.

## 10. Known Limitations And Next Actions

`ISDM-RESP-INFO` is `blocked` for any recovery conclusion. There is no claim
that extra response streams improve shared/full surfaces or `Psi`, no interval
claim, and no spatial, empirical, or API conclusion. The remaining work is
read-only final evidence/reproducibility review, package-scope provenance
reconciliation, and one compact draft PR that carries this internal result
without widening public documentation.
