```text
GOAL: private Design-102 q=2 QD/QF/JD/JF recovery envelope.  Run 32 seeds over
N={24,80,240} and regimes={near_diag,correlated}; retain all three starts and
select only by native objective among healthy starts.  Evaluate selected fits
on GH61, retain every failure, and close privately.  EVA, package paths, public
claims, prior result roots, and campaign extension are excluded.
```

# Frozen contract

The model is \(Y_{it}\sim Bernoulli(logit^{-1}(\beta_t+\lambda_t^Tu_i))\),
\(u_i\sim N_2(0,I)\), with six traits and the positive lower-triangular
two-column loading chart.  Recovery targets are `beta`,
\(\Sigma_\Lambda=\Lambda\Lambda^T\), and integrated trait probabilities.
No diagonal Psi is present in this lowest non-Gaussian private tier.

The 32 seed schedule is `102001:102032`.  Every seed crosses the two named
loading regimes and N values, giving 192 independent cells and 2,304 immutable
start attempts.  A selected endpoint is healthy iff its optimizer code is zero,
all coordinates/objective are finite, and max absolute AD gradient is below
`1e-3`.  Within a method/cell select the largest native bound/objective only
among healthy starts; do not compare objectives between methods.  Report no
recovery verdict for a method/regime/N cell with fewer than 29 selected healthy
endpoints.  GH61 is common post-fit evaluation; GH101 is a sentinel only.

The smoke consists of one seed in each of the six N/regime combinations and all
twelve method/start attempts.  It must publish all records with no malformed or
missing endpoint and establish p95 runtime/memory before the DRAC array.  The
array uses one serial cell per task, one thread, and immutable RDS records.  A
private local adjudicator is the only component permitted to create summaries.
