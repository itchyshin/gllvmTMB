# Fisher: frozen retained Gaussian study

Read-only assessment by the existing Sol-high mathematical/evidence reviewer
`rho_math`, returned 2026-08-31. Root retained this report; reviewer made no
edits, fits, retries or seed changes. This is evidence review, not the final
three-person candidate panel. Sources: evidence/retained-summary-01/summary/
cells.csv, attempts.csv and paired-diagnostics.csv; raw2400 receipts under
evidence/totoro-study-01/raw/results; PLAN.md and PILOT.md.

All2400 attempts returned once with convergence zero and positive-definite
Hessians. The predeclared gradient rule leaves2248 numerical successes and152
failures; failing maximum gradients range .010003–.021442. No process errors,
timeouts or missing results occurred. All failure denominators remain50 per
cell. Success summaries are conditional on that numerical rule.

Verdicts concern only the frozen Gaussian source/mode regime. No retrospective
numeric pass cutoff was imposed. A bounded pass permits a qualified recovery
statement; partial requires the weakness to stay visible.

| Source / mode | Verdict | Reason |
| --- | --- | --- |
| Phylo indep | partial | Downward rho bias −.095/−.068 at truth .3/.7 |
| Phylo dep | partial | Downward bias −.076/−.054 and covariance error .392/.397 |
| Phylo loadings-only | partial | RMSE .199/.156; covariance error .562/.394 |
| Phylo latent plus Psi | partial | Downward bias −.073/−.047 despite Psi |
| Animal indep | partial | Lower-strength bias; RMSE .143/.130 |
| Animal dep | pass, bounded | Useful recovery with modest bias; RMSE .137/.121 |
| Animal loadings-only | partial | Small bias masks RMSE .222/.244 |
| Animal latent plus Psi | partial | Good conditional accuracy, but8/50 and4/50 failures |
| Kernel indep | pass, bounded | RMSE .108/.093;3/50 and5/50 failures |
| Kernel dep | pass, bounded | RMSE .100/.096;1/50 and4/50 failures |
| Kernel loadings-only | partial | Weaker at .7; RMSE .147/.206 |
| Kernel latent plus Psi | pass, bounded | RMSE .086/.080;3/50 failures at each strength |

All errors above are conditional on success. Full cells.csv includes bias,
RMSE and covariance-error Monte Carlo standard errors, boundary frequencies,
all-attempt failure frequencies and Wilson limits. For example phylo
loadings-only at .3 has bias −.128 ± .022 MCSE, RMSE .199 ± .013, and covariance
error .562 ± .046. Animal loadings-only at .7 has RMSE .244 ± .020. The reviewer
independently recomputed RMSE MCSEs and confirmed agreement.

Every estimated fit had lower negative log likelihood than its fixed-at-truth
pair. Among1054 pairs with both fits numerically successful, freeing rho
increased mean covariance error by .060–.436 for phylo, .004–.073 for animal,
and .013–.120 for kernel. This supports limited finite-sample information,
without proving global optimization. Fixed-at-truth is a diagnostic benchmark,
not an available real-data estimator.

All27 boundary fits passed numerical criteria. Physical-rho scores had the
correct constrained directions (22 lower,5 upper). Phylo loadings-only at .3
had8/48 successful fits at zero; animal loadings-only had8/48 and5/47 boundary
fits. A tiny logit score alone does not establish false convergence.

No regime requires removing implementation on this evidence. Separate recovery
of loadings versus Psi is not established by aggregate covariance errors.
Spatial recovery, interval calibration, other source geometries and other
families remain outside this campaign. No automatic campaign expansion.
