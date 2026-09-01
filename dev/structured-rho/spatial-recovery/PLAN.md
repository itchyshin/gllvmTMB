# Structured spatial rho recovery and clean landing

## Goal and authority

Earn bounded point-recovery evidence for spatial source strength when range is
estimated jointly, then construct one compact exact-SHA green draft PR. The
maintainer approved 1,600 retained attempts, Totoro with 12 workers and BLAS
threads one, a measured checkpoint after the first 32 retained attempts, and a
clean draft-PR landing. Merge, release, tag, version bump, publication, rho
intervals, unseen-location recovery, non-Gaussian recovery, competing sources,
and coefficient-rho remain excluded.

## Frozen intended design

- 120 source groups, three complete replicates, six Gaussian traits, residual
  SD 0.6, rho 0.3 or 0.7.
- Four trait forms: independent, dependent, rank-one latent without Psi, and
  rank-one latent with positive Psi.
- Regular-short regime: 12 by 10 grid over `[0,2]^2`, mesh cutoff 0.10,
  generating kappa 2.
- Irregular-long regime: 120 uniform locations over `[0,2]^2` from seed
  320102, mesh cutoff 0.08, generating kappa 0.7.
- Scale each base trait covariance by the reciprocal of the mean diagonal of
  the resolved source covariance. Do not normalize the source covariance.
- Fifty datasets per regime/form/rho cell. Pair one fixed-at-truth fit and one
  estimated-rho fit per dataset: 1,600 attempts total.
- Dataset seeds are `3202000 + dataset_id`; fit seeds are
  `730000 + dataset_id`. The first replication from all 16 cells is the
  32-attempt retained pilot.

## Work order

1. Write the ledger, independent fixture generator, runner, summarizer, and
   pure-logic checks.
2. Obtain bounded Gauss/Noether read-only review of source/range/rho algebra.
3. Run eight toy engineering attempts. All count against the 32-attempt
   engineering ceiling.
4. Freeze, hash, and stage the retained fixtures and exact candidate bundle.
   Base `K = A Q^-1 A'` may be rank deficient, so validate it as positive
   semidefinite with the scale-aware tolerance
   `100 * .Machine$double.eps * max(1, max(abs(eigen(K))))`. Require the actual
   `K_rho` at `rho = 0.3` and `0.7` to be strictly positive definite and admit
   Cholesky factorization; record these checks in the geometry receipt.
5. Run the first 32 retained attempts on Totoro within 30 minutes.
6. Show timing, memory, failures, projection, and the frozen manifest. Do not
   launch the remaining 1,568 attempts without the measured checkpoint.
7. After approval, run the 1,568 non-pilot jobs once with 12 workers, a
   two-hour total ceiling, and an 840-second per-attempt timeout. The runner
   refuses to start unless the exact 32 pilot IDs and the same fixture-manifest
   hash are retained. Then summarize all attempts and obtain Fisher/Rose
   verdicts.
8. Build a fresh compact landing branch from current main, verify at one SHA,
   push it, open a draft PR, and run the authorized CI matrix.

## Budgets and stop rules

Engineering: 32 attempts. Retained: exactly 1,600. Teaching: eight fits.
Package regression: one exact full check plus one attributable repair rerun.
CI: one fast three-OS dispatch and one heavy Ubuntu dispatch. Failures,
timeouts, interruptions, and reporting failures consume attempts. Stop if the
pilot exceeds 30 minutes, any worker exceeds 8 GiB, projected remainder exceeds
two hours, a frozen covariance is invalid, or the approved estimand changes.

## Evidence boundary

Fixed-at-truth fits are diagnostic benchmarks, not estimators. Recovery metrics
are conditional on the immutable numerical-success rule, while all failure
rates use every attempted job. Report rho and kappa bias/RMSE, covariance error,
boundaries, failure mechanisms, runtime, memory, and Monte Carlo uncertainty by
named cell. Public wording may name only passing cells and must retain the
interval, unseen-location, non-Gaussian, and competing-covariance exclusions.
