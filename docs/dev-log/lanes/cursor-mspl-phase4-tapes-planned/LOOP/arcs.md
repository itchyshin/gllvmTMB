# Arcs — cursor-mspl-phase4-tapes-planned

| ID | Status | Arc | Notes |
|---|---|---|---|
| A0 | **DONE** | LOOP kit on `cursor/mspl-phase4-tapes-planned` | `b1271cca` from `origin/main` @ #977 `2a99af3a` |
| A1 | **DONE** | Wave 1: specs + failing tests (no `src/` first) | Poisson public-door was RED on the old fence; now GREEN |
| A2 | **DONE** | Wave 2: shared weight hook | `gll_mspl_log_weight_glm`; 2-arg Bernoulli `gll_mspl_log_weight` unchanged |
| A3 | **DONE** | Wave 3: Poisson tape + prepare widen | public `mspl` for Poisson; still `planned` |
| A4 | **DONE** | Wave 4: NB1, NB2, beta, Tweedie tapes | public still errors; NB2 stays `excluded` |
| A5 | **DONE** | Wave 5: Gauss, Noether, Rose, Shannon, Melissa | PR [#978](https://github.com/itchyshin/gllvmTMB/pull/978); still no admit |

Finish line: **fenced planned tapes + Poisson public door**, not admission.

## HARD STOP flags

- Admit any family / NEWS covered / SE
- Public `mspl` on NB1, NB2, beta, Tweedie
- Second `src/gllvmTMB.cpp` editor
- Bernoulli/Gaussian `c` transplant
- Calling GLM-outer `I_LA(β)`
- Prepare message still “binomial or gaussian only” after Poisson is callable
- Merge #972–#976 / Codex interval lane / Totoro>30min
- Repo-root `LOOP/` / Dropbox / `git add -A`
