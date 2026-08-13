#ifndef GLLVMTMB_LANE_B_JEFFREYS_MAXVOL_ATOMIC_V8_HPP
#define GLLVMTMB_LANE_B_JEFFREYS_MAXVOL_ATOMIC_V8_HPP

// Frozen Lane B v8 numerically guarded maximum-volume Jeffreys atom.
// Mechanically ported from the SHA-verified external prototype bundle.
// Guarded backend core from the frozen external R&D prototype v1.  The
// a-posteriori certificate covers the inverse/exchange decision, not a formal
// interval enclosure for every returned value or derivative entry.
// Exact-dyadic modular rank start + adaptive-style multiprecision
// one-row-exchange maximum-volume refinement.

#include <boost/multiprecision/cpp_dec_float.hpp>
#include <boost/multiprecision/cpp_int.hpp>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <random>
#include <stdexcept>
#include <vector>

using boost::multiprecision::cpp_int;
using boost::multiprecision::cpp_rational;
using mp = boost::multiprecision::number<boost::multiprecision::cpp_dec_float<100> >;
using DMat = std::vector<std::vector<double> >;
using MMat = std::vector<std::vector<mp> >;

static uint64_t powmod(uint64_t a, uint64_t e, uint64_t q) {
  uint64_t z = 1;
  while (e) {
    if (e & 1) z = (z * a) % q;
    a = (a * a) % q;
    e >>= 1;
  }
  return z;
}

struct Dyadic {
  bool neg;
  uint64_t mant;
  int exp2;
};

static Dyadic dyadic(double x) {
  uint64_t u;
  std::memcpy(&u, &x, sizeof(u));
  bool neg = (u >> 63) != 0;
  uint64_t eb = (u >> 52) & 0x7ffULL;
  uint64_t frac = u & ((1ULL << 52) - 1ULL);
  if (eb == 0) return {neg, frac, -1074};
  if (eb == 0x7ffULL) throw std::runtime_error("non-finite double");
  return {neg, (1ULL << 52) | frac, int(eb) - 1023 - 52};
}

static uint64_t mod_dyadic(double x, uint64_t q) {
  Dyadic d = dyadic(x);
  if (d.mant == 0) return 0;
  uint64_t z = d.mant % q;
  if (d.exp2 >= 0) z = (z * powmod(2, uint64_t(d.exp2), q)) % q;
  else {
    uint64_t inv2 = (q + 1) / 2;
    z = (z * powmod(inv2, uint64_t(-d.exp2), q)) % q;
  }
  return d.neg && z ? q - z : z;
}

static cpp_rational rat_dyadic(double x) {
  Dyadic d = dyadic(x);
  if (d.mant == 0) return cpp_rational(0);
  cpp_int z = d.mant;
  if (d.neg) z = -z;
  if (d.exp2 >= 0) return cpp_rational(z << d.exp2);
  return cpp_rational(z, cpp_int(1) << (-d.exp2));
}

static int rank_mod(const DMat &X, const std::vector<int> &rows, uint64_t q) {
  int m = int(rows.size()), p = int(X[0].size()), r = 0;
  std::vector<std::vector<uint64_t> > a(m, std::vector<uint64_t>(p));
  for (int i = 0; i < m; ++i)
    for (int j = 0; j < p; ++j) a[i][j] = mod_dyadic(X[rows[i]][j], q);
  for (int col = 0; col < p && r < m; ++col) {
    int piv = r;
    while (piv < m && a[piv][col] == 0) ++piv;
    if (piv == m) continue;
    std::swap(a[piv], a[r]);
    uint64_t inv = powmod(a[r][col], q - 2, q);
    for (int j = col; j < p; ++j) a[r][j] = (a[r][j] * inv) % q;
    for (int i = r + 1; i < m; ++i) if (a[i][col]) {
      uint64_t f = a[i][col];
      for (int j = col; j < p; ++j) {
        uint64_t sub = (f * a[r][j]) % q;
        a[i][j] = a[i][j] >= sub ? a[i][j] - sub : a[i][j] + q - sub;
      }
    }
    ++r;
  }
  return r;
}

static int rank_exact(const DMat &X, const std::vector<int> &rows) {
  int m = int(rows.size()), p = int(X[0].size()), r = 0;
  std::vector<std::vector<cpp_rational> > a(m, std::vector<cpp_rational>(p));
  for (int i = 0; i < m; ++i)
    for (int j = 0; j < p; ++j) a[i][j] = rat_dyadic(X[rows[i]][j]);
  for (int col = 0; col < p && r < m; ++col) {
    int piv = r;
    while (piv < m && a[piv][col] == 0) ++piv;
    if (piv == m) continue;
    std::swap(a[piv], a[r]);
    cpp_rational d = a[r][col];
    for (int j = col; j < p; ++j) a[r][j] /= d;
    for (int i = r + 1; i < m; ++i) if (a[i][col] != 0) {
      cpp_rational f = a[i][col];
      for (int j = col; j < p; ++j) a[i][j] -= f * a[r][j];
    }
    ++r;
  }
  return r;
}

static std::vector<int> exact_basis(const DMat &X, const std::vector<double> &lw,
                                    int &exact_fallbacks) {
  int n = int(X.size()), p = int(X[0].size());
  std::vector<int> ord(n), basis;
  std::iota(ord.begin(), ord.end(), 0);
  std::stable_sort(ord.begin(), ord.end(), [&](int i, int j) {
    if (lw[i] != lw[j]) return lw[i] > lw[j];
    for (int k = 0; k < p; ++k) {
      Dyadic a = dyadic(X[i][k]), b = dyadic(X[j][k]);
      if (a.neg != b.neg || a.mant != b.mant || a.exp2 != b.exp2)
        return X[i][k] < X[j][k];
    }
    return i < j;
  });
  const uint64_t primes[] = {1000000007ULL, 1000000009ULL, 998244353ULL};
  exact_fallbacks = 0;
  for (int cand : ord) {
    std::vector<int> trial = basis;
    trial.push_back(cand);
    bool independent = false;
    for (uint64_t q : primes)
      if (rank_mod(X, trial, q) == int(trial.size())) { independent = true; break; }
    if (!independent) {
      ++exact_fallbacks;
      independent = rank_exact(X, trial) == int(trial.size());
    }
    if (independent) basis.push_back(cand);
    if (int(basis.size()) == p) return basis;
  }
  throw std::runtime_error("exact rank deficient design");
}

