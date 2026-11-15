# Synthetic fixed-error bootstrap forwarding probe

The synthetic single-kernel probe completed one initial fit and one bootstrap
refit. Both returned optimizer code 0. The bootstrap refit entered
`gllvmTMB()` with `known_sigma_eps = 1e-4`, returned that same fixed SD,
and retained an all-`NA` `log_sigma_eps` map with parameter value
`log(1e-4) = -9.21034`. The bootstrap object recorded `n_failed = 0`.

The run took 11.83 seconds wall time under a 300-second process-group limit
with BLAS, OpenMP and MKL threads set to one. It used 10 synthetic species,
three Gaussian traits and one named kernel. One bootstrap replicate cannot
support an interval: the package reported a zero coverage ceiling for this
replicate count. Internal refit warnings are suppressed by `bootstrap_Sigma()`;
the outer warning log is not a complete record of those warnings.

The probe ran with `pkgload::load_all()` against an uncommitted worktree based
on `abf3e905fb9e22f5eca9b8dd01c9ea476fde4ee2`. The supervisor recorded all
R and source-file SHA-256 hashes before and after; they were unchanged. Key
hashes were `7a16ba01f8af8e96030a552d28fc52ca8fba4534c4902a8a6991a5427b27b45f`
for `R/fit-multi.R`,
`6de47e770d767e9238865361c956ce40bbc7040a38b98a6e8dc94fdb632c980a`
for `R/gllvmTMB.R`, and
`9b91c20b0863f5b246f3454cd0f3c0116317ade5d62738038ebf7410d902eadf`
for `R/bootstrap-sigma.R`. The loaded temporary DLL's MD5 was
`a9978719fe7f4e71b4652e1d6d0132be` before and after. Its build lineage was
not independently verified. Re-run against a clean final-source build before
using this as final-source evidence.

The runner is `run.py`; `probe.R` contains the synthetic generator and traces.
`output/run.log`, `output/result.rds` and `output/supervisor.json` retain the
result, warnings, exact command, hashes and process status. The probe checks
argument forwarding and fixed mapping; recovery and interval calibration
remain untested.
