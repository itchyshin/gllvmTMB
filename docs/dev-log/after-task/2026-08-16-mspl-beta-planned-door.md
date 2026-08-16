# After Task: planned-only Beta-logit door for SE pins

**Branch**: `cursor/mspl-beta-planned-door`
**Date**: `2026-08-16`
**Roles (engaged)**: Gauss / Curie / Rose
**Worktree**: `/private/tmp/gllvmtmb-mspl-beta-planned-door` from
`origin/main` @ `e46a3a2e` (#1045)

## 1. Goal

Open a fenced planned-only Beta-logit prepare door so the live #999
\(Q_P\)/\(Q_0\) pin can run. Mirror nbinom #1007. Do not admit. Do
not NEWS covered. Do not public `se=TRUE` inference. Tweedie stays
closed because #1047 is not on main.

## 2. Implemented

- Public `estimator = "mspl"` now accepts single-family Beta logit
  ordinary latent q=1/2 (`family_id` 7).
- Registry rows stay `planned` / `phase4_prep`. Notes drop
  "no public door" and still say not admitted / not covered.
- Public `se=TRUE` still withholds `sdreport()` / `vcov()` /
  `confint()`.
- Internal curvature pin already allowed Beta-logit; prepare now
  matches.
- Tweedie (`family_id` 6) remains off the allow-list.
- Rate stays unpinned `c=1`. Atom is the #1045 FCN \(K_{\beta\beta}\)
  (\(\phi^2\)) form; not coercive at \(\mu\to 0/1\).

## 3. Files Changed

- `R/mspl.R` — allow-list `{0,1,2,5,7,15}`; abort text names Beta
  and still defers Tweedie.
- `R/mspl-registry.R` — Beta notes drop "no public door".
- `tests/testthat/test-mspl-beta-public-door.R` — new door-opens pin.
- `tests/testthat/test-mspl-prepare-fence.R` — Tweedie-only reject.
- `tests/testthat/test-zz-mspl-fenced-family-tapes.R`
- `tests/testthat/test-zz-mspl-rest-family-prepare-fence.R`
- `tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R`
- `tests/testthat/test-mspl-registry.R`
- `tests/testthat/test-mspl-beta-jeffreys-atom.R`
- `tests/testthat/test-estimator-provenance.R`
- this after-task; `docs/dev-log/check-log.md`.

No NEWS. No `src/`. No register admit. No `man/` / pkgdown.

## 3a. Decisions and Rejected Alternatives

- **Decision:** Beta-only door; leave Tweedie closed.
  **Rationale:** #1045 fixed the Jeffreys atom; #1047 hang-fix is
  still open. The previous #1014 door was blocked on those two
  hostilities. **Rejected:** wait for a combined Tweedie+Beta PR;
  treat the remaining \(\mu\to 0/1\) non-coercivity as a packet
  blocker. That hostility is documented, same class as the nbinom
  planned door. **Confidence:** high on the door shape; high that
  opening Tweedie without #1047 would re-hang CI.

## 4. Checks Run

See `docs/dev-log/check-log.md` for this sitting. No NEWS. No `src/`
(C++ GLM-outer tape for `family_id` 7 already existed after #1045).

## 5. Tests of the Tests

- Failure-before-fix: `test-mspl-prepare-fence.R` and
  `test-zz-mspl-fenced-family-tapes.R` required Beta to abort
  `gllvmTMB_mspl_unsupported`. Those pins now fail if the door
  closes again.
- Boundary: Tweedie and rest-family rejects still match the new
  allow-list sentence. Status 0/1 atom codes unchanged.
- Feature-combination: #999 Beta live pin may run \(Q_P\)/\(Q_0\)
  or skip for an honest nll-tie; it must not skip for
  "family door is missing".

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `fam_ids %in% c(0L, 1L, 2L, 5L, 7L, 15L)` | present |
| `6L` on the public allow-list | absent (Tweedie still closed) |
| Beta notes `no public door` | gone |
| Beta notes `not admitted` / `not covered` | still present |
| NEWS covered / admit row | absent |

## 7. Roadmap Tick

N/A. No ROADMAP / NEWS / admit row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. The work is the #999
pin's remaining "family door is missing" skip after #1045.

## 8. What Did Not Go Smoothly

#1014 already wrote the Beta prepare branches and then closed the
allow-list. This slice only widens `family_id` 7. The dead
`is_beta` / `log_phi_beta` / planned-status path was already on
main.

## 9. Team Learning

**Gauss.** The #1045 \(\phi^2\) atom and V8 status 1 are the
scientific reason the door can open. The remaining hostility is
named, not repaired.

**Curie.** A planned door is what lets the live pin stop skipping
for a missing family. Tweedie hang skips stay `skip_if(TRUE)`.

**Rose.** Neighbor fence tests must move the still-fenced abort
onto Tweedie only. Leaving Beta in `test-mspl-prepare-fence.R`
would make the door look closed.

## 10. Known Limitations And Next Actions

- Not admitted. Not covered. No public `vcov()`.
- Atom is still not a \(\mu\to 0/1\) repair.
- Tweedie door waits on #1047.
- Do not merge as a covered-SE or admit claim.
