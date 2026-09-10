🎯 GOAL
```text
Solo platform: Codex; Astra high plans, a FRESH Terra high task implements after approval.
Deliverable: a native temporal AR1 latent-score provider, initially replicated Gaussian, rank 1.
HEADLINE: reuse the loading matrix and z_B storage; change the score prior and occasion indexing.
IN PARALLEL: bounded source reconnaissance and independent mathematical/plan review.
DEFER: OU implementation, higher rank, transition matrices, phi predictors, combined providers,
        Julia bridge, bootstrap/paired intervals, scale naming, release, and recovery campaigns.
DISCIPLINE: independent dense oracle + iid identity + recovery; local fixtures only after approval;
            planning closes with a local commit and handover, never implementation in Astra.
```

# Temporal latent AR1 — proposal awaiting approval

Reader: the R/TMB contributor who will implement this slice. This document specifies a proposed
capability; no temporal helper or likelihood has been implemented or tested by this task.
The acceptance ledger is [ACCEPTANCE.md](ACCEPTANCE.md); closure and resume instructions are
[HANDOVER.md](HANDOVER.md).

## 1. Scope and grammar

Add a temporal sibling provider. Preserve every existing cell and every existing default:

| Provider | Independent traits | Full trait covariance | Latent trait covariance |
|---|---|---|---|
| ordinary / none | `indep()` | `dep()` | `latent()` |
| animal / relatedness | `animal_indep()` | `animal_dep()` | `animal_latent()` |
| phylogenetic | `phylo_indep()` | `phylo_dep()` | `phylo_latent()` |
| spatial | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |
| dense kernel / relatedness | `kernel_indep()` | `kernel_dep()` | `kernel_latent()` |
| temporal, proposed | deferred; no exported helper | deferred; no exported helper | `temporal_latent(..., structure = "ar1")` |

This is the current **5 × 3 grid plus one proposed, partly populated provider row**, not eighteen
implemented keywords. `scalar`/`common` and `unique` remain modifiers, not additional modes.
Temporal `phi` is lag-one persistence, not source attenuation `rho`, a trait correlation, or a
response-family dispersion. No existing phylogenetic, spatial, kernel or ordinary grammar is rewritten.

Proposed paired calls (not runnable until implementation):

```r
fit_long <- gllvmTMB(
  value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion, replicate = replicate_id, d = 1,
                    structure = "ar1"),
  data = df_long, trait = "trait", family = gaussian())

fit_wide <- gllvmTMB(
  traits(y1, y2, y3) ~ 1 +
    temporal_latent(1 | series, time = occasion, replicate = replicate_id, d = 1,
                    structure = "ar1"),
  data = df_wide, family = gaussian())
```

Data contain independent series, integer-valued numeric occasions, and replicate measurements.
For this first admitted model require complete trait panels, at least three traits, at least two
series with at least three successive occasions each, and at least two measurement replicates
of every `(series, occasion, trait)`. Within a series, occasion differences must equal one;
different series may have different lengths and starting values. These are initial engineering
admission limits, not mathematical guarantees of precise estimation.

`time` captures one column name; reject expressions, missing/nonfinite values, character/factor
times, dates, fractional spacing, skipped occasions, and ambiguous duplicate rows. Require an
explicit `replicate` column when rows repeat; match trait panels within each replicate. Sort
distinct occasions internally and restore original observation order for output. Repetition of
an occasion across traits/replicates is expected, not a malformed-time error. Reject duplicate
`(series, occasion, replicate, trait)` keys. Expose trailing `replicate = NULL` after `structure`
in the helper's formal arguments, preserving the requested argument order; replicated fits without
it produce an actionable error naming that argument. The original requested call remains the
minimal marker spelling; this first admission regime requires explicit replication metadata.

Reserve `structure = "ou"` with an informative unsupported error: this implementation accepts
unit-spaced AR1 only. Do not silently renumber gaps. Users with dates first supply a documented
integer occasion index only when elapsed intervals really are equal. Irregular times wait for OU.

