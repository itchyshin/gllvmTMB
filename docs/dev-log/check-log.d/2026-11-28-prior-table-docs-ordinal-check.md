# Prior-table scope and ordinal help check

The R-CMD-check failure on source `540be304` was reproduced with the original ordinal help test in a planted package-check layout. The corrected test uses `gllvmTMB_pkg_file()` and passed seven expectations in each of three checkout or package-check layouts. A missing-page control failed with the expected source-file error.

The corrected prior-table article on candidate `2e0190f8` rendered on the same production code as `540be304`; HTML SHA-256 `c914347c0170a179b83c64c30ef3dc4770e4026d9610307f57a292b5e301e975`. `pkgdown::check_pkgdown()` reported no problems. The first attempt stopped after that check because its output directory was not supplied; the second rendered successfully. The source-bound test and documentation logs are in `/Users/z3437171/.codex/evidence/generalized-prior-20261128/gllvm-ordinal-check-layout/` and `/home/snakagaw/hsq_work/generalized-prior-table-arc/gllvm-doc-ci-fix-2e0190f8/`.

Register row `FE-PRIOR-02` records the shared prior-table routes as partial. At this check, GitHub coverage was queued and the corrected candidate awaited that run before push. No merge or release was performed.

The Psi Gamma guide now states that the mean must be finite and positive and
the shape finite and greater than one. The article rendered on unchanged
production source with exit 0; rendered HTML SHA-256:
`30b7db38668550691e2ba56ad0044328ffc3b0daa15f470ddc7dc5fd1729f101`.

The capability-ledger generator now accounts for the partial shared-table
record without claiming a row in the frozen Julia comparison ledger. The
generator and its `--check` passed with zero unaccounted rows; the focused
parity-ledger test passed in an isolated Git-backed checkout. The repeated
Beta MSPL decomposition failure is separate and remains unresolved.
