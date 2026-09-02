# B1/B2 report: gllvmTMB capability ledger + R<->Julia parity tool

## Files created

- `dev/gapclose/build-capability-status.R` -- B1 generator. Parses
  `docs/design/35-validation-debt-register.md` (dynamically, so it survives
  the register being edited under this session -- confirmed live: the
  register grew from 946 to 947 lines, and gained a `STR-RHO-SPA` row,
  mid-build), maps every register row to a ledger capability row (or an
  explicit `UNMAPPED_BY_DESIGN` reason), and writes
  `docs/design/capability-status.md`. Supports `--check`.
- `docs/design/capability-status.md` -- generated ledger. 76 capability rows
  across the 10 groups (Response families; Covariance grid source × mode;
  Grouping levels; Estimators; Intervals; Post-fit and extractors;
  Diagnostics; Missing data; Integrated SDM; Bridge), backed by 244 register
  rows, plus a trailing table of 32 register rows deliberately
  unmapped-by-design with a reason each.
- `tools/parity_ledger.R` -- B2 parity tool. Joins the R ledger against
  GLLVM.jl's own `docs/design/capability-status.md` (default: live
  `git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" show
  origin/main:docs/design/capability-status.md`, with a fallback to the
  scratchpad copy, both verified working; `--julia <path>` reads a file
  directly). Prints matched rows, R-only rows, and a
  port/accounted/divergence disposition for every Julia-only row, ending in
  a `CLOSURE: PASS`/`FAIL` line. `--check-names` additionally asserts 0
  near-misses and the four required grouping-level rows.
- `tests/testthat/test-gapclose-parity-ledger.R` -- the five required tests,
  pure R, nothing skipped.
- `dev/gapclose/B-parity-notes.md` -- vocabulary map, collision resolutions,
  disposition table, UNVERIFIED list, mission-control paste-ready note.

Not created by this task (present in the shared worktree from a concurrent
lane, `recon-0-abort-inventory`, left untouched):
`dev/gapclose/abort-inventory-notes.md`, `dev/gapclose/abort-inventory.tsv`.

## `build-capability-status.R --check`

```
$ Rscript dev/gapclose/build-capability-status.R --check
capability-status.md up to date; 76 rows; 0 unmapped register rows
```
(exit 0)

## CORRECTION (2026-09-02): B1 status-inflation bug, found by adversarial review

