#include <TMB.hpp>
#include "gllvmTMB_cloglog.h"

template <class Type>
Type objective_function<Type>::operator() ()
{
  DATA_VECTOR(y);
  DATA_VECTOR(n_trials);
  PARAMETER_VECTOR(eta);
  Type nll = Type(0.0);
  for (int i = 0; i < y.size(); ++i) {
    nll -= gll_dbinom_cloglog(y(i), n_trials(i), eta(i));
  }
  return nll;
}
