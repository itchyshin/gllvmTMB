# Paper 1 range--amplitude orthogonal chart -- mathematical audit of the map

**Status:** review note.  It audits the design at
`2026-08-15-paper1-range-amplitude-orthogonal-design.md` and the pure contract at
`range-amplitude-orthogonal-contract.R`.  It authorises no TMB construction, no
numerical attempt, no result root, and no claim.  It is not evidence that the
estimator works; it is evidence about what the chart is and is not.

Auditor: Claude, Noether lens, 2026-08-15.  Every numerical statement below was
computed in pure base R against the committed contract; every source statement
cites `file:line`.

## 1. What the chart is, stated precisely

The design describes the map as "a fixed 45-degree rotation of `log_kappa_spde`
and the GBIF loading log-amplitude".  That is accurate for one of its two
factors and understates the other.  The map composes as

\[
(u,v,a,b)\;\xrightarrow{\;R\;}\;(q,\eta,a,b)\;\xrightarrow{\;E\;}\;(q,\lambda),
\]

where \(R\) is linear and orthogonal, and \(E\) is nonlinear:

\[
R=\frac1{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix},
\qquad
E:(q,\eta,a,b)\mapsto\bigl(q,\;e^{\eta}(1,a,b)^{\top}\bigr).
\]

Two corrections of terminology follow, neither of which changes a conclusion but
both of which matter in a lane whose whole discipline is precision of claim.

**1.1 \(R\) is a reflection, not a rotation.**  \(R^{\top}R=I\) to
\(2.2\times10^{-16}\) and \(\det R=-1\).  A proper rotation has determinant
\(+1\).  \(R\) is the reflection across the line at \(22.5^{\circ}\); it is
orthogonal, which is all the argument below needs, but "45-degree rotation" is
loose.

**1.2 The substantive factor is \(E\), not \(R\).**  \(E\) is the nonlinear
separation of the loading vector into an amplitude \(e^{\eta}\) and a direction
\((1,a,b)\).  That is a genuine change of geometry.  \(R\) is not: see §2.

## 2. An orthogonal factor cannot, by itself, improve conditioning

Let \(H\) be the curvature of the objective restricted to the \((q,\eta)\)
plane.  Under \(R\) it becomes \(R^{\top}HR\), an orthogonal similarity, so its
eigenvalues -- and therefore its condition number -- are **unchanged**.
Verified: eigenvalues agree to \(1.1\times10^{-16}\) across test cases.

Write the block as \(\bigl(\begin{smallmatrix}A&B\\B&C\end{smallmatrix}\bigr)\).
Carrying out the congruence directly,

\[
R^{\top}HR=\tfrac12\begin{pmatrix}A+C+2B & A-C\\ A-C & A+C-2B\end{pmatrix},
\]

so the transformed cross-term is \((A-C)/2\) **for every value of \(B\)**, and

\[
\boxed{\;R \text{ decorrelates } (q,\eta) \iff A=C.\;}
\]

This derivation replaces an earlier one via \(\tan 2\theta = 2B/(A-C)\), which
reaches the same conclusion but is degenerate at \(B=0\) and is strictly weaker.
The direct form is what should be cited.

Measured:

| case | cross-term before | cross-term after \(R^{\top}HR\) |
| --- | --- | --- |
| \(A=3,\;B=1.7,\;C=3\) | \(1.7\) | \(9.3\times10^{-17}\) |
| \(A=3,\;B=1.7,\;C=0.4\) | \(1.7\) | \(1.30\) |
| \(A=3,\;B=0,\;C=0.4\) | \(0\) | \(1.30\) |
| \(A=10,\;B=0.1,\;C=0\) | \(0.1\) | \(5.0\) |

The last two rows matter more than the first two.  Because the outcome depends
only on \(A-C\), the transform **can create correlation in an already-diagonal
block** (row 3) and **can amplify an existing cross-term by any factor**
(row 4, a fiftyfold increase).  An earlier draft of this note observed that row
2 "reduces the cross-term from 1.7 to 1.30"; that is a case-specific accident of
the chosen numbers and must not be read as a tendency.  The correct statement is
that \(R\) **cannot control the cross-term at all** -- it replaces it with a
quantity that does not depend on it.

