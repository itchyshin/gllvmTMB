# Ultra Plan — Integrated-JSDM failure-mechanism experiment

## GOAL

Solo platform: Codex
Deliverable: a retained, paired sentinel experiment that triages candidate
iJSDM failure mechanisms and names the next confirmatory experiment or focused
engineering investigation. It does not estimate mechanism prevalence or prove
cause.
HEADLINE: diagnose before modifying the engine or rerunning production.
IN PARALLEL: prior-work/ownership sweep, seed selection, estimand decomposition,
and spatial diagnostic design.
DEFER: threshold changes, replacement production attempts, interval
implementation, public promotion, private-fit routes, and unrelated
`*_coef`/`*_slope` work.
DISCIPLINE: public fitting route only · existing production evidence remains
immutable · four-fit smoke first · Totoro · expected diagnostic compute under
10 minutes · retained all-attempt records.

## Prior-work and ownership receipt

- Platform: Codex. Lane: `codex/isdm-identifiability-diagnostic`.
- Fresh worktree: `/Users/z3437171/local-scratch/lanes/gllvmTMB-isdm-identifiability-diagnostic`.
- Base: exact `origin/main` SHA `09eca7b1eb9018958bad367be824871161a60af1`,
  tree `fb979daa5d9a93d0804a053ff1bb00eced47ad09`.
- Exact-main CI: run 33272534580 passed after PR 1227.
- Package-code delta from the previous qualified production pin `c5bb0b80`:
  none. The delta contains only requalification evidence/tests and shared
  dev-log/register updates.
- Repository route manifest loaded. It says recovery-to-truth outranks a lone
  second-order flag, and warns that a missing `fit$sdr` is not a Hessian result.
  This experiment therefore records both recovery and populated curvature
  objects.
- Brain search returned no newer integrated-JSDM rescue decision. Repository
  evidence is authoritative.
- GLLVM.jl contains useful general Hessian/identifiability practice but no
  directly reusable iJSDM spatial rescue.
- The standard goal launcher was attempted and failed because its wrapper
  resolves to absent `~/.codex/tools/lane_launch.sh`. The canonical hub launcher
  was inspected; the lane was created directly with equivalent git-worktree
  semantics and the required `codex/` branch prefix.
- Lease granted for `LOOP/`,
  `dev/isdm-requalification/diagnostic-rescue/`, and dedicated diagnostic tests.
  No package R/C++/API path is owned.
- Historical immutable root:
  `/home/snakagaw/gllvm_work/isdm-requalification/c5bb0b80/`.
  The selector must verify `production-point/raw-manifest-sha256.txt` with
  `sha256sum -c`; that manifest file has SHA-256
  `bfcc17994d2fc9a46c5d9f372be63ce2074629a2fe6dbd9a01df156d35e5e092`.
  It also binds v3 adjudication SHA-256
  `32c7a9cb325d1e45f015b38b53a8722473e0a9ffc254d3f5e79fb2c6c22001ab`
  and v3 chain-manifest SHA-256
  `b452c79c2328a88a1821bee3b1925ccd357c7af1b3dbb4ea7453509127bf9bfa`.
- New fail-if-exists result root:
  `/home/snakagaw/gllvm_work/isdm-identifiability-diagnostic/09eca7b1-20260829/`.
  It is never reused or overwritten.

## Frozen evidence that motivates the experiment

- Nonspatial fixed coefficients and `Sigma` passed, but total conditional
  surfaces, weak-overlap surfaces, species-1 `Psi`, and two weak/full
  coefficient-RMSE ratios failed.
- Increasing cells from 150 to 810 improved `Psi` substantially but barely
  changed surface accuracy. This suggests, but does not prove, that information
  per cell-trait or the scored conditional component is limiting.
- Spatial fits all returned finite objectives, but only 302/800 were strictly
  eligible. The exact split was 302 converged/PD, 361 converged/non-PD,
  131 nonconverged/non-PD, and 6 nonconverged/PD.
