# After-task — Stan oracle Arc 2: the `tree =` augmented-sparse phylogenetic path

Date: 2026-08-03. Platform: **Claude Code** (solo lane; no Codex lane on this subject —
`lane_preflight.sh` returned "no codex lane detected in the last 12h").
Branch: `claude/stan-oracle-arc2-tree`, worktree
`/Users/z3437171/local-scratch/worktrees/stan-phylo-tree`, forked from `origin/main` @ `dbd0b2d5`.

## 1. Goal

Extend the fixed-parameter Stan oracle from Arc 1's dense/legacy `vcv =` route to the
**canonical `tree =` augmented-sparse** route — the one users are steered toward, where latent
scores live at internal tree nodes as well as tips, and where a tips-vs-nodes error would have
been invisible to Arc 1. Keep the independence fence: the Stan model's density must come from
published equations and design prose, never from `src/gllvmTMB.cpp`.

## 2. Implemented

An independent Stan oracle for the augmented-node phylogenetic GLLVM, and its reconciliation
against gllvmTMB's joint log-density.

- `gllvm_phylo_tree.stan` implements `model-spec-phylo.md` §8.5 — Brownian motion over non-root
  tree nodes, `a_v | a_p(v) ~ N(a_p(v), b_v)` with `a_root ≡ 0`. It takes a **parent map and
  branch lengths** and never receives `A`, `A⁻¹`, or any Cholesky factor.
- `tmb-side-tree.R` builds the `tree =` fixture and measures the transport.
- `transport-tree.md` declares the transport: Arc 1's rules 1–4 carry over, rule 6 (the `1e-8`
  ridge) is **void**, rules 5/7/8 are replaced, and two new rules appear (node permutation,
  branch-length rescaling).
- `gauss-reconcile-tree.R` compares the two, at four points, with six controls plus a
  star-phylogeny control.
- `verify-algebra.R` is a **third** implementation in pure R, using neither TMB nor Stan.

**Result: they agree.** `TMB 219.35321036952374` vs `Stan −219.35321036952377`, difference
`2.84e−14`, relative `1.30e−16`. Worst case over four points `1.82e−12` absolute (on a value of
`1.47e+04`), `5.14e−16` relative.

## 3a. Decisions and Rejected Alternatives

- **Enforced the fence structurally rather than by self-restraint.** I read
  `src/gllvmTMB.cpp:1160-1200` while scouting, so I was no longer fence-clean and did **not**
  write the Stan density. A sub-agent with an explicit prohibition on `src/`, `R/fit-multi.R`,
  `R/phylo-tree-precision.R`, `reconciliation-phylo.md` and every Arc 1 driver wrote it.
  *Rejected:* writing it myself with self-imposed discipline — that is precisely the posture
  Arc 1 §11.3 criticised.
- **Committed model + transport + driver before any result existed** (`cd0c58cf`), so git
  history is the chronology evidence. *Rejected:* asserting a-priori derivation in prose, which
  is what Arc 1 did and what its adversarial review refuted.
- **Built the Stan prior from the tree, not from a precision matrix.** *Rejected:* passing
  `Ainv_phy_rr` into Stan, which would have made the comparison largely circular.
- **Did not fix the two cosmetic print defects in the committed driver.** Editing a
  pre-registered artifact after seeing its results would undermine the very thing it exists to
  demonstrate. Recorded in `reconciliation-tree.md` §12 instead.
- **Left `n_aug = 2S−2` out of the Stan model as an assertion.** The model takes `n_node` as
  data and only requires "one parent and one branch per non-root node", so it works for
  polytomies. This turned out to matter (§7a).

## 4. Files Touched

Created, all under `dev/stan-oracle-phylo-tree/`:

| file | what |
|---|---|
| `gllvm_phylo_tree.stan` | the fence-clean augmented-node Stan model |
| `stan-side-tree.md` | its interface contract, derivation, and fence declaration |
| `tmb-side-tree.R`, `tmb-side-tree.md` | the `tree =` fixture builder and its measurements |
| `tmb-fixture-tree.rds`, `.json` | the fixture |
| `transport-tree.md` | the declared transport |
| `gauss-reconcile-tree.R`, `.log` | dataset A driver and its captured output |
| `gauss-reconcile-tree-k2.R`, `.json` | dataset B driver and results |
| `verify-algebra.R` | the orchestrator's third implementation, pure R |
| `reconciliation-tree.md` | the verdict document |
| `.gitignore` | mirrors Arc 1's (ignore compiled Stan `.rds`, keep the fixture) |

