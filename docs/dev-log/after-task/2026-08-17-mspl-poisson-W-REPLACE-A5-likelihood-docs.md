# After-task — A5 docs polish: Poisson MSPL \(W_*\) row + review checklist

**Date:** 2026-08-17  
**Lane:** `cursor/mspl-poisson-W-REPLACE-impl`  
**PR:** https://github.com/itchyshin/gllvmTMB/pull/1111  
**Status:** docs polish on top of landed A1–A8 (`e2b13651`+).  
**Roles:** Gauss / Noether / `tmb-likelihood-review` checklist expanded in
`docs/dev-log/research/2026-08-17-mspl-poisson-W-REPLACE-tmb-review.md`.

## Goal

After A1 landed: sharpen `docs/design/03-likelihoods.md` Poisson MSPL weight
row (logit \(\mu_*\), Tweedie `family_id == 6` precedent, existence device ≠
true Jeffreys, **not** NEWS `covered`) and leave an explicit Gauss/Noether
checklist for the PR skim. Do **not** claim NEWS `covered`.

## Files

- `docs/design/03-likelihoods.md` — Poisson REPLACE bullet polish
- `docs/dev-log/research/2026-08-17-mspl-poisson-W-REPLACE-tmb-review.md` — expanded checklist
- `docs/dev-log/after-task/2026-08-17-mspl-poisson-W-REPLACE-A5-likelihood-docs.md` (this file)
- `docs/dev-log/check-log.md` — append

## Mathematical contract (unchanged by polish)

Live: \(W_*=\mu_*(1-\mu_*)\), \(\mu_*=\operatorname{logit}^{-1}(\eta)\),
C++ `gll_mspl_log_weight(eta, 0)`. Historical contrast: \(W=\operatorname{diag}(\mu)\).
Not \(I_{\mathrm{LA}}(\beta)\); not public SE/CI; not NEWS `covered`.

## Checks

```sh
rg -n 'logit\^\{-1\}|/\*logit\*/ 0|not true-model|not NEWS' docs/design/03-likelihoods.md
rg -n 'Gauss|Noether|Hard OUT' \
  docs/dev-log/research/2026-08-17-mspl-poisson-W-REPLACE-tmb-review.md
# deliberately not: NEWS covered claim; MSPL-04 flip; undraft #1077
```

## Roadmap / issues

- Roadmap: N/A  
- #1102 authority; #1111 REPLACE PR; #1064 oracle rewrite parent
