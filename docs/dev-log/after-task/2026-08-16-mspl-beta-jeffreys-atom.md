# After Task: Beta Jeffreys / I_μ atom (status 1 was valid)

**Branch**: `cursor/mspl-beta-jeffreys-atom-fix`
**Date**: `2026-08-16`
**Roles (engaged)**: Gauss / Noether / Curie / Rose
**Worktree**: `/private/tmp/gllvmtmb-mspl-beta-atom-fix` from `origin/main` @ `55666f1e`

## 1. Goal

Diagnose why the Beta MSPL Jeffreys / \(I_\mu\) atom returned
status 1 on the #999 8×3 cell, fix the atom so an internal
\(Q_P\)/\(Q_0\) pin need not `skip_if` for atom-invalid, and keep
the public door closed. Tweedie hang stays out of this PR. No
admit. No `se=TRUE`. No NEWS.

## 2. Implemented

Two stacked defects, both now corrected:

1. The tape used Ferrari–Cribari-Neto’s *inner* \(W\)
   (\(w=\phi\{\psi'(a)+\psi'(b)\}\{\mu(1-\mu)\}^2\)). From
   \(\partial^2\ell/\partial\mu^2\), \(I_\mu=\phi^2\{\psi'(a)+\psi'(b)\}\),
   so the Fisher block is \(K_{\beta\beta}=\phi X^\top W X\) and the
   GLM-outer diagonal is
   \(w=\phi^2\{\mu(1-\mu)\}^2\{\psi'(a)+\psi'(b)\}\). Default
   `log_phi_beta = 1` means \(\phi=e\); every row was mis-scaled
   from the first evaluation. The weight is still not coercive at
   \(\mu\to 0/1\) (\(w\to 1\)).
2. Frozen V8 status **1 is `OK_MP_CERTIFIED`**, not invalid. R
   accepted only 0 (`OK_DOUBLE_CERTIFIED`). Nearly-constant Beta
   weights can take the MP path; that is a valid certified
   half-logdet.

Public prepare allow-list stays `{0,1,2,5,15}`. Family id 7 is
still rejected at the door. Tweedie hang skips are unchanged.
Beta registry rows stay `planned`.

## 2a. Mathematical contract

No public API / likelihood / grammar / family change. The fenced
Beta GLM-outer atom now uses the \(\phi^2\) information diagonal
already named by `test-mspl-beta-phase4-oracles.R`. Jeffreys atom
acceptance is 0 or 1.

## 3. Files Changed

- `src/gllvmTMB.cpp` — Beta `family_id == 7` log-weight is the
  \(\phi^2\) form, log-space.
- `R/mspl.R` — `.gllvmTMB_mspl_jeffreys_atom_ok()`,
  `.gllvmTMB_mspl_beta_jeffreys_weight()`.
- `R/fit-multi.R` — Jeffreys atom accepts status 0 or 1.
- `R/mspl-registry.R` — Beta planned notes drop “atom status 1”.
- `tests/testthat/test-mspl-beta-jeffreys-atom.R` — new pure-R
  oracle + pin that the SE file no longer `skip_if(TRUE)`s for
  status 1.
- `tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R` —
  removed `.mspl_se_beta_skip_if_atom_invalid()`.
- Comment-only: `test-mspl-prepare-fence.R`,
  `test-zz-mspl-fenced-family-tapes.R`,
  `test-estimator-provenance.R`.
- `docs/dev-log/research/2026-08-16-mspl-beta-jeffreys-atom.md`
- this after-task; `docs/dev-log/check-log.md`.

No NEWS. No register admit. No `man/` / pkgdown.

## 3a. Decisions and Rejected Alternatives

- **Decision:** accept V8 0 and 1 as valid; do not reopen family
  id 7. **Rationale:** MP-certified is a successful atom; the
  user forbade a public door. **Rejected:** treat status 1 as
  failure (that *was* the skip); add 7 to the allow-list in this
  PR. **Confidence:** high on the status table; high on
  \(I_\mu=\phi^2\{\psi'(a)+\psi'(b)\}\).
- **Decision:** leave Tweedie hang skips. **Rejected:** combine
  the two hostilities in one PR.
- **Decision:** new branch from current `origin/main` rather than
  rebase of open #1045. **Rationale:** #1045 is eight commits
  behind; this slice replays the same diagnosis onto `55666f1e`.

## 4. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "mspl-beta-jeffreys-atom|mspl-beta-phase4|zz-mspl-tweedie-beta|mspl-prepare-fence|zz-mspl-fenced-family|mspl-registry$|estimator-provenance")'
# [ FAIL 0 | WARN 0 | SKIP 4 | PASS 267 ]
# Tweedie live: SKIP hang (unchanged)
# Beta live: SKIP "family door is missing" (not atom-invalid)
```

```sh
rg -n "atom status 1|skip_if_atom_invalid" tests src R
# only the new test's negative pin
rg -n "fam_ids %in% c" R/mspl.R
# still 0L, 1L, 2L, 5L, 15L
```

Not run: `devtools::test()` full suite; `--as-cran`; Totoro;
public Beta fit (door closed).

## 5. Tests of the Tests

- Failure-before-fix: `.gllvmTMB_mspl_jeffreys_atom_ok(1L)` is
  now TRUE; the old `atom_status != 0` check would still abort.
- Boundary: status −1 / 10 / 11 / NA / empty / length-2 are
  still FALSE. \(\mu\to 0/1\) still \(w\to 1\), one-\(\phi\)
  form still \(w\to 1/\phi\).
- Feature-combination: #999 pin file must not contain
  `skip_if(TRUE)` for status 1; Tweedie hang skip remains.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `atom status 1` in tests/src/R | gone |
| `skip_if_atom_invalid` | gone |
| C++ `not coercive` | still present (fenced-tape pin) |
| Beta notes `not admitted` / `not covered` | still present |
| public allow-list `{0,1,2,5,15}` | unchanged |

## 7. Roadmap Tick

N/A. No ROADMAP / NEWS / admit row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. The work is the
#999 pin’s documented atom-invalid skip, not a numbered issue.
Open #1045 is the same diagnosis on a stale tip.

## 8. What Did Not Go Smoothly

The Phase-4 oracles already used \(\phi^2\) while the tape and
the five-atoms note used one \(\phi\). The status-1 skip treated
a valid V8 code as a broken atom, which hid the formula bug.

## 9. Team Learning

**Gauss.** The Jeffreys atom’s second return is a typed V8
status, not a boolean. 1 means MP-certified. Do not invent a
third meaning.

**Noether.** \(I_\mu=\phi^2\{\psi'(a)+\psi'(b)\}\) is the
information; FCN’s inner \(W\) is not. Phase-4 E2/E5 already
named the \(\phi^2\) limits.

**Curie.** A live \(Q_P\)/\(Q_0\) pin still cannot run until
family id 7 is on the allow-list. The pin now skips for the
door, not for a fake invalid atom.

**Rose.** “Status 1 (invalid)” in the #1014 / #999 comments was
stale wording. Comments in the fence tests were updated in the
same PR.

## 10. Known Limitations And Next Actions

- Public door still closed. Internal pin un-skips only after a
  later planned-door slice (Beta-only, not Tweedie).
- Atom is still not a \(\mu\to 0/1\) repair.
- Tweedie hang is untouched.
- Do not admit. Do not NEWS covered. Do not public `vcov()`.
