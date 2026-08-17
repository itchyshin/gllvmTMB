# Codex handover — Poisson \(W\) REPLACE

**Status:** G0 **SIGNED — REPLACE** on `main` (#1102). Implementation **not started**.

**Build contract (authoritative):** `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (SIGNED paste) and `docs/dev-log/decisions.md` (2026-08-17 REPLACE entry).

**Job:** change live Poisson MSPL tape from GLM-outer \(W=\operatorname{diag}(\mu)\) / `return eta` to working logistic \(W_*\) (Tweedie precedent). Required: `tmb-likelihood-review` + Gauss/Noether + `docs/design/03-likelihoods.md` + simulation recovery; rewrite #1064 W2/W7 (they pin `return eta` by design). Twin rematch must go green before SE-series doors open.

**Hard stops:** no public `se` / `vcov` / `confint`; `MSPL-04` blocked; no Design 118; Lane B PROTECTED; no rebuild #1090; do not undraft #1077 for public confint.
