# G2g information check on the frozen Paper 1 fixture -- measurement

**Status:** read-only measurement on the sealed MSPDE V3 packet. No TMB
construction, optimiser, fit, smoke, result root, or recovery ran. Nothing was
written to any consumed root. This authorises no claim about the estimator.

**Question.** `2026-08-11-g2g-identifiability-certificate.md` diagnosed
`COVARIANCE_INFORMATION_LIMITED` and prescribed a redesign whose acceptance bar
it predeclared: *"the next fixture must predeclare a minimum of 130 for every
\(\sum_c\mu^G_{cs}b_c^2\)"*, with the redesign drawing the bias covariate at
\(|\operatorname{cor}(x,b)|\le0.10\). **Did the frozen Paper 1 fixture meet its
own diagnostic's bar?**

## 1. Result -- the fixture MEETS the bar

\[
I^{G}_{\gamma_s\gamma_s}=\sum_c \mu^G_{cs}b_c^2,\qquad
\mu^G_{cs}=a^G_c\exp(\eta_{cs}+\delta_s+b_c\gamma_s)
\]

evaluated on `MSPDE_P1_S3_C360_R3_V3` (360 cells, 3 species, 1080 GBIF rows,
Poisson/log GBIF branch, binomial PA branch).

| species | \(I\) at RE \(=0\) | latent var | \(e^{v/2}\) | \(I\) marginal |
| --- | --- | --- | --- | --- |
| 1 | 142.77 | 0.2860 | 1.1537 | **164.72** |
| 2 | 174.92 | 0.2088 | 1.1100 | **194.17** |
| 3 | 125.30 | 0.2511 | 1.1338 | **142.06** |

**Minimum = 142.06 against a bar of 130 -> MEETS.**  G2g predicted the redesign
would reach "about 133"; it delivered ~142.

Reported honestly, both ways: at random effects \(=0\) the minimum is 125.30,
which *fails* by 3.6%. The marginal figure applies the convexity correction
\(E[e^{\eta}]=e^{E\eta+v/2}\) using the fitted variance components, which is the
right quantity for a *design* question. Either figure is within a few percent of
the bar. **Neither is the three-fold shortfall that would explain a total
failure to admit across 24 routes.**

The second criterion passes decisively: \(\operatorname{cor}(x,b) =\)
**\(-0.0000\)** on GBIF rows, against the required \(\le0.10\) (G2g's own
fixture was 0.1999). The aliasing the certificate worried about was removed.

**Conclusion: G2g's prescribed redesign was implemented and hit both targets.
The information-limitation hypothesis, as operationalised by G2g's own bar, does
not explain the continued failures.**

## 1a. AMENDMENT (same day, live objective) -- the falsifier ran, and §2 below is REFUTED

§4 named the falsifier: *"recompute \(I\) at the fitted Laplace modes with a live
objective."*  It has now been run, in this session, with the maintainer
reassigning execution from Codex to Claude.

**Provenance.**  The live objective replays the sealed state using the DLL whose
MD5 matches the recorded V3 replay DLL
(`7797c4674e4758fca2da27151e5c2508`): objective `2549.0400257186` against sealed
`2549.0400257186`, difference \(1.5\times10^{-11}\); gradient max abs difference
\(1.5\times10^{-11}\); `parameter_order` matches positionally.

**Falsifier result -- it does NOT fire.**

| species | \(I\) at the fitted modes |
| --- | --- |
| 1 | 149.22 |
| 2 | 191.72 |
| 3 | **135.84** |

Minimum **135.84 \(\ge\) 130 -> MEETS**, sitting between the two earlier
estimates exactly as it should (125.30 at RE \(=0\); 142.06 prior-corrected).
**§1 stands, now measured on the faithful quantity** -- G2g's "conditional on
\(\eta\)", at the fitted state.

**But §2's mechanism is REFUTED by direct measurement of the marginal Hessian**
(22x22, central differences of the exact gradient; the negative eigenvalue below
is stable to seven significant figures across steps \(10^{-3}\) to \(10^{-6}\),
so it is not finite-difference noise):

