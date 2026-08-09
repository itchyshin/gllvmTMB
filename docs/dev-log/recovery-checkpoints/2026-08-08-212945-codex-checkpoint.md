# Codex recovery checkpoint — v4 detached-source launch gate

## Branch and working tree

- Worktree: `/private/tmp/gllvmtmb-cran-0.7-20260807`
- Branch: `cursor/cran-0.7-20260807`
- Status: intentionally dirty with the integrated pre-CRAN 0.6 development arc; preserve all tracked and untracked work.
- Package identity remains 0.6.0. No commit, push, version bump, release, or CRAN action occurred.

## Completed evidence

- Stable full ordinary suite: exit 0; no failures or errors.
- Six exact `glmmTMB` comparator rows: 6 PASS / 0 HOLD.
- Stan ordinary oracle: 9 PASS / 0 HOLD; maximum relative discrepancy `8.062e-16`.
- Narrow default warm-`nlminb` repair: independent bounded PASS; focused pure 64 expectations and focused heavy 125 expectations.
- V4 pure harness: PASS with zero fits; production identities, restart provenance, estimand joins, truth-metric recomputation, public fences, and fail-closed gates exercised.
- Detached-source launch: latest 3,076-member provisional archive passed exact manifest/type/mode/hash validation, fresh extraction, `R CMD build`, isolated-first `R CMD INSTALL`, runner source revalidation, and loaded-package provenance from a control path and launch root containing spaces. The deliberate invalid campaign stopped before attempt construction; zero fits ran.

## Latest source changes

- `inst/sim/cran07-v4/launch-bound-source.R`: quoted environment values; isolated library first while retaining installed dependency paths; Rscript `~+~` path decoding; SHA-ledger digest binding.
- All seven other v4 CLI entry points using `--file=` now decode Rscript's `~+~` representation.
- `inst/sim/cran07-core/campaign.R`: quote paths passed to `sha256sum` and `shasum`.
- `inst/sim/cran07-v4/campaign-v4.R`: binding receipt now includes the detached SHA-ledger basename and SHA-256.
- Pending binding CSV schema expanded accordingly; launch remains `HOLD_PENDING_SOURCE_ARCHIVE`.

## Verification just run

- All 12 v4 R scripts parsed.
- `inst/sim/cran07-v4/self-test.R`: PASS, `fits_run=0`.
- Direct SHA helper test on a path containing spaces: PASS.
- `git diff --check` on the touched v4/core files: PASS.
- Independent adversarial reviewer: all archive, path, dependency, source, and namespace checks PASS; one authority blocker remains.

## Remaining blocker

The detached binding receipt is internally exact but self-authenticating if the whole control root is copied. A trust anchor outside that copyable tree is required before smoke/pilot/production. An attempted unsigned `/tmp` authority workaround was rejected by the safety reviewer and did not land.

Preferred next decision: obtain explicit maintainer authorization for one fixed external campaign-authority record containing only the final receipt/archive/manifest/ledger/launcher SHA-256 values, stored outside the source tree and made read-only. It authorizes v4 simulation launch only, not a 0.7 release or CRAN submission. A cryptographic signing design is safer but materially more complex.

## Next safest actions after authorization

1. Implement and adversarially test the external authority binding.
2. Regenerate the SHA ledger without its circular binding-receipt row.
3. Build the exact source archive twice and require byte identity.
4. Bind the exact archive and re-run the zero-fit detached launch.
5. Run the local two-attempt-per-cell smoke.
6. Transfer the exact archive/envelope/authority to Totoro; run the 20-attempt pilot, then adjudicate before production.
7. After the v4 arc, perform the fresh full GitHub issue sweep before any 0.7 identity/source freeze.

## Blocking question

Does Shinichi authorize the fixed external v4 campaign-authority record described above, with the explicit boundary that it permits simulations only and cannot authorize a package release or CRAN upload?