Nothing in the design or the frozen state establishes \(A=C\), and no evidence
anywhere in this lane bears on it.  The inertness is moreover exact for the full
four-coordinate block, not merely the \(2\times2\): writing \(T=E\circ\tilde R\)
with \(\tilde R=\operatorname{blkdiag}(R,I_2)\) *linear*, the transformed
curvature is \(\tilde R^{\top}\,\mathrm{Hess}(f\circ E)\,\tilde R\), an orthogonal
congruence with no second-order term, so the whole \(4\times4\) spectrum is
preserved.

**Consequence for the design.**  The claim in §3 of the parent design that the
chart "separates the log-range and log-amplitude axes algebraically" is true as
a statement about *coordinates* and not as a statement about *curvature*.  The
chart's value therefore cannot come from conditioning of the \((q,\eta)\) block.
It can come from only two places: (i) the nonlinear amplitude/direction split
\(E\), which does change the geometry, and (ii) axis alignment, which helps only
a numerical procedure that is **not** affine-invariant -- a diagonal
preconditioner, a coordinate-wise trust region, per-coordinate step control.
A method that is affine-invariant in exact arithmetic gains nothing from \(R\).

This is why the no-fit gate must *report* \(A\), \(C\) and the true
diagonalising angle at the frozen point, and why that report must not be a
pass/fail criterion: no threshold on \(|A-C|\) has any evidence behind it, and
inventing one today would close the lane on a criterion manufactured after the
design.  Deciding which anisotropy the numerical procedure exploits is the job
of the separately reviewed execution design required by parent design §6.

**Terminology hazard.**  "Orthogonal parameters" has an established and
different meaning in this literature -- zero cross-information,
\(i_{\psi\lambda}=0\), as in the Cox--Reid modified profile likelihood.  That
sense is *not* delivered here.  It is also worth recording that Cox--Reid
orthogonality is itself not invariant to one-to-one reparametrisations of the
nuisance parameter, "even reparametrisations that remain orthogonal"
(Reid & Fraser 2003).  A reader arriving from that literature will misread the
lane name.

## 3. The chart treats one of two confounded amplitudes

This is the audit's most consequential finding.

The engine declares a **single** `log_kappa_spde` (`src/gllvmTMB.cpp:748`) but
the SPDE latent-slope block carries **two** LHS columns.  The per-column loading
length is `len_per_col = p * rank - rank * (rank - 1) / 2`
(`src/gllvmTMB.cpp:1830`), which is \(3\) at \(p=3\), rank \(1\); the columns are
laid out consecutively, column 0 then column 1
(`src/gllvmTMB.cpp:1836-1837`).  Hence in the 22-vector:

| raw positions | contents |
| --- | --- |
| 16 | `log_kappa_spde` -- one \(\kappa\), shared |
| 17--19 | loading column 0 (intercept) |
| 20--22 | loading column 1 (GBIF slope); \(\Sigma=\lambda\lambda^{\top}\) at `src/gllvmTMB.cpp:1863` |

That there is only one \(\kappa\) is not inferred from the layout comment: the
`PARAMETER(log_kappa_spde)` at `src/gllvmTMB.cpp:748` is a **scalar**, `kappa_l`
at `:1822` builds a single `Q_lat`, and the one `gmrf_lat` is applied inside the
`kcol` loop at `:1846-1851`.  No per-column range exists.  The column identity
is likewise closed from **data** rather than from the `{0 = intercept,
1 = slope}` comment at `:357`: in the sealed state `Z_spde_lat` is
\(4320\times2\) with column 1 identically \(1\) and column 2 binary with mean
\(0.25\).  Positions 17--19 are therefore the intercept column and 20--22 the
GBIF-indicator column.

Both columns' fields are governed by the same \(\kappa\), so the
\(\kappa\)-versus-amplitude trade-off exists for **both**.  The chart rotates
\(\kappa\) against the slope amplitude only; positions 17--19 remain in the
identity block of the Jacobian (`range-amplitude-orthogonal-contract.R:98`) and
stay confounded with the same \(\kappa\).

*Correction to an earlier draft.*  That draft added "worse, the intercept
amplitude now trades off against *both* new coordinates rather than one".  That
is wrong.  The cross-block \([cK,\;cK]\) has Frobenius norm
\(\lvert K\rvert\sqrt{2c^{2}}=\lvert K\rvert\), **exactly preserved** by the
transform.  The coupling is redistributed across the two new coordinates, not
increased.

