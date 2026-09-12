# Temporal dependent-kernel optimizer diagnostic: result

## Boundary

This is a diagnostic of the retained failed long-occasion qualification cell,
not a replacement fit or a recovery result.  The original nine-cell campaign
and its failed verdict remain unchanged.

## Retained runs

`optimizer-diagnostic-p00-seed-2609373.rds` retained a harness error because
the direct fixture did not carry labelled series and trait vectors into the
independent panel checker.  It is preserved.  The repaired, separate receipt
`optimizer-diagnostic-v2-p00-seed-2609373.rds` completed successfully on the
same fixed design point (`phi = 0`, seed `2609373`, 80 series, 32 occasions).

At the native endpoint, the outer gradient is still `0.00167243199`, exceeding
the unchanged `0.001` qualification criterion.  The independent block
Gaussian likelihood agrees with the native objective to `2.02e-9`; its central
finite-difference gradient has maximum absolute discrepancy `3.87e-6`.

The largest native derivative is
`theta_temporal_rr[6] = -0.0016724320`.  The AR1 coordinate has derivative
`theta_temporal_time[1] = 0.0001320071`.  Thus this fixture does not support
attributing the failed gate to the zero-persistence coordinate.  The native
Hessian remains unavailable because this random-effects model does not
implement it; the retained message records that limitation.

## Implication

The failed gradient is consistent with the specified additive Gaussian
likelihood at this endpoint.  It does not establish why BFGS stopped there or
that coordinate scaling will repair recovery.  Any intervention must be a
separate algebraically equivalent, prespecified contract, tested on new seeds
across all persistence values while retaining the original threshold and this
failed evidence.