Initial estimation is native TMB ML/Laplace, Gaussian identity link, one temporal intercept block,
unweighted complete data. Reject REML, VA/EVA, AGHQ, MSPL, Julia, latent-score predictors, slopes,
multiple temporal terms, `meta_V`/`known_V`, missing-response/predictor integration, and other random
or structured terms in a temporal fit. Ordinary models retain their existing routes. Cross-provider
composition can be admitted later without changing this provider's meaning.

## 2. Mathematical contract and identification

For series g, occasion t, trait j and measurement replicate r:

\[
 z_{g1k}\sim N(0,1),\qquad
 z_{gtk}=\phi z_{g,t-1,k}+\sqrt{1-\phi^2}\,\eta_{gtk},\quad
 \eta_{gtk}\stackrel{iid}{\sim}N(0,1),\quad |\phi|<1;
\]
\[
 u_{gtj}\stackrel{ind}{\sim}N(0,\psi_j),\quad
 y_{gtrj}=x_{gtrj}^{T}\beta+\lambda_j z_{gt1}+u_{gtj}+\epsilon_{gtrj},\quad
 \epsilon_{gtrj}\stackrel{iid}{\sim}N(0,\sigma_\epsilon^2).
\]

Here `psi_j` is a **variance** and `Psi = diag(psi_j)`; the existing `theta_diag_B` stores
log SD, so `psi_j = exp(2 * theta_diag_B[j])`. This explicit local definition avoids the
SD/variance ambiguity in historical notes. It does not rename an existing extractor field.
Retain independent unique variation at each `(series, occasion)` and row-level response noise.
Only shared factor scores persist through time. Uniqueness is shared by replicate measurements
of the same occasion and trait; it is independent between occasions. In contrast, temporally
correlating the whole `Lambda Lambda^T + Psi` block would be a different model.

For h > 0, the between-occasion trait covariance is `phi^h Lambda Lambda^T`; at h = 0 it
is `Lambda Lambda^T + Psi`. Across series it is zero. Repeated measurements separate `Psi`
from `sigma_epsilon^2`: with only one measurement per cell both contribute to the same diagonal,
so estimating both freely cannot recover them separately. The first recovery fixture therefore
includes replication; do not zero B-tier uniqueness to make a test pass.

Fix stationary score variance at one; loading magnitudes carry process amplitude. Do not add
a free score SD. Rank is exactly one, with one shared scalar phi (the future common-phi formula
above is written for k, but d > 1 is rejected). There is no full transition matrix A, regression
or random effects for phi, or known-covariance shortcut.

Keep the current lower-triangular loading packing, including its free signed diagonal
(`src/gllvmTMB.cpp:34–60`). It does **not** enforce a positive diagonal. For comparisons and
reported scores, use one deterministic sign convention: make the first trait's nonzero loading
positive by multiplying both the loadings and scores by the same sign. Do not constrain its
magnitude to one. A near-zero anchor triggers a diagnostic; covariance is still the primary
rotation-invariant estimand. For rank one the only rotation is sign; higher-rank rotation is deferred.

Proposed differentiable transform: `phi = (1 - 1e-6) * tanh(theta_temporal_phi)`, giving a
numerically protected estimation domain inside (-1,1). No hard clip or optimiser-specific bound
is used. Test fixtures map fixed phi back with `atanh(phi / (1 - 1e-6))`. Report a near-boundary
diagnostic at `abs(phi) > 0.99`; the tiny numerical margin is not an identifiability remedy.
Stationary start contributes `-dnorm(z_1,0,1,log=TRUE)` and every transition contributes
`-dnorm(z_t,phi*z_prev,sqrt(1-phi^2),log=TRUE)`, including normalising constants.
Use stable `log1p(-phi*phi)` evaluation; never add the iid score prior a second time.
There is no Jacobian for maximising the likelihood over a transformed free parameter.

