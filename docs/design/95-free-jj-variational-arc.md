```text
🎯 GOAL
PLATFORM: Codex | DESIGN: 95 | DELIVERABLE: a private, identified q=2
Bernoulli-logit Jaakkola--Jordan variational prototype with independent R
oracle and deterministic evidence packet. HEADLINE: determine whether the
fixed-loading lower-bound kernel from Design 94 remains mathematically and
numerically coherent when intercepts and identified loadings are free. IN
PARALLEL: identification review and scope/provenance review. DEFER: package
engine integration, public API, structured priors, long-format mapping,
upstream parity, recovery/calibration campaigns, and every Design 72/85/86/
90/91 artifact. DISCIPLINE: every gate is prospective and private; a failed
gate stops the arc, and a passing gate is experimental developer evidence only.
```

# Design 95 — free-parameter JJ variational prototype arc

## Context and prior-work receipt

| Surface | Evidence run | Finding | Forced call |
|---|---|---|---|
| Repository | `git status -sb`; `git log --oneline -20`; `git branch -a`; `git worktree list`; `git stash list`; `branch_drift_check.sh` | Many historical worktrees exist; this branch starts at `c6297589`, the current package base. | Use a new isolated worktree; do not resume a historical lane. |
| Project records | `rg` over `docs/design/72-variational-approximation-feasibility.md` | Design 72 Phase 1 was parked: VA did not cure genuinely rank-deficient small-data models. | No claim of universal stability; freeze identification and inspect collapse. |
| New private work | Design 94 commit `f88f4420`, read its contract/test record | Fixed-loading q=2 JJ kernel passed deterministic checks only. | Reuse equations as a reference, not as evidence for free parameters. |
| Sister repository | `rg -i 'variational|jaakkola|polya|EVA'` in `GLLVM.jl` | No reusable Bernoulli variational engine was found. | Build only the missing private q=2 gap. |
| Brain | `search_notes(..., search_all_projects = true)` query `gllvmTMB Design 94 ... VA free-loading recovery design` | Design 72/85 are parked/no-go; Design 94 is a new narrow kernel. | Preserve their boundaries. |
| External evidence | Design 94 Notebook `89d8ce4a-ef18-420a-b9ce-ed69c17b3d39` | Pólya--Gamma/JJ supports a genuine quadratic lower-bound route; it does not validate a GLLVM engine. | Retain JJ as a private variational alternative, not EVA parity. |

**Genuine new gap:** an identified, free-parameter q=2 implementation can be
checked for objective/gradient consistency and evident degeneracy before any
claim about recovery or integration.

## Contract

For unit `i` and trait `t`, let

\[
\eta_{it}=\beta_t+\lambda_t^\top u_i,\quad
q_i(u_i)=N_2\{m_i,\operatorname{diag}(s_{i1}^2,s_{i2}^2)\}.
\]

For binary `y` define \(\kappa_{it}=y_{it}-1/2\),
\(\mu_{it}=\beta_t+\lambda_t^\top m_i\),
\(v_{it}=\sum_k\lambda_{tk}^2s_{ik}^2\), and
\(\xi_{it}=\sqrt{\mu_{it}^2+v_{it}}\). The implementation minimizes the
negative of the complete JJ ELBO

\[
\begin{aligned}
\mathcal L_{JJ}=&\sum_{it}\{\kappa_{it}\mu_{it}
-\omega(\xi_{it})(\mu_{it}^2+v_{it})+\log\sigma(\xi_{it})
-\xi_{it}/2+\omega(\xi_{it})\xi_{it}^2\}\\
&-\frac12\sum_{ik}\{s_{ik}^2+m_{ik}^2-1-\log(s_{ik}^2)\},
\end{aligned}
\]

where \(\omega(\xi)=\tanh(\xi/2)/(4\xi)\), with removable limit
\(\omega(0)=1/8\). No \(\xi\) is optimized: it is profiled as the stated
second moment. `log_sd` is unconstrained and \(s=\exp(\mathrm{log\_sd})\);
the code uses the small-\(\xi\) expansion \(1/8-\xi^2/96\) to avoid `0/0`.
All displayed terms, including constants, are retained.

