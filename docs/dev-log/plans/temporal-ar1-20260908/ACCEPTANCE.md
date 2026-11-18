🎯 GOAL — approval and executable acceptance contract for the proposed temporal AR1 slice.

# Acceptance ledger

Status: **AWAITING MAINTAINER APPROVAL; ALL IMPLEMENTATION GATES NOT RUN**.
OWNS (planning only): `docs/dev-log/plans/temporal-ar1-20260908/`.
This is the immutable planning specification. After approval, the fresh Terra owner copies it
to ignored `.unlazy/temporal-ar1/` and records actual evidence there, then retains a dated receipt
in the dev log. No `covered` status follows from this file's existence.

For each command below, first run `devtools::load_all()` in the approved worktree, with
`NOT_CRAN=true OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1`. Reject all-skipped tests.
Standard check template (the named test file must exist first):

```sh
NOT_CRAN=true OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript --vanilla -e \
 'devtools::load_all(); testthat::test_file("tests/testthat/test-temporal-ar1-oracles.R", stop_on_failure=TRUE)'
```

Store command, commit, seed, elapsed time, assertion counts, result, warnings and output path.
No numerical gate may be weakened after seeing its result without a recorded methodological
review. The approximate recovery tolerances below are preregistered engineering bars, not
confidence coverage or a general guarantee.

- [ ] **G0 — approval and ownership.** CHECK: human approval cites PLAN.md plus lease/preflight
  refreshed on the execution base; EXPECT: explicit approval, fresh Terra task, no overlap.
  EVIDENCE: pending. Owner Ada. A new lease on engine/fit files is mandatory; the planning lease
  grants no implementation ownership.

- [ ] **G1 — grammar/index admission.** CHECK: run `test-temporal-ar1-parser.R`.
  EXPECT: both formula shapes preserve series, time and explicit replicate metadata; sorted
  pair map is bijective and original rows round-trip. Test permuted rows/traits/series names,
  unequal series lengths, different start values and punctuation in IDs. Reject collisions in
  concatenated labels (use tuple-safe IDs). Every prohibited family, estimator, extra provider,
  rank, fixed/unknown structure, malformed time and duplicate full key errors before TMB.
  Require `replicate = replicate_id` in the replicated long/wide example. Bare `ar1()` remains
  unsupported. EVIDENCE: NOT RUN. Owner Boole.

- [ ] **G2 — fixed-parameter latent-prior dense identity.** CHECK: oracle file, test name
  `temporal prior matches independent dense MVN`.
  EXPECT: compare native objective with z_B temporarily fixed on the test tape to independently
  computed Cholesky MVN NLL including constants; subtract the same fixed observation terms, or
  compare the full joint density. Use phi `(-0.7,0,0.65,0.95)`, distinct series lengths `(3,5)`
  and nonzero fixed score vectors. Maximum absolute NLL difference < `1e-8`; gradients versus
  independent central differences < `1e-5`. The oracle must construct `C_g[i,j]=phi^abs(i-j)`
  directly, not call the production AR1 helper. Include initial-state variance and per-series
  log determinants. EVIDENCE: NOT RUN. Owner Gauss; reviewer Noether.

- [ ] **G3 — Gaussian marginal dense identity and iid reduction.** CHECK: oracle file, tests
  `temporal marginal matches dense replicated covariance` and `phi zero matches ordinary latent`.
  EXPECT: with beta, Lambda, Psi, sigma and phi fixed, compare Laplace-integrated Gaussian NLL
  to dense observation MVN, absolute error < `1e-6`. Build an observation incidence map Z from
  rows to `(pair,trait)` and use
  `V = Z [blockdiag(C_g) %x% (Lambda %*% t(Lambda)) + I_pair %x% Psi] t(Z) + sigma2 * I_obs`
  in a documented pair-major/trait-minor order. Compare likelihood differences too, so an
  omitted constant cannot hide a covariance error. At phi=0 compare against ordinary
  `latent(0 + trait | pair_id)` with the same independent unique companion and residual;
  joint NLL < `1e-8`, integrated NLL < `1e-6`, eta < `1e-10`, covariance < `1e-10`.
  Assert directly that with two replicates both `theta_diag_B` and the Gaussian residual
  dispersion remain free in the TMB map; `s_B` remains a random block. Replicate rows share
  the same pair/trait `s_B` but receive independent response noise. No fitted-parameter
  equality between independent optimisers substitutes for this identity.
  EVIDENCE: NOT RUN. Owner Gauss; reviewer Noether.

- [ ] **G4 — AR1/OU correspondence.** CHECK: oracle file, `regular-time OU equals positive AR1`.
  EXPECT: independently calculate `exp(-kappa*abs(t_i-t_j))` at Delta `(1,2.5)`, phi
  `(0.2,0.6,0.95)`, kappa `-log(phi)/Delta`; max covariance error < `1e-12`, NLL error <
  `1e-8`. Assert negative phi is outside this correspondence and OU API still refuses.
  This tests a kernel identity, not implemented OU estimation. EVIDENCE: NOT RUN. Owner Curie.

