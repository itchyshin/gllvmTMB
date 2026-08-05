# gllvm 2.0.13 Dispatch & Objective Investigation

## Q1: Dispatch (Which Internal Fires)

**METHOD:** R tracing instrumentation on a tiny fit.

**COMMAND:**
```r
trace(gllvm:::gllvm.VA, tracer = quote(cat("<<<HIT gllvm.VA>>>\n")), print = FALSE)
trace(gllvm:::gllvm.TMB, tracer = quote(cat("<<<HIT gllvm.TMB>>>\n")), print = FALSE)
fit <- gllvm(y = Y, family = binomial(link = "probit"), num.lv = 2, method = "VA")
```

**RESULT:**
```
<<<HIT gllvm.TMB>>>
<<<HIT gllvm.TMB>>>
```

**FINDING:** `gllvm.TMB` fires (twice). `gllvm.VA` does NOT fire.

**VERDICT:** For `method = "VA"`, gllvm 2.0.13 executes `gllvm.TMB`, not `gllvm.VA`. **The `gllvm.VA` function is not reached from the public API** (it may be legacy code or internal-only).

---

## Q2: Probit Objective in C++ (gllvm/src/gllvm.cpp)

**DOWNLOAD:** Tarball fetched from https://cran.r-project.org/src/contrib/gllvm_2.0.13.tar.gz (3.3 MB, extracted to scratchpad/gllvm/).

**OBJECTIVE FOR BINARY PROBIT (extra(j) == 1):**

**Lines 3342–3368** define the probit case in the VA method:

```cpp
} else if (extra(j) == 1) { // probit (line 3342)
  for (int i=0; i<n; i++) {
    if(!gllvmutils::isNA(y(i,j))){
      Type etaD =  dnorm(eta(i,j), Type(0), Type(1), 1);   // line 3347
      Type logit_p = gllvmutils::logit_pnorm(eta(i,j));   // line 3348
      
      Type log_p = -CppAD::CondExpLe(-logit_p, Type(18.0), gllvmutils::log1plus(exp(-logit_p)), -logit_p); 
      Type log_1mp = -CppAD::CondExpLe(logit_p, Type(18.0), gllvmutils::log1plus(exp(logit_p)), logit_p);
      
      nll -= y(i,j)*log_p + (Type(1.0)-y(i,j))*log_1mp;  // line 3353 - Main likelihood
      
      nll -= ((y(i,j)*(gllvmutils::mfexp(log_p + etaD)*(-eta(i,j))-gllvmutils::mfexp(2.*etaD))*gllvmutils::mfexp(2.*log_1mp) 
               + (1.-y(i,j))*(gllvmutils::mfexp(log_1mp+etaD)*eta(i,j)-gllvmutils::mfexp(2.*etaD))*gllvmutils::mfexp(2.*log_p) )
               /(gllvmutils::mfexp(2*log_p)*(gllvmutils::mfexp(2*log_p)-2*gllvmutils::mfexp(log_p)+1)))*cQ(i,j);  // line 3357 - Variance adjustment
    }
  }
}
```

**KEY FINDINGS:**

1. **Main likelihood** (line 3353): Standard probit log-likelihood
   - `nll -= y(i,j)*log_p + (1-y(i,j))*log_1mp`
   
2. **Variance adjustment** (line 3357): A mu-dependent term scaled by `cQ(i,j)`
   - The coefficient is a complex expression involving `etaD` (the standard normal density at eta)
   - This is NOT a constant-curvature term like `-v/2`; it is likelihood-dependent

3. **Where cQ comes from** (lines 3094 for Binomial/Gaussian/Ordinal group):
   ```cpp
   cQ(i,j) += (D(j)*Acov*D(j)*Acov).trace() 
               + 2*(u.row(i)*D(j)*Acov*D(j)*u.row(i).transpose()).value() 
               - 2*(u.row(i)*D(j)*Acov*newlam.col(j)).value();  // line 3094
   ```
   where `Acov = A(i) * A(i).transpose()` (line 3058), and A(i) is built from the variational covariance parameters Au (lines 401–412).

**VERDICT:** 
- **The probit objective does NOT use a simple constant-curvature term** (like `-v/2`)
- Instead, it uses the **full mu-dependent curvature of the probit likelihood** (dnorm-weighted)
- The variational covariance enters via a sophisticated quadratic form in `cQ(i,j)`, not as a linear penalty

---

## Q3: Parameter Declarations (Au as Free TMB Parameter)

**Line 86 in gllvm/src/gllvm.cpp:**
```cpp
PARAMETER_VECTOR(Au); // variational covariances for u
```

**FINDING:** `Au` is declared as a `PARAMETER_VECTOR`, which means it is a **free TMB parameter** optimized jointly by nlminb (line 86 confirms this).

**HOW Au IS USED** (lines 401–412):
```cpp
for(int d=0; d<(num_lv+num_lv_c); d++){
  A(i)(d+(nlvr-num_lv-num_lv_c),d+(nlvr-num_lv-num_lv_c))=exp(Au(d*n+i));  // line 402 - diagonal
  // A(d,d,i)=exp(Au(d*n+i));
}
if(Au.size()>((num_lv+num_lv_c)*n)){
  for(int k=0; k<Ab.cols(); k++){
    for(int r=0; r<Ab.rows(); r++){
      for(int c=r+1; c<Ab.cols(); c++){
        A(i)(r+(nlvr-num_lv-num_lv_c),c+(nlvr-num_lv-num_lv_c))=Au((num_lv+num_lv_c)*n+k*n+i);  // line 411 - off-diagonal
      }
    }
  }
}
```

The diagonal elements of A are `exp(Au(d*n+i))` (exponential transform for positivity), and off-diagonal elements (if present) are directly from `Au`.

**VERDICT:** Au is a **free PARAMETER_VECTOR** in TMB, optimized jointly with all other parameters via nlminb. There is **no fixed-point update loop**; the entire variational covariance is a parameter of the joint optimization.

---

## Summary

### Q1: LIVE PATH = **gllvm.TMB**
- Instrumentation confirms: gllvm.VA is NOT reached
- All method="VA" fits execute gllvm.TMB

### Q2: Probit Objective Variational Variance Term = **YES, but not `-v/2`**
- The variance adjustment IS present (line 3357)
- It is **mu-dependent** (weighted by dnorm), not constant-curvature
- Formula: `[complex likelihood-dependent expression] * cQ(i,j)`, where cQ includes the full variational covariance structure

### Q3: Parameter Declarations = **Au IS a free PARAMETER_VECTOR**
- Line 86: `PARAMETER_VECTOR(Au);`
- No fixed-point update; joint optimization by nlminb