static MMat inverse_basis(const DMat &X, const std::vector<int> &basis,
                          mp &log_abs_det) {
  int p = int(basis.size());
  MMat a(p, std::vector<mp>(2 * p));
  for (int i = 0; i < p; ++i) {
    for (int j = 0; j < p; ++j) a[i][j] = mp(X[basis[i]][j]);
    a[i][p + i] = 1;
  }
  log_abs_det = 0;
  for (int col = 0; col < p; ++col) {
    int piv = col;
    for (int i = col + 1; i < p; ++i)
      if (abs(a[i][col]) > abs(a[piv][col])) piv = i;
    if (a[piv][col] == 0) throw std::runtime_error("MP singular basis");
    std::swap(a[piv], a[col]);
    mp d = a[col][col];
    log_abs_det += log(abs(d));
    for (int j = 0; j < 2 * p; ++j) a[col][j] /= d;
    for (int i = 0; i < p; ++i) if (i != col && a[i][col] != 0) {
      mp f = a[i][col];
      for (int j = 0; j < 2 * p; ++j) a[i][j] -= f * a[col][j];
    }
  }
  MMat inv(p, std::vector<mp>(p));
  for (int i = 0; i < p; ++i)
    for (int j = 0; j < p; ++j) inv[i][j] = a[i][p + j];
  return inv;
}

struct RefineResult {
  std::vector<int> basis;
  int exchanges;
  mp max_log_gain;
  mp log_abs_det;
  double coordinate_seconds;
};

static std::vector<std::vector<double> > inverse_basis_double(
    const DMat &X, const std::vector<int> &basis) {
  int p = int(basis.size());
  DMat a(p, std::vector<double>(2 * p));
  for (int i = 0; i < p; ++i) {
    for (int j = 0; j < p; ++j) a[i][j] = X[basis[i]][j];
    a[i][p + i] = 1;
  }
  for (int col = 0; col < p; ++col) {
    int piv = col;
    for (int i = col + 1; i < p; ++i)
      if (std::abs(a[i][col]) > std::abs(a[piv][col])) piv = i;
    if (a[piv][col] == 0) throw std::runtime_error("double singular basis");
    std::swap(a[piv], a[col]);
    double d = a[col][col];
    for (int j = 0; j < 2 * p; ++j) a[col][j] /= d;
    for (int i = 0; i < p; ++i) if (i != col && a[i][col] != 0) {
      double f = a[i][col];
      for (int j = 0; j < 2 * p; ++j) a[i][j] -= f * a[col][j];
    }
  }
  DMat inv(p, std::vector<double>(p));
  for (int i = 0; i < p; ++i)
    for (int j = 0; j < p; ++j) inv[i][j] = a[i][p + j];
  return inv;
}

static std::pair<int, double> refine_maxvol_double(
    const DMat &X, const std::vector<double> &lw, std::vector<int> basis,
    double tau, int max_exchange = 100) {
  int n = int(X.size()), p = int(X[0].size()), exchanges = 0;
  while (true) {
    DMat inv = inverse_basis_double(X, basis);
    std::vector<char> in_basis(n, 0);
    for (int i : basis) in_basis[i] = 1;
    int best_i = -1, best_j = -1;
    double best_gain = std::log1p(tau), final_max = -INFINITY;
    for (int i = 0; i < n; ++i) if (!in_basis[i]) {
      for (int j = 0; j < p; ++j) {
        double c = 0;
        for (int k = 0; k < p; ++k) c += X[i][k] * inv[k][j];
        if (c == 0) continue;
        double gain = std::log(std::abs(c)) + 0.5 * (lw[i] - lw[basis[j]]);
        final_max = std::max(final_max, gain);
        if (gain > best_gain) { best_gain = gain; best_i = i; best_j = j; }
      }
    }
    if (best_i < 0) return {exchanges, std::exp(final_max)};
    basis[best_j] = best_i;
    if (++exchanges >= max_exchange) throw std::runtime_error("double exchange cap");
  }
}

struct InverseCertificate {
  DMat inv;
  double inverse_error_inf;
  double eta;
};

// A posteriori certificate for the stored double inverse R.  E = I-XB*R is
// bounded with a standard gamma_p dot-product allowance.  If ||E||_inf < 1,
// Neumann gives ||XB^-1-R||_inf <= ||R||_inf*eta/(1-eta).
static InverseCertificate inverse_certificate(const DMat &X,
                                              const std::vector<int> &basis) {
  int p = int(basis.size());
  DMat R = inverse_basis_double(X, basis);
  long double eta = 0;
  const long double eps = std::numeric_limits<double>::epsilon() / 2.0L;
  const long double gamma = (p * eps) / (1.0L - p * eps);
  for (int i = 0; i < p; ++i) {
    long double rowsum = 0;
    for (int j = 0; j < p; ++j) {
      long double dot = 0, absdot = 0;
      for (int k = 0; k < p; ++k) {
        long double term = (long double)X[basis[i]][k] * (long double)R[k][j];
        dot += term; absdot += std::abs(term);
      }
      long double target = i == j ? 1.0L : 0.0L;
      rowsum += std::abs(target - dot) + gamma * absdot;
    }
    eta = std::max(eta, rowsum);
  }
  long double rinf = 0;
  for (int i = 0; i < p; ++i) {
    long double s = 0;
    for (int j = 0; j < p; ++j) s += std::abs((long double)R[i][j]);
    rinf = std::max(rinf, s);
  }
  if (!(eta < 1)) return {R, INFINITY, double(eta)};
  long double err = rinf * eta / (1.0L - eta);
  return {R, double(err), double(eta)};
}

struct HybridResult {
  std::vector<int> basis;
  int exchanges;
  int mp_scans;
  int ambiguous_coordinates;
  double seconds;
  double final_max_abs_A;
  double final_eta;
};