**The untreated amplitude is the dominant one, by a factor of 325.**  Read
directly from the sealed V3 state (`v2-materialized-state.rds`, MD5
`e3b17636c9f5fa0e9e555a307c923724`, verified on read):

| block | raw positions | values | norm |
| --- | --- | --- | --- |
| intercept (untreated) | 17--19 | \(21.618,\;-21.081,\;14.560\) | \(33.522\) |
| GBIF slope (charted) | 20--22 | \(0.06615,\;-0.005920,\;-0.07900\) | \(0.10321\) |

\(\lVert\lambda_{\text{intercept}}\rVert / \lVert\lambda_{\text{slope}}\rVert =
324.79\).  The chart therefore treats the numerically **minor** of the two
\(\kappa\)-amplitude confoundings and leaves the major one untouched.  Any
expectation that the chart tames the range--amplitude ridge must be weighed
against that ordering.  The design weighting sharpens this rather than softening
it: `Z_spde_lat` column 2 is active on only \(25\%\) of the \(4320\) rows, so the
intercept column's dominance in the likelihood is larger still than the
parameter norms alone suggest.

**What the 325 figure does and does not establish.**  It is a ratio of
*parameter magnitudes*, not of curvatures.  Ridge severity is a curvature
question, and §2 has just established that nothing in this lane bears on the
curvature.  So the number supports the *ordering* claim -- which confounding is
the larger one -- and does not by itself quantify how much worse the untreated
ridge is.  The qualitative conclusion stands without it; the number should not
be cited as though it measured the ridge.

Separately, and offered as an observation rather than a claim: intercept
loadings of magnitude \(21.6\) and \(21.1\) sit close to the package's own
`loading_runaway_thresh = 25`.  That threshold is family-gated and does not
evaluate on this model, so this is **not** a diagnostic result -- but a reviewer
of the frozen state should be aware of it.

This is recorded as a **scoped limitation of the estimator**, not as a defect to
repair in this lane (maintainer decision, 2026-08-15).  Widening the chart to
six coordinates would be a materially different estimator requiring its own
identity, contract, and review, and adapting the design on speculation is
precisely what this programme is disciplined against.  Parent design §6 must
state the limitation so that the later numerical design cannot silently assume
the ridge has been removed.

## 4. The no-Jacobian argument is sound, and its conditions are checkable

Parent design §2 asserts that no \(|\det J|\) term is added because this is "a
frequentist re-expression of the same marginal Laplace objective, not a
probability-density transformation".  The **pointwise** half of the argument
holds unconditionally; the **argmin** half rests on three conditions, not the
two an earlier draft of this note listed.  The third is the one with no
evidence, and omitting it let that draft call the section "sound" when it is
not yet:

1. **The chart acts on fixed parameters only.**  Verified directly on the sealed
   V3 state during this audit: `random = c("s_B", "g_spde_slope")`, and the
   22-entry `parameter_order` contains neither.  Positions 16 and 20--22 are
   fixed parameters, so the inner Laplace integral is untouched and
   \(f(T(\phi))\) is the *identical number*, not an approximation of it.  Had
   the chart touched a random effect, the Laplace approximation itself would
   move, because it is not invariant under nonlinear reparametrisation of the
   integrand's variable.
2. **\(T\) is a bijection on the stated domain.**  Established in §5 below.

3. **The raw optimum lies inside the chart's image.**  \(T\) is a bijection onto
   \(\mathbb R\times\{\lambda:\lambda_1>0\}\), **not onto \(\mathbb R^{4}\)**.
   If the raw \(\arg\min\) has \(\lambda_1\le0\), then
   \(T^{-1}(\arg\min_\theta f)\) is simply **undefined** and the identity below
   does not hold.  What makes the restriction harmless is precisely that the
   negative representative is an equivalence class member rather than a
   different estimand -- which is the **full random-effect sign-orbit property
   of parent design §5 gate 3, recorded in §10 as untested**.

Given all three, \(\arg\min_{\phi} f(T(\phi)) = T^{-1}(\arg\min_{\theta}
f(\theta))\) exactly, and a Jacobian term would be an error rather than an
omission.  A \(|\det J|\) term would be required only for a density
transformation -- a Bayesian prior, or an integral taken in the new coordinates
-- and neither occurs.