| claim in §2 | measurement | verdict |
| --- | --- | --- |
| \(u=(q+\eta)/\sqrt2\) is the flat direction | \(u\)-axis curvature \(76.4955\); \(v\)-axis \(76.4962\); ratio \(1.00\) | **refuted** -- \(u\) is not flat |
| the degeneracy is a \(\kappa\)--amplitude ridge | near-null eigenvector weight on `log_kappa` = **0.0000** | **refuted** |
| caused by `log_tau_spde` being fixed | `src/gllvmTMB.cpp:1674-1679` -- the slope block calls `GMRF(Q_slope)` with **no** `SCALE(...,1/tau)`; tau is absent from this block by design | **refuted** |

**What the null direction actually is.**  Its weight lies **entirely** in the
GBIF slope loading block: coords 20--22 carry \(1.0000\) of it, coord 16 and
coords 17--19 carry \(0.0000\).  The spectrum there is
\(-2.591\times10^{-4},\;+3.616\times10^{-3},\;+4.488\times10^{-3}\) against a
leading eigenvalue of \(508.01\) -- four to six orders of magnitude smaller.  And
\(\lVert\lambda_{\rm slope}\rVert=0.1032\) against
\(\lVert\lambda_{\rm intercept}\rVert=33.5224\).

**So the diagnosis is neither hypothesis.  The GBIF-only spatial slope field is
essentially unidentified: its loading block is flat to numerical precision and
carries one genuinely negative eigenvalue, so the frozen point is a very shallow
saddle rather than a minimum.**  This is what `pdHess = false` records, and it is
why the sibling lane's covariance was unavailable
(`FSB_COVARIANCE_UNAVAILABLE`).

**This also reconciles the sealed SAR result -- and the reconciliation is not
the obvious one.**  `SAR_P1_S3_C360_R3_V1` (2026-08-14) recorded
`SAR_RETAINED_RANGE_NUMERICALLY_FLAT`, asking whether the shared range is
informative *"when the two retained spatial amplitudes are almost zero."*  Its
retained ledger holds the actual evidence: across its nine-point range grid the
objective moved by a **relative \(8.86\times10^{-12}\)** with
`retained_max_abs_score` \(4.71\times10^{-8}\), classified `NUMERICALLY_FLAT`.

At first reading that **contradicts** the measurement above, which finds
substantial curvature along the range direction (\(76.4955\)) and zero
null-weight on `log_kappa`.  It does not, because the two are measured on
**different states**:

