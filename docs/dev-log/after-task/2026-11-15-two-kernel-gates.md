# Check the fixed-rho grid against a dense likelihood

The previous test required a very large gain over the null. That gain came from a poor single-start null fit. The revised test retains the planted-versus-null direction for the seeded fixture and checks the kernel, dense Gaussian likelihood and a feasible null optimization point directly.

The large-gain claim is no longer asserted. The focused target passed; other failing tests and full release checks remain open. The result is not a claim of general detection power or coverage.

With the maintainer's approval, the null-grid test now compares every seeded fit with a separately optimized dense likelihood and retains the other null and overfit checks. The historical bound on every phylogenetic Gamma norm is no longer an acceptance claim; its failing seeds are reported. The focused null target passed, without establishing null-recovery calibration.

The high-overlap test retains exact-duplicate equivalence. For a diagonally shrunk kernel it now checks the correct covariance decomposition and dense likelihood instead of requiring fitted likelihoods to be within two units. This approved change drops that empirical closeness claim. Its focused target passed; full integrated checks remain open.
