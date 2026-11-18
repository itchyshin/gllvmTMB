# Private repeated-visit detection extension — implementation specification

**Status:** design only; not an implemented `gllvmTMB` capability and not a
public article/API contract.  It becomes executable only after the G2k
nonspatial core recovery campaign has an all-attempt, admissible PASS.

## Scientific target and units

For cell \(c=1,\ldots,C\), species \(s=1,\ldots,S\), and survey visit
\(v=1,\ldots,V_c\), infer relative ecological intensity from the common
cell/species state \(\eta_{cs}\), while distinguishing a missed survey event
from a low ecological event rate.  This is neither abundance estimation nor a
generic zero-inflation model.

The core state and covariance stay frozen:

\[
 \eta_{cs}=\alpha_s+x_c^\top\beta_s+\lambda_s z_c+e_{cs},\qquad
 z_c\sim N(0,1),\quad e_{cs}\sim N(0,\psi_s),\quad
 \Sigma=\Lambda\Lambda^\top+\Psi,
\]

where \(\Lambda=(\lambda_1,\ldots,\lambda_S)^\top\), \(
\Psi=\operatorname{diag}(\psi_1,\ldots,\psi_S)\), and the rank is one.
The sign convention for the latent factor must be fixed exactly as in the
core's parameter map.

## Joint observation model

The GBIF-like opportunistic channel is unchanged:

\[
 N^G_{cs}\mid\eta_{cs}\sim
 \operatorname{Poisson}\{a^G_c\exp(\eta_{cs}+b_c\gamma_s)\}.
\]

`b_c` is observed only for GBIF rows.  Survey rows retain an unavailable
GBIF-bias covariate and must never be routed through this term.

For the planned survey, the ecological event probability over known visit
support \(a^S_{cv}>0\) is

\[
 q_{csv}=1-\exp\{-a^S_{cv}\exp(\eta_{cs})\}.
\]

Conditional detection uses visit-level covariates \(w_{cv}\) and a
species-specific coefficient vector \(\delta_s\):

\[
 p_{csv}=\operatorname{logit}^{-1}(w_{cv}^{\top}\delta_s),\qquad
 Y_{csv}\mid\eta_{cs}\sim
 \operatorname{Bernoulli}(p_{csv}q_{csv}).
\]

Given \(\eta\), all GBIF counts and survey observations are conditionally
independent.  The per-observation Bernoulli contribution is evaluated on the
log scale:

\[
 \ell^S_{csv}=Y_{csv}[\log p_{csv}+\log q_{csv}]
 +(1-Y_{csv})\log(1-p_{csv}q_{csv}).
\]

This is a *marginal event-and-detection* observation law.  It does not create
a latent occupancy indicator shared across visits.  A shared occupancy state
would be a distinct extension with a different estimand and identifiability
analysis; it is out of scope here.

## Required parameter map

| Block | Free parameters | Identifying constraint | Data information |
| --- | --- | --- | --- |
| Ecology | \(\alpha_s,\beta_s\) | frozen core coding | GBIF and all survey visits |
| Latent covariance | rank-one \(\Lambda\), diagonal \(\Psi\) | fixed factor sign; \(\psi_s>0\) transform | joint residual co-occurrence |
| GBIF bias | \(\gamma_s\) | GBIF rows only; \(b_c\) nonconstant | opportunistic count variation |
| Survey detection | \(\delta_s\) | intercept plus non-aliased visit covariates | within-cell visit replication |
| Survey support | observed \(a^S_{cv}\) | fixed offset, not estimated | known design input |

No source-availability or structural-zero parameter is included.  It may only
be proposed later with distinct replicated/auxiliary information and a new
known-truth gate against low-intensity alternatives.

## Identifiability admission conditions

The synthetic fixture must prove these conditions before a fit is attempted.

1. Every analysed cell has at least three visits, with more than one visit
   condition \(w_{cv}\) within cells.
2. At least one column of \(w_{cv}\) varies within cell and is not a linear
   combination of the ecological design \(x_c\), support offset
   \(\log a^S_{cv}\), or an intercept.
3. `a^S` is known, positive, and has finite range.  It is never re-estimated
   as detection effort.
4. The fixture has detections and nondetections for every species, with no
   all-zero or all-one detection column and no complete separation of a
   detection covariate.
5. GBIF bias `b` is finite and nonconstant for GBIF rows and `NA` for survey
   rows.  No survey-only covariate may enter the GBIF likelihood.
6. The rank-one factor orientation and ecological maps match the successful
   G2k core parameter map exactly.

Passing these checks establishes that the *design has information*; it is not
evidence of estimator recovery.

## Frozen known-truth DGP and recovery campaign

The future fixture will retain G2k's six species, nonspatial covariate
geometry, rank-one \(\Lambda\), diagonal \(\Psi\), GBIF Poisson channel, and
three visits.  It additionally freezes a nonzero within-cell visit covariate,
moderate detection intercepts/slopes, positive supports, and independent
survey Bernoulli draws under the equations above.  Seeds, starts, tolerances,
truth, maps, and pass thresholds are written before any fit.

For every requested seed the campaign retains the truth, fit, profile data,
diagnostic ledger, wall time, and failure reason.  The denominator is all
predeclared seeds: failed fits are never replaced.  A recovery PASS requires
all predeclared denominators and thresholds for:

- finite objective, valid Hessian, and exact mapped parameter vector;
- ecological fixed effects and GBIF-bias effects;
- rank-one covariance and diagonal-variance recovery;
- detection coefficients \(\delta_s\), including the within-cell varying
  effect;
- profile/gradient diagnostics and all-attempt failure accounting.

The pre-run estimates runtime.  A campaign longer than 30 minutes receives an
explicit user compute approval and runs as a single-threaded scheduler array;
it is never routed to GitHub Actions.

## Implementation sequence and boundary

1. Core G2k campaign PASS and reconciliation.
2. Add the symbolic-to-TMB alignment table, simulation generator, and pure
   no-fit admission tests for this specification.
3. Implement the survey likelihood privately, followed by a Gauss/Noether
   likelihood review and one local pre-run.
4. Run the approved all-attempt recovery array and independently review the
   estimand/claim boundary.
5. Only then consider a narrow public synthetic workflow.  The local articles
   remain staging drafts until that separate promotion gate.
