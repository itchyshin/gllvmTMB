// gllvmTMB_va_r3.cpp -- standalone, research-only Gaussian VA objective.
//
// This template implements Design 85 only.  It is deliberately separate from
// the shipped gllvmTMB engine and supplies no public fitting method, marginal
// likelihood, rank selection, REML adjustment, or TMB random-parameter path.

#include <TMB.hpp>
#include <cmath>
#include <vector>

// Stable softplus in the exact max/log1p form required by Design 85.  The
// only exponential has a non-positive argument, including on AD tapes.
template <class Type>
Type va_r3_softplus(const Type &x)
{
  Type zero = Type(0.0);
  Type abs_x = CppAD::CondExpGe(x, zero, x, -x);
  Type max_x = CppAD::CondExpGe(x, zero, x, zero);
  // TMB's logspace_add is its AD-safe implementation of
  // log(exp(0) + exp(-abs_x)) = log1p(exp(-abs_x)).
  return max_x + logspace_add(zero, -abs_x);
}

// Stable inverse logit used only to form softplus derivatives in the small-v
// expansion.  As above, exp() is evaluated only at a non-positive argument.
template <class Type>
Type va_r3_invlogit(const Type &x)
{
  Type zero = Type(0.0);
  Type abs_x = CppAD::CondExpGe(x, zero, x, -x);
  Type e = exp(-abs_x);
  Type upper = Type(1.0) / (Type(1.0) + e);
  Type lower = e / (Type(1.0) + e);
  return CppAD::CondExpGe(x, zero, upper, lower);
}

// E[softplus(mu + sqrt(v) Z)] by physicists' Gauss-Hermite quadrature.
//
// At small v, the heat-kernel expansion
//   f + v f''/2 + v^2 f''''/8 + v^3 f^(6)/48 + O(v^4)
// is a polynomial in v.  Thus AD never differentiates sqrt(v) at zero.  The
// GH branch receives max(v, threshold), and the outer CondExp selects the
// polynomial branch when v <= threshold.  At 1e-6 the omitted value term is
// O(1e-24) and the omitted first derivative is O(1e-18) for softplus.
template <class Type>
Type va_r3_softplus_expectation(const Type &mu,
                                const Type &v,
                                const vector<Type> &gh_nodes,
                                const vector<Type> &gh_weights)
{
  const Type threshold = Type(1e-6);
  const Type one = Type(1.0);

  Type p = va_r3_invlogit(mu);
  Type pq = p * (one - p);
  Type p2 = p * p;
  Type p3 = p2 * p;
  Type p4 = p2 * p2;
  Type f2 = pq;
  Type f4 = pq * (one - Type(6.0) * p + Type(6.0) * p2);
  Type f6 = pq * (one - Type(30.0) * p + Type(150.0) * p2
                  - Type(240.0) * p3 + Type(120.0) * p4);
  Type expansion = va_r3_softplus(mu)
    + v * f2 / Type(2.0)
    + v * v * f4 / Type(8.0)
    + v * v * v * f6 / Type(48.0);

  Type safe_v = CppAD::CondExpGt(v, threshold, v, threshold);
  Type scale = sqrt(Type(2.0) * safe_v);
  Type weighted_sum = Type(0.0);
  for (int h = 0; h < gh_nodes.size(); ++h) {
    weighted_sum += gh_weights(h) *
      va_r3_softplus(mu + scale * gh_nodes(h));
  }
  const Type sqrt_pi = sqrt(Type(3.141592653589793238462643383279502884));
  Type quadrature = weighted_sum / sqrt_pi;

  return CppAD::CondExpGt(v, threshold, quadrature, expansion);
}

// Jaakkola-Jordan / Polya-Gamma variational upper bound on
// E[softplus(mu + sqrt(v) Z)] for eta ~ N(mu, v), returned in the same
// "softplus expectation" units as va_r3_softplus_expectation() above so the
// two evaluation tiers plug into the identical ell = log_choose + y*mu -
// n*softplus_expectation formula. With xi = sqrt(mu^2 + v):
//   softplus_expectation_jj = log(2*cosh(xi/2)) + mu/2
// which recovers the textbook bound
//   ell_JJ = log_choose + (y - n/2)*mu - n*log(2*cosh(xi/2)).
//
// As xi^2 -> 0, sqrt(xi^2) has an unbounded derivative at zero, so below a
// threshold on xi^2 = mu^2 + v this instead evaluates the Taylor series of
// log(2*cosh(z)) in z^2 = xi^2/4 -- a smooth polynomial in mu and v with no
// square root. At 1e-6 the omitted quartic term is O(1e-12) in value and
// smaller still in the first derivative, matching the threshold convention
// used for the small-v branch above.
template <class Type>
Type va_r3_jj_softplus_expectation(const Type &mu, const Type &v)
{
  const Type threshold = Type(1e-6);
  Type xi2 = mu * mu + v;
  Type safe_xi2 = CppAD::CondExpGt(xi2, threshold, xi2, threshold);
  Type half_xi = sqrt(safe_xi2) / Type(2.0);
  Type exact = logspace_add(half_xi, -half_xi) + mu / Type(2.0);

  Type t = xi2 / Type(4.0);
  Type expansion = log(Type(2.0))
    + t / Type(2.0)
    - t * t / Type(12.0)
    + t * t * t / Type(45.0)
    + mu / Type(2.0);

  return CppAD::CondExpGt(xi2, threshold, exact, expansion);
}

// ---------------------------------------------------------------------------
// Design 108 Gate A Stage 4: a tail-safe log Phi for use INSIDE the quadrature.
//
// Design 105 s1.3 is the reason this exists.  Every probit guard in the shipped
// engine was written for a single evaluation at eta = mu, but under the
// physicists' Gauss-Hermite rule the integrand is evaluated at
// eta_h = mu + sqrt(2v) x_h, and the extreme node reaches +/- 6.36 SD of eta at
// H = 15 and +/- 14.50 SD at H = 61.  Past x ~ -37.5 the double-precision
// pnorm() underflows to 0, and past x ~ -38.6 dnorm() does too, so the naive
// derivative dnorm(x)/pnorm(x) becomes 0/0 = NaN -- which is a NaN gradient,
// not a slightly wrong one.  Verified: dnorm(-40)/pnorm(-40) is NaN in double.
//
// Laplace continued fraction for the Mills ratio (Laplace 1805; the standard
// convergent -- NOT asymptotic -- expansion), evaluated by backward recurrence:
//
//   Phi(-z) / phi(z) = 1 / (z + 1/(z + 2/(z + 3/(z + ...))))     for z > 0
//
// This returns the tail c(z) so that the Mills ratio is 1/(z + c) and its
// reciprocal, the inverse Mills ratio phi(z)/Phi(-z), is exactly (z + c).  The
// recurrence only ever divides by (z + c) with c >= 0 and z >= va_r3_logphi_z0,
// so every denominator is bounded below by that switch point: the whole helper
// is a bounded rational function of z with no branch and nothing that can
// vanish.  With the switch at z = 10 and K = 20 terms the value agrees with R's
// pnorm(log.p = TRUE) to 0 ULP over z in [10, 200] (measured, not asserted).
template <class Type>
Type va_r3_mills_cf(const Type &z)
{
  const int K = 20;
  Type c = Type(0.0);
  for (int k = K; k >= 1; --k)
    c = Type(static_cast<double>(k)) / (z + c);
  return c;
}

// The switch point |x| = z0 between the continued fraction and log(pnorm()).
// Both sides have headroom at 10: pnorm(-10) = 7.6e-24 is 284 orders above
// underflow, and the CF has already converged to 0 ULP by z = 10 with K = 20.
static const double va_r3_logphi_z0 = 10.0;

// log Phi(x), tail-safe for arbitrarily negative x.
//
// AD-safety rests on ONE rule, the same one the shipped engine's
// gll_log_pnorm() uses (src/gllvmTMB.cpp:83): CppAD::CondExp evaluates BOTH
// branches, so an UNSELECTED branch that computes a non-finite value can still
// contaminate the tape.  The fix is to clamp the INPUT of each branch, never
// its output, so that neither branch can produce a non-finite value or a
// non-finite partial in the region where it is not used.
//
// WHAT THE CLAMP ACTUALLY PROTECTS -- measured, do not weaken on the strength
// of a gradient check (adversarial review, 2026-08-02).  An earlier version of
// this comment said an unselected log(0) "would poison the GRADIENT".  That is
// WRONG on this CppAD/TMB build, and the error is dangerous in one specific
// way: it invites a future reader to test only obj$gr(), see it finite, and
// conclude the clamp is unnecessary.  Removing the clamp and probing at
// x = -50 gives, measurably:
//     clamped (as shipped) : fn 1254.83   gr -50.02   he  0.999601
//     unclamped            : fn 1254.83   gr -50.02   he  NaN
// The gradient stays finite AND CORRECT; it is the HESSIAN that dies.  So any
// check that this clamp is still needed MUST call obj$he(), not just obj$gr().
// test-va-probit-adsafety.R's `finite` predicate does include he() -- that is
// why the test is stronger than the rationale this comment used to give.
//
// Only the LEFT tail needs the special form.  The right tail is handled by
// symmetry at the call site (log(1 - Phi(eta)) is always written log Phi(-eta)),
// so the cancellation-prone difference of two nearly-equal CDFs -- Design 105
// s6.3's objection -- is never formed at all.
template <class Type>
Type va_r3_log_pnorm(const Type &x)
{
  const Type z0 = Type(va_r3_logphi_z0);
  const Type half_log_two_pi = Type(0.5) *
    log(Type(2.0) * Type(3.141592653589793238462643383279502884));
  // Tail branch: z = max(-x, z0) >= z0 > 0, so the continued fraction is
  // evaluated only where it converges, and -0.5 z^2 - log(z + c) is finite for
  // every finite z.
  Type z = CppAD::CondExpGt(-x, z0, -x, z0);
  Type tail = -Type(0.5) * z * z - half_log_two_pi - log(z + va_r3_mills_cf(z));
  // Direct branch: xd = max(x, -z0) >= -10, where pnorm(xd) >= 7.62e-24 and
  // the derivative dnorm(xd)/pnorm(xd) <= 10.03.  Nothing underflows.
  Type xd = CppAD::CondExpLt(x, -z0, -z0, x);
  Type direct = log(pnorm(xd));
  return CppAD::CondExpLt(x, -z0, tail, direct);
}

