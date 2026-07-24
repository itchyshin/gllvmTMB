# Design 95 plan-versus-actual reconciliation

| Axis | Planned | Actual | Classification |
|---|---|---|---|
| Scope | Private q=2 JJ prototype only | `dev/design95-free-jj-va/` plus design records only | aligned |
| Evidence | Objective, gradient, lower-bound, identification, one stability probe | All passed; covariance diagnostic was 1.236890 | aligned; diagnostic retained without threshold |
| Routing | Two Terra reviews, one Luna mechanical verification | Two native review agents completed; Luna was unavailable in this runtime, so Ada ran local mechanical checks | adaptive; no model claim substituted for Luna |
| Safety | No package/public paths, no earlier-design alterations | Empty-diff guard passed for package/public paths | aligned |
| Claims | Experimental only | Closeout explicitly withheld recovery, calibration, parity, and integration claims | aligned |
| Handoff | Local checkpoint | Pending commit on isolated branch | aligned |

No material scope drift was found.  The only routing deviation is documented:
the live Codex runtime exposed Terra/Sol but not Luna, so a tiered Luna dispatch
was unavailable.  This did not affect the independent mathematical and scope
reviews.
