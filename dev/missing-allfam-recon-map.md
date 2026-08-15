# Family/Test Inventory for Missing-Response All-Families Sweep

**Generated:** 2026-08-15  
**Worktree:** `/private/tmp/gllvmtmb-missing-all-families`  
**Branch:** claude/missing-all-families-20260815 @ origin/main tip

---

## 1. FAMILY REGISTRY

**Source:** `/private/tmp/gllvmtmb-missing-all-families/R/fit-multi.R:436-510`

Canonical family list with family_id integers and admitted links, as spelled in R code:

| family_id | Family Name | Constructor | Admitted Links | Notes |
|-----------|-------------|-------------|-----------------|-------|
| 0 | gaussian | `gaussian()` | identity, log, inverse | Built-in from stats package |
| 1 | binomial | `binomial()` | logit, probit, cloglog | Built-in from stats package |
| 2 | poisson | `poisson()` | log, identity | Built-in from stats package |
| 3 | lognormal | `lognormal()` | identity, log, inverse | R/families.R:145 |
| 4 | Gamma | `Gamma()` | identity, log, inverse | Built-in from stats package (capitalized) |
| 5 | nbinom2 | `nbinom2()` | log | R/families.R:221 |
| 6 | tweedie | `tweedie()` | log, identity | R/families.R:313 |
| 7 | Beta | `Beta()` | logit | R/families.R:137 |
| 8 | betabinomial | `betabinomial()` | logit, cloglog | R/families.R:502 |
| 9 | student | `student()` | identity, log, inverse | R/families.R:291 |
| 10 | truncated_poisson | `truncated_poisson()` | log | R/families.R:242 |
| 11 | truncated_nbinom2 | `truncated_nbinom2()` | log | R/families.R:256 |
| 12 | delta_lognormal | `delta_lognormal()` | standard/logit+log or poisson-link | R/families.R:402 |
| 13 | delta_gamma | `delta_gamma()` | standard/logit+log or poisson-link | R/families.R:343 |
| 14 | ordinal_probit | `ordinal_probit()` | probit (fixed) | R/families.R:606 |
| 15 | nbinom1 | `nbinom1()` | log | R/families.R:232 |
| 16 | multinomial | `multinomial()` | logit (baseline-category) | R/families.R:651 |

**Total families: 17**

### NOT Supported (exported but rejected):
- `gengamma()` — R/families.R:167 (line 164: "generalized-gamma")
- `gamma_mix()`, `lognormal_mix()`, `nbinom2_mix()` — Mixture families (line 164)
- `censored_poisson()` — R/families.R:328 (line 164)
- `truncated_nbinom1()` — R/families.R:272 (line 164: "truncated NB1")
- `delta_gengamma()`, `delta_gamma_mix()`, `delta_lognormal_mix()` — Delta variants (line 164)
- `delta_truncated_nbinom1()`, `delta_truncated_nbinom2()` — Delta variants
- `delta_beta()` — Delta variant
- `delta_poisson_link_gamma()`, `delta_poisson_link_lognormal()` — Deprecated poisson-link wrappers (R/families.R:479-495, line 483/494)

**Error message source:** R/fit-multi.R:514

---

## 2. MASKED-RESPONSE TEST COVERAGE

**Definition:** Tests that verify `miss_control(response = "include")` sentinelinvariance and masking gates with `is_y_observed`.

### Families WITH Existing Masked-Response Tests