static HybridResult refine_maxvol_hybrid(const DMat &X,
    const std::vector<double> &lw, std::vector<int> basis,
    double tau, int max_exchange = 200) {
  int n = int(X.size()), p = int(X[0].size());
  int exchanges = 0, mp_scans = 0, ambiguous_total = 0;
  double final_max = 0, final_eta = INFINITY;
  const long double eps = std::numeric_limits<double>::epsilon() / 2.0L;
  const long double gamma = (p * eps) / (1.0L - p * eps);
  const double threshold = std::log1p(tau);
  auto begin = std::chrono::steady_clock::now();
  while (true) {
    InverseCertificate cert = inverse_certificate(X, basis);
    final_eta = cert.eta;
    std::vector<char> in_basis(n, 0);
    for (int i : basis) in_basis[i] = 1;
    if (!std::isfinite(cert.inverse_error_inf)) {
      ++mp_scans;
      mp logdet;
      MMat inv = inverse_basis(X, basis, logdet);
      mp mp_threshold = log(mp(1) + mp(tau)), best = mp_threshold, mpmax = -INFINITY;
      int bi = -1, bj = -1;
      for (int i = 0; i < n; ++i) if (!in_basis[i]) for (int j = 0; j < p; ++j) {
        mp c = 0;
        for (int k = 0; k < p; ++k) c += mp(X[i][k]) * inv[k][j];
        if (c == 0) continue;
        mp gain = log(abs(c)) + mp(0.5) * (mp(lw[i]) - mp(lw[basis[j]]));
        if (gain > mpmax) mpmax = gain;
        if (gain > best) { best = gain; bi = i; bj = j; }
      }
      if (bi >= 0) {
        basis[bj] = bi;
        if (++exchanges >= max_exchange) throw std::runtime_error("hybrid exchange cap");
        continue;
      }
      final_max = mpmax > -INFINITY ? exp(mpmax).convert_to<double>() : 0;
      break;
    }
    int exchange_i = -1, exchange_j = -1;
    double exchange_lower = threshold;
    struct Amb { int i, j; };
    std::vector<Amb> ambiguous;
    final_max = 0;
    double certified_max = 0;
    for (int i = 0; i < n; ++i) if (!in_basis[i]) {
      long double b1 = 0;
      for (int k = 0; k < p; ++k) b1 += std::abs((long double)X[i][k]);
      for (int j = 0; j < p; ++j) {
        long double chat = 0, absdot = 0;
        for (int k = 0; k < p; ++k) {
          long double term = (long double)X[i][k] * (long double)cert.inv[k][j];
          chat += term; absdot += std::abs(term);
        }
        long double cerr = b1 * cert.inverse_error_inf + gamma * absdot;
        long double lo = std::max((long double)0, std::abs(chat) - cerr);
        long double hi = std::abs(chat) + cerr;
        long double d = 0.5L * ((long double)lw[i] - (long double)lw[basis[j]]);
        double loglo = lo > 0 ? double(log(lo) + d) : -INFINITY;
        double loghi = hi > 0 ? double(log(hi) + d) : -INFINITY;
        if (loglo > exchange_lower) {
          exchange_lower = loglo; exchange_i = i; exchange_j = j;
        } else if (loghi > threshold) ambiguous.push_back({i, j});
        else if (loghi > -745) certified_max = std::max(certified_max, std::exp(loghi));
      }
    }
    if (exchange_i >= 0) {
      basis[exchange_j] = exchange_i;
      if (++exchanges >= max_exchange) throw std::runtime_error("hybrid exchange cap");
      continue;
    }
    if (!ambiguous.empty()) {
      ++mp_scans;
      ambiguous_total += int(ambiguous.size());
      mp logdet;
      MMat inv = inverse_basis(X, basis, logdet);
      mp mp_threshold = log(mp(1) + mp(tau));
      mp best = mp_threshold, mpmax = -INFINITY;
      for (const Amb &a : ambiguous) {
        mp c = 0;
        for (int k = 0; k < p; ++k) c += mp(X[a.i][k]) * inv[k][a.j];
        if (c == 0) continue;
        mp gain = log(abs(c)) + mp(0.5) * (mp(lw[a.i]) - mp(lw[basis[a.j]]));
        if (gain > mpmax) mpmax = gain;
        if (gain > best) { best = gain; exchange_i = a.i; exchange_j = a.j; }
      }
      if (exchange_i >= 0) {
        basis[exchange_j] = exchange_i;
        if (++exchanges >= max_exchange) throw std::runtime_error("hybrid exchange cap");
        continue;
      }
      final_max = std::max(certified_max,
        mpmax > -INFINITY ? exp(mpmax).convert_to<double>() : 0.0);
    } else {
      final_max = certified_max;
    }
    break;
  }
  auto end = std::chrono::steady_clock::now();
  return {basis, exchanges, mp_scans, ambiguous_total,
          std::chrono::duration<double>(end-begin).count(), final_max, final_eta};
}

#include <TMB.hpp>
#include <algorithm>
#include <limits>
#include <numeric>
#include <vector>

enum class V8Status : int {
  OK_DOUBLE_CERTIFIED = 0,
  OK_MP_CERTIFIED = 1,
  INPUT_NONFINITE = 10,
  DESIGN_RANK_DEFICIENT = 11,
  MAXVOL_UNCERTIFIED = 12,
  FACTORIZATION_FAILED = 13,
  DERIVATIVE_ORDER_UNSUPPORTED = 20
};

struct V8Cache {
  bool valid = false;
  std::vector<double> key;
  double value = R_NaN;
  std::vector<double> gradient;
  Eigen::MatrixXd A;
  Eigen::MatrixXd Ginv;
  V8Status status = V8Status::MAXVOL_UNCERTIFIED;
};

static thread_local V8Cache v8_cache;
static thread_local V8Status v8_last_status = V8Status::MAXVOL_UNCERTIFIED;

struct LDInverseCertificate {
  std::vector<std::vector<long double> > inv;
  long double inverse_error_inf = INFINITY;
  long double eta = INFINITY;
  long double log_abs_det = 0;
};

