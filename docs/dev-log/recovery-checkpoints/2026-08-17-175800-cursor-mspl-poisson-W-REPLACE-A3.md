# Recovery checkpoint — A3 twin rematch (Poisson W_* REPLACE)

**When:** 2026-08-17 ~17:58 local (MDT).  
**Lane:** `cursor/mspl-poisson-W-REPLACE-impl` @  
`/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-poisson-W-REPLACE`  
**Commit carrying A1–A3:** `e2b13651` (`feat(mspl): Poisson GLM-outer W_* REPLACE (G0 #1102)`).  
**PR:** https://github.com/itchyshin/gllvmTMB/pull/1111

## A3 deliverable (verified)

| Item | State |
|---|---|
| `R/mspl-poisson-atoms.R` Jeffreys twin | `W_* = mu_*(1-mu_*)`, `mu_* = plogis(eta)`; arg is `eta` not `mu` |
| `R/mspl-registry.R` poisson notes | names working logistic `W_*` + G0 REPLACE; still `no public SE` |
| Admit-packet **A6** | pins twin = working `W_*`; contrasts true `W=diag(mu)`; A7 live tape matches twin; A8 notes match |
| Hard OUT | intact — no public `se` / `vcov` / `confint`; SE doors PREP-only |

## Checks run

```sh
# Install from /tmp copy (local-scratch src/ blocked .o writes)
R CMD INSTALL --library=/tmp/gllvmtmb-mspl-pois-lib3 /tmp/gllvmtmb-mspl-pois-build
NOT_CRAN=true Rscript -e 'testthat::test_dir(..., filter="mspl-poisson", package="gllvmTMB")'
```

**Result:** `filter=mspl-poisson` — **30/30 PASS** (0 fail / 0 error / 0 skip) under `NOT_CRAN=true`.

## Already true before this sitting

- A1 `src/` `family_id==2` → `gll_mspl_log_weight(eta, 0)` committed in `e2b13651`.
- A2 W2/W7/W8 rewrite in same commit.
- Lane arcs A0–A7 marked done; A8 = wait/merge #1111.

## Next (not this checkpoint)

A8: CI green on #1111 → merge (preapproved). Do **not** open public SE or family SE doors.

## Dirty tree at checkpoint (do not `git add -A`)

Parallel LOOP / A5 docs / point-smoke notes may be uncommitted; leave for A8 owner.
