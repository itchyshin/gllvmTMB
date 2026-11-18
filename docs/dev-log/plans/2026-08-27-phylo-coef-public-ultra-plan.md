# Ultra Plan — public `column_coef()` and `phylo_coef()`

```text
🎯 GOAL
Solo platform: Codex
Deliverable: Exported, documented, and fitted Gaussian point-model `column_coef()` and `phylo_coef()` interfaces for long and wide data, including fixed and estimated phylogenetic correlation strength, exact released-slope equivalence, extractor metadata, runnable articles, independent review, and protected three-OS landing evidence.
HEADLINE: Finish the response-column coefficient programme at the smallest honest public boundary.
IN PARALLEL: Independent Gauss/Noether, Grace, Rose, and applied-user reviews begin only after their reviewed byte sets are frozen; CI jobs run only through the repository's paced routine and manual full-matrix workflows.
DEFER: `animal_coef()`, `kernel_coef()`, `spatial_coef()`, interval inference, non-Gaussian admission, latent coefficient covariance, and any deprecation or warning for current `*_slope()` APIs.
DISCIPLINE: verify=Unlazy gates plus fresh source checks · compute=local timed point-recovery fixtures unless a >30-minute campaign is proven necessary · closure=normal protected merge, exact-main check, after-task, plan-vs-actual, and handover.
```

## 1. Exact starting state

- Branch: `codex/phylo-coef-public`.
- Base: exact verified main `e431f7890a425d76f29cff072682ec0514226801`.
- Fixed-rho landing: PR #1219, reviewed head
  `4e38af6dc68af24865e32dafe75b639d6954d483`.
- Required evidence already earned:
  - PR routine run `33120117574` passed;
  - exact-head full matrix `33122782836` passed Ubuntu, macOS, and Windows;
  - exact-main run `33126077131`, Ubuntu job `98704433259`, passed in
    54m16s;
  - `codex:phylo-coef-fixed-rho` lease was explicitly released.
- Fresh preflight found active foreign lanes but no live lease. Their MSPL,
  random-slope handover, and LV recovery paths remain outside this lane.
- This lane holds the exact public coefficient source, test, article, help,
  design, and closeout paths listed in `.unlazy/phylo-coef-public/GATES.md`.

## 2. Public scientific contract

For response column `t`, sampled row `i`, and selected coefficient basis
`z_i`, fit

```text
eta_it,coef = z_i^T b_t,
B = [b_1^T; ...; b_T^T],
B ~ MN(0, K_rho, Sigma_coef).
```

Trait-major vectorisation therefore has

```text
Cov(vec(B^T)) = K_rho (x) Sigma_coef.
```

The admitted public bases remain exactly `1`, `0 + x`, and `1 + x`; single
bar estimates a full positive-definite `Sigma_coef`, and double bar maps its
strict lower triangle to zero. IID `column_coef()` has `K_rho = I`.

For a supplied positive-definite phylogenetic covariance `K`, use

```text
D = diag(sqrt(diag(K))),
R = D^(-1) K D^(-1),
K_rho = D [rho R + (1-rho) I] D
      = rho K + (1-rho) diag(K).
```

Numeric `rho` remains fixed in `[0,1]`. `rho = NULL` estimates an interior
value with one unconstrained TMB parameter `eta_rho` and
`rho = plogis(eta_rho)`. It must never silently snap to an endpoint.

### AD-safe estimated-rho representation

Because `R` is fixed, write `R = U diag(lambda) U^T`. Then

```text
s_j(rho) = (1-rho) + rho lambda_j,
K_rho^(-1) = D^(-1) U diag(1/s_j) U^T D^(-1),
log|K_rho| = 2 sum(log(diag(D))) + sum(log(s_j)).
```