Also created: this report. **Nothing under `R/`, `src/`, `tests/`, or `docs/design/` was
modified by the oracle work** — see §12 for the separately-fenced documentation slice.

## 5. Checks Run

| check | result |
|---|---|
| `pkgbuild::compile_dll(".")` | exit 0, `src/gllvmTMB.so` built |
| `Rscript dev/stan-oracle-phylo-tree/tmb-side-tree.R` | fixture written; joint = `173.37932199712063` |
| `Rscript dev/stan-oracle-phylo-tree/verify-algebra.R` | 3 claims × 3 trees, all to machine precision |
| `Rscript dev/stan-oracle-phylo-tree/gauss-reconcile-tree.R` | 4 points agree; 6 controls + star control all fire |
| re-run of the same driver | **byte-identical** headline; reproducible |
| `Rscript dev/stan-oracle-phylo-tree/gauss-reconcile-tree-k2.R` | dataset B — see §5b |
| Jacobian audit | `log_prob(TRUE) − log_prob(FALSE) = log(σ_ε)` to `7.3e−15` |
| difference-of-differences | `0`, `1.79e−12`, `−1.42e−13` — agreement is pointwise, not up to a constant |
| Stan model mtime asserted unchanged on driver exit | `TRUE` |
| adversarial panel, two fresh lenses | see §6 |

**Not run:** `devtools::test()`, `R CMD check`. No package code changed in the oracle work, so
neither would have exercised anything new. The documentation slice (§12) is the one that would
need `document()`; stated there rather than implied.

## 6. Tests of the Tests

The controls exist precisely to show the comparison **can** fail. Each breaks exactly one
transport rule; all shifts are 11–14 orders above the `≤1.8e−12` agreement floor:

| control | shift |
|---|---|
| internal-node score perturbed (η never reads it) — **the vacuity test** | `−0.2688` |
| engine node order fed directly, permutation skipped | `−4.8245` |
| branch lengths unscaled | `+7.6139` |
| root added as a 15th node (the documented `2S−1`) | `−0.9189385332` |
| tip block permuted | `+31.9878` |
| `branch_len` read as an SD not a variance | `−496.9393` |

The star-phylogeny control is the strongest single piece: `n_aug` collapses 14 → 8, both sides
still agree to `5.68e−14`, and the density moves `44.74` when the real tree is swapped for a
star. So both sides track real phylogenetic structure *and* agree on a degenerate one.

The root control is **exact**: `−0.91893853320468` measured against `−½log(2π) =
−0.91893853320467`, agreeing to `8.7e−15`.

## 7a. Issue Ledger

**Found — documentation vs implementation:**

1. **The augmented node count is wrong in five places.** `n_aug = n_tip + Nnode − 1` = the
   number of **edges** in the tree. `2·n_tips − 1` (`src/gllvmTMB.cpp:1168`,
   `docs/design/69:193`) is wrong for every tree; `2·n_tips − 2` is right only for a fully
   bifurcating tree. A **polytomous tree fits successfully** with `n_aug_phy = 5` where the
   formulas predict 6 or 7. Cost quantified at exactly `−½log(2π)` per latent axis.
2. **`src/gllvmTMB.cpp:380` still credits `MCMCglmm::inverseA(tree)`** — stale since the native
   builder landed.
3. **`docs/design/69:191` carries the pre-#611 log-determinant sign** (`-sum(log(inv$dii))`),
   the form that issue #611 fixed. `docs/design/35:194` has the post-fix form. Both label the
   result `log|A|`.

**Deferred (flagged, not actioned):** the seed-fragile loading-sign assertion at
`tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R:126`, spun out as its own task.
`dep()`'s `L` description at `docs/design/04-random-effects.md:332` — Arc 2 touches no `dep()`
code and has no evidence either way; left explicitly open rather than guessed at.

## 8. Consistency Audit

Applying "fix the class, not the instance" to the node-count error: I did not stop at the first
site. I grepped every `2*n_tips`, `2N-1`, `2S-1` form across `src/`, `docs/design/`, and `R/`,
found five statements, and classified each as flat-wrong versus hedged. I then tested the
formula across **four tree shapes** — bifurcating, large bifurcating, star, and polytomy —
rather than the one shape the fixture uses, which is what revealed that even `2S−2` is only
conditionally right.