- [ ] **G5 — independent series and malformed time.** CHECK: parser/oracle files.
  EXPECT: joint prior equals sum of per-series priors < `1e-10`; changing one series changes
  no other score covariance block. Fixed-parameter results survive row permutation and series
  relabelling. Include the deliberate wrong single-chain construction joining two series and
  require an NLL difference > `1e-3` for the named fixed fixture. Missing, Inf, NaN, gaps,
  fractional time steps, factor time and duplicated full observation keys fail with next-step
  messages. Trait/replicate repetitions at the same occasion remain valid. EVIDENCE: NOT RUN.

- [ ] **G6 — scale/sign/identification.** CHECK: oracle/methods files.
  EXPECT: rank two rejected; stationary score variance fixed one; no extra free scale; one
  phi scalar only. `(Lambda,z) -> (-Lambda,-z)` preserves eta/NLL within `1e-10`; reported
  canonical sign transforms both and preserves covariance. Near-zero anchor diagnosed.
  Numerical near-boundary theta evaluations and gradients finite under the specified smooth
  `(1-1e-6)*tanh(theta)` transform (including theta = -20 and 20), no
  evaluation at |phi|=1. Tests reject the unreplicated free-Psi-plus-free-residual model.
  EVIDENCE: NOT RUN. Owner Noether/Curie.

- [ ] **G7 — small replicated recovery.** CHECK: timed pilot, then
  `test-temporal-ar1-recovery.R` only if the updated estimate is <=30 min (otherwise separate
  approved compute plan). Independent DGP from PLAN.md: G=12, T=20, J=3, R=2; phi
  `(-0.4,0,0.6)`, seeds `(2609081,2609082,2609083)` in each cell. Nine fits total, no seed
  replacement. EXPECT per cell: all fits return finite parameters/objectives; convergence
  diagnostic recorded, `max(abs(obj$gr(opt$par))) <= 1e-3`; mean signed phi error magnitude
  <= `0.15`; median absolute phi error <= `0.20`; median relative Frobenius error of
  `Lambda Lambda^T` <= `0.30`; median relative error of each psi variance and residual
  variance <= `0.35`; fixed-effect mean absolute error <= `0.25`. Report every replicate and
  failure, including Hessian availability and boundary hits. If a bar fails, diagnose before
  changing N, starts or tolerance; larger fixtures require a new estimate. Do not test
  recovery of individual random scores against their realised truth as if shrinkage were
  bias. No interval coverage claim from nine fits. EVIDENCE: NOT RUN. Owner Curie/Fisher.

- [ ] **G8 — simulation/output and fit lifecycle.** CHECK: methods file.
  EXPECT: nonempty ordered pair metadata, phi on natural scale, scores correctly labelled as
  states, covariance and SD/variance units match the symbolic table. `simulate()` must use
  stationary starts per series and transition SD sqrt(1-phi^2), retain iid unique draws shared
  by replicates, then independent observation errors. A fixed innovation-input unit test
  verifies recurrence exactly; many cheap draws at fixed parameters check within/cross-series
  moments against Monte Carlo error, with two-sided bars. Seed repeatability and original row
  order tested. In-sample predict/fitted, logLik, AIC parameter count and update/refit agree;
  unsupported prediction/newdata/forecast/interval/bootstrap routes explicitly refuse, with
  a fixture proving they cannot fall through to iid logic. No edits to active bootstrap or
  paired-interval lanes; coordinate the guard first if required. EVIDENCE: NOT RUN.

- [ ] **G9 — unchanged provider regression and public contract.** CHECK: run existing
  parser/ordinary-latent and affected phylo/spatial/kernel fixture files selected at the
  execution base, plus new tests; `devtools::document(quiet=TRUE)`,
  `pkgdown::check_pkgdown()`, render `temporal-latent` and `api-keyword-grid` with
  `pkgdown::build_articles(articles=c("temporal-latent","api-keyword-grid"),lazy=FALSE)`,
  and local `devtools::check(args="--no-manual",quiet=TRUE)`.
  EXPECT: named non-skipped assertions pass; old models map phi off and add no likelihood
  term/parameter; generated help agrees; both example forms run on the same replicated
  fixture; limitations visible with no register codes on reader surfaces. Registry gets a
  uniquely allocated temporal row initially partial at the demonstrated scope; no claim
  for OU, other families or provider combinations. Enumerate exact existing files and
  commands in the receipt before running them. EVIDENCE: NOT RUN. Owner Grace/Pat/Rose.

- [ ] **G10 — review, integration and honest close.** CHECK: Noether/Gauss likelihood review,
  Boole grammar review, Curie/Fisher fixture review, Pat worked-example read, Rose pre-publish
  and Shannon coordination checks; after-task validator; git diff and 3-OS CI at the exact
  publication candidate only after publication authority exists. EXPECT: no unresolved
  blocking finding; all six repository completion criteria addressed; no merge/release
  claim from local tests. This planning lane never pushes, merges or releases.
  EVIDENCE: NOT RUN.

Planning acceptance (separate from G0–G10): source-grounded contract and file map; symbolic
table complete; initial and transition densities explicit; all required identities and recovery
fixtures specified; ownership and compute boundaries explicit; independent plan review addressed;
three planning artifacts only, local commit and approval-gated fresh-Terra handover.
