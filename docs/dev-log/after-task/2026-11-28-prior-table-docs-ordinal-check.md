# Prior-table scope and ordinal help check

## Goal and changes

Help applied readers distinguish a named kernel's trait-specific Psi SD from the Gaussian residual SD and from grouping-factor random-effect SDs. The prior-table article now names the Psi target in its description and introduction and states the grouping-factor boundary. The validation-debt register records the shared-table routes as `FE-PRIOR-02`, partial; the half-normal control remains the separate `KER-03B` slice.

The ordinal help test now resolves source files with `gllvmTMB_pkg_file()`. This keeps the underflow wording check active in a source checkout and in the package-check layouts used by GitHub. No likelihood, formula, exported function or fitted example changed.

## Evidence and tests of the tests

GitHub R-CMD-check run `46082255226` failed on source `540be304` because the ordinal help test looked for `../../man/ordinal_logit.Rd`; the page exists in the package source but not at that path in the check layout. A reproduction with the original test in a planted `00_pkg_src` layout failed with the same missing-path failure and error. The corrected test passed seven expectations in each of a checkout layout and two package-check layouts. A missing-page control failed with the expected source-file error; no skip was added.

The candidate's production code is identical to `540be304`, on which the public-table derivative and order gate passed 146 checks and the 815-file inventory passed across the original run and exact Git-backed replays. The original controller failure and the replay remain separate evidence. On candidate `2e0190f8`, `pkgdown::check_pkgdown()` reported no problems, and the prior article rendered with the current production code and a source-path assertion. The page-only output SHA-256 is `c914347c0170a179b83c64c30ef3dc4770e4026d9610307f57a292b5e301e975`.

## Consistency and limitations

A scoped Rose-perspective consistency check compared the article introduction, supported-rows table and example with the source tests and the partial validation register. The table and example already included the named-kernel Psi SD; the introduction now agrees with them. The natural-SD Gamma table route remains distinct from the half-normal control. The register entry is `partial`, because broader model routes, calibrated uncertainty, and the GLLVM R-to-Julia bridge are not established. The earlier fixture review and oracle evidence remain source-bound to their recorded versions.

The first article-check attempt passed `pkgdown::check_pkgdown()` but stopped before rendering because its output directory was not supplied. A separate corrected attempt rendered successfully. The original GitHub failure and both attempts are preserved. At this check, the existing GitHub coverage run was queued; repository CI pacing required it to finish before the follow-up push. No PR was merged or released.

The Psi Gamma guide now states that the mean must be finite and positive and
the shape finite and greater than one. The article rendered on unchanged
production source with exit 0; rendered HTML SHA-256:
`30b7db38668550691e2ba56ad0044328ffc3b0daa15f470ddc7dc5fd1729f101`.

The capability-ledger generator now accounts for the partial shared-table
record without claiming a row in the frozen Julia comparison ledger. The
generator and its `--check` passed with zero unaccounted rows; the focused
parity-ledger test passed in an isolated Git-backed checkout. The repeated
Beta MSPL decomposition failure is separate and remains unresolved.