// log(1 - exp(a)) for a <= 0.
//
// Each branch receives its OWN safe surrogate while the selected small-u branch
// retains the true u. This matters for zero-truncated families: in the left tail
// a = log(P0) is arbitrarily close to zero and log(1-P0) ~ log(-a). Flooring the
// shared input at unit roundoff changes that density (eta=-40 was wrong by 3.34
// log units). A branch-local surrogate keeps the unselected path finite without
// changing the selected likelihood.
//
// Why both branches are safe everywhere:
//  (i)   the cubic u - u^2/2 + u^3/6 has derivative ((u-1)^2 + 1)/2 > 0 for all
//        u, so it increases strictly from 0 and is strictly POSITIVE for every
//        u > 0; its branch-local input is also capped before evaluation;
//  (ii)  the direct branch sees max(u, 1e-6), so 1-exp(-u) cannot round to zero
//        on its unselected path;
//  (iii) the series branch sees min(max(u, 1e-300), 1e-6), so it cannot return
//        log(0) or overflow on its unselected path. The lower floor acts only
//        beyond the representable probability range, not at ordinary tails.
template <class Type>
Type va_r3_log1mexp(const Type &a)
{
  const Type switch_u = Type(1e-6);
  const Type tiny_u = Type(1e-300);
  Type u = -a;
  Type positive_u = CppAD::CondExpGt(u, tiny_u, u, tiny_u);
  Type series_u = CppAD::CondExpLt(positive_u, switch_u,
                                   positive_u, switch_u);
  Type direct_u = CppAD::CondExpGt(positive_u, switch_u,
                                   positive_u, switch_u);
  Type series = log(series_u - series_u * series_u / Type(2.0)
                    + series_u * series_u * series_u / Type(6.0));
  Type direct = log(Type(1.0) - exp(-direct_u));
  return CppAD::CondExpLt(positive_u, switch_u, series, direct);
}

// log(Phi(a) - Phi(b)) for a > b -- the ordinal cell probability.
//
// This breaks the standing invariant stated above ("the cancellation-prone
// difference of two nearly-equal CDFs is never formed at all").  Forming it is
// unavoidable for a cumulative-probit ordinal likelihood, but the regime is the
// FAVOURABLE one: under Albert-Chib it is evaluated ONCE PER CELL at eta = mu,
// not at H quadrature nodes -- the same regime the shipped Laplace engine
// already handles, not the harder AGHQ regime.
//
// Algorithm (derivation section 5.7): factor out the larger probability and pick
// the branch by sign(a + b) so the SMALLER of the two candidate leading terms is
// used.  Both log1mexp arguments are <= 0 by construction, since a > b implies
// Phi(b) <= Phi(a) and Phi(-a) <= Phi(-b).
//
//   a + b <= 0 (left) :  logPhi(a)  + log1mexp( logPhi(b)  - logPhi(a)  )
//   a + b >  0 (right):  logPhi(-b) + log1mexp( logPhi(-a) - logPhi(-b) )
//
// The branch is NOT cosmetic.  Naive log(pnorm(a) - pnorm(b)) is fine in the left
// tail and dies in the right: at (a,b) = (+9.20, +9.00) it returns -inf where the
// stable form gives -43.800817; at (+30.20, +30.00), -inf against -454.323660.
//
// This deliberately does NOT reuse the shipped engine's gll_log_pnorm_diff.  Its
// ALGORITHM is correct and is kept verbatim, but it calls gll_log_pnorm, which
// switches at x = -20 to a 4-term asymptotic Mills series; va_r3_log_pnorm above
// switches at -10 to a 20-term convergent continued fraction (0 ULP over
// z in [10,200], correct to x = -145).  The VA tier uses the better primitive it
// already owns.
template <class Type>
Type va_r3_log_pnorm_diff(const Type &a, const Type &b)
{
  Type left = va_r3_log_pnorm(a) +
    va_r3_log1mexp(va_r3_log_pnorm(b) - va_r3_log_pnorm(a));
  Type right = va_r3_log_pnorm(-b) +
    va_r3_log1mexp(va_r3_log_pnorm(-a) - va_r3_log_pnorm(-b));
  return CppAD::CondExpLe(a + b, Type(0.0), left, right);
}

// Clamp an AD value while keeping both CondExp branches finite.  This is used
// only inside nodewise density kernels whose natural parameters must stay in
// an open domain (Beta shapes and positive means at extreme GH nodes).
template <class Type>
Type va_r3_clamp(const Type &x, const Type &lower, const Type &upper)
{
  Type ans = CppAD::CondExpLt(x, lower, lower, x);
  return CppAD::CondExpGt(ans, upper, upper, ans);
}

// Stable cloglog success probability on the log scale.  Above eta = 35 the
// probability differs from one by less than double precision, so returning
// zero avoids exp(eta) overflowing in an unselected AD branch.  The failure
// contribution is integrated analytically elsewhere as -E[exp(eta)].
template <class Type>
Type va_r3_cloglog_logp(const Type &eta)
{
  const Type upper = Type(35.0);
  Type safe_eta = CppAD::CondExpGt(eta, upper, upper, eta);
  Type ordinary = va_r3_log1mexp(-exp(safe_eta));
  return CppAD::CondExpGt(eta, upper, Type(0.0), ordinary);
}

// Truncated-Poisson / PoisG closed-form cloglog VA expectation
// (gllvm 2.0.13 src/gllvm.cpp ~3303-3311, method="VA", extra==2).
//
// gllvm stores cQ = v/2 and writes, with mu_pois = exp(eta + cQ):
//   y*log1p(-exp(-mu_pois*exp(-cQ))) - (N-y)*mu_pois
//     + mu_pois*(exp(-cQ)-1)
// which algebraically equals (our mu = E_q[eta], v = Var_q[eta]):
//   y * cloglog_logp(mu) + exp(mu) - (n - y + 1) * exp(mu + v/2).
//
// THIS IS A DIFFERENT OBJECTIVE from the GH cloglog branch below (which
// quadratures E[cloglog_logp(eta)] and uses the exact failure mean
// E[exp(eta)]). It is the construction gllvm ships as cloglog VA -- NOT
// JJ, NOT AC, NOT EVA/GH. Research/comparator tier: registry default for
// binomial_cloglog remains "gh"; callers opt in with eval_method = "poisg".
// Returns the same units as the GH cloglog evaluator so both plug into
// ell = log_choose + <evaluator>.
template <class Type>
Type va_r3_cloglog_poisg_expectation(const Type &mu, const Type &v,
                                     const Type &y, const Type &n)
{
  Type e_mu = exp(mu);
  Type e_mean = exp(mu + v / Type(2.0));
  return y * va_r3_cloglog_logp(mu) + e_mu - (n - y + Type(1.0)) * e_mean;
}

// Inverse Mills ratio lambda(x) = phi(x)/Phi(x) = d/dx log Phi(x).
//
// Needed only by the small-v expansion below, but it carries the same 0/0
// hazard, so it gets the same two-branch treatment.  In the tail it is the
// continued-fraction DENOMINATOR (z + c) read off directly -- no division by a
// probability that has underflowed.
template <class Type>
Type va_r3_inv_mills(const Type &x)
{
  const Type z0 = Type(va_r3_logphi_z0);
  Type z = CppAD::CondExpGt(-x, z0, -x, z0);
  Type tail = z + va_r3_mills_cf(z);
  Type xd = CppAD::CondExpLt(x, -z0, -z0, x);
  Type direct = dnorm(xd, Type(0.0), Type(1.0), false) / pnorm(xd);
  return CppAD::CondExpLt(x, -z0, tail, direct);
}

