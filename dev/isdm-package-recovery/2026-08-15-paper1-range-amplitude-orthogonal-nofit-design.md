# Paper 1 range--amplitude orthogonal-chart no-fit / provenance gate --
# design-only specification

**Status:** design-only.  This document specifies a no-fit provenance and
identity gate for the estimator identity `PAPER1_SPDE_SLOPE_RANGE_AMPLITUDE_ORTHOGONAL_V1`.
It is not a runner, not a contract, not a test file, and not an authorisation.
No TMB object is constructed by this document, no DLL is loaded, no
`MakeADFun` call is proposed, no optimizer runs, and no numerical result is
claimed anywhere below.  Every numeric value cited from the sealed predecessor
state is reported for specification purposes only; the gate itself must
re-derive every one of those values at runtime from the sealed state, and this
document earns none of them.

This specification operationalises `2026-08-15-paper1-range-amplitude-orthogonal-design.md`
("the parent design"), Section 5's four no-fit gates and Section 7's amendment
after the independent audit at
`2026-08-15-paper1-range-amplitude-orthogonal-map-audit.md` ("the audit").
Where this document and the parent design disagree, the parent design governs;
this document exists to make Section 5 and Section 7 executable, not to revise
them.

## A. Scope and non-authorisation

This document authorises:

- writing pure R contract functions and their unit tests against synthetic
  inputs;
- writing a compiled random-effects fixture that is **not** the frozen Paper 1
  model (Gate 4 below);
- an independent mathematical and systems review of the specification itself.

This document does **not** authorise, and no later step may treat it as having
authorised:

- constructing the frozen Paper 1 `MakeADFun` object, loading its DLL, or
  calling `obj$fn`/`obj$gr`/`obj$report`/`sdreport` against it;
- claiming a scientific packet root, running a smoke, or writing anything
  under `dev/isdm-package-recovery/results/` (gitignored,
  `.gitignore:128`);
- any recovery calculation, coverage claim, or comparison to a known-truth
  simulation;
- any numerical-admission terminal (`_ADMISSION`, `_ELIGIBLE`, `_VALID` in the
  sense of a fitted result) -- the only positive terminal this gate can ever
  emit is the no-fit `RAO_NOFIT_VALID` defined in Section 8, which certifies
  identity and provenance, not a model result;
- treating passage of every gate below as evidence that the estimator
  recovers anything. A clean no-fit gate is a precondition for building a
  numerical execution design (parent design Section 6); it is not a substitute
  for one.

## B. The immutable predecessor: sealed MSPDE V3 packet

### B.1 Identity

- Root: `/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3`
- Commit: `a6255290810269510bba87951ea2dee365861e21`
- Materialized-state MD5: `e3b17636c9f5fa0e9e555a307c923724`

This MD5 belongs to the file **`v2-materialized-state.rds`** inside the V3
root, not a file literally named `materialized-state.rds`
(`spde-slope-gauge-nofit-contract.R:29-44`; independently re-confirmed against
the packet on disk with `md5 -q .../MSPDE_P1_S3_C360_R3_V3/v2-materialized-state.rds`
during the drafting of this document, returning the identical digest). The
`v2-` prefix is retained inside the `V3`-named root and must **not** be
"corrected" to `v3-` by any runner; it is the historical filename the
predecessor packet actually uses.

### B.2 What must be reread and byte-verified before a new root is consumed

Mirroring the established predecessor-binding pattern at
`spde_slope_gauge_nofit_locked_predecessor()`
(`spde-slope-gauge-nofit-contract.R:29-54`) and its validator
`spde_slope_gauge_nofit_validate_predecessor_bytes()`
(`spde-slope-gauge-nofit-contract.R:123-225`), any runner built from this
specification must, before it creates its own staging root:

1. Normalise the predecessor root path and require it to resolve to exactly
   the path in B.1 (`normalizePath(..., mustWork = TRUE)`, rejecting a
   missing, relocated, or symlinked packet).
2. List the predecessor root's top-level, non-recursive inventory and require
   it to equal, as a set, exactly the seven declared files plus the one
   declared empty claim directory:

   | file | role |
   | --- | --- |
   | `all-attempt-ledger.rds` | prior attempt history |
   | `attempt-started.rds` | marker |
   | `file-manifest.csv` | ordered `path,md5` manifest |
   | `root-receipt.rds` | binding receipt (fields: `schema`, `source_gate`, `root`, `commit`, `consumed_v2`, `runner_md5`, `contract_md5`, `design_md5`; `spde-slope-gauge-nofit-contract.R:186-196`) |
   | `session-info.rds` | `sessionInfo()` |
   | `time-estimate.md` | pre-run estimate text |
   | `v2-materialized-state.rds` | the frozen fit state (B.1) |

   directory: `.attempt-started.claim` (must be a real, non-symlinked,
   **empty** directory -- `spde-slope-gauge-nofit-contract.R:157-172`).
3. Confirm every declared file is a regular, non-symlinked file
   (`.spde_slope_gauge_nofit_regular_file`,
   `spde-slope-gauge-nofit-contract.R:19-27`) and that its MD5 equals the
   locked digest exactly (B.1's value for the state file; the receipt,
   ledger, marker, and manifest digests are the ones already frozen at
   `spde-slope-gauge-nofit-contract.R:37-43`, which this gate must re-read
   rather than assume).
4. Confirm `file-manifest.csv` has exactly the two columns `path, md5`, and
   that its declared row order equals the locked file order exactly (no
   reordering, no omission, no extra row) -- the ordered-manifest contract at
   `spde-slope-gauge-nofit-contract.R:106-121`.
5. Read `root-receipt.rds` and require its named-list shape and every field
   above to match the locked commit, and require the receipt's own
   `contract_md5` to equal the MD5 of the historical production terminal
   validator file (B.3) read fresh from disk -- not assumed from a cached
   digest (`spde-slope-gauge-nofit-contract.R:200-208`).