Neighbourhood swept: `R/phylo-tree-precision.R` (the builder), `R/fit-multi.R:3157-3229` (all
three phylo branches), `R/va-r3-proto.R` (the only correct statement), the phylo test files, and
the two tests that appeared to disagree about `tree=` vs `vcv=` equivalence.

## 9. What Did Not Go Smoothly

- `dev/stan-oracle-phylo/tmb-side-phylo.R:46` hard-codes a worktree path that no longer exists,
  so Arc 1's harness would fail on a fresh checkout. Repointed in the Arc 2 copy; **Arc 1's file
  is left as-is** since it is committed evidence.
- My first polytomy fit failed with "Column site not found in data" — the `site` argument is
  required in this call shape and I omitted it. Unrelated to the finding.
- Two cosmetic defects in my committed driver (a diagnostic that prints one branch length
  instead of a path sum; a bare `[1]` echo from a helper). Recorded rather than patched, for the
  chronology reason in §3a.

## 10. Known Residuals

- **The sparse `vcv = <sparseMatrix>` route is untested** by any arc. It is structurally similar
  to `tree =` and is reached by `animal_*(pedigree=)` / `Ainv=`.
- **Non-ultrametric trees are unresolved.** `correlation = TRUE` requires ultrametricity, and
  §8.5's "scale that makes root-to-tip depth 1" presupposes it. The Stan side's own note flags
  this; Arc 2 did not test it.
- Gaussian only; `unique = FALSE` only; small trees (`S ≤ 10`) only; the **joint, pre-Laplace**
  density only. A correct joint density is necessary, not sufficient.
- **No coverage or calibration claim. No validation-debt register row moved.**

## 11. Team Learning

Five reusable points, filed to the brain as *"gllvmTMB Stan-oracle programme"* (the deterministic
grep found the programme was entirely absent from the brain until now):

1. **Enforce a fence structurally, not by self-restraint** — dispatch to an agent that *cannot
   open* the forbidden files, and commit the artifact before its result exists.
2. **A real fence leaves a fingerprint.** Arc 2's Stan author independently chose *tips-first*
   node ordering; the engine uses *internal-first*. An author who had peeked would have matched.
   Look for such mismatches as positive evidence.
3. **Build a third implementation.** A pure-R check using neither side being compared validates
   the algebra before either engine is trusted.
4. **Design the control that makes the check vacuous, then run it.** Arc 1's was the star
   phylogeny; Arc 2's was internal-node inertness.
5. **Two different numerical routes beat two spellings of one route.**

## 12. Cross-Product Coverage

Cross-cutting things this arc touched, and what it does **not** cover for each:

| touched | covered | NOT covered |
|---|---|---|
| phylo routes | `tree =` (this arc), dense `vcv =` (Arc 1) | **sparse `vcv =`/`Ainv =`** — untested by anything |
| families | Gaussian identity | every other `family_id` branch |
| phylo tiers | `unique = FALSE` (loadings-only) | `unique = TRUE` (`Ψ_phy`), `phylo_slope`, `phylo_dep`, `phylo_scalar`, `animal_*`, kernel |
| tree shapes | ultrametric bifurcating, star, one polytomy | non-ultrametric; large `S`; ill-conditioned |
| inference stages | pre-Laplace joint at fixed `(θ, a)` | Laplace, gradients, `sdreport()`, any fitted estimate, all downstream |
| parameter blocks | `b_fix`, `log_sigma_eps`, `theta_rr_phy`, `g_phy` | `g_phy_diag`, `b_phy_slope`, `b_phy_aug`, `g_phy_slope` — all share `n_aug_phy` and are untested |

**The documentation slice is deliberately separate.** The oracle work is `dev/`-only. The
package documentation fixes arising from §7a land in their own commit, touching
`R/brms-sugar.R` roxygen, `src/gllvmTMB.cpp` comments, and `docs/design/{35,69,106,108}`. That
commit needs `devtools::document()`; the oracle commits do not.

**Memory receipt.** Loaded: the hub `AGENTS.md` cross-repo guards (recall-before-scouting;
"existence is not validation"; lane preflight before claiming a lane), the repo `CLAUDE.md`
(capability widget first; the multi-lane split), and `ultra-plan` Phases 0–2. What actually
shaped the work: **recall-before-scouting** (the brain query surfaced
`2026-07-05-sparse-ainv-extra-node-engine`, and the deterministic greps found the Stan-oracle
programme absent from the brain — which is why §11 was filed); and **lane preflight**, which
confirmed no Codex lane on this subject before any branch was created. Golden Set: not run — no
known-mistake class from the regression set was in scope.