// E[ y log Phi(eta) + (n - y) log Phi(-eta) ] for eta ~ N(mu, v), by the same
// physicists' Gauss-Hermite rule the softplus expectation uses.
//
// `threshold` is a caller-supplied argument (Design 108 Gate A Stage 5 --
// added when va_r3_probit_ac2_expectation below needed this SAME
// expansion/quadrature hybrid at a much larger switch point). It MUST stay
// an ordinary CondExp comparison, not a native if/else: v is a function of
// the free parameters (an AD Type, not fixed DATA like eval_method above),
// so a native `if (v > threshold)` would bake in whichever branch the
// TAPE-RECORDING parameter values happened to select and silently keep
// using it as v moves during optimisation -- exactly the failure mode the
// "eval_method is fixed DATA" comment elsewhere in this file distinguishes
// itself from. Both branches are therefore evaluated on every call
// regardless of threshold -- CondExp is a differentiable SELECT, not a
// runtime skip -- so raising `threshold` does NOT, by itself, reduce the
// per-call cost of this function; see va_r3_probit_ac2_expectation's own
// comment for what raising it actually buys and what it does not.
//
// The "gh" tier (this function's original, sole caller before ac2) passes
// Type(1e-6): effectively "always quadrature", since GH's whole purpose is
// exactness. That call is UNCHANGED by adding this parameter -- it now
// passes the literal 1e-6 explicitly where it used to be a local constant.
//
// Small v: as for softplus, sqrt(v) has an unbounded derivative at v = 0, so
// the GH branch receives max(v, threshold) and the outer CondExp selects a
// heat-kernel expansion below the threshold.  Here the expansion is carried to
// FIRST order in v,
//     E[g(mu + sqrt(v) Z)] = g(mu) + v g''(mu)/2 + O(v^2),
// with g''(x) obtained from the standard identity
//     d^2/dx^2 log Phi(x) = -lambda(x) (x + lambda(x)).
// Stopping at first order (rather than the softplus branch's third) is a
// deliberate, bounded choice: at the ORIGINAL threshold v = 1e-6 the omitted
// term is O(v^2) = 1e-12 in the value and O(v) = 1e-6 RELATIVE in dE/dv,
// against an O(1) leading term -- while the fourth derivative of log Phi is
// a quartic in lambda whose hand-derivation is a correctness risk with no
// measurable payoff. At ac2's much larger threshold this omitted-term
// argument no longer applies verbatim at that scale; see that function's
// own accuracy evidence (measured against quadrature, not re-derived here).
template <class Type>
Type va_r3_probit_expectation(const Type &mu, const Type &v,
                              const Type &y, const Type &n,
                              const vector<Type> &gh_nodes,
                              const vector<Type> &gh_weights,
                              const Type &threshold)
{
  Type lam_p = va_r3_inv_mills(mu);
  Type lam_q = va_r3_inv_mills(-mu);
  // g(eta) = y logPhi(eta) + (n-y) logPhi(-eta); the second term's second
  // derivative in eta is logPhi''(-mu), hence the sign flip on mu below.
  Type d2_p = -lam_p * (mu + lam_p);
  Type d2_q = -lam_q * (-mu + lam_q);
  Type expansion = y * va_r3_log_pnorm(mu) + (n - y) * va_r3_log_pnorm(-mu)
    + v * (y * d2_p + (n - y) * d2_q) / Type(2.0);

  Type safe_v = CppAD::CondExpGt(v, threshold, v, threshold);
  Type scale = sqrt(Type(2.0) * safe_v);
  Type weighted_sum = Type(0.0);
  for (int h = 0; h < gh_nodes.size(); ++h) {
    Type eta_h = mu + scale * gh_nodes(h);
    weighted_sum += gh_weights(h) *
      (y * va_r3_log_pnorm(eta_h) + (n - y) * va_r3_log_pnorm(-eta_h));
  }
  const Type sqrt_pi = sqrt(Type(3.141592653589793238462643383279502884));
  Type quadrature = weighted_sum / sqrt_pi;

  return CppAD::CondExpGt(v, threshold, quadrature, expansion);
}

// Albert-Chib closed-form replacement for va_r3_probit_expectation above.
//
// Returns E[ y log Phi(eta) + (n - y) log Phi(-eta) ] in the SAME UNITS as the
// GH evaluator, so both plug into the identical `ell = log_choose + <evaluator>`
// formula at the family/link 1/1 dispatch -- the same contract
// va_r3_jj_softplus_expectation() honours for fam == 1.
//
// DERIVATION: dev/va-speed/ALBERT-CHIB-DERIVATION.md.  Augmenting with a
// truncated-normal auxiliary z ~ N(eta, 1) and maximising the augmented ELBO
// over a free-form q(z) at fixed q(a) has the closed-form maximiser
// q*(z) = TN(mu, 1, H_y), and the profiled value collapses to the expression
// below -- no residual free parameter, so z never becomes a TMB parameter.
// The closed form was confirmed against a 200-node GH reference to 6.2e-11.
//
// THIS IS A DIFFERENT OBJECTIVE.  It is a strict LOWER BOUND on the GH value,
// not an approximation to it, so it does NOT inherit GH's accuracy evidence and
// must carry its own against planted truth.  It is also loosest exactly on
// well-fitted cells, which at convergence is most of them.
//
// n * v / 2, NOT v / 2: there is one latent z per TRIAL, and each charges v/2.
// The two coincide only at n = 1.  gllvm subtracts v/2 once per cell regardless
// of trial.size; at n = 20 that is not a lower bound at all, exceeding the true
// value by up to 10.98 nats (measured).  gllvmTMB carries n_trials, so it must
// use the n-scaled form -- copying the reference here would be wrong.
//
// No gh_nodes, no threshold, no CondExp: v enters LINEARLY, so the sqrt(v)
// unbounded-derivative-at-zero problem that forces the GH evaluator's small-v
// expansion branch does not arise here at all.
template <class Type>
Type va_r3_probit_ac_expectation(const Type &mu, const Type &v,
                                 const Type &y, const Type &n)
{
  return y * va_r3_log_pnorm(mu) + (n - y) * va_r3_log_pnorm(-mu)
    - n * v / Type(2.0);
}

// Curvature-corrected alternative to va_r3_probit_ac_expectation above.
// ADDITIVE, opt-in ("ac2"): the function above is untouched byte-for-byte.
//
// va_r3_probit_ac_expectation hard-codes BOTH second derivatives of the
// probit log-likelihood to their worst-case value -1 (its "- n*v/2" term is
// (v/2)*[y*(-1) + (n-y)*(-1)]).  The EXACT mu-dependent second derivatives
// are
//   (log Phi(mu))''     = -h(mu) (mu + h(mu)),  h(mu) = phi(mu)/Phi(mu)
//   (log(1-Phi(mu)))''  =  g(mu) (mu - g(mu)),  g(mu) = phi(mu)/(1-Phi(mu))
// both of which lie in (-1, 0) and equal -2/pi = -0.6366 at mu = 0,
// approaching -1 only in the respective far tail (Mills-ratio inequality).
// This is the standard second-order delta-method expansion of E_q[log p]
// for eta ~ N(mu, v) (see e.g. Hui, Warton, Ormerod et al. 2017, JCGS) --
// re-derived and checked here against central finite differences of
// pnorm(., log.p = TRUE), not transliterated from any external source.
//
// WHY THIS IS A HYBRID, NOT A PURE EXPANSION (measured, not theoretical).
// An earlier version of this function used the expansion above
// UNCONDITIONALLY for every v. That is unsound as an OPTIMISATION
// OBJECTIVE, not merely imprecise: as |mu| grows, h(mu)(mu+h(mu)) -> 1, so
// BOTH curvatures -> 0, and the variance penalty v*(...)/2 vanishes with
// them. A pure-expansion "ac2" therefore has nothing stopping the
// optimiser from inflating the loadings: bigger Lambda -> bigger |mu| in
// the tail -> smaller curvature -> smaller penalty -> bigger Lambda again.
// Measured (probit, n=150, p=20, q=2): the pure expansion reached
// `convergence: 0` (nlminb reports success) with max_v ~ 1.5e10 and
// Sigma trace ~ 2.2e9 -- ten orders of magnitude past anything physical --
// correctly refused by the
// `variance_domain_ok <- max_projected_variance <= 4` gate
// (R/va-r3-proto.R). That gate is a REFEREE catching a real design flaw in
// this function, not a bug to route around; it is unchanged by this fix.
//
// THE FIX: give this function the SAME expansion/quadrature hybrid
// va_r3_probit_expectation already uses for its own, much smaller reason
// (the sqrt(v) derivative singularity at v=0), at a much larger switch
// point, so quadrature -- whose implied curvature does NOT vanish, because
// it evaluates log Phi at the actual GH nodes rather than trusting a local
// derivative -- takes over before the runaway regime is reached. Reuses
// va_r3_probit_expectation verbatim (no new quadrature code).
//
// THE THRESHOLD IS RUNTIME DATA (DATA_SCALAR(ac2_threshold) below, plumbed
// from R/va-r3-proto.R's ac2_threshold argument), not a compile-time
// constant -- deliberately, so a sweep over switch points needs no rebuild.
// R's default is 1.0. Measured (stats::integrate() quadrature oracle,
// independent of both this expansion and the package's own GH rule):
// worst absolute error of the expansion vs the true E_q[log p], over mu in
// [-2,2] and y in {0,1}, is 0.0176 at v=1.0, rising smoothly to 0.060 at
// v=2.0 and 0.118 at v=3.0, and falling to 0.0070 at v=0.6. 1.0 sits where
// the expansion is still a modest, bounded approximation and not yet past
// it -- above it, quadrature takes over exactly, for ANY threshold value,
// because the underlying call is the identical va_r3_probit_expectation.
//
// h and g in the expansion branch are exactly va_r3_inv_mills(mu) (:276)
// and va_r3_inv_mills(-mu): the SAME primitive va_r3_probit_expectation's
// own small-v branch already uses for this identical curvature -- inherited
// automatically now that this function forwards to it, rather than
// duplicated here.
//
// ELBO STATUS, revised for the hybrid. For v > threshold this function IS
// va_r3_probit_expectation's quadrature branch -- the same value "gh"
// would compute for that row -- which numerically approximates the exact
// integral, so it inherits the ordinary variational-inequality argument (a
// genuine ELBO term) there. For v <= threshold it is still the plain
// delta-method expansion above, with unsigned truncation error, not a
// proven bound. Because a single fit can have rows on EITHER side of the
// threshold, the objective AS A WHOLE is not uniformly a certified ELBO --
// R/va-r3-proto.R's .va_r3_objective_type still labels it "APPROX_AC2",
// not "ELBO_AC2", for exactly this reason (true at every threshold value,
// including one so small the fit is ELBO-valid almost everywhere in
// practice, because "almost everywhere" is not "everywhere"). Do not treat
// an ac2 fit's `elbo` as a certified lower bound on the marginal
// likelihood. Research/comparison tier only -- R/va-r3-proto.R's registry
// keeps "gh" as binomial_probit's default_tier; this tier is not reachable
// from the public integration fence.
//
// COST. Both branches of a CondExp are evaluated on every call regardless
// of which is selected (see va_r3_probit_expectation's own comment above)
// -- so this hybrid does NOT skip the quadrature loop's per-call cost
// merely by raising the threshold past it; the threshold changes which
// VALUE is selected, not how much is computed to select it. See the
// implementation report for the measured fit-time comparison against "ac"
// and "gh" across a range of threshold values -- an empirical question,
// not a theoretical guarantee of this structure.
template <class Type>
Type va_r3_probit_ac2_expectation(const Type &mu, const Type &v,
                                  const Type &y, const Type &n,
                                  const vector<Type> &gh_nodes,
                                  const vector<Type> &gh_weights,
                                  const Type &threshold)
{
  return va_r3_probit_expectation(mu, v, y, n, gh_nodes, gh_weights,
                                   threshold);
}