**This is the section's real status.**  Conditions 1 and 2 are verified.
Condition 3 is not, and it is not a formality: the \(\phi\)-problem is a
relabelling of a *restricted* \(\theta\)-problem, and only the sign-orbit result
makes the restriction without loss of generality.  Until gate 3 passes on the
immutable V3 state, the no-Jacobian argument licenses the *objective value*
identity but not the *optimum* identity.  Note also that the chart pushes the
\(\lambda_1=0\) boundary to \(\eta\to-\infty\), i.e. to infinite distance in
\(\phi\): a raw path that would cross the boundary cannot be represented at all.

A second, smaller qualification: \(T(\phi)\) reproduces \(\theta\) bit-for-bit
only in exact arithmetic -- the gate's own \(64\varepsilon\) tolerance concedes
this -- and TMB's warm-started inner Newton makes \(f\) mildly path-dependent.
"The identical number" is an exact-arithmetic statement, not a claim about a
particular evaluation.

## 5. Bijectivity, orientation, and the exact determinant

The forward and inverse maps compose to the identity: substituting
\(q=(u+v)/\sqrt2,\ \eta=(u-v)/\sqrt2\) into
\(u=(q+\eta)/\sqrt2,\ v=(q-\eta)/\sqrt2\) returns \((u,v)\), and
\(\log\lambda_1=\eta,\ \lambda_2/\lambda_1=a,\ \lambda_3/\lambda_1=b\) invert
\(E\) on \(\lambda_1>0\).  The chart is a smooth bijection
\(\mathbb R^4\to\mathbb R\times\{\lambda:\lambda_1>0\}\).

The local Jacobian block, rows \((q,\lambda_1,\lambda_2,\lambda_3)\) against
columns \((u,v,a,b)\), is block lower-triangular, giving

\[
\det J_{\text{local}} = \det\!\begin{pmatrix}c&c\\cs&-cs\end{pmatrix}\cdot s^{2}
= -2c^{2}s\cdot s^{2} = -s^{3} = -\lambda_1^{3},
\qquad c=\tfrac1{\sqrt2},\; s=e^{\eta}.
\]

Confirmed numerically at the contract's test point: computed determinant
\(-2.895242\times10^{-4}\), \(-\lambda_1^{3}=-2.895242\times10^{-4}\), ratio
\(1.0\); the full \(22\times22\) determinant equals the same value, the identity
block contributing \(1\).  The sign decomposes exactly as §1 predicts:
\(\det R=-1\) times \(\det E = s^{3}\).

Two consequences.  The map is **orientation-reversing everywhere** and its
determinant is **never zero on the domain**, so it is a local diffeomorphism at
every admissible point.  But \(\det J\to 0\) as \(\lambda_1\to0\): the chart
degenerates exactly where the reference loading vanishes.

**The reference coordinate is silently index 1.**  Nothing in the design states
why \(\lambda_1\) carries the amplitude while \(\lambda_2,\lambda_3\) become
ratios.  At the frozen point \(\lambda=(0.06615,\,-0.00592,\,-0.07900)\), so
\(\lambda_1\) is not the largest-magnitude component -- \(\lambda_3\) is.  A
reference chosen as the largest component would be better conditioned, but
selecting it from the data would forfeit the "fixed, predeclared, not adapted"
property the design rests on in §3.  The current choice is defensible; it is the
*silence* that is the defect.  The design should state index 1 as predeclared,
and the gate should record \(\lambda_1\) at the frozen point so a later reader
can see how close to degeneracy the chart was.

## 6. The gradient tolerance does not test what it says

Parent design §5 gate 2 requires the analytic transformed gradient to match a
22-coordinate central-difference ledger "to `1e-5`", and the contract supplies
`rao_relative_error` (`range-amplitude-orthogonal-contract.R:118-124`) as the
metric.  That function computes

```
max(abs(x - y)) / max(1, abs(x), abs(y))
```

-- a single ratio whose denominator is the largest magnitude anywhere in the
vector.  It fails in both directions.