static LDInverseCertificate inverse_certificate_ld(
    const DMat &X, const std::vector<int> &basis) {
  int p = int(basis.size());
  std::vector<std::vector<long double> > aug(
    p, std::vector<long double>(2 * p, 0));
  LDInverseCertificate ans;
  for (int i = 0; i < p; ++i) {
    for (int j = 0; j < p; ++j) aug[i][j] = X[basis[i]][j];
    aug[i][p + i] = 1;
  }
  for (int col = 0; col < p; ++col) {
    int piv = col;
    for (int i = col + 1; i < p; ++i)
      if (fabsl(aug[i][col]) > fabsl(aug[piv][col])) piv = i;
    if (aug[piv][col] == 0 || !std::isfinite(aug[piv][col])) return {};
    std::swap(aug[piv], aug[col]);
    long double d = aug[col][col];
    ans.log_abs_det += logl(fabsl(d));
    for (int j = 0; j < 2 * p; ++j) aug[col][j] /= d;
    for (int i = 0; i < p; ++i) if (i != col && aug[i][col] != 0) {
      long double f = aug[i][col];
      for (int j = 0; j < 2 * p; ++j) aug[i][j] -= f * aug[col][j];
    }
  }
  ans.inv.assign(p, std::vector<long double>(p));
  for (int i = 0; i < p; ++i)
    for (int j = 0; j < p; ++j) ans.inv[i][j] = aug[i][p + j];
  const long double eps = std::numeric_limits<long double>::epsilon() / 2;
  const long double gamma = (p * eps) / (1 - p * eps);
  ans.eta = 0;
  for (int i = 0; i < p; ++i) {
    long double rowsum = 0;
    for (int j = 0; j < p; ++j) {
      long double dot = 0, absdot = 0;
      for (int k = 0; k < p; ++k) {
        long double term = (long double)X[basis[i]][k] * ans.inv[k][j];
        dot += term; absdot += fabsl(term);
      }
      rowsum += fabsl((i == j ? 1.0L : 0.0L) - dot) + gamma * absdot;
    }
    ans.eta = std::max(ans.eta, rowsum);
  }
  long double rinf = 0;
  for (int i = 0; i < p; ++i) {
    long double s = 0;
    for (int j = 0; j < p; ++j) s += fabsl(ans.inv[i][j]);
    rinf = std::max(rinf, s);
  }
  if (ans.eta < 1) ans.inverse_error_inf = rinf * ans.eta / (1 - ans.eta);
  return ans;
}

static void cached_hvp(const Eigen::MatrixXd &A, const Eigen::MatrixXd &Ginv,
                        const std::vector<double> &gradient,
                        const std::vector<double> &direction,
                        std::vector<double> &hvp) {
  int n = A.rows(), p = A.cols();
  Eigen::MatrixXd C = Eigen::MatrixXd::Zero(p, p);
  for (int i = 0; i < n; ++i)
    C.noalias() += direction[i] * A.row(i).transpose() * A.row(i);
  Eigen::MatrixXd middle = Ginv * C * Ginv;
  hvp.assign(n, 0.0);
  for (int i = 0; i < n; ++i) {
    double second = A.row(i).dot(middle * A.row(i).transpose());
    hvp[i] = 0.5 * (2.0 * gradient[i] * direction[i] - second);
  }
}

template<class Type>
void basis_dims(const CppAD::vector<Type> &tx, int &n, int &p,
                int &lw0, int &x0) {
  n = CppAD::Integer(tx[0]);
  p = CppAD::Integer(tx[1]);
  lw0 = 2;
  x0 = lw0 + n;
}

long double determinant_long_double(const Eigen::MatrixXd &input) {
  int n = input.rows();
  std::vector<long double> a(n * n);
  for (int i = 0; i < n; ++i)
    for (int j = 0; j < n; ++j) a[i * n + j] = input(i, j);
  long double det = 1.0L;
  for (int j = 0; j < n; ++j) {
    int pivot = j;
    for (int i = j + 1; i < n; ++i)
      if (fabsl(a[i * n + j]) > fabsl(a[pivot * n + j])) pivot = i;
    if (a[pivot * n + j] == 0.0L) return 0.0L;
    if (pivot != j) {
      for (int k = j; k < n; ++k) std::swap(a[j * n + k], a[pivot * n + k]);
      det = -det;
    }
    long double diagonal = a[j * n + j];
    det *= diagonal;
    for (int i = j + 1; i < n; ++i) {
      long double multiplier = a[i * n + j] / diagonal;
      for (int k = j + 1; k < n; ++k)
        a[i * n + k] -= multiplier * a[j * n + k];
    }
  }
  return det;
}

bool equilibrate_columns(Eigen::MatrixXd &X, double &log_correction) {
  log_correction = 0.0;
  for (int j = 0; j < X.cols(); ++j) {
    double scale = 0.0;
    for (int i = 0; i < X.rows(); ++i) scale = std::max(scale, fabs(X(i, j)));
    if (!(scale > 0.0) || !R_FINITE(scale)) return false;
    log_correction += log(scale);
    for (int i = 0; i < X.rows(); ++i) X(i, j) /= scale;
  }
  return R_FINITE(log_correction);
}

bool equilibrate_rows(Eigen::MatrixXd &X, std::vector<double> &logw) {
  for (int i = 0; i < X.rows(); ++i) {
    double scale = 0.0;
    for (int j = 0; j < X.cols(); ++j) scale = std::max(scale, fabs(X(i, j)));
    if (scale > 0.0) {
      logw[i] += 2.0 * log(scale);
      if (!R_FINITE(logw[i])) return false;
      for (int j = 0; j < X.cols(); ++j) X(i, j) /= scale;
    }
  }
  return true;
}

