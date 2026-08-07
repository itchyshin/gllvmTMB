# After-task: binomial Σ rel-Frob challenge (runaway vs collapse)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Scope:** Diagnose whether binomial logit gtmb_VA Σ relative Frobenius 3.7–4.9 is impossible / a scorer bug.

## Outcome

- **Relative Frob >1 is not impossible** (unbounded). >1 = worse than zero estimator in Frobenius distance.
- **Verdict (A):** table numbers are real — gtmb_VA **runaway** loadings (`‖Σ̂‖_F ≫ ‖Σ‖_F`). Not (B) scorer arithmetic bug; not (C) estimand mismatch inflating ours only.
- **Interpretation fix:** gllvm VA ~1.0 on logit is **Σ̂≈0 collapse** (`sigma.lv`~1e−6), not a good recovery. Hand-checked seeds 10801/10804/10814.
- Probes now emit `frob_Shat` / `sigma_collapse`. Audits amended. Numbers unchanged (no re-fit).

## Checks

- Hand recompute via `dev/va-gh-h7-campaign/probe-sigma-hand-audit2.R` (local, untracked diagnostic).
- Totoro summary MD5 unchanged; annotation only.
- Did not re-run full 24-seed campaigns (systematic logit/probit already finished; no double-claim).

## Follow-up

Continue logit/probit dig with corrected metric reading; fair Σ comparator prefers non-collapsed arms + ‖Σ̂‖_F. STOP: no nbinom Totoro without G0.