6. Read `v2-materialized-state.rds` and validate its shape against the fixed
   field list `schema, objective, theta, gradient, convergence, covariance,
   start_provenance, restart_history, warm_restart_provenance,
   isdm_polish_provenance, parameters, map, data, random, block_labels,
   parameter_order` (`.spde_slope_gauge_nofit_state_ok`,
   `spde-slope-gauge-nofit-contract.R:56-104`), including that `theta` and
   `gradient` are finite doubles named in exactly the locked 22-coordinate raw
   order and that `parameter_order` equals that same order.

A failure at any of steps 1--6 is `RAO_NOFIT_PREDECESSOR_REPLAY_HOLD`
(Section 8); it is an infrastructure/provenance finding, never a numerical
one, and it must retain whichever partial byte evidence was actually read.

### B.3 The historical production terminal validator

The parent design (Section 1) requires rereading "the ... production terminal
validator" alongside the receipt/marker/ledger/manifest/claim directory. In
the established predecessor lane this is the file named
`matched-spde-smoke-contract.R` from the MSPDE V3 lane's own repository
location (`spde-slope-gauge-nofit-contract.R:48-52`, `historical_contract_path`
/ `historical_contract_md5`). This gate must resolve that same file from the
MSPDE V3 lane (not from this worktree, where it does not exist -- confirmed
absent here during drafting) and bind its MD5 exactly as the predecessor
receipt's `contract_md5` field requires (B.2 step 5). This gate does not
re-derive a new validator; it reuses the identical historical one, byte for
byte.

## C. Proposed gate identity and packet layout

### C.1 Gate identity

No no-fit gate identity has been minted for this estimator anywhere in the
repository as of this writing. Mirroring the established derivation --
`PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1`/`V2` sit alongside the numerical
`PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1`, both stems from the shorter base
`PAPER1_SPDE_SLOPE_GAUGE` (`materialize-paper1-spde-slope-gauge-nofit-gate.R:203,238`;
`materialize-paper1-spde-slope-gauge-trust-region.R:31,56`) -- this
specification proposes:

```
PAPER1_SPDE_SLOPE_RANGE_AMPLITUDE_ORTHOGONAL_NOFIT_GATE_V1
```

taking the estimator identity `PAPER1_SPDE_SLOPE_RANGE_AMPLITUDE_ORTHOGONAL_V1`,
stripping the trailing `_V1`, and appending `_NOFIT_GATE_V1`. This name is
**proposed, not established**; it should be confirmed (or replaced) by the
independent review in Section G before any runner uses it.

### C.2 Root location and packet contents

Root: `dev/isdm-package-recovery/results/PAPER1_SPDE_SLOPE_RANGE_AMPLITUDE_ORTHOGONAL_NOFIT_GATE_V1`,
under the gitignored results tree (`.gitignore:128`).

Two established packet shapes exist for this family of lane, and they differ
in exactly the way this document's task brief anticipated:

- The single-attempt V1 gauge no-fit gate's sealed packet holds
  `child-receipt.rds`, `[no-fit-result.rds` or `unvalidated-child-result.rds]`,
  `file-manifest.csv`, `materializer.R`, `root-receipt.rds`,
  `session-info.rds`, `time-estimate.md`, plus the empty
  `.attempt-started.claim` directory
  (`.spde_slope_gauge_nofit_gate_files`, `spde-slope-gauge-nofit-contract.R:770-783`).
  It carries **no** `attempt-started.rds` marker and **no**
  `all-attempt-ledger.rds` -- those are absent from this lane because it is
  single-shot by construction.
- The V2 gate and the trust-region estimator both add
  `attempt-started.rds` (marker), `all-attempt-ledger.rds` (multi-attempt
  history), and, for trust-region, `control.rds` and the two-stage
  `predecessor-v3-*`/`v3-live-child.rds`/`worker-result.rds` files
  (`materialize-paper1-spde-slope-gauge-trust-region.R:37-48`).

This specification adopts the **marker-plus-ledger** shape (the second
pattern above), because the task that produced this document explicitly
named `attempt-started.rds` and `all-attempt-ledger.rds` as required packet
slots. A reviewer should treat this as a deliberate choice to admit more than
one no-fit attempt over this estimator's lifetime (e.g. after a
`RAO_NOFIT_INFRASTRUCTURE_HOLD`), not as a claim that the simpler V1 shape is
wrong -- the V1 shape remains a valid, simpler alternative and is the closer
precedent by mechanism (this is a pure no-fit gate, not a two-stage
numerical worker). Section G lists this as an item for explicit confirmation.

Under the adopted shape, the sealed root holds:

| slot | role | source of convention |
| --- | --- | --- |
| `attempt-started.rds` | marker, written before any child launches | `spde-slope-gauge-nofit-contract.R:38` |
| `.attempt-started.claim` | empty claim directory | `spde-slope-gauge-nofit-contract.R:45`, `:157-172` |
| `all-attempt-ledger.rds` | ordered record of every attempt against this root | `spde-slope-gauge-nofit-contract.R:37` |
| `root-receipt.rds` | binding receipt: predecessor projection, source hashes, DLL identity (absent/NA here -- no DLL is loaded by Gates 1/2/3's pure checks; Gate 4's compiled fixture uses its own disposable synthetic DLL, never the frozen model's), controls, process, gate name, commit | pattern of `spde-slope-gauge-nofit-contract.R:1408-1470` |
| `child-receipt.rds` | the isolated child's own typed result | `materialize-paper1-spde-slope-gauge-nofit-gate.R:173-174` |
| `no-fit-result.rds` | present only when the child produced a validated result | `spde-slope-gauge-nofit-contract.R:779-781` |
| `session-info.rds` | `sessionInfo()` | `materialize-paper1-spde-slope-gauge-nofit-gate.R:179` |
| `time-estimate.md` | pre-run wall-time estimate; **not** a numerical claim | `materialize-paper1-spde-slope-gauge-nofit-gate.R:180-183` |
| `materializer.R` | a copy of the script that wrote this root | `materialize-paper1-spde-slope-gauge-nofit-gate.R:175-178` |
| `file-manifest.csv` | ordered `path,md5`, declared order equal to the locked order | `.spde_slope_gauge_nofit_manifest_ok`, `spde-slope-gauge-nofit-contract.R:106-121` |

**`.parent-stage.rds` is not part of the sealed packet.** It is a disposable
token written into a parent-authenticated *staging* directory before the
child launches (`.spde_slope_gauge_tr_materializer_parent_stage`,
`materialize-paper1-spde-slope-gauge-trust-region.R:248-262`; the same
mechanism at `materialize-paper1-spde-slope-gauge-nofit-gate.R:69-77,158-161`)
and it is deleted before the stage is sealed and renamed into the final root
(`materialize-paper1-spde-slope-gauge-nofit-gate.R:172`). Its purpose is to
let the parent process verify, by rereading a token only it could have
written, that the artifacts appearing in the stage really came from a child
it launched -- not from an unrelated process that happened to write into the
same directory. A runner built from this specification must reproduce that
lifecycle exactly: write the token, launch the child, reread and compare the
token before treating anything the child wrote as trustworthy, then delete
the token before the final atomic rename.

## D. The four no-fit gates, made executable

Gate numbers below match parent design Section 5's list exactly. Section 7's
amendments are folded into the gate they modify and marked accordingly.

### D.1 Gate 1 -- predecessor replay and runtime shape re-assertion

**Precondition.** Section B.2's byte verification has already returned valid;
the historical validator (B.3) is bound. No TMB object exists yet.

**Procedure (byte replay).** As specified in full in Section B.2.

**Procedure (runtime shape re-assertion -- audit F4 / parent design 7.1 /
task item D1).** `src/gllvmTMB.cpp:365-366` declares `d_spde_slope` and
`n_lhs_cols_spde_lat` as `DATA_INTEGER` inputs, and the only validation the
engine itself performs is the range check at `src/gllvmTMB.cpp:1811-1812`
(`n_lhs_cols_spde_lat` must be 1 or 2). The engine therefore proves only that
it **supports** those values; it cannot establish what the frozen Paper 1
model actually used. This gate must re-assert the frozen model's shape from
the sealed `v2-materialized-state.rds` at runtime, not assume it. Read-only
inspection of that sealed state (reported to this document; independently
re-confirmed here only at the byte level via the B.1 MD5, not by opening the
RDS) establishes the following, and the gate must assert every one of these
exactly, each with its own typed failure if it does not hold:

- `length(state$theta) == 22L` and `state$convergence == 0L`;
- `state$random` is exactly `c("s_B", "g_spde_slope")`, and **neither** name
  appears anywhere in `state$parameter_order`. This is the executable form of
  the no-Jacobian argument's first condition (audit Section 4 condition 1,
  parent design Section 2): the chart acts on fixed parameters only, so
  `f(T(phi))` is the identical marginal-Laplace number, not an approximation
  of it, precisely because the coordinates the chart touches are never
  integrated over;
- `state$data$n_lhs_cols_spde_lat == 2L` and `state$data$d_spde_slope == 1L`;
- `state$parameter_order` is exactly `rao_raw_order()`
  (`range-amplitude-orthogonal-contract.R:16-23`): `b_fix[1]`..`b_fix[12]`,
  `theta_diag_B[13]`..`[15]`, `log_kappa_spde[16]`,
  `theta_rr_spde_slope[17]`..`[22]`, in that order;
- the state's own `parameter_order` further agrees, name for name, with the
  legacy predecessor-contract's `spde_slope_gauge_raw_order()`
  (`spde-slope-gauge-nofit-contract.R:75,83,87`), which parent design Section
  2 asserts is the same raw order under a different contract file. This
  cross-file identity is a live, checkable assertion, not an assumption.

**Tolerance.** All checks in this gate are exact-identity checks (byte MD5
equality, `identical()` on names/order/integers, or an exact-zero
`convergence` code). No numeric tolerance applies to Gate 1.

**Status tokens on failure.**

- `RAO_NOFIT_PREDECESSOR_REPLAY_HOLD` -- any B.2 byte/receipt/manifest/claim
  check fails.
- `RAO_NOFIT_SHAPE_ASSERTION_HOLD` -- the byte replay above succeeds but any
  one of the shape assertions in this subsection fails (wrong length, wrong
  random set, a random name leaking into `parameter_order`, wrong
  `n_lhs_cols_spde_lat`/`d_spde_slope`, wrong `parameter_order`, or a
  cross-file order mismatch).

**Evidence retained.** The full predecessor verdict object (root, commit,
receipt, state, state MD5), and a separate `shape_assertion` record naming
every field checked, its expected value, its observed value, and a pass/fail
flag per field -- even on success, so the terminal ledger shows what was
actually checked rather than only that "it passed."

### D.2 Gate 2 -- map/objective/gradient numeric identity, per-coordinate
gradient ledger, curvature diagnostic, and conditioning witness

**Precondition.** Gate 1 passed (`RAO_NOFIT_VALID`-eligible so far); the
frozen `theta0` (V3 `state$theta`) and `phi0 = rao_phi_from_theta(theta0)`
are available in pure R, with no compiled object required for the identity
sub-checks below.

**Procedure -- three-part identity triad (parent design Section 5 item 2,
first three clauses).**

1. `T(phi0)` (via `rao_theta_from_phi`) matches raw `theta0` to
   `64 * .Machine$double.eps`.
2. The mapped objective `F(phi0)` matches the V3 `state$objective` to
   `1e-10`.
3. The raw gradient recovered from replay matches the locked V3
   `state$gradient` to `1e-6`.

Both the exact comparator applied at each of these three checks (a scaled
absolute bound on the maximum coordinate difference, versus `rao_relative_error`
applied to the whole 22-vector) and whether check 3 is exposed to the same
masking failure mode as the transformed-gradient ledger below (Section D.2's
next clause) are **not settled by the parent design's wording** and are
flagged for the independent review in Section G rather than resolved here.
This document takes no position on extending the per-coordinate fix beyond
the one clause the audit named.