**It masks.**  With `x = c(1e6, 1, 2)` and `y = c(1e6, 2, 2)`, coordinate 2 is
wrong by 100%, yet the metric returns \(1\times10^{-6}\) and passes a
\(1\times10^{-5}\) gate.  The worst per-coordinate relative error is \(0.5\).

**It is not relative.**  When every component is below 1 the denominator pins to
\(1\) and the metric degenerates to an *absolute* tolerance.  That is exactly
the regime that obtains at the frozen point.  Read from the sealed V3 state:

| quantity | value |
| --- | --- |
| \(\max_j\lvert g_j\rvert\) | \(2.8237\times10^{-4}\) |
| \(\min_j\lvert g_j\rvert\) | \(1.5687\times10^{-6}\) |
| spread | \(180\times\) |
| coordinates with \(\lvert g_j\rvert < 10^{-5}\) | **4 of 22** |
| \(\lvert g\rvert\) at chart coordinates 16, 20--22 | \(8.86\times10^{-5},\;2.82\times10^{-4},\;2.82\times10^{-4},\;1.60\times10^{-4}\) |

The consequences are severe and specific.  For the four coordinates whose
gradient is already below \(10^{-5}\), the gate's tolerance **exceeds the
quantity being tested**: a 100% error in those coordinates cannot be detected at
all.  On the smallest, \(1.57\times10^{-6}\), an admissible absolute deviation of
\(10^{-5}\) is 637% of the value.  Even on the chart's own log-range coordinate,
\(\lvert g_{16}\rvert = 8.86\times10^{-5}\), the tolerance admits an 11% relative
error.

A correction of record: an earlier draft of this note cited
\(0.002431251466981631\) as the gradient scale.  That figure is from the
**G3 attempt root** `G3_P1_S3_C360_R3_V3`
(`2026-08-14-g3-marginal-curvature-terminal-adjudication.md`), a different and
consumed root.  The predecessor this chart actually starts from is MSPDE V3,
whose maximum is \(2.82\times10^{-4}\) -- about \(8.6\times\) smaller, which
makes the defect correspondingly worse, not better.  The frozen state records
`convergence = 0`.

### 6.1 The obvious remedy does not work, and a strictly relative gate is impossible

An earlier draft of this note prescribed "a per-coordinate **relative**
tolerance, via a companion `rao_coordinatewise_relative_error`".  That
prescription was wrong in two independent ways, and both were found by review
rather than by the draft itself.  They are recorded here because the failure is
instructive: the defect has **two faces** and the obvious fix addresses only
one.

**Face 1 -- masking by a large sibling.**  Fixed by going per-coordinate.

**Face 2 -- the floor at 1.**  *Not* fixed.  The companion function divides by
`pmax(1, |x|, |y|)`, which is the same floor the same paragraph had just
condemned.  Every coordinate below unity is still judged absolutely, and every
coordinate of the frozen gradient is below unity.  Demonstrated on the sealed
state: zeroing \(g_8\) -- a 100% error on one of the four coordinates the
finding was written to protect -- returns \(5.53\times10^{-6}\) and **passes** a
\(10^{-5}\) gate.  The remedy was vacuous for precisely the coordinates that
motivated it.

**And a strictly relative \(10^{-5}\) is unreachable anyway.**  The objective at
the frozen point is \(\lvert f\rvert = 2549.04\), so the best attainable
central-difference accuracy is of order
\((\varepsilon\lvert f\rvert)^{2/3} = 6.84\times10^{-9}\) *absolute*.  Against the
gradient components that is:

| reference | best-case relative accuracy |
| --- | --- |
| \(\max_j\lvert g_j\rvert = 2.82\times10^{-4}\) | \(2.42\times10^{-5}\) |
| \(\min_j\lvert g_j\rvert = 1.57\times10^{-6}\) | \(4.36\times10^{-3}\) |

**All 22 of 22 coordinates fail a true \(10^{-5}\) relative gate**, including the
largest.  So the literal reading of parent design §5 gate 2 -- "matches ... to
`1e-5`", relative -- is not merely loose, it is **unsatisfiable**; the only
reason it would ever pass is Face 2.

### 6.2 What the gate actually requires

A **mixed** criterion, with both tolerances named and neither defaulted:

\[
\lvert x_j - y_j\rvert \;\le\; \texttt{atol} + \texttt{rtol}\cdot\lvert y_j\rvert
\qquad\text{for every }j,
\]

