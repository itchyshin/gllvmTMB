# G2k gradient diagnostic decision

## Decision: `NO_REPAIR`

Retain `G2K_CALIBRATION_HOLD`.  No same-objective optimizer repair is
evidence-supported for the dominant 69 attempts that recover all five
known-truth metrics but fail the raw-gradient gate, and no DGP/estimand
redesign is justified by this fixed-DGP diagnostic.

The one existing same-objective polish is successful for every one of its 31
predeclared eligible boundary cases.  It is therefore not a failed repair.
However, its predicate excludes 68 of the 69 recovery-pass/raw-gradient holds
because they have no `near_zero_sd_B` flag; their largest raw component is
`b_fix` (58) or `theta_rr_B` (11).  The evidence cannot justify applying that
boundary remedy to a different parameter geometry, changing tolerances,
changing starts, or rebuilding the objective.

Fifteen additional strict holds have passed the raw gradient and all recovery
metrics but fail the frozen mandatory-polish admission rule.  Changing that
rule would change the recovery criterion, which is out of scope.  It should
not be silently counted as numerical nonstationarity.

## Frozen next protocol (not authorized by this decision)

Before any new fit or campaign, a separately approved **numerical-admission
design** task must:

1. state a complete decision table distinguishing a raw-gradient-passing,
   polish-ineligible fit from a raw-gradient-failing, polish-eligible fit;
2. decide prospectively whether polish is a conditional repair evidence record
   or a universal admission requirement;
3. define, before fitting, a distinct same-objective candidate for the
   `b_fix`/`theta_rr_B` residual-score geometry, or explicitly rule one out;
4. subject that candidate to compiled-unit and adversarial no-fit validation;
5. obtain explicit approval for one local pre-run before any campaign.

No retained G2k classification may be recomputed under such a future rule, and
no future campaign is authorized by this memo.