bool select_basis(const Eigen::MatrixXd &X, const std::vector<double> &logw,
                  std::vector<int> &basis, double &quality) {
  int n = X.rows(), p = X.cols();
  std::vector<int> order(n);
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) {
    return logw[a] > logw[b];
  });
  basis.clear();
  const double rank_clear = 1e-10, rank_zero = 1e-14;
  size_t group_begin = 0;
  while (group_begin < order.size() && (int) basis.size() < p) {
    size_t group_end = group_begin + 1;
    while (group_end < order.size() &&
           logw[order[group_end]] == logw[order[group_begin]]) ++group_end;
    std::vector<int> group(order.begin() + group_begin, order.begin() + group_end);
    std::stable_sort(group.begin(), group.end(), [&](int a, int b) {
      for (int j = 0; j < p; ++j) {
        if (X(a, j) < X(b, j)) return true;
        if (X(a, j) > X(b, j)) return false;
      }
      return a < b;
    });
    while (!group.empty() && (int) basis.size() < p) {
      int best_position = -1; double best_ratio = -1.0;
      for (int position = 0; position < (int) group.size(); ++position) {
        Eigen::MatrixXd trial((int) basis.size() + 1, p);
        for (int r = 0; r < (int) basis.size(); ++r) trial.row(r) = X.row(basis[r]);
        trial.row((int) basis.size()) = X.row(group[position]);
        Eigen::JacobiSVD<Eigen::MatrixXd> svd(trial);
        Eigen::VectorXd s = svd.singularValues();
        if (s.size() == 0) return false;
        double ratio = s(0) > 0.0 ? s(s.size() - 1) / s(0) : 0.0;
        if (ratio > best_ratio) { best_ratio = ratio; best_position = position; }
      }
      if (best_ratio > rank_clear) {
        basis.push_back(group[best_position]);
        group.erase(group.begin() + best_position);
      } else if (best_ratio >= rank_zero) return false;
      else break;
    }
    group_begin = group_end;
  }
  if ((int) basis.size() != p) return false;
  Eigen::MatrixXd XB(p, p);
  for (int j = 0; j < p; ++j) XB.row(j) = X.row(basis[j]);
  Eigen::JacobiSVD<Eigen::MatrixXd> svd(XB);
  Eigen::VectorXd s = svd.singularValues();
  if (s.size() != p || !(s(p - 1) > 0.0)) return false;
  quality = s(p - 1) / s(0);
  return quality > rank_clear;
}

