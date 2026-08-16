# Paper 1 GBIF effort-ladder pilot -- the recoverability frontier

**Status:** maintainer-authorized diagnostic pilot, run by Claude in-session
(execution reassigned from Codex).  Fresh synthetic data simulated FROM the
retained sealed truth; no sealed root written or modified; no packet, ledger,
status token, admission claim, or recovery-campaign claim.  Four fits on new
data, ~15 s each.  Script: `pilot-paper1-gbif-effort-ladder.R` (this
directory); results at commit time in the after-task record.

## 0. Provenance and the byte gate

The sealed V2 root `MSPDE_P1_S3_C360_R3_V2` retains `fixture.rds` with the
complete generator truth: `eta_ecological`, `eta_gbif_field`,
`trait_residual`, draw seeds, and

\[
\lambda_{\rm bias}^{\rm true} = (11.2798,\,-8.7732,\,7.5199),\quad
\lVert\lambda_{\rm bias}\rVert = 16.1478,\qquad
q^{\rm true} = 2.5538,\qquad
\gamma^{\rm true} = (0.30,\,-0.20,\,0.15).
\]

**Byte gate.**  Rebuilding `y` from that truth under the recorded draw seeds
(GBIF `rpois(support * exp(eta_e + b*gamma + eta_b))`, PA
`rbinom(1, -expm1(-support * exp(eta_e)))`) reproduces the fixture's
`rows$value` **bitwise**, and that vector is **bitwise identical** to the
sealed TMB `d$y`.  The DGP reconstruction is exact; everything below inherits
that exactness.

## 1. Design

Hold the entire latent truth fixed (the same realised fields, residuals, and
covariates as the sealed fixture).  Multiply GBIF **effort** by
\(E \in \{1, 4, 16, 64\}\): the GBIF mean becomes \(E\cdot\mu\) and the fitted
offset gains \(\log E\).  Redraw only the GBIF Poisson noise, fresh seed per
rung (`20260815 + E`).  PA rows unchanged.  \(E = 1\) is therefore a fresh
replicate of the sealed design -- a control for whether the collapse is
noise-specific.  Fit each rung from the standard template start with `nlminb`
on the 22 fixed parameters; the FD Hessian of the exact gradient supplies
`pdHess` and the slope-block spectrum.

## 2. Result

| \(E\) | GBIF counts | conv | \(\lVert\hat\lambda_{\rm slope}\rVert\) | cos to truth dir | \(\hat q\) | pdHess | min eig |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 458 | 0 | **0.070** | 0.943 | 2.8220 | **FALSE** | \(-4.9\times10^{-6}\) |
| 4 | 1,933 | 0 | 20.394 | 0.980 | 2.6073 | TRUE | \(+8.3\times10^{-3}\) |
| 16 | 7,746 | 0 | 15.949 | 0.996 | 2.4161 | TRUE | \(+2.7\times10^{-2}\) |
| 64 | 30,872 | 0 | 16.282 | 0.996 | 2.4077 | TRUE | \(+3.5\times10^{-2}\) |
| truth | -- | -- | 16.148 | 1 | 2.5538 | -- | -- |

\(\hat\gamma\) converges on \((0.30, -0.20, 0.15)\) by \(E = 16\).

**Reading, in order of importance.**

1. **The estimator is vindicated.**  Given roughly \(4\times\) the GBIF
   information, the model recovers the GBIF-only field's amplitude, direction
   (cos 0.996), the fixed bias coefficients, and a positive-definite Hessian.
   There is nothing wrong with the model class or the likelihood.
2. **The collapse is a design property, and it replicates.**  At \(E = 1\)
   with fresh noise the fit collapses again (\(\lVert\hat\lambda\rVert = 0.07\),
   `pdHess = FALSE`, a tiny negative eigenvalue at the sign-symmetric fixed
   point) -- exactly as the adversarial review predicted it would in "every
   replicate whose GBIF field collapses".
3. **The recoverability frontier sits between \(E=1\) and \(E=4\)** -- between
   roughly 460 and 1,900 total GBIF detections for this 3-species, 360-cell
   design.  The sealed fixture sits just below its own frontier.
4. \(\hat q\) drifts slightly below truth at high effort (2.41 vs 2.55);
   consistent with the intercept-block range--amplitude ridge the review
   identified (corr \(-0.955\)), and untested here.  A recovery campaign, not
   this pilot, would quantify it.

## 3. What this settles for the two standing questions

**Why did 24 estimator routes fail?**  Because every one of them fit the same
frozen dataset, whose GBIF branch carries too little information to determine
the GBIF-only field: the truth sits inside a likelihood region that also
contains zero (review: raising \(\theta_{20:22}\) to truth costs 0.57 nats,
\(p = 0.765\)).  No optimiser, chart, gauge, trust region, or curvature trick
was ever going to change that; the routes were re-asking a question the data
cannot answer.  This pilot shows the *same* estimator answering it correctly
the moment the data can.

**Is Paper 1's STOP/HOLD the end?**  No -- it is one measured point.  The
honest statement is now sharper than either "cannot separate" or "correctly
detects absence" (the truth is NOT absent): **at the frozen design the
GBIF-only field is inside the data's indifference region; at ~4x GBIF effort it
is cleanly identified.**  That is a recoverability-frontier result, and it is
the natural spine of the reframed paper: *when can a two-source design separate
ecology from source-specific sampling, and how much opportunistic data does it
take?*

## 4. Boundaries

Single realisation of the latent fields; one noise draw per rung; frontier
localised only to a factor-of-4 bracket; \(\hat q\) bias unquantified; no
multi-seed statement.  Any frequency claim (coverage, bias, frontier location
with uncertainty) requires a designed multi-seed campaign with its own
predeclared design, estimate, and approval.  This pilot licenses exactly one
sentence: *the frozen design is information-poor for its own question, and
modestly more GBIF effort makes the same model answer it.*