- Eligible spatial fits predicted withheld surfaces accurately. The projection
  machinery is therefore not the primary suspect.

## Symbolic estimands

For cell `c`, trait `t`, and source `d`, the nonspatial DGP is

`eta_ctd = alpha_t + beta_t x_c + gamma_d + delta_d q_cd + lambda_t u_c + e_ct`,

with `u_c ~ N(0,1)` and `e_ct ~ N(0, psi_t)`. Three nested ecological targets
are scored from each returned public-route fit:

1. fixed ecological mean: `m_ct = alpha_t + beta_t x_c`;
2. shared latent surface: `s_ct = m_ct + lambda_t u_c`;
3. full conditional surface: `h_ct = s_ct + e_ct`.

The source-free prediction grid sets `gamma_d = delta_d q_cd = 0` and the
offset to zero. Raw latent axes are never compared; only the resulting surfaces
and rotation-invariant covariance summaries are interpreted.

The spatial DGP replaces `u_c` with the projected SPDE field `w(c)`:

`eta_ctd = alpha_t + beta_t x_c + gamma_d + delta_d q_cd + lambda_t w(c)`.

Curvature diagnostics are descriptive: eigenvalues and eigenvectors are used
to locate weak parameter blocks, never as a stand-alone recovery verdict.

## ADEMP experiment

### Aims

1. Describe which nonspatial surface component loses recovery in eight frozen
   paired sentinels.
2. Screen whether three independent observations per observed source-cell-
   trait improve that component and `Psi` under an otherwise paired DGP.
3. Screen whether spatial sentinel eligibility is sensitive to optimizer basin
   or termination, or remains associated with non-positive curvature.
4. Describe recurring, parameterization-dependent parameter blocks in the
   weakest Hessian directions.

### Data-generating mechanisms

Nonspatial uses the existing eight cells:
`n_sources {2,3} × overlap {full,weak} × n_cells {150,810}`. One deterministic
paired production seed is chosen per cell. Within each `(n_sources, n_cells)`
combination, choose the smallest `pair_id` present in both overlap regimes,
then retain both its full and weak members. Record native `task_id`, `pair_id`,
shared `structure_seed`, and each member's distinct observation/response seed.
Refuse missing partners, ambiguity, or duplicate selected task/seed identities.
Each receives:

- `baseline`: exact production-fixture replay with one response per observed
  source-cell-trait;
- `rep3`: byte-identical baseline rows as `replicate_id = 1`, plus two newly
  generated independent responses as `replicate_id = 2,3`. The added streams
  use registered seeds `203000000 + 2 * native_task_id` and the next integer.
  They preserve row order, truth, support, covariates, factor levels, and both
  Poisson and Bernoulli laws exactly.

This is 8 × 2 = 16 fits.

Spatial uses the four cells `n_sources {2,3} × overlap {full,weak}`. Within
each cell, the smallest production seed in each universally populated outcome
class is chosen: converged/PD, converged/non-PD, and
nonconverged/non-PD. Each exact fixture is fit sequentially in one R process in
the order default → BFGS continuation → nlminb5, with:

- `default`: the production public-route control;
- `nlminb5`: public `gllvmTMBcontrol(n_init = 5, init_jitter = 0.3)`, screening
  basin sensitivity while retaining all five restart rows and costs;
- `bfgs_continuation`: public `gllvmTMBcontrol(start_from = default_fit,
  n_init = 1, init_jitter = 0, optimizer = "optim",
  optArgs = list(method = "BFGS", control = list(maxit = 5000,
  reltol = 1e-10)))`, screening termination sensitivity from the returned
  default point. If the default fit is unavailable, this dependent task is
  terminal unavailable and is not replaced.

