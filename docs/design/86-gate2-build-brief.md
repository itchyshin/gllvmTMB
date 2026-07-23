# Design 86 — Gate 2 build brief: information-rich correctness anchor

**Status:** DRAFT — requires maintainer approval of the Gate-2 anchor parameter
file before implementation, input generation, smoke testing, or Totoro use.

## Purpose and fence

Gate 2 asks whether the private EVA implementation recovers the planted primary
coefficient and ordinary B-tier covariance on one deliberately information-rich,
complete Bernoulli-logit GLLVM cell. It is not sparse admission, a
Gauss–Hermite reference comparison, a public feature, or a likelihood contest.

The only permitted new implementation is a pair of unexported runners under
dev/: one for the standalone EVA prototype and one for the unchanged live
Laplace fit. The shipped source, public R surfaces, package metadata, user
documentation, and all Gate-3/Gate-4 files remain untouched.

## Frozen-input contract

After maintainer sign-off, the runner reads the Gate-2 JSON verbatim. It must
not restate or alter its DGP, 500 seeds, interval, restart, collapse, or
denominator choices. It first writes an immutable input manifest covering, for
every attempt, the ordered complete cell map, truth, response, and complete
input-object SHA-256 values. Both arms consume the same manifest and repeat
its hash in their independent receipts.

The EVA and Laplace output roots, runners, checksums, and denominator IDs are
Gate-2-only and must be non-nested and distinct from every future Gate-4 path.

The information check is the pooled type-8 tenth percentile of all planted
unit-level information values. Each loading row has norm one and the displayed
loading matrix has cross-product 6 times the two-dimensional identity. At zero
latent score, the information is 1.4100222732. On the 90-percent normal-ball
event, the information lower bound is 0.371103565; the frozen 0.35 threshold is
therefore conservative population support, not a licence to remove a low
information unit or replicate.

The JSON fixes all four EVA start formulas, four live-Laplace restarts, and
their health rules. EVA beta intervals use the fully specified joint negative
Hessian, Schur complement over variational coordinates, symmetric positive
definite solve, and pseudo-inverse rule. A failed fit has coverage zero and
counts as collapsed; it is never silently replaced or removed.

## Required checks

Before Totoro, run a one-seed local smoke. It must produce finite labelled
outputs, a valid input manifest, both arm receipts, a Schur-complement beta
Wald interval, restart histories, realised information summaries, and no
objective-ranking field. A failed or ambiguous smoke stops the arc.

After the pre-authorized bounded Totoro run, score all 500 attempts. Gate 2
passes only when the JSON thresholds for beta bias/coverage, every
Sigma_B-diagonal bias, information, and collapse are met. Failed fits stay in
the named denominator. Laplace rows are reported beside EVA recovery rows but
have no superiority threshold and no objective comparison.

## Closeout

Run fresh math, numerical, and scope reviews after candidate results exist.
Write the check-log and after-task report, explicitly state the Gate-3/Gate-4
fence, and stop for the maintainer.
