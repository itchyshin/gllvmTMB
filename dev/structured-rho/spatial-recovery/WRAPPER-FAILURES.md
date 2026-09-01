# Wrapper failures retained

## Engineering repair 01

- Candidate bundle: `11dbf4dbb02dd36c60e19b4ed238747f253e5d7ef3d762cd74724dc2eab0439b`
- Command: `python3 dev/structured-rho/spatial-recovery/run-engineering.py /home/snakagaw/spatial-rho-recovery-8c1f884ef`
- Outcome: failed before output-directory creation, ledger mutation, or optimizer launch.
- Error: `AttributeError: 'list' object has no attribute 'items'` while verifying
  the engineering fixture manifest.
- Accounting: one of the 32 engineering/repair attempts consumed; zero of the
  eight planned toy optimizer attempts and zero retained attempts consumed.
- Repair: serialize named fixture hashes as a JSON object and allow explicitly
  retained pre-launch repair rows without allowing any planned job ID to repeat.

## Engineering repair 02

- Candidate bundle: `9c78c7df116554178e72015b9713f69e1f258350349e9e664b10ba39cb87ab6b`
- Outcome: failed before output-directory creation, ledger mutation, or
  optimizer launch.
- Error: `FileNotFoundError` because `jsonlite` encoded list keys as numeric
  indices rather than file paths.
- Accounting: a second engineering/repair attempt consumed; zero toy optimizer
  attempts and zero retained attempts consumed.
- Repair: use an explicit cross-language array of `{path, md5}` records.

## Engineering repair 03

- Candidate: working tree after `e461d79ff`, before a new bundle was staged.
- Outcome: local fixture-record validation failed; nothing was deployed and no
  optimizer launched.
- Error: relative fixture paths were truncated because `list.files()` paths
  were compared with the character length of `normalizePath(dest)`.
- Accounting: a third engineering/repair attempt consumed; zero toy optimizer
  attempts and zero retained attempts consumed.
- Repair: normalize every file path before stripping the normalized fixture
  root prefix.

## Engineering smoke batch 01

- Candidate bundle: `698609830dfbb7b91dfc82cab68a77abf14b9edd22de01a491bc69c3179324e1`.
- Outcome: all eight planned fixed/estimated toy fits returned terminal errors
  before an optimizer entry was created.
- Error: `make_mesh() projection has 40 rows but the long-format data has 320.`
- Accounting: eight engineering attempts consumed. Together with the three
  earlier repair attempts, 11 of the 32 engineering attempts are used; zero
  retained attempts are used.
- Repair: build the production mesh on the repeated long-format template, then
  select one projection row per group for the independent source-level DGP and
  covariance oracle. Assert that expanding those source-level rows reproduces
  the complete production projection matrix.

## Engineering repair 04

- Candidate: working tree after the long-format projection repair.
- Outcome: fixture generation and its internal projection assertions passed;
  the separate local inspection command then used a duplicated `fixtures/`
  path and could not reopen `indep.rds`.
- Accounting: one engineering/repair attempt consumed; no optimizer and no
  retained attempt was launched. Total engineering usage is 12 of 32.
- Repair: inspect the data path relative to the already resolved fixture
  directory.

## Engineering repair 05

- Candidate bundle: `0b97295770c0474106834a2b317bec8eaa6fdf90aa6fe053bcb8f791ac9b0bb8`.
- Outcome: exact installation passed, but pre-run inspection found that the
  repaired fixture still named its jobs `spatial-engineering-01` through `08`,
  which are immutable IDs from the failed first batch. The runner was not
  invoked.
- Accounting: one engineering/repair attempt consumed; no optimizer and no
  retained attempt was launched. Total engineering usage is 13 of 32.
- Repair: assign unique IDs `spatial-engineering-09` through `16` and distinct
  fit seeds to the repaired smoke batch.

## Engineering repair 06

- Candidate bundle: `30434660f352573591ed0e8e0301c481827c07acdf5c270db81c59d02683a465`.
- Outcome: data generation stopped before retained fitting because the
  irregular base `K = A Q^-1 A'` failed a strict positive-definite assertion.
- Diagnosis: the smallest base eigenvalue was `-2.10e-14` relative to a largest
  eigenvalue of `81.63`, with numerical rank 103. The actual attenuated
  covariances were positive definite: minimum eigenvalues `0.493` at `rho=0.3`
  and `0.211` at `rho=0.7`, and both Cholesky checks passed.
- Accounting: one engineering/repair attempt consumed; no retained attempt was
  launched. Total engineering usage is 22 of 32.
- Repair: use a scale-aware positive-semidefinite tolerance for base `K`, then
  require and record strict positive definiteness for each study `K_rho`.