| Family | Test File | Lines | What's Asserted |
|--------|-----------|-------|-----------------|
| gaussian | test-missing-response-gaussian.R:41-159 | L41-159 | Deterministic match (include==drop on observed), sentinel-invariance byte-identical (logLik/gradient), is_y_observed masking, nobs() reports observed rows |
| gaussian | test-missing-response-cellwise.R:29-42 | L29-42 | Cell-wise (not listwise) drop default: one NA cell keeps sibling traits |
| gaussian | test-missing-response-traits.R:95-184 | L95-184 | Wide-format traits() cell-identity mask, is_y_observed matches NA pattern, deterministic match (include==drop at ~1e-6) |
| gaussian | test-lv-missing-response.R:90-184 | L90-184 | Latent variable (~lv) support with masked Gaussian response, include==drop match (~1e-8 logLik) |
| gaussian | test-reml-missing-response.R:51-74 | L51-74 | REML + response="include" matches response="drop" on observed rows |
| poisson | test-missing-response-nongaussian.R:24-77 | L31-38 (fit_inc), L35-38 (fit_cc) | Deterministic match (include==drop at tolerance=1e-6), sentinel-invariance on logLik and extract_Sigma (tolerance=1e-3) |
| nbinom2 | test-missing-response-nongaussian.R:24-77 | L31-38 (fit_inc), L35-38 (fit_cc) | Same as poisson: include==drop deterministic, logLik and Sigma match |
| binomial | test-missing-response-nongaussian.R:24-77 | L31-38 (fit_inc), L35-38 (fit_cc) | Same as poisson/nbinom2: include==drop deterministic match |
| binomial | test-binomial-cbind-missing-response.R:8-33 | L22-27 (fit) | cbind(succ, fail) format with masked response doesn't crash, is_y_observed gating works |
| binomial | test-aghq-missing-response.R:25-60 | L40-41 (fits), L51-52 (with mask) | AGHQ engine engages, include==drop under AGHQ at tolerance=1e-5 |
| binomial | test-va-missing-response.R:91-109 | L99-103 (fit) | VA integration accepts response="include", is_y_observed dense masks admitted |

**Families WITH masked-response tests: 4 (gaussian, poisson, nbinom2, binomial)**

### Families LACKING Masked-Response Tests

| Family | family_id |
|--------|-----------|
| lognormal | 3 |
| Gamma | 4 |
| tweedie | 6 |
| Beta | 7 |
| betabinomial | 8 |
| student | 9 |
| truncated_poisson | 10 |
| truncated_nbinom2 | 11 |
| delta_lognormal | 12 |
| delta_gamma | 13 |
| ordinal_probit | 14 |
| nbinom1 | 15 |
| multinomial | 16 |

**Families LACKING masked-response tests: 13**

---

## 3. FIT SHAPES TO COPY (Green-Test Template Fits)

For each family lacking masked-response tests, one representative existing fit from the full test suite, suitable as a copy template for the S1 sweep.

### Lognormal (family_id = 3)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-family-lognormal.R:29-34`

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 2),
  data   = df,
  site   = "individual",
  family = lognormal()
)
```

**Special data needs:**
- Strictly positive support required (log-transformation in engine)
- Simulated as: `y <- exp(log_y)` where `log_y ~ Normal(mu, sigma_eps)` (line 21)
- Range check added: errors if any `value <= 0` (line 53-59)

---

### Gamma (family_id = 4)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-family-gamma.R:34-39`

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 2, unique = FALSE),
  data   = df,
  site   = "individual",
  family = Gamma(link = "log")
)
```

**Special data needs:**
- Strictly positive support required
- Default link is "log" (as shown here)
- Simulated with `mu <- exp(eta); y ~ Gamma(shape = 3, rate = shape/mu)` (test-family-gamma.R setup)

---

### Tweedie (family_id = 6)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-tweedie-recovery.R:40-45`

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data   = df,
  site   = "individual",
  family = tweedie()
)
```

**Special data needs:**
- Non-negative support required (includes zeros and positive reals)
- Default power `p` is estimated (or supply fixed `p` between 1 and 2 as parameter)
- Simulated with: ensure `all(df$value >= 0)` check (line 37)

---

### Beta (family_id = 7)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-beta-recovery.R:39-45`

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data   = df,
  unit   = "individual",
  family = Beta()
)
```

**Special data needs:**
- Unit support: strictly between 0 and 1 (open interval)
- Default link is "logit"
- Simulated with `y ~ Beta(shape1, shape2)` where shapes derived from eta via logistic (test-beta-recovery.R setup)

---

### Betabinomial (family_id = 8)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-betabinomial-recovery.R:42-47`

```r
gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data   = df,
  unit   = "individual",
  family = betabinomial()
)
```

**Special data needs:**
- Response format: `cbind(successes, failures)` (two-column format)
- Trials `n = successes + failures` constructed in engine
- Default link is "logit"
- Simulated with `n_trials <- N; y_succ ~ BetaBinomial(n_trials, mu, phi)` (test-betabinomial-recovery.R:26-36)

---