with \(y\) the finite-difference ledger (the reference) and \(x\) the analytic
transformed gradient (the quantity under test).  `rao_coordinatewise_discrepancy`
is added to the contract; it returns the worst ratio, passes when that is
\(\le1\), and **requires** `atol` and `rtol` -- there is no default, because
every default that has been tried here was silently wrong.  Verified: the same
zeroed-\(g_8\) probe returns \(5242.67\) and fails.

`atol` **must be justified against the measured central-difference noise floor
of the objective actually under test**, not against \(1\) and not against
convenience.  The two numbers are deliberately **not fixed in this note**: the
floor above is an order-of-magnitude estimate from \(\lvert f\rvert\), and the
execution design must measure it -- for instance by differencing at several step
sizes and observing where the estimate stops improving -- before choosing them.
Inventing them here would repeat exactly the error this section documents.

`rao_relative_error` remains valid for scalar comparisons such as the objective.
`rao_coordinatewise_relative_error` remains useful as a diagnostic for Face 1
alone.  **Neither may gate the gradient ledger.**

## 7. Evidence citation to correct

Parent design §2 cites the engine for the claim that the frozen model has
`n_lhs_cols_spde_lat = 2` and `d_spde_slope = 1`.  Both are `DATA_INTEGER`
inputs -- `d_spde_slope` at `src/gllvmTMB.cpp:365` and `n_lhs_cols_spde_lat` at
`:366`, with a runtime validator "must be 1 or 2" at `:1811-1812` (an earlier
draft of this note gave `:366` for both).  The source therefore proves only that the engine
**supports** those values; it cannot establish what the frozen Paper 1 model
uses.  The binding evidence is the sealed MSPDE V3 state, whose read-only
inspection recorded `random = c("s_B", "g_spde_slope")`,
`g_spde_slope = 118 x 1 x 2`, `n_lhs_cols_spde_lat = 2`, and `d_spde_slope = 1`
(`docs/dev-log/recovery-checkpoints/2026-08-15-codex-gauge-trust-region-checkpoint.md`).

The citation should be corrected, and the shape must be **re-asserted at
runtime** from the sealed state rather than assumed, with a typed failure.

## 8. Domain guard

The contract admits any \(\lambda_1>0\)
(`range-amplitude-orthogonal-contract.R:50-52,62-64`).  Adversarial probing
shows the boundaries divide cleanly, and **not in the way the first pass of this
audit assumed**.

*Fails loudly, correctly:* \(\lambda_1=0\); \(\lambda_1<0\);
\(\lambda_1=10^{-320}\) with \(\lambda_2=1\); \(\eta=\pm745\) (amplitude overflow
and underflow).  These need no new guard, and none was added.

*Silently wrong:* at \(\lambda_1=10^{-160}\) and at denormal
\(\lambda_1=5\times10^{-324}\), the round trip succeeds, every finiteness check
passes, and `rao_full_jacobian` returns an **all-finite** Jacobian whose
\(\det J_{\text{local}}\) has underflowed to **exactly \(-0\)**.  At
\(\lambda_1=10^{160}\) the determinant is \(-\infty\) and the round-trip absolute
error is \(5.09\times10^{146}\), still passing the finiteness check.  Forward,
\(\eta=-700\) with \(a=10^{300}\) yields a finite positive
\(\lambda_1=9.51\times10^{-305}\) and is accepted.

The cause is structural: the contract validates `any(!is.finite(jacobian))` and
**never checks the determinant it spends §5 deriving**.  So the chart admits
points at which it is numerically non-invertible while reporting nothing.  By
this section's own criterion -- a guard is justified where the answer is
silently wrong, not where it already fails loudly -- **F5 is not "minor"**, and
the earlier severity is corrected in §9.  A determinant check belongs in the
contract; the specific floor is left to the execution design, since it depends
on the conditioning the numerical procedure actually needs.

## 8a. The chart manufactures its primary coordinate by cancellation (F7)

Not raised in the first pass of this audit, and found by review.

At the frozen point \(q = 2.687653\) and \(\eta = \log\lambda_1 = -2.715757\).
These are nearly negatives of one another, so

\[
u = \frac{q+\eta}{\sqrt2},\qquad q+\eta = -0.02810406,
\]

