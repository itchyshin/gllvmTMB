# R ↔ Julia bridge coordination (2026-06-20, Claude/Ada)

A cross-repo coordination note tying the **gllvmTMB** R bridge and the
**GLLVM.jl** Julia engine together: what is verified, what each side owns, and
the family/feature map so the two roadmaps stay in sync. Posted to both repos
(gllvmTMB dev-log + a pointer comment on GLLVM.jl #65).

Pinned commits: gllvmTMB `origin/main` = `f4da6c1`; GLLVM.jl `origin/main` =
`3d6dd3a` (#101 wide bridge + #102 docstring truth-fix merged).

## Verified state of the live bridge

- gllvmTMB `engine = "julia"` routes through `GLLVM.bridge_fit` / `bridge_capabilities`
  (both on GLLVM.jl `main` via #101). The **live `julia-bridge` suite re-verified
  clean against `main`-on-`main`: PASS 1228 / FAIL 0 / WARN 0 / SKIP 0**
  (2026-06-20, after-task `2026-06-20-bridge-reverify-101.md`).
- The Julia engine's analytic Laplace gradients are the production default and
  FD-gated (`test_laplace_grad.jl`); masked Poisson/Binomial fits now use the
  analytic gradient too (GLLVM.jl #103, held).
- Hard guard: PR green ≠ bridge complete ≠ scientific coverage passed. JUL-01 /
  JUL-01A stay `partial` (no promotion this session).

## Who owns what

| Concern | Owner (repo) | Tracked in |
|---|---|---|
| Engine fitters / families / gradients / CIs | **GLLVM.jl** | issues #65 (analytic-grad/bench), #104–#110 (new families), #61/#62 (phylo/SPDE) |
| `bridge_fit` / `bridge_capabilities` surface | **GLLVM.jl** | `src/bridge.jl` |
| R `engine="julia"` routing, payload labels, gates | **gllvmTMB** | `R/julia-bridge.R`, validation-debt rows JUL-01 / JUL-01A |
| Native-vs-Julia parity evidence + status calls | **gllvmTMB** | `docs/design/35-validation-debt-register.md` |

Division of labour: the Julia side advances the engine; the R side exposes it
behind explicit gates and never advertises beyond `partial` without parity
evidence. Engine merges and grammar changes need maintainer sign-off.

## Family / feature exposure map

**Bridge-exposed today** (both `_BRIDGE_ONEPART_FAMILIES` on GLLVM.jl and
`.GLLVM_JULIA_BRIDGE_FAMILIES` on gllvmTMB agree): gaussian, poisson, binomial,
negbinomial (NB2), nb1, beta, gamma, ordinal, ordinal_probit, plus the narrow
mixed-family vector route.
- Fixed-effect **X**: poisson / binomial / negbinomial / beta / gamma (no NB1-X,
  no ordinal-X kernel yet).
- Response **masks**: the non-ordinal non-Gaussian subset; CI on masked no-X.
- Grouped dispersion, post-fit simulate, Wald/profile/bootstrap CI fan-out.

**Planned engine families (NOT yet in either bridge — new issues from the #94
supersession):** GenPoisson (#104), Student-t (#105), one-part lognormal (#106),
zero-truncated Poisson/NB (#107). When any lands in the engine, it needs, in the
**same coordination loop**:
1. GLLVM.jl: add to `_BRIDGE_ONEPART_FAMILIES` (+ `_BRIDGE_X_FAMILIES` if a
   covariate kernel exists) and `bridge_capabilities`.
2. gllvmTMB: add the family to `.GLLVM_JULIA_BRIDGE_FAMILIES`, a public scale/label
   map, a per-family ADEMP recovery gate, and a JUL row with parity evidence.

## Largest remaining bridge gaps (decision-gated, from the finish-map)

- **Structured-term routing** (phylo / spatial / animal / kernel through the flat
  bridge): the engine has the fitters but none are wired into `bridge_fit`; needs
  a new structured payload contract over the ASCII bridge + R labels + CI + an
  article. Phase-scale program — the single biggest bridge gap.
- **New families through the bridge** (Tweedie / ZIP / ZINB / Delta-Gamma): the
  engine implements several (CI-gated); the bridge family map + R scale-maps +
  per-family ADEMP gates are the missing exposure layer.
- **CIs absent at the engine level**: NB1-X / ordinal-X CIs, mixed-CI,
  ordinal-CI, newdata predict/simulate (engine is structurally in-sample).
- **Broad native-vs-Julia parity promotion** (JUL-01/JUL-01A → `covered`): a
  sustained validation campaign + status sign-off, not a single slice.

## This session's R↔Julia items

- ✅ Bridge re-verified (1228) — gllvmTMB #498 (merged).
- 🟡 J1 docstrings — GLLVM.jl #102 (merged); masked Poisson/Binomial analytic —
  GLLVM.jl #103 (held, verified).
- 🟡 Coevolution exports salvaged — gllvmTMB #500 (held).
- 📋 #94 closed as superseded; engine family work preserved as GLLVM.jl
  #104–#110.
- ⏭️ Next bridge-adjacent build: NB/Gamma/Beta masked analytic gradient (after
  GLLVM.jl #103 merges, to avoid a `test_laplace_grad.jl` overlap).

## Coordination protocol

Per AGENTS.md, agent-to-agent handoffs live in the repo, not chat. R↔Julia
coordination uses: GLLVM.jl issue comments (#65 for bridge/engine), gllvmTMB
`check-log.md` + this note, and the JUL rows in the validation-debt register as
the shared contract surface. When one side moves a family/feature, it pings the
other via the linked issue.