template<class Type>
bool basis_stats(const CppAD::vector<Type> &tx, double &value,
                 std::vector<double> &gradient,
                 const std::vector<double> *direction,
                 std::vector<double> *hvp,
                 std::vector<int> *basis_out = NULL,
                 const std::vector<double> *third_u = NULL,
                 std::vector<double> *third_out = NULL,
                 std::vector<double> *hu_out = NULL) {
  int n, p, lw0, x0;
  v8_last_status = V8Status::MAXVOL_UNCERTIFIED;
  basis_dims(tx, n, p, lw0, x0);
  Eigen::MatrixXd X(n, p);
  std::vector<double> logw(n);
  for (int i = 0; i < n; ++i) {
    logw[i] = asDouble(tx[lw0 + i]);
    if (!R_FINITE(logw[i])) {
      v8_last_status = V8Status::INPUT_NONFINITE;
      return false;
    }
    for (int j = 0; j < p; ++j) {
      X(i, j) = asDouble(tx[x0 + i + n * j]);
      if (!R_FINITE(X(i, j))) {
        v8_last_status = V8Status::INPUT_NONFINITE;
        return false;
      }
    }
  }
  std::vector<double> cache_key;
  cache_key.reserve(n + n * p);
  cache_key.insert(cache_key.end(), logw.begin(), logw.end());
  for (int j = 0; j < p; ++j)
    for (int i = 0; i < n; ++i) cache_key.push_back(X(i,j));
  if (third_u == NULL && v8_cache.valid && v8_cache.key == cache_key) {
    v8_last_status = v8_cache.status;
    value = v8_cache.value;
    gradient = v8_cache.gradient;
    if (direction != NULL && hvp != NULL)
      cached_hvp(v8_cache.A, v8_cache.Ginv, gradient, *direction, *hvp);
    return true;
  }

  DMat Xcore(n, std::vector<double>(p));
  for (int i = 0; i < n; ++i)
    for (int j = 0; j < p; ++j) Xcore[i][j] = X(i,j);
  std::vector<int> basis;
  int initial_exchanges = 0, initial_mp_scans = 0;
  try {
    int exact_fallbacks = 0;
    basis = exact_basis(Xcore, logw, exact_fallbacks);
    HybridResult refined = refine_maxvol_hybrid(Xcore, logw, basis, 1e-12);
    initial_exchanges = refined.exchanges;
    initial_mp_scans = refined.mp_scans;
    basis = refined.basis;
  } catch (const std::exception &e) {
    std::string why(e.what());
    v8_last_status = why.find("rank deficient") != std::string::npos
      ? V8Status::DESIGN_RANK_DEFICIENT : V8Status::MAXVOL_UNCERTIFIED;
    return false;
  }
  MMat Xeval;
  std::vector<mp> lweval;
  mp log_column_scale_mp = 0;

  // Fast certificate representation: power-of-two row/column scaling is exact
  // for stored dyadic doubles.  Any nonzero-to-zero conversion disables this
  // route and leaves the v7 MP-normalized fallback in charge.
  DMat Xfast = Xcore;
  std::vector<double> lwfast = logw;
  std::vector<long double> lwfast_ld(n);
  std::vector<mp> lwfast_mp(n);
  for (int i = 0; i < n; ++i) {
    lwfast_ld[i] = (long double)logw[i];
    lwfast_mp[i] = mp(logw[i]);
  }
  bool fast_safe = true;
  const long double ln2_ld = std::log(2.0L);
  const mp ln2_mp = log(mp(2));
  mp fast_column_scale_mp = 0;
  long double fast_log_abs_det = 0;
  for (int i = 0; i < n; ++i) {
    double mx = 0;
    for (int j = 0; j < p; ++j) mx = std::max(mx, std::abs(Xfast[i][j]));
    if (mx > 0) {
      int e = 0; std::frexp(mx, &e);
      for (int j = 0; j < p; ++j) {
        double old = Xfast[i][j];
        Xfast[i][j] = std::ldexp(old, -e);
        if (old != 0.0 && Xfast[i][j] == 0.0) fast_safe = false;
      }
      lwfast[i] += double(2.0L * e * ln2_ld);
      lwfast_ld[i] += 2.0L * e * ln2_ld;
      lwfast_mp[i] += mp(2 * e) * ln2_mp;
    }
  }
  for (int j = 0; j < p; ++j) {
    double mx = 0;
    for (int i = 0; i < n; ++i) mx = std::max(mx, std::abs(Xfast[i][j]));
    if (!(mx > 0)) { fast_safe = false; continue; }
    int e = 0; std::frexp(mx, &e);
    fast_column_scale_mp += mp(e) * ln2_mp;
    for (int i = 0; i < n; ++i) {
      double old = Xfast[i][j];
      Xfast[i][j] = std::ldexp(old, -e);
      if (old != 0.0 && Xfast[i][j] == 0.0) fast_safe = false;
    }
  }

  bool fast_certified = false;
  Eigen::MatrixXd Afast = Eigen::MatrixXd::Zero(n, p);
  int fast_exchanges = -1, fast_mp_scans = -1;
  long double fast_eta = INFINITY;
  double fast_max_width = INFINITY, fast_candidate_max = INFINITY,
         fast_max_gamma = INFINITY;
  if (fast_safe) try {
    HybridResult proposal = refine_maxvol_hybrid(Xfast, lwfast, basis, 1e-12);
    fast_exchanges = proposal.exchanges;
    fast_mp_scans = proposal.mp_scans;
    basis = proposal.basis;
    LDInverseCertificate cert = inverse_certificate_ld(Xfast, basis);
    fast_eta = cert.eta;
    fast_log_abs_det = cert.log_abs_det;
    if (std::isfinite(cert.inverse_error_inf)) {
      const long double eps = std::numeric_limits<long double>::epsilon() / 2.0L;
      const long double gamma = (p * eps) / (1.0L - p * eps);
      std::vector<char> in_basis(n, 0);
      for (int j = 0; j < p; ++j) {
        in_basis[basis[j]] = 1; Afast(basis[j], j) = 1.0;
      }
      fast_certified = true;
      const long double log_threshold = log1pl(1e-12L);
      const long double log_round_budget = logl(1e-9L);
      fast_max_width = 0; fast_candidate_max = 0; fast_max_gamma = 0;
      for (int i = 0; i < n && fast_certified; ++i) if (!in_basis[i]) {
        long double b1 = 0;
        for (int k = 0; k < p; ++k) b1 += std::abs((long double)Xfast[i][k]);
        for (int j = 0; j < p; ++j) {
          long double chat = 0, absdot = 0;
          for (int k = 0; k < p; ++k) {
            long double term = (long double)Xfast[i][k] * cert.inv[k][j];
            chat += term; absdot += std::abs(term);
          }
          long double cerr = b1 * cert.inverse_error_inf + gamma * absdot;
          long double hi = std::abs(chat) + cerr;
          long double d = 0.5L * (lwfast_ld[i] - lwfast_ld[basis[j]]);
          long double loghi = hi > 0 ? logl(hi) + d : -INFINITY;
          double hiw = hi > 0 ? double(expl(loghi)) : 0;
          double width = cerr > 0 ? double(2 * cerr * expl(d)) : 0;
          double gamm = absdot > 0 ? double(gamma * absdot * expl(d)) : 0;
          fast_candidate_max = std::max(fast_candidate_max, hiw);
          fast_max_width = std::max(fast_max_width, width);
          fast_max_gamma = std::max(fast_max_gamma, gamm);
          if (loghi > log_threshold) { fast_certified = false; break; }
          if (cerr > 0 && logl(cerr) + d > log_round_budget) {
            fast_certified = false; break;
          }
          if (chat == 0) Afast(i,j) = 0;
          else {
            long double logmag = logl(std::abs(chat)) + d;
            double mag = double(expl(logmag));
            Afast(i,j) = chat < 0 ? -mag : mag;
            if (!R_FINITE(Afast(i,j))) { fast_certified = false; break; }
          }
        }
      }
    }
  } catch (...) { fast_certified = false; }
  static thread_local bool reported_large = false;
  if (n >= 2000 && !reported_large) {
    Rprintf("V8CERT safe=%d ok=%d exchanges=%d mp_scans=%d eta=%.6Le max_width=%.6g max_gamma=%.6g candidate_max=%.17g sizeof_ld=%d sizeof_d=%d\n",
      int(fast_safe), int(fast_certified), initial_exchanges + fast_exchanges,
      initial_mp_scans + fast_mp_scans,
      fast_eta, fast_max_width, fast_max_gamma, fast_candidate_max,
      int(sizeof(long double)), int(sizeof(double)));
    reported_large = true;
  }
  if (fast_certified) {
    lweval = lwfast_mp;
    log_column_scale_mp = fast_column_scale_mp;
  } else {
    // V7 correctness fallback: normalize the stored doubles entirely in MP.
    Xeval.assign(n, std::vector<mp>(p));
    lweval.resize(n);
    for (int i = 0; i < n; ++i) {
      mp ri = 0; lweval[i] = mp(logw[i]);
      for (int j = 0; j < p; ++j) {
        Xeval[i][j] = mp(Xcore[i][j]);
        mp aij = abs(Xeval[i][j]); if (aij > ri) ri = aij;
      }
      if (ri > 0) {
        for (int j = 0; j < p; ++j) Xeval[i][j] /= ri;
        lweval[i] += mp(2) * log(ri);
      }
    }
    for (int j = 0; j < p; ++j) {
      mp dj = 0;
      for (int i = 0; i < n; ++i) {
        mp aij = abs(Xeval[i][j]); if (aij > dj) dj = aij;
      }
      if (!(dj > 0)) {
        v8_last_status = V8Status::DESIGN_RANK_DEFICIENT;
        return false;
      }
      for (int i = 0; i < n; ++i) Xeval[i][j] /= dj;
      log_column_scale_mp += log(dj);
    }
  }
  mp log_abs_det_mp;
  MMat XB_inv_mp;
  try {
    const mp threshold = log(mp(1) + mp(1e-12));
    for (int exchange = 0; ; ++exchange) {
      if (fast_certified) {
        log_abs_det_mp = mp(fast_log_abs_det);
        break;
      }
      int q = p;
      MMat aug(q, std::vector<mp>(2 * q));
      for (int i = 0; i < q; ++i) {
        for (int j = 0; j < q; ++j) aug[i][j] = Xeval[basis[i]][j];
        aug[i][q + i] = 1;
      }
      log_abs_det_mp = 0;
      for (int col = 0; col < q; ++col) {
        int piv = col;
        for (int i = col + 1; i < q; ++i)
          if (abs(aug[i][col]) > abs(aug[piv][col])) piv = i;
        if (aug[piv][col] == 0) throw std::runtime_error("MP singular normalized basis");
        std::swap(aug[piv], aug[col]);
        mp d = aug[col][col];
        log_abs_det_mp += log(abs(d));
        for (int j = 0; j < 2 * q; ++j) aug[col][j] /= d;
        for (int i = 0; i < q; ++i) if (i != col && aug[i][col] != 0) {
          mp f = aug[i][col];
          for (int j = 0; j < 2 * q; ++j) aug[i][j] -= f * aug[col][j];
        }
      }
      XB_inv_mp.assign(q, std::vector<mp>(q));
      for (int i = 0; i < q; ++i)
        for (int j = 0; j < q; ++j) XB_inv_mp[i][j] = aug[i][q + j];
      std::vector<char> in_basis(n, 0);
      for (int bi : basis) in_basis[bi] = 1;
      int best_i = -1, best_j = -1;
      mp best_gain = threshold;
      for (int i = 0; i < n; ++i) if (!in_basis[i]) {
        for (int j = 0; j < p; ++j) {
          mp c = 0;
          for (int k = 0; k < p; ++k) c += Xeval[i][k] * XB_inv_mp[k][j];
          if (c == 0) continue;
          mp gain = log(abs(c)) + mp(0.5) * (lweval[i] - lweval[basis[j]]);
          if (gain > best_gain ||
              (gain == best_gain && (best_i < 0 || i < best_i ||
               (i == best_i && j < best_j)))) {
            best_gain = gain; best_i = i; best_j = j;
          }
        }
      }
      if (best_i < 0) break;
      if (exchange >= 99) throw std::runtime_error("MP normalized exchange cap");
      basis[best_j] = best_i;
    }
  } catch (const std::exception &) {
    v8_last_status = V8Status::MAXVOL_UNCERTIFIED;
    return false;
  }
  double log_abs_det = log_abs_det_mp.convert_to<double>();
  if (!R_FINITE(log_abs_det)) {
    v8_last_status = V8Status::FACTORIZATION_FAILED;
    return false;
  }
  if (basis_out != NULL) *basis_out = basis;

  Eigen::MatrixXd A = fast_certified ? Afast : Eigen::MatrixXd::Zero(n, p);
  if (!fast_certified) for (int j = 0; j < p; ++j) A(basis[j], j) = 1.0;
  if (!fast_certified) for (int i = 0; i < n; ++i) {
    if (std::find(basis.begin(), basis.end(), i) != basis.end()) continue;
    for (int j = 0; j < p; ++j) {
      mp c = 0;
      for (int k = 0; k < p; ++k) c += mp(Xeval[i][k]) * XB_inv_mp[k][j];
      if (c == 0) { A(i,j) = 0.0; continue; }
      mp gain = log(abs(c)) + mp(0.5) * (lweval[i] - lweval[basis[j]]);
      if (gain > log(mp(1.0 + 1e-12))) {
        v8_last_status = V8Status::MAXVOL_UNCERTIFIED;
        return false;
      }
      if (gain < mp(log(std::numeric_limits<double>::denorm_min()))) A(i,j)=0.0;
      else {
        double mag = exp(gain).convert_to<double>();
        A(i,j) = c < 0 ? -mag : mag;
      }
      if (!R_FINITE(A(i, j))) {
        v8_last_status = V8Status::FACTORIZATION_FAILED;
        return false;
      }
    }
  }

  Eigen::MatrixXd G = A.transpose() * A;
  Eigen::LLT<Eigen::MatrixXd> llt(G);
  if (llt.info() != Eigen::Success) {
    v8_last_status = V8Status::FACTORIZATION_FAILED;
    return false;
  }
  Eigen::VectorXd diagL = llt.matrixL().toDenseMatrix().diagonal();
  if ((diagL.array() <= 0.0).any()) {
    v8_last_status = V8Status::FACTORIZATION_FAILED;
    return false;
  }
  mp basis_value_mp = log_column_scale_mp + log_abs_det_mp;
  for (int j = 0; j < p; ++j)
    basis_value_mp += mp(0.5) * lweval[basis[j]];
  value = basis_value_mp.convert_to<double>();
  for (int j = 0; j < p; ++j) value += log(diagL(j));
  if (!R_FINITE(value)) {
    v8_last_status = V8Status::FACTORIZATION_FAILED;
    return false;
  }

  Eigen::MatrixXd Ginv = llt.solve(Eigen::MatrixXd::Identity(p, p));
  Eigen::MatrixXd AGinv = A * Ginv;
  gradient.assign(n, 0.0);
  for (int i = 0; i < n; ++i)
    gradient[i] = 0.5 * AGinv.row(i).dot(A.row(i));

  if (third_u == NULL) {
    v8_cache.valid = true;
    v8_cache.key = cache_key;
    v8_cache.value = value;
    v8_cache.gradient = gradient;
    v8_cache.A = A;
    v8_cache.Ginv = Ginv;
    v8_cache.status = fast_certified ? V8Status::OK_DOUBLE_CERTIFIED
                                     : V8Status::OK_MP_CERTIFIED;
    v8_last_status = v8_cache.status;
  }

  if (direction != NULL && hvp != NULL) {
    Eigen::MatrixXd C = Eigen::MatrixXd::Zero(p, p);
    for (int i = 0; i < n; ++i)
      C.noalias() += (*direction)[i] * A.row(i).transpose() * A.row(i);
    Eigen::MatrixXd middle = Ginv * C * Ginv;
    hvp->assign(n, 0.0);
    for (int i = 0; i < n; ++i) {
      double h = 2.0 * gradient[i];
      double second = A.row(i).dot(middle * A.row(i).transpose());
      (*hvp)[i] = 0.5 * (h * (*direction)[i] - second);
    }

    if (third_u != NULL && third_out != NULL && hu_out != NULL) {
      Eigen::MatrixXd Cu = Eigen::MatrixXd::Zero(p, p);
      Eigen::MatrixXd Cuv = Eigen::MatrixXd::Zero(p, p);
      for (int i = 0; i < n; ++i) {
        Eigen::MatrixXd outer = A.row(i).transpose() * A.row(i);
        Cu.noalias() += (*third_u)[i] * outer;
        Cuv.noalias() += ((*third_u)[i] * (*direction)[i]) * outer;
      }
      Eigen::MatrixXd Mu = Ginv * Cu * Ginv;
      Eigen::MatrixXd Mv = Ginv * C * Ginv;
      Eigen::MatrixXd Muv = Ginv * Cuv * Ginv;
      Eigen::MatrixXd Ruv = Ginv * Cu * Ginv * C * Ginv;
      third_out->assign(n, 0.0);
      hu_out->assign(n, 0.0);
      for (int i = 0; i < n; ++i) {
        Eigen::RowVectorXd ai = A.row(i);
        double h = 2.0 * gradient[i];
        double su = ai.dot(Mu * ai.transpose());
        double sv = ai.dot(Mv * ai.transpose());
        double suv = ai.dot(Muv * ai.transpose());
        double ruv = ai.dot(Ruv * ai.transpose());
        (*hu_out)[i] = 0.5 * (h * (*third_u)[i] - su);
        (*third_out)[i] = 0.5 * (
          h * (*third_u)[i] * (*direction)[i] -
          su * (*direction)[i] - (*third_u)[i] * sv - suv + 2.0 * ruv);
      }
    }
  }
  return true;
}

