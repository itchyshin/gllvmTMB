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

## `parity_ledger.R --check-names`

```
$ Rscript tools/parity_ledger.R --check-names
[... matched / R-only / Julia-only sections omitted here, full output below ...]

--check-names
0 near-miss
all 4 grouping-level rows present (unit / unit_obs / cluster / cluster2)

CLOSURE: PASS -- every one of 29 Julia-only rows carries a port/accounted/divergence disposition, 0 near-misses, all 4 grouping-level rows present, collision rows join correctly
```
(exit 0)

## `parity_ledger.R --ref origin/main` (head + counts + CLOSURE line)

```
$ Rscript tools/parity_ledger.R --ref origin/main
R ledger:     /Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902/docs/design/capability-status.md (76 rows)
Julia ledger: git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" show origin/main:docs/design/capability-status.md (73 rows)

COUNTS: 44 matched, 32 R-only, 29 Julia-only

MATCHED ROWS (44)
  [AGREE      ] none × indep (`indep()` / ordinary independent RE)                    R=implemented          Julia=implemented
  [AGREE      ] none × dep (`dep()` / unstructured trait covariance)                  R=implemented          Julia=implemented
  [AGREE      ] none × latent (`latent()` / ordinary LV GLLVM)                        R=implemented          Julia=implemented
  [AGREE      ] phylogenetic × indep (`phylo_indep()`)                                R=implemented          Julia=implemented
  [... 39 more matched rows, 4 with a divergence note (student, AGHQ estimator,
       the 3 kernel × * rows) and 8 flagged R-AHEAD ...]

[... AHEAD OF gllvmTMB (29 Julia-only, all dispositioned: 8 port, 21 accounted) ...]
[... AHEAD OF GLLVM.jl (32 R-only, printed for symmetry) ...]

CLOSURE: PASS -- every one of 29 Julia-only rows carries a port/accounted/divergence disposition, 0 near-misses, all 4 grouping-level rows present, collision rows join correctly
```
(exit 0; identical result whether reached via `--ref origin/main`, the
default `--julia-repo`, an explicit `--julia <file>`, or the git-failure
fallback path -- all four were run and produced the same 44/32/29 split and
`CLOSURE: PASS`.)

## Test summary

```
$ Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-parity-ledger.R")'
TEST SUMMARY: 6 test blocks, 21 assertions passed, 0 failed, 0 skipped, 0 warnings
```

The 5 required tests, each its own `test_that()` block:

1. generator `--check` passes on the committed ledger (after a live
   regeneration, since the register is being edited concurrently) -- PASS
2. all 4 grouping-level rows exist -- PASS
3. `--check-names` reports 0 near-miss against the scratchpad Julia copy --
   PASS
4. `parity_ledger.R` ends with `CLOSURE: PASS` -- PASS
5. `cumulative_logit` never joins to Julia's ordinal row (structural check:
   the R row is R-only in the matched/Julia-only partition, is textually the
   missing-predictor imputation family, and Julia's combined
   `ordinal_probit / cumulative_logit` row is separately dispositioned
   `port`) -- PASS

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