OU's future unit-variance kernel is `exp(-kappa * abs(time_i-time_j))`, kappa > 0.
At regular spacing Delta and **positive** phi, set `kappa = -log(phi)/Delta` to obtain the
same covariance as AR1. Negative AR1 persistence has no such OU counterpart; phi = 0 is
the OU infinite-rate limit. This identity is tested now as mathematics, without shipping OU.
The official [glmmTMB covariance vignette](https://cran.r-project.org/web/packages/glmmTMB/vignettes/covstruct.html)
confirms its AR1 unit-spacing and OU coordinate conventions and independent groups sharing covariance
parameters. It is a comparator reference, not source copied into this package.

## 3. Symbolic alignment — proposed implementation names

| Symbol | API / formula | TMB data / parameter | DGP | Recovery / extractor | Test |
|---|---|---|---|---|---|
| g,t,r,j | `series`, `time`, `replicate`, trait LHS | new temporal metadata: sorted pair keys, start/length per series, observation-to-pair map; existing `site`, trait index | 12 series × 20 times × 2 replicates × 3 traits | retained table `(pair_id,series,time)` and original row map | G1/G5 indexing and permutation |
| beta | `0 + trait` / `traits(...) ~ 1` | existing `X`, `b_fix` | intercepts `(0.2,-0.3,0.1)` | existing fixed-effect extractor | G3/G7 |
| phi | `structure="ar1"`, estimated shared persistence | new flag `use_temporal_B`, scalar `theta_temporal_phi`; starts/lengths | cells `(-0.4,0,0.6)` | proposed `extract_temporal()` one-row parameter table | G2/G3/G4/G7 |
| z | `temporal_latent(...,d=1)` | existing `z_B`, now 1 × number of pairs; same random block | fresh N(0,1) series starts and independent transition innovations | existing score extractor with pair metadata; states called scores, not one-step innovations | G2/G5/G6/G8 |
| Lambda | same term, existing packing | `theta_rr_B`, `Lambda_B` | `(1,0.7,-0.5)^T` | existing loading extractor, simultaneous sign handling | G3/G6/G7 |
| Psi | temporal helper's retained independent unique companion | existing `s_B`, `theta_diag_B`; iid prior untouched | variances `(0.16,0.09,0.25)`; shared across r, fresh across (g,t) | existing unique component, convert reported SD to variance explicitly | G3/G7/G8 |
| sigma_epsilon^2 | Gaussian response | existing response dispersion parameter | variance 0.36; new noise per row | existing response SD, squared for recovery | G3/G7/G8 |
| C_g | temporal AR1 prior | no dense production matrix; per-series recursion | dense `phi^abs(outer(time,time,"-"))` in independent oracle | implied lag covariance from phi and Lambda | G2/G3/G4 |

New names in this table are proposed contracts; confirm existing parameter spellings at the
execution commit. In particular, do not confuse latent states z with transition noise eta.

## 4. Minimal integration route and exact files

The inspected base is `3e646cbf28c585251a369949c62ab86d9e112f85`, equal to the locally cached
`origin/main` on 2026-09-08. Feasibility is a source-level inference, not a compiled proof.
`z_B` is declared at `src/gllvmTMB.cpp:1109`, its iid prior at 1676–1685, and its loading
contribution at 2891–2898. Keep that matrix and loading multiplication; replace only the prior
under a temporal flag and ensure its columns index occasion pairs rather than series.

| Slice | Files / exact integration target | Result |
|---|---|---|
| Admission and index | new `R/temporal.R`; `R/brms-sugar.R`, `R/parse-multi-formula.R`, `R/gllvmTMB.R`, `R/fit-multi.R` | marker captures metadata before model-frame processing; wide rewriting retains marker args; one internal pair ID drives B-tier indexing; preserve user series/time columns |
| Engine and start | `R/fit-multi.R`, `src/gllvmTMB.cpp`; review `R/init-warmstart.R` | add flag/offsets/scalar; map scalar off for every non-temporal model; leave `z_B` random under Laplace; start phi at zero and use existing loading starts |
| Output and simulation | `R/extractors.R`, `R/output-methods.R`, new `R/temporal.R`, `R/methods-gllvmTMB.R` | scores labelled by pair; `extract_temporal()` reports provider, structure, phi, series/occasion counts, boundary status; unconditional simulation draws AR1 states; conditional draws retain fitted eta |
| Tests | new `tests/testthat/test-temporal-ar1-parser.R`, `test-temporal-ar1-oracles.R`, `test-temporal-ar1-recovery.R`, `test-temporal-ar1-methods.R` | checks specified in acceptance ledger; no production-prior helper reused by dense oracle |
| Documentation | new `man/temporal_latent.Rd`, `man/extract_temporal.Rd`, `vignettes/articles/temporal-latent.Rmd`; `NAMESPACE`, `_pkgdown.yml`, relevant existing Rd | roxygen-generated help and a replicated Gaussian long/wide worked example |
| Contract cascade, after ownership cleared | `AGENTS.md`, `CLAUDE.md`, `docs/design/{00-vision,01-formula-grammar,03-likelihoods,04-random-effects,05-testing-strategy,06-extractors-contract,35-validation-debt-register}.md`; `vignettes/articles/api-keyword-grid.Rmd`, `README.md`, `NEWS.md`, `ROADMAP.md`, `docs/dev-log/check-log.md` | additive proposed row becomes one validated latent cell; scope in plain language on public surfaces; register IDs allocated only at execution |

`R/extractors.R:511–527` reshapes z_B using `fit$n_sites` and labels by `fit$unit_col`;
both must remain coherent with the internal pair map. `R/methods-gllvmTMB.R:1486` exposes
simulation; its unconditional path currently redraws scores. That path must not silently draw
iid states for a temporal object. Audit in-sample prediction, logLik/AIC parameter counting,
summary, update/refit and `getME`-style parameter access. Unsupported forecast/newdata,
selection, profile/interval and uncertainty methods must refuse temporal objects explicitly
at a safe dispatch boundary; never inherit an iid algorithm accidentally. Bootstrap and paired
interval files are protected: do not modify them. If an honest guard needs their active owner,
defer publication and resolve ownership rather than taking over their files.

The source scout confirmed ordinary latent expansion at `R/brms-sugar.R:4013–4117`, named extras
at `R/parse-multi-formula.R:255–315`, grouping dispatch at `R/fit-multi.R:1791–1799`, and ID
construction at 3128–3137 / 3531–3533. Reuse these through a temporal-only preprocessing branch:
create a collision-safe private pair column, expand to existing rr + auto-diag with that column,
and set the temporal route's fitter `site` argument to that private column before the
1791–1799 group-equality dispatch. Both `z_B` and `s_B` then receive that pair index in TMB.
Retain temporal metadata and original series/time values; adapt output labelling accordingly.
Do not globally replace the meaning of the user unit column.
Grouped starts at `R/fit-multi.R:5719–5728` must see the pair index. Its 6790–6829 guard already
distinguishes replicated diagonal effects from one-response-per-cell residual confounding.
`R/output-methods.R:252–277` also assumes `d_B * n_sites`; include it in the score-accessor audit.

This first slice reuses the sole ordinary B block exclusively. A temporal + ordinary B combination
would require separate score blocks and is rejected. That restriction does not change the
ordinary helper's semantics or imply that temporal is merely an alias for `latent()`.

## 5. Work order, roles and estimates

Route check: destination and file outputs are specified; no unresolved architecture alternatives
are hidden in the slice list. Maintainer approval covers the proposed replication/admission
contract, not a recovery campaign. Implementation estimates are engineering guesses from the
number of integration surfaces, not measured fitting times.

| Step / dependency | Member, model + effort, dispatch | Time estimate | Output |
|---|---|---|---|
| S0 fresh checkout / approval | Ada, Terra high, fresh task | 15–30 min | refreshed base and nonoverlapping file leases; accepted ledger copied to runtime `.unlazy/` |
| S1 contract + failing parser/index tests; S0 | Boole, Terra high, native/explicit | 1–2 h | temporal marker, pair map and parser tests |
| S2 prior + fixed-parameter oracles; S1 | Gauss, Terra high, native/explicit | 2–3 h | conditional prior, parameter maps and G2–G6 receipts |
| S3 output/simulation + recovery; S2 | Curie/Emmy, Terra high, native/explicit, sequential owner | 1.5–3 h plus timed fixtures | G7–G9 receipts; honest unsupported-method guards |
| S4 examples/contract cascade; S2, finalise after S3 | Pat, Terra medium, native/explicit | 1–2 h | long/wide article, generated help, documented boundary |
| S5 independent review; S3/S4 | Noether + Rose, Terra high, native/explicit | 30–60 min | mathematical and cross-file review; fixes returned to owner |
| S6 mechanical verification + reconciliation; S5 | Grace/Rose, Terra medium, native/explicit | 1–3 h excluding queues | local package/docs receipts, after-task and plan-versus-actual note |

Estimated implementation plus local verification: **7–14 hours**, likely several checkpoints in
one fresh Terra task. Three-OS CI/merge is a later publication gate, subject to renewed authority;
this planning task authorises no push. Use at most two concurrent children, with separate
ownership; S1–S3 remain sequential because they share fit/engine files. Reviewers are bounded
read-only children. Astra is not the execution parent. Escalate only a specific unresolved
mathematical discrepancy, not the whole job.

No model has been run here. Planned compute: local four-core maximum, BLAS one thread, timed
single-fixture pilot estimated 1–3 minutes **after plan approval**. The nine small recovery fits
are estimated 15–30 minutes pending that pilot. If the estimate exceeds 30 minutes, or the pilot
cannot establish it, write/show the pre-run result and ask approval for a separate Totoro run
(or a named DRAC array after live routing). Stop and re-report if a run exceeds its estimate.
No campaigns on GitHub Actions; no launch from this plan-only task.

## 6. Prior-work and coordination receipt

* Local brain search: `search_notes(query='"temporal_latent" OR "temporal autocorrelation"',
  search_all_projects=true)` recovered the 2026-08-31 focused recommendation; it was planning,
  not implementation. Deterministic `rg -n -i 'temporal_latent|temporal autocorrelation|dynamic gllvm|ar1'`
  over hub AGENT_LOG, DECISIONS, OPEN_QUESTIONS and deep-research README returned no hit.
* Git: initial tree clean/detached; HEAD and cached origin/main identical; all-ref commit search
  for `temporal|autocorrelation|AR1` found a cross-package corpus test commit, not a temporal
  provider. Branch/worktree/stash inventories were read; foreign state was not edited.
* Code/docs: `rg -n -i 'temporal|ar1|ornstein' docs/design R tests/testthat` found unsupported-AR1
  tests and [Design 87](../../../design/87-latent-variable-oracle-map.md), especially §2.4's
  `gllvm::lvCor` prior-art map. New temporal syntax must coexist with the existing refusal of bare
  glmmTMB `ar1()` syntax. No novelty claim or broad literature campaign is needed.
* Sister scan: no temporal implementation hit in GLLVM.jl/src or drmTMB/R for the searched terms;
  GLLVM.jl/docs contains an `ar1-sparse` relatedness benchmark proxy, not evidence of learned phi.
  Scope is the inspected local snapshots, not an assertion about every sister branch.
* Hub `MODEL-ROUTING.md` D-251 requires Astra high planning followed by a fresh Terra task;
  it supersedes older Sol-parent guidance in Ultra Plan. WHAT-WORKS' 2026-08-31 comparator lesson
  supports comparing the same likelihood at matched parameters, with limits explicit.
* Lane preflight: **FOREIGN LANE ACTIVE (claude)** plus two active Codex lanes and bootstrap lease.
  Coordination board and every row of the 2026-07-25 split were read. The board's older
  “no Claude lane” statement is superseded by live preflight; never use it as permission.
* Lease **GRANTED**: `codex:temporal-ar1-plan-20260908-cb78`, only
  `docs/dev-log/plans/temporal-ar1-20260908/`. Its note is the coordination notice. Shared
  board/check-log/design-number edits are deliberately excluded; preflight reports duplicate
  ledger IDs and this task forbids GitHub API checks/external messages. No foreign lane is claimed.

## 7. Approval and handoff

Approve this bounded replicated-Gaussian AR1 plan, then start a **fresh Terra high** task from
HANDOVER.md. G0 in ACCEPTANCE.md remains pending until that explicit approval. Approval of this
plan is not approval of OU, other families, provider combinations, coverage claims, a >30-minute
campaign, publication, or work in another lane.
