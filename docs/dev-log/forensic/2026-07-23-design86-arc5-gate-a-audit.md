# Design 86 Arc 5 — Gate-A numerical diagnosis audit

**Decision:** `PARK`
**Base:** `e0e16079` on `codex/design86-arc2r-20260723`
**Scope:** deterministic, non-Gate-2 diagnostics only

## Result

Arc 5 does not identify one justified numerical mechanism for the two immutable
G2/EVA smoke failures.  Therefore it does not draft a V2 amendment and does
not invoke a Design-86 runner.  The historical and V1 smoke roots remain
byte-for-byte unchanged.

Gauss's numerical review found the predeclared raw-loading scale comparison
**inconclusive**: both final traces were unhealthy (`3.45369310` and
`1.26558302` maximum absolute gradient), and the resulting controlled
objectives (`0.07072063` and `0.01601469`) were not the same target within the
predeclared tolerance.  Rose's independent review sets the operative verdict
to **PARK** because the resulting receipt is not a complete auditable record
of the frozen A0–A3 criteria.  Under the Gate-A specification, either outcome
withholds amendment and run authority.

## Evidence established

- The historical and V1 artifact chains are valid receipt evidence.  In each,
  the input-manifest digest cross-links between the manifest, result, and
  receipt.  The receipt field named `output_manifest_sha256` instead hashes
  that root's result JSON; source line
  `dev/design86-gate2-eva-runner.R:400-403` confirms the field does not refer
  to a separate stored output manifest.
- Static source analysis maps V1's 424 flattened coordinates as `beta[1]`,
  `theta_rr[2:24]`, `a[25:184]`, `log_A_diag[185:344]`, and `A_off[345:424]`.
  The recorded values above 1,000 are raw signed `theta_rr` loading entries,
  not transformed covariance coordinates.
- On the deterministic Gate-1 `bernoulli_q2` objective, two fixed interior
  points had maximum normalized AD/central-finite-difference discrepancies of
  `5.144237e-09` and `5.531004e-09` across step sizes `1e-4`, `1e-5`, and
  `1e-6`.  This is local derivative QA for that controlled objective only.
- The four-stage tracer distinguishes a code from the recomputed gradient:
  its nonstationary linear objective had final gradient `1` despite interim
  `nlminb` code-zero stages.  It does not establish the source of the smoke
  failures.

## Why Gate A did not pass

The controlled scale wrapper used `z_theta = theta_rr / 10`, started each raw
loading at 5, and mapped its AD gradient back by the chain rule.  It reduced
the final gradient but neither raw nor transformed trace passed the frozen
health predicate, and their final objectives differed.  This cannot identify
scaling as the common mechanism or justify a prospective change.

Further, the retained JSON receipt is deliberately a summary, not the full
Gate-A audit record: A0 digest rechecks were not performed by the helper; A1
does not retain the V1 extreme-coordinate ledger; A2 omits each coordinate's
finite-difference values and objective evaluations; and A3 omits all messages
and per-stage gradients.  Those omissions prevent promotion even if A4 had
appeared favorable.

## Boundaries

No conclusion is made about EVA likelihood correctness, identifiability,
global optimality, engine attribution, a numerical remedy, recovery, coverage,
intervals, Laplace, Gate-2 admission, or a public capability.  The controlled
probe used no Design-86 runner, Gate-2 seed, Gate-2 input, DGP, historical
artifact root, prospective artifact root, campaign, Totoro, or DRAC.

## Maintainer options

1. **Park/close (current outcome).** Retain the audit and leave V1 untouched.
2. **Commission a new diagnostic arc.** First require a versioned audit
   protocol that retains full A0–A3 raw evidence and a new, falsifiable
   mechanism; this does not authorize a rerun.
3. **Defer.** Revisit only when independent numerical review supplies a
   different discriminating hypothesis.

None of these options authorizes a V2 amendment or a smoke.  A future live
lane would need a fresh Gate-A `GO`, a signed exact amendment and fixture hash,
and separate Gate-B authority.