| state | \(\lVert\lambda_{\rm intercept}\rVert\) | \(\lVert\lambda_{\rm slope}\rVert\) | what is flat |
| --- | --- | --- | --- |
| `FSB_P1_S3_C360_R3_V2` (SAR's predecessor) | ~0 | ~0 | the **range** -- no field for it to describe |
| `MSPDE_P1_S3_C360_R3_V3` (here) | 33.52 | 0.1032 | the **GBIF slope loading block** |

The unifying statement is simpler than either lane's framing: **a spatial field
whose loading amplitude is approximately zero is unidentified, and so is
anything that reaches the likelihood only through it.**  At FSB both amplitudes
had collapsed, so \(\kappa\) itself went flat.  At V3 the intercept amplitude is
large -- so \(\kappa\) is well determined -- and only the GBIF slope amplitude
has collapsed, so the flatness has **moved** from \(\kappa\) into the slope
loading block.

SAR therefore has precedence over §2 by a day for the *phenomenon*, and §2
mis-attributed its cause.  But SAR's flat range does **not** transfer to V3, and
neither lane had stated the amplitude-collapse rule that covers both.

**Consequence for the science.**  Paper 1 asks whether the model can keep the
ecological and GBIF-only fields distinct without collapsing them.  At this
design the answer the data gives is that **the GBIF-only field collapses to
approximately zero and is not identified**.  That is a result, and it is the
STOP/HOLD outcome Paper 1's own staging document pre-declares -- not a numerical
defect to be engineered around.

**Consequence for method.**  No reparameterisation can help: a chart cannot
create information for a field the data does not support.  §3's candidate list
below is superseded -- items 1--3 (range/SD reparameterisation, freeing tau,
prior on kappa) address a \(\kappa\)--\(\lambda\) ridge that the measurement
shows does not exist.  **Only item 4, spatial replication, and more generally
the design/data, bear on what was actually measured.**

## 1b. AMENDMENT (same day, after independent adversarial review and the effort-ladder pilot)

A fresh-context reviewer attacked §1a; every number reproduced, but three
framings were overturned, and the effort-ladder pilot
(`2026-08-15-paper1-gbif-effort-ladder-pilot.md`) then settled the question
§1a left open.  Corrections, in order of weight:

**1b.1 The truth was never consulted, and it is NOT near zero.**  The sealed
V2 root's own `fixture.rds` records
\(\lambda_{\rm bias}^{\rm true} = (11.2798, -8.7732, 7.5199)\),
\(\lVert\cdot\rVert = 16.148\) -- **64% of the ecological field's amplitude by
construction**.  The fitted \(0.1032\) is a 156-fold collapse with the wrong
sign pattern.  But raising \(\theta_{20:22}\) to the truth costs only 0.574
nats (\(2\Delta = 1.148\) on 3 df, \(p = 0.765\)), and the LR-95% bound on
\(\lVert\lambda\rVert\) reaches 33.  **§1a's "the GBIF-only field collapses to
approximately zero *and that is the answer the data gives*" is wrong**: the
answer the data give is an indifference interval containing both zero and the
truth.  A recovery failure was reported as a scientific result.

**1b.2 The negative eigenvalue is a sign-symmetry fixed point, not a
substantive saddle.**  \((\Lambda_1, g_1)\to(-\Lambda_1, -g_1)\) leaves the
likelihood and prior exactly invariant (verified bitwise), so
\(\Lambda_1 = 0\) is a stationary point of the marginal likelihood **for any
data**, and whether it is a minimum or a saddle is the symmetry-breaking
question.  Consequently §1a's "no reparameterisation can help" conflated two
things and is a **non-sequitur as stated**: the *information deficit* is real
and no chart creates information, but the *pdHess failure* is a symmetry
artifact that a sign-quotiented parameterisation (log-SD with an anchored
direction) removes without adding information.  The pilot confirmed the
fixed-point behaviour replicates under fresh noise at baseline effort.

**1b.3 Framing and citation repairs.**
(i) Step-size stability was **invalid evidence** for the eigenvalue's realness
-- the exact gradient is deterministic, so a smooth inner-solve bias would be
equally stable; the claim survives on other grounds (gradient-free second
differences \(-2.589\times10^{-4}\), `optimHess`, `sdreport` non-PD).
(ii) "Flat to numerical precision" and "four to six orders" were unscaled-
Hessian rhetoric; on the correlation scale the near-null eigenvalue is ~1/60 of
the stiffest direction.  The **localisation** survives scaling (weight 0.99992
on coords 20--22).
(iii) §1a's \(\tau\) citation pointed at a **dead branch**
(`use_spde_slope == 1`; this state runs `use_spde_latent_slope == 1`,
`src/gllvmTMB.cpp:1810-1866`).  The conclusion holds on the live path --
`log_tau_spde` is simply **absent** there, not "fixed at 1".
(iv) The frozen point is **not stationary** (max\(|g| = 2.8\times10^{-4}\),
concentrated on coords 20--22); any "saddle" language must carry that caveat.
(v) The u/v curvature test in §1a was nearly vacuous: with
\(\lVert\lambda_{\rm slope}\rVert = 0.1\), both axes were ~99% \(\kappa\)
(\(\cos(u,v) = 0.979\)).  The honest \(2\times2\) chart Hessian has **zero**
\(q\)--\(\eta\) cross-term with \(\eta\) alone flat.  And on the **intercept**
block the same chart shows a *genuine* range--amplitude ridge
(corr \(-0.955\), curvature ratio 28:1) -- so the range is also weakly
determined on its own terms, which likely explains the pilot's small
\(\hat q\) drift.

**1b.4 The pilot's settlement.**  With the truth held fixed and GBIF effort
multiplied: at \(E=1\) the collapse **replicates** (fresh noise,
\(\lVert\hat\lambda\rVert = 0.07\), pdHess FALSE); at \(E=4\) the field is
recovered; by \(E=16\) amplitude, direction (cos 0.996), and \(\gamma\) are
all essentially at truth with a PD Hessian.  **The estimator is correct; the
frozen design is information-poor for its own question; the recoverability
frontier lies between ~460 and ~1,900 GBIF detections.**  This supersedes both
§1a's framing and §2's mechanism as the diagnosis of record.

## 2. SUPERSEDED -- what the earlier pass inferred (retained for the record)

> The following section was written before the live objective was available. Its
> mechanism is refuted by §1a. It is retained because the reasoning is on record
> and the correction should be visible, not silently overwritten.

`log_tau_spde` is **mapped out and fixed at \(\tau=1\)** (confirmed in the sealed
`map`). With \(\kappa=14.697\), the Matern (\(\nu=1\), \(d=2\)) marginal variance
is

\[
\sigma^2_{\rm spde}=\frac{1}{4\pi\kappa^2\tau^2}=3.684\times10^{-4}.
\]

Three consequences, in order.

**2.1 The "huge" loadings are not pathological.** The audit
(`2026-08-15-paper1-range-amplitude-orthogonal-map-audit.md` F1) flagged
intercept loadings of 21.618, -21.081, 14.560. Against a field of SD
\(0.0192\) these produce predictor SDs of **0.415, 0.405, 0.279** -- ordinary
ecological signal. The magnitude is the arithmetic consequence of fixing
\(\tau\), not a Heywood case. **That part of F1's framing is hereby corrected.**

**2.2 The field's contribution depends on \(\lambda\) and \(\kappa\) only through
\(\lambda/\kappa\).** The predictor variance is
\(\lambda^2/(4\pi\kappa^2\tau^2)\). With \(\tau\) fixed, \(\kappa\) is separately
identified **only** through the spatial correlation range.

**2.3 That range is weakly determined here.** Practical range
\(=\sqrt8/\kappa=0.1924\); FEM domain area \(1.4528\), side \(\approx1.2053\);
so range/side \(=0.160\) -- about **6.3 independent patches per side, ~39 in
total**. With ~39 effective independent spatial units, \(\kappa\) is poorly
determined by the correlation structure, and \(\lambda\) and \(\kappa\) collapse
onto their ratio.

**The resulting flat direction is \(\log\kappa+\log\lambda=q+\eta\) -- which is
exactly the chart's \(u\) coordinate.** The audit measured
\(q+\eta=-0.02810\), i.e. \(u\approx-0.0199\approx0\), and recorded it as a
cancellation costing two decimal digits (F7).

So the range--amplitude chart **correctly located the degenerate direction** --
that is *why* the cancellation appears. But rotating a coordinate system into a
flat direction does not make the direction non-flat. The degeneracy is
structural, and `pdHess = false` for Paper 1 follows from it directly.

## 3. What this eliminates, and what it implies

Two standing explanations are now eliminated by measurement rather than
judgement:

- **Coordinates.** The audit showed the orthogonal factor preserves eigenvalues
  and cannot change conditioning.
- **GBIF information.** This measurement shows the fixture meets G2g's bar.

What remains is a **model-parameterisation** problem: two scale parameters whose
only separate identification is a spatial range that this design does not
resolve. Candidate directions, none authorised here and all requiring their own
design and review:

1. **Reparameterise to (range, marginal SD)** -- the standard INLA/sdmTMB
   parameterisation, constructed to be identifiable, instead of
   (\(\kappa\), \(\tau\) fixed, free loading).
2. **Free `log_tau_spde`, or fix the loading amplitude instead of \(\tau\)** so
   the model carries one scale parameter where it currently carries two that
   appear as a ratio.
3. **Penalise or prior \(\kappa\)** (a PC prior on range).
4. **Increase spatial replication** -- range/side \(=0.16\) is the binding
   constraint, not the GBIF support.

**No further coordinate chart should be opened.** The chart lane's own geometry
now argues against it.

## 4. Method, assumptions, and what would falsify this

Computed in pure base R from `v2-materialized-state.rds` (MD5
`e3b17636c9f5fa0e9e555a307c923724`, verified on read), using fitted
`theta[1:12]` and `X_fix` (columns 10--12, `traitsp*:isdm_gbif_b_bias`, are the
per-species bias covariate; nonzero on the 1080 GBIF rows only).

Assumptions that a reviewer should attack:
- The marginal correction assumes the latent contribution is Gaussian on the
  link scale with the fitted variance components; \(\theta_{\rm diag,B}\) is read
  as a log-SD.
- \(\sigma^2_{\rm spde}=1/(4\pi\kappa^2\tau^2)\) assumes the standard Matern
  \(\nu=1,\,d=2\) normalisation. If gllvmTMB normalises the SPDE differently,
  \(\S2\) changes quantitatively -- **though not in direction**, since the
  \(\lambda/\kappa\) ratio structure is normalisation-independent.
- The fitted random-effect modes are not in the sealed state, so \(I\) at
  RE \(=0\) is exact and the marginal figure is a design-level estimate.

Falsifier: recompute \(I\) at the fitted Laplace modes with a live objective. If
the minimum lands materially below 130, \(\S1\) is wrong and the information
hypothesis returns.
