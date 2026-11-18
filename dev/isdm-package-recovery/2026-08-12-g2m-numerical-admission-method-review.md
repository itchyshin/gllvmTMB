# G2m independent numerical-method review

**Reviewer:** Noether/Gauss perspective (read-only)
**Verdict:** HOLD for any Case-C repair; PASS for a prospective
`NO_CANDIDATE`/HOLD rule.

The proposed decision table is valid only if raw-pass/polish-ineligible cases
are `NOT_REQUIRED`, existing one-diagonal-boundary cases retain their named
conditional candidate, and non-boundary `b_fix`/`theta_rr_B` cases remain
`NO_CANDIDATE`.  The 15 G2k raw-pass/all-metric/polish-ineligible records rule
out universal polish admission; the 31/31 accepted boundary cases establish
that the existing candidate works only inside its declared envelope.

The source contains an algebraic covariance-Newton primitive
\(\theta-\widehat{\mathrm{Cov}}g\), but it is invoked only after the
boundary-only eligibility predicate.  It is not an admissible Case-C candidate:
the helper lacks symmetry, PD, conditioning, and dimname-order checks for the
covariance, while rank-one loading coordinates have sign-reflection symmetry.
It may be a future proposal only after a new estimator specification and the
adversarial validation stated in the protocol.

**Evidence checked:** `R/fit-multi.R` lines 6610–6669 (boundary-only invocation
and same-objective evaluation), 7090–7105 (one-boundary eligibility), and
7144–7157 (minimal covariance-Newton input checks); `src/gllvmTMB.cpp` line 33
and `tests/testthat/test-loading-unpack-contract.R` line 128 (rank-one loading
packing/sign reflection); and the G2k certificate sections “Near-boundary
geometry”, “Inadequately targeted polish”, and “Gate interaction retained
separately”.

Required correction adopted in the G2m protocol: retain `candidate_method` and
the ordered covariance/parameter provenance, so a retry and Newton correction
cannot be conflated in a later decision ledger.
