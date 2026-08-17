# Kosmidis & Firth (2021): the coverage caveat DOES extend to profiled penalised likelihood

**Date:** 2026-08-17 · **Lane:** `claude/mspl-interval-computable-pin` · **Status:** VERIFIED
against the primary source (quote read directly, not from a search snippet or secondary summary)

**Source read:** arXiv:1812.01938 v4 (March 2020 preprint) of Kosmidis & Firth,
*"Jeffreys-prior penalty, finiteness and shrinkage in binomial-response generalized linear
models"*, **Biometrika** 108(1):71–82, doi `10.1093/biomet/asaa052`. Quote located in
**Section 2.2 "Finiteness", final paragraph, p. 5** of the preprint. **Version caveat:** section
and page numbering may differ in the Warwick accepted manuscript and the version of record; cite
one of those for a published page reference.

---

## 1. Why this note exists

`docs/dev-log/research/2026-08-16-mspl-se-paper-ranga-synthesis.md` and the maintainer's SE/CI
pass-on note both recorded the caveat as **unresolved for profiles**: *"the warning may hold even
for profiles. Verify against the PDF before anyone designs an MSPL interval."* It is now resolved.
The answer is **yes**, and it is stated by the authors themselves.

## 2. The verbatim passage

> "Since \(y_1,\dots,y_n\) are realizations of binomial random variables, there is only a finite
> number of values that the estimator \(\tilde\beta\) can take for any given \(x_1,\dots,x_n\).
> Hence, there will always be a parameter vector with large enough components that the usual
> Wald-type confidence intervals \(\tilde\beta_t \pm z_{1-\alpha/2}s_t(\tilde\beta)\), or
> confidence regions in general, will fail to cover regardless of the nominal level \(\alpha\)
> that is used. This has also been observed in the complete enumerations of Kosmidis (2014) for
> proportional odds models which are extensions of logistic regression to ordinal responses; and
> **it is also true when the penalized likelihood is profiled for the construction of confidence
> intervals**, as is proposed, for example, in Heinze & Schemper (2002), and in Bull et al. (2007)
> for multinomial regression models."
>
> — §2.2, p. 5 (emphasis added)

## 3. The mechanism, and why it matters more than the sentence

The failure is **not** a quadratic-approximation artefact. That is the key point, because a
quadratic-approximation artefact is exactly the thing profiling repairs.

The authors' argument is about the **attainable estimator set**: the responses are binomial, so
for fixed design \(X\) the penalised estimator \(\tilde\beta\) can take only **finitely many
values**, each with finite components (their Corollary 1). The true parameter, by contrast, is
unbounded. So for a \(\beta\) with large enough components, **no** interval built from the
attainable \(\tilde\beta\) reaches it — at any nominal level.

Profiling the same penalised likelihood does not escape this: it changes the interval's *shape*,
not the boundedness of the estimator it is built from. This is why "use profile instead of Wald"
is not a remedy here, even though profile is otherwise the better instrument
([[DECISIONS#D-12|D-12]]).

## 4. Standing of the claim — assertion, not theorem

Stated precisely, so nobody over-cites it: the sentence is an **authors' assertion supported by
citation** to observed failures (Kosmidis 2014 complete enumerations; Heinze & Schemper 2002;
Bull et al. 2007). The paper's own formal results — **Theorem 1** and **Corollary 1**
(finiteness), **Theorem 2** (shrinkage toward equiprobability) — do **not** prove an interval
coverage result. It is nonetheless a direct, unambiguous statement by the authors of the penalty
we use, about the exact construction we were considering.

## 5. Scope — and what may NOT be cited to this paper

- **Links covered:** logit (§2), extended in §3 to **probit, c-log-log, log-log, cauchit**
  (Table 1, p. 6). All three of our binary MSPL links are inside this scope.
- **Setting:** **binomial-response GLMs with full-rank \(X\)**. Fixed design, no latent variables.
- **Therefore NOT citable to this paper:** Gamma, lognormal, Student, Tweedie, ordinal_probit,
  delta/hurdle families, or any non-binomial family. The SE-series lane must not extend this
  sentence to those families on this source's authority.
- **AGENT-INFERRED, not established:** gllvmTMB's MSPL is a *GLLVM* — latent variables and a
  Laplace-approximated marginal likelihood, not the paper's fixed-design GLM. The finite-attainable-set
  mechanism *plausibly* transfers (our responses are still binomial and the penalised point is
  still finite), but the paper does not cover latent-variable models and we have not proved the
  transfer. Treat the transfer as a lead, not a load-bearing claim.

## 6. Consequences for this repository

1. **It retroactively explains Design 118's failure.** A fitted calibration map cannot repair a
   coverage failure whose mechanism is that the attainable estimator set is finite and bounded
   while the parameter is not. D-155/D-157's FAIL and PARK are consistent with the primary source,
   not merely with bad luck in one campaign.
2. **"Penalised-profile CI at nominal level" is not an admissible target for binary MSPL** in the
   separation regime. Any earlier plan or draft resting on that premise — including this lane's own
   halted theorem-gated draft — is void on this point and should not be revived as written.
3. **The honest constructions that survive** are the ones the pass-on note already listed:
   parametric bootstrap with the **same penalty inside every resample**, and **refusal on
   penalty-determined coordinates** (Rainey 2016). Refusal is now the better-supported default.
4. **It does not affect the SE work.** The caveat is about *interval coverage*. \(Q_0\) remains
   the paper-aligned SE reporting target (D-149, #1061), and the curvature pin is untouched.
5. **It does not forbid an internal, uncalibrated interval *computer*.** Computability and
   coverage are different claims (the distinction D-149 encodes as *"pins ≠ public intervals"*).
   What this note forbids is calling such endpoints a confidence interval — which is precisely why
   the instrument must carry an explicit not-calibrated marker.

## 7. Directed to the Cursor SE/CI lane

You are implementing SE/CI across the non-binomial families. Three asks:

- **Do not build a profile-CI *claim* path for MSPL on the assumption that profiling repairs Wald
  undercoverage.** The authors of the penalty say it does not, for binomial-response GLMs.
- **Do not cite this paper for non-binomial families.** Its scope is binomial-response with
  full-rank \(X\). For Gamma/lognormal/Student/Tweedie/ordinal/delta the question is *open*, not
  settled either way, and the honest label is UNVERIFIED.
- **`#1075`'s "profile = signature / primary claim path" needs a footnote** for the MSPL case
  specifically. D-12's profile-over-Wald doctrine stands in general and for ML; what does not
  stand is the inference that profiling rescues coverage under a finiteness penalty.

## 8. Verification trail

- Read the preprint PDF directly (pp. 4–6) and confirmed the sentence verbatim; the first pass at
  this question came from a sub-agent and was independently re-read before this note was written,
  because the finding redirects other lanes.
- A web-search snippet was **not** treated as sufficient evidence: the abstract concerns finiteness
  and shrinkage only and would have supported a wrong "silent on profiles" verdict.

## 9. Relations

- amends the open question in `docs/dev-log/research/2026-08-16-mspl-se-paper-ranga-synthesis.md`
- supports [[DECISIONS#D-157|D-157]] (park) and [[DECISIONS#D-155|D-155]] (Phase B FAIL)
- bounds `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` (the CI triad)
- does not alter [[DECISIONS#D-149|D-149]] (\(Q_0\) SE target) or `R/mspl-curvature-pin.R`
