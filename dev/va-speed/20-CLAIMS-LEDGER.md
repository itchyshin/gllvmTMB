# Claims ledger — every substantive claim this arc made, and its current status

Written because the arc's headline changed **twice** under measurement, and several
commits are now on record carrying superseded framings. A reader arriving at any one
commit should be able to find out here whether it still stands.

**Convention:** STANDS · QUALIFIED · SUPERSEDED · RETRACTED.

| # | claim | where | status |
|---|---|---|---|
| 1 | Albert-Chib is an **objective substitution**, not an architecture change: `z` profiles out analytically to `y·logΦ(μ) + (n−y)·logΦ(−μ) − n·v/2` | `ALBERT-CHIB-DERIVATION.md`, `de255ba9` | **STANDS.** Confirmed against a 200-node GH reference to 6.2e-11, and by the working implementation. |
| 2 | The AC tier is correctly wired: strict lower bound, `he()` finite, family guard both ways, no silent tier fallback | `06-ac-tier-verify.R`, `478cc977` | **STANDS.** 21/21 checks; 245 existing VA tests green. |
| 3 | gllvm's `−v/2` is **not a valid lower bound** for `n > 1`; ours is | `de255ba9`, §6.2 | **STANDS** as a statement about the BOUND. Measured −15.584 nats at n=20. |
| 4 | …and that makes us "better than gllvm" | `478cc977` commit body | **QUALIFIED** by `1d10bca7`. It is a correctness property of the bound, **not** an accuracy claim. The two implementations reach the same optimum to 1e-5, so the corrected term barely moves this estimand. **Never quote (3) as an accuracy result.** |
| 5 | The AC evaluator is **15.5× cheaper** per evaluation; **17.7–26×** per fit | `fde6ca20`, `1ed59990` | **STANDS.** Clean, interleaved, serial. |
| 6 | AC is ~94–264× slower than gllvm | chat, mid-session | **SUPERSEDED.** That compared *different models* — ours carried a ψ tier gllvm does not fit. Like-for-like: **3.7×** (2.71 s vs 0.74 s). |
| 7 | GH "does not complete" at N=250/T=20 | `1ed59990` | **SUPERSEDED.** An artifact of `unique = TRUE`. With gllvm's model both complete in seconds. The commit already flagged it UNVERIFIED as a tier property; it was not one. |
| 8 | **The accuracy gate PASSES** — AC median 0.2259 ≤ 0.298 | `47d1fa22` | **QUALIFIED, and this is the important one.** Measured on a DGP planting **ψ = 0** — AC's single most favourable corner, since AC's known failure is collapsing ψ. It stands *for what it measured* and must not be read as general. |
| 9 | AC reproduces gllvm to 1.06e-04, independent of starting values | `47d1fa22`, `1d10bca7` | **STANDS.** Independence proven by construction: identical objective (1649.569276) and rel_frob spread 2.36e-06 from three starts. |
| 10 | …therefore AC is a success | implicit framing | **SUPERSEDED.** Agreement with the reference is **parity, not superiority.** Our **GH** tier beats gllvm (0.1974 vs 0.2259). |
| 11 | The ψ tier is B-tier, so D-28 forbids zeroing it | `6102e044` | **RETRACTED** by `ac3ed04e`. The level's *name* does not decide which tier is lowest — the data structure does. With one observation per (unit,trait) cell there is no `unit_obs` beneath it. |
| 12 | ψ is unidentified for probit, so fitting it is waste | implied by the 1e-05 measurement | **RETRACTED.** The DGP planted ψ = 0, so ~0 was correct. With ψ = 0.6 planted, ψ **is** recovered at `n_trials = 20` (0.5399) and the profiled objective has a clear minimum — identified, not degenerate. |
| 13 | **AC collapses a real ψ at low `n_trials`** — 0.0001 vs a planted 0.6 at n=6, where GH gives 0.6207 | `6cc84122` | **STANDS.** Same data through both tiers. AC also 29% worse on the loadings there. This is Risk R1 materialising. |
| 14 | The ψ = unique + link **conditional** is already correctly implemented | `6102e044`, `14-tier-rule-check.R` | **STANDS.** Only `gaussian_anchor` carries `log_sigma`; the B-tier ψ is family-agnostic. |
| 15 | **Warm-starting GH from AC** gives GH's accuracy in 36.8 vs 138.6 iterations | `17c03f4b` | **STANDS** as an ITERATION result (5 seeds, objectives agree to 4–5 s.f.). The **~3.0× whole-fit figure is ARITHMETIC**, not an end-to-end timing — confirm serially before quoting. |
| 16 | Our Laplace beats gllvm's Laplace by ~28% at `n_trials ≥ 6`, and does not collapse ψ | `775a9fdb` | **STANDS**, with one caveat: ψ was inferred as total−shared because `extract_Sigma(part="unique"/"psi")` returns NA. The qualitative conclusion does not depend on the exact value. |
| 17 | Amdahl caps Item 1 at ~3.35× whole-fit | `fde6ca20` | **STANDS** for the GH→AC substitution in isolation, and is *why* (10) is true — but it is not the ceiling for the arc, because the warm start and the model right-sizing are separate levers. |

## Open, and honestly unresolved

- **The `n·v/2` puzzle** (`12-INDEPENDENCE-AND-THE-NV2-PUZZLE.md`): two provably
  different objectives share an optimum to 1e-5. The inference — that the `v`
  coefficient steers `A_i` while `Λ` is driven by the `y`-term — is **unmeasured**.
  Four experiments named there would settle it; none is run.
- **Which tier is "lowest"** (`15-PSI-TIER-WHICH-LEVEL.md`): depends on replication
  and `n_trials`, not on the level's name. Experiment (2) — genuine `unit_obs`
  replication — is still open.
- **`extract_Sigma(part = "unique"/"psi")` returns an all-NA diagonal** where
  `total`/`shared` are finite. Filed, not fixed; different lane.
- **Overdispersed Poisson has no VA family code** — the one family that should carry
  both a unique and a link term. Gap, not defect.

## The two process lessons this arc paid for

1. **A comparison is only as good as its model match.** The 264× headline, and the
   Design 108 campaign this session refuted, were the *same error in two places*: arms
   fitted to different models, scored on one estimand. Check the model before the number.
2. **A gate passed on a favourable DGP is not a gate passed.** Claim 8 looked like the
   arc's success until claim 13 showed the DGP excluded the one regime where AC fails.
   **State the regime with the result, every time.**
