#include <TMB.hpp>

// Private Design-102 q=2 objective.  Method IDs: QD=0, QF=1, JD=2, JF=3.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y); DATA_INTEGER(method_id); DATA_VECTOR(gh_nodes); DATA_VECTOR(gh_weights);
  PARAMETER_VECTOR(beta); PARAMETER_VECTOR(loading_free); PARAMETER_MATRIX(mean); PARAMETER_MATRIX(chol_free);
  const int n = y.rows(), traits = y.cols();
  const bool full = method_id == 1 || method_id == 3, direct = method_id == 0 || method_id == 1;
  const int cols = full ? 3 : 2;
  if (method_id < 0 || method_id > 3 || traits < 2 || beta.size() != traits || loading_free.size() != 2 * traits - 1 || mean.rows() != n || mean.cols() != 2 || chol_free.rows() != n || chol_free.cols() != cols) error("Design102 dimension mismatch");
  matrix<Type> loading(traits, 2); loading.setZero();
  loading(0, 0) = exp(loading_free(0)); loading(1, 0) = loading_free(1); loading(1, 1) = exp(loading_free(2));
  int cursor = 3; for (int t = 2; t < traits; ++t) { loading(t, 0) = loading_free(cursor++); loading(t, 1) = loading_free(cursor++); }
  Type nll = 0;
  for (int i = 0; i < n; ++i) {
    Type a = chol_free(i, 0), b = full ? chol_free(i, 1) : Type(0), c = full ? chol_free(i, 2) : chol_free(i, 1);
    Type l11 = exp(a), l22 = exp(c), s11 = l11*l11, s12 = l11*b, s22 = b*b+l22*l22;
    for (int t = 0; t < traits; ++t) {
      Type mu = beta(t) + loading(t,0)*mean(i,0) + loading(t,1)*mean(i,1);
      Type variance = loading(t,0)*loading(t,0)*s11 + Type(2)*loading(t,0)*loading(t,1)*s12 + loading(t,1)*loading(t,1)*s22;
      Type obs;
      if (direct) {
        Type regular = 0, sd = sqrt(CppAD::CondExpLt(variance, Type(1e-8), Type(1e-8), variance));
        for (int h = 0; h < gh_nodes.size(); ++h) regular += gh_weights(h) * logspace_add(Type(0), mu + sd*gh_nodes(h));
        Type p = invlogit(mu), second = p*(Type(1)-p), fourth = second*(Type(1)-Type(6)*p+Type(6)*p*p);
        Type series = logspace_add(Type(0),mu) + Type(0.5)*variance*second + variance*variance*fourth/Type(8);
        obs = y(i,t)*mu - CppAD::CondExpLt(variance, Type(1e-8), series, regular);
      } else {
        Type r = mu*mu + variance, root = sqrt(CppAD::CondExpLt(r, Type(1e-8), Type(1e-8), r));
        Type regular = -log(Type(2))-log(cosh(root/Type(2))), series = -log(Type(2))-r/Type(8)+r*r/Type(192);
        obs = CppAD::CondExpLt(r, Type(1e-8), series, regular) + (y(i,t)-Type(0.5))*mu;
      }
      nll -= obs;
    }
    nll += Type(0.5)*(s11+s22+mean(i,0)*mean(i,0)+mean(i,1)*mean(i,1)-Type(2)*(a+c)-Type(2));
  }
  return nll;
}