Reset a registered optimizer RNG seed before every arm. Verify that default
and the first `nlminb5` start hashes match. For BFGS continuation, verify and
hash copied `b_fix`, `log_kappa_spde`, `theta_rr_spde_lv`, and
`omega_spde_lv` blocks from the live default fit. A failed copy check makes the
continuation unavailable. The exact default replay must reproduce its original
production outcome class before transition interpretation.

This is 4 × 3 seeds × 3 controls = 36 planned task identities and up to 36
optimizer entries. Total planned diagnostic denominator: 52.

### Estimands and diagnostics

- correlation and normalized RMSE for fixed, shared, and full surfaces. Fitted
  fixed is the neutral ecological design times `b_fix`; shared adds the
  rotation-invariant product `Lambda_B z_B`; full adds fitted `s_B`. Full must
  equal public `predict(..., type = "link")` on the neutral grid within
  `1e-10`, and a sign-flipped loading/score control must leave shared unchanged;
- `Sigma` and `Psi` relative errors for nonspatial fits;
- paired baseline-to-rep3 changes within design cell;
- optimizer convergence, finite objective, maximum gradient, PD-Hessian state,
  selected restart, and objective change;
- freshly reevaluated same-objective values and their difference from the
  optimizer-reported objective;
- smallest five eigenvalues of the symmetrized direct marginal fixed Hessian
  from `optimHess(par, fn, gr)`, after refreshing the live ADFun state;
- conditional-random Hessian PD/minimum-eigenvalue diagnostics from
  `obj$env$spHess(last.par, random = TRUE)`;
- smallest five joint-precision eigenvalues from explicit post-fit
  `TMB::sdreport(..., hessian.fixed = Hf, getJointPrecision = TRUE,
  skip.delta.method = TRUE)`. This is attempted in-process for every arm, has
  its own availability denominator/reason, and is densified only when dimension
  is at most 500; otherwise it is unavailable;
- raw native-scale and relative-coordinate-scaled squared parameter-block mass
  in the weakest eigenvector, block-size-normalized mass, exact parameter-index
  maps, and top positional coordinates. Attribution is called ambiguous if
  native and relative block rankings disagree, and is always labelled
  parameterization-dependent. Freeze `D = diag(pmax(1, abs(par)))` and
  `H_rel = D %*% Hf %*% D`. For the eigenvector of the smallest algebraic
  eigenvalue, block total mass is `M_b = sum(v_j^2)`, size-adjusted mass is
  `A_b = M_b / n_b`, and normalized mass is `N_b = A_b / sum(A)`. The
  `CURVATURE_SIGNAL` uses `N_b`. Also report the closest-to-zero eigenvector as
  secondary. The direct marginal Hessian is primary;
- transitions among converged/PD, converged/non-PD,
  nonconverged/non-PD, nonconverged/PD, error, and unavailable states.

The curvature operation order is frozen because the ADFun is mutable:
`obj$fn(par)`; align `last.par.best <- last.par`; compute `Hf` with
`optimHess`; replay and align again; then compute conditional `spHess` and
`sdreport`. The direct `chol(Hf)` PD result must equal
`fit$sd_report$pdHess`; a mismatch makes primary curvature unavailable. All
optimizer comparisons use the freshly reevaluated `F(par)`, never only the
stored optimizer objective.

### Seed selection and denominator policy

The selection algorithm is frozen before reading individual seed identities.
It verifies the pinned original raw manifest, reads native production task
specs, retains selected native terminal-record hashes, and writes a checksum-
bound seed manifest. It refuses a missing outcome class, duplicate seed, source
mismatch, or changed raw record. The harness manifest is frozen locally before
transfer; remote qualification compares received bytes with those precomputed
hashes. Every worker writes a started receipt before fitting and one terminal
receipt after return, error, interruption, or unavailability. An append-only
coordinator reconciliation records planned-not-started tasks as unavailable
and started-without-terminal tasks as interrupted after a stopped process group;
it never overwrites worker receipts. All 52 planned identities remain in the
denominator and no task is replaced.

