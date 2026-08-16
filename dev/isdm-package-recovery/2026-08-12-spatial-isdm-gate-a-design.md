# Spatial iSDM Stage 1: Gate-A architecture and information specification

**Status:** private design only.  It preserves all retained nonspatial G2
HOLDs and authorises neither implementation nor computation.

## 1. Aim and protected evidence

The new question is whether a two-source spatial relative-intensity iSDM can,
under its own frozen synthetic DGP, distinguish a shared ecological spatial
field from a GBIF-only spatial bias field.  It is not a repair, rerun, or
reinterpretation of `G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`,
`G2C_SMOKE_ADMISSION_HOLD`, or `PAPER2_PRIVATE_STOP_HOLD`.

Paper 1 means the three-species family.  `S=6` is a separate spatial design
family; it does not reopen or continue the terminal nonspatial
`PAPER2_PRIVATE_STOP_HOLD` evidence-to-reader programme.  The two spatial
families receive separate seed panels, all-attempt denominators, summaries,
and verdicts.

## 2. Candidate estimand and source map

For cell `c`, species `s`, and visit `v`, the candidate DGP is

\[
 \eta^{E}_{cs}=\alpha_s+x_c\beta_s+u_c\lambda_s+e_{cs},
 \qquad e_{cs}\sim N(0,\psi_s^2),
\]
\[
 Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c\exp(\eta^E_{cs}+
 \delta_s+b_c\gamma_s+h_c)\},
 \qquad
 D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a^S_c\exp(\eta^E_{cs})]\}.
\]

`u` is the ecological SPDE field and is visible to both sources through
`eta^E`; `h` is a GBIF-only spatial bias field and is structurally absent from
every PA row.  The model remains relative intensity: it has no detection
multiplier or absolute-abundance interpretation.

The engine-feasibility review has narrowed this candidate: the current SPDE
implementation can represent `u` and `h` as the intercept and GBIF-indicator
columns of one augmented `spatial_latent(1 + isdm_gbif | cell_id, d = K)` term.
That design gives separate field scores and loading matrices, while enforcing a
shared mesh, range (`kappa`), and rank.  It cannot represent separately ranged
or separately meshed fields without a new TMB architecture.  Thus Gate A must
choose one of two explicit routes: (a) the shared-range private design above,
or (b) a new-architecture design that is not implemented by this programme.
The PA cloglog branch also needs a private, source-contract-specific augmented
SPDE admission; the existing public augmented-slope gate must remain fail-loud.

## 3. ADEMP information design

### Aims

1. Establish whether source-pure PA data identify the ecological field while
   GBIF data identify the additional bias field in a known-truth regime.
2. Determine separately whether added cells, spatial layout, and source support
   change recovery in Paper 1 and Paper 2.

### DGP factors

The Stage-1 design freezes values only after the source map and engine review.
It must cross the following factors without changing the estimand:

| Factor | Ordinary values | Reason |
| --- | --- | --- |
| Family | Paper 1 `S=3`; Paper 2 `S=6` | Community dimension is a separate family, not replication. |
| Cells | `C=360`, then `C=1,000` | Core versus realistically large synthetic spatial support. |
| Layout | increasing-domain; fixed-domain infill | Separates new spatial extent from denser sampling. |
| Shared field range / spacing | short and moderate shared range-to-spacing ratios | Prevents a single mesh resolution from masquerading as a sample-size result. |
| Source support | adequate paired PA coverage | Ordinary separation regime. |
| PA visits | `r=3` | Retains the Paper 2 repeated-PA observation structure. |

The ordinary design has `R=20` seed-pinned replicates per family/cell/layout
cell.  Its binomial pass-rate MCSE is reported, including the approximately
11% worst-case MCSE at `R=20`.

### Attacks

Each family carries separate, retained attack panels: weak PA spatial coverage,
ecological--bias near-collinearity, and disconnected GBIF/PA support.  Their
expected outcomes are respectively degraded field separation, degraded or
non-admission, and a diagnostic warning/rejection or retained recovery failure.
An attack cannot supply an ordinary pass.

### Estimands and performance measures

Every attempted fit retains numerical predicates and the existing five
nonspatial recovery measures where applicable.  Spatial additions are:

- ecological-field map correlation/error on the predeclared aligned scale;
- GBIF-bias-field map correlation/error on its declared scale;
- field range and marginal-scale error, only if these are estimable under the
  implemented parameterisation;
- a separation diagnostic showing that an estimated GBIF-only field is absent
  from PA prediction.

All starts, selected start, warnings/errors, objective, gradient, Hessian/SE
state, profiles, maps, truth, data/mesh hashes, stage time, peak RSS, and first
failure state remain in the fixture ledger.  Missing or failed fields are not
eligible-only deletions.

## 4. Gate-A acceptance requirements

Before implementation, Gauss/Noether must certify that the shared-range,
intercept-plus-GBIF-indicator source map is represented without a silent
one-field collapse; otherwise the result is an architecture HOLD.  Fisher must
approve the estimator-to-truth map and all-attempt metrics.  Rose must verify
that this document does not alter the protected nonspatial contracts.

Only then may a separate approval authorise private implementation of source
purity, aligned mesh projection, the private cloglog admission, field-map
construction, extractor/truth alignment, and no-fit guards.  The implementation
must prove that perturbing only the GBIF field leaves PA eta and PA NLL exactly
unchanged.  No smoke, timing probe, Totoro run, or recovery campaign is
authorised here.

## 5. Claim fence

A later pass would be evidence only for the exact synthetic relative-intensity
DGP, field ranges, sampling layout, source support, and species family.  It
does not support occupancy/detection, count surveys, absolute abundance,
empirical data, generic zero inflation, arbitrary source integration, a public
workflow, or `S=10,000` scalability.
