# Temporal supplied-candidate comparison contract

`compare_temporal()` reports only optimized log likelihood, parameter count,
and AIC for named, already fitted candidates. It assigns no likelihood-ratio
test or p-value, because persistence and variance boundaries do not have a
generic chi-square reference distribution.

The first composed extension admits exactly a set of replicated Gaussian AR1
`temporal_indep() + kernel_indep()` candidates. Every candidate must carry one
fixed labelled diagonal kernel with the same label, labels, and matrix. This
keeps the source component identical while candidates differ only through
user-supplied temporal model choices. The helper neither searches a model
space nor refits candidates.

Tests require the reported AIC to equal `-2 * logLik + 2 * df`, confirm there
is no p-value column, and reject a phylogenetic source, a dependent temporal
mode, a differently labelled/matrix kernel, and mixed temporal-only/source-pair
candidate sets. This supplies no recovery, calibration, coverage, forecast,
profile, bootstrap, or general model-selection claim.
