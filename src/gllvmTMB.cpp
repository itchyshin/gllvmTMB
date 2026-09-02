// gllvmTMB_multi.cpp -- TMB template for the multivariate (stacked-trait,
// long-format) model. Companion to src/gllvmTMB.cpp (single-response sdmTMB
// engine). Implements the Nakagawa et al. (in prep) functional-biogeography
// GLLVM with a glmmTMB-style covariance dispatch (rr / diag / propto /
// equalto) and an sdmTMB-style spde() spatial term.
//
// Stage 2 (this version) supports:
//   * trait-specific fixed effects via X_fix
//   * rr(0+trait | site, d = d_B) (between-site reduced-rank: u_st = Lambda_B * z_B)
//   * diag(0+trait | site) (between-site trait-specific specific variance: s_st_B)
//   * rr(0+trait | site_species, d = d_W) (within-site reduced-rank: e_sit = Lambda_W * z_W)
//   * diag(0+trait | site_species) (within-site specific variance: s_sit_W)
//   * Gaussian observation likelihood
// Each of the four covstruct terms can be toggled on/off independently via
// the use_* flags.
//
// Reduced-rank covariance terms use the standard identified factor-loading
// layout: theta stores the rank diagonal entries first, followed by the
// strict lower triangle column-by-column.  The unpacking implementation below
// is independently written for gllvmTMB and shared by every covariance tier.
//
// Stages 3-5 will add propto/equalto and the spde() term inside this same
// template; the layout of DATA / PARAMETER macros is designed to be
// extensible.

#define TMB_LIB_INIT R_init_gllvmTMB
#include "lane_b_jeffreys_maxvol_atomic_v8.h"
#include "../inst/include/gllvmTMB/detail/column_prior.hpp"

// Independently implemented standard lower-triangular factor-loading unpack.
// Keeping one cursor-based implementation prevents the packing convention
// from drifting across ordinary, phylogenetic, kernel, and spatial tiers.
template <class Type>
matrix<Type> gll_unpack_rr_loadings(const vector<Type>& theta,
                                    int n_rows,
                                    int rank)
{
  if (n_rows < 1)
    error("gllvmTMB_multi: loading matrix must have at least one row");
  if (rank < 1 || rank > n_rows)
    error("gllvmTMB_multi: loading rank must be between 1 and the number of rows");

  const int expected = n_rows * rank - rank * (rank - 1) / 2;
  if (theta.size() != expected)
    error("gllvmTMB_multi: packed loading vector has wrong length");

  matrix<Type> loading(n_rows, rank);
  loading.setZero();

  int cursor = 0;
  for (int column = 0; column < rank; ++column)
    loading(column, column) = theta(cursor++);
  for (int column = 0; column < rank; ++column)
    for (int row = column + 1; row < n_rows; ++row)
      loading(row, column) = theta(cursor++);

  if (cursor != theta.size())
    error("gllvmTMB_multi: packed loading vector was not exhausted exactly");
  return loading;
}

// Stable log helpers for the cumulative-logit ordered missing-PREDICTOR prior
// (Phase 5b, design 68 sec.1.2). Ported verbatim from drmTMB src/drm_numeric.h
// (drm_log_inv_logit / drm_log1m_inv_logit / drm_log1mexp / drm_log_inv_logit_
// diff) so the finite-state SUM math is byte-identical across packages (the
// cross-package contract, design 68 sec.7.5). gllvmTMB already has logspace_add
// but lacks the named log_inv_logit helpers.
template <class Type>
Type gll_log_inv_logit(Type eta)
{
  // log F(eta) = log( 1 / (1 + exp(-eta)) ) = -log(1 + exp(-eta)).
  return -logspace_add(Type(0.0), -eta);
}

template <class Type>
Type gll_log1m_inv_logit(Type eta)
{
  // log(1 - F(eta)) = -log(1 + exp(eta)).
  return -logspace_add(Type(0.0), eta);
}

template <class Type>
Type gll_log1mexp(Type log_p)
{
  // log(1 - exp(log_p)) for log_p <= 0, with a small-argument series guard
  // (drm_log1mexp). u = -log_p >= 0; for tiny u use the Taylor series.
  //
  // AD-SAFETY CEILING ON THE INPUT. CppAD::CondExp evaluates BOTH branches, so
  // both must be finite at every reachable argument even when only one is
  // selected. At log_p = 0 neither is: series_arg is 0 so log(0) = -Inf, and
  // 1 - exp(0) is 0 so log(0) = -Inf again. A non-finite value on an UNSELECTED
  // branch leaves fn() and gr() finite AND CORRECT while making he() return
  // NaN -- the failure mode measured and documented at
  // inst/tmb/gllvmTMB_va_r3.cpp:154-180, and invisible to any gradient check.
  //
  // log_p = 0 is REACHABLE, not hypothetical. gll_log_pnorm's direct branch is
  // log(pnorm(x)), and pnorm(x) rounds to EXACTLY 1.0 for x > 8.2924 (measured),
  // so in gll_log_pnorm_diff the two log-probabilities become bit-identical and
  // their difference is exactly 0 whenever both cutpoints sit more than ~8.3
  // from eta on the same side -- a rare extreme ordinal category under a
  // moderately large eta, on the shipped Laplace ordinal_probit path (fid 14).
  //
  // The ceiling sits at the double unit roundoff, and that MAGNITUDE IS LOAD
  // BEARING: a -1e-300 or -1e-20 floor rescues the SERIES branch but leaves the
  // DIRECT branch computing log(1 - exp(-1e-300)) = log(0) = -Inf, because
  // exp(tiny) rounds back to exactly 1. At -1.2e-16, 1 - exp(ac) is 1.11e-16
  // rather than 0, so BOTH branches are finite (series -36.659, direct -36.737).
  // Clamp the INPUT, never the output -- the discipline at va_r3:154-180.
  //
  // The cubic u - u^2/2 + u^3/6 has derivative ((u-1)^2 + 1)/2 > 0, so it is
  // strictly increasing from 0 and strictly positive for every u > 0: once u is
  // floored away from 0 the series branch is finite at any argument.
  //
  // Where the clamp binds, CondExp returns a constant, so the propagated partial
  // is exactly 0 and no spurious gradient is manufactured. Where it does not
  // bind -- log_p <= -1.2e-16, i.e. every ordinary argument -- the value is
  // bit-identical to the previous implementation (verified at log_p = -0.5,
  // -1e-3, -1e-7, -1e-12).
  //
  // Semantics where it binds: a cell probability that has underflowed to zero in
  // THIS parameterisation is treated as ~1.1e-16 rather than as impossible. The
  // true probability there is tiny but positive -- Phi(-8.5) - Phi(-9) is a real
  // number -- so this recovers a finite approximation rather than inventing one.
  // A genuinely zero-width category now returns a large finite negative instead
  // of -Inf; that is a model-specification error either way, and -Inf makes the
  // entire objective non-finite rather than diagnosing it.
  Type ceil_a = Type(-1.2e-16);
  Type ac = CppAD::CondExpGt(log_p, ceil_a, ceil_a, log_p);   // min(log_p, ceil)
  Type u = -ac;
  Type series_arg = u - u * u / Type(2.0) + u * u * u / Type(6.0);
  Type series = log(series_arg);
  Type direct = log(Type(1.0) - exp(ac));
  return CppAD::CondExpLt(u, Type(1e-6), series, direct);
}

template <class Type>
Type gll_clamp(Type x, Type lower, Type upper)
{
  x = CppAD::CondExpLt(x, lower, lower, x);
  x = CppAD::CondExpGt(x, upper, upper, x);
  return x;
}

#include "gllvmTMB_cloglog.h"

template <class Type>
Type gll_log_pnorm(Type x)
{
  // log Phi(x), stable in the far LEFT tail. For x >= -20 the direct
  // log(pnorm(x)) is used (pnorm(-20) = 2.8e-89, so there is ~200 orders of
  // headroom before underflow). Below that we use the Mills-ratio asymptotic
  // expansion (Abramowitz & Stegun 26.2.12)
  //   log Phi(x) = -x^2/2 - log(-x) - log(sqrt(2 pi))
  //                + log(1 - 1/x^2 + 3/x^4 - 15/x^6 + 105/x^8)
  // which is accurate to 9e-11 in log-probability at the -20 switch point
  // (checked against R's pnorm(log.p = TRUE)) and is what keeps the density
  // finite past x ~ -37.5, where pnorm underflows to 0 and log() gives -Inf.
  //
  // CppAD::CondExp evaluates BOTH branches, so each branch is fed a CLAMPED
  // argument that keeps it finite on the side where it is not selected.
  //
  // Why this matters: the ordinal_probit cell probability used to be floored
  // at 1e-12, which is harmless under Laplace (eta sits at the conditional
  // mode) but BINDS at outer quadrature nodes, where eta is deliberately
  // pushed several conditional SDs into the tail. A hard floor turns the
  // tail into a constant and kills the node's gradient; this formulation
  // lets the tail decay instead.
  Type cut = Type(-20.0);
  Type xa   = CppAD::CondExpLt(x, cut, x, cut);        // min(x, -20)
  Type inv2 = Type(1.0) / (xa * xa);
  Type series = Type(1.0) - inv2 * (Type(1.0) - Type(3.0) * inv2 *
                (Type(1.0) - Type(5.0) * inv2 *
                (Type(1.0) - Type(7.0) * inv2)));
  Type tail = -Type(0.5) * xa * xa - log(-xa) -
              Type(0.5) * log(Type(2.0) * M_PI) + log(series);
  Type xd = CppAD::CondExpLt(x, cut, cut, x);          // max(x, -20)
  Type direct = log(pnorm(xd));
  return CppAD::CondExpLt(x, cut, tail, direct);
}

template <class Type>
Type gll_log_pnorm_diff(Type a, Type b)
{
  // log( Phi(a) - Phi(b) ) for a > b, stable in BOTH tails.
  //   left  form (a, b both left of centre): logPhi(a) + log1mexp(logPhi(b) - logPhi(a))
  //   right form (a, b both right of centre): by symmetry Phi(a) - Phi(b)
  //     = Phi(-b) - Phi(-a), with -b > -a both left of centre.
  // Pick by the sign of a + b so the selected form always evaluates the
  // SMALLER of the two probabilities as the leading term. Both arguments of
  // gll_log1mexp are <= 0 by construction (a > b), on either branch.
  Type la  = gll_log_pnorm(a);
  Type lb  = gll_log_pnorm(b);
  Type lna = gll_log_pnorm(-a);
  Type lnb = gll_log_pnorm(-b);
  Type left  = la  + gll_log1mexp(lb  - la);
  Type right = lnb + gll_log1mexp(lna - lnb);
  return CppAD::CondExpLe(a + b, Type(0.0), left, right);
}

// Expected-information log weights for the fixed-only Bernoulli Jeffreys
// component.  These are evaluated at X_fix * b_fix + offset, before any
// latent-score contribution.  No probability or information floor is used.
template <class Type>
Type gll_mspl_log_weight(Type eta, int link_id)
{
  if (link_id == 0) {
    Type log_p1 = -logspace_add(Type(0.0), -eta);
    Type log_p0 = -logspace_add(Type(0.0),  eta);
    return log_p1 + log_p0;
  }
  if (link_id == 1) {
    Type log_p1 = gll_log_pnorm( eta);
    Type log_p0 = gll_log_pnorm(-eta);
    return Type(2.0) * (-Type(0.5) * eta * eta -
      Type(0.5) * log(Type(2.0) * M_PI)) - log_p1 - log_p0;
  }
  if (link_id == 2) {
    // w(eta) = exp(2 eta) / expm1(exp(eta)).  The small-a series retains
    // eta when exp(eta) is close to underflow; the direct branch never forms
    // exp(exp(eta)).  CppAD evaluates both branches, so each receives a safe
    // eta. Beyond eta=690 the real exp(eta) term approaches the representable
    // double boundary. Continue with a finite, strictly decreasing C1-matched
    // logarithmic tail; a separate report counts every row that touches it.
    Type cut = Type(log(1e-4));
    Type eta_small = CppAD::CondExpGt(eta, cut, cut, eta);
    Type a_small = exp(eta_small);
    Type a2 = a_small * a_small;
    Type small_ratio = Type(1.0) + a_small / Type(2.0) +
      a2 / Type(6.0) + a2 * a_small / Type(24.0) +
      a2 * a2 / Type(120.0);
    Type small_log_denom = eta + log(small_ratio);

    Type hi = Type(690.0);
    Type eta_direct = CppAD::CondExpLt(eta, cut, cut, eta);
    eta_direct = CppAD::CondExpGt(eta_direct, hi, hi, eta_direct);
    Type a_direct = exp(eta_direct);
    Type direct_log_denom = a_direct + log(Type(1.0) - exp(-a_direct));
    Type log_denom = CppAD::CondExpLt(eta, cut,
                                      small_log_denom, direct_log_denom);
    Type regular = Type(2.0) * eta - log_denom;

    Type a_hi = exp(hi);
    Type regular_hi = Type(2.0) * hi - a_hi -
      log(Type(1.0) - exp(-a_hi));
    Type delta = CppAD::CondExpGt(eta, hi, eta - hi, Type(0.0));
    Type tail = regular_hi - (a_hi - Type(2.0)) *
      log(Type(1.0) + delta);
    return CppAD::CondExpGt(eta, hi, tail, regular);
  }
  error("gllvmTMB_multi: MSPL supports only logit, probit, and cloglog links");
  return Type(0.0);
}

// AD-safe digamma / trigamma via recurrence + asymptotic. Used only for
// the fenced NB1 / Beta GLM-outer atoms. Not Laplace-marginal I(beta).
template <class Type>
Type gll_mspl_digamma(Type x)
{
  Type acc = Type(0.0);
  Type z = x;
  for (int i = 0; i < 8; ++i) {
    acc -= Type(1.0) / z;
    z += Type(1.0);
  }
  Type iz = Type(1.0) / z;
  Type iz2 = iz * iz;
  return acc + log(z) - Type(0.5) * iz - iz2 / Type(12.0) +
    iz2 * iz2 / Type(120.0);
}

template <class Type>
Type gll_mspl_trigamma(Type x)
{
  Type acc = Type(0.0);
  Type z = x;
  for (int i = 0; i < 8; ++i) {
    acc += Type(1.0) / (z * z);
    z += Type(1.0);
  }
  Type iz = Type(1.0) / z;
  Type iz2 = iz * iz;
  return acc + iz + Type(0.5) * iz2 + iz2 * iz / Type(6.0);
}

// GLM-outer log weight at eta = X_fix * b_fix + offset, before any
// latent-score contribution. This is the candidate outer penalty weight,
// NOT Laplace-marginal I(beta).
template <class Type>
Type gll_mspl_log_weight_glm(Type eta, int family_id, int link_id,
                             Type log_phi, Type logit_p)
{
  if (family_id == 1)
    return gll_mspl_log_weight(eta, link_id);
  if (family_id == 2) {
    // True Poisson W = mu (log w = eta) is one-sided (0 / +Inf) and
    // rewards intercept runaway under soft Jeffreys (#1064 W2).
    // Live tape uses working logistic W_* = mu_*(1-mu_*) on eta
    // (Tweedie family_id==6 precedent; 2023 P^(f) existence device).
    // Not true-model Jeffreys. G0 SIGNED REPLACE 2026-08-17 (#1102).
    return gll_mspl_log_weight(eta, 0);
  }
  if (family_id == 5) {
    // NB2: W = mu * phi / (phi + mu)
    Type log_mu = eta;
    return log_mu + log_phi - logspace_add(log_mu, log_phi);
  }
  if (family_id == 15) {
    // NB1: PMF-summed exact I_eta at fixed phi via truncated PMF outer product.
    // NOT quasi W=mu/(1+phi).
    Type mu = exp(eta);
    Type phi = exp(log_phi);
    Type r = mu / phi;
    Type log_p = -logspace_add(Type(0.0), log_phi);
    Type sd = sqrt(mu * (Type(1.0) + phi));
    int ymax = 80;
    double cap = asDouble(mu + Type(12.0) * sd);
    if (R_FINITE(cap) && cap < 80.0)
      ymax = (cap < 8.0) ? 8 : (int)cap;
    Type I = Type(0.0);
    for (int y = 0; y <= ymax; ++y) {
      Type yy = Type(y);
      Type log_f = lgamma(yy + r) - lgamma(r) - lgamma(yy + Type(1.0)) +
        r * log_p + yy * (log_phi + log_p);
      Type s = r * (gll_mspl_digamma(yy + r) - gll_mspl_digamma(r) + log_p);
      I += exp(log_f) * s * s;
    }
    return log(I + Type(1e-12));
  }
  if (family_id == 7) {
    // Ferrari & Cribari-Neto (2004) K_ββ = φ X' W X with
    //   w_t = φ {ψ'(a)+ψ'(b)} / {g'(μ)}^2, a=μφ, b=(1-μ)φ.
    // Logit: g'(μ)=1/(μ(1-μ)), so the GLM-outer diagonal is
    //   w = φ² {μ(1-μ)}² {ψ'(a)+ψ'(b)}.
    // The previous one-φ form was FCN's inner W, not K_ββ; at the
    // default log_phi_beta=1 (φ=e) that mis-scale sent the maxvol
    // atom down the MP path (V8 status 1 = OK_MP_CERTIFIED), which
    // R then treated as invalid. As μ→0/1, w→1: not coercive.
    Type log_mu = -logspace_add(Type(0.0), -eta);
    Type log_ommu = -logspace_add(Type(0.0), eta);
    Type a = exp(log_mu + log_phi);
    Type b = exp(log_ommu + log_phi);
    Type a_floor = Type(1e-8);
    a = CppAD::CondExpGt(a, a_floor, a, a_floor);
    b = CppAD::CondExpGt(b, a_floor, b, a_floor);
    Type trig = gll_mspl_trigamma(a) + gll_mspl_trigamma(b);
    return Type(2.0) * log_phi + Type(2.0) * (log_mu + log_ommu) +
      log(trig + Type(1e-12));
  }
  if (family_id == 6) {
    // True Tweedie W = mu^{2-p}/phi fails the two-sided vanishing
    // test (0 / +inf) and rewards phi -> 0. That chase hung the
    // #999 8x3 live cell (>5 min) while Tweedie ML on the same
    // cell returned in ~1.3 s. Live tape uses working logistic
    // W_* = mu_*(1-mu_*) on eta (2023 P^(f)); existence device,
    // not true-model Jeffreys. log_phi / logit_p enter Huber, not
    // this weight. Not admitted.
    return gll_mspl_log_weight(eta, 0);
  }
  error("gllvmTMB_multi: MSPL GLM-outer weight: unknown family_id");
  return Type(0.0);
}

template <class Type>
Type gll_mspl_bernoulli_loglik(Type y, Type eta, int link_id)
{
  Type log_p1;
  Type log_p0;
  if (link_id == 0) {
    log_p1 = -logspace_add(Type(0.0), -eta);
    log_p0 = -logspace_add(Type(0.0),  eta);
  } else if (link_id == 1) {
    log_p1 = gll_log_pnorm( eta);
    log_p0 = gll_log_pnorm(-eta);
  } else if (link_id == 2) {
    Type cut = Type(log(1e-4));
    Type eta_small = CppAD::CondExpGt(eta, cut, cut, eta);
    Type a_small = exp(eta_small);
    Type a2 = a_small * a_small;
    Type p1_ratio = Type(1.0) - a_small / Type(2.0) +
      a2 / Type(6.0) - a2 * a_small / Type(24.0) +
      a2 * a2 / Type(120.0);
    Type p1_small = eta + log(p1_ratio);

    Type hi = Type(690.0);
    Type eta_direct = CppAD::CondExpLt(eta, cut, cut, eta);
    eta_direct = CppAD::CondExpGt(eta_direct, hi, hi, eta_direct);
    Type a_direct = exp(eta_direct);
    Type p1_direct = log(Type(1.0) - exp(-a_direct));
    Type p1_regular = CppAD::CondExpLt(eta, cut, p1_small, p1_direct);
    log_p1 = CppAD::CondExpGt(eta, hi, Type(0.0), p1_regular);

    Type a_hi = exp(hi);
    Type delta = CppAD::CondExpGt(eta, hi, eta - hi, Type(0.0));
    Type p0_tail = -a_hi - a_hi * log(Type(1.0) + delta);
    Type p0_regular = -exp(eta_direct);
    log_p0 = CppAD::CondExpGt(eta, hi, p0_tail, p0_regular);
  } else {
    error("gllvmTMB_multi: MSPL supports only logit, probit, and cloglog links");
    return Type(0.0);
  }
  return y * log_p1 + (Type(1.0) - y) * log_p0;
}

// Gaussian FA Hirose atom (Sterzinger–Kosmidis–Moustaki 2026 (4.1)):
// sum_j S_jj / psi_j. Primary soft atom for Gaussian LA-MSPL Heywood.
// Do NOT reuse Bernoulli V_loading here — that atom is inert in psi.
template <class Type>
Type gll_mspl_hirose_atom(const vector<Type> &S_diag, const vector<Type> &psi)
{
  if (S_diag.size() != psi.size())
    error("gllvmTMB_multi: MSPL Hirose S_diag and psi length mismatch");
  Type ans = Type(0.0);
  for (int j = 0; j < S_diag.size(); ++j) {
    Type sjj = S_diag(j);
    Type psi_j = psi(j);
    double sjj_d = asDouble(sjj);
    double psi_d = asDouble(psi_j);
    if (!R_FINITE(sjj_d) || !(sjj_d > 0.0))
      error("gllvmTMB_multi: MSPL Hirose requires finite S_jj > 0");
    if (!R_FINITE(psi_d) || !(psi_d > 0.0))
      error("gllvmTMB_multi: MSPL Hirose requires psi_j > 0");
    ans += sjj / psi_j;
  }
  return ans;
}

template <class Type>
Type gll_mspl_row_radial_penalty(const matrix<Type> &Lambda, int rank)
{
  Type ans = Type(0.0);
  for (int t = 0; t < Lambda.rows(); ++t) {
    Type max_abs = Type(0.0);
    for (int k = 0; k < rank; ++k) {
      Type a = CppAD::CondExpGe(Lambda(t, k), Type(0.0),
                                Lambda(t, k), -Lambda(t, k));
      max_abs = CppAD::CondExpGt(a, max_abs, a, max_abs);
    }
    Type scale = CppAD::CondExpLt(max_abs, Type(1.0), Type(1.0), max_abs);
    scale = CppAD::CondExpGt(scale, Type(1e300), Type(1e300), scale);
    Type scaled_norm2 = Type(0.0);
    Type small_norm2 = Type(0.0);
    for (int k = 0; k < rank; ++k) {
      Type z = Lambda(t, k) / scale;
      scaled_norm2 += z * z;
      Type z_small = gll_clamp(Lambda(t, k), Type(-1.0), Type(1.0));
      small_norm2 += z_small * z_small;
    }
    Type small = small_norm2 /
      (sqrt(Type(1.0) + small_norm2) + Type(1.0));
    Type radius = scale * sqrt(scaled_norm2);
    Type radius_large = CppAD::CondExpLt(radius, Type(1.0), Type(1.0), radius);
    Type large = radius_large *
      sqrt(Type(1.0) + Type(1.0) / (radius_large * radius_large)) -
      Type(1.0);
    ans += CppAD::CondExpLe(max_abs, Type(1.0), small, large);
  }
  return ans;
}

// Poisson event-weighted loading atom (admit-packet science, not admission).
// V = sum_t (sqrt(1 + ||lambda_t||^2 * ybar_t) - 1). Observed trait means
// weight the radial term so all-zero traits contribute 0 (Jeffreys-on-beta
// owns that path). Do not reuse Bernoulli V_loading here.
template <class Type>
Type gll_mspl_poisson_event_radial_penalty(const matrix<Type> &Lambda,
                                           const vector<Type> &y,
                                           const vector<int> &trait_id,
                                           int rank,
                                           int n_traits)
{
  if (Lambda.rows() != n_traits)
    error("gllvmTMB_multi: Poisson loading atom Lambda rows must equal n_traits");
  if (y.size() != trait_id.size())
    error("gllvmTMB_multi: Poisson loading atom y/trait_id length mismatch");
  vector<Type> ysum(n_traits);
  vector<Type> ycount(n_traits);
  ysum.setZero();
  ycount.setZero();
  for (int o = 0; o < y.size(); ++o) {
    int t = trait_id(o);
    if (t < 0 || t >= n_traits)
      error("gllvmTMB_multi: Poisson loading atom trait_id out of range");
    ysum(t) += y(o);
    ycount(t) += Type(1.0);
  }
  Type ans = Type(0.0);
  for (int t = 0; t < n_traits; ++t) {
    Type ybar = CppAD::CondExpGt(ycount(t), Type(0.0),
                                 ysum(t) / ycount(t), Type(0.0));
    ybar = CppAD::CondExpGt(ybar, Type(0.0), ybar, Type(0.0));
    Type ss = Type(0.0);
    for (int k = 0; k < rank; ++k)
      ss += Lambda(t, k) * Lambda(t, k);
    Type inside = Type(1.0) + ss * ybar;
    ans += sqrt(inside) - Type(1.0);
  }
  return ans;
}

template <class Type>
Type gll_mspl_pseudohuber(Type x)
{
  Type ax = CppAD::CondExpGe(x, Type(0.0), x, -x);
  Type x_small = gll_clamp(x, Type(-1.0), Type(1.0));
  Type x2 = x_small * x_small;
  Type small = x2 / (sqrt(Type(1.0) + x2) + Type(1.0));
  Type ax_large = CppAD::CondExpLt(ax, Type(1.0), Type(1.0), ax);
  ax_large = CppAD::CondExpGt(ax_large, Type(1e300), Type(1e300), ax_large);
  Type large = ax_large *
    sqrt(Type(1.0) + Type(1.0) / (ax_large * ax_large)) - Type(1.0);
  return CppAD::CondExpLe(ax, Type(1.0), small, large);
}

template <class Type>
Type gll_log_inv_logit_diff(Type upper, Type lower)
{
  // log( F(upper) - F(lower) ) for upper > lower, stable form (drm_log_inv_
  // logit_diff): the log of the cumulative-logit cell probability of a middle
  // ordered category.
  //
  // This function has no CondExp of its own, but it inherits gll_log1mexp's, and
  // therefore inherited that function's unselected-branch hazard: the exposure
  // is the whole interval (-1.1e-16, 0], not just exactly 0, because for any
  // tiny-but-nonzero argument the series branch is selected while the UNSELECTED
  // direct branch computes log(1 - exp(tiny)) = log(0) = -Inf. Reachable here
  // when two adjacent cutpoints fall within ~1e-16 of each other on the eta
  // scale -- far narrower than the probit route, which reaches log_p = 0 by
  // ordinary CDF rounding above 8.2924, but the same defect and the same NaN
  // Hessian. Fixed at source by the input ceiling in gll_log1mexp; nothing is
  // needed here.
  return upper + gll_log1mexp(lower - upper) -
    logspace_add(Type(0.0), upper) -
    logspace_add(Type(0.0), lower);
}

