# Design 93 — private Bernoulli-logit EVA scalar algebra

## Scope

Design 93 maps the released `gllvm` Bernoulli-logit EVA *observation term* to a
small standalone scalar comparator.  It does not implement upstream `gllvm`,
gllvmTMB, joint parameter estimation, a public interface, or an inference
engine.  It follows Design 92's independently tested VA baseline but has a
separate source map and tests.

In released `gllvm` 2.0.13, `method > 1` denotes EVA.  For Bernoulli-logit,
the relevant branch evaluates the Bernoulli log likelihood at `eta` and adds
`p(eta){1-p(eta)} * cQ` to the negative log likelihood
(`src/gllvm.cpp`, lines 3309--3322).  In the narrow fixed-global scalar case,
`cQ = v/2`, where \(v\) is the variational linear-predictor variance.  Thus
the corresponding log-observation surrogate is

\[
\ell_{\rm EVA}(y;\mu,v)=
y\mu-\log(1+e^\mu)-\tfrac12p(\mu)\{1-p(\mu)\}v
=\ell(y;\mu)+\tfrac12\ell''(\mu)v.
\]

This is a second-order Taylor surrogate for \(E\{\ell(y;\eta)\}\), not the
exact Gaussian expectation and not a claim about the full upstream covariance
construction.  Its scalar code is a source-mapped comparator only.

## Gate

The comparator must match the written source formula, equal the ordinary log
likelihood at zero variance, and agree locally with high-order Gaussian
quadrature as variance tends to zero.  Passing these checks permits only a
future standalone objective/oracle design.  It does not permit gllvmTMB or
public EVA implementation.