This is algebraically identical to the declared covariance mixture, keeps
all `rho` dependence inside automatic differentiation, avoids mixing source
precisions, and avoids a dense AD matrix inverse. R validates and aligns the
source, constructs `D`, `U`, and `lambda`, and TMB owns the transformed
parameter, precision, log determinant, objective contribution, and reports.

### Compatibility boundary

- `column_coef(0 + x | trait)` remains exactly equivalent to
  `slope(x | trait)`, including maps, objective, gradient, random block,
  reports, fitted values, and extractor covariance.
- No-intercept `phylo_coef(..., rho = 1)` continues to hard-dispatch through
  released `phylo_slope()` under both bars.
- The released dense-VCV endpoint therefore retains its historical
  `K + 1e-8 I` conditioning. Interior or intercept-bearing coefficient fits
  use the raw declared mixture. The help and article disclose this narrow
  endpoint seam; they do not imply continuity that the package does not have.
- Every current `*_slope()` helper stays exported, warning-free, current, and
  non-deprecated.

## 3. Public API and extractor contract

1. Export formula markers `column_coef()` and `phylo_coef()` with roxygen
   documentation, runnable examples, generated Rd, NAMESPACE, pkgdown index,
   and NEWS entry.
2. Admit the already-fitted IID route through ordinary public `gllvmTMB()`.
3. Admit fixed and estimated phylogenetic routes through ordinary public
   `gllvmTMB()` for the tested Gaussian multivariate regime.
4. Preserve typed syntax/source/fixed-overlap failures and keep
   `animal_coef()`, `kernel_coef()`, and `spatial_coef()` fenced.
5. Add `extract_Sigma(fit, level = "column_coef")` as the coefficient-specific
   contract. It reports, with stable labels/order:
   - coefficient `basis`;
   - `source` (`iid` or `phylo`);
   - `Sigma_coef` and its correlation form;
   - `rho`, plus `rho_status` (`not_applicable`, `fixed`, or `estimated`);
   - the aligned fitted `K_rho` for phylogenetic fits.
6. Leave `extract_Sigma(..., level = "column_slope")` and existing slope-fit
   objects backward compatible.
7. Exercise `screen_gllvmTMB()` and keyed `column_data` boundaries explicitly;
   public export must not bypass the established long/wide preparation rules.

## 4. Long/wide and article contract

- Long form remains canonical:

  ```r
  gllvmTMB(value ~ 1 + phylo_coef(1 + latitude | trait, tree = tree),
           data = df_long, trait = "trait")
  ```

- Wide form uses the same entry point and `traits(...)` grammar:

  ```r
  gllvmTMB(traits(sp1, sp2, sp3) ~ 1 +
             phylo_coef(1 + latitude | trait, tree = tree),
           data = df_wide)
  ```

- Matched fixtures must prove identical prepared basis, objective, parameter
  maps, fitted values, `rho`, and extracted covariance after label alignment.
- `where-does-the-tree-go.Rmd` will replace its stale “no `column_coef()`”
  boundary with a runnable biological workflow using earned `column_coef()`
  and `phylo_coef()` syntax in long and wide form.
- `api-keyword-grid.Rmd` will describe both coefficient helpers outside the
  5 x 3 covariance-keyword grid. It must not turn coefficient sources into new
  grid rows or modes.
- `phylogenetic-gllvm.Rmd` remains unchanged unless a concrete contradiction
  appears during stale-wording review.

## 5. Depth tree and dependencies

The work is sequential because the high-risk implementation and public docs
share central files. Independent reviewers receive frozen byte sets only.

