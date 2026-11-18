#include <TMB.hpp>

template<class Type>
Type objective_function<Type>::operator() () {
  DATA_VECTOR(y);
  DATA_IVECTOR(group);
  DATA_SCALAR(log_obs_sd);
  PARAMETER(beta);
  PARAMETER(log_sd_group);
  PARAMETER_VECTOR(u);

  Type nll = Type(0);
  Type sd_group = exp(log_sd_group);
  Type obs_sd = exp(Type(log_obs_sd));

  for (int j = 0; j < u.size(); ++j) {
    nll -= dnorm(u(j), Type(0), sd_group, true);
  }
  for (int i = 0; i < y.size(); ++i) {
    nll -= dnorm(y(i), beta + u(group(i)), obs_sd, true);
  }
  return nll;
}