is formed by subtracting quantities of magnitude \(\approx2.7\) to obtain one of
magnitude \(\approx0.028\).  That destroys \(\log_{10}(2.7/0.028) = 1.99\) -- very
nearly **two decimal digits** -- in the chart's own primary coordinate, and the
loss grows without bound as \(\kappa\) and the amplitude drift toward
reciprocity.

Two consequences.  First, this is a genuine numerical property of the
\(45^{\circ}\) mixing, not of the model: the frozen state happens to sit close to
\(\kappa\approx1/\text{amplitude}\), which is precisely where the transform is
worst conditioned in floating point.  Second, it **compounds F3**: the coordinate
in which the gate can least afford noise is the one the chart creates by
cancellation.  The gate should record \(q+\eta\) alongside \(\lambda_1\) as a
conditioning witness.

## 9. Findings, and what each forces

| # | Finding | Severity | Action |
| --- | --- | --- | --- |
| F1 | One \(\kappa\), two loading columns; only the slope amplitude is charted (§3) | material | record as a scoped limitation in parent design §6 |
| F2 | The orthogonal factor decorrelates iff \(A=C\); it cannot change conditioning (§2) | material | gate reports \(A\), \(C\), true angle; explicitly not pass/fail |
| F3 | Gate-2 metric masks, is absolute below 1, and a strictly relative gate is unreachable (§6) | **most serious** | mixed `atol`/`rtol` criterion; `rao_coordinatewise_discrepancy`; tolerances fixed by the execution design after measuring the noise floor |
| F4 | Engine citation cannot support the shape claim (§7) | correctness of record | correct the citation; re-assert shape at runtime |
| F5 | Chart is admitted at points where \(\det J\) has underflowed to \(-0\); reference index unstated (§5, §8) | **material** (raised from minor) | determinant check belongs in the contract; state index 1 as predeclared; record \(\lambda_1\) |
| F6 | \(\det J=-\lambda_1^{3}\) exactly, orientation-reversing, never zero (§5) | none -- confirmatory | pin value and sign in the tests |
| F7 | The chart forms \(u\) by cancellation, losing ~2 decimal digits at the frozen point (§8a) | material | record \(q+\eta\) as a conditioning witness; compounds F3 |

### Revisions forced by independent review

This note was reviewed adversarially after its first pass, and the review
changed it materially.  Recording what it overturned, because a finding that
survived attack and one that was waved through are not the same evidence:

- **F3's remedy was refuted.**  The prescribed per-coordinate function kept the
  floor at 1 and passed a 100% error on the very coordinates the finding
  protected.  A strictly relative gate was then shown *unreachable for all 22
  coordinates*.  The metric was rebuilt (§6.2).  This was the first pass's
  worst error: it diagnosed correctly and prescribed something that could not
  work.
- **§4 was incomplete.**  The argmin identity needs a third condition -- that
  the raw optimum lies in \(\{\lambda_1>0\}\) -- which is the untested sign-orbit
  gate.  The first pass called the section "sound".
- **F2's derivation was weak** (degenerate at \(B=0\)) and its severity too
  lenient: the transform can *create* and *amplify* the cross-term, not merely
  fail to remove it.
- **F1 contained a refuted sentence** -- the cross-block Frobenius norm is
  preserved exactly, so the coupling is redistributed, not worsened.  The 325
  figure was also reclassified as evidence of *ordering*, not of ridge severity.
- **F5 was under-graded**, and **F7 was missed entirely**.
- **The verification receipt contained a false row** (§9a).

Two findings were raised by direct measurement rather than review: F1's
\(325\times\) ordering and F3's vacuity for 4 of 22 coordinates.

## 9a. Verification receipt for this audit

Every numerical statement above was recomputed during the audit rather than
carried over from a prior document.

