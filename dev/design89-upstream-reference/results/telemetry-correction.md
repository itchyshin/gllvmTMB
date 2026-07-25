# Design-89 post-run telemetry correction

The single reference call was executed with runner SHA-256
`b8bcc78b10e041d1504a4d8d387653dff84513f65d41196f42ec6a73acb314ad`.
The generated RDS and JSON are retained unchanged as the raw execution record.

That runner incorrectly evaluated the returned `fit$convergence` field as
`fit$convergence == 0`.  The locked upstream source at
`R/gllvm.TMB.R:3310` defines that field as the *logical* expression
`optrFinal$convergence == 0`; therefore a successful logical value was turned
into `FALSE` by the runner's extra comparison.  The locked wrapper at
`R/gllvm.R:1956-1957` emits a non-convergence warning if that field is false.
The raw result records no warning, so the one executed fit had
`fit$convergence == TRUE`.

No model call has been repeated.  Applying the locked health rule to the raw
telemetry with the corrected convergence interpretation gives
`UPSTREAM_REFERENCE_PASS`: both upstream assertions are true, the log
likelihood and parameters are finite, `max(abs(gradient)) = 0.00168`, and the
predeclared 0.05 gradient bound is met.  This amendment corrects telemetry
interpretation only; it does not establish gllvmTMB parity or authorise any
subsequent design.