TMB_ATOMIC_VECTOR_FUNCTION_DECLARE(lb_basis_grad)
TMB_ATOMIC_VECTOR_FUNCTION_DECLARE(lb_basis_hvp)
TMB_ATOMIC_VECTOR_FUNCTION_DECLARE(lb_basis_value)

#ifdef TMBAD_FRAMEWORK
# define GLLVMTMB_V8_ATOMIC_CALL(name, x) name<>(x)
#else
# define GLLVMTMB_V8_ATOMIC_CALL(name, x) name(x)
#endif

TMB_ATOMIC_VECTOR_FUNCTION_DEFINE(
  lb_basis_hvp,
  CppAD::Integer(tx[0]),
  {
    int n;
    int p;
    int lw0;
    int x0;
    basis_dims(tx, n, p, lw0, x0);
    int base_size = 2 + n + n * p;
    std::vector<double> direction(n);
    std::vector<double> gradient;
    std::vector<double> hv;
    for (int i = 0; i < n; ++i) direction[i] = asDouble(tx[base_size + i]);
    double value;
    bool ok = basis_stats(tx, value, gradient, &direction, &hv);
    for (int i = 0; i < n; ++i)
      ty[i] = ok ? hv[i] : R_NaN;
  },
  { Rf_error("DERIVATIVE_ORDER_UNSUPPORTED: v8 supports the fixed-only TMB path through order 2"); }
)