### Performance measures and decision rules

This is a hypothesis-generating sentinel experiment, not a promotion campaign.
It has no new recovery gate. Report all eight nonspatial paired deltas with
median, IQR, and sign count, and all 36 spatial outcomes/transitions. The
following preregistered screening labels choose only the next investigation:

- `REPLICATION_SIGNAL`: at least 7/8 rep3 fits reduce full-surface nRMSE, the
  median reduction is at least 0.05, at least 7/8 do not reduce full-surface
  correlation, and at least 6/8 reduce species-1 `Psi` relative error with
  median reduction at least 0.10. This selects a confirmatory within-cell-
  information campaign; it does not establish prevalence or cause.
- `ESTIMAND_SIGNAL`: in at least 7/8 baseline sentinels, shared-surface nRMSE is
  at least 0.10 lower than full-surface nRMSE and shared correlation is no lower
  than full correlation. This selects an estimand-focused confirmatory design;
  it never retroactively rescores production.
- `BASIN_SIGNAL`: among the eight originally ineligible sentinels, nlminb5
  converts at least 6 to converged/PD while objective is no worse than default
  by more than `1e-6 * (1 + abs(default))`, maximum gradient is no higher than
  `max(default_gradient, 0.01)`, held-out correlation falls by at most 0.005,
  and held-out nRMSE rises by at most 0.01.
- `TERMINATION_SIGNAL`: the same rule holds for BFGS continuation in at least
  6/8 originally ineligible sentinels.
- `CURVATURE_SIGNAL`: no optimizer signal fires, and one normalized fixed-
  Hessian block is largest in at least 9/12 default sentinels with median
  normalized mass at least 0.50. Native and relative-scale rankings must agree;
  otherwise attribution is `AMBIGUOUS`. This selects a focused curvature
  investigation, not an engine repair.
- Exactly one fired signal selects its named follow-up. Two or more fired
  signals, or no fired signal, yield `MIXED` and select only a narrower
  discriminating experiment.

## Compute gate

Four smoke fits, outside the 52-fit denominator, cover one nonspatial rep3
(including byte-preserved baseline rows and all three estimands), one spatial
default, one spatial nlminb5, and one BFGS continuation from that live default.
Expected wall time is under 2 minutes. The full 52-task experiment is estimated
at 5–10 minutes on Totoro with 16 one-thread workers, well below the 30-minute
line and the 150-core ceiling. A 10-minute live watchdog stops the process group
on estimate overrun, reconciles unfinished tasks without replacement, and
reports; it never relaunches. The launch is allowed only if the smoke retains
four started and four terminal records; verifies the public full-surface
identity, default/first-nlminb5 start-hash equality, BFGS copied-block equality,
and populated primary marginal-curvature diagnostics; matches the exact package
identity; and projects no more than 10 minutes. A longer
projection stops and requires renewed authority even though Totoro's general
target boundary is 30 minutes.

## Execution slices

1. Freeze plan, symbolic alignment, ledger, source/harness identity, and seed
   selection code.
2. Independent Curie, Gauss, and Rose reviews; resolve blocking findings before
   compute.
3. Qualify the exact-main Totoro install and verify the immutable production
   manifest.
4. Run and adjudicate four smoke fits.
5. Conditionally execute exactly 52 diagnostic task identities once; unavailable
   dependencies receive one terminal disposition without optimizer entry.
6. Freeze raw checksums and independently summarize.
7. Review the hypothesis-generating interpretation and choose one bounded next
   confirmatory experiment or engineering investigation.
8. Complete after-task, reconciliation, tests, PR/CI, merge, exact-main
   verification, and lease release. Acquire a fresh narrow shared-doc lease
   before after-task/check-log edits. A final allowlist diff verifier refuses
   package R/C++/API/NEWS/man/design changes. Record compute pin and later
   evidence-landing main separately, proving package-code hashes are unchanged.
   No release or public capability promotion.
