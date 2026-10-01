# Proposed NEWS.md replacement (not applied; NEWS.md is owned by the 0.7.1 release lane)

Replace this passage in the `d = "auto"` bullet (NEWS.md lines 42-49 on branch `claude/lane-auto-d-recovery`):

> Recovery evidence is family-specific: a simulation with known true rank found `"bic_sites"` recovers it most often for Gaussian (recovery rate 0.95), Poisson (0.999) and negative-binomial (0.93, re-measured on the corrected NB fitting code) data. For single-trial binary (Bernoulli) data recovery is still weak at small sizes even with the default loading ridge (`binary_ridge = 2`; e.g. 20 traits, 120 units: the true rank was found in 8/10 simulated datasets with the ridge).

with:

> Recovery evidence is family-specific. In a simulation with known true rank (13,789 datasets; 50 to 400 units, 8 or 16 traits, true rank 1 to 3), `"bic_sites"` found the true rank in at least 97% of datasets in every setting for Gaussian and Poisson data, and in at least 93% for negative-binomial data with 16 traits (as low as 39% with 8 traits and a true rank of 3). `d = "auto"` is not reliable for single-trial binary (Bernoulli) data: it usually selects too few factors, and neither the default loading ridge (`binary_ridge = 2`) nor `criterion = "aic"` fixes this. For binary data, set `d` from subject knowledge or compare explicit fits.

Line 13 (the `binary_ridge` bullet, "8/10 datasets against 4/10 without") is still accurate as a statement of that one experiment and can stay.