TMB_ATOMIC_VECTOR_FUNCTION_DEFINE(
  lb_basis_grad,
  CppAD::Integer(tx[0]),
  {
    int n;
    int p;
    int lw0;
    int x0;
    basis_dims(tx, n, p, lw0, x0);
    double value;
    std::vector<double> gradient;
    bool ok = basis_stats(tx, value, gradient, NULL, NULL);
    for (int i = 0; i < n; ++i)
      ty[i] = ok ? gradient[i] : R_NaN;
  },
  {
    int n;
    int p;
    int lw0;
    int x0;
    basis_dims(tx, n, p, lw0, x0);
    int base_size = 2 + n + n * p;
    CppAD::vector<Type> hx(base_size + n);
    for (int i = 0; i < base_size; ++i) hx[i] = tx[i];
    for (int i = 0; i < n; ++i) hx[base_size + i] = py[i];
    CppAD::vector<Type> hv = GLLVMTMB_V8_ATOMIC_CALL(lb_basis_hvp, hx);
    for (size_t i = 0; i < px.size(); ++i) px[i] = Type(0.0);
    for (int i = 0; i < n; ++i) px[lw0 + i] = hv[i];
  }
)

TMB_ATOMIC_VECTOR_FUNCTION_DEFINE(
  lb_basis_value,
  2,
  {
    double value;
    std::vector<double> gradient;
    bool ok = basis_stats(tx, value, gradient, NULL, NULL);
    ty[0] = ok ? value : R_NaN;
    ty[1] = static_cast<int>(v8_last_status);
  },
  {
    int n;
    int p;
    int lw0;
    int x0;
    basis_dims(tx, n, p, lw0, x0);
    CppAD::vector<Type> g = GLLVMTMB_V8_ATOMIC_CALL(lb_basis_grad, tx);
    for (size_t i = 0; i < px.size(); ++i) px[i] = Type(0.0);
    for (int i = 0; i < n; ++i) px[lw0 + i] = py[0] * g[i];
  }
)

template<class Type>
vector<Type> gll_mspl_atomic_half_logdet(const vector<Type> &logw,
                                         const matrix<Type> &X) {
  int n = X.rows();
  int p = X.cols();
  CppAD::vector<Type> ax(2 + n + n * p);
  ax[0] = Type(n);
  ax[1] = Type(p);
  for (int i = 0; i < n; ++i) ax[2 + i] = logw(i);
  int x0 = 2 + n;
  for (int j = 0; j < p; ++j)
    for (int i = 0; i < n; ++i)
      ax[x0 + i + n * j] = X(i, j);
  CppAD::vector<Type> atom = GLLVMTMB_V8_ATOMIC_CALL(lb_basis_value, ax);
  vector<Type> out(2);
  out(0) = atom[0];
  out(1) = atom[1];
  return out;
}

#undef GLLVMTMB_V8_ATOMIC_CALL

#endif