For a fixture with `T >= 2` and frozen trait order, `beta`, the
lower-triangular leading `2 x 2` loading block, and all remaining loading rows
are free. Its first two rows are
\(\lambda_{1\cdot}=(\exp(a_1),0)\) and
\(\lambda_{2\cdot}=(a_{21},\exp(a_2))\). This fixes sign and rotation
convention locally; dimension/trait-order violations fail loudly. It is not a
claim that this is the package's future parameterisation.

## Gates and stop rules

1. **G0 — contract and isolation.** New fixture, seeds, thresholds, output
   root, C++ source, and telemetry are Design 95 only.  The sole code allowlist
   is `dev/design95-free-jj-va/`; guards require empty diffs for
   `src/`, `R/`, `man/`, `NAMESPACE`, `DESCRIPTION`, `inst/`, `vignettes/`,
   `README*`, `NEWS*`, `_pkgdown.yml`, and the terminal Design 72/85/86/90/91
   files.  In particular, `src/gllvmTMB.cpp` and every package compilation
   input are forbidden.
2. **G1 — algebra and autodiff.** Independent R and C++ objectives agree;
   TMB gradients agree with finite differences at a nondegenerate point.
3. **G2 — identification/invariance.** Decode/encode transforms are exact;
   a deliberately invalid leading block is unrepresentable; the fitted
   loading cross-product is reported, never raw rotated alternative loadings.
4. **G3 — bounded stability probe.** One new deterministic known-parameter
   Bernoulli fixture, one fixed start, and predeclared finite/gradient/positive
   diagonal checks.  It reports a truth-aligned covariance distance only as a
   diagnostic, with no recovery threshold and no admission claim.
5. **G4 — closeout.** A scope and method review must agree that the result is
   still only a private prototype.  Any failure writes a stop receipt and ends
   this arc; no retries, altered thresholds, new starts, or campaigns.

## Slice plan

| Slice | Member / model / effort / routing | Time | Output | Dependency |
|---|---|---:|---|---|
| Contract review | Gauss/Noether, Terra-high, native/explicit | 35 min | plan-review verdict | G0 contract |
| Scope review | Rose, Terra-medium, native/explicit | 25 min | boundary verdict | G0 contract |
| Prototype build | Ada, current session | 2.5 h | private C++/R/test files | both reviews pass |
| Mechanical verification | Luna, low, tiered-cli/enforced | 25 min | file/path/check receipt | build complete |
| Method closeout | Fisher/Rose, Terra-high, native/explicit | 45 min | experimental-only verdict | test receipt |
| Consolidation | Ada | 45 min | check-log, after-task, commit | all gates |

**Estimate:** up to seven hours, two review agents plus one mechanical
verifier.  The arc should fit this session.  `LUNA SUITABILITY: yes` for the
post-build file/diff/checksum verification only; mathematical and scope
judgment require Terra.

## What the brain already knows

Design 72 established that VA does not create information in rank-deficient
models.  Design 85 is a no-go.  Design 86/90/91 have terminal observation
boundaries.  Design 94 is a passing fixed-global kernel, not an engine.

## What Shinichi told us

The maintainer explicitly requested a seven-hour autonomous big arc and asked
for implementation/testing.  Economy is required; therefore no campaign,
cluster compute, public integration, or duplicated external research is in
scope.

## Team raised

- **Gauss** — free q=2 loadings are rotation-sensitive; parameterisation must
  be fixed before optimization. Recommendation: use a lower-triangular leading
  block with positive diagonal.
- **Fisher** — a finite objective is not recovery. Recommendation: retain a
  bounded known-fixture diagnostic only, with no success threshold.
- **Rose** — past EVA/VA attempts were over-interpreted. Recommendation: add
  empty-diff guards and an explicit experimental-only stop boundary.
- **Ada** — the recommended arc is a bridge between fixed-kernel correctness
  and any later recovery design, not an admission attempt.

## Decisions locked

- This is Design 95, not an Arc 9 continuation of Design 86.
- The local lower-triangular convention is for prototype identifiability only.
- One deterministic known fixture is a stability probe, not a recovery study.
- No package source or public surface can change in this arc.

## Questions still open

None requiring maintainer input: the stated gate sequence is the conservative
default and execution was explicitly approved.  Any failure that would require
a different estimator, a threshold change, extra start, or broader compute is
a new decision point.