template <class Type>
Type objective_function<Type>::operator()()
{
  // Data are long-format dense cells (exactly N*T rows). unit_id and trait_id
  // are zero-based. Design 107: is_y_observed gates the density term; masked
  // rows keep a sentinel y/n_trials that is never evaluated.
  DATA_VECTOR(y);
  DATA_VECTOR(n_trials);
  DATA_MATRIX(X);
  DATA_IVECTOR(unit_id);
  DATA_IVECTOR(trait_id);
  DATA_IVECTOR(is_y_observed);     // 1 = response observed, 0 = masked (Design 107)
  DATA_INTEGER(N);
  DATA_INTEGER(T);
  DATA_INTEGER(q);
  DATA_VECTOR(gh_nodes);
  DATA_VECTOR(gh_weights);
  // Design 110: the VA template uses the SAME scalar-family identifiers as the
  // Laplace template: family 0:15 plus the same binomial link identifiers
  // (0 logit, 1 probit, 2 cloglog).  Multinomial 16 is deliberately fenced.
  DATA_IVECTOR(family);
  DATA_IVECTOR(link_id);
  DATA_IVECTOR(n_ordinal_cuts_per_trait);
  DATA_IVECTOR(ordinal_offset_per_trait);
  DATA_INTEGER(eval_method);       // 0 = Gauss-Hermite quadrature;
                                   // 1 = Jaakkola-Jordan/PG bound (binomial-only fits)
                                   // 2 = Albert-Chib closed form (binomial-probit only)
                                   // 3 = "ac2", curvature-corrected Albert-Chib
                                   //     (binomial-probit only; research/comparison
                                   //     tier, see va_r3_probit_ac2_expectation above)
                                   // 4 = "poisg", truncated-Poisson closed form
                                   //     (binomial-cloglog only; research/comparison
                                   //     tier, see va_r3_cloglog_poisg_expectation)
  // "ac2"'s expansion/quadrature switch point (va_r3_probit_ac2_expectation
  // above). Runtime DATA, not a compile-time constant, so a threshold sweep
  // needs no rebuild; read unconditionally, so it must be present (and
  // finite and positive -- checked R-side, R/va-r3-proto.R) even when
  // eval_method != 3, where it is simply unused.
  DATA_SCALAR(ac2_threshold);

  // ---------------------------------------------------------------------
  // Design 108 Gate A Stage 6: multiple unstructured tiers (Design 106 s1).
  //
  // An observation o loads on ONE level of each tier k:
  //     eta_o = x_o' beta + sum_k a_{k,o}' u_{k, g_k(o)}
  // and Proposition 1 makes mu and v ACCUMULATE across tiers, with the KL
  // decomposing into a sum over tiers and levels.  No new integrand, no new
  // quadrature, no new linear algebra -- only indexing.
  //
  // Two loading SHAPES, and they get two code paths on purpose:
  //   tier_kind == 0  DENSE.  a_{k,o} = Lambda_k(trait(o), .), a T x d_k
  //     lower-triangular loadings matrix unpacked from theta_rr.  The
  //     variational block is a full d_k x d_k Cholesky.
  //   tier_kind == 1  TRAIT-DIAGONAL (Psi / unique / indep / cluster).
  //     a_{k,o} = sd_{k,trait(o)} * e_{trait(o)}, so d_k == T and each
  //     observation loads on exactly ONE coordinate.  Design 106
  //     Proposition 2 (Fischer's inequality) says the optimal q is then
  //     block-diagonal EXACTLY, so this path allocates NO off-diagonal
  //     Cholesky entries at all: 2T numbers per level, not T + T(T+1)/2.
  //     That is a free reduction, not an approximation -- 7.25x at T = 26 --
  //     and routing a diagonal tier through the dense path would silently
  //     forfeit it.
  //
  // Tier 0 is the ordinary latent tier by construction: it is dense, has
  // dimension q, has N levels, and its level index IS unit_id.  Every one of
  // those is checked below, so the K = 1 layout is provably today's layout.
  DATA_INTEGER(n_tiers);
  DATA_IVECTOR(tier_kind);         // length K: 0 = dense, 1 = trait-diagonal
  DATA_IVECTOR(tier_dim);          // length K: d_k (== T for diagonal tiers)
  DATA_IVECTOR(tier_n_levels);     // length K: n_k
  DATA_IMATRIX(level_id);          // n_obs x K, zero-based; column 0 == unit_id

  // ---------------------------------------------------------------------
  // Design 108 Gate A Stage 7: STRUCTURED prior on a tier (Design 106 s3).
  //
  // A structured tier differs from an unstructured one in EXACTLY one place:
  // its KL.  The data term is untouched -- the loading shapes above are still
  // the only two -- so nothing in the mu/v accumulation changes.
  //
  // Convention (Design 106 s3.2), copied from the shipped Laplace engine
  // (src/gllvmTMB.cpp:1166-1174, 1203-1208) rather than reinvented:
  //
  //     g_{.,c} ~ N(0, A)  independently for each coordinate c,
  //     eta += a_{k,o}' u_{k,g},     the SCALE living in the loading a,
  //     -log p(g_c) = 0.5*( n*log(2pi) + log_det_A + g_c' Ainv g_c )
  //
  // This is the STANDARDIZED-FIELD convention: the field is unit-scale and the
  // scale sits in the linear predictor.  Its consequence is the one that makes
  // this stage tractable -- under it the structured KL contains NO model
  // hyperparameters at all.  `Ainv` is pure DATA.
  //
  // With prior precision Q_p = I_d (x) Ainv and a level-factorised
  // q = prod_g N(m_g, S_g), Design 106 s3.1 + s3.3 give
  //
  //   KL = 0.5*[ sum_g Ainv_gg * tr(S_g)          <- s3.3: only diag(Ainv)
  //            + sum_c m_.c' Ainv m_.c            <- s3.5a: the Laplace block
  //            - n*d
  //            - sum_g logdet(S_g)
  //            + d * log_det_A ]                  <- s3.4: kept, not dropped
  //
  // Setting Ainv = I collapses every term to the existing per-level
  // 0.5*(tr(S_g) + m_g'm_g - logdet(S_g) - d), EXACTLY.  That identity is the
  // stage's primary oracle and is asserted to 1e-14 in
  // tests/testthat/test-va-r3-structured-phylo.R.
  //
  // ONE shared precision, not one per tier.  That mirrors the engine, which
  // runs phylo_rr, phylo_diag and phylo_slope through the single
  // Ainv_phy_rr / log_det_A_phy_rr pair, and it is what
  // `phylo_latent(unique = TRUE)` needs: a structured low-rank tier and a
  // structured diagonal Psi tier over the SAME tree.  Two different trees are
  // out of scope for this stage and are refused on the R side.
  //
  // The number of levels of a structured tier is nrow(Ainv) and nothing else.
  // For the augmented Hadfield representation those levels are tips PLUS
  // internal nodes, so most of them carry no observation at all; the R adapter
  // therefore relaxes its "every level must be used" check for structured
  // tiers only.  No 2N-1 (or 2N-2) arithmetic appears anywhere: polytomies and
  // non-bifurcating trees are handled by reading the matrix.
  DATA_IVECTOR(tier_structured);   // length K: 0 = iid prior, 1 = uses Ainv
  DATA_SPARSE_MATRIX(Ainv_struct); // shared structured precision, n_struct^2
  DATA_VECTOR(diag_Ainv_struct);   // diag(Ainv), the ONLY thing the trace needs
  DATA_SCALAR(log_det_A_struct);   // log det A = -log det Ainv (engine's sign)

  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(theta_rr);      // dense tiers' packed loadings, tier order;
                                   // live-engine packing, raw diagonal first
  PARAMETER_VECTOR(log_sd_tier);   // diagonal tiers' per-trait log SDs, T per
                                   // diagonal tier, tier order
  // The variational block is stored FLAT, tier-major, and within a tier in
  // the same column-major order the pre-Stage-6 N x q matrices used:
  //     entry (tier k, level g, coordinate c) sits at
  //     offset_k + c * tier_n_levels(k) + g.
  // At K = 1 that is exactly as.vector() of the old N x q matrix, element for
  // element, so the K = 1 parameter vector is byte-identical to Stage 5's.
  PARAMETER_VECTOR(m);             // variational means
  PARAMETER_VECTOR(log_L_diag);    // log Cholesky diagonals (log SDs when diagonal)
  PARAMETER_VECTOR(L_off);         // strict-lower Cholesky entries, dense tiers only
  PARAMETER_VECTOR(log_sigma);                    // Gaussian identity, fid 0
  PARAMETER_VECTOR(log_sigma_lognormal);          // lognormal, fid 3
  PARAMETER_VECTOR(log_phi_gamma);                // Gamma shape, fid 4
  PARAMETER_VECTOR(log_phi_nbinom2);              // NB2 size, fid 5
  PARAMETER_VECTOR(log_phi_tweedie);              // Tweedie dispersion, fid 6
  PARAMETER_VECTOR(logit_p_tweedie);              // Tweedie p = 1 + invlogit(.)
  PARAMETER_VECTOR(log_phi_beta);                 // Beta precision, fid 7
  PARAMETER_VECTOR(log_phi_betabinom);            // beta-binomial precision, fid 8
  PARAMETER_VECTOR(log_sigma_student);            // Student scale, fid 9
  PARAMETER_VECTOR(log_df_student);               // Student df = 1 + exp(.), fid 9
  PARAMETER_VECTOR(log_phi_truncnb2);             // truncated NB2 size, fid 11
  PARAMETER_VECTOR(log_sigma_lognormal_delta);    // delta-lognormal SD, fid 12
  PARAMETER_VECTOR(log_phi_gamma_delta);          // delta-Gamma CV, fid 13
  PARAMETER_VECTOR(ordinal_log_increments);        // packed ordered increments, fid 14
  PARAMETER_VECTOR(log_phi_nbinom1);              // NB1 overdispersion, fid 15

  const int n_obs = y.size();
  const int n_off = q * (q - 1) / 2;
  const int theta_expected = T * q - q * (q - 1) / 2;

  // Defensive dimension/scope checks. The R adapter performs the richer
  // pre-construction validation required by Design 85.
  if (N <= 0 || T <= 0 || q <= 0 || q > T)
    error("gllvmTMB_va_r3: require N > 0, T > 0, and 1 <= q <= T");
  if (n_obs != N * T)
    error("gllvmTMB_va_r3: the research objective requires exactly N*T cells");
  if (n_trials.size() != n_obs || unit_id.size() != n_obs ||
      trait_id.size() != n_obs || is_y_observed.size() != n_obs ||
      family.size() != n_obs || link_id.size() != n_obs || X.rows() != n_obs)
    error("gllvmTMB_va_r3: response-side data dimensions do not agree");
  if (X.cols() != beta.size())
    error("gllvmTMB_va_r3: ncol(X) must equal length(beta)");

  // ---- Tier structure: validate BEFORE any offset arithmetic uses it. ----
  if (n_tiers < 1)
    error("gllvmTMB_va_r3: n_tiers must be at least 1");
  if (tier_kind.size() != n_tiers || tier_dim.size() != n_tiers ||
      tier_n_levels.size() != n_tiers)
    error("gllvmTMB_va_r3: tier_kind, tier_dim and tier_n_levels must each have length n_tiers");
  if (level_id.rows() != n_obs || level_id.cols() != n_tiers)
    error("gllvmTMB_va_r3: level_id must be n_obs x n_tiers");
  // Tier 0 IS the ordinary latent tier. Pinning it is what makes the K = 1
  // path provably the pre-Stage-6 path rather than a coincidence.
  if (tier_kind(0) != 0 || tier_dim(0) != q || tier_n_levels(0) != N)
    error("gllvmTMB_va_r3: tier 0 must be the dense ordinary latent tier with tier_dim = q and tier_n_levels = N");
  for (int k = 0; k < n_tiers; ++k) {
    if (tier_kind(k) != 0 && tier_kind(k) != 1)
      error("gllvmTMB_va_r3: tier_kind entries must be 0 (dense) or 1 (trait-diagonal)");
    if (tier_n_levels(k) < 1)
      error("gllvmTMB_va_r3: tier_n_levels entries must be positive");
    if (tier_kind(k) == 0) {
      if (tier_dim(k) < 1 || tier_dim(k) > T)
        error("gllvmTMB_va_r3: a dense tier needs 1 <= tier_dim <= T");
    } else {
      // A trait-diagonal tier has one field per trait by definition; any
      // other dimension means the caller packed something else and the
      // per-trait indexing below would read the wrong coordinate.
      if (tier_dim(k) != T)
        error("gllvmTMB_va_r3: a trait-diagonal tier must have tier_dim = T");
    }
  }

  // ---- Structured-tier contract (Stage 7). --------------------------------
  if (tier_structured.size() != n_tiers)
    error("gllvmTMB_va_r3: tier_structured must have length n_tiers");
  if (tier_structured(0) != 0)
    error("gllvmTMB_va_r3: tier 0 is the ordinary latent tier and must be unstructured");
  int n_structured = 0;
  for (int k = 0; k < n_tiers; ++k) {
    if (tier_structured(k) != 0 && tier_structured(k) != 1)
      error("gllvmTMB_va_r3: tier_structured entries must be 0 or 1");
    n_structured += (tier_structured(k) == 1);
  }
  if (n_structured > 0) {
    const int n_struct = Ainv_struct.rows();
    if (n_struct < 1 || Ainv_struct.cols() != n_struct)
      error("gllvmTMB_va_r3: Ainv_struct must be square and non-empty when a tier is structured");
    if (diag_Ainv_struct.size() != n_struct)
      error("gllvmTMB_va_r3: diag_Ainv_struct must have one entry per row of Ainv_struct");
    for (int g = 0; g < n_struct; ++g) {
      // A precision diagonal is strictly positive.  A zero or negative entry
      // means the caller supplied a covariance, a sign-flipped matrix, or a
      // mis-aligned diagonal -- each of which produces a KL that runs.
      if (!std::isfinite(asDouble(diag_Ainv_struct(g))) ||
          !(asDouble(diag_Ainv_struct(g)) > 0.0))
        error("gllvmTMB_va_r3: diag_Ainv_struct entries must be finite and strictly positive");
    }
    if (!std::isfinite(asDouble(log_det_A_struct)))
      error("gllvmTMB_va_r3: log_det_A_struct must be finite");
    for (int k = 0; k < n_tiers; ++k) {
      if (tier_structured(k) == 1 && tier_n_levels(k) != n_struct)
        error("gllvmTMB_va_r3: a structured tier must have one level per row of Ainv_struct");
    }
  }

  // Flat-layout offsets, recomputed here from the tier vectors rather than
  // trusted from R. The length checks that follow therefore CATCH an R/C++
  // disagreement instead of silently reading past a tier boundary.
  std::vector<int> m_offset(n_tiers, 0);
  std::vector<int> off_offset(n_tiers, 0);
  std::vector<int> theta_offset(n_tiers, 0);
  std::vector<int> sd_offset(n_tiers, 0);
  std::vector<int> level_offset(n_tiers, 0);
  int total_mean = 0, total_off = 0, total_theta = 0, total_sd = 0,
      total_levels = 0;
  for (int k = 0; k < n_tiers; ++k) {
    m_offset[k] = total_mean;
    off_offset[k] = total_off;
    theta_offset[k] = total_theta;
    sd_offset[k] = total_sd;
    level_offset[k] = total_levels;
    const int d = tier_dim(k);
    const int nk = tier_n_levels(k);
    total_mean += nk * d;
    total_levels += nk;
    if (tier_kind(k) == 0) {
      total_off += nk * d * (d - 1) / 2;
      total_theta += T * d - d * (d - 1) / 2;
    } else {
      // Proposition 2: zero off-diagonals, T log SDs for the loading.
      total_sd += T;
    }
  }
  if (theta_rr.size() != total_theta)
    error("gllvmTMB_va_r3: theta_rr has the wrong live-packed length for the declared dense tiers");
  if (n_tiers == 1 && theta_rr.size() != theta_expected)
    error("gllvmTMB_va_r3: theta_rr has the wrong live-packed length");
  if (log_sd_tier.size() != total_sd)
    error("gllvmTMB_va_r3: log_sd_tier must supply T entries per trait-diagonal tier");
  if (m.size() != total_mean || log_L_diag.size() != total_mean ||
      L_off.size() != total_off)
    error("gllvmTMB_va_r3: variational parameter dimensions do not agree");
  if (n_tiers == 1 && (m.size() != N * q || L_off.size() != N * n_off))
    error("gllvmTMB_va_r3: variational parameter dimensions do not agree");
  for (int r = 0; r < n_obs; ++r) {
    for (int k = 0; k < n_tiers; ++k) {
      if (level_id(r, k) < 0 || level_id(r, k) >= tier_n_levels(k))
        error("gllvmTMB_va_r3: level_id is out of range for its tier");
    }
    if (level_id(r, 0) != unit_id(r))
      error("gllvmTMB_va_r3: tier 0's level index must be unit_id");
  }
  if (log_sigma.size() != T || log_sigma_lognormal.size() != T ||
      log_phi_gamma.size() != T || log_phi_nbinom2.size() != T ||
      log_phi_tweedie.size() != T || logit_p_tweedie.size() != T ||
      log_phi_beta.size() != T || log_phi_betabinom.size() != T ||
      log_sigma_student.size() != T || log_df_student.size() != T ||
      log_phi_truncnb2.size() != T || log_sigma_lognormal_delta.size() != T ||
      log_phi_gamma_delta.size() != T || log_phi_nbinom1.size() != T)
    error("gllvmTMB_va_r3: every per-trait family parameter must have length T");
  if (n_ordinal_cuts_per_trait.size() != T || ordinal_offset_per_trait.size() != T)
    error("gllvmTMB_va_r3: ordinal metadata must have length T");
  int ordinal_required = 0;
  for (int t = 0; t < T; ++t) {
    if (n_ordinal_cuts_per_trait(t) < 0 || ordinal_offset_per_trait(t) < 0)
      error("gllvmTMB_va_r3: ordinal cut counts and offsets must be non-negative");
    int end = ordinal_offset_per_trait(t) + n_ordinal_cuts_per_trait(t);
    if (end > ordinal_required) ordinal_required = end;
  }
  if (ordinal_log_increments.size() != ordinal_required)
    error("gllvmTMB_va_r3: ordinal_log_increments length disagrees with ordinal metadata");
  if (gh_nodes.size() <= 0 || gh_weights.size() != gh_nodes.size())
    error("gllvmTMB_va_r3: GH nodes and weights must have the same positive length");
  if (eval_method != 0 && eval_method != 1 && eval_method != 2 &&
      eval_method != 3 && eval_method != 4)
    error("gllvmTMB_va_r3: eval_method must be 0 (Gauss-Hermite), 1 (Jaakkola-Jordan/PG bound), 2 (Albert-Chib closed form), 3 (ac2, curvature-corrected Albert-Chib), or 4 (poisg, truncated-Poisson cloglog)");

  // Dense convention: each unit-trait cell is exactly one row. Family range
  // checks apply only to observed cells (Design 107); masked sentinels are
  // never fed to a density call.
  std::vector<int> cell_count(N * T, 0);
  // JJ is binomial-logit only. AC/AC2 are binomial-probit only.
  // PoisG is binomial-cloglog only.
  int n_non_jj = 0;
  int n_non_ac = 0;
  int n_non_poisg = 0;
  for (int r = 0; r < n_obs; ++r) {
    int i = unit_id(r);
    int t = trait_id(r);
    int obs = is_y_observed(r);
    int fam = family(r);
    int lid = link_id(r);
    if (i < 0 || i >= N || t < 0 || t >= T)
      error("gllvmTMB_va_r3: unit_id or trait_id is out of range");
    if (obs != 0 && obs != 1)
      error("gllvmTMB_va_r3: is_y_observed entries must be 0 or 1");
    if (fam < 0 || fam > 15)
      error("gllvmTMB_va_r3: family entries must be Laplace-aligned scalar ids 0:15; multinomial 16 is not admitted");
    if (lid < 0 || lid > 2 || (fam != 1 && lid != 0))
      error("gllvmTMB_va_r3: link_id must be 0:2 for binomial and 0 for every other scalar family");
    if (!(fam == 1 && lid == 0)) n_non_jj += 1;
    if (!(fam == 1 && lid == 1)) n_non_ac += 1;
    if (!(fam == 1 && lid == 2)) n_non_poisg += 1;
    cell_count[i * T + t] += 1;
    if (!std::isfinite(asDouble(y(r))) || !std::isfinite(asDouble(n_trials(r))))
      error("gllvmTMB_va_r3: y and n_trials must be finite");
    if (obs == 1 && (fam == 1 || fam == 8)) {
      double yd = asDouble(y(r));
      double nd = asDouble(n_trials(r));
      if (nd < 1.0 || std::floor(nd) != nd || yd < 0.0 || yd > nd ||
          std::floor(yd) != yd)
        error("gllvmTMB_va_r3: binomial cells require integer n >= 1 and 0 <= y <= n");
    }
    if (obs == 1 && (fam == 2 || fam == 5 || fam == 15)) {
      double yd = asDouble(y(r));
      if (yd < 0.0 || std::floor(yd) != yd)
        error("gllvmTMB_va_r3: count cells require finite non-negative integer y");
    }
    if (obs == 1 && fam == 6 && asDouble(y(r)) < 0.0)
      error("gllvmTMB_va_r3: Tweedie cells require y >= 0");
    if (obs == 1 && (fam == 12 || fam == 13) && asDouble(y(r)) < 0.0)
      error("gllvmTMB_va_r3: delta-family cells require y >= 0");
    if (obs == 1 && fam == 7 && !(asDouble(y(r)) > 0.0 && asDouble(y(r)) < 1.0))
      error("gllvmTMB_va_r3: Beta cells require 0 < y < 1");
    if (obs == 1 && (fam == 3 || fam == 4) && !(asDouble(y(r)) > 0.0))
      error("gllvmTMB_va_r3: lognormal and Gamma cells require y > 0");
    if (obs == 1 && (fam == 10 || fam == 11)) {
      double yd = asDouble(y(r));
      if (yd < 1.0 || std::floor(yd) != yd)
        error("gllvmTMB_va_r3: zero-truncated count cells require positive integer y");
    }
    if (obs == 1 && fam == 14) {
      int K = n_ordinal_cuts_per_trait(t) + 2;
      double yd = asDouble(y(r));
      if (K < 2 || yd < 1.0 || yd > K || std::floor(yd) != yd)
        error("gllvmTMB_va_r3: ordinal cells require integer categories in 1..K");
    }
  }
  if (eval_method == 1 && n_non_jj > 0)
    error("gllvmTMB_va_r3: eval_method = 1 requires pure binomial-logit data");
  if (eval_method == 2 && n_non_ac > 0)
    error("gllvmTMB_va_r3: eval_method = 2 requires pure binomial-probit data");
  // Same domain restriction as eval_method == 2 above -- "ac2" is the same
  // closed-form family with curvature-corrected coefficients, so it reuses
  // n_non_ac rather than widening the admitted family set.
  if (eval_method == 3 && n_non_ac > 0)
    error("gllvmTMB_va_r3: eval_method = 3 requires pure binomial-probit data");
  if (eval_method == 4 && n_non_poisg > 0)
    error("gllvmTMB_va_r3: eval_method = 4 requires pure binomial-cloglog data");
  for (int cell = 0; cell < N * T; ++cell) {
    if (cell_count[cell] != 1)
      error("gllvmTMB_va_r3: every unit-trait cell must occur exactly once");
  }
  for (int h = 0; h < gh_weights.size(); ++h) {
    if (!std::isfinite(asDouble(gh_nodes(h))) ||
        !std::isfinite(asDouble(gh_weights(h))) ||
        !(asDouble(gh_weights(h)) > 0.0))
      error("gllvmTMB_va_r3: GH nodes must be finite and weights finite and positive");
  }
  for (int r = 0; r < X.rows(); ++r) {
    for (int p = 0; p < X.cols(); ++p) {
      if (!std::isfinite(asDouble(X(r, p))))
        error("gllvmTMB_va_r3: X must be finite");
    }
  }

  // Exact live-engine reconstruction, once per DENSE tier: raw diagonal, then
  // strict lower triangle column-by-column. Strict upper triangle stays zero.
  // Diagonal tiers get an empty slot -- their loading is sd_j * e_j and is
  // read straight out of log_sd_tier, never materialised as a matrix.
  std::vector<matrix<Type> > Lambda_tier(n_tiers);
  for (int k = 0; k < n_tiers; ++k) {
    const int d = tier_dim(k);
    if (tier_kind(k) != 0) {
      Lambda_tier[k] = matrix<Type>(0, 0);
      continue;
    }
    matrix<Type> Lk(T, d);
    Lk.setZero();
    const int len = T * d - d * (d - 1) / 2;
    vector<Type> theta_k = theta_rr.segment(theta_offset[k], len);
    vector<Type> lam_diag = theta_k.head(d);
    vector<Type> lam_lower = theta_k.tail(len - d);
    for (int j = 0; j < d; ++j) {
      for (int t = j; t < T; ++t) {
        if (t == j) {
          Lk(t, j) = lam_diag(j);
        } else {
          int pos = j * T - (j + 1) * j / 2 + t - 1 - j;
          Lk(t, j) = lam_lower(pos);
        }
      }
    }
    Lambda_tier[k] = Lk;
  }
  // Reported for back-compatibility: tier 0 IS the ordinary latent tier, so
  // these keep their pre-Stage-6 meaning exactly.
  matrix<Type> Lambda = Lambda_tier[0];
  matrix<Type> Sigma_B = Lambda * Lambda.transpose();
  vector<Type> sd_tier = exp(log_sd_tier);

  // Materialise each unit Cholesky only as a q x q work matrix. S is never
  // inverted and its determinant is never formed. Flattened L/S reports are
  // for algebra tests and diagnostics only.
  matrix<Type> L_flat(N, q * q);
  matrix<Type> S_flat(N, q * q);
  L_flat.setZero();
  S_flat.setZero();
  // kl_by_unit keeps its pre-Stage-6 meaning: tier 0's per-level KL. The
  // tier-general quantities are kl_by_level (flat, tier-major) and
  // kl_by_tier; total_kl below is what enters the ELBO, and equals
  // sum(kl_by_level) + sum(kl_const_by_tier) = sum(kl_by_tier).
  vector<Type> kl_by_unit(N);
  vector<Type> kl_by_level(total_levels);
  vector<Type> kl_by_tier(n_tiers);
  // A structured tier's KL carries one term, 0.5*d*log_det_A, that belongs to
  // the TIER and not to any level.  It is reported separately rather than
  // smeared over levels, so kl_by_level keeps meaning "the level-decomposable
  // part" on every tier.  kl_by_tier(k) includes it; total_kl adds it once.
  vector<Type> kl_const_by_tier(n_tiers);
  kl_by_unit.setZero();
  kl_by_level.setZero();
  kl_by_tier.setZero();
  kl_const_by_tier.setZero();
  Type kl_const_total = Type(0.0);

  for (int k = 0; k < n_tiers; ++k) {
    const int d = tier_dim(k);
    const int nk = tier_n_levels(k);
    const int mo = m_offset[k];
    const int oo = off_offset[k];
    const bool structured = (tier_structured(k) == 1);

    // The quadratic form m' (I_d (x) Ainv) m, computed exactly as the Laplace
    // engine computes its prior block (src/gllvmTMB.cpp:1419-1421): one sparse
    // matrix product against the whole n x d mean matrix, O(nnz * d).  Row g of
    // the product gives level g's share of the quadratic form, which is what
    // lets the level decomposition survive a prior that couples levels.
    matrix<Type> AinvM;
    if (structured) {
      matrix<Type> Mmat(nk, d);
      for (int c = 0; c < d; ++c)
        for (int g = 0; g < nk; ++g) Mmat(g, c) = m(mo + c * nk + g);
      AinvM = Ainv_struct * Mmat;
      Type tier_const = Type(0.5) * Type(d) * log_det_A_struct;
      kl_const_by_tier(k) = tier_const;
      kl_by_tier(k) += tier_const;
      kl_const_total += tier_const;
    }

    if (tier_kind(k) == 1) {
      // Trait-diagonal tier (Design 106 Prop. 2). The variational block is
      // diag(s_1^2, ..., s_T^2), so the KL is a sum of T univariate KLs and
      // there is NOTHING off-diagonal to read. This is the whole point of the
      // second code path: the saving is structural, not a converged-to zero.
      for (int g = 0; g < nk; ++g) {
        Type kl = Type(0.0);
        if (structured) {
          // Same T univariate KLs, with the iid precision 1 replaced by
          // Ainv_gg on the trace and the quadratic form replaced by level g's
          // row of m' Ainv m.  At Ainv = I these are literally the two
          // expressions in the else-branch.
          Type qgg = diag_Ainv_struct(g);
          for (int j = 0; j < d; ++j) {
            const int pos = mo + j * nk + g;
            Type log_s = log_L_diag(pos);
            Type s = exp(log_s);
            kl += qgg * s * s + m(pos) * AinvM(g, j)
              - Type(2.0) * log_s - Type(1.0);
          }
        } else {
          for (int j = 0; j < d; ++j) {
            const int pos = mo + j * nk + g;
            Type log_s = log_L_diag(pos);
            Type s = exp(log_s);
            kl += s * s + m(pos) * m(pos) - Type(2.0) * log_s - Type(1.0);
          }
        }
        kl = Type(0.5) * kl;
        if (!std::isfinite(asDouble(kl)))
          Rf_error("gllvmTMB_va_r3: non-finite KL coordinate at tier %d level %d", k, g);
        kl_by_level(level_offset[k] + g) = kl;
        kl_by_tier(k) += kl;
      }
      continue;
    }

    for (int g = 0; g < nk; ++g) {
      matrix<Type> Li(d, d);
      Li.setZero();
      for (int c = 0; c < d; ++c)
        Li(c, c) = exp(log_L_diag(mo + c * nk + g));
      int off_pos = 0;
      for (int col = 0; col < d; ++col) {
        for (int row = col + 1; row < d; ++row) {
          Li(row, col) = L_off(oo + off_pos * nk + g);
          ++off_pos;
        }
      }

      Type trace_S = Type(0.0);
      Type mean_sq = Type(0.0);
      Type logdet_S = Type(0.0);
      for (int row = 0; row < d; ++row) {
        if (!structured)
          mean_sq += m(mo + row * nk + g) * m(mo + row * nk + g);
        logdet_S += Type(2.0) * log_L_diag(mo + row * nk + g);
        for (int col = 0; col <= row; ++col)
          trace_S += Li(row, col) * Li(row, col);
      }
      Type kl;
      if (structured) {
        Type row_quad = Type(0.0);
        for (int c = 0; c < d; ++c)
          row_quad += m(mo + c * nk + g) * AinvM(g, c);
        kl = Type(0.5) * (diag_Ainv_struct(g) * trace_S + row_quad
                          - logdet_S - Type(d));
      } else {
        kl = Type(0.5) * (trace_S + mean_sq - logdet_S - Type(d));
      }
      if (!std::isfinite(asDouble(kl)))
        Rf_error("gllvmTMB_va_r3: non-finite KL coordinate at tier %d level %d", k, g);
      kl_by_level(level_offset[k] + g) = kl;
      kl_by_tier(k) += kl;
      if (k == 0) {
        kl_by_unit(g) = kl;
        matrix<Type> Si = Li * Li.transpose();
        for (int row = 0; row < d; ++row) {
          for (int col = 0; col < d; ++col) {
            L_flat(g, row * d + col) = Li(row, col);
            S_flat(g, row * d + col) = Si(row, col);
          }
        }
      }
    }
  }

  vector<Type> expected_loglik_by_unit(N);
  vector<Type> expected_loglik_by_obs(n_obs);
  vector<Type> softplus_expectation_by_obs(n_obs);
  vector<Type> mu_by_obs(n_obs);
  vector<Type> v_by_obs(n_obs);
  expected_loglik_by_unit.setZero();
  expected_loglik_by_obs.setZero();
  softplus_expectation_by_obs.setZero();
  mu_by_obs.setZero();
  v_by_obs.setZero();

  const Type log_two_pi = log(Type(2.0) *
    Type(3.141592653589793238462643383279502884));
  const Type sqrt_pi = sqrt(Type(3.141592653589793238462643383279502884));

  for (int r = 0; r < n_obs; ++r) {
    int i = unit_id(r);
    int t = trait_id(r);
    int fam = family(r);
    int lid = link_id(r);

    Type mu = Type(0.0);
    for (int p = 0; p < X.cols(); ++p)
      mu += X(r, p) * beta(p);

    // Design 106 Proposition 1: mu and v ACCUMULATE over tiers. Means add and
    // variances add because the tiers are uncorrelated under q; there is no
    // cross term to carry and no new algebra of any kind.
    Type v = Type(0.0);
    for (int k = 0; k < n_tiers; ++k) {
      const int d = tier_dim(k);
      const int nk = tier_n_levels(k);
      const int mo = m_offset[k];
      const int oo = off_offset[k];
      const int g = level_id(r, k);

      if (tier_kind(k) == 1) {
        // a_{k,o} = sd_{k,t} e_t: the observation touches ONE coordinate, so
        // both mu and v read a single scalar. No d_k-length inner product,
        // and no off-diagonal Cholesky to project through.
        Type sd = sd_tier(sd_offset[k] + t);
        const int pos = mo + t * nk + g;
        mu += sd * m(pos);
        Type projected = sd * exp(log_L_diag(pos));
        v += projected * projected;
        continue;
      }

      const matrix<Type> &Lam = Lambda_tier[k];
      for (int c = 0; c < d; ++c)
        mu += Lam(t, c) * m(mo + c * nk + g);

      // v contribution = ||L_{k,g}' a_{k,o}||^2, without forming S.
      for (int col = 0; col < d; ++col) {
        Type projected = Type(0.0);
        projected += exp(log_L_diag(mo + col * nk + g)) * Lam(t, col);
        int off_pos = 0;
        for (int prior_col = 0; prior_col < col; ++prior_col)
          off_pos += d - prior_col - 1;
        for (int row = col + 1; row < d; ++row) {
          projected += L_off(oo + (off_pos + row - col - 1) * nk + g) *
            Lam(t, row);
        }
        v += projected * projected;
      }
    }
    if (!std::isfinite(asDouble(mu)))
      Rf_error("gllvmTMB_va_r3: non-finite mu coordinate at unit %d trait %d", i, t);
    if (!std::isfinite(asDouble(v)))
      Rf_error("gllvmTMB_va_r3: non-finite variance projection at unit %d trait %d", i, t);

    mu_by_obs(r) = mu;
    v_by_obs(r) = v;

    // Design 107: never evaluate a family density on a masked sentinel row.
    if (is_y_observed(r) == 0) {
      expected_loglik_by_obs(r) = Type(0.0);
      continue;
    }

    Type ell = Type(0.0);
    if (fam == 0) {
      // Design 108 Stage 2: per-trait estimated residual SD.
      Type sigma = exp(log_sigma(t));
      Type gaussian_var = sigma * sigma;
      Type residual = y(r) - mu;
      ell = -Type(0.5) *
        (log_two_pi + Type(2.0) * log_sigma(t)
         + (residual * residual + v) / gaussian_var);
    } else if (fam == 1) {
      Type n = n_trials(r);
      Type log_choose = lgamma(n + Type(1.0))
        - lgamma(y(r) + Type(1.0))
        - lgamma(n - y(r) + Type(1.0));
      if (lid == 0) {
        // Logistic link. JJ remains an explicit alternative; GH is the common
        // Design-110 evaluator.
        Type softplus_expectation = (eval_method == 1)
          ? va_r3_jj_softplus_expectation(mu, v)
          : va_r3_softplus_expectation(mu, v, gh_nodes, gh_weights);
        softplus_expectation_by_obs(r) = softplus_expectation;
        ell = log_choose + y(r) * mu - n * softplus_expectation;
      } else if (lid == 1) {
        Type probit_expectation;
        if (eval_method == 2) {
          probit_expectation = va_r3_probit_ac_expectation(mu, v, y(r), n);
        } else if (eval_method == 3) {
          probit_expectation = va_r3_probit_ac2_expectation(
            mu, v, y(r), n, gh_nodes, gh_weights, Type(ac2_threshold));
        } else {
          probit_expectation = va_r3_probit_expectation(
            mu, v, y(r), n, gh_nodes, gh_weights, Type(1e-6));
        }
        ell = log_choose + probit_expectation;
      } else {
        // cloglog: default GH; PoisG (eval_method == 4) is the gllvm-matched
        // truncated-Poisson closed form (opt-in; auto stays GH).
        if (eval_method == 4) {
          ell = log_choose +
            va_r3_cloglog_poisg_expectation(mu, v, y(r), n);
        } else {
          // Failure term is exact because log(1-p)=-exp(eta);
          // only the success log-probability needs GH.
          Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
          Type scale = sqrt(Type(2.0) * safe_v);
          Type success = Type(0.0);
          for (int h = 0; h < gh_nodes.size(); ++h)
            success += gh_weights(h) * va_r3_cloglog_logp(mu + scale * gh_nodes(h));
          success /= sqrt_pi;
          ell = log_choose + y(r) * success
            - (n - y(r)) * exp(mu + v / Type(2.0));
        }
      }
    } else if (fam == 2) {
      // Poisson-log: E[exp(eta)] for eta ~ N(mu, v) is exact (log-normal
      // mean), so no quadrature is required.
      ell = y(r) * mu - exp(mu + v / Type(2.0)) - lgamma(y(r) + Type(1.0));
    } else if (fam == 3) {
      // Lognormal-log is Gaussian on log(y), with the Jacobian retained.
      Type sigma = exp(log_sigma_lognormal(t));
      Type z = log(y(r)) - mu;
      ell = -Type(0.5) * (log_two_pi + Type(2.0) * log_sigma_lognormal(t)
        + (z * z + v) / (sigma * sigma)) - log(y(r));
    } else if (fam == 4) {
      // Gamma-log, mean-shape parameterisation.  Polynomial-plus-exp(-eta)
      // gives an exact normal expectation.
      Type log_shape = log_phi_gamma(t);
      Type shape = exp(log_shape);
      ell = shape * log_shape - lgamma(shape)
        + (shape - Type(1.0)) * log(y(r)) - shape * mu
        - shape * y(r) * exp(-mu + v / Type(2.0));
    } else if (fam == 5) {
      // nbinom2-log: log p(y|eta) = lgamma(y+phi) - lgamma(phi) - lgamma(y+1)
      //   + phi*log(phi) - (y+phi)*log(phi + exp(eta)) + y*eta
      // The only hard term is E[log(phi + exp(eta))]. Since
      //   log(phi + exp(eta)) = log(phi) + softplus(eta - log(phi)),
      // E[log(phi + exp(eta))] = log(phi) + E[softplus(eta - log(phi))],
      // which is exactly the existing softplus-expectation helper evaluated
      // at a shifted mean -- no new quadrature machinery. Collecting terms
      // (phi*log(phi) - (y+phi)*log(phi) = -y*log(phi)):
      //   E[log p] = lgamma(y+phi) - lgamma(phi) - lgamma(y+1) - y*log(phi)
      //              + y*mu - (y+phi) * E[softplus(mu - log(phi), v)]
      Type log_phi_t = log_phi_nbinom2(t);
      Type phi = exp(log_phi_t);
      Type softplus_expectation = va_r3_softplus_expectation(
        mu - log_phi_t, v, gh_nodes, gh_weights);
      softplus_expectation_by_obs(r) = softplus_expectation;
      ell = lgamma(y(r) + phi) - lgamma(phi) - lgamma(y(r) + Type(1.0))
        - y(r) * log_phi_t + y(r) * mu
        - (y(r) + phi) * softplus_expectation;
    } else if (fam == 6) {
      Type phi = exp(log_phi_tweedie(t));
      Type power = Type(1.0) + va_r3_invlogit(logit_p_tweedie(t));
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        ell += gh_weights(h) * dtweedie(y(r), exp(eta_h), phi, power, true);
      }
      ell /= sqrt_pi;
    } else if (fam == 7) {
      Type phi = exp(log_phi_beta(t));
      Type log_y = log(y(r));
      Type log_1my = log(Type(1.0) - y(r));
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        // Construct both shapes from stable log probabilities. Computing
        // 1-invlogit(eta) loses all precision in the right tail; clamping the
        // probability avoids that NaN but changes the statistical model.
        Type log_p = -va_r3_softplus(-eta_h);
        Type log_1mp = -va_r3_softplus(eta_h);
        Type a = phi * exp(log_p);
        Type b = phi * exp(log_1mp);
        Type node = lgamma(phi) - lgamma(a) - lgamma(b)
          + (a - Type(1.0)) * log_y + (b - Type(1.0)) * log_1my;
        ell += gh_weights(h) * node;
      }
      ell /= sqrt_pi;
    } else if (fam == 8) {
      Type phi = exp(log_phi_betabinom(t));
      Type n = n_trials(r);
      Type yy = y(r);
      Type constant = lgamma(n + Type(1.0)) - lgamma(yy + Type(1.0))
        - lgamma(n - yy + Type(1.0)) + lgamma(phi);
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        Type log_p = -va_r3_softplus(-eta_h);
        Type log_1mp = -va_r3_softplus(eta_h);
        Type a = phi * exp(log_p);
        Type b = phi * exp(log_1mp);
        Type node = constant + lgamma(yy + a) + lgamma(n - yy + b)
          - lgamma(a) - lgamma(b) - lgamma(n + phi);
        ell += gh_weights(h) * node;
      }
      ell /= sqrt_pi;
    } else if (fam == 9) {
      Type sigma = exp(log_sigma_student(t));
      Type df = Type(1.0) + exp(log_df_student(t));
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        ell += gh_weights(h) * (dt((y(r) - eta_h) / sigma, df, true)
                                  - log_sigma_student(t));
      }
      ell /= sqrt_pi;
    } else if (fam == 10) {
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        Type lambda = exp(eta_h);
        Type node = y(r) * eta_h - lambda - lgamma(y(r) + Type(1.0))
          - va_r3_log1mexp(-lambda);
        ell += gh_weights(h) * node;
      }
      ell /= sqrt_pi;
    } else if (fam == 11) {
      Type log_phi = log_phi_truncnb2(t);
      Type phi = exp(log_phi);
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        Type sp = va_r3_softplus(eta_h - log_phi);
        Type base = lgamma(y(r) + phi) - lgamma(phi) - lgamma(y(r) + Type(1.0))
          - y(r) * log_phi + y(r) * eta_h - (y(r) + phi) * sp;
        Type log_p0 = -phi * sp;
        ell += gh_weights(h) * (base - va_r3_log1mexp(log_p0));
      }
      ell /= sqrt_pi;
    } else if (fam == 12) {
      Type present = CppAD::CondExpGt(y(r), Type(0.0), Type(1.0), Type(0.0));
      Type sp = va_r3_softplus_expectation(mu, v, gh_nodes, gh_weights);
      ell = present * mu - sp;
      if (asDouble(y(r)) > 0.0) {
        Type sigma = exp(log_sigma_lognormal_delta(t));
        Type z = log(y(r)) - mu;
        ell += -Type(0.5) * (log_two_pi + Type(2.0) * log_sigma_lognormal_delta(t)
          + (z * z + v) / (sigma * sigma)) - log(y(r));
      }
    } else if (fam == 13) {
      Type present = CppAD::CondExpGt(y(r), Type(0.0), Type(1.0), Type(0.0));
      Type sp = va_r3_softplus_expectation(mu, v, gh_nodes, gh_weights);
      ell = present * mu - sp;
      if (asDouble(y(r)) > 0.0) {
        Type phi = exp(log_phi_gamma_delta(t));
        Type shape = Type(1.0) / (phi * phi);
        ell += shape * log(shape) - lgamma(shape)
          + (shape - Type(1.0)) * log(y(r)) - shape * mu
          - shape * y(r) * exp(-mu + v / Type(2.0));
      }
    } else if (fam == 14) {
      int K = n_ordinal_cuts_per_trait(t) + 2;
      int offset = ordinal_offset_per_trait(t);
      vector<Type> cuts(K - 1);
      cuts(0) = Type(0.0);
      for (int j = 1; j < K - 1; ++j)
        cuts(j) = cuts(j - 1) + exp(ordinal_log_increments(offset + j - 1));
      int yk = CppAD::Integer(y(r));
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        Type node;
        if (yk <= 1) node = va_r3_log_pnorm(cuts(0) - eta_h);
        else if (yk >= K) node = va_r3_log_pnorm(eta_h - cuts(K - 2));
        else node = va_r3_log_pnorm_diff(cuts(yk - 1) - eta_h,
                                         cuts(yk - 2) - eta_h);
        ell += gh_weights(h) * node;
      }
      ell /= sqrt_pi;
    } else {
      // fam == 15: TMB's robust NB kernel avoids the large-size cancellation
      // in the equivalent lgamma ratio.  var-mu = phi*mu on the NB1 route.
      Type safe_v = CppAD::CondExpGt(v, Type(1e-12), v, Type(1e-12));
      Type scale = sqrt(Type(2.0) * safe_v);
      for (int h = 0; h < gh_nodes.size(); ++h) {
        Type eta_h = mu + scale * gh_nodes(h);
        ell += gh_weights(h) * dnbinom_robust(
          y(r), eta_h, eta_h + log_phi_nbinom1(t), true);
      }
      ell /= sqrt_pi;
    }
    if (!std::isfinite(asDouble(ell)))
      Rf_error("gllvmTMB_va_r3: non-finite expected log-likelihood at unit %d trait %d", i, t);

    expected_loglik_by_obs(r) = ell;
    expected_loglik_by_unit(i) += ell;
  }

  Type expected_loglik = expected_loglik_by_unit.sum();
  // kl_const_total is EXACTLY zero when no tier is structured, so this adds
  // 0.0 on the pre-Stage-7 path and the Stage 6 byte-identity is preserved.
  Type total_kl = kl_by_level.sum() + kl_const_total;
  Type elbo = expected_loglik - total_kl;
  Type negative_elbo = -elbo;
  if (!std::isfinite(asDouble(negative_elbo)))
    error("gllvmTMB_va_r3: non-finite negative ELBO");

  REPORT(eval_method);
  REPORT(is_y_observed);
  REPORT(family);
  REPORT(link_id);
  REPORT(log_sigma);
  REPORT(Lambda);
  REPORT(Sigma_B);
  // `m` keeps its pre-Stage-6 REPORT shape -- tier 0's N x q variational
  // means -- because readers downstream index it as a matrix. REPORT() keys
  // on the token name, so the matrix is bound to a shadowing local inside its
  // own block; the flat, tier-major block is reported alongside as m_flat.
  vector<Type> m_flat = m;
  REPORT(m_flat);
  {
    matrix<Type> m(N, q);
    for (int g = 0; g < N; ++g)
      for (int c = 0; c < q; ++c)
        m(g, c) = m_flat(m_offset[0] + c * N + g);
    REPORT(m);
  }
  REPORT(L_flat);
  REPORT(S_flat);
  REPORT(mu_by_obs);
  REPORT(v_by_obs);
  REPORT(expected_loglik_by_obs);
  REPORT(softplus_expectation_by_obs);
  REPORT(expected_loglik_by_unit);
  REPORT(kl_by_unit);
  REPORT(kl_by_level);
  REPORT(kl_by_tier);
  REPORT(kl_const_by_tier);
  REPORT(tier_structured);
  REPORT(n_tiers);
  REPORT(tier_kind);
  REPORT(tier_dim);
  REPORT(tier_n_levels);
  REPORT(sd_tier);
  REPORT(expected_loglik);
  REPORT(total_kl);
  REPORT(elbo);
  REPORT(negative_elbo);

  return negative_elbo;
}