template <class Type>
Type objective_function<Type>::operator()()
{
  using namespace density;

  // -------- DATA --------------------------------------------------------
  DATA_VECTOR(y);                  // long-format response (n_obs)
  DATA_IVECTOR(is_y_observed);     // 1 = response observed, 0 = missing (n_obs).
                                   // Phase 1 response mask: rows with 0 add
                                   // nothing to the likelihood and their y entry
                                   // is a safe sentinel (filled on the R side).
                                   // All-ones under miss_control(response="drop")
                                   // -> an exact no-op.
  DATA_VECTOR(n_trials);           // length n_obs; size argument for binomial.
                                   // For non-binomial rows the entry is unused
                                   // (set to 1.0 by R). For Bernoulli rows it
                                   // is 1.0; for binomial(k-of-n) rows it is
                                   // the trial count and y is the success count.
  DATA_MATRIX(X_fix);              // fixed-effects design matrix (n_obs x p)
  DATA_IVECTOR(trait_id);          // 0-indexed trait per row
  DATA_IVECTOR(site_id);           // 0-indexed site per row
  DATA_IVECTOR(site_species_id);   // 0-indexed site_species per row
  DATA_INTEGER(n_traits);
  DATA_INTEGER(n_sites);
  DATA_INTEGER(n_site_species);
  DATA_INTEGER(d_B);               // rank of between-site rr term (>= 1 if used)
  DATA_INTEGER(d_W);               // rank of within-site rr term  (>= 1 if used)
  DATA_INTEGER(use_rr_B);          // 1/0
  DATA_INTEGER(use_lv_B);          // 1/0 predictor-informed mean for B-tier scores
  DATA_INTEGER(n_lv_B);            // columns in X_lv_B (>= 1 stub when inactive)
  DATA_MATRIX(X_lv_B);             // n_sites x n_lv_B unit-level score-mean design
  DATA_INTEGER(use_diag_B);        // 1/0
  // Optional for saved pre-repair tapes: absence preserves the original joint
  // Gaussian calculation. New R fits set this only after the private cell gate.
  SEXP gaussian_diag_B_flag = getListElement(
    TMB_OBJECTIVE_PTR->data, "integrate_gaussian_diag_B");
  int integrate_gaussian_diag_B = 0;
  if (!Rf_isNull(gaussian_diag_B_flag)) {
    if (Rf_length(gaussian_diag_B_flag) != 1 ||
        !(Rf_isInteger(gaussian_diag_B_flag) || Rf_isReal(gaussian_diag_B_flag)))
      error("gllvmTMB_multi: integrate_gaussian_diag_B must be scalar 0 or 1");
    double flag = Rf_asReal(gaussian_diag_B_flag);
    if (flag != 0.0 && flag != 1.0)
      error("gllvmTMB_multi: integrate_gaussian_diag_B must be 0 or 1");
    integrate_gaussian_diag_B = static_cast<int>(flag);
  }
  // Per-trait mask (length n_traits): 1 = this trait's between-unit Psi was
  // pinned off by the R-side identifiability gate (single-trial binary /
  // categorical traits), 0 = free. A pinned trait has s_B(t,.) fixed at 0 and
  // sd_B(t) fixed near zero, so its density term is a large positive constant
  // that must NOT enter the objective at all.
  DATA_IVECTOR(diag_B_skip);
  DATA_INTEGER(use_rr_W);          // 1/0
  DATA_INTEGER(use_diag_W);        // 1/0
  // Per-trait mask (length n_traits): 1 = this trait's OLRE was pinned off by
  // the R-side identifiability gate (single-trial Bernoulli / ordinal_probit /
  // multinomial traits), 0 = free. Exactly the diag_B_skip situation one tier
  // down: a pinned trait has s_W(t,.) fixed at 0 and sd_W(t) fixed near zero,
  // so its density term is a large positive constant that must NOT enter.
  DATA_IVECTOR(diag_W_skip);
  DATA_INTEGER(use_rr_B_slope);     // 1/0 augmented B-tier random regression
  DATA_INTEGER(use_diag_B_slope);   // 1/0 augmented B-tier unique random regression
  DATA_INTEGER(d_B_slope);          // rank of augmented B-tier random regression
  DATA_INTEGER(n_lhs_cols_B_lat);   // C = 2*n_traits for single-slope augmented B path
  DATA_MATRIX(Z_B_lat);             // n_obs x C selector/design matrix
  DATA_INTEGER(n_lhs_cols_B_diag);  // C = 2*n_traits for augmented B unique path
  DATA_MATRIX(Z_B_diag);            // n_obs x C selector/design matrix

  // Stage-3 phylogenetic random effect (propto): one length-n_species draw
  // per trait, prior MVN(0, exp(loglambda_phy) * C_phy). The species factor
  // is mapped onto observations via species_id.
  DATA_INTEGER(use_propto);
  DATA_IVECTOR(species_id);        // 0-indexed species per row (only used if use_propto)
  DATA_INTEGER(n_species);
  DATA_MATRIX(Cphy_inv);           // n_species x n_species, precomputed
  DATA_SCALAR(log_det_Cphy);       // scalar, precomputed

  // Stage-3 species non-phylogenetic random effect (q_it): diag of trait-
  // specific variances on species level. Re-uses diag_covstruct semantics
  // but on the species grouping rather than site / site_species.
  DATA_INTEGER(use_diag_species);

  // cluster2: a SECOND independent diagonal grouping (a renamed copy of
  // the diag_species block). Lets a user fit two crossed/nested plain
  // diagonal per-trait variance components at once. Family-agnostic: the
  // contribution is added to eta before family dispatch.
  DATA_IVECTOR(cluster2_id);       // 0-indexed cluster2 grouping per row
  DATA_INTEGER(n_cluster2);
  DATA_INTEGER(use_diag_cluster2);

  // Stage-3 known-V (equalto): a single length-n_obs draw with prior
  // MVN(0, V), V fixed. Used by Stage 6's two-stage meta-regression.
  DATA_INTEGER(use_equalto);
  DATA_MATRIX(V_inv);              // n_obs x n_obs (kept as dense for now)
  DATA_SCALAR(log_det_V);

  // Stage-4 spde: one independent SPDE field per trait. Uses fmesher-built
  // SPDE finite-element matrices M0, M1, M2 and a sparse projection matrix
  // A_proj (n_obs x n_mesh). The Q matrix is reconstructed inside the
  // template as Q_base = kappa^4 * M0 + 2 * kappa^2 * M1 + M2.
  //
  // spde_lv_k toggles the rank of the spatial component:
  //   * spde_lv_k == 0: per-trait independent fields path
  //     (`spatial_unique` / `spatial_scalar`). One omega_spde column per
  //     trait, prior SCALE(GMRF(Q), 1/tau)(omega_t).
  //   * spde_lv_k >= 1: low-rank `spatial_latent` path. K_S shared spatial
  //     fields omega_spde_lv (n_mesh x K_S) with prior GMRF(Q_base) (tau
  //     absorbed into Lambda_spde for identifiability, mirroring
  //     phylo_latent), and a T x K_S loading matrix Lambda_spde drives all
  //     traits via eta(o) += sum_k Lambda_spde(t, k) * (A_proj * omega_spde_lv.col(k))(o).
  //     If spde_lv_unique == 1, an additional per-trait omega_spde block is
  //     kept alive on the same Q_base with its own tau_t scale, giving
  //     Sigma_spde = Lambda_spde Lambda_spde' + diag(Psi_spde).
  DATA_INTEGER(use_spde);
  DATA_INTEGER(spde_lv_k);         // 0 = per-trait path; >=1 = K-rank loadings path
  DATA_INTEGER(spde_lv_unique);    // 1 = spatial_latent(..., unique = TRUE)
  DATA_INTEGER(n_mesh);
  (void)n_mesh;                    // retained in the data contract for mesh sanity checks in R
  DATA_SPARSE_MATRIX(A_proj);      // n_obs x n_mesh
  // Dedicated response-column SPDE projection. Unlike A_proj, A_column has
  // one row per response column and is used to normalize the projected field
  // to unit marginal variance at those exact coordinates. It is a 1x1 zero
  // stub unless use_spatial_column_slope == 1.
  DATA_INTEGER(use_spatial_column_slope);
  DATA_MATRIX(A_column);           // n_traits x n_mesh when active
  DATA_SPARSE_MATRIX(spde_M0);     // n_mesh x n_mesh
  DATA_SPARSE_MATRIX(spde_M1);
  DATA_SPARSE_MATRIX(spde_M2);

  // BASE augmented SPDE slope (spatial_unique 1 + x | coords).
  // Dormant unless use_spde_slope == 1. A SECOND SPDE field on the
  // covariate x is added on the SAME mesh / SAME Q_base (same kappa)
  // as the intercept field; the two node-level fields
  // (omega_alpha, omega_beta) share a 2x2 cross-field covariance
  // Sigma_field, giving the matrix-normal prior
  //   vec(Omega) ~ N(0, Sigma_field (x) Q^{-1}),   Omega = [omega_a | omega_b].
  // eta(o) += (A_proj omega_a)(o) + x(o) * (A_proj omega_b)(o)
  //         = sum_j (A_proj omega_j)(o) * Z_spde_aug(o, j).
  // Sigma_field absorbs the field marginal variances (no separate tau),
  // mirroring how spde_lv absorbs scale into Lambda_spde.
  DATA_INTEGER(use_spde_slope);    // 0 = dormant (default); 1 = base augmented SPDE slope
  DATA_INTEGER(n_lhs_cols_spde);   // block-local LHS columns: 1 (slope-only) or 2 (intercept + slope);
                                   // C = 2*n_traits on the spatial_dep slope path
  DATA_ARRAY(Z_spde_aug);          // n_obs x n_lhs_cols_spde (col 0 = 1's; col 1 = x covariate);
                                   // INTERLEAVED (alpha_t0, beta_t0, alpha_t1, ...) on the dep path

  // spatial_dep slope flag (Design 64 sec.2). When 1, the augmented SPDE prior
  // uses the full unstructured C x C Sigma_field = L L^T (C = 2*n_traits) built
  // from theta_spde_dep_chol, replacing the closed-form 1x1 / 2x2 Sigma_field of
  // the base. This is the spatial analogue of use_phylo_dep_slope with A_phy
  // swapped for the SPDE field covariance Q_base^{-1}. Default 0 keeps the
  // base unique/indep SPDE-slope paths byte-identical.
  DATA_INTEGER(use_spde_dep_slope);

  // spatial_latent slope (Design 64 sec.3): spatial_latent(1 + x | coords, d).
  // Block-diagonal reduced-rank random regression on the SPDE field. For each
  // LHS column k in {0 = intercept, 1 = slope} an INDEPENDENT rank-d_spde_slope
  // factor structure Sigma_k = Lambda_k Lambda_k^T (n_traits x n_traits), with
  // d_spde_slope shared spatial fields g_spde_slope[ , f, k] ~ N(0, Q_base^{-1})
  // i.i.d. across f and k. No intercept-slope correlation (block-diagonal). This
  // is the spatial analogue of use_phylo_latent_slope with the species-indexed
  // score g_phy_slope replaced by the A_proj-projected mesh field. When
  // use_spde_latent_slope == 0 the parameters below are mapped off on the R side.
  DATA_INTEGER(use_spde_latent_slope);
  DATA_INTEGER(d_spde_slope);      // rank K of each per-column FA decomposition
  DATA_INTEGER(n_lhs_cols_spde_lat);  // LHS columns for the latent-slope block (1 or 2)
  DATA_MATRIX(Z_spde_lat);         // n_obs x n_lhs_cols_spde_lat (col 0 = 1's; col 1 = x)

  // Stage-33 + 37: response family. family_id_vec is length n_obs;
  // each entry picks the family for that observation:
  //   0 = Gaussian (identity link)
  //   1 = Bernoulli / binomial
  //   2 = Poisson (log link)
  //   3 = Lognormal (log link)
  //   4 = Gamma (log link)
  //   5 = NB2 negative binomial type-2 (log link)
  //   6 = Tweedie compound Poisson-Gamma (log link)
  //   7 = Beta (logit link; mu-phi parameterisation, y in (0, 1))
  //   8 = Beta-binomial (logit link; n_trials trials, mu-phi parameterisation)
  //   9 = Student-t (identity link; per-trait sigma + df)
  //  10 = truncated Poisson (log link; y >= 1 strictly)
  //  11 = truncated NB2 (log link; y >= 1 strictly; per-trait phi)
  //  12 = delta_lognormal (hurdle: Bernoulli{y>0} x Lognormal{y|y>0})
  //  13 = delta_gamma     (hurdle: Bernoulli{y>0} x Gamma{y|y>0})
  //  14 = ordinal_probit  (Wright/Falconer/Hadfield threshold model;
  //                        K-category ordinal data with K >= 3, K-2 free
  //                        cutpoints per trait beyond the fixed tau_1 = 0)
  //  15 = NB1 negative binomial type-1 (log link; Var = mu*(1+phi), linear
  //                        in the mean; per-trait phi via log_phi_nbinom1)
  //  16 = multinomial (baseline-category logit / softmax; unordered K >= 3
  //                        categories; fixed-effects-only). A categorical
  //                        observation is expanded (R side) into K-1 contiguous
  //                        "category-contrast" pseudo-rows sharing one
  //                        multinom_group_id; the softmax density is evaluated
  //                        ONCE at the group's anchor (first) row, NOT per row.
  //                        See multinom_group_id / multinom_K_per_trait below.
  // For single-family fits the vector is filled with the same value.
  // sigma_eps is mapped off when no row has family_id_vec(o) in {0, 3}.
  // Ordinary Gamma (fid 4) has its own per-trait shape/CV parameter below.
  // Delta families share ONE linear predictor for both components: p =
  // invlogit(eta) for presence and mu_pos = exp(eta) for the positive
  // continuous part. A future release may decouple the two predictors.
  DATA_IVECTOR(family_id_vec);

  // link_id_vec is length n_obs (matched to family_id_vec). Currently
  // only the binomial family (fid 1) is link-flexible; for other
  // families the entry is ignored. Encoding:
  //   0 = logit   (binomial; canonical; implicit latent-residual var = pi^2/3)
  //   1 = probit  (binomial; implicit latent-residual var = 1)
  //   2 = cloglog (binomial; implicit latent-residual var = pi^2/6)
  // For Gaussian/Poisson/lognormal/Gamma, link_id_vec entries are 0
  // and unused.
  DATA_IVECTOR(link_id_vec);

  // offset_vec is length n_obs: a KNOWN per-row addition to the linear
  // predictor, contributing no parameter. On the log link this is the usual
  // exposure/effort idiom, eta = log(effort) + X b, i.e. a multiplicative
  // rate adjustment. Zeros when the user supplied no offset(), so a fit
  // without one is unchanged.
  //
  // The R side gates this to count families (fids 2, 5, 10, 11, 15), plus
  // the private iSDM Bernoulli-cloglog route with known sampled-area support.
  // All other rows have exact zero. The template applies the prepared offset
  // unconditionally so it cannot discard a value the R side has admitted.
  DATA_VECTOR(offset_vec);

  // MERGE (isdm x mspl): both lanes added DATA objects here; the blocks are
  // additive and orthogonal, so both are kept.
  // Developer-only diagnostic: when enabled by the private iSDM R route,
  // report the unintegrated, weighted observation contribution for each row.
  // Public fits leave this exactly zero and receive no additional report field.
  DATA_INTEGER(report_obs_nll);
  // Lane B opt-in estimator contract. ML callers supply inert stubs and the
  // data-constant branch below never tapes the guarded Jeffreys atom.
  DATA_INTEGER(estimator_id);      // 0 = ML, 1 = LA-MSPL, 2 = internal penalty-off LA-MSPL kernel
  DATA_MATRIX(X_mspl);             // resolved free fixed design; N_eff x p_beta
  DATA_INTEGER(N_eff);             // complete contributing Bernoulli rows (or stacked Gaussian rows)
  DATA_INTEGER(p_free);            // independent penalized outer coordinates
  DATA_SCALAR(spde_r0);            // positive spatial reference distance; 1 for ML
  DATA_IVECTOR(mspl_tau_representative); // 0-based free tau representatives
  // Gaussian ordinary LA-MSPL (pick C / Hirose): ML Gram diagonal S_jj and
  // unit count N for c_N = sqrt(2/N). Bernoulli / ML supply length-1 stubs.
  DATA_VECTOR(mspl_S_diag);
  DATA_INTEGER(mspl_N_units);

  // ordinal_probit (fid 14): per-trait cutpoint metadata.
  // n_ordinal_cuts_per_trait(t)  = K_t - 2, the number of FREE cutpoints
  //                               for trait t (0 for non-ordinal traits).
  //                               tau_1 = 0 is fixed for identifiability,
  //                               so a K_t-category trait estimates K_t - 2
  //                               cutpoints {tau_2, ..., tau_{K_t-1}}.
  // ordinal_offset_per_trait(t)  = cumulative count of free cutpoints across
  //                               traits 1..t-1 (start index into the flat
  //                               ordinal_log_increments parameter vector).
  // The vector length is n_traits in both cases; entries for non-ordinal
  // traits are 0 and unused. Reference: Hadfield (2015) MEE 6:706-714, eqn 9.
  DATA_IVECTOR(n_ordinal_cuts_per_trait);
  DATA_IVECTOR(ordinal_offset_per_trait);

  // multinomial (fid 16): baseline-category logit / softmax response. A
  // categorical observation with K_t categories is expanded (R side) into
  // K_t - 1 CONTIGUOUS "category-contrast" pseudo-rows sharing one
  // multinom_group_id. The eta on contrast row j (j = 0..K_t-2) is the
  // baseline-category logit for category j+2; baseline category 1 is pinned at
  // eta = 0 (the implicit exp(0) = 1 term in the softmax normaliser). y on each
  // contrast row is the 0/1 indicator "observed category == this contrast"
  // (all zero => baseline observed). The grouped softmax density is evaluated
  // ONCE at the group anchor (first) row over its L = K_t - 1 contrast rows;
  // there is NO cutpoint or dispersion parameter (contrast ordinal fid 14).
  //   multinom_group_id(o)    = observation-group index (>= 0) for a fid-16 row;
  //                             -1 for every non-multinomial row. (length n_obs)
  //   multinom_K_per_trait(t) = K_t - 1 for a multinomial (pseudo-)trait t;
  //                             0 for non-multinomial traits. (length n_traits)
  DATA_IVECTOR(multinom_group_id);
  DATA_IVECTOR(multinom_K_per_trait);

  // Stage-35 / Stage-40: phylogenetic reduced-rank covstruct (PGLLVM).
  // For each factor k = 0..d_phy-1, g_phy.col(k) ~ N(0, A) where A is
  // the phylogenetic correlation matrix, passed as its (sparse) inverse
  // for efficient quadratic-form evaluation.
  //
  // Stage-40 (true sparse-$A^{-1}$ trick): A^-1 is built over tips +
  // internal nodes by .gllvm_phylo_tree_precision() (R/phylo-tree-precision.R;
  // no MCMCglmm dependency), giving a genuinely sparse matrix of dimension
  // n_aug_phy = n_tip + Nnode - 1 -- one row per EDGE of the tree, the root
  // excluded. That is 2*n_tips - 2 for a fully bifurcating tree and SMALLER
  // for any polytomy; it is never 2*n_tips - 1. Each observation's contribution
  // reads g_phy at the augmented row corresponding to its tip species, via
  // species_aug_id.
  //
  // Backward-compatible fallback: when no tree is provided, R passes
  // a dense Cphy^-1 and species_aug_id == species_id; the dimensions
  // collapse to n_species and behaviour is identical to the previous
  // implementation.
  DATA_INTEGER(use_phylo_rr);
  DATA_INTEGER(d_phy);
  DATA_INTEGER(n_aug_phy);           // n_aug_phy >= n_species (== n_species in legacy path)
  DATA_SPARSE_MATRIX(Ainv_phy_rr);   // n_aug_phy x n_aug_phy (sparse)
  DATA_SCALAR(log_det_A_phy_rr);     // precomputed
  DATA_IVECTOR(species_aug_id);      // n_obs, 0-indexed row in g_phy (== species_id in legacy path)
  DATA_INTEGER(structured_rho_sparse);
  DATA_INTEGER(structured_rho_spatial);
  DATA_IVECTOR(spatial_rho_group_id);
  DATA_SPARSE_MATRIX(spatial_rho_A);
  DATA_SCALAR(structured_rho_value);
  DATA_VECTOR(structured_rho_diagonal);
  DATA_INTEGER(structured_rho_estimated);
  DATA_MATRIX(structured_rho_eigenvectors);
  DATA_VECTOR(structured_rho_eigenvalues);

  // Design 65 C3.1: generic fixed dense multi-kernel tiers. This is active
  // only for two or more named kernel_* tiers; the one-name path stays in the
  // phylo-equivalent block above for KER-02 byte-equivalence.
  DATA_INTEGER(n_kernel_tiers);
  DATA_INTEGER(n_kernel_levels);
  DATA_INTEGER(max_kernel_rank);
  DATA_IVECTOR(kernel_group_id);      // n_obs, 0-indexed row in each K_r
  DATA_IVECTOR(kernel_rank);          // rank per tier
  DATA_IVECTOR(kernel_has_latent);    // 1 when Lambda_r / g_r is active
  DATA_IVECTOR(kernel_has_diag);      // 1 when Psi_r is active
  DATA_IVECTOR(kernel_g_offset);      // flat offset into g_kernel per tier
  DATA_IVECTOR(kernel_logsd_offset);  // flat offset into log_sd_kernel_diag
  DATA_IVECTOR(kernel_diag_offset);   // flat offset into g_kernel_diag
  DATA_ARRAY(Ainv_kernel);            // n_tier x n_level x n_level
  DATA_VECTOR(log_det_A_kernel);      // length n_tier

  // Two-U PGLLVM: phylo_diag (per-trait phylogenetic random intercept).
  // When phylo_latent(species, d=K) and phylo_unique(species) co-fit, the
  // phy-tier covariance becomes Sigma_phy = Lambda_phy Lambda_phy^T +
  // diag(U_phy). The Lambda_phy Lambda_phy^T part is fit by the phylo_rr
  // block above; the diag(U_phy) part is fit here, with one phylogenetic
  // random intercept per trait. Each column g_phy_diag.col(t) ~ N(0, A)
  // (the same A used by phylo_rr), scaled by exp(log_sd_phy_diag(t)).
  // Reuses Ainv_phy_rr, n_aug_phy, log_det_A_phy_rr, species_aug_id from
  // the phylo_rr machinery (no new tree / VCV needed). When
  // use_phylo_diag == 0, log_sd_phy_diag and g_phy_diag are mapped off.
  // Reference: Hadfield & Nakagawa (2010) JEB 23:494-508; Halliwell et al.
  // (2025); Meyer & Kirkpatrick (2008) Genetics 178:2223-2240.
  DATA_INTEGER(use_phylo_diag);

  // Phylogenetic random slope (Q6):
  //   eta(o) += b_phy_slope(phylo_slope_aug_id(o)) * x_phy_slope(o)
  //   b_phy_slope ~ N(0, sigma_slope^2 * A_phy)
  // Slopes are shared across traits (one per species, applied uniformly to
  // every trait). Its precision and map are resolved from the term RHS, not
  // from the global cluster tier. When use_phylo_slope == 0, b_phy_slope is mapped
  // off and x_phy_slope is unused.
  DATA_INTEGER(use_phylo_slope);
  DATA_VECTOR(x_phy_slope);          // length n_obs; covariate values
  // PR-0: legacy slope-only terms have their own RHS-controlled grouping
  // map and precision.  This keeps the global cluster-tier phylogenetic
  // fields independent when `phylo_slope(x | g)` uses a different `g`.
  DATA_INTEGER(n_aug_phy_slope);
  DATA_SPARSE_MATRIX(Ainv_phy_slope);
  DATA_SCALAR(log_det_A_phy_slope);
  DATA_IVECTOR(phylo_slope_aug_id);
  // Augmented-LHS random-regression path (live). The default R-side flag is
  // 0, so the legacy b_phy_slope path above remains active and byte-identical
  // for non-augmented fits; the parser/R design-matrix routes set it to 1.
  DATA_INTEGER(use_phylo_slope_correlated);
  // Slope-only response-column submode.  It reuses the augmented
  // matrix-normal likelihood below, but its precision and row map are the
  // term-local RHS-resolved fields above rather than the shared cluster tier.
  DATA_INTEGER(use_phylo_column_slope);
  DATA_INTEGER(use_column_coef_estimated_rho);
  // Old serialized payloads retain centred B coordinates when this private
  // flag is absent. Admitted new fits use b_phy_aug as standardized U instead.
  SEXP column_standardization_flag = getListElement(
    TMB_OBJECTIVE_PTR->data, "standardize_column_coef");
  int standardize_column_coef = 0;
  if (!Rf_isNull(column_standardization_flag)) {
    if (Rf_length(column_standardization_flag) != 1 ||
        !(Rf_isInteger(column_standardization_flag) ||
          Rf_isReal(column_standardization_flag)))
      error("gllvmTMB_multi: standardize_column_coef must be scalar 0 or 1");
    double flag = Rf_asReal(column_standardization_flag);
    if (flag != 0.0 && flag != 1.0)
      error("gllvmTMB_multi: standardize_column_coef must be 0 or 1");
    standardize_column_coef = static_cast<int>(flag);
  }
  DATA_MATRIX(column_coef_source_U);
  DATA_VECTOR(column_coef_source_lambda);
  DATA_VECTOR(column_coef_source_inv_d);
  DATA_SCALAR(column_coef_source_logdet_D2);
  DATA_INTEGER(n_lhs_cols);           // block-local LHS columns: 1 or 2 (unique/indep);
                                      // C = 2*n_traits for the phylo_dep slope path
  DATA_ARRAY(Z_phy_aug);              // n_obs x n_lhs_cols x n_phy_aug_blocks
  // phylo_dep slope flag (Stage 3, Design 56 sec.9.5c). When 1, the
  // augmented prior below uses the full unstructured C x C Sigma_b built
  // from theta_dep_chol instead of the closed-form 1x1 / 2x2 covariance.
  // Default 0 keeps the unique/indep/legacy paths byte-identical.
  DATA_INTEGER(use_phylo_dep_slope);

  // phylo_latent random slope (Design 56 Sec. 5.3 latent row; Sec. 9.5a):
  //   phylo_latent(1 + x | sp, d = K) -- reduced-rank, BLOCK-DIAGONAL across
  //   the LHS columns. Each LHS column k in {0 = intercept, 1 = slope} gets
  //   its OWN factor-analytic decomposition Sigma_k = Lambda_k Lambda_k^T
  //   (n_traits x n_traits, rank d_phy_slope), with K latent factor-score
  //   columns g_phy_slope[ , f, k] ~ N(0, A_phy) i.i.d. across f and k. There
  //   is NO intercept-slope correlation (block-diagonal == cross-column
  //   covariance blocks are zero), which is the Sec. 5.3 latent semantics, in
  //   contrast to the full 2x2 / unstructured b_phy_aug (dep/unique) path.
  //
  //   eta(o) += sum_{k} Z_phy_lat(o, k)
  //               * sum_{f} Lambda_phy_slope(t(o), f, k) * g_phy_slope(sp(o), f, k)
  //
  //   This is the existing phylo_rr eta term replicated per LHS column, with
  //   an independent loading matrix per column and the column design value
  //   Z_phy_lat (column 0 = 1's; column 1 = x covariate). Reuses
  //   Ainv_phy_rr / n_aug_phy / log_det_A_phy_rr / species_aug_id from the
  //   phylo_rr machinery (same tree / VCV). When use_phylo_latent_slope == 0
  //   the parameters below are mapped off on the R side and this block is
  //   inert. References: Hadfield & Nakagawa (2010) JEB 23:494-508 (the A
  //   prior); the random-regression / reaction-norm decomposition (Design 56
  //   Sec. 5.1) restricted to the block-diagonal (uncorrelated) case.
  DATA_INTEGER(use_phylo_latent_slope);
  DATA_INTEGER(d_phy_slope);          // rank K of each per-column FA decomposition
  DATA_INTEGER(n_lhs_cols_lat);       // LHS columns for the latent-slope block (1 or 2)
  DATA_MATRIX(Z_phy_lat);             // n_obs x n_lhs_cols_lat (col 0 = 1's; col 1 = x)

  // Generic random intercepts `(1 | group)` (lme4/glmmTMB bar syntax).
  // Each term t adds u_re_int[offset(t) + group_id(o, t)] to eta(o), where
  // u_re_int[range_t] ~ N(0, sigma_re_int(t)^2) i.i.d. across levels.
  // Random slopes are not yet implemented.
  DATA_INTEGER(use_re_int);
  DATA_INTEGER(n_re_int_terms);
  DATA_IVECTOR(re_int_offsets);      // length n_re_int_terms (start of each term in u_re_int)
  DATA_IVECTOR(re_int_n_groups);     // length n_re_int_terms (n levels per term)
  DATA_IMATRIX(re_int_group_id);     // n_obs x n_re_int_terms (0-indexed group level per row, term)

  // lme4 / glmmTMB-style per-row likelihood weights (length n_obs). The
  // observation-level NLL contribution for row o is multiplied by
  // weights_i(o). For binomial rows the user-supplied `weights = ` is
  // already absorbed into n_trials (the alternative-API trial-count
  // semantics), so weights_i(o) is set to 1 on those rows by the R side
  // to avoid double-application. Unit weights (default) reproduce the
  // unweighted behaviour exactly. Mirrors src/gllvmTMB.cpp:162.
  DATA_VECTOR(weights_i);

  // -------- Missing-PREDICTOR layer (Phase 2a/2b/2c, design 67) ----------
  // One continuous Gaussian missing predictor declared with mi(x). The missing
  // x lives at a LATENT level -- the wide-row unit (Phase 2a/2b) or, when the
  // covariate model carries a mi_group(g) marker, a coarser/cross-cutting group
  // g (Phase 2c, design 67 sec.2.1 / 69 sec.4.1). x is broadcast across that
  // level's long rows, so the latent x_mis has ONE entry per missing LEVEL
  // value (not per long row), and the Gaussian covariate density is evaluated
  // at the LATENT level. The long-row -> level map `mi_unit_id` broadcasts
  // x_full(u) to every long row. The block is level-agnostic: n_units below is
  // the number of latent-level values (units or groups). has_mi == 0 -> every
  // block below is gated off (exact no-op).
  DATA_INTEGER(has_mi);            // 1 = an mi() predictor is present
  DATA_INTEGER(mi_family);         // 0 = Gaussian, 1 = binary, 2 = ordered, 3 = unordered
  DATA_INTEGER(mi_col);            // 0-indexed column of X_fix for the mi() x
  DATA_VECTOR(mi_x_unit);          // length n_units (latent levels); observed x,
                                   // sentinel where missing (x_mis overrides)
  DATA_IVECTOR(mi_observed_unit);  // length n_units; 1 = x observed for a level
  DATA_IVECTOR(mi_missing_index);  // 0-indexed positions of missing levels
  DATA_IVECTOR(mi_unit_id);        // length n_obs; long-row -> level (0-indexed)
  DATA_MATRIX(X_mi);               // level covariate design (n_units x p_x)
  // Phase 2b: ONE grouped random intercept on the covariate model, at the
  // LATENT level. has_mi_group == 0 -> the group block is an exact no-op.
  DATA_INTEGER(has_mi_group);      // 1 = the covariate model has (1 | group)
  DATA_IVECTOR(mi_group_index);    // length n_units; level -> RE group (0-idx)
  // Phase 3 (design 69): a PHYLOGENETIC structured intercept on the covariate
  // model. The covariate latent level is SPECIES, so the field g_x ~ N(0, A)
  // is evaluated through the SAME sparse precision Ainv_phy_rr / log_det_A_phy_rr
  // / n_aug_phy the response phylo block uses (no new precision). mi_species_
  // node_id maps each latent species (the covariate-model rows, length n_units)
  // to its augmented-A node row in g_x. has_mi_phylo == 0 -> the g_x block is an
  // exact no-op and Ainv_phy_rr is referenced but unused by this block.
  DATA_INTEGER(has_mi_phylo);          // 1 = the covariate model has phylo(1|species)
  DATA_IVECTOR(mi_species_node_id);    // length n_units; species -> aug node (0-idx)
  // Phase 5b/5c (design 68 sec.1.2 / sec.1.3 / sec.4): the ORDERED (cumulative-
  // logit, mi_family == 2) and UNORDERED (baseline-softmax, mi_family == 3)
  // discrete predictors share the K-state full-swap machinery. mi_n_state = K
  // (number of categories). X_fix_state is the long-and-stacked state-design
  // matrix (the gllvmTMB analogue of drmTMB X_mi_state_mu) FILTERED to the long
  // rows of missing units: for a missing-unit long row o it holds K stacked
  // rows -- the FULL fixed-effect design of row o with the mi() factor predictor
  // forced to category k (k = 0..K-1), state as the FAST index. The base row of
  // o's K-block is mi_state_row(o); state k is row mi_state_row(o) + k.
  // mi_state_row(o) = -1 for observed-unit rows (no state block). When mi_family
  // not in {2, 3} these are 1x1 / length-1 stubs and the whole block is an exact
  // no-op.
  DATA_INTEGER(mi_n_state);            // K = number of categories (ordered/unordered)
  DATA_MATRIX(X_fix_state);            // (sum_{missing u} |rows(u)| * K) x p
  DATA_IVECTOR(mi_state_row);          // length n_obs; 0-idx K-block base or -1

  // -------- AGHQ (adaptive Gauss-Hermite quadrature) --------------------
  // Stage 1a: quadrature over the B-tier reduced-rank latent block z_B only
  // (latent(..., unique = FALSE)). use_aghq == 0 -> every line below is an
  // exact no-op and the Laplace path is byte-identical to the pre-AGHQ
  // template.
  //
  // The adaptation points are computed in R (conditional modes + Cholesky
  // factors of the conditional Hessian at the CURRENT fixed parameters) and
  // enter as DATA_, so the template stays differentiable in the fixed
  // parameters and TMB supplies exact gradients for free.
  //
  // Per site i, with H_i = L_i L_i' the conditional Hessian of the negative
  // log integrand and z = zhat_i + L_i^{-T} u,
  //
  //   log L_i = aghq_logdet(i)
  //             + logsumexp_j [ aghq_logw(j) + inner_ll(i, j) ]
  //
  // where inner_ll(i, j) sums this site's row log-densities evaluated at
  // z_ij = zhat_i + L_i^{-T} u_j PLUS log N(z_ij; 0, I).
  //
  // WEIGHT CONVENTION (must match R/fit-multi.R .gllvmTMB_aghq_grid()):
  // aghq_nodes are PROBABILISTS' (N(0,1)-scaled) Gauss-Hermite nodes and
  //   aghq_logw(j) = sum_m log w~_{j_m} + (d/2) log(2 pi) + 0.5 * u_j' u_j
  // i.e. the log tensor weight, the (2 pi)^{d/2} factor from writing du in
  // the standard-normal measure, and the exp(u'u/2) correction that undoes
  // the Gauss-Hermite kernel are ALL folded in. With this convention k = 1
  // reproduces the Laplace approximation EXACTLY (single node u = 0,
  // w~ = 1 -> log L_i = logdet_i + (d/2) log(2 pi) + inner_ll(zhat_i)).
  DATA_INTEGER(use_aghq);          // 0 = Laplace (default), 1 = quadrature
  DATA_INTEGER(aghq_d);            // quadrature dimension (= d_B here)
  DATA_MATRIX(aghq_nodes);         // n_node x aghq_d
  DATA_VECTOR(aghq_logw);          // n_node
  DATA_MATRIX(aghq_mode);          // n_sites x aghq_d
  DATA_MATRIX(aghq_Lt);            // n_sites x (aghq_d * aghq_d), row-major
  DATA_VECTOR(aghq_logdet);        // n_sites

  // -------- PARAMETERS --------------------------------------------------
  PARAMETER_VECTOR(b_fix);                       // fixed-effects coefficients (p)
  PARAMETER_VECTOR(log_sigma_eps);               // residual log-SD slot(s)

  // Missing-predictor (Phase 2a): Gaussian covariate-model coefficients,
  // log residual SD, and the latent missing UNIT-level x values (random).
  PARAMETER_VECTOR(beta_mi);                     // covariate-model coefs (p_x)
  PARAMETER_VECTOR(log_sigma_mi);                // length 1; log sigma_x
  PARAMETER_VECTOR(x_mis);                       // latent missing UNIT x values
  // Phase 2b grouped covariate random intercept: standardized unit-level group
  // effects u_mi_group ~ N(0, 1) (joins `random`) scaled by sd_mi_group.
  PARAMETER_VECTOR(u_mi_group);                  // length n_group; N(0,1)
  PARAMETER_VECTOR(log_sd_mi_group);             // length 1; log group SD
  // Phase 3 phylogenetic covariate field (design 69): STANDARDIZED unit-variance
  // field g_x ~ N(0, A) over the augmented A nodes (joins `random`), scaled by
  // sd_x when it enters the covariate mean. log_sd_x is its log phylogenetic SD.
  // Parallels g_phy_diag / log_sd_phy_diag (the response per-trait phylo
  // intercept). Mapped off (length 1) when no phylo() covariate term is present.
  PARAMETER_VECTOR(g_x);                         // length n_aug_phy (or 1 if unused)
  PARAMETER_VECTOR(log_sd_x);                    // length 1; log phylo SD of x
  // Phase 5b (design 68 sec.1.2): the ORDERED predictor cutpoints, K-1 FREE,
  // parametrised as theta_ord = (free base c_1, log-increments...). The cutpoint
  // reconstruction is c_1 = theta_ord(0); c_j = c_{j-1} + exp(theta_ord(j)) for
  // j = 1..K-2. This MIRRORS drmTMB (K-1 free) and is DISTINCT from gllvmTMB's
  // fid-14 ordinal_probit RESPONSE convention (tau_1 = 0, K-2 free): the
  // cumulative-logit PREDICTOR has no separate response intercept, so the first
  // cutpoint stays free. Length 0 (mapped off) when mi_family != 2.
  PARAMETER_VECTOR(theta_ord);                   // length K-1 (ordered) or 0

  // Between-site rr: Lambda_B (n_traits x d_B) packed as theta_rr_B
  // length = d_B + (n_traits - d_B) * d_B = n_traits*d_B - d_B*(d_B-1)/2
  PARAMETER_VECTOR(theta_rr_B);
  PARAMETER_MATRIX(z_B);                         // d_B x n_sites spherical N(0, I)
  PARAMETER_MATRIX(alpha_lv_B);                  // n_lv_B x d_B score-mean coefficients
  // Augmented between-site random regression:
  // Lambda_B_slope is C x d_B_slope where C = 2*n_traits for the single
  // intercept+slope path. Rows are interleaved by trait:
  // intercept.t1, slope.t1, intercept.t2, slope.t2, ...
  PARAMETER_VECTOR(theta_rr_B_slope);
  PARAMETER_MATRIX(z_B_slope);                   // d_B_slope x n_sites spherical N(0, I)

  // Between-site diag: log-SDs per trait
  PARAMETER_VECTOR(theta_diag_B);                // length n_traits
  PARAMETER_MATRIX(s_B);                         // n_traits x n_sites
  // Augmented between-site diag: log-SDs for the 2T coefficient vector
  // intercept.t1, slope.t1, intercept.t2, slope.t2, ...
  PARAMETER_VECTOR(theta_diag_B_slope);          // length n_lhs_cols_B_diag
  PARAMETER_MATRIX(s_B_slope);                   // n_lhs_cols_B_diag x n_sites

  // Within-site rr: Lambda_W (n_traits x d_W)
  PARAMETER_VECTOR(theta_rr_W);
  PARAMETER_MATRIX(z_W);                         // d_W x n_site_species

  // Within-site diag
  PARAMETER_VECTOR(theta_diag_W);                // length n_traits
  PARAMETER_MATRIX(s_W);                         // n_traits x n_site_species

  // Stage-3 propto: phylogenetic random effects p_it. Single global scaling
  // loglambda_phy. p_phy is n_species x n_traits, prior MVN(0, exp(loglambda_phy) * Cphy)
  // applied independently across trait columns.
  PARAMETER(loglambda_phy);                      // single global scaling
  PARAMETER_MATRIX(p_phy);                       // n_species x n_traits

  // Stage-3 non-phylogenetic species term q_it: diag(0 + trait | species)
  PARAMETER_VECTOR(theta_diag_species);          // length n_traits
  PARAMETER_MATRIX(q_sp);                        // n_traits x n_species

  // cluster2 diagonal term: diag(0 + trait | cluster2) -- renamed copy of
  // the diag_species block on a second independent grouping.
  PARAMETER_VECTOR(theta_diag_cluster2);         // length n_traits
  PARAMETER_MATRIX(r_c2);                        // n_traits x n_cluster2

  // Stage-3 equalto: known-V random effect e_eq, length n_obs, prior MVN(0, V)
  PARAMETER_VECTOR(e_eq);                        // length n_obs (or 1 if unused)

  // Stage-4 spde: one SPDE field per trait
  PARAMETER_VECTOR(log_tau_spde);                // length n_traits (or 1 if unused)
  PARAMETER(log_kappa_spde);                     // shared
  PARAMETER_MATRIX(omega_spde);                  // n_mesh x n_traits
  PARAMETER_MATRIX(omega_spde_iid);              // modeled locations x traits
  PARAMETER_MATRIX(omega_spde_lv_iid);           // modeled locations x rank

  // spatial_latent: low-rank SPDE loadings + K_S shared spatial fields.
  // Same packed lower-triangular layout as theta_rr_B / theta_rr_W /
  // theta_rr_phy; identifiability via the standard rr() convention. Tau is
  // absorbed into Lambda_spde so omega_spde_lv has prior N(0, Q_base^{-1}).
  PARAMETER_VECTOR(theta_rr_spde_lv);            // packed Lambda_spde (n_traits x spde_lv_k)
  PARAMETER_MATRIX(omega_spde_lv);               // n_mesh x spde_lv_k

  // BASE augmented SPDE slope: the (intercept, slope) spatial field and its
  // 2x2 cross-field covariance Sigma_field. Dormant unless use_spde_slope==1.
  // Same scalable-name scheme as the phylo augmented block (log_sd_b /
  // atanh_cor_b): Sigma_field is built from log_sd_spde_b + atanh_cor_spde_b.
  PARAMETER_ARRAY(omega_spde_aug);               // n_mesh x n_lhs_cols_spde (col 0 = alpha; col 1 = beta;
                                                 // C = 2T interleaved fields on the dep path)
  PARAMETER_VECTOR(log_sd_spde_b);               // length n_lhs_cols_spde (mapped off on the dep path)
  PARAMETER_VECTOR(atanh_cor_spde_b);            // length n_lhs_cols_spde*(n_lhs_cols_spde-1)/2 (off on dep)
  // spatial_dep slope (Design 64 sec.2): full unstructured C x C field
  // covariance Sigma_field = L L^T over the C = 2T interleaved (intercept,
  // slope) spatial fields. theta_spde_dep_chol packs the free lower-triangular
  // Cholesky factor L as the C log-diagonal entries (C++ exp-transforms them)
  // followed by the strictly-lower entries column-major; length C(C+1)/2. Empty
  // (and mapped off) for the base unique / indep SPDE-slope paths (C in {1,2}),
  // so those fits are byte-identical. Same packing as theta_dep_chol.
  PARAMETER_VECTOR(theta_spde_dep_chol);         // length C(C+1)/2 when use_spde_dep_slope; else 0
  // spatial_latent slope (Design 64 sec.3): per-column reduced-rank loadings +
  // shared spatial fields. theta_rr_spde_slope packs n_lhs_cols_spde_lat
  // lower-triangular Lambda_k blocks back-to-back (each length
  // n_traits*d_spde_slope - d_spde_slope*(d_spde_slope-1)/2, same rr() layout as
  // theta_rr_phy_slope). g_spde_slope holds the shared spatial field scores on
  // the mesh. Mapped off on the R side when use_spde_latent_slope == 0.
  PARAMETER_VECTOR(theta_rr_spde_slope);         // n_lhs_cols_spde_lat packed Lambda_k blocks
  PARAMETER_ARRAY(g_spde_slope);                 // n_mesh x d_spde_slope x n_lhs_cols_spde_lat

  // Stage-35 PGLLVM: phylogenetic reduced-rank loadings + species factors.
  PARAMETER_VECTOR(theta_rr_phy);                // packed lower-triangular Lambda_phy
  PARAMETER_MATRIX(g_phy);                       // n_species x d_phy
  PARAMETER_MATRIX(g_phy_iid);                   // modeled levels only
  PARAMETER_MATRIX(g_phy_diag_iid);              // folded Psi companion
  PARAMETER(eta_structured_rho);                 // distinct outer parameter
  // Two-U PGLLVM: per-trait phylogenetic random intercepts and their log-SDs.
  // log_sd_phy_diag is length n_traits (or 1 if unused); g_phy_diag is
  // n_aug_phy x n_traits (or n_aug_phy x 1 if unused). Each trait column is
  // ~ N(0, A) with the same Ainv_phy_rr / log_det_A_phy_rr as phylo_rr.
  PARAMETER_VECTOR(log_sd_phy_diag);             // length n_traits (or 1 if unused)
  PARAMETER_MATRIX(g_phy_diag);                  // n_aug_phy x n_traits (or x 1 if unused)
  // Generic fixed dense multi-kernel block (Design 65 C3.1). Flat vectors use
  // tier offsets from DATA so component ranks can differ without unused random
  // effects. For each tier r, g_kernel rows are ordered level-major, rank-minor:
  // offset + i * rank_r + k. Optional Psi fields use offset + i * n_traits + t.
  PARAMETER_VECTOR(theta_rr_kernel);             // packed Lambda_r blocks
  PARAMETER_VECTOR(g_kernel);                    // flat kernel factor scores
  PARAMETER_VECTOR(log_sd_kernel_diag);          // optional Psi log-SDs
  PARAMETER_VECTOR(g_kernel_diag);               // optional Psi fields
  // phylo_slope params (Q6)
  PARAMETER_VECTOR(b_phy_slope);                 // length n_aug_phy_slope; per-group slopes
  PARAMETER(log_sigma_slope);                    // scalar; log slope sd
  PARAMETER_ARRAY(b_phy_aug);                     // n_aug_phy x n_lhs_cols x n_phy_aug_blocks
  PARAMETER_VECTOR(log_sd_b);                     // length n_lhs_cols
  PARAMETER_VECTOR(atanh_cor_b);                  // n_lhs_cols * (n_lhs_cols - 1) / 2
  // phylo_latent slope (Design 56 Sec. 5.3 / 9.5a). theta_rr_phy_slope packs
  // n_lhs_cols_lat lower-triangular Lambda_k blocks back-to-back, each of
  // length n_traits*d_phy_slope - d_phy_slope*(d_phy_slope-1)/2 (same packed
  // layout as theta_rr_phy). g_phy_slope holds the per-column latent factor
  // scores. Mapped off on the R side when use_phylo_latent_slope == 0.
  PARAMETER_VECTOR(theta_rr_phy_slope);           // n_lhs_cols_lat packed Lambda_k blocks
  PARAMETER_ARRAY(g_phy_slope);                   // n_aug_phy x d_phy_slope x n_lhs_cols_lat
  // phylo_dep slope (Stage 3, Design 56 sec.9.5c): full unstructured
  // C x C covariance Sigma_b = L L^T over the C = 2T trait-stacked
  // (intercept, slope) random-effect columns. theta_dep_chol packs the
  // free lower-triangular Cholesky factor L column-major below the
  // diagonal plus the C log-diagonal entries; length C(C+1)/2. Empty
  // (and mapped off) for the legacy / unique / indep paths (C in {1,2}),
  // so those fits are byte-identical. See Sigma_b construction below.
  PARAMETER_VECTOR(theta_dep_chol);               // length C(C+1)/2 when use_phylo_dep_slope; else 0
  PARAMETER(eta_column_coef_rho);                 // outer fixed parameter; never Laplace-random

  // Generic random intercepts: flat vector across all (1|g) terms.
  PARAMETER_VECTOR(u_re_int);                    // length sum(re_int_n_groups) (or 1 if unused)
  PARAMETER_VECTOR(log_sigma_re_int);            // length n_re_int_terms (or 1 if unused)

  // NB2 / NB1 / Gamma / Tweedie dispersion parameters (per trait). Mapped off when the
  // corresponding family is not in family_id_vec; otherwise one log-phi
  // (NB2 / NB1 / Gamma) and one log-phi + logit-p (Tweedie) per trait is estimated.
  // NB2 variance: var = mu + mu^2 / phi (so phi -> infinity recovers Poisson).
  // NB1 variance: var = mu * (1 + phi) = mu + phi * mu (linear in the mean;
  //               phi -> 0 recovers Poisson). Reference: Hilbe (2011) Negative
  //               Binomial Regression, 2nd ed.
  // Gamma shape: phi; CV = 1 / sqrt(phi).
  // Tweedie:      var = phi * mu^p with 1 < p < 2 (compound Poisson-Gamma).
  PARAMETER_VECTOR(log_phi_nbinom2);             // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_phi_nbinom1);             // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_phi_gamma);               // length n_traits (or 1 if unused), fid 4
  PARAMETER_VECTOR(log_phi_tweedie);             // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(logit_p_tweedie);             // length n_traits (or 1 if unused); p = 1 + plogis(.)

  // Beta / beta-binomial precision parameters (per trait). Mapped off when
  // the corresponding family is not in family_id_vec. Both families use the
  // mean-precision (mu, phi) parameterisation: a = mu * phi, b = (1-mu)*phi
  // so Var(y_beta) = mu*(1-mu)/(1+phi). Larger phi -> tighter concentration.
  // Reference for the Beta regression parameterisation: Smithson & Verkuilen
  // (2006) Psychol. Methods 11:54-71. Beta-binomial follows Hilbe (2014)
  // Modeling Count Data and Bolker (2008) Ecological Models and Data in R.
  PARAMETER_VECTOR(log_phi_beta);                // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_phi_betabinom);           // length n_traits (or 1 if unused)

  // Student-t (family_id 9): per-trait scale (log_sigma_student) and
  // per-trait log(df - 1) (log_df_student) so df = 1 + exp(log_df_student) > 1.
  // Mapped off when no row has fid 9. Reference: Lange, Little & Taylor
  // (1989) JASA 84:881-896; Pinheiro, Liu & Wu (2001) Comp. Stat. Data Anal.
  // 38:367-386. Identity link; mu = eta(o).
  PARAMETER_VECTOR(log_sigma_student);           // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_df_student);              // length n_traits (or 1 if unused); df = 1 + exp(log_df_student)

  // truncated_nbinom2 (family_id 11): zero-truncated NB2. Per-trait log-phi.
  // Likelihood: dnbinom2(y, mu, phi) / (1 - dnbinom2(0, mu, phi)) for y >= 1.
  // Mapped off when no row has fid 11.
  PARAMETER_VECTOR(log_phi_truncnb2);            // length n_traits (or 1 if unused)

  // Zero-inflated families (fid 17 zi_poisson, 18 zi_nbinom2, 19
  // zi_binomial; Design 62 reserves the zi_* name for a TRUE mixture, not
  // the delta/hurdle families above). logit_zi is a per-trait, intercept-
  // only structural-zero probability: zi = invlogit(logit_zi), NO
  // covariates and NO random effects on the zero part (recon Decision 2 --
  // matches GLLVM.jl's v1 scope, Lambda_z = 0). Mapped off (per-trait) when
  // the trait has no zi_* row, same convention as every other dispersion
  // vector above. zi_nbinom2 REUSES log_phi_nbinom2 above for its count-
  // process dispersion rather than adding a second NB2 phi vector (recon
  // open question 2 -- a deliberate per-trait departure from GLLVM.jl's
  // single shared-scalar r).
  PARAMETER_VECTOR(logit_zi);                    // length n_traits (or 1 if unused)

  // Delta (hurdle) families: per-trait dispersion of the *positive*
  // component only. The Bernoulli presence component has no extra
  // dispersion. Mapped off when fid 12/13 is absent.
  PARAMETER_VECTOR(log_sigma_lognormal_delta);   // length n_traits (or 1 if unused), fid 12
  PARAMETER_VECTOR(log_phi_gamma_delta);         // length n_traits (or 1 if unused), fid 13

  // ordinal_probit (fid 14): flat vector of LOG-spacings between
  // consecutive cutpoints, packed across ordinal traits in trait order.
  // For each ordinal trait t with K_t categories, n_ordinal_cuts_per_trait(t)
  // = K_t - 2 elements live at positions [ordinal_offset_per_trait(t),
  // ordinal_offset_per_trait(t) + K_t - 2). Cutpoints are then reconstructed
  // as tau_t = (0, exp(delta_{t,1}), exp(delta_{t,1}) + exp(delta_{t,2}), ...)
  // which guarantees tau_t,1 = 0 < tau_t,2 < tau_t,3 < ... by construction
  // (Christensen 2019 ordinal R package; brms cumulative()). Mapped off
  // (length 1 stub) when no row has fid 14.
  PARAMETER_VECTOR(ordinal_log_increments);

  Type nll = 0;
  Type mspl_cloglog_likelihood_tail_extension_count = Type(0.0);
  Type mspl_cloglog_weight_tail_extension_count = Type(0.0);
  int mspl_structure_id_int = 0; // 1 ordinary, 2 spatial_indep, 3 spatial_latent
  int mspl_family_mode = 0; // 0 unused, 1 Bernoulli, 2 Gaussian FA (pick C)
  if (estimator_id != 0 && estimator_id != 1 && estimator_id != 2)
    error("gllvmTMB_multi: estimator_id must be 0 (ML), 1 (MSPL), or 2 (internal penalty-off MSPL)");

  // Nonspatial Gaussian response-column coefficients only. The coefficient
  // covariance/source parameters and the observation model remain unchanged;
  // the private R gate additionally excludes fixed or tied physical-B maps.
  if (standardize_column_coef == 1) {
    SEXP reml_data = getListElement(TMB_OBJECTIVE_PTR->data, "REML");
    bool gaussian_reml = !Rf_isNull(reml_data) && Rf_asLogical(reml_data) != 0;
    if (use_phylo_column_slope != 1 || use_phylo_slope_correlated != 1 ||
        use_phylo_dep_slope != 1 || estimator_id != 0 || gaussian_reml ||
        use_aghq != 0 || has_mi != 0 || use_equalto != 0 || use_lv_B != 0 ||
        use_rr_W != 0 || use_diag_W != 0 || use_rr_B_slope != 0 ||
        use_diag_B_slope != 0 || use_propto != 0 || use_diag_species != 0 ||
        use_diag_cluster2 != 0 || use_spde != 0 ||
        use_spatial_column_slope != 0 || use_spde_slope != 0 ||
        use_spde_dep_slope != 0 || use_spde_latent_slope != 0 ||
        n_kernel_tiers != 0 || use_phylo_latent_slope != 0 || use_re_int != 0)
      error("gllvmTMB_multi: unsupported standardized Gaussian coefficient composition");
    if (n_traits < 1 || n_sites < 1 || y.size() != n_traits * n_sites ||
        family_id_vec.size() != y.size() || link_id_vec.size() != y.size() ||
        is_y_observed.size() != y.size() || weights_i.size() != y.size() ||
        trait_id.size() != y.size() || site_id.size() != y.size())
      error("gllvmTMB_multi: coefficient standardization requires a complete cell matrix");
    vector<int> cell_counts(n_traits * n_sites);
    cell_counts.setZero();
    for (int o = 0; o < y.size(); ++o) {
      if (family_id_vec(o) != 0 || link_id_vec(o) != 0 ||
          is_y_observed(o) != 1 || asDouble(weights_i(o)) != 1.0 ||
          trait_id(o) < 0 || trait_id(o) >= n_traits ||
          site_id(o) < 0 || site_id(o) >= n_sites)
        error("gllvmTMB_multi: coefficient standardization requires observed unit-weight identity Gaussian rows");
      int cell = trait_id(o) + n_traits * site_id(o);
      if (++cell_counts(cell) != 1)
        error("gllvmTMB_multi: coefficient standardization requires one observation per cell");
    }
  }

  // Exact scalar Gaussian convolution is admitted only for complete independent
  // cell effects in the reviewed ordinary/phylogenetic ML compositions. Keep
  // this fence on direct template calls as well as the R-side admission gate.
  if (integrate_gaussian_diag_B != 0 && integrate_gaussian_diag_B != 1)
    error("gllvmTMB_multi: integrate_gaussian_diag_B must be 0 or 1");
  if (integrate_gaussian_diag_B == 1) {
    SEXP reml_data = getListElement(TMB_OBJECTIVE_PTR->data, "REML");
    bool gaussian_reml = !Rf_isNull(reml_data) && Rf_asLogical(reml_data) != 0;
    if (use_diag_B != 1 || estimator_id != 0 || gaussian_reml || use_aghq != 0 ||
        has_mi != 0 || use_equalto != 0 || use_lv_B != 0 ||
        use_rr_W != 0 || use_diag_W != 0 || use_rr_B_slope != 0 ||
        use_diag_B_slope != 0 || use_propto != 0 || use_diag_species != 0 ||
        use_diag_cluster2 != 0 || use_spde != 0 ||
        use_spatial_column_slope != 0 || use_spde_slope != 0 ||
        use_spde_dep_slope != 0 || use_spde_latent_slope != 0 ||
        n_kernel_tiers != 0 || use_phylo_latent_slope != 0 || use_re_int != 0 ||
        (use_phylo_slope != 0 && use_phylo_column_slope != 1))
      error("gllvmTMB_multi: unsupported Gaussian cell-integration composition");
    if (n_traits < 1 || n_sites < 1 || y.size() != n_traits * n_sites ||
        s_B.rows() != n_traits || s_B.cols() != n_sites ||
        diag_B_skip.size() != n_traits || family_id_vec.size() != y.size() ||
        link_id_vec.size() != y.size() || is_y_observed.size() != y.size() ||
        weights_i.size() != y.size() || trait_id.size() != y.size() ||
        site_id.size() != y.size())
      error("gllvmTMB_multi: Gaussian cell integration requires a complete cell matrix");
    vector<int> cell_counts(n_traits * n_sites);
    cell_counts.setZero();
    for (int t = 0; t < n_traits; ++t)
      if (diag_B_skip(t) != 0)
        error("gllvmTMB_multi: Gaussian cell integration cannot skip Psi coordinates");
    for (int o = 0; o < y.size(); ++o) {
      if (family_id_vec(o) != 0 || link_id_vec(o) != 0 ||
          is_y_observed(o) != 1 || asDouble(weights_i(o)) != 1.0 ||
          trait_id(o) < 0 || trait_id(o) >= n_traits ||
          site_id(o) < 0 || site_id(o) >= n_sites)
        error("gllvmTMB_multi: Gaussian cell integration requires observed unit-weight identity Gaussian rows");
      int cell = trait_id(o) + n_traits * site_id(o);
      if (++cell_counts(cell) != 1)
        error("gllvmTMB_multi: Gaussian cell integration requires one observation per cell");
    }
  }

  // Fail closed for direct template callers. The R fence repeats these checks
  // before MakeADFun(), but unsupported structures must not acquire an MSPL
  // objective merely by bypassing that public fence.
  if (estimator_id != 0) {
    int common_family = family_id_vec(0);
    for (int o = 0; o < y.size(); ++o) {
      if (family_id_vec(o) != common_family)
        error("gllvmTMB_multi: MSPL requires a single response family");
    }
    bool mspl_gaussian = (common_family == 0);
    bool mspl_bernoulli = (common_family == 1);
    bool mspl_poisson = (common_family == 2);
    bool mspl_fenced = (common_family == 5 || common_family == 6 ||
                        common_family == 7 || common_family == 15);
    if (!mspl_gaussian && !mspl_bernoulli && !mspl_poisson && !mspl_fenced)
      error("gllvmTMB_multi: MSPL admits only gaussian, Bernoulli, Poisson, or fenced planned families");
    if (mspl_gaussian)
      mspl_family_mode = 2;
    else if (mspl_bernoulli)
      mspl_family_mode = 1;
    else if (mspl_poisson)
      mspl_family_mode = 3;
    else if (common_family == 5)
      mspl_family_mode = 4;
    else if (common_family == 15)
      mspl_family_mode = 5;
    else if (common_family == 7)
      mspl_family_mode = 6;
    else
      mspl_family_mode = 7;

    bool mspl_ordinary = (use_rr_B == 1 && use_spde == 0);
    bool mspl_spatial_indep = (use_rr_B == 0 && use_spde == 1 &&
                               spde_lv_k == 0 && spde_lv_unique == 0);
    bool mspl_spatial_latent = (use_rr_B == 0 && use_spde == 1 &&
                                spde_lv_k >= 1 && spde_lv_k <= 2 &&
                                spde_lv_k <= n_traits && spde_lv_unique == 0);
    if (mspl_gaussian) {
      // Gaussian LA-MSPL: ordinary latent + free Psi only (pick C).
      if (!mspl_ordinary)
        error("gllvmTMB_multi: Gaussian MSPL admits only ordinary latent(unique=TRUE)");
      if (mspl_spatial_indep || mspl_spatial_latent)
        error("gllvmTMB_multi: Gaussian MSPL does not admit spatial structures yet");
    } else if (mspl_poisson || mspl_fenced) {
      if (!mspl_ordinary)
        error("gllvmTMB_multi: Poisson/fenced MSPL admits only ordinary latent");
    } else {
      int n_admitted = int(mspl_ordinary) + int(mspl_spatial_indep) +
                       int(mspl_spatial_latent);
      if (n_admitted != 1)
        error("gllvmTMB_multi: MSPL requires exactly one ordinary latent, spatial_indep, or spatial_latent(q=1:2) block");
    }
    if (mspl_ordinary && (d_B < 1 || d_B > 2 || d_B > n_traits))
      error("gllvmTMB_multi: ordinary MSPL latent rank q must be 1 or 2");
    mspl_structure_id_int = mspl_ordinary ? 1 :
      (mspl_spatial_indep ? 2 : 3);
    if (use_lv_B == 1 || use_rr_B_slope == 1 || use_diag_B_slope == 1 ||
        use_rr_W == 1 || use_diag_W == 1 || use_propto == 1 ||
        use_diag_species == 1 || use_diag_cluster2 == 1 || use_equalto == 1 ||
        use_spde_slope == 1 || use_spde_dep_slope == 1 ||
        use_spde_latent_slope == 1 || use_phylo_rr == 1 ||
        use_phylo_diag == 1 || use_phylo_slope == 1 ||
        use_phylo_slope_correlated == 1 || use_phylo_dep_slope == 1 ||
        use_phylo_latent_slope == 1 || n_kernel_tiers != 0 ||
        use_re_int == 1 || has_mi == 1 || use_aghq != 0)
      error("gllvmTMB_multi: MSPL admits no additional random or structured block");
    if (mspl_gaussian) {
      if (use_diag_B != 1)
        error("gllvmTMB_multi: Gaussian MSPL requires free unique Psi (latent unique=TRUE)");
      if (diag_B_skip.size() != n_traits)
        error("gllvmTMB_multi: MSPL diag_B_skip has wrong length");
      for (int t = 0; t < n_traits; ++t)
        if (diag_B_skip(t) != 0)
          error("gllvmTMB_multi: Gaussian MSPL requires every Psi coordinate free");
      if (mspl_S_diag.size() != n_traits)
        error("gllvmTMB_multi: Gaussian MSPL requires mspl_S_diag length n_traits");
      if (mspl_N_units < 2)
        error("gllvmTMB_multi: Gaussian MSPL requires mspl_N_units >= 2");
    } else {
      if (!mspl_ordinary && use_diag_B == 1)
        error("gllvmTMB_multi: spatial MSPL does not admit an ordinary Psi block");
      if (mspl_ordinary && use_diag_B == 1) {
        if (diag_B_skip.size() != n_traits)
          error("gllvmTMB_multi: MSPL diag_B_skip has wrong length");
        for (int t = 0; t < n_traits; ++t)
          if (diag_B_skip(t) != 1)
            error("gllvmTMB_multi: MSPL does not admit free Bernoulli Psi coordinates");
      }
      if (mspl_S_diag.size() < 1)
        error("gllvmTMB_multi: Bernoulli MSPL requires an mspl_S_diag stub");
      if (mspl_N_units != 0)
        error("gllvmTMB_multi: Bernoulli MSPL leaves mspl_N_units at 0");
    }
    if (!mspl_ordinary) {
      double r0 = asDouble(spde_r0);
      if (!R_FINITE(r0) || !(r0 > 0.0))
        error("gllvmTMB_multi: spatial MSPL requires finite spde_r0 > 0");
    }
    if (mspl_spatial_indep) {
      if (log_tau_spde.size() != n_traits ||
          mspl_tau_representative.size() < 1)
        error("gllvmTMB_multi: spatial_indep MSPL requires tau representatives");
      std::vector<int> seen_tau(n_traits, 0);
      for (int j = 0; j < mspl_tau_representative.size(); ++j) {
        int t = mspl_tau_representative(j);
        if (t < 0 || t >= n_traits || seen_tau[t] == 1)
          error("gllvmTMB_multi: invalid spatial_indep MSPL tau representative");
        seen_tau[t] = 1;
      }
    }
    int expected_p_free = X_mspl.cols();
    if (mspl_ordinary) {
      expected_p_free += theta_rr_B.size();
      if (mspl_gaussian)
        expected_p_free += theta_diag_B.size();
    } else if (mspl_spatial_indep)
      expected_p_free += mspl_tau_representative.size() + 1;
    else
      expected_p_free += theta_rr_spde_lv.size() + 1;
    if (N_eff != y.size() || N_eff <= 0 || X_mspl.rows() != N_eff ||
        X_mspl.cols() < 1 || p_free != expected_p_free)
      error("gllvmTMB_multi: invalid MSPL N_eff, p_free, or resolved fixed design");
    int common_link = link_id_vec(0);
    if (mspl_gaussian) {
      if (common_link != 0)
        error("gllvmTMB_multi: Gaussian MSPL requires the identity link");
      for (int o = 0; o < y.size(); ++o) {
        double yo = asDouble(y(o));
        double wo = asDouble(weights_i(o));
        double oo = asDouble(offset_vec(o));
        if (is_y_observed(o) != 1 || family_id_vec(o) != 0 ||
            link_id_vec(o) != 0 || wo != 1.0 ||
            !R_FINITE(yo) || !R_FINITE(oo) || oo != 0.0)
          error("gllvmTMB_multi: Gaussian MSPL requires complete unweighted identity rows with all-zero offsets");
        for (int j = 0; j < X_mspl.cols(); ++j)
          if (!R_FINITE(asDouble(X_mspl(o, j))))
            error("gllvmTMB_multi: MSPL resolved fixed design must be finite");
      }
    } else if (mspl_bernoulli) {
      if (common_link < 0 || common_link > 2)
        error("gllvmTMB_multi: MSPL link must be logit, probit, or cloglog");
      for (int o = 0; o < y.size(); ++o) {
        double yo = asDouble(y(o));
        double no = asDouble(n_trials(o));
        double wo = asDouble(weights_i(o));
        double oo = asDouble(offset_vec(o));
        if (is_y_observed(o) != 1 || family_id_vec(o) != 1 ||
            link_id_vec(o) != common_link || no != 1.0 ||
            (yo != 0.0 && yo != 1.0) || wo != 1.0 ||
            !R_FINITE(oo) || oo != 0.0)
          error("gllvmTMB_multi: MSPL requires complete unweighted single-trial Bernoulli rows with one common link and all-zero offsets");
        for (int j = 0; j < X_mspl.cols(); ++j)
          if (!R_FINITE(asDouble(X_mspl(o, j))))
            error("gllvmTMB_multi: MSPL resolved fixed design must be finite");
      }
    } else {
      if (mspl_poisson) {
        if (common_link != 0)
          error("gllvmTMB_multi: Poisson MSPL requires the log link");
      } else if (common_family == 7) {
        if (common_link != 0)
          error("gllvmTMB_multi: Beta MSPL requires the logit link");
      } else if (common_link != 0) {
        error("gllvmTMB_multi: fenced count/Tweedie MSPL requires the log link");
      }
      for (int o = 0; o < y.size(); ++o) {
        double yo = asDouble(y(o));
        double wo = asDouble(weights_i(o));
        double oo = asDouble(offset_vec(o));
        if (is_y_observed(o) != 1 || family_id_vec(o) != common_family ||
            link_id_vec(o) != common_link ||
            wo != 1.0 || !R_FINITE(yo) || !R_FINITE(oo) || oo != 0.0 ||
            (mspl_poisson && yo < 0.0))
          error("gllvmTMB_multi: Poisson/fenced MSPL requires complete unweighted rows with all-zero offsets");
        for (int j = 0; j < X_mspl.cols(); ++j)
          if (!R_FINITE(asDouble(X_mspl(o, j))))
            error("gllvmTMB_multi: MSPL resolved fixed design must be finite");
      }
    }
  }

  // -------- Fixed-effects part of the linear predictor ------------------
  vector<Type> eta_fix = X_fix * b_fix;
  vector<Type> eta(y.size());
  for (int o = 0; o < y.size(); o++) eta(o) = eta_fix(o) + offset_vec(o);

  // -------- Missing-PREDICTOR block (Phase 2a, mi_family == 0) ----------
  // Direct analogue of drmTMB src/drmTMB.cpp mi_family == 0, with the design
  // 67 sec.2.0-2.1 unit broadcast: reconstruct x_full per UNIT (observed x, or
  // the latent x_mis for missing units); add the unit-level Gaussian covariate
  // density; delta-correct each long row's eta by swapping the broadcast mi()
  // column's contribution for the reconstructed value. For a singleton-unit
  // model `mi_unit_id` is the identity and this collapses to the per-row
  // drmTMB form -- the cross-package contract.
  if (has_mi == 1 && mi_family == 0) {
    int n_units = mi_x_unit.size();
    // Per-unit covariate mean eta_x = X_mi * beta_mi.
    vector<Type> mi_eta_x = X_mi * beta_mi;
    Type sigma_mi = exp(log_sigma_mi(0));
    // Phase 2b: add the UNIT-level grouped random intercept to eta_x. Direct
    // analogue of drmTMB src/drmTMB.cpp has_mi_group (mi_eta(i) += sd *
    // u(group(i))), evaluated at the unit level here. u_mi_group ~ N(0, 1).
    Type sd_mi_group = Type(0.0);
    if (has_mi_group == 1) {
      sd_mi_group = exp(log_sd_mi_group(0));
      for (int u = 0; u < n_units; ++u) {
        mi_eta_x(u) += sd_mi_group * u_mi_group(mi_group_index(u));
      }
      for (int g = 0; g < u_mi_group.size(); ++g) {
        nll -= dnorm(u_mi_group(g), Type(0.0), Type(1.0), true);
      }
    }
    // Phase 3 (design 69): the PHYLOGENETIC structured intercept on the
    // covariate mean. STANDARDIZED-field convention (Q1), mirroring the
    // response phylo_diag block (:771-776): the field g_x ~ N(0, A) is drawn
    // with a UNIT-variance GMRF penalty through the SAME sparse Ainv_phy_rr
    // (no new precision), then scaled by sd_x = exp(log_sd_x) as it enters the
    // per-species covariate mean:
    //   eta_x(u) += sd_x * g_x(mi_species_node_id(u))
    //   -log p(g_x) = 0.5 * (n_aug_phy*log(2pi) + log_det_A_phy_rr + g_x' Ainv g_x)
    // This is equivalent to a per-species phylogenetic intercept u_x ~ N(0,
    // sd_x^2 A). It is the covariate's OWN field (its OWN sd_x), SEPARATE from
    // any response phylo field -- they may reuse Ainv_phy_rr but are distinct
    // latents (Level-1 independent; the joint field is deferred to Phase 4).
    // The residual sigma_mi (sigma_x) stays -- the Pagel partition (Q2): as
    // sd_x -> 0 the field flattens and the covariate model degrades to the
    // independent Phase-2c model with no separate code path.
    Type sd_x = Type(0.0);
    if (has_mi_phylo == 1) {
      sd_x = exp(log_sd_x(0));
      for (int u = 0; u < n_units; ++u) {
        mi_eta_x(u) += sd_x * g_x(mi_species_node_id(u));
      }
      Type quad_x = (g_x.matrix().transpose() * Ainv_phy_rr * g_x.matrix())(0, 0);
      nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                    + log_det_A_phy_rr + quad_x);
    }
    // Reconstruct x_full(u): observed value, else the latent x_mis entry.
    vector<Type> mi_x_full(n_units);
    for (int u = 0; u < n_units; ++u) mi_x_full(u) = mi_x_unit(u);
    for (int j = 0; j < mi_missing_index.size(); ++j) {
      mi_x_full(mi_missing_index(j)) = x_mis(j);
    }
    // Covariate density, summed over UNITS (NOT long rows).
    for (int u = 0; u < n_units; ++u) {
      nll -= dnorm(mi_x_full(u), mi_eta_x(u), sigma_mi, true);
    }
    // Delta-correct each long row: replace the broadcast mi() column's
    // contribution X_fix(o, mi_col) * b_fix(mi_col) with the reconstructed
    // x_full(mi_unit_id(o)) * b_fix(mi_col).
    for (int o = 0; o < y.size(); ++o) {
      eta(o) += b_fix(mi_col) * (mi_x_full(mi_unit_id(o)) - X_fix(o, mi_col));
    }
    REPORT(mi_x_full);
    REPORT(beta_mi);
    REPORT(log_sigma_mi);
    REPORT(sigma_mi);
    REPORT(x_mis);
    if (has_mi_group == 1) {
      REPORT(u_mi_group);
      REPORT(log_sd_mi_group);
      REPORT(sd_mi_group);
      ADREPORT(log_sd_mi_group);
      ADREPORT(sd_mi_group);
    }
    // Phase 3: EBLUP field + the phylogenetic SD of the covariate.
    if (has_mi_phylo == 1) {
      REPORT(g_x);
      REPORT(log_sd_x);
      REPORT(sd_x);
      ADREPORT(log_sd_x);
      ADREPORT(sd_x);
    }
    ADREPORT(beta_mi);
    ADREPORT(log_sigma_mi);
    ADREPORT(sigma_mi);
  }

  // -------- Construct Lambda_B (n_traits x d_B), lower-triangular -------
  matrix<Type> Lambda_B(n_traits, std::max(d_B, 1));
  Lambda_B.setZero();
  if (use_rr_B == 1) {
    int p = n_traits;
    int rank = d_B;
    Lambda_B = gll_unpack_rr_loadings(theta_rr_B, p, rank);
    // Spherical prior on z_B.
    // Under AGHQ the z_B block is NOT a random effect: R maps the parameter
    // off and the N(0, I) prior is evaluated INSIDE the quadrature (at each
    // node), so it must not also be added here.
    if (use_aghq == 0) {
      for (int s = 0; s < n_sites; s++) {
        vector<Type> col_s = z_B.col(s);
        nll -= dnorm(col_s, Type(0), Type(1), true).sum();
      }
    }
    REPORT(Lambda_B);
    matrix<Type> Sigma_B = Lambda_B * Lambda_B.transpose();
    REPORT(Sigma_B);
  }

  // -------- Predictor-informed B-tier latent-score mean -------------------
  // Design 73 C1: z_i = X_lv_B(i, .) alpha_lv_B + e_i, e_i ~ N(0, I).
  // The existing z_B parameter remains the zero-mean innovation e_i; the score
  // entering eta is the total mean-plus-innovation score U_B_total.
  matrix<Type> U_lv_mean_B(std::max(n_sites, 1), std::max(d_B, 1));
  matrix<Type> U_B_total(std::max(n_sites, 1), std::max(d_B, 1));
  U_lv_mean_B.setZero();
  U_B_total.setZero();
  if (use_lv_B == 1) {
    if (use_rr_B != 1)
      error("gllvmTMB_multi: use_lv_B requires use_rr_B");
    if (X_lv_B.rows() != n_sites || X_lv_B.cols() != n_lv_B)
      error("gllvmTMB_multi: X_lv_B must be n_sites x n_lv_B");
    if (alpha_lv_B.rows() != n_lv_B || alpha_lv_B.cols() != d_B)
      error("gllvmTMB_multi: alpha_lv_B must be n_lv_B x d_B");
    for (int s = 0; s < n_sites; s++) {
      for (int k = 0; k < d_B; k++) {
        Type mean_sk = Type(0.0);
        for (int h = 0; h < n_lv_B; h++) {
          mean_sk += X_lv_B(s, h) * alpha_lv_B(h, k);
        }
        U_lv_mean_B(s, k) = mean_sk;
        U_B_total(s, k) = mean_sk + z_B(k, s);
      }
    }
    matrix<Type> B_lv_unit = Lambda_B * alpha_lv_B.transpose();
    REPORT(alpha_lv_B);
    REPORT(U_lv_mean_B);
    REPORT(U_B_total);
    REPORT(B_lv_unit);
    ADREPORT(B_lv_unit);
  }

  // -------- Construct augmented Lambda_B_slope (C x d_B_slope) ----------
  // Ordinary random-regression latent covariance over the augmented
  // coefficient vector (intercept, slope) x trait. This is deliberately
  // separate from the legacy intercept-only Lambda_B path so old fits remain
  // byte-stable and so the new path can have C = 2*n_traits rows.
  matrix<Type> Lambda_B_slope(n_lhs_cols_B_lat, std::max(d_B_slope, 1));
  Lambda_B_slope.setZero();
  // Hoisted out of the `if (use_rr_B_slope == 1)` block (previously local)
  // so the combined-total block below (after the diag_B_slope section) can
  // read its diagonal when both the loadings and diagonal Psi companions
  // are active. Additive only: still zero / unused when use_rr_B_slope == 0.
  matrix<Type> Sigma_B_slope(n_lhs_cols_B_lat, n_lhs_cols_B_lat);
  Sigma_B_slope.setZero();
  if (use_rr_B_slope == 1) {
    if (n_lhs_cols_B_lat < 1)
      error("gllvmTMB_multi: n_lhs_cols_B_lat must be >= 1");
    if (Z_B_lat.rows() != y.size() || Z_B_lat.cols() != n_lhs_cols_B_lat)
      error("gllvmTMB_multi: Z_B_lat must be n_obs x n_lhs_cols_B_lat");
    int p = n_lhs_cols_B_lat;
    int rank = d_B_slope;
    if (z_B_slope.rows() != d_B_slope || z_B_slope.cols() != n_sites)
      error("gllvmTMB_multi: z_B_slope must be d_B_slope x n_sites");
    Lambda_B_slope = gll_unpack_rr_loadings(theta_rr_B_slope, p, rank);
    for (int s = 0; s < n_sites; s++) {
      vector<Type> col_s = z_B_slope.col(s);
      nll -= dnorm(col_s, Type(0), Type(1), true).sum();
    }
    REPORT(Lambda_B_slope);
    Sigma_B_slope = Lambda_B_slope * Lambda_B_slope.transpose();
    REPORT(Sigma_B_slope);
    // Marginal per-augmented-coordinate SD from the loadings block alone
    // (Sigma_B_slope(j,j) = sum_k Lambda_B_slope(j,k)^2, a quadratic form
    // in MULTIPLE theta_rr_B_slope entries -- exactly the "loadings route"
    // slope_sd_ci() slice 1 refuses because a univariate Wald read on a
    // single parameter cannot cover it). ADREPORT so sdreport() runs the
    // delta method against this expression directly; see register row
    // CI-15 and dev/S6-slope-sd-ci-review.md.
    vector<Type> sd_rr_B_slope(n_lhs_cols_B_lat);
    for (int j = 0; j < n_lhs_cols_B_lat; j++)
      sd_rr_B_slope(j) = sqrt(Sigma_B_slope(j, j));
    REPORT(sd_rr_B_slope);
    ADREPORT(sd_rr_B_slope);
  }

  // -------- diag_B contribution ----------------------------------------
  if (use_diag_B == 1) {
    if (theta_diag_B.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_B has wrong length");
    if (diag_B_skip.size() != n_traits)
      error("gllvmTMB_multi: diag_B_skip has wrong length");
    vector<Type> sd_B = exp(theta_diag_B);
    REPORT(sd_B);
    for (int s = 0; s < n_sites; s++) {
      for (int t = 0; t < n_traits; t++) {
        // A trait whose Psi was pinned off carries no between-unit density
        // term.  Including it would add dnorm(0, 0, ~1e-6, log = TRUE), a
        // large POSITIVE constant, once per (trait, site) cell -- which is
        // how a Bernoulli fit could report a positive log-likelihood.
        if (diag_B_skip(t) == 1 || integrate_gaussian_diag_B == 1) continue;
        nll -= dnorm(s_B(t, s), Type(0), sd_B(t), true);
      }
    }
  }

  // -------- augmented diag_B slope contribution ------------------------
  if (use_diag_B_slope == 1) {
    if (n_lhs_cols_B_diag < 1)
      error("gllvmTMB_multi: n_lhs_cols_B_diag must be >= 1");
    if (Z_B_diag.rows() != y.size() || Z_B_diag.cols() != n_lhs_cols_B_diag)
      error("gllvmTMB_multi: Z_B_diag must be n_obs x n_lhs_cols_B_diag");
    if (theta_diag_B_slope.size() != n_lhs_cols_B_diag)
      error("gllvmTMB_multi: theta_diag_B_slope has wrong length");
    if (s_B_slope.rows() != n_lhs_cols_B_diag || s_B_slope.cols() != n_sites)
      error("gllvmTMB_multi: s_B_slope must be n_lhs_cols_B_diag x n_sites");
    vector<Type> sd_B_slope = exp(theta_diag_B_slope);
    REPORT(sd_B_slope);
    matrix<Type> Sigma_B_unique_slope(n_lhs_cols_B_diag, n_lhs_cols_B_diag);
    Sigma_B_unique_slope.setZero();
    for (int j = 0; j < n_lhs_cols_B_diag; j++) {
      Sigma_B_unique_slope(j, j) = sd_B_slope(j) * sd_B_slope(j);
    }
    REPORT(Sigma_B_unique_slope);
    for (int s = 0; s < n_sites; s++) {
      for (int j = 0; j < n_lhs_cols_B_diag; j++) {
        nll -= dnorm(s_B_slope(j, s), Type(0), sd_B_slope(j), true);
      }
    }

    // Combined TOTAL marginal slope SD, i.e. the quantity slope_sd_ci()'s
    // `total_sd` column reports as a point estimate only in slice 1
    // (R/slope-sd-ci.R): sqrt(diag(Sigma_B_slope) + diag(Sigma_B_unique_slope)).
    // When use_rr_B_slope == 1 the shared loadings block is active on the
    // SAME 2*n_traits interleaved augmented coordinates (n_lhs_cols_B_lat ==
    // n_lhs_cols_B_diag whenever both are on -- R/fit-multi.R:2185-2237), so
    // indexing both by j is safe; when use_rr_B_slope == 0, Sigma_B_slope is
    // the untouched zero placeholder above and this reduces to sd_B_slope
    // itself. ADREPORTing this single combined expression (rather than
    // combining two separately-ADREPORTed pieces in R) lets sdreport() take
    // the delta method over the joint covariance of theta_rr_B_slope and
    // theta_diag_B_slope, including any correlation between them -- an R-side
    // sum of two independently-computed SEs could not do that correctly.
    vector<Type> sd_B_slope_total(n_lhs_cols_B_diag);
    for (int j = 0; j < n_lhs_cols_B_diag; j++) {
      Type var_total = Sigma_B_unique_slope(j, j);
      if (use_rr_B_slope == 1) var_total += Sigma_B_slope(j, j);
      sd_B_slope_total(j) = sqrt(var_total);
    }
    REPORT(sd_B_slope_total);
    ADREPORT(sd_B_slope_total);
  }

  // -------- Construct Lambda_W (n_traits x d_W), lower-triangular -------
  matrix<Type> Lambda_W(n_traits, std::max(d_W, 1));
  Lambda_W.setZero();
  if (use_rr_W == 1) {
    int p = n_traits;
    int rank = d_W;
    Lambda_W = gll_unpack_rr_loadings(theta_rr_W, p, rank);
    for (int ss = 0; ss < n_site_species; ss++) {
      vector<Type> col_ss = z_W.col(ss);
      nll -= dnorm(col_ss, Type(0), Type(1), true).sum();
    }
    REPORT(Lambda_W);
    matrix<Type> Sigma_W = Lambda_W * Lambda_W.transpose();
    REPORT(Sigma_W);
  }

  // -------- diag_W contribution ----------------------------------------
  if (use_diag_W == 1) {
    if (theta_diag_W.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_W has wrong length");
    if (diag_W_skip.size() != n_traits)
      error("gllvmTMB_multi: diag_W_skip has wrong length");
    vector<Type> sd_W = exp(theta_diag_W);
    REPORT(sd_W);
    for (int ss = 0; ss < n_site_species; ss++) {
      for (int t = 0; t < n_traits; t++) {
        // A trait whose OLRE was pinned off carries no density term. See the
        // diag_B_skip note above: including it would add
        // dnorm(0, 0, ~1e-6, log = TRUE) once per (trait, site_species) cell.
        if (diag_W_skip(t) == 1) continue;
        nll -= dnorm(s_W(t, ss), Type(0), sd_W(t), true);
      }
    }
  }

  // Source strength for the single admitted structured trait-intercept block.
  // All branching is on fixed DATA; estimated weights stay on the AD tape.
  bool structured_rho_field_active = structured_rho_estimated == 1 ||
    structured_rho_sparse == 0 || asDouble(structured_rho_value) > 0;
  Type structured_rho_wK = Type(1), structured_rho_wD = Type(0);
  Type rho_structured = structured_rho_value;
  if (structured_rho_estimated == 1) {
    structured_rho_wK = exp(-Type(0.5) * logspace_add(Type(0), -eta_structured_rho));
    structured_rho_wD = exp(-Type(0.5) * logspace_add(Type(0), eta_structured_rho));
    rho_structured = structured_rho_wK * structured_rho_wK;
    REPORT(rho_structured); // point estimate only; no interval contract
  } else if (structured_rho_sparse == 1 || structured_rho_spatial == 1) {
    structured_rho_wK = sqrt(structured_rho_value);
    structured_rho_wD = sqrt(Type(1) - structured_rho_value);
  }
  bool structured_rho_dense_estimated = structured_rho_estimated == 1 &&
    structured_rho_sparse == 0 && structured_rho_spatial == 0;
  vector<Type> structured_rho_spectral_var(structured_rho_eigenvalues.size());
  Type structured_rho_logdet = Type(0);
  if (structured_rho_dense_estimated) {
    for (int j = 0; j < n_species; j++) {
      structured_rho_spectral_var(j) = structured_rho_wD * structured_rho_wD +
        rho_structured * structured_rho_eigenvalues(j);
      structured_rho_logdet += log(structured_rho_diagonal(j)) +
        log(structured_rho_spectral_var(j));
    }
  }
  auto structured_rho_quad = [&](const vector<Type>& field) -> Type {
    Type quad = Type(0);
    for (int j = 0; j < n_species; j++) {
      Type projected = Type(0);
      for (int i = 0; i < n_species; i++) {
        projected += structured_rho_eigenvectors(i,j) * field(i) /
          sqrt(structured_rho_diagonal(i));
      }
      quad += projected * projected / structured_rho_spectral_var(j);
    }
    return quad;
  };

  // -------- propto phylogenetic random effect (per trait) ---------------
  // For each trait t, p_phy.col(t) ~ MVN(0, exp(loglambda_phy) * Cphy)
  // -log p = 0.5 * (n_species*log(2*pi) + n_species*loglambda_phy + log_det_Cphy
  //                + exp(-loglambda_phy) * p_t' Cphy_inv p_t)
  if (use_propto == 1) {
    Type lam_phy = exp(loglambda_phy);
    Type inv_lam = exp(-loglambda_phy);
    for (int t = 0; t < n_traits; t++) {
      vector<Type> p_t = p_phy.col(t);
      Type quad = (p_t.matrix().transpose() * Cphy_inv * p_t.matrix())(0, 0);
      if (structured_rho_dense_estimated) quad = structured_rho_quad(p_t);
      nll += 0.5 * (Type(n_species) * log(2.0 * M_PI)
                    + Type(n_species) * loglambda_phy
                    + (structured_rho_dense_estimated ? structured_rho_logdet : log_det_Cphy)
                    + inv_lam * quad);
    }
    REPORT(lam_phy);
  }

  // -------- diag(0 + trait | species) -- non-phylo q_it ----------------
  if (use_diag_species == 1) {
    if (theta_diag_species.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_species has wrong length");
    vector<Type> sd_q = exp(theta_diag_species);
    REPORT(sd_q);
    for (int i = 0; i < n_species; i++) {
      for (int t = 0; t < n_traits; t++)
        nll -= dnorm(q_sp(t, i), Type(0), sd_q(t), true);
    }
  }

  // -------- diag(0 + trait | cluster2) -- 2nd-grouping per-trait var ----
  // Renamed copy of the diag_species block on the cluster2 grouping.
  if (use_diag_cluster2 == 1) {
    if (theta_diag_cluster2.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_cluster2 has wrong length");
    vector<Type> sd_c2 = exp(theta_diag_cluster2);
    REPORT(sd_c2);
    for (int i = 0; i < n_cluster2; i++) {
      for (int t = 0; t < n_traits; t++)
        nll -= dnorm(r_c2(t, i), Type(0), sd_c2(t), true);
    }
  }

  // -------- Stage-35 phylo_rr (PGLLVM) ----------------------------------
  // For each phylogenetic factor k, g_phy.col(k) ~ N(0, A_phy). Apply
  // the lower-triangular rr() identifiability convention to Lambda_phy
  // (re-using the same packed layout as theta_rr_B / theta_rr_W).
  matrix<Type> Lambda_phy(n_traits, std::max(d_phy, 1));
  Lambda_phy.setZero();
  if (use_phylo_rr == 1) {
    int p = n_traits;
    int rank = d_phy;
    Lambda_phy = gll_unpack_rr_loadings(theta_rr_phy, p, rank);
    // Prior: each column of g_phy is N(0, A), evaluated through the sparse Ainv.
    // -log p(g_k) = 0.5 * (n_aug_phy * log(2pi) + log_det_A + g_k' Ainv g_k)
    // In the Stage-40 sparse-$A^{-1}$ path n_aug_phy = n_tip + Nnode - 1, i.e.
    // one row per EDGE of the tree (tips + internal nodes, root excluded) --
    // 2*n_tips - 2 only when the tree is fully bifurcating, and never
    // 2*n_tips - 1. In the legacy dense path n_aug_phy == n_species.
    if (structured_rho_field_active) for (int k = 0; k < d_phy; k++) {
      vector<Type> g_k = g_phy.col(k);
      Type quad = (g_k.matrix().transpose() * Ainv_phy_rr * g_k.matrix())(0, 0);
      if (structured_rho_dense_estimated) quad = structured_rho_quad(g_k);
      nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                    + (structured_rho_dense_estimated ? structured_rho_logdet : log_det_A_phy_rr) + quad);
    }
    if (structured_rho_sparse == 1) {
      for (int j = 0; j < n_species; j++)
        for (int k = 0; k < d_phy; k++)
          nll -= dnorm(g_phy_iid(j, k), Type(0), Type(1), true);
    }
    REPORT(Lambda_phy);
    matrix<Type> Sigma_phy = Lambda_phy * Lambda_phy.transpose();
    REPORT(Sigma_phy);
  }

  // -------- Two-U PGLLVM phylo_diag (per-trait phylo random intercept) ---
  // Each trait column g_phy_diag.col(t) ~ N(0, A) with the same A^-1 as
  // phylo_rr, scaled by exp(log_sd_phy_diag(t)). The contribution to eta
  // is eta(o) += exp(log_sd_phy_diag(t)) * g_phy_diag(species_aug_id(o), t),
  // which is equivalent to drawing a per-trait phylogenetic intercept
  // u_t ~ N(0, sd^2 * A). The trait-by-trait diagonal U_phy =
  // diag(exp(2 * log_sd_phy_diag)) is the "unique" phylogenetic component
  // (Hadfield & Nakagawa 2010; Meyer & Kirkpatrick 2008).
  vector<Type> sd_phy_diag(n_traits);
  matrix<Type> Sigma_phy_diag(n_traits, n_traits);
  if (use_phylo_diag == 1) {
    if (log_sd_phy_diag.size() != n_traits)
      error("gllvmTMB_multi: log_sd_phy_diag has wrong length");
    for (int t = 0; t < n_traits; t++) sd_phy_diag(t) = exp(log_sd_phy_diag(t));
    REPORT(sd_phy_diag);
    ADREPORT(sd_phy_diag);
    Sigma_phy_diag.setZero();
    for (int t = 0; t < n_traits; t++)
      Sigma_phy_diag(t, t) = sd_phy_diag(t) * sd_phy_diag(t);
    REPORT(Sigma_phy_diag);
    // Prior: each column ~ N(0, A).
    // -log p(g_t) = 0.5 * (n_aug_phy * log(2pi) + log_det_A + g_t' Ainv g_t)
    if (structured_rho_field_active) for (int t = 0; t < n_traits; t++) {
      vector<Type> g_t = g_phy_diag.col(t);
      Type quad = (g_t.matrix().transpose() * Ainv_phy_rr * g_t.matrix())(0, 0);
      if (structured_rho_dense_estimated) quad = structured_rho_quad(g_t);
      nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                    + (structured_rho_dense_estimated ? structured_rho_logdet : log_det_A_phy_rr) + quad);
    }
    if (structured_rho_sparse == 1) {
      for (int j = 0; j < n_species; j++)
        for (int t = 0; t < n_traits; t++)
          nll -= dnorm(g_phy_diag_iid(j, t), Type(0), Type(1), true);
    }
  }

  // -------- Generic dense multi-kernel tiers (Design 65 C3.1) --------------
  array<Type> Lambda_kernel(n_traits, std::max(max_kernel_rank, 1),
                            std::max(n_kernel_tiers, 1));
  array<Type> Sigma_kernel(n_traits, n_traits, std::max(n_kernel_tiers, 1));
  matrix<Type> sd_kernel_diag(n_traits, std::max(n_kernel_tiers, 1));
  Lambda_kernel.setZero();
  Sigma_kernel.setZero();
  sd_kernel_diag.setZero();
  if (n_kernel_tiers > 0) {
    if (kernel_group_id.size() != y.size())
      error("gllvmTMB_multi: kernel_group_id must have length n_obs");
    if (kernel_rank.size() != n_kernel_tiers ||
        kernel_has_latent.size() != n_kernel_tiers ||
        kernel_has_diag.size() != n_kernel_tiers ||
        kernel_g_offset.size() != n_kernel_tiers ||
        kernel_logsd_offset.size() != n_kernel_tiers ||
        kernel_diag_offset.size() != n_kernel_tiers ||
        log_det_A_kernel.size() != n_kernel_tiers)
      error("gllvmTMB_multi: kernel tier metadata has wrong length");
    if (Ainv_kernel.dim.size() != 3)
      error("gllvmTMB_multi: Ainv_kernel must be a 3D array");
    if (Ainv_kernel.dim[0] != n_kernel_tiers ||
        Ainv_kernel.dim[1] != n_kernel_levels ||
        Ainv_kernel.dim[2] != n_kernel_levels)
      error("gllvmTMB_multi: Ainv_kernel dimensions do not match kernel metadata");

    int theta_pos = 0;
    int expected_g = 0;
    int expected_logsd = 0;
    int expected_diag = 0;
    for (int r = 0; r < n_kernel_tiers; r++) {
      int rank = kernel_rank(r);
      if (rank < 1 || rank > n_traits)
        error("gllvmTMB_multi: invalid kernel rank");
      int len_theta = n_traits * rank - rank * (rank - 1) / 2;
      if (kernel_has_latent(r) != 1)
        error("gllvmTMB_multi: multi-kernel first wave requires latent tiers");
      if (kernel_g_offset(r) != expected_g)
        error("gllvmTMB_multi: kernel_g_offset mismatch");
      if (theta_pos + len_theta > theta_rr_kernel.size())
        error("gllvmTMB_multi: theta_rr_kernel has wrong length");

      vector<Type> theta_r = theta_rr_kernel.segment(theta_pos, len_theta);
      theta_pos += len_theta;
      expected_g += n_kernel_levels * rank;
      matrix<Type> loading_r =
        gll_unpack_rr_loadings(theta_r, n_traits, rank);
      for (int j = 0; j < rank; j++) {
        for (int i = 0; i < n_traits; i++) {
          Lambda_kernel(i, j, r) = loading_r(i, j);
        }
      }
      for (int i = 0; i < n_traits; i++) {
        for (int j = 0; j < n_traits; j++) {
          Type s = 0;
          for (int k = 0; k < rank; k++)
            s += Lambda_kernel(i, k, r) * Lambda_kernel(j, k, r);
          Sigma_kernel(i, j, r) = s;
        }
      }

      int goff = kernel_g_offset(r);
      for (int k = 0; k < rank; k++) {
        Type quad = 0;
        for (int i = 0; i < n_kernel_levels; i++) {
          Type gi = g_kernel(goff + i * rank + k);
          for (int j = 0; j < n_kernel_levels; j++) {
            Type gj = g_kernel(goff + j * rank + k);
            quad += gi * Ainv_kernel(r, i, j) * gj;
          }
        }
        nll += Type(0.5) * (Type(n_kernel_levels) * log(2.0 * M_PI)
                            + log_det_A_kernel(r) + quad);
      }

      if (kernel_has_diag(r) == 1) {
        if (kernel_logsd_offset(r) != expected_logsd ||
            kernel_diag_offset(r) != expected_diag)
          error("gllvmTMB_multi: kernel Psi offset mismatch");
        int lsoff = kernel_logsd_offset(r);
        int doff = kernel_diag_offset(r);
        for (int t = 0; t < n_traits; t++) {
          sd_kernel_diag(t, r) = exp(log_sd_kernel_diag(lsoff + t));
          Type quad = 0;
          for (int i = 0; i < n_kernel_levels; i++) {
            Type gi = g_kernel_diag(doff + i * n_traits + t);
            for (int j = 0; j < n_kernel_levels; j++) {
              Type gj = g_kernel_diag(doff + j * n_traits + t);
              quad += gi * Ainv_kernel(r, i, j) * gj;
            }
          }
          nll += Type(0.5) * (Type(n_kernel_levels) * log(2.0 * M_PI)
                              + log_det_A_kernel(r) + quad);
        }
        expected_logsd += n_traits;
        expected_diag += n_kernel_levels * n_traits;
      }
    }
    if (theta_pos != theta_rr_kernel.size() ||
        expected_g != g_kernel.size() ||
        expected_logsd != log_sd_kernel_diag.size() ||
        expected_diag != g_kernel_diag.size())
      error("gllvmTMB_multi: flat multi-kernel parameter lengths mismatch");
    REPORT(Lambda_kernel);
    REPORT(Sigma_kernel);
    REPORT(sd_kernel_diag);
  }

  // -------- Q6: phylo_slope prior --------------------------------------
  // Legacy path: b_phy_slope ~ N(0, sigma_slope^2 * A_phy), evaluated
  // through the sparse Ainv. The augmented path below is live (parser
  // activation has landed); keeping this branch active preserves current
  // phylo_slope() fits and parameter names byte-for-byte.
  // -log p(b) = 0.5 * (n_aug_phy_slope * log(2pi)
  //                    + 2 n_aug_phy_slope log_sigma_slope
  //                    + log_det_A_phy_slope
  //                    + b' Ainv b / sigma_slope^2)
  if (use_phylo_slope == 1 && use_phylo_slope_correlated == 0) {
    if (b_phy_slope.size() != n_aug_phy_slope ||
        Ainv_phy_slope.rows() != n_aug_phy_slope ||
        Ainv_phy_slope.cols() != n_aug_phy_slope ||
        phylo_slope_aug_id.size() != y.size())
      error("gllvmTMB_multi: legacy phylo_slope dimensions are inconsistent");
    for (int o = 0; o < y.size(); ++o)
      if (phylo_slope_aug_id(o) < 0 || phylo_slope_aug_id(o) >= n_aug_phy_slope)
        error("gllvmTMB_multi: legacy phylo_slope RHS map is out of bounds");
    Type sigma_slope = exp(log_sigma_slope);
    Type sigma_slope2 = sigma_slope * sigma_slope;
    vector<Type> b = b_phy_slope;
    Type quad = (b.matrix().transpose() * Ainv_phy_slope * b.matrix())(0, 0);
    nll += 0.5 * (Type(n_aug_phy_slope) * log(2.0 * M_PI)
                  + Type(2) * Type(n_aug_phy_slope) * log_sigma_slope
                  + log_det_A_phy_slope
                  + quad / sigma_slope2);
    REPORT(sigma_slope);
  }
  // Physical coefficients enter predictors and reports even when the private
  // parameter block contains standardized U. Preserve the centred fallback.
  array<Type> b_phy_aug_physical = b_phy_aug;
  // Augmented path (live): vec(B) ~ N(0, Sigma_b \otimes A_phy), where
  // Sigma_b is block-local across LHS columns (1 = legacy slope-only;
  // 2 = intercept + slope). Driven by the phylo_unique / phylo_indep /
  // phylo_dep parser routes.
  if (use_phylo_slope_correlated == 1) {
    // Closed-form covariance paths (unique / indep / legacy) require
    // n_lhs_cols in {1, 2}. The phylo_dep slope path (use_phylo_dep_slope
    // == 1) lifts this cap: there C = 2*n_traits and Sigma_b is the full
    // unstructured C x C built from theta_dep_chol.
    if (use_phylo_dep_slope == 0 && (n_lhs_cols < 1 || n_lhs_cols > 2))
      error("gllvmTMB_multi: n_lhs_cols must be 1 or 2 in the closed-form augmented path");
    if (use_phylo_dep_slope == 1 && n_lhs_cols < 1)
      error("gllvmTMB_multi: n_lhs_cols must be >= 1 in the phylo_dep slope path");
    if (b_phy_aug.dim.size() != 3 || Z_phy_aug.dim.size() != 3)
      error("gllvmTMB_multi: b_phy_aug and Z_phy_aug must be 3D arrays");
    int n_aug_phy_aug = use_phylo_column_slope == 1 ?
      n_aug_phy_slope : n_aug_phy;
    if (use_phylo_column_slope == 1) {
      if (n_aug_phy_slope < 1 ||
          Ainv_phy_slope.rows() != n_aug_phy_slope ||
          Ainv_phy_slope.cols() != n_aug_phy_slope ||
          phylo_slope_aug_id.size() != y.size())
        error("gllvmTMB_multi: column-slope phylogenetic source dimensions are inconsistent");
      for (int o = 0; o < y.size(); ++o)
        if (phylo_slope_aug_id(o) < 0 ||
            phylo_slope_aug_id(o) >= n_aug_phy_slope)
          error("gllvmTMB_multi: column-slope RHS map is out of bounds");
      if (use_column_coef_estimated_rho == 1 &&
          (column_coef_source_U.rows() != n_aug_phy_slope ||
           column_coef_source_U.cols() != n_aug_phy_slope ||
           column_coef_source_lambda.size() != n_aug_phy_slope ||
           column_coef_source_inv_d.size() != n_aug_phy_slope))
        error("gllvmTMB_multi: estimated-rho spectral source dimensions are inconsistent");
    }
    if (b_phy_aug.dim[0] != n_aug_phy_aug)
      error("gllvmTMB_multi: b_phy_aug first dimension has wrong phylogenetic source size");
    if (b_phy_aug.dim[1] != n_lhs_cols || Z_phy_aug.dim[1] != n_lhs_cols)
      error("gllvmTMB_multi: n_lhs_cols does not match augmented phylo arrays");
    if (Z_phy_aug.dim[0] != y.size())
      error("gllvmTMB_multi: Z_phy_aug first dimension must equal n_obs");
    if (Z_phy_aug.dim[2] != b_phy_aug.dim[2])
      error("gllvmTMB_multi: Z_phy_aug and b_phy_aug block counts differ");

    if (use_phylo_dep_slope == 1) {
      // ---- phylo_dep slope: full unstructured C x C Sigma_b = L L^T -----
      // theta_dep_chol packs L (C x C lower-triangular) as: the C diagonal
      // entries are exp(theta_dep_chol[j]) (strictly positive, identified);
      // the strictly-lower entries follow in column-major order. Hence
      // Sigma_b = L L^T is symmetric positive-definite by construction --
      // the natural unrestricted parameterisation of an unstructured
      // covariance (Pinheiro & Bates 1996). Length C(C+1)/2.
      int C = n_lhs_cols;
      int n_chol = C * (C + 1) / 2;
      if (theta_dep_chol.size() != n_chol)
        error("gllvmTMB_multi: theta_dep_chol has wrong length for phylo_dep slope");
      matrix<Type> Lb(C, C);
      Lb.setZero();
      {
        int idx = 0;
        // Diagonal first (exp-transformed for positivity / identifiability).
        for (int j = 0; j < C; j++) {
          Lb(j, j) = exp(theta_dep_chol(idx));
          idx++;
        }
        // Strictly-lower entries, column-major (j = col, i = row > j).
        for (int j = 0; j < C; j++) {
          for (int i = j + 1; i < C; i++) {
            Lb(i, j) = theta_dep_chol(idx);
            idx++;
          }
        }
      }
      matrix<Type> Sigma_b_dep = Lb * Lb.transpose();
      // log det Sigma_b = 2 * sum_j log L_jj.
      Type logdet_Sigma_b = Type(0);
      for (int j = 0; j < C; j++) logdet_Sigma_b += Type(2) * log(Lb(j, j));
      // Report the recovered SDs and correlation matrix for extractors/tests.
      vector<Type> sd_b(C);
      for (int j = 0; j < C; j++) sd_b(j) = sqrt(Sigma_b_dep(j, j));
      REPORT(sd_b);
      // ADREPORT so sdreport() runs the delta method against the
      // authoritative theta_dep_chol packing itself (sd_b(j) = sqrt(sum_k
      // Lb(j,k)^2) is a nonlinear function of MULTIPLE theta_dep_chol
      // entries whenever j has off-diagonal L entries below it -- e.g. for
      // C = 2*n_traits interleaved (intercept, slope) per trait, a slope
      // coordinate's marginal SD can depend on more than one packed entry).
      // This is deliberately additive: it changes nothing about sd_b's
      // value or REPORT, only adds it to the sdreport payload so the R-side
      // slope_sd_ci() extractor can read a name instead of hand-indexing
      // cov.fixed against this packing (see dev/S6-slope-sd-ci-review.md
      // and register row CI-15).
      ADREPORT(sd_b);
      matrix<Type> cor_b_mat(C, C);
      for (int a = 0; a < C; a++)
        for (int bcol = 0; bcol < C; bcol++)
          cor_b_mat(a, bcol) = Sigma_b_dep(a, bcol) / (sd_b(a) * sd_b(bcol));
      REPORT(cor_b_mat);
      REPORT(Sigma_b_dep);
      matrix<Type> prior_L = Lb;
      if (standardize_column_coef == 1) {
        // B = U L'. Independent source-prior columns of U have identity
        // coefficient covariance: no inverse L enters their random Hessian.
        prior_L.setZero();
        for (int j = 0; j < C; ++j) prior_L(j, j) = Type(1);
        for (int k = 0; k < b_phy_aug.dim[2]; ++k)
          for (int i = 0; i < n_aug_phy_aug; ++i)
            for (int j = 0; j < C; ++j) {
              Type value = Type(0);
              for (int l = 0; l <= j; ++l)
                value += b_phy_aug(i, l, k) * Lb(j, l);
              b_phy_aug_physical(i, j, k) = value;
            }
      }
      Type column_coef_rho = invlogit(eta_column_coef_rho);
      Type column_coef_logdet_K_rho = log_det_A_phy_slope;
      if (use_column_coef_estimated_rho == 1) {
        column_coef_logdet_K_rho = column_coef_source_logdet_D2;
        for (int i = 0; i < n_aug_phy_slope; ++i) {
          Type s_i = Type(1) - column_coef_rho +
            column_coef_rho * column_coef_source_lambda(i);
          column_coef_logdet_K_rho += log(s_i);
        }
        REPORT(column_coef_rho);
        ADREPORT(column_coef_rho);
        REPORT(column_coef_logdet_K_rho);
      }
      // Centred: -log p(B) = .5[n*C*log(2pi) + n*logdet(Sigma_b)
      //                         + C*logdet(K) + tr(Sigma_b^{-1} B' K^-1 B)].
      // Standardized: p(U) is normalized with identity coefficient covariance.
      // The change-of-variable Jacobian cancels the coefficient determinant;
      // adding it again would alter the marginal likelihood.
      for (int k = 0; k < b_phy_aug.dim[2]; k++) {
        // Gather the source-by-coefficient deviations for this block.
        matrix<Type> Bmat(n_aug_phy_aug, C);
        for (int j = 0; j < C; j++)
          for (int i = 0; i < n_aug_phy_aug; i++) Bmat(i, j) = b_phy_aug(i, j, k);
        Type quad = gll_column_coef_quad(
          Bmat, prior_L, use_phylo_column_slope == 1 ? Ainv_phy_slope : Ainv_phy_rr,
          use_column_coef_estimated_rho, column_coef_source_U,
          column_coef_source_lambda, column_coef_source_inv_d, column_coef_rho);
        nll += Type(0.5) * (Type(n_aug_phy_aug * C) * log(2.0 * M_PI)
                            + (standardize_column_coef == 1 ? Type(0) :
                               Type(n_aug_phy_aug) * logdet_Sigma_b)
                            + Type(C) * (use_column_coef_estimated_rho == 1 ?
                              column_coef_logdet_K_rho :
                              (use_phylo_column_slope == 1 ? log_det_A_phy_slope : log_det_A_phy_rr))
                            + quad);
      }
    } else {
    if (log_sd_b.size() != n_lhs_cols)
      error("gllvmTMB_multi: log_sd_b has wrong length");
    int n_cor_b = n_lhs_cols * (n_lhs_cols - 1) / 2;
    if (atanh_cor_b.size() != n_cor_b)
      error("gllvmTMB_multi: atanh_cor_b has wrong length");

    vector<Type> sd_b(n_lhs_cols);
    for (int j = 0; j < n_lhs_cols; j++) sd_b(j) = exp(log_sd_b(j));
    REPORT(sd_b);
    if (n_lhs_cols == 1) {
      Type sd0 = sd_b(0);
      Type inv00 = Type(1) / (sd0 * sd0);
      Type logdet_Sigma_b = Type(2) * log_sd_b(0);
      for (int k = 0; k < b_phy_aug.dim[2]; k++) {
        vector<Type> b0(n_aug_phy);
        for (int i = 0; i < n_aug_phy; i++) b0(i) = b_phy_aug(i, 0, k);
        Type quad00 = (b0.matrix().transpose() * Ainv_phy_rr * b0.matrix())(0, 0);
        nll += Type(0.5) * (Type(n_aug_phy) * log(2.0 * M_PI)
                            + Type(n_aug_phy) * logdet_Sigma_b
                            + log_det_A_phy_rr
                            + inv00 * quad00);
      }
    } else {
      Type rho = tanh(atanh_cor_b(0));
      Type one_minus_rho2 = Type(1) - rho * rho;
      Type inv00 = Type(1) / (sd_b(0) * sd_b(0) * one_minus_rho2);
      Type inv11 = Type(1) / (sd_b(1) * sd_b(1) * one_minus_rho2);
      Type inv01 = -rho / (sd_b(0) * sd_b(1) * one_minus_rho2);
      Type logdet_Sigma_b = Type(2) * log_sd_b(0) +
                             Type(2) * log_sd_b(1) +
                             log(one_minus_rho2);
      vector<Type> cor_b(1);
      cor_b(0) = rho;
      REPORT(cor_b);
      for (int k = 0; k < b_phy_aug.dim[2]; k++) {
        vector<Type> b0(n_aug_phy);
        vector<Type> b1(n_aug_phy);
        for (int i = 0; i < n_aug_phy; i++) {
          b0(i) = b_phy_aug(i, 0, k);
          b1(i) = b_phy_aug(i, 1, k);
        }
        Type quad00 = (b0.matrix().transpose() * Ainv_phy_rr * b0.matrix())(0, 0);
        Type quad01 = (b0.matrix().transpose() * Ainv_phy_rr * b1.matrix())(0, 0);
        Type quad11 = (b1.matrix().transpose() * Ainv_phy_rr * b1.matrix())(0, 0);
        Type quad = inv00 * quad00 + Type(2) * inv01 * quad01 + inv11 * quad11;
        nll += Type(0.5) * (Type(n_aug_phy * n_lhs_cols) * log(2.0 * M_PI)
                            + Type(n_aug_phy) * logdet_Sigma_b
                            + Type(n_lhs_cols) * log_det_A_phy_rr
                            + quad);
      }
    }
    }  // end closed-form (use_phylo_dep_slope == 0) branch
  }

  if (standardize_column_coef == 1) {
    REPORT(b_phy_aug_physical);
    // U remains a random effect. Delta-method propagation through U and L
    // includes their joint uncertainty; there is no eliminated-effect add-on.
    ADREPORT(b_phy_aug_physical);
  }

  // -------- phylo_latent slope (Design 56 Sec. 5.3 / 9.5a) -------------
  // Block-diagonal reduced-rank random regression on the phylogeny. For each
  // LHS column k, build an independent loading matrix Lambda_k (n_traits x
  // d_phy_slope, lower-triangular rr() convention) and place an independent
  // N(0, A) prior on each of the d_phy_slope factor-score columns
  // g_phy_slope[ , f, k]. The negative log prior is the standard MVN constant
  // 0.5*(n_aug*log2pi + log|A|) plus 0.5*g' Ainv g, summed over the
  // n_lhs_cols_lat * d_phy_slope independent latent columns -- the existing
  // phylo_rr prior loop replicated across an extra LHS-column axis. There is
  // no cross-column (intercept-slope) term: the cross-column covariance
  // blocks are exactly zero (the Sec. 5.3 "block-diagonal across LHS columns"
  // semantics). Lambda_phy_slope is REPORTed per column for extraction.
  array<Type> Lambda_phy_slope(n_traits, std::max(d_phy_slope, 1),
                               std::max(n_lhs_cols_lat, 1));
  Lambda_phy_slope.setZero();
  if (use_phylo_latent_slope == 1) {
    if (n_lhs_cols_lat < 1 || n_lhs_cols_lat > 2)
      error("gllvmTMB_multi: n_lhs_cols_lat must be 1 or 2");
    if (g_phy_slope.dim.size() != 3)
      error("gllvmTMB_multi: g_phy_slope must be a 3D array");
    if (g_phy_slope.dim[0] != n_aug_phy)
      error("gllvmTMB_multi: g_phy_slope first dimension must equal n_aug_phy");
    if (g_phy_slope.dim[1] != d_phy_slope)
      error("gllvmTMB_multi: g_phy_slope second dimension must equal d_phy_slope");
    if (g_phy_slope.dim[2] != n_lhs_cols_lat)
      error("gllvmTMB_multi: g_phy_slope third dimension must equal n_lhs_cols_lat");
    if (Z_phy_lat.rows() != y.size() || Z_phy_lat.cols() != n_lhs_cols_lat)
      error("gllvmTMB_multi: Z_phy_lat must be n_obs x n_lhs_cols_lat");
    int p = n_traits;
    int rank = d_phy_slope;
    int len_per_col = p * rank - rank * (rank - 1) / 2;
    if (theta_rr_phy_slope.size() != n_lhs_cols_lat * len_per_col)
      error("gllvmTMB_multi: theta_rr_phy_slope has wrong length");
    // Build each per-column Lambda_k from its packed lower-triangular slice.
    for (int kcol = 0; kcol < n_lhs_cols_lat; kcol++) {
      vector<Type> theta_k =
        theta_rr_phy_slope.segment(kcol * len_per_col, len_per_col);
      matrix<Type> loading_k = gll_unpack_rr_loadings(theta_k, p, rank);
      for (int j = 0; j < rank; j++) {
        for (int i = 0; i < p; i++) {
          Lambda_phy_slope(i, j, kcol) = loading_k(i, j);
        }
      }
    }
    // Independent N(0, A) prior on every factor-score column.
    for (int kcol = 0; kcol < n_lhs_cols_lat; kcol++) {
      for (int f = 0; f < d_phy_slope; f++) {
        vector<Type> g_kf(n_aug_phy);
        for (int i = 0; i < n_aug_phy; i++) g_kf(i) = g_phy_slope(i, f, kcol);
        Type quad = (g_kf.matrix().transpose() * Ainv_phy_rr * g_kf.matrix())(0, 0);
        nll += Type(0.5) * (Type(n_aug_phy) * log(2.0 * M_PI)
                            + log_det_A_phy_rr + quad);
      }
    }
    REPORT(Lambda_phy_slope);
    // Per-column Sigma_k = Lambda_k Lambda_k^T for extraction / recovery.
    matrix<Type> L0(n_traits, std::max(d_phy_slope, 1));
    matrix<Type> L1(n_traits, std::max(d_phy_slope, 1));
    for (int j = 0; j < std::max(d_phy_slope, 1); j++)
      for (int i = 0; i < n_traits; i++) {
        L0(i, j) = Lambda_phy_slope(i, j, 0);
        L1(i, j) = (n_lhs_cols_lat > 1) ? Lambda_phy_slope(i, j, 1) : Type(0);
      }
    matrix<Type> Sigma_phy_slope_intercept = L0 * L0.transpose();
    matrix<Type> Sigma_phy_slope_slope = L1 * L1.transpose();
    REPORT(Sigma_phy_slope_intercept);
    REPORT(Sigma_phy_slope_slope);
  }

  // -------- spde: per-trait SPDE GMRF prior on omega columns -----------
  // Marriage step: glmmTMB-style covstruct dispatch + sdmTMB-style sparse Q.
  // Two paths share the same Q_base = kappa^4 M0 + 2 kappa^2 M1 + M2:
  //
  //   * per-trait path (spde_lv_k == 0): one omega_spde column per trait,
  //     each scaled by its own tau_t -- prior N(0, (tau_t^2 Q_base)^-1).
  //     Used by spatial_unique() and spatial_scalar() (the latter ties the
  //     log_tau_spde entries via the R-side TMB map).
  //   * spatial_latent path (spde_lv_k >= 1): K_S shared spatial fields in
  //     omega_spde_lv with prior GMRF(Q_base) (tau == 1, scale absorbed
  //     into Lambda_spde for identifiability), and a packed
  //     lower-triangular Lambda_spde (n_traits x K_S) loading matrix.
  //     If spde_lv_unique == 1, also keep the per-trait omega_spde block as
  //     the diagonal Psi_spde companion.
  matrix<Type> Lambda_spde(n_traits, std::max(spde_lv_k, 1));
  Lambda_spde.setZero();
  vector<Type> spatial_rho_diagonal(spatial_rho_A.rows());
  spatial_rho_diagonal.setOnes();
  bool spatial_rho_field_active = structured_rho_spatial == 0 ||
    structured_rho_estimated == 1 || asDouble(structured_rho_value) > 0;
  if (use_spde == 1) {
    Type kappa  = exp(log_kappa_spde);
    Type kappa2 = kappa * kappa;
    Type kappa4 = kappa2 * kappa2;
    Eigen::SparseMatrix<Type> Q_base =
      kappa4 * spde_M0 + Type(2.0) * kappa2 * spde_M1 + spde_M2;
    if (structured_rho_spatial == 1) {
      // One sparse factorization, one projected-variance solve per location.
      // Keep kappa on the AD tape; neither Q^-1 nor a full K is materialized.
      Eigen::SimplicialLDLT< Eigen::SparseMatrix<Type> > spatial_ldlt(Q_base);
      Eigen::SparseMatrix<Type> spatial_rho_At = spatial_rho_A.transpose();
      for (int j=0; j<spatial_rho_A.rows(); j++) {
        matrix<Type> a(Q_base.rows(),1);
        a.setZero();
        for (typename Eigen::SparseMatrix<Type>::InnerIterator it(spatial_rho_At,j); it; ++it)
          a(it.row(),0) = it.value();
        matrix<Type> solved = spatial_ldlt.solve(a);
        spatial_rho_diagonal(j) = (a.transpose()*solved)(0,0);
      }
      REPORT(spatial_rho_diagonal);
    }
    if (spde_lv_k == 0 || spde_lv_unique == 1) {
      // Per-trait path, or diagonal Psi companion for spatial_latent(unique=TRUE).
      for (int t = 0; t < n_traits; t++) {
        Type tau = exp(log_tau_spde(t));
        vector<Type> omega_t = omega_spde.col(t);
        if (spatial_rho_field_active) nll += SCALE(GMRF(Q_base), Type(1.0) / tau)(omega_t);
        if (structured_rho_spatial == 1) for(int j=0;j<omega_spde_iid.rows();j++)
          nll -= dnorm(omega_spde_iid(j,t),Type(0),Type(1),true);
      }
      REPORT(log_tau_spde);
    }
    if (spde_lv_k > 0) {
      // spatial_latent: build Lambda_spde from packed lower-triangular
      // theta_rr_spde_lv (same layout as theta_rr_B/W/phy).
      int p = n_traits;
      int rank = spde_lv_k;
      Lambda_spde = gll_unpack_rr_loadings(theta_rr_spde_lv, p, rank);
      // Prior on each column of omega_spde_lv: GMRF(Q_base) (no tau scale --
      // absorbed into Lambda_spde).
      for (int k = 0; k < spde_lv_k; k++) {
        vector<Type> omega_k = omega_spde_lv.col(k);
        if (spatial_rho_field_active) nll += GMRF(Q_base)(omega_k);
        if (structured_rho_spatial == 1) for(int j=0;j<omega_spde_lv_iid.rows();j++)
          nll -= dnorm(omega_spde_lv_iid(j,k),Type(0),Type(1),true);
      }
      REPORT(Lambda_spde);
      matrix<Type> Sigma_spde_shared = Lambda_spde * Lambda_spde.transpose();
      matrix<Type> Sigma_spde = Sigma_spde_shared;
      REPORT(Sigma_spde_shared);
      if (spde_lv_unique == 1) {
        vector<Type> sd_spde_unique(n_traits);
        vector<Type> Psi_spde_unique(n_traits);
        for (int t = 0; t < n_traits; t++) {
          Type tau = exp(log_tau_spde(t));
          sd_spde_unique(t) = Type(1.0) / tau;
          Psi_spde_unique(t) = sd_spde_unique(t) * sd_spde_unique(t);
          Sigma_spde(t, t) += Psi_spde_unique(t);
        }
        REPORT(sd_spde_unique);
        REPORT(Psi_spde_unique);
      }
      REPORT(Sigma_spde);
    }
    REPORT(kappa);
  }

  // -------- BASE augmented SPDE slope: vec(Omega) ~ N(0, Sigma_field (x) Q^-1)
  // Omega = [omega_alpha | omega_beta] is n_mesh x n_lhs_cols_spde, drawn on
  // the SAME mesh / Q_base (same kappa) as the intercept field. Sigma_field is
  // the 2x2 cross-field covariance, shared across traits (BASE unique case).
  //
  // The negative-log-density is computed by REUSING density::GMRF(Q_base):
  //   GMRF(Q)(x) = 0.5*( n log(2pi) - logdet(Q) + x' Q x )   [TMB convention]
  // For the 2-column matrix-normal prior with precision Sigma_field^-1 (x) Q,
  //   nll = GMRF(Q)(om0) + GMRF(Q)(om1)               // gives 2n log2pi - 2 logdetQ + q00 + q11
  //       + 0.5 * n_mesh * logdet(Sigma_field)
  //       + 0.5 * [ (Sinv00 - 1) q00 + (Sinv11 - 1) q11 + 2 Sinv01 q01 ]
  // where qij = om_i' Q om_j (sparse Q via GMRF::Quadform / Q*x). The field
  // prior uses the sparse machinery already exercised by the per-trait path.
  // The response-column submode below additionally factorizes Q once and
  // solves only the T projection right-hand sides to obtain its exact
  // projected unit-diagonal normalization.
  vector<Type> spatial_column_inv_sd(n_traits);
  spatial_column_inv_sd.setOnes();
  if (use_spde_slope == 1) {
    // Closed-form Sigma_field paths (base unique / indep) require
    // n_lhs_cols_spde in {1, 2}. The spatial_dep slope path
    // (use_spde_dep_slope == 1) lifts this cap: there C = 2*n_traits and
    // Sigma_field is the full unstructured C x C built from theta_spde_dep_chol.
    if (use_spde_dep_slope == 0 && (n_lhs_cols_spde < 1 || n_lhs_cols_spde > 2))
      error("gllvmTMB_multi: n_lhs_cols_spde must be 1 or 2 in the base SPDE slope");
    if (use_spde_dep_slope == 1 && n_lhs_cols_spde < 1)
      error("gllvmTMB_multi: n_lhs_cols_spde must be >= 1 in the spatial_dep slope path");
    if (omega_spde_aug.dim.size() != 2)
      error("gllvmTMB_multi: omega_spde_aug must be a 2D array");
    if (omega_spde_aug.dim[1] != n_lhs_cols_spde || Z_spde_aug.dim[1] != n_lhs_cols_spde)
      error("gllvmTMB_multi: n_lhs_cols_spde does not match augmented SPDE arrays");
    if (Z_spde_aug.dim[0] != y.size())
      error("gllvmTMB_multi: Z_spde_aug first dimension must equal n_obs");

    Type kappa_s  = exp(log_kappa_spde);
    Type kappa_s2 = kappa_s * kappa_s;
    Type kappa_s4 = kappa_s2 * kappa_s2;
    Eigen::SparseMatrix<Type> Q_slope =
      kappa_s4 * spde_M0 + Type(2.0) * kappa_s2 * spde_M1 + spde_M2;
    density::GMRF_t<Type> gmrf_slope(Q_slope);

    if (use_spatial_column_slope == 1) {
      if (A_column.rows() != n_traits || A_column.cols() != Q_slope.rows())
        error("gllvmTMB_multi: A_column must be n_traits x n_mesh");
      // Exact projected covariance without forming dense Q^{-1}: factor the
      // sparse Q once and solve only the T right-hand sides A_column'.
      // C_raw = A Q^{-1} A'; K = D^{-1/2} C_raw D^{-1/2}.
      Eigen::SimplicialLDLT< Eigen::SparseMatrix<Type> > column_ldlt(Q_slope);
      matrix<Type> Qinv_At = column_ldlt.solve(A_column.transpose());
      matrix<Type> C_raw = A_column * Qinv_At;
      vector<Type> spatial_column_variance_raw(n_traits);
      for (int t = 0; t < n_traits; t++) {
        Type variance_t = C_raw(t, t);
        double variance_value = asDouble(variance_t);
        if (!R_FINITE(variance_value) || variance_value <= 0.0)
          error("gllvmTMB_multi: projected spatial column variance must be finite and positive");
        spatial_column_variance_raw(t) = variance_t;
        spatial_column_inv_sd(t) = Type(1.0) / sqrt(variance_t);
      }
      matrix<Type> spatial_column_K(n_traits, n_traits);
      for (int t = 0; t < n_traits; t++) {
        for (int u = 0; u < n_traits; u++) {
          spatial_column_K(t, u) = (t == u) ? Type(1.0) :
            C_raw(t, u) * spatial_column_inv_sd(t) * spatial_column_inv_sd(u);
        }
      }
      REPORT(spatial_column_variance_raw);
      REPORT(spatial_column_K);
    }

    if (use_spde_dep_slope == 1) {
      // ---- spatial_dep slope: full unstructured C x C Sigma_field = L L^T ----
      // Design 64 sec.2.2/2.3, eq (**). Build L (C x C lower-triangular) from
      // theta_spde_dep_chol: C log-diagonal entries (exp-transformed, >0 and
      // identified) then the strictly-lower entries column-major. Then the
      // matrix-normal nll vec(Omega) ~ N(0, Sigma_field (x) Q_base^{-1}) is
      //   nll = sum_j GMRF(Q_base)(omega_j)               // n*C log2pi - C logdetQ + tr(Q)
      //       + 0.5 * n_node * logdet(Sigma_field)
      //       + 0.5 * ( tr(Sinv*Q) - tr(Q) ),    Q(j,l) = omega_j' Q_base omega_l.
      // This is the phylo_dep formula (src/gllvmTMB.cpp dep block) with
      // A_phy^{-1} -> Q_base and n_aug_phy -> n_node. No new atomic / sparse op.
      int C = n_lhs_cols_spde;
      int n_chol = C * (C + 1) / 2;
      if (theta_spde_dep_chol.size() != n_chol)
        error("gllvmTMB_multi: theta_spde_dep_chol has wrong length for spatial_dep slope");
      int n_node = omega_spde_aug.dim[0];
      matrix<Type> Lf(C, C);
      Lf.setZero();
      {
        int idx = 0;
        for (int j = 0; j < C; j++) { Lf(j, j) = exp(theta_spde_dep_chol(idx)); idx++; }
        for (int j = 0; j < C; j++)
          for (int i = j + 1; i < C; i++) { Lf(i, j) = theta_spde_dep_chol(idx); idx++; }
      }
      matrix<Type> Sigma_field = Lf * Lf.transpose();
      matrix<Type> Sigma_field_inv = atomic::matinv(Sigma_field);
      Type logdet_Sigma_field = Type(0);
      for (int j = 0; j < C; j++) logdet_Sigma_field += Type(2) * log(Lf(j, j));
      // Report recovered per-field SDs (covariance scale) + correlation matrix.
      vector<Type> sd_spde_b(C);
      for (int j = 0; j < C; j++) sd_spde_b(j) = sqrt(Sigma_field(j, j));
      REPORT(sd_spde_b);
      matrix<Type> cor_spde_field(C, C);
      for (int a = 0; a < C; a++)
        for (int bcol = 0; bcol < C; bcol++)
          cor_spde_field(a, bcol) = Sigma_field(a, bcol) / (sd_spde_b(a) * sd_spde_b(bcol));
      REPORT(cor_spde_field);
      REPORT(Sigma_field);
      // Pull the C field columns; Q(j,l) = omega_j' Q_base omega_l via sparse
      // mat-vec, and accumulate sum_j GMRF(Q_base)(omega_j).
      matrix<Type> Qmat(C, C);
      for (int j = 0; j < C; j++) {
        vector<Type> omj(n_node);
        for (int i = 0; i < n_node; i++) omj(i) = omega_spde_aug(i, j);
        nll += gmrf_slope(omj);                          // single-field GMRF
        for (int l = 0; l <= j; l++) {
          vector<Type> oml(n_node);
          for (int i = 0; i < n_node; i++) oml(i) = omega_spde_aug(i, l);
          Type qjl = (omj * (Q_slope * oml.matrix()).array()).sum();
          Qmat(j, l) = qjl;
          Qmat(l, j) = qjl;
        }
      }
      Type trQ = Type(0);
      for (int j = 0; j < C; j++) trQ += Qmat(j, j);
      Type tr_SinvQ = Type(0);
      for (int j = 0; j < C; j++)
        for (int l = 0; l < C; l++)
          tr_SinvQ += Sigma_field_inv(j, l) * Qmat(l, j);
      nll += Type(0.5) * Type(n_node) * logdet_Sigma_field
           + Type(0.5) * (tr_SinvQ - trQ);
      REPORT(kappa_s);
    } else {
    if (log_sd_spde_b.size() != n_lhs_cols_spde)
      error("gllvmTMB_multi: log_sd_spde_b has wrong length");
    int n_cor_spde = n_lhs_cols_spde * (n_lhs_cols_spde - 1) / 2;
    if (atanh_cor_spde_b.size() != n_cor_spde)
      error("gllvmTMB_multi: atanh_cor_spde_b has wrong length");

    vector<Type> sd_spde_b(n_lhs_cols_spde);
    for (int j = 0; j < n_lhs_cols_spde; j++) sd_spde_b(j) = exp(log_sd_spde_b(j));
    REPORT(sd_spde_b);

    if (n_lhs_cols_spde == 1) {
      // Slope-only: omega_beta ~ N(0, sd^2 Q^-1) == SCALE(GMRF(Q), sd).
      vector<Type> om0(omega_spde_aug.dim[0]);
      for (int i = 0; i < omega_spde_aug.dim[0]; i++) om0(i) = omega_spde_aug(i, 0);
      nll += SCALE(gmrf_slope, sd_spde_b(0))(om0);
    } else {
      Type rho = tanh(atanh_cor_spde_b(0));
      Type one_minus_rho2 = Type(1) - rho * rho;
      Type Sinv00 =  Type(1) / (sd_spde_b(0) * sd_spde_b(0) * one_minus_rho2);
      Type Sinv11 =  Type(1) / (sd_spde_b(1) * sd_spde_b(1) * one_minus_rho2);
      Type Sinv01 = -rho / (sd_spde_b(0) * sd_spde_b(1) * one_minus_rho2);
      Type logdet_Sigma_field = Type(2) * log_sd_spde_b(0)
                              + Type(2) * log_sd_spde_b(1)
                              + log(one_minus_rho2);
      vector<Type> cor_spde_b(1);
      cor_spde_b(0) = rho;
      REPORT(cor_spde_b);

      int n_node = omega_spde_aug.dim[0];
      vector<Type> om0(n_node), om1(n_node);
      for (int i = 0; i < n_node; i++) {
        om0(i) = omega_spde_aug(i, 0);
        om1(i) = omega_spde_aug(i, 1);
      }
      Type q00 = gmrf_slope.Quadform(om0);                 // om0' Q om0
      Type q11 = gmrf_slope.Quadform(om1);                 // om1' Q om1
      Type q01 = (om0 * (Q_slope * om1.matrix()).array()).sum();  // om0' Q om1

      // Two single-field GMRF calls supply 2n log2pi - 2 logdetQ + q00 + q11.
      nll += gmrf_slope(om0);
      nll += gmrf_slope(om1);
      // Sigma_field log-determinant + the off-diagonal / rescaled quadratic.
      nll += Type(0.5) * Type(n_node) * logdet_Sigma_field
           + Type(0.5) * ((Sinv00 - Type(1)) * q00
                          + (Sinv11 - Type(1)) * q11
                          + Type(2) * Sinv01 * q01);
    }
    REPORT(kappa_s);
    }  // end closed-form (use_spde_dep_slope == 0) branch
  }

  // -------- spatial_latent slope (Design 64 sec.3) ----------------------
  // Block-diagonal reduced-rank random regression on the SPDE field. For each
  // LHS column k, build an independent loading matrix Lambda_k (n_traits x
  // d_spde_slope, lower-triangular rr() convention) and place an independent
  // N(0, Q_base^{-1}) prior on each of the d_spde_slope shared field columns
  // g_spde_slope[ , f, k] (a single GMRF(Q_base) call each; scale absorbed into
  // Lambda_k). The negative log prior is sum over the n_lhs_cols_spde_lat *
  // d_spde_slope independent fields of GMRF(Q_base)(.) -- the existing
  // spatial_latent (intercept-only) prior loop replicated across an extra
  // LHS-column axis. No cross-column (intercept-slope) term. This is the
  // phylo_latent slope block with the species-indexed score replaced by the
  // shared mesh field, and Ainv_phy_rr replaced by GMRF(Q_base).
  array<Type> Lambda_spde_slope(n_traits, std::max(d_spde_slope, 1),
                                std::max(n_lhs_cols_spde_lat, 1));
  Lambda_spde_slope.setZero();
  if (use_spde_latent_slope == 1) {
    if (n_lhs_cols_spde_lat < 1 || n_lhs_cols_spde_lat > 2)
      error("gllvmTMB_multi: n_lhs_cols_spde_lat must be 1 or 2");
    if (g_spde_slope.dim.size() != 3)
      error("gllvmTMB_multi: g_spde_slope must be a 3D array");
    if (g_spde_slope.dim[1] != d_spde_slope)
      error("gllvmTMB_multi: g_spde_slope second dimension must equal d_spde_slope");
    if (g_spde_slope.dim[2] != n_lhs_cols_spde_lat)
      error("gllvmTMB_multi: g_spde_slope third dimension must equal n_lhs_cols_spde_lat");
    if (Z_spde_lat.rows() != y.size() || Z_spde_lat.cols() != n_lhs_cols_spde_lat)
      error("gllvmTMB_multi: Z_spde_lat must be n_obs x n_lhs_cols_spde_lat");
    int n_node = g_spde_slope.dim[0];
    Type kappa_l  = exp(log_kappa_spde);
    Type kappa_l2 = kappa_l * kappa_l;
    Type kappa_l4 = kappa_l2 * kappa_l2;
    Eigen::SparseMatrix<Type> Q_lat =
      kappa_l4 * spde_M0 + Type(2.0) * kappa_l2 * spde_M1 + spde_M2;
    density::GMRF_t<Type> gmrf_lat(Q_lat);
    int p = n_traits;
    int rank = d_spde_slope;
    int len_per_col = p * rank - rank * (rank - 1) / 2;
    if (theta_rr_spde_slope.size() != n_lhs_cols_spde_lat * len_per_col)
      error("gllvmTMB_multi: theta_rr_spde_slope has wrong length");
    // Build each per-column Lambda_k from its packed lower-triangular slice
    // (identical packing to theta_rr_phy_slope / theta_rr_spde_lv).
    for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
      vector<Type> theta_k =
        theta_rr_spde_slope.segment(kcol * len_per_col, len_per_col);
      matrix<Type> loading_k = gll_unpack_rr_loadings(theta_k, p, rank);
      for (int j = 0; j < rank; j++) {
        for (int i = 0; i < p; i++) {
          Lambda_spde_slope(i, j, kcol) = loading_k(i, j);
        }
      }
    }
    // Independent N(0, Q_base^{-1}) prior on every shared field column.
    for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
      for (int f = 0; f < d_spde_slope; f++) {
        vector<Type> g_kf(n_node);
        for (int i = 0; i < n_node; i++) g_kf(i) = g_spde_slope(i, f, kcol);
        nll += gmrf_lat(g_kf);
      }
    }
    REPORT(Lambda_spde_slope);
    // Per-column Sigma_k = Lambda_k Lambda_k^T for extraction / recovery.
    matrix<Type> Ls0(n_traits, std::max(d_spde_slope, 1));
    matrix<Type> Ls1(n_traits, std::max(d_spde_slope, 1));
    for (int j = 0; j < std::max(d_spde_slope, 1); j++)
      for (int i = 0; i < n_traits; i++) {
        Ls0(i, j) = Lambda_spde_slope(i, j, 0);
        Ls1(i, j) = (n_lhs_cols_spde_lat > 1) ? Lambda_spde_slope(i, j, 1) : Type(0);
      }
    matrix<Type> Sigma_spde_slope_intercept = Ls0 * Ls0.transpose();
    matrix<Type> Sigma_spde_slope_slope = Ls1 * Ls1.transpose();
    REPORT(Sigma_spde_slope_intercept);
    REPORT(Sigma_spde_slope_slope);
  }

  // -------- generic (1 | group) random intercepts -----------------------
  // For each term t, the slice u_re_int[offset(t) .. offset(t)+n_groups(t))
  // is i.i.d. N(0, sigma_re_int(t)^2). Sum independent normal log-densities.
  if (use_re_int == 1) {
    for (int t = 0; t < n_re_int_terms; t++) {
      Type sigma_t = exp(log_sigma_re_int(t));
      int off = re_int_offsets(t);
      int ng  = re_int_n_groups(t);
      for (int g = 0; g < ng; g++) {
        nll -= dnorm(u_re_int(off + g), Type(0), sigma_t, true);
      }
    }
    REPORT(log_sigma_re_int);
  }

  // -------- equalto: e_eq ~ MVN(0, V), V fixed --------------------------
  if (use_equalto == 1) {
    Type quad = (e_eq.matrix().transpose() * V_inv * e_eq.matrix())(0, 0);
    nll += 0.5 * (Type(e_eq.size()) * log(2.0 * M_PI)
                  + log_det_V
                  + quad);
  }

  // -------- Pre-compute spatial-projected fields for spde --------------
  // For the per-trait path (spde_lv_k == 0): A_omega(o, t) =
  //   (A_proj * omega_spde)(o, t). One sparse matvec per trait.
  // For the spatial_latent path (spde_lv_k >= 1): A_omega_lv(o, k) =
  //   (A_proj * omega_spde_lv)(o, k). One sparse matvec per latent field;
  //   the per-trait contribution is built inside the eta loop via
  //   sum_k Lambda_spde(t, k) * A_omega_lv(o, k).
  matrix<Type> A_omega(y.size(), std::max(n_traits, 1));
  matrix<Type> A_omega_lv(y.size(), std::max(spde_lv_k, 1));
  A_omega.setZero();
  A_omega_lv.setZero();
  if (use_spde == 1) {
    if (spde_lv_k == 0 || spde_lv_unique == 1) {
      for (int t = 0; t < n_traits; t++) {
        vector<Type> omega_t = omega_spde.col(t);
        vector<Type> Ao_t = A_proj * omega_t;
        for (int o = 0; o < y.size(); o++) {
          A_omega(o,t) = Ao_t(o);
          if (structured_rho_spatial == 1) {
            int j = spatial_rho_group_id(o);
            A_omega(o,t) = structured_rho_wK*Ao_t(o) + structured_rho_wD*
              sqrt(spatial_rho_diagonal(j))*exp(-log_tau_spde(t))*omega_spde_iid(j,t);
          }
        }
      }
    }
    if (spde_lv_k > 0) {
      for (int k = 0; k < spde_lv_k; k++) {
        vector<Type> omega_k = omega_spde_lv.col(k);
        vector<Type> Ao_k = A_proj * omega_k;
        for (int o = 0; o < y.size(); o++) {
          A_omega_lv(o,k) = Ao_k(o);
          if (structured_rho_spatial == 1) {
            int j = spatial_rho_group_id(o);
            A_omega_lv(o,k) = structured_rho_wK*Ao_k(o) + structured_rho_wD*
              sqrt(spatial_rho_diagonal(j))*omega_spde_lv_iid(j,k);
          }
        }
      }
    }
  }

  // Augmented SPDE slope: project each field column (alpha, beta) once.
  //   A_omega_aug(o, j) = (A_proj * omega_spde_aug.col(j))(o).
  // eta gets sum_j A_omega_aug(o, j) * Z_spde_aug(o, j) in the loop below.
  matrix<Type> A_omega_aug(y.size(), std::max(n_lhs_cols_spde, 1));
  A_omega_aug.setZero();
  if (use_spde_slope == 1) {
    for (int j = 0; j < n_lhs_cols_spde; j++) {
      vector<Type> omega_j(omega_spde_aug.dim[0]);
      for (int i = 0; i < omega_spde_aug.dim[0]; i++) omega_j(i) = omega_spde_aug(i, j);
      vector<Type> Ao_j = A_proj * omega_j;
      for (int o = 0; o < y.size(); o++) {
        A_omega_aug(o, j) = use_spatial_column_slope == 1 ?
          Ao_j(o) * spatial_column_inv_sd(trait_id(o)) : Ao_j(o);
      }
    }
  }

  // spatial_latent slope: project each shared field column g_spde_slope[ ,f,k]
  // once. A_g_spde_slope(o, f, k) = (A_proj * g_spde_slope.col(f, k))(o). eta
  // gets sum_k Z_spde_lat(o,k) * sum_f Lambda_k(t(o),f) * A_g_spde_slope(o,f,k).
  array<Type> A_g_spde_slope(y.size(), std::max(d_spde_slope, 1),
                             std::max(n_lhs_cols_spde_lat, 1));
  A_g_spde_slope.setZero();
  if (use_spde_latent_slope == 1) {
    for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
      for (int f = 0; f < d_spde_slope; f++) {
        vector<Type> g_kf(g_spde_slope.dim[0]);
        for (int i = 0; i < g_spde_slope.dim[0]; i++) g_kf(i) = g_spde_slope(i, f, kcol);
        vector<Type> Ag = A_proj * g_kf;
        for (int o = 0; o < y.size(); o++) A_g_spde_slope(o, f, kcol) = Ag(o);
      }
    }
  }

  // -------- Add RE contributions to eta ---------------------------------
  vector<Type> observation_nll(y.size());
  observation_nll.setZero();
  for (int o = 0; o < y.size(); o++) {
    int t  = trait_id(o);
    int s  = site_id(o);
    int ss = site_species_id(o);
    // Under AGHQ the z_B contribution is added per QUADRATURE NODE in the
    // observation loop below, not here: eta(o) is left as the "base" linear
    // predictor with the B-tier latent block removed, so the node loop only
    // has to add Lambda_B * z_ij.
    if (use_rr_B == 1 && use_aghq == 0) {
      Type u_B_st = 0;
      for (int k = 0; k < d_B; k++) {
        Type score_k = (use_lv_B == 1) ? U_B_total(s, k) : z_B(k, s);
        u_B_st += Lambda_B(t, k) * score_k;
      }
      eta(o) += u_B_st;
    }
    if (use_rr_B_slope == 1) {
      Type u_B_aug = 0;
      for (int j = 0; j < n_lhs_cols_B_lat; j++) {
        Type coef_j = 0;
        for (int k = 0; k < d_B_slope; k++)
          coef_j += Lambda_B_slope(j, k) * z_B_slope(k, s);
        u_B_aug += Z_B_lat(o, j) * coef_j;
      }
      eta(o) += u_B_aug;
    }
    if (use_diag_B == 1 && integrate_gaussian_diag_B == 0)
      eta(o) += s_B(t, s);
    if (use_diag_B_slope == 1) {
      Type u_B_diag_aug = 0;
      for (int j = 0; j < n_lhs_cols_B_diag; j++) {
        u_B_diag_aug += Z_B_diag(o, j) * s_B_slope(j, s);
      }
      eta(o) += u_B_diag_aug;
    }
    if (use_rr_W == 1) {
      Type u_W_sst = 0;
      for (int k = 0; k < d_W; k++) u_W_sst += Lambda_W(t, k) * z_W(k, ss);
      eta(o) += u_W_sst;
    }
    if (use_diag_W == 1)
      eta(o) += s_W(t, ss);
    if (use_propto == 1)
      eta(o) += p_phy(species_id(o), t);
    if (use_diag_species == 1)
      eta(o) += q_sp(t, species_id(o));
    if (use_diag_cluster2 == 1)
      eta(o) += r_c2(t, cluster2_id(o));
    if (use_equalto == 1)
      eta(o) += e_eq(o);
    if (use_spde == 1) {
      if (spde_lv_k == 0) {
        eta(o) += A_omega(o, t);
      } else {
        Type contrib_spde = 0;
        for (int k = 0; k < spde_lv_k; k++)
          contrib_spde += Lambda_spde(t, k) * A_omega_lv(o, k);
        if (spde_lv_unique == 1)
          contrib_spde += A_omega(o, t);
        eta(o) += contrib_spde;
      }
    }
    if (use_spde_slope == 1) {
      // eta(o) += (A_proj omega_alpha)(o) + x(o) * (A_proj omega_beta)(o).
      // On the spatial_dep path the loop runs over all C = 2T interleaved
      // fields, Z_spde_aug selecting this row's trait pair.
      Type contrib_spde_aug = 0;
      for (int j = 0; j < n_lhs_cols_spde; j++)
        contrib_spde_aug += A_omega_aug(o, j) * Z_spde_aug(o, j);
      eta(o) += contrib_spde_aug;
    }
    if (use_spde_latent_slope == 1) {
      // Block-diagonal reduced-rank random regression on the SPDE field: per
      // LHS column k, the reduced-rank field structure (independent Lambda_k
      // and shared field scores), weighted by the column design Z_spde_lat(o,k).
      Type contrib_spde_lat = 0;
      for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
        Type u_kt = 0;
        for (int f = 0; f < d_spde_slope; f++)
          u_kt += Lambda_spde_slope(t, f, kcol) * A_g_spde_slope(o, f, kcol);
        contrib_spde_lat += Z_spde_lat(o, kcol) * u_kt;
      }
      eta(o) += contrib_spde_lat;
    }
    if (use_phylo_rr == 1) {
      Type contrib = 0;
      for (int k = 0; k < d_phy; k++) {
        Type score = g_phy(species_aug_id(o), k);
        if (structured_rho_sparse == 1)
          score = structured_rho_wK * score + structured_rho_wD *
            sqrt(structured_rho_diagonal(species_id(o))) * g_phy_iid(species_id(o), k);
        contrib += Lambda_phy(t, k) * score;
      }
      eta(o) += contrib;
    }
    if (use_phylo_diag == 1) {
      // Per-trait phylogenetic random intercept.
      Type score = g_phy_diag(species_aug_id(o), t);
      if (structured_rho_sparse == 1)
        score = structured_rho_wK * score + structured_rho_wD *
          sqrt(structured_rho_diagonal(species_id(o))) * g_phy_diag_iid(species_id(o), t);
      eta(o) += exp(log_sd_phy_diag(t)) * score;
    }
    if (n_kernel_tiers > 0) {
      int kid = kernel_group_id(o);
      if (kid < 0 || kid >= n_kernel_levels)
        error("gllvmTMB_multi: kernel_group_id out of range");
      for (int r = 0; r < n_kernel_tiers; r++) {
        int rank = kernel_rank(r);
        int goff = kernel_g_offset(r);
        Type contrib = 0;
        for (int k = 0; k < rank; k++)
          contrib += Lambda_kernel(t, k, r) *
            g_kernel(goff + kid * rank + k);
        eta(o) += contrib;
        if (kernel_has_diag(r) == 1) {
          int lsoff = kernel_logsd_offset(r);
          int doff = kernel_diag_offset(r);
          eta(o) += exp(log_sd_kernel_diag(lsoff + t)) *
            g_kernel_diag(doff + kid * n_traits + t);
        }
      }
    }
    if (use_phylo_slope_correlated == 1) {
      Type contrib_aug = 0;
      for (int k = 0; k < b_phy_aug.dim[2]; k++)
        for (int j = 0; j < n_lhs_cols; j++)
          contrib_aug += b_phy_aug_physical(
            use_phylo_column_slope == 1 ? phylo_slope_aug_id(o) : species_aug_id(o),
            j, k
          ) * Z_phy_aug(o, j, k);
      eta(o) += contrib_aug;
    } else if (use_phylo_slope == 1) {
      // Per-species slope on x, shared across traits.
      eta(o) += b_phy_slope(phylo_slope_aug_id(o)) * x_phy_slope(o);
    }
    if (use_phylo_latent_slope == 1) {
      // Block-diagonal reduced-rank random regression: per LHS column k,
      // the reduced-rank phylo factor structure (independent Lambda_k and
      // scores), weighted by the column design value Z_phy_lat(o, k).
      Type contrib_lat = 0;
      for (int kcol = 0; kcol < n_lhs_cols_lat; kcol++) {
        Type u_kt = 0;
        for (int f = 0; f < d_phy_slope; f++)
          u_kt += Lambda_phy_slope(t, f, kcol)
                  * g_phy_slope(species_aug_id(o), f, kcol);
        contrib_lat += Z_phy_lat(o, kcol) * u_kt;
      }
      eta(o) += contrib_lat;
    }
    if (use_re_int == 1) {
      for (int term = 0; term < n_re_int_terms; term++) {
        int gid = re_int_group_id(o, term);
        eta(o) += u_re_int(re_int_offsets(term) + gid);
      }
    }
  }

  // -------- Observation likelihood --------------------------------------
  bool has_gaussian_rows = false;
  bool has_lognormal_rows = false;
  for (int o = 0; o < family_id_vec.size(); o++) {
    has_gaussian_rows = has_gaussian_rows || family_id_vec(o) == 0;
    has_lognormal_rows = has_lognormal_rows || family_id_vec(o) == 3;
  }
  int expected_sigma_slots =
    has_gaussian_rows && has_lognormal_rows ? 2 : 1;
  if (log_sigma_eps.size() != expected_sigma_slots)
    error("gllvmTMB_multi: log_sigma_eps shape does not match active Gaussian/lognormal families");
  vector<Type> sigma_eps(log_sigma_eps.size());
  for (int j = 0; j < log_sigma_eps.size(); j++)
    sigma_eps(j) = exp(log_sigma_eps(j));
  Type sigma_eps_gaussian = sigma_eps(0);
  Type sigma_eps_lognormal =
    log_sigma_eps.size() == 2 ? sigma_eps(1) : sigma_eps(0);
  REPORT(sigma_eps);
  // Per-row response log-density log p(y(o) | eta_o), factored out of the
  // family-dispatch loop so the SAME kernels can be evaluated at a STATE-
  // SUBSTITUTED eta for the discrete missing-predictor SUM (design 68
  // sec.1.0 / sec.3.3: "the SUM introduces NO new RESPONSE family"). The
  // ordinary loop calls obs_loglik(o, eta(o)); the binary mi() block (below)
  // calls obs_loglik(o, eta_state) for each hypothetical predictor state and
  // accumulates the per-unit product. The body is the verbatim fid dispatch
  // with each `nll -= <density>` rewritten as `ll += <density>; return ll`.
  auto obs_loglik = [&](int o, Type eta_o) -> Type {
    int fid = family_id_vec(o);
    Type ll = Type(0.0);
    if (fid == 0) {
      // Gaussian, identity link
      if (integrate_gaussian_diag_B == 1) {
        // Integrate s_B ~ N(0, psi) exactly. The independent observation
        // stabilizer remains unchanged and contributes its original variance.
        Type variance = exp(Type(2) * theta_diag_B(trait_id(o))) +
          sigma_eps_gaussian * sigma_eps_gaussian;
        ll += dnorm(y(o), eta_o, sqrt(variance), true);
      } else {
        ll += dnorm(y(o), eta_o, sigma_eps_gaussian, true);
      }
    } else if (fid == 1) {
      // Bernoulli / binomial(k-of-n). Link depends on link_id_vec(o):
      //   0 = logit:    p = 1 / (1 + exp(-eta))
      //   1 = probit:   p = pnorm(eta)
      //   2 = cloglog:  p = 1 - exp(-exp(eta))
      // `n_trials(o)` is the size: 1.0 for Bernoulli (default and previous
      // behaviour), otherwise the user-supplied trial count from
      // `cbind(successes, failures)` on the LHS of the formula. `y(o)` is
      // the success count; the parser ensures 0 <= y(o) <= n_trials(o).
      int lid = link_id_vec(o);
      // MERGE (isdm x mspl): two lanes restructured this dispatch. The MSPL
      // opt-in estimator takes the row when active -- its kernel owns every
      // link, including its own cloglog tail counter. On the ML path, cloglog
      // routes to the iSDM tail-safe kernel (series expansion below eta = -20,
      // cap at 700) instead of the naive clamped form; logit and probit keep
      // the clamped dbinom path unchanged.
      if (estimator_id != 0) {
        ll += gll_mspl_bernoulli_loglik(y(o), eta_o, lid);
        if (lid == 2) {
          mspl_cloglog_likelihood_tail_extension_count += CppAD::CondExpGt(
            eta_o, Type(690.0), Type(1.0), Type(0.0));
        }
      } else if (lid == 2) {
        ll += gll_dbinom_cloglog(y(o), n_trials(o), eta_o);
      } else {
        Type p;
        if (lid == 0) {
          p = Type(1.0) / (Type(1.0) + exp(-eta_o));
        } else if (lid == 1) {
          p = pnorm(eta_o);
        } else {
          error("gllvmTMB_multi: unknown link_id for binomial family");
        }
        // Numerical safety: clip away from 0/1 to prevent log(0).
        Type tiny = Type(1e-12);
        p = gll_clamp(p, tiny, Type(1.0) - tiny);
        ll += dbinom(y(o), n_trials(o), p, true);
      }
    } else if (fid == 2) {
      // Poisson, log link
      ll += dpois(y(o), exp(eta_o), true);
    } else if (fid == 3) {
      // Lognormal, log link
      // y > 0 strictly. log(y) ~ Normal(eta, sigma_eps); add Jacobian -log(y).
      ll += dnorm(
        log(y(o)), eta_o, sigma_eps_lognormal, true
      ) - log(y(o));
    } else if (fid == 4) {
      // Gamma, log link, mean-shape parametrization
      // mu = exp(eta); per-trait shape phi = exp(log_phi_gamma(t)).
      // scale = mu / phi so E(y) = mu and CV(y) = 1 / sqrt(phi).
      int t = trait_id(o);
      Type mu_g    = exp(eta_o);
      Type shape_g = exp(log_phi_gamma(t));
      Type scale_g = mu_g / shape_g;
      ll += dgamma(y(o), shape_g, scale_g, true);
    } else if (fid == 5) {
      // NB2 (negative binomial, type 2), log link.
      // Var(y) = mu + mu^2 / phi, with one log_phi per trait.
      // Use dnbinom_robust (numerically stable; takes log_mu and log(var-mu)).
      // log(var - mu) = log(mu^2 / phi) = 2*log(mu) - log(phi).
      int t = trait_id(o);
      Type log_mu = eta_o;                         // log link
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_nbinom2(t);
      ll += dnbinom_robust(y(o), log_mu, log_v_minus_mu, true);
    } else if (fid == 6) {
      // Tweedie compound Poisson-Gamma, log link.
      // y >= 0 (point mass at zero plus continuous positive part).
      // Per-trait dispersion phi = exp(log_phi_tweedie(t));
      // power p in (1, 2), parameterised as p = 1 + plogis(logit_p_tweedie(t)).
      int t = trait_id(o);
      Type mu_t  = exp(eta_o);
      Type phi_t = exp(log_phi_tweedie(t));
      Type p_t   = Type(1.0) + invlogit(logit_p_tweedie(t));
      ll += dtweedie(y(o), mu_t, phi_t, p_t, true);
    } else if (fid == 7) {
      // Beta family, logit link, mean-precision parameterisation.
      // y in (0, 1); mu = invlogit(eta); a = mu*phi, b = (1-mu)*phi.
      // log f(y) = lgamma(phi) - lgamma(a) - lgamma(b)
      //           + (a - 1) log(y) + (b - 1) log(1 - y)
      // (Smithson & Verkuilen 2006 Psychol. Methods 11:54-71.)
      int t = trait_id(o);
      Type mu_b  = invlogit(eta_o);
      Type phi_b = exp(log_phi_beta(t));
      Type a_b   = mu_b * phi_b;
      Type b_b   = (Type(1.0) - mu_b) * phi_b;
      Type tiny_y = Type(1e-12);
      Type y_safe = y(o);
      y_safe = gll_clamp(y_safe, tiny_y, Type(1.0) - tiny_y);
      Type ld = lgamma(phi_b) - lgamma(a_b) - lgamma(b_b)
              + (a_b - Type(1.0)) * log(y_safe)
              + (b_b - Type(1.0)) * log(Type(1.0) - y_safe);
      ll += ld;
    } else if (fid == 8) {
      // Beta-binomial family (Hilbe 2014; Bolker 2008).
      int t = trait_id(o);
      Type mu_bb  = invlogit(eta_o);
      Type phi_bb = exp(log_phi_betabinom(t));
      Type a_bb   = mu_bb * phi_bb;
      Type b_bb   = (Type(1.0) - mu_bb) * phi_bb;
      Type N      = n_trials(o);
      Type yo     = y(o);
      Type ld = lgamma(N + Type(1.0))
              + lgamma(yo + a_bb)
              + lgamma(N - yo + b_bb)
              + lgamma(a_bb + b_bb)
              - lgamma(yo + Type(1.0))
              - lgamma(N - yo + Type(1.0))
              - lgamma(a_bb)
              - lgamma(b_bb)
              - lgamma(N + a_bb + b_bb);
      ll += ld;
    } else if (fid == 9) {
      // Student-t, identity link.
      int t = trait_id(o);
      Type mu_t    = eta_o;
      Type sigma_t = exp(log_sigma_student(t));
      Type df_t    = Type(1.0) + exp(log_df_student(t));
      Type z_t     = (y(o) - mu_t) / sigma_t;
      ll += dt(z_t, df_t, true) - log(sigma_t);
    } else if (fid == 10) {
      // Zero-truncated Poisson, log link.
      Type lambda_t = exp(eta_o);
      ll += dpois(y(o), lambda_t, true)
             - logspace_sub(Type(0.0), -lambda_t);
    } else if (fid == 11) {
      // Zero-truncated NB2, log link.
      int t = trait_id(o);
      Type log_mu = eta_o;
      Type mu_t   = exp(log_mu);
      Type phi_t  = exp(log_phi_truncnb2(t));
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_truncnb2(t);
      Type log_p0 = phi_t * (log_phi_truncnb2(t) - log(mu_t + phi_t));
      ll += dnbinom_robust(y(o), log_mu, log_v_minus_mu, true)
             - logspace_sub(Type(0.0), log_p0);
    } else if (fid == 12) {
      // delta_lognormal (hurdle): one shared eta drives both components.
      //   Presence: I{y>0} ~ Bernoulli(invlogit(eta))   via dbinom_robust
      //   Positive: log y | y>0 ~ Normal(eta, sigma_t)
      // The Bernoulli logit-p IS eta(o) under the shared-predictor scheme,
      // so we hand eta directly to dbinom_robust for numerical stability.
      int t = trait_id(o);
      Type x_pres = (y(o) > Type(0)) ? Type(1.0) : Type(0.0);
      ll += dbinom_robust(x_pres, Type(1.0), eta_o, true);
      if (y(o) > Type(0)) {
        Type sigma_t = exp(log_sigma_lognormal_delta(t));
        // log y ~ Normal(eta, sigma_t); add Jacobian -log y so the density
        // is for Y rather than log Y.
        ll += dnorm(log(y(o)), eta_o, sigma_t, true) - log(y(o));
      }
    } else if (fid == 13) {
      // delta_gamma (hurdle): same shared-eta logic.
      //   Positive: y | y>0 ~ Gamma(shape = 1/phi^2, scale = mu * phi^2)
      //     so E(y) = mu = exp(eta), CV(y) = phi.
      int t = trait_id(o);
      Type x_pres = (y(o) > Type(0)) ? Type(1.0) : Type(0.0);
      ll += dbinom_robust(x_pres, Type(1.0), eta_o, true);
      if (y(o) > Type(0)) {
        Type phi_t   = exp(log_phi_gamma_delta(t));
        Type mu_g    = exp(eta_o);
        Type shape_g = Type(1.0) / (phi_t * phi_t);
        Type scale_g = mu_g / shape_g;
        ll += dgamma(y(o), shape_g, scale_g, true);
      }
    } else if (fid == 14) {
      // ordinal_probit (Wright/Falconer/Hadfield threshold model).
      //   y* = eta + e,  e ~ N(0, 1)   (link-residual variance = 1)
      //   y = k iff tau_{k-1} < y* <= tau_k
      //   tau_0 = -Inf, tau_1 = 0, tau_K = +Inf
      //   Free params: tau_2, ..., tau_{K-1}  (K - 2 cutpoints)
      // P(y = k | eta) = pnorm(tau_k - eta) - pnorm(tau_{k-1} - eta)
      // Reference: Hadfield (2015) MEE 6:706-714, eqn 9. K = 2 reduces to
      // binomial(probit) (eqn 10). y is 1-indexed (1, 2, ..., K).
      int t       = trait_id(o);
      int K_minus_2 = n_ordinal_cuts_per_trait(t);   // = K_t - 2
      int offset  = ordinal_offset_per_trait(t);
      int K       = K_minus_2 + 2;                   // number of categories
      // Reconstruct cutpoints tau_1 = 0, tau_2, ..., tau_{K-1} from log-
      // increments. cuts has length K-1 (excluding tau_0 = -Inf, tau_K = +Inf).
      vector<Type> cuts(K - 1);
      cuts(0) = Type(0.0);   // tau_1 fixed at 0 for identifiability
      for (int j = 1; j < K - 1; j++) {
        cuts(j) = cuts(j - 1) + exp(ordinal_log_increments(offset + j - 1));
      }
      int yk = CppAD::Integer(y(o));   // observed category, 1..K
      // log P(y = yk) = log( Phi(upper - eta) - Phi(lower - eta) ), computed
      // ENTIRELY on the log scale (gll_log_pnorm / gll_log_pnorm_diff).
      //
      // Was: p_k = upper_p - lower_p with a hard floor p_k >= 1e-12, then
      // log(p_k). That floor is harmless under Laplace but BINDS at AGHQ
      // quadrature nodes -- once the node pushes s_cond * |lambda| past about
      // 1.56 at k = 9 the true cell probability drops below 1e-12 and the
      // floor replaces the decaying tail with a constant (zero gradient in
      // eta). The log-scale form below keeps decaying; the residual guard is
      // at log(1e-300), i.e. only where a double would underflow anyway.
      Type logp_k;
      if (yk >= K) {
        // Top category: P = 1 - Phi(lower - eta) = Phi(eta - lower).
        logp_k = gll_log_pnorm(eta_o - cuts(yk - 2));
      } else if (yk <= 1) {
        // Bottom category: P = Phi(upper - eta).
        logp_k = gll_log_pnorm(cuts(yk - 1) - eta_o);
      } else {
        logp_k = gll_log_pnorm_diff(cuts(yk - 1) - eta_o,
                                    cuts(yk - 2) - eta_o);
      }
      Type log_tiny_ord = Type(-690.7755278982137);   // log(1e-300)
      logp_k = CppAD::CondExpLt(logp_k, log_tiny_ord, log_tiny_ord, logp_k);
      ll += logp_k;
    } else if (fid == 15) {
      // NB1 (negative binomial, type 1), log link.
      // Var(y) = mu * (1 + phi) = mu + phi * mu, with one log_phi per trait
      // (linear mean-variance; phi -> 0 recovers Poisson). Hilbe (2011).
      // Use dnbinom_robust (numerically stable; takes log_mu and log(var-mu)).
      // Contrast NB2 (fid 5), where var - mu = mu^2 / phi so the second
      // argument is 2*log(mu) - log(phi); here var - mu = phi * mu so it is
      // log(phi) + log(mu) = log_mu + log_phi_nbinom1(t).
      int t = trait_id(o);
      Type log_mu = eta_o;                         // log link
      Type log_v_minus_mu = log_mu + log_phi_nbinom1(t);
      ll += dnbinom_robust(y(o), log_mu, log_v_minus_mu, true);
    } else if (fid == 16) {
      error("gllvmTMB_multi: multinomial (fid 16) is evaluated as a grouped "
            "softmax at its anchor row, not per-row via obs_loglik");
    } else if (fid == 17) {
      // zi_poisson: TRUE zero-inflation mixture (Design 62 -- not the
      // fid 12/13 hurdle path; the count process is active at y == 0 too).
      //   P(y=0) = pi + (1-pi)*dpois(0, mu);  P(y=k>0) = (1-pi)*dpois(k, mu)
      // logit_zi is per-trait, intercept-only (recon Decision 2).
      // log(sigmoid(x)) = -logspace_add(0,-x); log(1-sigmoid(x)) =
      // -logspace_add(0,x) -- same numerically-stable idiom drmTMB uses for
      // its zi_poisson (recon section D).
      int t = trait_id(o);
      Type log_zi          = -logspace_add(Type(0.0), -logit_zi(t));
      Type log_one_minus_zi = -logspace_add(Type(0.0), logit_zi(t));
      Type mu = exp(eta_o);
      if (asDouble(y(o)) == 0.0) {
        ll += logspace_add(log_zi, log_one_minus_zi - mu);   // dpois(0,mu,log=T) = -mu
      } else {
        ll += log_one_minus_zi + dpois(y(o), mu, true);
      }
    } else if (fid == 18) {
      // zi_nbinom2: same mixture, NB2 count kernel. REUSES log_phi_nbinom2
      // (per-trait) rather than a new shared-scalar dispersion (recon open
      // question 2 -- a deliberate departure from GLLVM.jl's shared r).
      int t = trait_id(o);
      Type log_zi          = -logspace_add(Type(0.0), -logit_zi(t));
      Type log_one_minus_zi = -logspace_add(Type(0.0), logit_zi(t));
      Type log_mu = eta_o;
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_nbinom2(t);
      if (asDouble(y(o)) == 0.0) {
        Type log_p0 = dnbinom_robust(Type(0.0), log_mu, log_v_minus_mu, true);
        ll += logspace_add(log_zi, log_one_minus_zi + log_p0);
      } else {
        ll += log_one_minus_zi + dnbinom_robust(y(o), log_mu, log_v_minus_mu, true);
      }
    } else if (fid == 19) {
      // zi_binomial: mixture over a multi-trial Binomial(N_i, p) count part,
      // logit link only. Admission (R/fit-multi.R) refuses N_i == 1 rows --
      // the single-trial mixture is not identified (recon Decision 6 /
      // alignment-zi.md). dbinom_robust takes logit(p) directly, matching
      // the fid 12/13 hurdle presence term's idiom elsewhere in this file.
      int t = trait_id(o);
      Type log_zi          = -logspace_add(Type(0.0), -logit_zi(t));
      Type log_one_minus_zi = -logspace_add(Type(0.0), logit_zi(t));
      if (asDouble(y(o)) == 0.0) {
        Type log_p0 = dbinom_robust(Type(0.0), n_trials(o), eta_o, true);
        ll += logspace_add(log_zi, log_one_minus_zi + log_p0);
      } else {
        ll += log_one_minus_zi + dbinom_robust(y(o), n_trials(o), eta_o, true);
      }
    } else {
      error("gllvmTMB_multi: unknown family_id");
    }
    return ll;
  };

  // -------- Discrete missing-PREDICTOR SUM: binary + ordered + unordered -
  // Design 68 sec.1.1 / sec.1.2 / sec.1.3 / sec.3 (drmTMB MD6a/MD6b/MD6c
  // analogue with the multivariate per-UNIT product). A discrete missing
  // predictor is marginalised EXACTLY by a finite-state SUM evaluated here, with
  // NO latent x. For a missing-x unit u the observed-data contribution is
  //   nll -= logspace_add_over_k( log p(x=k|z_u) + log_y_k(u) )
  // where log_y_k(u) = sum_t obs_loglik(o, eta_state(o, k)) is the PRODUCT
  // over u's trait rows (sec.3.2: the SUM is OUTSIDE the trait product, so the
  // prior is counted ONCE per unit and a SINGLE state k feeds all traits -- a
  // per-row SUM would double-count the prior). The per-unit, per-state
  // accumulator mi_acc(u, k) is M x K (K = 2 for binary, K = mi_n_state for
  // ordered / unordered -- the generalisation of Phase 5a's M x 2); it is filled
  // by the gated rows in the loop below, initialised here to the per-unit
  // log-priors.
  //   * binary    (mi_family == 1): K = 2; Bernoulli-logit prior; the state-eta
  //     uses the single-column DELTA-SWAP (sec.3.4), value k in {0, 1}.
  //   * ordered   (mi_family == 2): K states; cumulative-logit prior with K-1
  //     free cutpoints reconstructed from theta_ord (sec.1.2); the state-eta
  //     uses the FULL-SWAP via X_fix_state (a factor expands to K-1 contrast
  //     columns, so a single-column delta is insufficient).
  //   * unordered (mi_family == 3): K states; baseline-category SOFTMAX prior
  //     (sec.1.3) -- the ONE family with a genuinely NEW predictor-model block;
  //     beta_mi is packed as (K-1) blocks of n_coef, eta_state(0) = 0 baseline,
  //     log_denom via the explicit max-subtraction guard. Same FULL-SWAP eta and
  //     same per-unit product / M x K accumulator as ordered (sec.1.3: the SUM
  //     identity + response-side reuse are identical to MD6a/MD6b).
  // has_mi != 1, or mi_family not in {1, 2, 3} -> the whole block is an exact
  // no-op (mi_acc / mi_logp* / mi_cutpoints / mi_log_prior unused).
  bool mi_is_discrete = (has_mi == 1 &&
                         (mi_family == 1 || mi_family == 2 || mi_family == 3));
  int mi_K = (has_mi == 1 && (mi_family == 2 || mi_family == 3))
    ? mi_n_state : 2;
  int mi_n_units = mi_is_discrete ? mi_x_unit.size() : 0;
  matrix<Type> mi_acc(std::max(mi_n_units, 1), std::max(mi_K, 1));
  mi_acc.setZero();
  // Binary prior caches (used only for mi_family == 1; the observed-unit term
  // and the posterior probability read them in the collapse pass).
  vector<Type> mi_logp1(std::max(mi_n_units, 1));
  vector<Type> mi_logp0(std::max(mi_n_units, 1));
  mi_logp1.setZero();
  mi_logp0.setZero();
  // Ordered per-unit per-state log-prior cache (used only for mi_family == 2).
  matrix<Type> mi_log_prior(std::max(mi_n_units, 1), std::max(mi_K, 1));
  mi_log_prior.setZero();
  // Ordered cutpoints c_1 < ... < c_{K-1} reconstructed from the K-1 FREE raw
  // vector theta_ord (sec.1.2): c_1 = theta_ord(0) free base, c_j = c_{j-1} +
  // exp(theta_ord(j)). MIRRORS drmTMB (K-1 free); NOT the fid-14 tau_1 = 0
  // RESPONSE convention. Length 0 unless mi_family == 2.
  vector<Type> mi_cutpoints(theta_ord.size());
  if (has_mi == 1 && mi_family == 1) {
    // Per-unit Bernoulli-logit predictor prior (verbatim drmTMB MD6a:
    // log_p1 = -logspace_add(0, -eta_x), log_p0 = -logspace_add(0, eta_x)).
    vector<Type> mi_eta_x = X_mi * beta_mi;
    for (int u = 0; u < mi_n_units; ++u) {
      mi_logp1(u) = -logspace_add(Type(0.0), -mi_eta_x(u));
      mi_logp0(u) = -logspace_add(Type(0.0),  mi_eta_x(u));
      // Initialise the per-state accumulator with the state log-prior; the
      // response product (sec.3.3 step 2) is added per trait row below.
      mi_acc(u, 0) = mi_logp0(u);
      mi_acc(u, 1) = mi_logp1(u);
    }
  } else if (has_mi == 1 && mi_family == 2) {
    // Reconstruct the K-1 free cutpoints (sec.1.2). The increment loop body is
    // byte-identical to drmTMB MD6b src/drmTMB.cpp:872-875 and to gllvmTMB's
    // fid-14 reconstruction (sec.5) -- but entry 0 stays a FREE base here.
    if (theta_ord.size() > 0) {
      mi_cutpoints(0) = theta_ord(0);
      for (int j = 1; j < theta_ord.size(); ++j) {
        mi_cutpoints(j) = mi_cutpoints(j - 1) + exp(theta_ord(j));
      }
    }
    // Per-unit cumulative-logit state log-prior (drmTMB MD6b sec.1.2 form):
    //   state 0    : log F(c_1 - eta_x)
    //   state K-1  : log(1 - F(c_{K-1} - eta_x))
    //   state k    : log[ F(c_k - eta_x) - F(c_{k-1} - eta_x) ]
    vector<Type> mi_eta_x = X_mi * beta_mi;
    for (int u = 0; u < mi_n_units; ++u) {
      for (int k = 0; k < mi_K; ++k) {
        Type log_prob;
        if (k == 0) {
          log_prob = gll_log_inv_logit(mi_cutpoints(0) - mi_eta_x(u));
        } else if (k == mi_K - 1) {
          log_prob = gll_log1m_inv_logit(mi_cutpoints(mi_K - 2) - mi_eta_x(u));
        } else {
          Type upper = mi_cutpoints(k) - mi_eta_x(u);
          Type lower = mi_cutpoints(k - 1) - mi_eta_x(u);
          log_prob = gll_log_inv_logit_diff(upper, lower);
        }
        mi_log_prior(u, k) = log_prob;
        // Initialise the accumulator with the state log-prior (sec.3.3 step 3);
        // the response product is added per trait row below.
        mi_acc(u, k) = log_prob;
      }
    }
  } else if (has_mi == 1 && mi_family == 3) {
    // Baseline-category SOFTMAX predictor prior (drmTMB MD6c, design 68 sec.1.3).
    // beta_mi is packed as (K-1) blocks of n_coef: block (k-1) is the linear
    // predictor for state k. eta_state(0) = 0 (baseline = first level);
    // eta_state(k) = X_mi(u,.) . beta_mi[block (k-1)], k = 1..K-1; the log
    // normaliser uses the EXPLICIT max-subtraction guard (NOT a library
    // logsumexp), matching drmTMB src/drmTMB.cpp:987-995; log P(x=k+1|z) =
    // eta_state(k) - log_denom. This is the one family with a genuinely NEW
    // predictor-model block; the SUM identity + response-side reuse are
    // otherwise identical to MD6a/MD6b.
    int n_coef = X_mi.cols();
    for (int u = 0; u < mi_n_units; ++u) {
      vector<Type> eta_state(mi_K);
      eta_state(0) = Type(0.0);
      for (int k = 1; k < mi_K; ++k) {
        Type eta = Type(0.0);
        int offset = (k - 1) * n_coef;
        for (int col = 0; col < n_coef; ++col) {
          eta += X_mi(u, col) * beta_mi(offset + col);
        }
        eta_state(k) = eta;
      }
      // Explicit max-subtraction guard for the softmax normaliser (sec.1.3).
      Type max_eta = eta_state(0);
      for (int k = 1; k < mi_K; ++k) {
        max_eta = CppAD::CondExpGt(eta_state(k), max_eta, eta_state(k), max_eta);
      }
      Type denom = Type(0.0);
      for (int k = 0; k < mi_K; ++k) {
        denom += exp(eta_state(k) - max_eta);
      }
      Type log_denom = max_eta + log(denom);
      for (int k = 0; k < mi_K; ++k) {
        Type log_prob = eta_state(k) - log_denom;
        mi_log_prior(u, k) = log_prob;
        // Initialise the accumulator with the state log-prior (sec.3.3 step 3);
        // the response product is added per trait row below.
        mi_acc(u, k) = log_prob;
      }
    }
  }

  // -------- AGHQ setup (Stage 1a: the z_B block) -------------------------
  // Everything below is skipped entirely when use_aghq == 0, and the sizes
  // collapse to 1 so the no-op path allocates nothing meaningful.
  int aghq_n_node = (use_aghq == 1) ? aghq_nodes.rows() : 1;
  // Per-site, per-node latent value z_ij = zhat_i + L_i^{-T} u_j, and the
  // per-node standard-normal log prior log N(z_ij; 0, I). Precomputed once so
  // the observation loop (which visits each site's rows repeatedly) does not
  // redo the d x d solve per row.
  array<Type> aghq_z((use_aghq == 1) ? n_sites : 1,
                     aghq_n_node,
                     (use_aghq == 1) ? std::max(aghq_d, 1) : 1);
  matrix<Type> aghq_site_ll((use_aghq == 1) ? n_sites : 1, aghq_n_node);
  aghq_z.setZero();
  aghq_site_ll.setZero();
  if (use_aghq == 1) {
    // Stage 1a fences. These are ALSO checked in R (R/fit-multi.R), but the
    // template must not silently produce a wrong objective if it is driven
    // directly, so they are re-asserted here.
    if (use_rr_B != 1)
      error("gllvmTMB_multi: use_aghq requires use_rr_B (the z_B block)");
    if (aghq_d != d_B)
      error("gllvmTMB_multi: aghq_d must equal d_B in Stage 1a");
    if (use_lv_B == 1)
      error("gllvmTMB_multi: use_aghq does not yet support use_lv_B");
    if (use_diag_B == 1) {
      // R may retain the ordinary latent() auto-Psi parameter stubs after the
      // single-trial Bernoulli gate has mapped every one off and fixed s_B = 0.
      // That route is mathematically loadings-only and is admitted. Any free
      // diagonal remains a genuine extra random block and is still fenced.
      if (diag_B_skip.size() != n_traits)
        error("gllvmTMB_multi: diag_B_skip has wrong length under use_aghq");
      bool any_free_diag_B = false;
      for (int t = 0; t < n_traits; t++) {
        if (diag_B_skip(t) == 0) any_free_diag_B = true;
      }
      if (any_free_diag_B)
        error("gllvmTMB_multi: use_aghq Stage 1a is loadings-only (free s_B remains)");
    }
    if (has_mi == 1)
      error("gllvmTMB_multi: use_aghq does not yet support mi() predictors");
    if (aghq_nodes.cols() != aghq_d)
      error("gllvmTMB_multi: aghq_nodes must be n_node x aghq_d");
    if (aghq_logw.size() != aghq_n_node)
      error("gllvmTMB_multi: aghq_logw must have one entry per node");
    if (aghq_mode.rows() != n_sites || aghq_mode.cols() != aghq_d)
      error("gllvmTMB_multi: aghq_mode must be n_sites x aghq_d");
    if (aghq_Lt.rows() != n_sites || aghq_Lt.cols() != aghq_d * aghq_d)
      error("gllvmTMB_multi: aghq_Lt must be n_sites x (aghq_d * aghq_d)");
    if (aghq_logdet.size() != n_sites)
      error("gllvmTMB_multi: aghq_logdet must have one entry per site");
    for (int o = 0; o < y.size(); o++) {
      if (family_id_vec(o) == 16)
        error("gllvmTMB_multi: use_aghq does not yet support multinomial rows");
      if (site_id(o) < 0 || site_id(o) >= n_sites)
        error("gllvmTMB_multi: site_id out of range under use_aghq");
    }
    Type half_log_2pi = Type(0.5) * log(Type(2.0) * M_PI);
    for (int s = 0; s < n_sites; s++) {
      for (int j = 0; j < aghq_n_node; j++) {
        Type quad = Type(0.0);
        for (int a = 0; a < aghq_d; a++) {
          // Row-major L^{-T}: entry (a, b) at column a * aghq_d + b.
          Type z_a = aghq_mode(s, a);
          for (int b = 0; b < aghq_d; b++)
            z_a += aghq_Lt(s, a * aghq_d + b) * aghq_nodes(j, b);
          aghq_z(s, j, a) = z_a;
          quad += z_a * z_a;
        }
        // log N(z_ij; 0, I) -- the latent prior, evaluated INSIDE the
        // quadrature (it was removed from nll above under use_aghq == 1).
        aghq_site_ll(s, j) = -Type(0.5) * quad - Type(aghq_d) * half_log_2pi;
      }
    }
  }

  for (int o = 0; o < y.size(); o++) {
    // Capture the running NLL so we can scale this row's contribution by
    // its weight after the family-dispatch block. Mirrors the
    // `tmp_ll *= weights_i(i)` pattern in src/gllvmTMB.cpp around line 1136.
    Type nll_before_row = nll;
    // multinomial (fid 16): the K-1 category-contrast pseudo-rows of one
    // categorical observation are contiguous and share multinom_group_id(o).
    // Evaluate the grouped baseline-category softmax density ONCE, at the
    // group's ANCHOR (first) row; the other K-2 rows are a no-op. This is the
    // anti-double-counting contract (the loop otherwise sums rows
    // independently). Baseline category 1 is the implicit eta = 0 normaliser
    // term; y(o+j) is the 0/1 indicator "observed == contrast j".
    if (family_id_vec(o) == 16) {
      bool is_anchor = (o == 0) ||
                       (multinom_group_id(o) != multinom_group_id(o - 1));
      if (is_anchor && is_y_observed(o)) {
        int t_mn = trait_id(o);
        int L_mn = multinom_K_per_trait(t_mn);       // = K_t - 1 contrast rows
        Type m_mn = Type(0.0);                        // baseline 0 seeds the max
        for (int j = 0; j < L_mn; ++j) {
          m_mn = CppAD::CondExpGt(eta(o + j), m_mn, eta(o + j), m_mn);
        }
        Type s_mn = exp(Type(0.0) - m_mn);            // baseline exp(0 - m)
        for (int j = 0; j < L_mn; ++j) {
          s_mn += exp(eta(o + j) - m_mn);
        }
        Type log_denom_mn = m_mn + log(s_mn);         // s >= 1 -> finite
        Type num_mn = Type(0.0);
        for (int j = 0; j < L_mn; ++j) {
          num_mn += y(o + j) * eta(o + j);            // one-hot picks observed eta
        }
        Type logp_mn = num_mn - log_denom_mn;
        Type log_tiny_mn = log(Type(1e-12));          // defensive AD-safe floor
        logp_mn = CppAD::CondExpLt(logp_mn, log_tiny_mn, log_tiny_mn, logp_mn);
        nll -= logp_mn;
      }
    }
    // The discrete-row GATE (design 68 sec.2 / drmTMB src/drmTMB.cpp:1163-1170).
    // For a row whose unit has a MISSING discrete predictor (mi_family in
    // {1, 2}, mi_observed_unit(unit) == 0), the per-state response density is
    // folded into the per-unit SUM (mi_acc below), so the ordinary family term
    // must NOT also fire -- otherwise y is double-counted. The gate consults the
    // per-UNIT observed flag via the long-row -> unit map mi_unit_id (the
    // multivariate adaptation: drmTMB's mi_observed is per response row). The
    // condition is identical for binary and ordered; only the accumulation
    // branch differs (delta-swap vs full-swap).
    bool mi_missing_row = (mi_is_discrete &&
                           mi_observed_unit(mi_unit_id(o)) == 0);
    // Phase 1 response mask: a row with is_y_observed(o) == 0 contributes
    // nothing to the likelihood. Its y(o) is a safe sentinel, so we must NOT
    // evaluate any family density on it (that is the sentinel-invariance
    // guarantee, design 59 sec.9). When all rows are observed (response="drop")
    // this guard is always true -> an exact no-op.
    if (family_id_vec(o) != 16 && is_y_observed(o) && !mi_missing_row) {
      // Ordinary path: observed-y row whose predictor value is NOT a missing
      // discrete x (observed-x units take this path with the true x in eta(o)).
      // fid-16 rows are handled by the multinomial group branch above and skip
      // this per-row family dispatch.
      if (use_aghq == 1) {
        // AGHQ path: instead of adding this row's log-density at the single
        // Laplace point, accumulate it into the row's SITE at every
        // quadrature node. eta(o) here is the base predictor with the z_B
        // block removed (see the eta assembly guard above), so the node loop
        // only adds Lambda_B(t, .) . z_ij.
        //
        // The weight is applied HERE (as on the mi() branch below) because
        // this branch adds nothing to `nll`, so the outer row-weight scaling
        // at the foot of the loop is a no-op for it.
        int s_a = site_id(o);
        int t_a = trait_id(o);
        for (int j = 0; j < aghq_n_node; j++) {
          Type eta_oj = eta(o);
          for (int k = 0; k < d_B; k++)
            eta_oj += Lambda_B(t_a, k) * aghq_z(s_a, j, k);
          aghq_site_ll(s_a, j) += weights_i(o) * obs_loglik(o, eta_oj);
        }
      } else {
        nll -= obs_loglik(o, eta(o));
      }
    } else if (family_id_vec(o) != 16 && is_y_observed(o) && mi_missing_row) {
      // Discrete-SUM path (sec.3.3 steps 1-2): accumulate the per-state
      // response log-density into the unit's K-state accumulator. Weights enter
      // HERE per trait row (the outer weight scaling at the foot of the loop is
      // bypassed for gated rows since row_nll == 0).
      int u = mi_unit_id(o);
      if (mi_family == 1) {
        // Binary: the single-column DELTA-SWAP removes the mi() column's
        // placeholder contribution and inserts the hypothetical state value k
        // in {0, 1}.
        Type eta_base = eta(o) - b_fix(mi_col) * X_fix(o, mi_col);
        mi_acc(u, 0) += weights_i(o) *
          obs_loglik(o, eta_base + b_fix(mi_col) * Type(0.0));
        mi_acc(u, 1) += weights_i(o) *
          obs_loglik(o, eta_base + b_fix(mi_col) * Type(1.0));
      } else {
        // Ordered: the FULL-SWAP (sec.3.4) swaps the ENTIRE fixed-effect linear
        // predictor for its state-k version, leaving every random-effect
        // contribution untouched (those do not depend on x):
        //   eta_state(o,k) = eta(o) - X_fix(o,.).b_fix + X_fix_state(base+k,.).b_fix
        // X_fix_state is filtered to missing-unit rows; mi_state_row(o) is o's
        // 0-indexed K-block base (state fast). Compute the base fixed-effect
        // contribution X_fix(o,.).b_fix once, then add each state's.
        Type eta_minus_fix = eta(o);
        for (int col = 0; col < X_fix.cols(); ++col) {
          eta_minus_fix -= X_fix(o, col) * b_fix(col);
        }
        int base = mi_state_row(o);
        for (int k = 0; k < mi_K; ++k) {
          Type state_fix = Type(0.0);
          for (int col = 0; col < X_fix_state.cols(); ++col) {
            state_fix += X_fix_state(base + k, col) * b_fix(col);
          }
          mi_acc(u, k) += weights_i(o) *
            obs_loglik(o, eta_minus_fix + state_fix);
        }
      }
    }
    // Apply the per-row weight: scale this row's NLL contribution by
    // weights_i(o). Unit weight is a no-op; weight 0 zeroes the row's
    // contribution (cross-validation hold-out semantics). For a masked or
    // gated row the family block above added nothing, so row_nll == 0 and this
    // is a no-op too.
    Type row_nll = nll - nll_before_row;
    nll = nll_before_row + row_nll * weights_i(o);
    if (report_obs_nll == 1 && use_aghq == 0)
      observation_nll(o) = row_nll * weights_i(o);
  }
  if (report_obs_nll == 1 && use_aghq == 0) REPORT(observation_nll);

  // -------- AGHQ collapse: log-sum-exp over the quadrature nodes ---------
  // log L_i = logdet_i + log sum_j exp( logw_j + inner_ll(i, j) ).
  // The max-subtraction is written out explicitly: inner_ll runs to hundreds
  // of nll units here, so a naive sum of exponentials overflows.
  if (use_aghq == 1) {
    vector<Type> aghq_site_logL(n_sites);
    for (int s = 0; s < n_sites; s++) {
      Type m = aghq_logw(0) + aghq_site_ll(s, 0);
      for (int j = 1; j < aghq_n_node; j++) {
        Type cand = aghq_logw(j) + aghq_site_ll(s, j);
        m = CppAD::CondExpGt(cand, m, cand, m);
      }
      Type acc = Type(0.0);
      for (int j = 0; j < aghq_n_node; j++)
        acc += exp(aghq_logw(j) + aghq_site_ll(s, j) - m);
      Type logL_s = aghq_logdet(s) + m + log(acc);
      aghq_site_logL(s) = logL_s;
      nll -= logL_s;
    }
    REPORT(aghq_site_logL);
  }

  // -------- Discrete missing-PREDICTOR SUM: collapse + report ------------
  // Second pass over the M missing units (design 68 sec.3.3 steps 4 + 6):
  // log-sum-exp the 2-state accumulator into nll ONCE per unit, and report the
  // per-unit posterior P(x = 1 | y_u) = exp(acc(u,1) - logspace_add(...)) (the
  // conditional probability, sec.4.4 -- NOT a latent mode). For OBSERVED-x
  // units the ordinary path already fired above; we add only the single
  // matching state's log-prior here (drmTMB MD6a `mi_x * log_p1 + (1-mi_x) *
  // log_p0`, src/drmTMB.cpp:847). mi_probability holds P(x=1|y) at missing
  // units and the observed x value at observed units (drmTMB mi_x_full shape).
  if (has_mi == 1 && mi_family == 1) {
    vector<Type> mi_probability(mi_n_units);
    for (int u = 0; u < mi_n_units; ++u) {
      if (mi_observed_unit(u) == 1) {
        // Observed-x unit: add the matching state's log-prior. mi_x_unit(u) is
        // the observed binary value (0 or 1).
        nll -= mi_x_unit(u) * mi_logp1(u)
             + (Type(1.0) - mi_x_unit(u)) * mi_logp0(u);
        mi_probability(u) = mi_x_unit(u);
      } else {
        // Missing-x unit: collapse the 2-state mixture-of-products ONCE.
        Type log_norm = logspace_add(mi_acc(u, 0), mi_acc(u, 1));
        nll -= log_norm;
        mi_probability(u) = exp(mi_acc(u, 1) - log_norm);
      }
    }
    REPORT(mi_probability);
    REPORT(beta_mi);
    ADREPORT(beta_mi);
  } else if (has_mi == 1 && mi_family == 2) {
    // Ordered (drmTMB MD6b): collapse the K-state mixture-of-products ONCE per
    // missing unit (sec.3.3 step 4) and report (step 6) the per-unit posterior
    // state weights w(u,k) (M x K) and the conditional EXPECTED CATEGORY SCORE
    // sum_k (k+1) w(u,k) (sec.4.4). For OBSERVED-x units the ordinary response
    // path already fired above; add only the single matching state's log-prior
    // (drmTMB MD6b src/drmTMB.cpp:899-913). mi_expected_score holds the expected
    // score at missing units and the observed integer category at observed
    // units; mi_state_probability holds w(u,.) (a one-hot at observed units).
    matrix<Type> mi_state_probability(mi_n_units, mi_K);
    mi_state_probability.setZero();
    vector<Type> mi_expected_score(mi_n_units);
    for (int u = 0; u < mi_n_units; ++u) {
      if (mi_observed_unit(u) == 1) {
        // Observed-x unit: mi_x_unit(u) is the observed integer category 1..K.
        int state = CppAD::Integer(mi_x_unit(u)) - 1;  // 0-indexed
        nll -= mi_log_prior(u, state);
        mi_state_probability(u, state) = Type(1.0);
        mi_expected_score(u) = mi_x_unit(u);
      } else {
        // Missing-x unit: log-sum-exp the K-state accumulator ONCE.
        Type log_norm = mi_acc(u, 0);
        for (int k = 1; k < mi_K; ++k) {
          log_norm = logspace_add(log_norm, mi_acc(u, k));
        }
        nll -= log_norm;
        Type score = Type(0.0);
        for (int k = 0; k < mi_K; ++k) {
          Type posterior = exp(mi_acc(u, k) - log_norm);
          mi_state_probability(u, k) = posterior;
          score += Type(k + 1) * posterior;
        }
        mi_expected_score(u) = score;
      }
    }
    REPORT(mi_expected_score);
    REPORT(mi_state_probability);
    REPORT(mi_cutpoints);
    REPORT(beta_mi);
    ADREPORT(beta_mi);
    ADREPORT(mi_cutpoints);
  } else if (has_mi == 1 && mi_family == 3) {
    // Unordered (drmTMB MD6c): collapse the K-state softmax mixture-of-products
    // ONCE per missing unit (sec.3.3 step 4) and report (step 6) the per-unit
    // posterior state weights w(u,k) (M x K). The conditional MODAL CATEGORY
    // argmax_k w(u,k) is derived R-side from mi_state_probability (the levels are
    // unordered, so there is NO expected score). For OBSERVED-x units the
    // ordinary response path already fired above; add only the single matching
    // state's softmax log-prior (drmTMB MD6c src/drmTMB.cpp:1002-1006).
    // mi_state_probability holds w(u,.) (a one-hot at observed units).
    matrix<Type> mi_state_probability(mi_n_units, mi_K);
    mi_state_probability.setZero();
    for (int u = 0; u < mi_n_units; ++u) {
      if (mi_observed_unit(u) == 1) {
        // Observed-x unit: mi_x_unit(u) is the observed integer category 1..K.
        int state = CppAD::Integer(mi_x_unit(u)) - 1;  // 0-indexed
        nll -= mi_log_prior(u, state);
        mi_state_probability(u, state) = Type(1.0);
      } else {
        // Missing-x unit: log-sum-exp the K-state accumulator ONCE.
        Type log_norm = mi_acc(u, 0);
        for (int k = 1; k < mi_K; ++k) {
          log_norm = logspace_add(log_norm, mi_acc(u, k));
        }
        nll -= log_norm;
        for (int k = 0; k < mi_K; ++k) {
          mi_state_probability(u, k) = exp(mi_acc(u, k) - log_norm);
        }
      }
    }
    REPORT(mi_state_probability);
    REPORT(beta_mi);
    ADREPORT(beta_mi);
  }

  // -------- Lane B LA-MSPL outer objective --------------------------------
  // TMB adds the Laplace log determinant outside this joint template. These
  // penalties contain outer parameters only, so adding them here leaves the
  // conditional random mode and its Hessian unchanged.
  // Bernoulli: Jeffreys + V_loading (+ spatial covariance terms).
  // Gaussian ordinary (pick C): Hirose atom only — c_N * sum_j S_jj / psi_j
  // with psi_j = sd_B(j)^2 and c_N = sqrt(2/N). No Jeffreys, no V_loading.
  Type joint_nll_unpenalized = nll;
  Type mspl_c_n = Type(0.0);
  Type mspl_logdet_information = Type(0.0);
  Type mspl_V_loading = Type(0.0);
  Type mspl_V_covariance = Type(0.0);
  Type mspl_V_hirose = Type(0.0);
  Type mspl_jeffreys_nll = Type(0.0);
  Type mspl_loading_nll = Type(0.0);
  Type mspl_covariance_nll = Type(0.0);
  Type mspl_hirose_nll = Type(0.0);
  Type mspl_V_dispersion = Type(0.0);
  Type mspl_dispersion_nll = Type(0.0);
  Type mspl_private_ridge_nll = Type(0.0);
  Type mspl_status = Type(0.0);       // 0 = ML/not requested, 1 = MSPL active
  Type mspl_atom_status = Type(-1.0); // frozen V8Status; -1 = not requested
  Type mspl_structure_id = Type(0.0); // 1 ordinary, 2 spatial_indep, 3 spatial_latent
  Type mspl_family_mode_rep = Type(0.0); // 1 Bernoulli, 2 Gaussian
  Type mspl_log_range_ratio = Type(0.0);
  vector<Type> mspl_log_sigma_spde_reference(n_traits);
  mspl_log_sigma_spde_reference.setZero();
  matrix<Type> mspl_Lambda_spde_reference(n_traits, std::max(spde_lv_k, 1));
  mspl_Lambda_spde_reference.setZero();

  if (estimator_id == 1) {
    mspl_status = Type(1.0);
    mspl_structure_id = Type(mspl_structure_id_int);
    mspl_family_mode_rep = Type(mspl_family_mode);
    if (mspl_family_mode == 2) {
      // Pick C: psi_j = sd_B(j)^2 = exp(2 * theta_diag_B(j)).
      vector<Type> psi(n_traits);
      for (int t = 0; t < n_traits; ++t)
        psi(t) = exp(Type(2.0) * theta_diag_B(t));
      mspl_V_hirose = gll_mspl_hirose_atom(mspl_S_diag, psi);
      mspl_c_n = sqrt(Type(2.0) / Type(mspl_N_units));
      mspl_hirose_nll = mspl_c_n * mspl_V_hirose;
      mspl_atom_status = Type(0.0);
      nll += mspl_hirose_nll;
    } else {
      // Bernoulli keeps the validated rate. Poisson uses event-count
      // c_P = 2 * sqrt(p_free / max(sum(y), 1)). Fenced GLM-outer
      // families stay at unpinned c=1 (not admitted here).
      if (mspl_family_mode == 1)
        mspl_c_n = Type(2.0) * sqrt(Type(p_free) / Type(N_eff));
      else if (mspl_family_mode == 3) {
        Type event_count = Type(0.0);
        for (int o = 0; o < y.size(); ++o)
          event_count += y(o);
        event_count = CppAD::CondExpLt(event_count, Type(1.0),
                                       Type(1.0), event_count);
        mspl_c_n = Type(2.0) * sqrt(Type(p_free) / event_count);
      } else
        mspl_c_n = Type(1.0);
      vector<Type> mspl_logw(N_eff);
      int link_id = link_id_vec(0);
      int fid = family_id_vec(0);
      for (int o = 0; o < N_eff; ++o) {
        Type eta_fixed_offset = eta_fix(o) + offset_vec(o);
        int t = trait_id(o);
        Type log_phi = Type(0.0);
        Type logit_p = Type(0.0);
        if (fid == 5)
          log_phi = log_phi_nbinom2(t);
        else if (fid == 15)
          log_phi = log_phi_nbinom1(t);
        else if (fid == 7)
          log_phi = log_phi_beta(t);
        else if (fid == 6) {
          log_phi = log_phi_tweedie(t);
          logit_p = logit_p_tweedie(t);
        }
        if (fid == 1) {
          mspl_logw(o) = gll_mspl_log_weight(eta_fixed_offset, link_id);
          if (link_id == 2) {
            mspl_cloglog_weight_tail_extension_count += CppAD::CondExpGt(
              eta_fixed_offset, Type(690.0), Type(1.0), Type(0.0));
          }
        } else {
          mspl_logw(o) = gll_mspl_log_weight_glm(
            eta_fixed_offset, fid, link_id, log_phi, logit_p);
        }
      }
      vector<Type> atom = gll_mspl_atomic_half_logdet(mspl_logw, X_mspl);
      Type mspl_half_logdet_information = atom(0);
      mspl_atom_status = atom(1);
      mspl_logdet_information = Type(2.0) * mspl_half_logdet_information;
      if (mspl_structure_id_int == 1) {
        if (mspl_family_mode == 3)
          mspl_V_loading = gll_mspl_poisson_event_radial_penalty(
            Lambda_B, y, trait_id, d_B, n_traits);
        else
          mspl_V_loading = gll_mspl_row_radial_penalty(Lambda_B, d_B);
      } else {
        Type half_log_4pi = Type(0.5) * log(Type(4.0) * M_PI);
        mspl_log_range_ratio = Type(0.5) * log(Type(8.0)) -
          log_kappa_spde - log(spde_r0);
        mspl_V_covariance = gll_mspl_pseudohuber(mspl_log_range_ratio);
        if (mspl_structure_id_int == 2) {
          for (int t = 0; t < n_traits; ++t) {
            mspl_log_sigma_spde_reference(t) = -half_log_4pi -
              log_kappa_spde - log_tau_spde(t);
          }
          for (int j = 0; j < mspl_tau_representative.size(); ++j) {
            int t = mspl_tau_representative(j);
            mspl_V_covariance += gll_mspl_pseudohuber(
              mspl_log_sigma_spde_reference(t));
          }
        } else {
          Type loading_scale = exp(-half_log_4pi - log_kappa_spde);
          for (int t = 0; t < n_traits; ++t)
            for (int k = 0; k < spde_lv_k; ++k)
              mspl_Lambda_spde_reference(t, k) =
                loading_scale * Lambda_spde(t, k);
          mspl_V_loading = gll_mspl_row_radial_penalty(
            mspl_Lambda_spde_reference, spde_lv_k);
        }
      }
      mspl_jeffreys_nll = -mspl_c_n * mspl_half_logdet_information;
      mspl_loading_nll = mspl_c_n * mspl_V_loading;
      mspl_covariance_nll = mspl_c_n * mspl_V_covariance;
      if (fid == 6) {
        // Huber on unconstrained Tweedie extras. Working W_* is
        // phi-inert, so this is what kills |log phi| and
        // |logit(p-1)|. Not admitted.
        for (int t = 0; t < n_traits; ++t) {
          mspl_V_dispersion += gll_mspl_pseudohuber(log_phi_tweedie(t));
          mspl_V_dispersion += gll_mspl_pseudohuber(logit_p_tweedie(t));
        }
        mspl_dispersion_nll = mspl_c_n * mspl_V_dispersion;
      }
      nll += mspl_jeffreys_nll + mspl_loading_nll + mspl_covariance_nll +
        mspl_dispersion_nll;
    }
  }
  Type joint_nll_penalized = nll;
  Type mspl_cloglog_tail_extension_count =
    mspl_cloglog_likelihood_tail_extension_count +
    mspl_cloglog_weight_tail_extension_count;

  REPORT(joint_nll_unpenalized);
  REPORT(joint_nll_penalized);
  REPORT(mspl_c_n);
  REPORT(mspl_logdet_information);
  REPORT(mspl_V_loading);
  REPORT(mspl_V_covariance);
  REPORT(mspl_V_hirose);
  REPORT(mspl_jeffreys_nll);
  REPORT(mspl_loading_nll);
  REPORT(mspl_covariance_nll);
  REPORT(mspl_hirose_nll);
  REPORT(mspl_V_dispersion);
  REPORT(mspl_dispersion_nll);
  REPORT(mspl_private_ridge_nll);
  REPORT(mspl_cloglog_tail_extension_count);
  REPORT(mspl_cloglog_likelihood_tail_extension_count);
  REPORT(mspl_cloglog_weight_tail_extension_count);
  REPORT(mspl_status);
  REPORT(mspl_atom_status);
  REPORT(mspl_structure_id);
  REPORT(mspl_family_mode_rep);
  REPORT(mspl_log_range_ratio);
  REPORT(mspl_log_sigma_spde_reference);
  REPORT(mspl_Lambda_spde_reference);

  ADREPORT(b_fix);
  if (integrate_gaussian_diag_B == 1) {
    // These moments condition on the retained random effects and parameters.
    // ADREPORT(mean) propagates their uncertainty; R adds the conditional
    // variance below to recover the original s_B marginal standard errors.
    // Reconstruct eta only AFTER every likelihood/penalty use of eta_0.
    matrix<Type> s_B_conditional_mean(n_traits, n_sites);
    matrix<Type> s_B_conditional_variance(n_traits, n_sites);
    Type eps_variance = sigma_eps_gaussian * sigma_eps_gaussian;
    for (int o = 0; o < y.size(); ++o) {
      int t = trait_id(o);
      int s = site_id(o);
      Type psi = exp(Type(2) * theta_diag_B(t));
      Type weight = psi / (psi + eps_variance);
      s_B_conditional_mean(t, s) = weight * (y(o) - eta(o));
      s_B_conditional_variance(t, s) = weight * eps_variance;
      eta(o) += s_B_conditional_mean(t, s);
    }
    REPORT(s_B_conditional_mean);
    ADREPORT(s_B_conditional_mean);
    REPORT(s_B_conditional_variance);
  }
  REPORT(eta);

  // Per-trait dispersion / power for NB2 and Tweedie. These are reported
  // unconditionally; the R side only reads them when the corresponding
  // family is in use (and TMB's `map` zeroes their gradient otherwise).
  vector<Type> phi_nbinom2 = exp(log_phi_nbinom2);
  vector<Type> phi_nbinom1 = exp(log_phi_nbinom1);
  vector<Type> phi_tweedie = exp(log_phi_tweedie);
  vector<Type> p_tweedie(logit_p_tweedie.size());
  for (int i = 0; i < logit_p_tweedie.size(); i++) {
    p_tweedie(i) = Type(1.0) + invlogit(logit_p_tweedie(i));
  }
  vector<Type> phi_beta = exp(log_phi_beta);
  vector<Type> phi_betabinom = exp(log_phi_betabinom);
  REPORT(phi_nbinom2);
  REPORT(phi_nbinom1);
  REPORT(phi_tweedie);
  vector<Type> phi_gamma = exp(log_phi_gamma);
  REPORT(phi_gamma);
  REPORT(p_tweedie);
  REPORT(phi_beta);
  REPORT(phi_betabinom);

  // Zero-inflated families (fid 17/18/19): per-trait structural-zero
  // probability. REPORT only (not ADREPORT), matching every other
  // dispersion vector above -- none of them get a delta-method SE either.
  vector<Type> zi = invlogit(logit_zi);
  REPORT(zi);

  // Student-t per-trait sigma and df (df = 1 + exp(log_df_student)).
  vector<Type> sigma_student = exp(log_sigma_student);
  vector<Type> df_student(log_df_student.size());
  for (int i = 0; i < log_df_student.size(); i++) {
    df_student(i) = Type(1.0) + exp(log_df_student(i));
  }
  REPORT(sigma_student);
  REPORT(df_student);

  // truncated NB2 per-trait phi.
  vector<Type> phi_truncnb2 = exp(log_phi_truncnb2);
  REPORT(phi_truncnb2);

  // Delta-family per-trait dispersion (positive component only).
  vector<Type> sigma_lognormal_delta = exp(log_sigma_lognormal_delta);
  vector<Type> phi_gamma_delta       = exp(log_phi_gamma_delta);
  REPORT(sigma_lognormal_delta);
  REPORT(phi_gamma_delta);

  // ordinal_probit cutpoints, reconstructed from log-increments and packed
  // back into a flat vector in the same layout as ordinal_log_increments.
  // The R side splits these by trait via ordinal_offset_per_trait. Each
  // trait's segment holds {tau_2, ..., tau_{K-1}} (length K_t - 2).
  vector<Type> ordinal_cutpoints(ordinal_log_increments.size());
  ordinal_cutpoints.setZero();   // initialise so TMB doesn't see undefined memory
  for (int t = 0; t < n_traits; t++) {
    int K_minus_2 = n_ordinal_cuts_per_trait(t);
    if (K_minus_2 == 0) continue;
    int offset = ordinal_offset_per_trait(t);
    Type running = Type(0.0);   // tau_1 = 0
    for (int j = 0; j < K_minus_2; j++) {
      running += exp(ordinal_log_increments(offset + j));
      ordinal_cutpoints(offset + j) = running;
    }
  }
  REPORT(ordinal_cutpoints);
  ADREPORT(ordinal_cutpoints);

  return nll;
}