A fresh Opus adversarial review (`/private/tmp/claude-503/.../scratchpad/verify-opus.md`,
finding B1, BLOCKING) found that `normalize_status()` in `tools/parity_ledger.R`
rewrote **every** non-canonical status word to `implemented` -- including the
R ledger's own two honesty statuses `scope-limited` and `point-fit-recovery`
(defined in `docs/design/capability-status.md`'s own Vocabulary section).
Both ledgers were parsed through the same function with the same 4-word
Julia-only canonical set, so **24 of the 44 "matched" rows printed
`R=implemented` when the generated R ledger actually said `scope-limited`**,
and were flagged `AGREE` against Julia's genuine `implemented` -- precisely
the false-"matched" the original B1/B2 brief warned is worse than an
unmatched row. The `R-NARROWER` branch that was supposed to catch this case
was dead code: it tested `rr$status %in% c("scope-limited",
"point-fit-recovery")`, a condition normalization had already made
unreachable. `CLOSURE: PASS` and the report below (now superseded) were
computed over that inflated field.

**Fix:** `normalize_status()` and `parse_capability_tables()` now take a
`canonical` parameter -- `JULIA_CANONICAL <- c("implemented", "planned",
"missing", "rejected")` for the Julia side, `R_CANONICAL <- c("implemented",
"scope-limited", "point-fit-recovery", "planned", "rejected")` for the R
side -- so each side's real vocabulary survives the join. The non-canonical
fallback (Julia's own "**observed**"/"Fisher" markers) still applies, but
only for words outside THAT side's own canonical set. The matched-row flag
is now: `AGREE` (identical canonical word), `R-NARROWER` (Julia
`implemented`, R `scope-limited`/`point-fit-recovery`), `J-NARROWER` (the
reverse: R `implemented`, Julia `planned`/`missing`/`rejected`), or `DIFFER`
(anything else, e.g. `rejected` vs `implemented`, or -- see AGHQ below -- R
`scope-limited` vs Julia `missing`). A dedicated `R-NARROWER ROWS` section is
now printed **unconditionally** (never gated behind a flag) so these rows
cannot be hidden inside the matched table alone, and `CLOSURE` now requires
`r_narrower_not_hidden` (a structural re-derivation of the printed count
against `matched_flags`) in addition to the disposition/near-miss/grouping-
level/collision checks -- CLOSURE is no longer PASS merely because
dispositions exist.

**Correction to the reviewer's own suggested test:** the review's fix
request named AGHQ as "a known" R-NARROWER row. Running the corrected tool
shows this is not so: `AGHQ estimator` is `R=scope-limited, Julia=missing`
-- `DIFFER`, not `R-NARROWER` (R-NARROWER requires Julia `implemented`; here
Julia has NOTHING and R has a real, if opt-in, capability -- the opposite
relationship). This matches `dev/gapclose/B-parity-notes.md`'s own prior
statement that AGHQ "genuinely disagrees" -- it was never claimed to be
R-narrower, only mis-displayed as `AGREE` by the bug. Test (7) below uses
`binomial` instead (Julia `implemented`, R `scope-limited` via the FAM-02/
03/04 link split), which the corrected run confirms is a genuine
R-NARROWER row.

## `parity_ledger.R --check-names` (post-fix)

```
$ Rscript tools/parity_ledger.R --check-names
[... matched / R-narrower / R-only / Julia-only sections omitted here, full output below ...]

--check-names
0 near-miss
all 4 grouping-level rows present (unit / unit_obs / cluster / cluster2)

CLOSURE: PASS -- every one of 29 Julia-only rows carries a port/accounted/divergence disposition, 0 near-misses, all 4 grouping-level rows present, collision rows join correctly, all 16 R-NARROWER row(s) listed (not hidden)
```
(exit 0)

## `parity_ledger.R --ref origin/main` (head + counts + CLOSURE line, post-fix)

```
$ Rscript tools/parity_ledger.R --ref origin/main
R ledger:     /Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902/docs/design/capability-status.md (76 rows)
Julia ledger: git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" show origin/main:docs/design/capability-status.md (73 rows)

COUNTS: 44 matched (15 AGREE, 16 R-NARROWER, 4 J-NARROWER, 9 DIFFER), 32 R-only, 29 Julia-only

MATCHED ROWS (44)
  [R-NARROWER ] none × indep (`indep()` / ordinary independent RE)                    R=scope-limited        Julia=implemented
  [R-NARROWER ] none × dep (`dep()` / unstructured trait covariance)                  R=scope-limited        Julia=implemented
  [R-NARROWER ] none × latent (`latent()` / ordinary LV GLLVM)                        R=scope-limited        Julia=implemented
  [R-NARROWER ] phylogenetic × indep (`phylo_indep()`)                                R=scope-limited        Julia=implemented
  [J-NARROWER ] phylogenetic × dep (`phylo_dep()`)                                    R=implemented          Julia=planned
  [AGREE      ] phylogenetic × latent (`phylo_latent()`)                              R=implemented          Julia=implemented
  [... 38 more matched rows ...]

R-NARROWER ROWS (16) -- Julia claims `implemented`, R honestly hedges
  none × indep (`indep()` / ordinary independent RE)                    R=scope-limited        Julia=implemented
  none × dep (`dep()` / unstructured trait covariance)                  R=scope-limited        Julia=implemented
  none × latent (`latent()` / ordinary LV GLLVM)                        R=scope-limited        Julia=implemented
  phylogenetic × indep (`phylo_indep()`)                                R=scope-limited        Julia=implemented
  animal × indep (`animal_indep()`)                                     R=scope-limited        Julia=implemented
  spatial × indep (`spatial_indep()`)                                   R=scope-limited        Julia=implemented
  spatial × latent (`spatial_latent()`)                                 R=scope-limited        Julia=implemented
  poisson                                                                R=scope-limited        Julia=implemented
  nbinom2                                                                R=scope-limited        Julia=implemented
  binomial                                                               R=scope-limited        Julia=implemented
  truncated_poisson                                                      R=scope-limited        Julia=implemented
  truncated_nbinom2                                                      R=scope-limited        Julia=implemented
  Profile-likelihood intervals                                           R=scope-limited        Julia=implemented
  VA / ELBO alternative (selected families; not R-default)               R=scope-limited        Julia=implemented
  Missing responses (NA / mask)                                          R=scope-limited        Julia=implemented
  Latent scores on covariates `latent(..., lv = ~ x)` ordinary           R=scope-limited        Julia=implemented

[... AHEAD OF gllvmTMB (29 Julia-only, all dispositioned: 8 port, 21 accounted) ...]
[... AHEAD OF GLLVM.jl (32 R-only, printed for symmetry) ...]

CLOSURE: PASS -- every one of 29 Julia-only rows carries a port/accounted/divergence disposition, 0 near-misses, all 4 grouping-level rows present, collision rows join correctly, all 16 R-NARROWER row(s) listed (not hidden)
```
(exit 0; identical 44/15/16/4/9/32/29 split and `CLOSURE: PASS` whether
reached via `--ref origin/main`, the default `--julia-repo`, an explicit
`--julia <file>`, or the git-failure fallback path -- all four re-run
post-fix.)

## Test summary (post-fix)

```
$ Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-parity-ledger.R")'
TEST SUMMARY: 8 test blocks, 32 assertions passed, 0 failed, 0 skipped, 0 warnings
```

The original 5 required tests (still PASS, now checking the honest field)
plus the 2 tests added for this correction:

1. generator `--check` passes on the committed ledger -- PASS
2. all 4 grouping-level rows exist -- PASS
3. `--check-names` reports 0 near-miss against the scratchpad Julia copy --
   PASS
4. `parity_ledger.R` ends with `CLOSURE: PASS` -- PASS
5. `cumulative_logit` never joins to Julia's ordinal row -- PASS
6. **(new)** the tool's printed `R=<status>` for every matched row equals
   the R ledger's own Status column, independently re-parsed (the
   reviewer's exact check) -- PASS, 44/44 matched rows checked, 0 mismatches
7. **(new)** at least one R-NARROWER row exists given the current ledgers
   (`binomial`, verified) -- PASS, 16 such rows found

## UNVERIFIED list

Five of the disposition table's `accounted` entries could not be grounded in
the text actually read from GLLVM.jl's `docs/design/capability-status.md`
(full read, ~610 lines, live `origin/main` of the Dropbox checkout, this
build) and are marked `UNVERIFIED:` in `tools/parity_ledger.R`'s `ACCOUNTED`
table -- inert (never fire against the live Julia ledger; confirmed by the
`CLOSURE: PASS` run above, where none of the 29 real Julia-only rows needed
them) unless a future Julia-ledger edit adds matching content:

- **relaxed clock**
- **node-frame gradient**
- **Takahashi**
- **EM family**
- **pPCA init**

Two of the brief's items WERE grounded directly in the file's own prose
(`Felsenstein contrasts`, `edge-incidence` -- the covariance-grid section's
note on the three equivalent phylo likelihood representations), and
`Laplace curvature contract` is grounded in the file's own dedicated
section (deliberately excluded from row-level parsing, since it uses a
different table header than `Capability | Status`). Full sourcing and
reasoning for every disposition entry: `dev/gapclose/B-parity-notes.md`.

## Deviation from the register's undercount

The brief estimated "≈221 rows" for the register; the actual count read by
the generator's live regex parse is **271-275** (271 under the ratified
`FG-`/`FAM-`/... ID convention, plus a 4-row "Structured source strength
arc" section explicitly marked "2026-08-31, local candidate only" that uses
a bare, non-backtick-quoted status format -- the generator's parser handles
both formats). All of them map to a ledger row or an explicit
`UNMAPPED_BY_DESIGN` reason; `--check` prints `0 unmapped register rows`.