**Procedure -- per-coordinate transformed-gradient ledger (audit F3 / parent
design 7.4 / task item D3).** Parent design Section 5 item 2's fourth clause
requires the analytic transformed gradient
`rao_full_chain_gradient(phi0, raw_gradient)` to match a 22-coordinate
central-difference ledger of `F(phi) = f(T(phi))`, using step
`eps^(1/3) * max(1, abs(phi0_j))` per coordinate, "to `1e-5`". The supplied
metric `rao_relative_error` (`range-amplitude-orthogonal-contract.R:118-124`)
computes `max(abs(x - y)) / max(1, abs(x), abs(y))` -- a single ratio over the
whole vector. The audit demonstrated this both masks a wrong coordinate
behind a large one, and silently becomes an absolute tolerance whenever every
component is below 1.

That second failure mode is not hypothetical here. The gradient scale that
actually applies is the **MSPDE V3 predecessor's own** gradient (not the
consumed `G3_P1_S3_C360_R3_V3` root's `0.002431251466981631`, which parent
design Section 7.4's current text cites -- that number belongs to a
different, already-terminal root and is the wrong scale for this gate; this
is flagged for correction in that section, out of scope for this document to
edit). Reported directly from a read-only inspection of the sealed
`v2-materialized-state.rds` (2026-08-15), independently re-confirmed at the
file-byte level only (B.1's MD5), the raw gradient magnitudes at the frozen
point are:

- `max|g| = 2.8237e-4`, `min|g| = 1.5687e-6` (a spread of about 180x);
- four of the 22 raw coordinates already have `|g| < 1e-5`;
- at the four chart-relevant raw/transformed positions, `|g|` is:
  `8.857e-5` (raw 16, `log_kappa_spde` / chart `u`),
  `2.824e-4` (raw 20 / chart `v`), `2.815e-4` (raw 21), `1.603e-4` (raw 22).

Under `rao_relative_error`'s global-max denominator, every one of these
components is compared against an **absolute** `1e-5` budget once any
coordinate elsewhere in the vector exceeds magnitude 1 (which raw `b_fix`
coordinates plausibly do) or once every component is below 1 (which this
22-vector's tail already is). On the chart's own log-range coordinate,
`|g_16| = 8.857e-5`, an absolute `1e-5` budget is about `1e-5 / 8.857e-5 ≈
11.3%` of the quantity being tested -- large enough that a materially wrong
transformed gradient on that coordinate would pass. On the four coordinates
already below `1e-5`, a `100%` error is undetectable in principle by an
absolute test at that level.

This gate therefore requires the companion function
`rao_coordinatewise_relative_error` (named in parent design 7.4) applied
**per coordinate**, not pooled. That function landed in
`range-amplitude-orthogonal-contract.R:130-136` during the drafting of this
document, as

```
rao_coordinatewise_relative_error(x, y) = max(abs(x - y) / pmax(1, abs(x), abs(y)))
```

Two consequences follow that this gate's specification must account for
precisely, and that the review in Section G should confirm.

**It returns a scalar, not a vector.** The outer `max()` collapses the
per-coordinate ratios to the single worst one. The evidence-retention
requirement below (the full 22-length `component_j` vector, not only its
maximum) therefore cannot be satisfied by calling this function directly; a
gate built from this specification must compute the unreduced vector itself
-- `abs(analytic - fd) / pmax(1, abs(analytic), abs(fd))` without the outer
`max()` -- retain that full vector, and use `rao_coordinatewise_relative_error`
(or an equivalent `max()` of the same vector) only as the pass/fail scalar.

**The floor is still `1`, so the absolute-tolerance failure mode is not
resolved by this function alone.** `pmax(1, abs(x), abs(y))` pins the
denominator to `1` for every coordinate whose magnitude is below `1` -- which
is every coordinate of this gradient, whose measured maximum is `2.8237e-4`
(Section D.2 above). Verified directly (pure arithmetic, evaluated in this
document's drafting, not a model computation): with `x = c(8.857e-5,
2.824e-4, 2.815e-4, 1.603e-4)` and `y` equal to `x` except for an `11.3%`
error injected on the first coordinate only, `rao_coordinatewise_relative_error(x,
y)` returns `1.0008e-5` -- at the gate boundary, for an error the audit's own
worked example (Section D.2 above, `1e-5 / 8.857e-5 ≈ 11.3%`) called
unacceptable. The masking failure mode the audit named first (a wrong
coordinate hiding behind a large one) **is** fixed by this function, because
each coordinate is now judged on its own ratio rather than a pooled one. The
second failure mode the audit named -- "when every component is below 1 the
denominator pins to 1 and the metric degenerates to an absolute tolerance" --
is **not** fixed, because it pins per-coordinate rather than globally, and
every coordinate here is below 1.

A gate built from this specification must not treat the existence of
`rao_coordinatewise_relative_error` as having closed this finding.

**Resolution (landed after this section was first drafted).** The open question
above has been settled, and not in favour of lowering the floor. Two facts
decide it.

First, the floor cannot simply be lowered to a relative test, because a strictly
relative `1e-5` gate is **unreachable at this point for every coordinate**. The
objective at the frozen state is `|f| = 2549.04`, so the best attainable
central-difference accuracy is of order `(eps*|f|)^(2/3) = 6.84e-9` absolute.
Against `max|g| = 2.8237e-4` that is `2.42e-5` relative, and against
`min|g| = 1.5687e-6` it is `4.36e-3`. **All 22 of 22 coordinates fail a true
`1e-5` relative gate**, the largest included.

Second, the audit's own worked demonstration is stronger than the `11.3%`
boundary case computed above: zeroing `g_8` outright -- a **100% error** on one
of the four coordinates already below `1e-5` -- returns `5.53e-6` from
`rao_coordinatewise_relative_error` and **passes**.

The gate therefore uses a **mixed absolute/relative criterion**, not a floored
relative one:

```
abs(x_j - y_j) <= atol + rtol * abs(y_j)     for every j
```

with `y` the finite-difference ledger and `x` the analytic transformed gradient,
via `rao_coordinatewise_discrepancy(x, y, atol, rtol)`
(`range-amplitude-orthogonal-contract.R`), which returns the worst ratio and
passes when that ratio is `<= 1`. Both tolerances are **required arguments with
no default** -- every default tried in this lane has been silently wrong. The
same zeroed-`g_8` probe returns `5242.67` under this criterion and fails, as it
must.

`atol` must be justified against the **measured** central-difference noise floor
of the objective under test -- measured by differencing at several step sizes
and observing where the estimate stops improving -- not against `1` and not
against convenience. The two numbers remain **to be fixed by the separately
reviewed execution design**, which must perform that measurement first. The
`6.84e-9` figure above is an order-of-magnitude estimate from `|f|`, offered to
scope the measurement, not as the value to use.

The scalar-versus-vector point above still stands unchanged: the gate must
compute and retain the unreduced 22-length ratio vector, using the function only
for the pass/fail scalar.

**Procedure -- curvature diagnostic, reported not gated (audit F2 / parent
design 7.3 / task item D2).** At the frozen point, using the same
finite-difference machinery as the transformed-gradient ledger above (central
differences of the transformed exact gradient; no optimizer, no trust-region
grid -- the identical technique used for the Hessian construction in the
gauge trust-region execution design,
`2026-08-15-paper1-spde-slope-gauge-trust-region-execution-design.md:88-126`),
compute the 2x2 block of the transformed curvature restricted to the chart's
`(u, v)` pair. Because `rao_phi_order()` places `u` at phi-position 16 and
`v` at phi-position 20 (`range-amplitude-orthogonal-contract.R:25-34`), this
is rows/columns `{16, 20}` of the transformed Hessian:

```
A = H[16, 16],  C = H[20, 20],  B = H[16, 20]  (= H[20, 16] by symmetry)
```

Compute and write into the terminal ledger: `A`, `C`, and the true
diagonalising angle `theta = 0.5 * atan2(2*B, A - C)` in degrees. This is a
**reported diagnostic and explicitly not a pass/fail criterion**: the audit
showed that the chart's orthogonal linear factor `R` is an orthogonal
similarity on this curvature block, so it preserves eigenvalues (and hence
condition number) regardless of `A`, `C`; it decorrelates `(u, v)` if and only
if `A = C`, which is a `45°` diagonalising angle, and nothing in the design or
the frozen state establishes that equality. No threshold on `|A - C|` or on
`theta - 45°` has evidence behind it, and inventing one now would close the
lane on a criterion manufactured after the design was written (maintainer
decision, 2026-08-15, recorded at parent design 7.3). This diagnostic's only
purpose is to inform the later, separately reviewed execution design about
which anisotropy, if any, a numerical procedure could exploit -- an
affine-invariant procedure gains nothing from `R` regardless of what `A` and
`C` turn out to be.

**Procedure -- conditioning witness (audit F5 / parent design 7.5).** Record
`lambda_1` (the frozen GBIF-slope reference loading, raw position 20) at the
frozen point. Reported value: `lambda_1 = 0.06615484` (from the raw block
`0.06615484, -0.005920384, -0.07900113`, reported directly from the same
read-only inspection as above). Because `det J = -lambda_1^3` exactly (audit
Section 5; `range-amplitude-orthogonal-contract.R:50-52,62-64` is the domain
guard `lambda_1 > 0`), the chart degenerates as `lambda_1 -> 0`; recording its
value at the frozen point lets a later reader see how far this attempt sits
from that degeneracy. Index 1 as the amplitude reference is recorded as
**predeclared** -- fixed before evaluating this estimator, not selected from
data (parent design 7.5) -- and this witness is retained as evidence, not
gated: no threshold on `lambda_1` is specified here, for the same reason as
the curvature diagnostic.

**Procedure -- second conditioning witness: the cancellation in `u` (audit F7 /
parent design 7.4b).** Record `q + eta` at the frozen point alongside
`lambda_1`. Reported value: `q = 2.687653`, `eta = log(lambda_1) = -2.715757`,
so `q + eta = -0.02810406`. Because `u = (q + eta)/sqrt(2)`, the chart's own
primary coordinate is formed by subtracting near-equal magnitudes, destroying
`log10(2.7/0.028) = 1.99` -- nearly **two decimal digits** -- and the loss grows
without bound as kappa approaches the reciprocal of the amplitude. This is a
property of the transform in floating point, not of the model. It **compounds
the gradient ledger**: the coordinate least able to tolerate noise is the one
the chart manufactures by cancellation. Retained as evidence, not gated.

**Procedure -- read `theta0` from the packet, never from a literal (audit
Section 9a / parent design 7.4a).** The pure contract's test fixture carries
`theta[16] = 2.687653160`, but the sealed value is `2.6876531596114015`. The
difference is `3.886e-10`, which is **27,345 times** the `64 * eps` round-trip
tolerance in the table below. Positions 20-22 are bit-identical; position 16 is
not. A gate that seeds `theta0` from that literal will fail its own round-trip
check for a reason that has nothing to do with the chart. **`theta0` must be
read from `v2-materialized-state.rds` in the sealed root**, and any transcribed
constant appearing in a runner is itself a defect. This is the concrete reason
the byte-verification in Section B.2 is a precondition of Gate 2 rather than a
formality.

**Tolerances (summary table).**

| check | quantity | tolerance | gated? |
| --- | --- | --- | --- |
| chart round-trip | `max\|T(phi0) - theta0\|` | `64 * .Machine$double.eps` (exact form TBD, Section G) | yes |
| objective identity | `rao_relative_error(F(phi0), V3 objective)` | `1e-10` | yes |
| raw gradient identity | vector comparison to locked `state$gradient` | `1e-6` (metric TBD, Section G) | yes |
| transformed gradient ledger | per-coordinate mixed criterion `abs(x_j - y_j) <= atol + rtol*abs(y_j)` via `rao_coordinatewise_discrepancy`; retain the unreduced 22-length ratio vector, not only its max | passes when the worst ratio is `<= 1`. **`atol` and `rtol` are required and are NOT fixed here** -- the execution design must set them from the measured central-difference noise floor (order `6.84e-9` absolute at `abs(f) = 2549.04`). A strictly relative `1e-5` is unreachable for all 22 coordinates | yes, per coordinate |
| curvature `A`, `C`, angle | reported only | none | **no -- diagnostic** |
| `lambda_1` at frozen point | reported only | none | **no -- witness** |

**Status tokens on failure.**

- `RAO_NOFIT_TRANSFORM_IDENTITY_HOLD` -- any of the round-trip, objective, or
  raw-gradient identity checks fails.
- `RAO_NOFIT_GRADIENT_LEDGER_HOLD` -- any one of the 22 per-coordinate
  transformed-gradient checks fails. The failing coordinate indices and their
  `component_j` values are retained, not only the worst one.

Neither the curvature diagnostic nor the conditioning witness can produce a
gate failure; a missing or non-finite value for either is instead an
infrastructure finding (`RAO_NOFIT_INFRASTRUCTURE_HOLD`, Section D.4/8),
because the diagnostic's *absence* is a defect in the gate's own execution,
not evidence about the model.

**Evidence retained.** `phi0`, `T(phi0)`, `F(phi0)`, the raw and transformed
gradients, the full 22-length `component_j` vector (not just its max), the
full central-difference ledger (all 22 evaluations, both signed steps, in the
fixed order already established for this kind of FD sweep --
`2026-08-15-paper1-spde-slope-gauge-trust-region-execution-design.md:98-99`),
`A`, `C`, `theta` (degrees), and `lambda_1`.

### D.3 Gate 3 -- full random-effect sign-orbit check

**Precondition.** Gate 2 passed. This gate requires a compiled callback
object (the frozen model's `obj$env$spHess` and `obj$report`), so it is the
first gate in this sequence that touches a compiled artifact; per the audit's
own scoping (Section 10, "Out of scope"), it is deferred, unchanged, to the
live phase and remains **untested and a prerequisite, not an assumption**.

**Status upgrade -- this gate is load-bearing for the no-Jacobian argument, and
should be sequenced first among the live gates.** The audit's revised Section 4
(parent design 7.6) shows the sign-orbit property is not one gate among four.
The chart is a bijection onto `R x {lambda_1 > 0}`, **not onto R^4**, so
`T^{-1}(argmin f)` is undefined unless the raw optimum lies in that half-space.
What makes the restriction without loss of generality is exactly this gate.
Until it passes on the immutable V3 state, the chart is established as an exact
re-expression of the objective's **values** but **not of its optimum** -- and
every downstream numerical claim concerns the optimum. Ordering it after Gates
1 and 2 is defensible only because those are cheaper; nothing that follows this
gate's failure would retain meaning, so an implementation that runs it late must
not report Gates 1, 2 or 4 as partial progress toward admission.

**Procedure.** As already specified for the sibling gauge chart, whose
random-effect declaration, LHS-column count, and slope rank are the same
frozen model (parent design Section 2: "The TMB objective, random-effect
declaration, likelihood, data, mesh, map, seed, bounds, source split, and raw
parameter order remain unchanged"). The signed conditional Hessian at the
signed full state is compared against `S^T Q S`, where
`Q = obj$env$spHess(full, random = TRUE)` and `S` flips only the second
`g_spde_slope` LHS field and its corresponding GBIF fixed-loading column (raw
positions 20--22)
(`2026-08-15-paper1-spde-slope-gauge-trust-region-execution-design.md:77-86`).
The same sign operation is separately applied to `obj$report(full)$eta` and to
the marginal objective at the two signed fixed vectors. All three comparisons
must agree, retaining the full/random axis names, sign indices, all three
errors, and the field dimensions `n_lhs_cols_spde_lat = 2`,
`d_spde_slope = 1` -- inferred from the actual full random-effect packing,
never from a single-field quadratic or from `cov.fixed` alone.

This gate proves that this chart's predeclared positive-`lambda_1`
representative is an equivalence class under the model's sign symmetry, not a
changed estimand (parent design Section 3).

**Tolerance.** No numeric tolerance for this specific relation is stated
anywhere in the parent design or the audit; parent design Section 5 item 3
only requires that the three quantities "agree." The exact numeric agreement
bound is **to be fixed by the separately reviewed execution design**, mirroring
the trust-region lane's own compiled-fixture precedent, which established the
mechanism (`Q_signed = S^T Q S`) but is itself a different chart's fixture and
supplies no borrowable numeric bound for this estimator (Section F).

**Status token on failure.** `RAO_NOFIT_SIGN_ORBIT_HOLD`.

**Evidence retained.** The signed and unsigned conditional Hessians (or a
retained summary sufficient to reconstruct their comparison), the sign
operator's index set, the `eta` comparison, both marginal-objective values,
and the field-dimension assertions with their observed values.

### D.4 Gate 4 -- pure round-trip, determinant, order, domain,
covariance-preservation, and compiled random-effects fixture

**Precondition.** Gates 1--3 passed, or this gate's pure sub-checks run
independently as a development-time regression suite (they require no
compiled object except for the fixture sub-check below).

**Procedure -- pure checks (no optimizer permitted).**

- **Round-trip:** `rao_theta_from_phi(rao_phi_from_theta(theta))` recovers
  `theta` exactly (to the same `64 * .Machine$double.eps` bound as Gate 2),
  and the reverse composition recovers `phi`, across the frozen point and at
  least the two predeclared interior points parent design Section 4 already
  requires for the composed-objective harness.
- **Determinant:** the full 22x22 Jacobian's determinant equals
  `-lambda_1^3` exactly (audit Section 5), confirming the identity-block
  contribution is `1` and the sign decomposes as `det R = -1` times
  `det E = lambda_1^3`.
- **Order:** `rao_raw_order()` and `rao_phi_order()`
  (`range-amplitude-orthogonal-contract.R:16-34`) are asserted as fixed
  22-name vectors in every function that consumes or produces them; no
  function may silently reorder.
- **Domain:** inputs with non-finite coordinates or `lambda_1 <= 0` fail the
  typed domain gate already in the pure contract
  (`range-amplitude-orthogonal-contract.R:50-52,62-64`); a later sign flip is
  never used to repair them (parent design Section 3). Adversarial coverage
  of amplitude overflow, amplitude underflow, and near-zero-`lambda_1`
  boundaries is added at this gate to establish which boundaries fail loudly
  versus which return a silently wrong answer -- per the audit (Section 8),
  no new numerical threshold is invented from this coverage; it only
  classifies failure behaviour.
- **Covariance-preservation:** this sub-check is **not yet defined** by any
  existing contract function (no `rao_*` covariance helper exists as of this
  writing). It must establish that a covariance computed in `phi`-coordinates
  and mapped to raw coordinates via `rao_full_jacobian` (or its transpose, as
  the correct delta-method direction requires) is consistent with a
  covariance computed directly in raw coordinates, for a synthetic positive-
  definite test matrix -- not the frozen model's actual covariance, which no
  no-fit gate may compute. The exact tolerance for this sub-check is **to be
  fixed by the separately reviewed execution design**.

**Procedure -- compiled random-effects fixture.** A new, independently
compiled fixture for this estimator (its own disposable DLL, never the frozen
model's), establishing that a synthetic 22-coordinate two-column random SPDE
slope block with `n_lhs_cols_spde_lat = 2`, `d_spde_slope = 1` behaves under
this chart's map/gradient/Jacobian exactly as the pure contract predicts. This
may follow the same construction technique as the sibling gauge chart's
compiled fixture (`docs/dev-log/recovery-checkpoints/2026-08-15-codex-gauge-trust-region-checkpoint.md:75-80`),
which is a documented **pattern**, not a numeric result -- this gate must not
import that fixture's object, DLL, or any retained numeric trace (Section F).

**Tolerance.** Round-trip and determinant checks use exact or near-machine-
epsilon bounds as stated above; the domain and order checks are boolean; the
covariance-preservation and compiled-fixture tolerances are open (Section G).

**Status tokens on failure.**

- `RAO_NOFIT_ROUNDTRIP_HOLD` -- any pure round-trip, determinant, order, or
  domain check fails.
- `RAO_NOFIT_FIXTURE_HOLD` -- the compiled random-effects fixture fails to
  build, fails to release cleanly, or its live checks disagree with the pure
  contract's predictions.

**Evidence retained.** Every pure-check input/output pair (including the
adversarial boundary cases), the exact determinant value and its comparison
to `-lambda_1^3`, and the fixture's compiled-object identity, callback audit,
and release/garbage-collection confirmation (mirroring the trust-region
worker's own object-lifecycle discipline,
`2026-08-15-paper1-spde-slope-gauge-trust-region-execution-design.md:56-62`).

## E. Known limitation: one kappa, two loading columns, and which one this
chart treats

The engine declares a single `log_kappa_spde` (`src/gllvmTMB.cpp:748`), a
scalar shared across the entire SPDE latent-slope block. That block carries
**two** LHS columns, with `len_per_col = p * rank - rank * (rank - 1) / 2`
(`src/gllvmTMB.cpp:1830`; `p = 3` traits, `rank = 1`, so `len_per_col = 3`)
and the columns laid out consecutively, column 0 then column 1
(`src/gllvmTMB.cpp:1835-1837`, `theta_k <- theta_rr_spde_slope.segment(kcol *
len_per_col, len_per_col)`). In the frozen 22-vector this gives:

| raw positions | contents | this chart |
| --- | --- | --- |
| 16 | `log_kappa_spde` -- one kappa, shared by both columns | charted (`u`, `v`) |
| 17--19 | loading column 0 (intercept) | **untreated** -- stays in the Jacobian's identity block |
| 20--22 | loading column 1 (GBIF slope); `Sigma = lambda * lambda^T` | charted (amplitude/direction split `eta, a, b`) |

Both columns' spatial fields are governed by the same `kappa`
(`src/gllvmTMB.cpp:1822-1827`, one `Q_lat` built from one `kappa_l` shared by
the loop over `kcol` at `src/gllvmTMB.cpp:1846-1847`), so the
kappa-versus-amplitude confounding this chart is built to separate exists
identically for **both** amplitudes. This chart separates `kappa` from the
GBIF slope amplitude only; the intercept amplitude remains exactly as
confounded with the same `kappa` as it was in raw coordinates, and -- because
the orthogonal factor `R` mixes `q` into both `u` and `v` -- it now trades off
against *both* new coordinates rather than the one it traded off against
before.

**This disparity is not symmetric, and the untreated amplitude is the
numerically dominant one.** Reported directly from the same read-only
inspection cited in Section D.2 (2026-08-15), the two raw loading blocks at
the frozen point are:

- raw 17--19 (intercept, **untreated**): `21.617935, -21.081067, 14.560273`,
  Euclidean norm `33.52235`;
- raw 20--22 (GBIF slope, **charted**): `0.06615484, -0.005920384,
  -0.07900113`, Euclidean norm `0.1032119`;
- ratio `‖intercept‖ / ‖slope‖ ≈ 324.79`.

(Both norms and the ratio were recomputed independently in this document from
the reported component values as a pure arithmetic check, not as a claim of
independent access to the sealed state: `sqrt(21.617935^2 + 21.081067^2 +
14.560273^2) = 33.5223`; `sqrt(0.06615484^2 + 0.005920384^2 + 0.07900113^2) =
0.103211`; `33.5223 / 0.103211 = 324.8`, consistent with the reported figures
to the precision shown.)

The chart therefore treats the numerically **minor** of the two
kappa-amplitude confoundings, by a factor of about 325, at this frozen point.

This is recorded as a **scoped limitation of the estimator, not a defect to
fix in this lane** (maintainer decision, 2026-08-15, parent design 7.2).
Widening the chart to six coordinates so that both loading columns are
gauge-transformed would be a materially different estimator, requiring its
own identity, contract, and independent review; adapting this design on
speculation is exactly the kind of scope drift this programme is disciplined
against. Any later execution design built on this gate **may not assume the
range--amplitude ridge has been removed** from the frozen model -- it has been
removed for one of two amplitudes, and the untreated one is the larger of the
two at the frozen point.

## F. Prohibition: consumed roots remain immutable

This gate is a **new** no-fit specification for a **distinct** estimator
identity. It is not a V3 (or later) replay of the gauge no-fit adapter, and
it must not be built by copying values, thresholds, or trial outcomes from
any of the following consumed lanes. Each is named here with its concrete
identity so a later reviewer can check a runner against this list mechanically:

| lane | identity / root | terminal | citation |
| --- | --- | --- | --- |
| G3, Paper 1 | `results/G3_P1_S3_C360_R3_V3` | `G3_RAW_INELIGIBLE` | `2026-08-14-g3-marginal-curvature-terminal-adjudication.md:33-35` |
| G3, Paper 2 | `results/G3_P2_S6_C360_R3_V5` | `G3_CURVATURE_INVALID` | `2026-08-14-g3-marginal-curvature-terminal-adjudication.md:15-17` |
| exact-gradient BFGS | continuation design | `INVALID_PROVENANCE`, `BFGS_INFRASTRUCTURE_HOLD` | `2026-08-14-bfgs-exact-gradient-continuation-design.md:86,94,128` |
| marginal-scale BFGS | named only in the parent design | consumed, per parent design | `2026-08-15-paper1-range-amplitude-orthogonal-design.md:10` (no separate identity file found in this worktree; see Section G) |
| gauge no-fit V1 | `PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1` | `SPDE_SLOPE_GAUGE_NOFIT_VALID` / `_REPLAY_HOLD` / `_INFRASTRUCTURE_HOLD` | `materialize-paper1-spde-slope-gauge-nofit-gate.R:203,238` |
| gauge no-fit V2 | `PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2` | (superseding V1; forensic-only per its own predecessor projection) | `materialize-paper1-spde-slope-gauge-nofit-v2-gate.R:525,660`; `spde-slope-gauge-nofit-contract.R:1641-1650` |
| gauge trust-region V1 | `PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1` | post-claim infrastructure/provenance failure; superseded attempt preserved at `/private/tmp/PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_SUPERSEDED_ace72ec1` | `docs/dev-log/recovery-checkpoints/2026-08-15-codex-gauge-trust-region-checkpoint.md:104-129` |

No repair, resume, reseal, backfill, control-selection, threshold-borrowing,
or trial-ranking may cross from any row above into this gate or into any
execution design built on it. Where this gate reuses a *technique* from one
of these lanes (the sign-orbit relation's mechanism in D.3, the compiled
fixture's construction pattern in D.4, the finite-difference Hessian
mechanism in D.2), it reuses the method, never a retained numeric trace,
callback count, or object from that lane's own attempt.

## G. What must be independently reviewed before any runner is written

1. Confirm or replace the proposed gate identity and packet shape
   (Section C.1, C.2) -- in particular whether the marker-plus-ledger shape
   is actually wanted for a single estimator's no-fit gate, or whether the
   simpler V1 single-attempt shape is the better precedent here.
2. Resolve the two open metric-form questions in Gate 2's identity triad: the
   exact comparator for `T(phi0)` vs `theta0` (scaled-absolute vs
   `rao_relative_error`), and whether the raw-gradient-vs-locked-vector check
   is exposed to the same masking failure mode the audit found in the
   transformed-gradient ledger -- the audit named only the latter, and this
   document does not extend the fix to the former without that review.
3. **RESOLVED during drafting; confirm the resolution rather than the original
   question.** `rao_coordinatewise_relative_error` fixes only the masking
   failure mode and retains the `floor = 1` denominator, which is absolute at
   this gradient's measured scale -- a **100% error** on `g_8` returns
   `5.53e-6` and passes. Lowering the floor is not the fix either: a strictly
   relative `1e-5` gate is unreachable for **all 22 coordinates**, since the
   central-difference noise floor is order `6.84e-9` absolute against
   `max|g| = 2.8237e-4`. The gate now specifies the mixed criterion via
   `rao_coordinatewise_discrepancy(x, y, atol, rtol)`, both tolerances required
   and unset here. **What needs review is (a) that the mixed form is the right
   instrument, and (b) the procedure by which the execution design will measure
   `atol` from the objective's actual noise floor** -- not a choice of number.
   Also confirm that a gate implementation retains the full per-coordinate
   vector rather than only the reduced scalar (Section D.2).
4. Fix the numeric agreement bound for Gate 3's sign-orbit triad (no bound is
   stated anywhere upstream) and the tolerance for Gate 4's
   covariance-preservation sub-check (no such check exists yet in the pure
   contract).
5. Review the D.2 curvature-diagnostic and conditioning-witness computations
   for correctness independently of this document -- both are new
   finite-difference constructions over a 2x2 submatrix and a single raw
   coordinate respectively, and both must be verified never to gate admission,
   only to report.
6. Locate (or confirm the absence of) a dedicated identity/root for the
   "marginal-scale BFGS" lane named in parent design Section 1; this document
   found no separate file for it in this worktree beyond that one sentence.
7. Verify, independently of this document's authors, that the compiled
   fixture proposed in Gate 4 cannot be satisfied by reusing any part of the
   sibling gauge chart's compiled fixture object, DLL, or retained trace
   (Section F) -- only the construction *technique* may be shared.
8. A Gauss/Noether mathematical review and a Fisher/Rose systems review, per
   parent design Section 6, of this specification as a whole, before any of
   it is implemented as a runner.
9. A time estimate immediately before any first execution of a runner built
   from this specification, per the established discipline (`>30 min`
   requires a pre-run test and explicit approval before the full run; `<=30
   min` still requires the estimate to be stated).

Nothing in this document is evidence that the range--amplitude orthogonal
chart works, recovers anything, or is numerically admissible. It specifies
what must be true, byte for byte and coordinate for coordinate, before anyone
is permitted to find out.