| ID | State | Needs | Deliverable |
|---|---|---|---|
| 1 | READY | none | Freeze symbolic math, parameter/data/report names, extractor schema, errors, and compatibility boundary. |
| 2 | WAITING | 1 | Write failing TDD oracles for public markers, estimated rho, long/wide parity, extraction, recovery, and released-slope invariants. |
| 3 | WAITING | 2 | Implement spectral estimated-rho TMB plumbing and public R routing without changing fixed endpoints. |
| 4 | WAITING | 3 | Implement exports, roxygen/Rd, extractor level, NEWS, pkgdown registration, and scope boundaries. |
| 5 | WAITING | 4 | Update and render the two named articles; inspect the actual built HTML. |
| 6 | WAITING | 5 | Run focused tests, recovery, slope regressions, full suite, pkgdown, local package check, stale scans, and Unlazy reverify. |
| 7 | WAITING | 6 | Obtain Gauss/Noether, Grace, Rose, and applied-user reviews; repair and rerun affected gates. |
| 8 | WAITING | 7 | Commit, push once with CI pacing, pass routine plus manual exact-head three-OS checks, merge normally without bypass, verify exact main, release lease, and finish durable closeout. |

## 6. TDD and independent oracles

RED tests precede implementation for:

1. exported marker/help registration and direct public long/wide routing;
2. exact fixed-rho regressions at `rho = 0`, interior, near one, and one;
3. spectral precision/log-determinant equality against direct covariance
   inversion for unit and non-unit diagonals;
4. automatic-differentiation gradient versus central finite difference for
   `eta_rho` at multiple interior values;
5. objective/report equality between fixed `rho = r` and estimated-route
   objective evaluated at `qlogis(r)`;
6. finite optimum gradients and deterministic known-DGP recovery for `rho`,
   `Sigma_coef`, and coefficient predictions;
7. exact IID and `rho = 1` released-slope equivalence under both bars;
8. fixed/estimated extractor labels, order, `K_rho`, and status metadata;
9. exact long/wide fitted-object parity;
10. typed malformed-source and still-fenced animal/kernel/spatial failures;
11. warning-free `*_slope()` regression scans and unchanged existing fits;
12. runnable article code and built-HTML content/links.

Negative assertions receive a known-positive control so a wrong path or empty
scan cannot pass as evidence.

## 7. Compute and fit budget

- Before every fit, simulation, or benchmark, record an estimate derived from
  the nearest fixed-rho/IID timing.
- Focused public-route and gradient fixtures are expected to finish locally in
  under 10 minutes each; the combined focused gate is expected under 25
  minutes. These may run after a succinct correctness pre-run.
- The local full package check is expected in 20–30 minutes from the fixed-rho
  receipt and may run once the candidate is frozen.
- No broad recovery campaign is planned. If evidence shows a claim-bearing
  campaign is necessary or any planned run projects above 30 minutes, stop,
  retain the pre-run result, present the exact Totoro/DRAC plan, and obtain
  explicit approval. GitHub Actions remains package/docs CI only.
- A run that exceeds its estimate stops and re-reports before being widened.

## 8. Review and release gates

- Gauss + Noether: covariance algebra, transform, TMB objective, determinant,
  parameter maps, endpoint equivalence, and finite gradients.
- Grace: compiled portability, generated docs, pkgdown, CI scope, and Windows
  risk.
- Rose: repeated discrepancy/stale wording audit across code, help, NEWS,
  Design 131, Design 35, both named articles, after-task, and handover.
- Pat/Darwin perspective: an applied reader can run both formats, understand
  what `rho` and `Sigma_coef` mean, and see the tested limitations.
- Pre-publish Rose gate is mandatory because exported roxygen, Rd, NEWS,
  pkgdown, and articles change.
- One frozen candidate, one push wave, routine PR CI, then one manual exact-head
  Ubuntu/macOS/Windows matrix. Merge normally without protection bypass only
  when all required exact-head checks are green. Verify exact merged main before
  lease release or completion claims.

## 9. Definition of genuinely complete

Every gate in `.unlazy/phylo-coef-public/GATES.md` has fresh evidence; no gate
is abandoned. The final audit maps every user requirement to code, tests,
rendered output, reviewer receipts, exact CI runs, merge SHA, exact-main run,
and lease release. Only then may the programme heartbeat be deleted and the
persistent goal marked complete.