| claim | how checked | result |
| --- | --- | --- |
| V3 state identity | `tools::md5sum` on `v2-materialized-state.rds` | `e3b17636c9f5fa0e9e555a307c923724` -- matches the design's declared MD5 |
| raw order | `parameter_order` from the sealed state vs `rao_raw_order()` | identical, all 22 entries |
| model shape | `n_lhs_cols_spde_lat`, `d_spde_slope` from the sealed state | \(2\) and \(1\) |
| random effects | `random` from the sealed state | `s_B`, `g_spde_slope` |
| contract test point | test fixture positions 16, 20--22 vs sealed `theta` | **positions 20--22 bit-identical; position 16 is NOT** -- see below |
| \(\det J\) | contract Jacobian vs \(-\lambda_1^{3}\) | ratio \(1.0\) |
| decorrelation iff \(A=C\) | \(R^{\top}HR\) off-diagonal at \(A=C\) and \(A\neq C\) | \(9.3\times10^{-17}\) vs \(1.30\) |
| eigenvalue preservation | \(\operatorname{eig}(H)\) vs \(\operatorname{eig}(R^{\top}HR)\) | agree to \(1.1\times10^{-16}\) |
| metric masking | `rao_relative_error` on the \(10^{6}\) probe | returns \(10^{-6}\); worst per-coordinate error \(0.5\) |

**Correction to this receipt.**  Its first version asserted that the test
fixture is identical to the sealed state at all four charted coordinates.  That
row was false, and the review caught it using this document's own tolerance:

| | value |
| --- | --- |
| sealed `theta[16]` | `2.6876531596114015` |
| fixture `theta[16]` (`tests/…-orthogonal-contract.R:11`) | `2.687653160` |
| `identical()` | **FALSE** |
| absolute difference | \(3.886\times10^{-10}\) |
| gate tolerance \(64\varepsilon\) | \(1.421\times10^{-14}\) |
| ratio | **27,345\(\times\) the tolerance** |

The fixture value is truncated to ten significant digits.  Positions 20--22 *are*
bit-identical (difference exactly zero).  The consequence is concrete and must
be fixed before any gate is written: **anything that starts from the fixture and
asserts \(T(\phi_0)=\theta_0\) to \(64\varepsilon\) against the sealed packet will
fail at coordinate 16** -- not because the chart is wrong, but because the
fixture is not the state it is claimed to be.  The gate must read \(\theta_0\)
from the sealed packet, never from a transcribed literal.

That this note's own receipt asserted a false identity, and that the falsifying
tolerance was one this note itself specifies, is the sharpest available argument
for the independent-review requirement in the parent design's discipline line.

Reading the sealed packet is a read-only operation and mutates nothing; the
design requires the executable gate to reread it in any case.  No optimiser,
`MakeADFun`, fit, smoke, or result root was run at any point in this audit.

**Nothing here refutes the chart, and one thing here does not yet establish it.**
Confirmed outright: bijectivity on the stated domain, a nonvanishing determinant
throughout it, and the derivative contract of parent design §4 exactly as
written.  Confirmed in part: the no-Jacobian argument holds pointwise
unconditionally, but its *optimum* half waits on the untested sign-orbit gate
(§4 condition 3).  An earlier draft of this paragraph claimed §4 confirmed the
argument outright; it does not.

What the audit removes is the assumption that the chart's *name* describes its
mechanism.  The working part is the nonlinear amplitude/direction split; the
orthogonal factor is inert with respect to conditioning and can as easily create
a cross-term as remove one; one of the two confounded amplitudes is untouched,
and it is the larger by a factor of 325; and the chart manufactures its own
primary coordinate by a subtraction that costs two decimal digits at the frozen
point.

None of that is a reason to abandon the chart.  It is the set of things a later
execution design must not assume away.

## 10. Out of scope

The full random-effect sign-orbit check (parent design §5 gate 3) requires the
compiled objective and is deferred, unchanged, to the live phase.  Only its pure
consequences are testable here: \(\lambda\lambda^{\top}\) is invariant under
\(\lambda\to-\lambda\), and the chart rejects the negative representative with a
typed error rather than repairing it by a sign flip.  Whether the signed
conditional Hessian, predictor, and marginal objective agree on the immutable V3
state remains **untested and is a prerequisite, not an assumption**.

Its status was upgraded by this audit.  §4 condition 3 shows the sign-orbit
property is not merely one gate among four: it is what makes the chart's
restriction to \(\lambda_1>0\) without loss of generality, and therefore what
licenses the argmin half of the no-Jacobian argument.  Until it passes, the
chart is established as an exact re-expression of the objective's *values* but
not of its *optimum*.  It should be sequenced first among the live gates, not
third.