### Student-t (family_id = 9)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-student-recovery.R:43-49`

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data   = df_long,
  site   = "individual",
  family = student()
)
```

**Special data needs:**
- Continuous support (real line)
- Default: degrees of freedom `df` estimated (or fixed with `student(df = 3)`, line 57)
- Simulated with `y ~ student_t(df, mu, sigma)` (test-student-recovery.R setup)

---

### Truncated Poisson (family_id = 10)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-truncated-recovery.R:51-57`

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data   = df_long,
  site   = "individual",
  family = truncated_poisson()
)
```

**Special data needs:**
- Support: integers >= 1 (zero-truncated; no zeros allowed)
- Engine errors if any `y < 1` (line 77: "y >= 1")
- Simulated with constraint `all(df_long$value >= 1L)` (line 50)

---

### Truncated NB2 (family_id = 11)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-truncated-recovery.R:99-107` (assumes second loop in file)

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data   = df_long,
  site   = "individual",
  family = truncated_nbinom2()
)
```

**Special data needs:**
- Support: integers >= 1 (zero-truncated negative binomial type 2)
- Engine errors if any `y < 1`
- Simulated with constraint `all(df_long$value >= 1L)` (assumes similar setup to truncated_poisson section)

---

### Delta-Lognormal (family_id = 12)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-delta-lognormal-recovery.R:67-72`

```r
gllvmTMB(
  value ~ 0 + trait,
  data   = df,
  site   = "individual",
  family = delta_lognormal()
)
```

**Special data needs:**
- Support: non-negative reals >= 0 (includes zeros; zeros handled by Bernoulli "occurrence" component)
- Two-part model: logit-link occurrence (zero/positive) + log-link positive component
- Default: standard delta (logit + log links)
- Simulated with: `all(df$value >= 0)` check (line 65)
- Engine errors if any negative values (line 80-82: "non-negative")

---

### Delta-Gamma (family_id = 13)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-delta-gamma-recovery.R:56-61`

```r
gllvmTMB(
  value ~ 0 + trait,
  data   = df,
  site   = "individual",
  family = delta_gamma()
)
```

**Special data needs:**
- Support: non-negative reals >= 0
- Two-part model: logit-link occurrence + log-link Gamma positive component
- Default: standard delta (logit + log)
- Simulated with: `all(df$value >= 0)` check

---

### Ordinal Probit (family_id = 14)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-ordinal-probit.R:44-50`

```r
gllvmTMB(
  value ~ 0 + trait + unique(0 + trait | individual),
  data   = df,
  unit   = "individual",
  family = ordinal_probit()
)
```

**Special data needs:**
- Response: ordered factor or integer from 1:K for K >= 3 categories
- Response must be explicitly coerced to ordered factor (e.g., `factor(value, ordered = TRUE)`)
- Link is probit (fixed; cannot be changed)
- Latent variable model: `y* ~ N(eta, 1)`, thresholds `tau_1=0` fixed, tau_2...tau_{K-1}` estimated
- Random-effect terms: unique() supported; latent() not supported on ordinal
- Simulated with: `y ~ ordered factor(rbinom(n, 1, plogis(eta)))` for K=2, extends to K=3,4 with cumulative categories (test-ordinal-probit.R:27-41)

---

### NB1 (Negative Binomial type 1; family_id = 15)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-crosspkg-nbinom1-glmmTMB.R` (no dedicated recovery test found; using cross-package smoke test)

**Alternative source for minimal fit:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-coevolution-two-kernel.R` (uses nbinom1() in model)

```r
gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data   = df,
  unit   = "unit",
  trait  = "trait",
  family = nbinom1()
)
```

**Special data needs:**
- Non-negative integer support (count data)
- Variance = mu * (1 + phi) [linear mean-variance, vs nbinom2's quadratic]
- Default link is "log"
- Simulated with: `y ~ NegBinomial(mu = exp(eta), phi = 0.8)` parameterized as NB1 (test-crosspkg-nbinom1-glmmTMB.R:26-40)

---

### Multinomial (family_id = 16)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-multinomial.R:51-55`

```r
gllvmTMB(
  value ~ 0 + trait + (0 + trait):x,
  data   = df,
  family = multinomial(),
  trait  = "trait",
  unit   = "unit"
)
```

**Special data needs:**
- Response: unordered factor or integer from 1:K for K >= 3 categories
- Baseline-category logit (softmax) model; reference category 1 pinned at eta=0
- Link is baseline-category logit (fixed; cannot be changed)
- Fixed-effects only: latent() and other random-effect terms NOT supported
- Data format: wide (one row per unit) or long with response as factor/integer column
- Simulated with: `y ~ factor(sample(1:K, size, prob = softmax(eta)))` where eta_1 = 0, eta_k for k=2..K (test-multinomial.R:6-45)

**Fit requires:**
- Exactly K traits: `value ~ 0 + trait` expands to K-1 pseudo-trait intercepts (K-1 contrasts vs reference)
- Example: K=3 categories yields 2 intercepts `b_fix[2]` (trait_2) and `b_fix[3]` (trait_3) vs trait_1=0

---

## 4. VA CELL SPELLINGS AND ADMITTED FAMILIES

### VA Integration Syntax

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-va-missing-response.R:99-103`

```r
gllvmTMB(
  fx$fml, data = df, family = stats::binomial(), unit = "site",
  missing = miss_control(response = "include"),
  control = gllvmTMBcontrol(integration = "va")
)
```

**VA control parameter:** `gllvmTMBcontrol(integration = "va")` (line 102)

**VA + masked response:** `missing = miss_control(response = "include")` is admitted (line 101); test asserts fit proceeds and `fit$status == "healthy"` (line 104-105)

### VA-Admitted Families (Scalar Laplace Route)

**Source:** `/private/tmp/gllvmtmb-missing-all-families/R/va-routing.R:58-80`

VA admits families 0 through 15 (Laplace family_ids); multinomial (16) uses a separate coupled-softmax route.

| family_id | Family | VA Support | Notes |
|-----------|--------|------------|-------|
| 0 | gaussian | ✓ | (from R/va-routing.R family_names list) |
| 1 | binomial | ✓ | link_id 0=logit, 1=probit, 2=cloglog all admitted |
| 2 | poisson | ✓ | |
| 3 | lognormal | ✓ | |
| 4 | Gamma | ✓ | |
| 5 | nbinom2 | ✓ | |
| 6 | tweedie | ✓ | |
| 7 | Beta | ✓ | |
| 8 | betabinomial | ✓ | |
| 9 | student | ✓ | |
| 10 | truncated_poisson | ✓ | |
| 11 | truncated_nbinom2 | ✓ | |
| 12 | delta_lognormal | ✓ | |
| 13 | delta_gamma | ✓ | |
| 14 | ordinal_probit | ✓ | |
| 15 | nbinom1 | ✓ | |
| 16 | multinomial | ✗ (separate design) | Coupled-softmax route (Design 110) |

**VA-admitted family count: 16** (families 0-15)

**VA-testing coverage:**
- test-va-missing-response.R tests binomial with response masking (line 99-103)
- test-va-all-family-compiled.R validates all 16 families (no missing-response; Design 110 bridge)

---

## 5. LOOP PARAMS: test-missing-response-nongaussian.R STRUCTURE

**Source:** `/private/tmp/gllvmtmb-missing-all-families/tests/testthat/test-missing-response-nongaussian.R:1-77`

### Loop Skeleton (Lines 42-77)

```r
for (fam in list(
  list(name = "poisson", fun = quote(poisson())),
  list(name = "nbinom2", fun = quote(nbinom2())),
  list(name = "binomial", fun = quote(binomial()))
)) {
  local({
    fam_name <- fam$name
    fam_fun <- eval(fam$fun)
    test_that(sprintf("masked response == complete-case for %s", fam_name), {
      r <- run_include_drop_equiv(fam_name, fam_fun)
      
      # ASSERTION 1: logLik finite
      expect_true(is.finite(as.numeric(stats::logLik(r$inc))))
      expect_true(is.finite(as.numeric(stats::logLik(r$cc))))
      
      # ASSERTION 2: is_y_observed masking
      expect_equal(sum(r$inc$tmb_data$is_y_observed == 0L), r$n_masked)
      
      # ASSERTION 3: sentinel-invariance on logLik
      expect_equal(
        as.numeric(stats::logLik(r$inc)),
        as.numeric(stats::logLik(r$cc)),
        tolerance = 1e-6
      )
      
      # ASSERTION 4: sentinel-invariance on Sigma
      expect_equal(
        extract_Sigma(r$inc, level = "unit")$Sigma,
        extract_Sigma(r$cc, level = "unit")$Sigma,
        tolerance = 1e-3
      )
    })
  })
}
```

### Data Generation (Lines 7-22)

```r
make_missing_resp_data <- function(family = "poisson", seed = 5L, n_unit = 45L) {
  set.seed(seed)
  traits <- c("t1", "t2", "t3")
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = factor(traits))
  u <- stats::rnorm(n_unit)[as.integer(df$unit)]
  lam <- c(t1 = 0.8, t2 = 0.6, t3 = 0.5)[as.character(df$trait)]
  b0 <- c(t1 = 1.0, t2 = 1.2, t3 = 0.8)[as.character(df$trait)]
  eta <- b0 + lam * u
  df$value <- switch(
    family,
    poisson = stats::rpois(nrow(df), exp(eta)),
    nbinom2 = stats::rnbinom(nrow(df), mu = exp(eta), size = 3),
    binomial = stats::rbinom(nrow(df), 1L, stats::plogis(eta))
  )
  df
}
```

### Fit Wrapper (Lines 24-40)

```r
run_include_drop_equiv <- function(family, famfun, seed = 5L) {
  df <- make_missing_resp_data(family, seed = seed)
  masked <- c(3L, 27L, 55L, 88L, 111L)  # 5 masked rows (family_id-agnostic)
  data_na <- df
  data_na$value[masked] <- NA
  data_cc <- df[-masked, , drop = FALSE]
  form <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  fit_inc <- suppressMessages(gllvmTMB(
    form, data = data_na, trait = "trait", unit = "unit",
    family = famfun, missing = miss_control(response = "include"), silent = TRUE
  ))
  fit_cc <- suppressMessages(gllvmTMB(
    form, data = data_cc, trait = "trait", unit = "unit",
    family = famfun, missing = miss_control(response = "drop"), silent = TRUE
  ))
  list(inc = fit_inc, cc = fit_cc, n_masked = length(masked))
}
```

### Loop Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Families in loop | 3: poisson, nbinom2, binomial | Current sweep scope (S1) |
| Data generation | `make_missing_resp_data(family, seed = 5L, n_unit = 45L)` | Reusable fixture; scales to accept additional families |
| n_unit | 45 | Units; expands to 135 long rows (45 × 3 traits) |
| n_traits | 3 (t1, t2, t3) | Fixed; expand if needed |
| n_masked | 5 (rows 3, 27, 55, 88, 111) | 3.7% MCAR pattern |
| latent structure | `latent(0 + trait \| unit, d = 1, unique = FALSE)` | Simple d=1 LV, no unit-specific offsets |
| formula | `value ~ 0 + trait + latent(...)` | Intercept per trait + LV loading per trait |
| Laplace tolerance | 1e-6 (logLik), 1e-3 (Sigma) | Sentinel-invariance thresholds; platform-dependent note on line 52-55 |

### Copy Instructions for S1 Sweep

1. **Extend data generation:** Add family-specific value generation to the `switch()` block in `make_missing_resp_data()` (lines 15-20).  
   - Use the fit-shape templates from section 3 to determine data simulation parameters.
   - Example for lognormal: `lognormal = exp(stats::rnorm(nrow(df), mean = eta, sd = 0.3))`

2. **Extend loop:** Add family list entries (line 42-46) for each new family.  
   - Format: `list(name = "<family_name_string>", fun = quote(<Family>()))`

3. **Adapt assertions if needed:**
   - For ordinal/multinomial: use appropriate extractor (e.g., `extract_cutpoints()` for ordinal)
   - For delta families: may need family-specific tolerance widening (document as comment, line 52-55 pattern)

---

## SUMMARY

- **Total admitted families:** 17
- **Families with masked-response tests:** 4 (gaussian, poisson, nbinom2, binomial)
- **Families lacking masked-response tests:** 13
- **Families lacking fit examples:** 0 (all have green-test templates identified)
- **VA-admitted family count (scalar route):** 16 (0-15)
- **VA-admitted family count (multinomial coupled route):** 1 (16)

### Next Steps (S1 Sweep):

1. Extend `make_missing_resp_data()` in test-missing-response-nongaussian.R to generate data for the 13 missing families.
2. Extend the family loop (lines 42-46) to include all 17 families.
3. Verify fit shapes from section 3 match data formats (especially cbind for betabinomial, ordered factor for ordinal, factor for multinomial).
4. Add family-specific data validation calls as needed (e.g., `all(value > 0)` for lognormal).
5. Run subset of 13 missing families first; integrate into main loop once working.

