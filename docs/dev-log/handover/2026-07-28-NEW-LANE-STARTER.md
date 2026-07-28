# New-lane starter — gllvmTMB, after the AGHQ close-out arc (2026-07-28)

Paste the block in §1 into a fresh Claude session and it will be fully oriented. Everything
below it is the *conversation* context a git log cannot carry: what Shinichi asked for, what he
corrected, and how he works. Read §3 before you form any confident opinion.

---

## 1 · Copy-paste this to open the lane

```
You are opening a NEW LANE on gllvmTMB, following the AGHQ close-out arc of 2026-07-28.

REHYDRATE IN THIS ORDER:
  1. docs/dev-log/handover/2026-07-28-claude-handover-aghq-closeout.md  — §2 FIRST: four
     figures from that arc are RETRACTED or STALE and citing them will make you wrong.
  2. docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md — the plan, 11 h, 10
     slices, Phase 0.25 receipt already complete, two decisions already locked.
     SHINICHI'S INSTRUCTION: this lane REFINES the ultra-plan and then RUNS it. It is a
     starting point, not a frozen contract — re-open Phase 0.4 with him, re-check the slice
     order against what S2/S3/S4 actually return, and rebalance after each batch (Phase 3.5).
     What is NOT open to refinement: the two locked decisions (§ below), the discipline list,
     and the D-43 gate. Everything else is yours to sharpen with him.
  3. docs/dev-log/decisions.md — the 2026-07-28 entries. The LAST FOUR are corrections and
     retractions; read them before the earlier ones or you will believe things that were
     withdrawn.
  4. docs/dev-log/handover/2026-07-25-active-lane-split.md — the lane map. Do not narrow it.

WORKTREE /private/tmp/gllvmtmb-arc0-identifiability, branch claude/aghq-engine-20260728,
PR #801 OPEN — DO NOT MERGE. 52 commits, pushed, clean.

THE JOB: extend gllvmTMB's CERTIFIED profile interval route to LOW-RANK Sigma = Lambda Lambda'.
The package has exactly one coverage-certified interval — the Gaussian Sigma_unit DIAGONAL
profile — but R/profile-route-matrix.R:631 says low-rank total Sigma FALLS BACK TO BOOTSTRAP,
which was ruled the wrong route on 2026-07-18. AGHQ forces unique = FALSE, so every AGHQ fit is
low-rank and the whole previous arc measured through that fallback. Fix S5 (the Self-Liang
defect at R/profile-ci.R:32) BEFORE S6, or the extension inherits it.

DECIDED, do not re-litigate: instrument before multinomial; A1/A3 superseded with the reversal
to be RECORDED explicitly in decisions.md, not assumed.

DISCIPLINE, all paid for in blood last arc:
  * QUERY THE BRAIN BEFORE BUILDING. Use /ask-brain or the shinichi-brain MCP with
    search_all_projects: true. Last arc built an instrument, ran two campaigns and convened two
    panels; the conventions, the literature and the prior attempt all already existed.
  * COMPUTE EVERY GATE YOU PRE-REGISTER. Last arc wrote one into its own script and skipped it;
    a panel computed it and it failed in 45 of 48 cells.
  * n_sim >= 2000 for adjudication. ~200 is PILOT ONLY (Design 66 §7). Say "pilot" in the same
    sentence if you run fewer.
  * FIXED TRUTH PER CELL is the house standard (m3_sample_truth), not an innovation.
  * Report the FIT-HEALTH DENOMINATOR, never complete-case coverage alone.
  * After ANY engine edit, re-run every measurement that engine produced — not only the
    Gaussian-exactness invariant, which is insensitive to most changes.
  * Compute on Totoro (~10x faster/fit; branch installed at ~/h4_work/aghq-lib), cap 150 cores.
    Local cap 6-8 — Codex shares the laptop.
  * Verify R jobs with `ps aux | grep exec/R`, NEVER `pgrep -f Rscript` (reports 0 for healthy
    R jobs).
  * D-43 panel (2 build + 1 ceiling, default NOT-DONE) before any claim, and record whatever it
    returns — including NOT-DONE.

FIRST ACTION: open docs/dev-log/capability-surface.html and show it to Shinichi (CLAUDE.md
step 0), then read the four documents above.
```

---

## 2 · What Shinichi asked for, in his own framing

* **Multinomial AGHQ is the standing ask** — "close this arc, then implement multinomial in
  the next one — please remember." It is **sequenced second**, by his own later decision, once
  the instrument works. It needs **less** work than first thought (the K−1 pseudo-trait path
  already exists, no new C++) but has an **unsolved precondition**: the multinomial latent
  scale is non-identified and must be fixed by convention, and quadrature over that same latent
  interacts with it.
* **"We need to find tricks — combinations of tricks — to prepare the best algorithm for our
  users."** That is the actual north star. Not "is AGHQ good" but "what routing gives users the
  best answer in their regime." The routing map is in `decisions.md` (2026-07-28, the O(1/T)
  entry).
* **Ranga / NotebookLM** — he raised this himself. It is **S2** in the plan, deliberately
  narrowed: the small-sample-VC literature is already in NotebookLM `3b3d2ec5`, so ask only the
  genuinely open question — *does anyone profile a reduced-rank covariance, and what happens
  under rotational non-identifiability (Σ identified, Λ not)?*
* **Codex review** — also his idea, and a good one. Three panels reviewed *claims*; nobody has
  reviewed the *code*. A review was dispatched (`task-ms52uh0u-4mcgsc`) and **never collected**.
  Worth doing.

---

## 3 · 🔴 The three corrections he made, and why they matter more than the code

He caught the previous session being wrong three times. Each was the same error, and it is the
error most likely to recur.

1. **"profile??"** — I had claimed gllvmTMB has no trustworthy Σ interval, from two true
   premises (`REPORT` not `ADREPORT`; `confint()` NA on reduced rank) and an invalid inference.
   **A validated profile route exists.** `CROSS-REPO-GUARDS`: *a negative probe cannot prove
   absence.* To check a capability is present, USE it or read its vignette.
2. **"at least for LA we did check??"** — yes. The Gaussian `Sigma_unit` diagonal profile at
   n≥150, d≤2 is simulation-validated at ~0.946–0.948. That narrowed the real gap from "no
   interval" to "low-rank Σ specifically", and made the next arc cheaper.
3. **"remember /ask-brain — you use Shinichi's second brain!!"** — the sweep that followed
   found the coverage conventions, the z-vs-t rule *with an issue number* (gllvmTMB#565), the
   Self–Liang profile defect (D-12), a `TMB::checkConsistency()` wrapper already in the
   package, and the paper predicting the arc's "flat likelihood" finding. **Querying should be
   a reflex, not something he has to ask for.**

He also asked, reasonably: *"you are good and you are making so many wrong predictions —
puzzled."* The honest diagnosis, which is worth carrying: **every wrong call had a correct
theory and a broken mechanism predicting the same number, and the agreement stopped the
checking.** Poisson's "null control" (AGHQ wasn't running), the complete-case coverage, nominal
coverage, and the 0.023 defect. The fourth was *unfavourable* to AGHQ and dissolved anyway —
so being unflattering is not a proxy for being rigorous.

---

## 4 · How he works — observed, not assumed

* **He interjects mid-turn with short, sharp questions.** They are usually right and usually
  point at something load-bearing. Treat "profile??" as a finding, not an aside.
* **He wants the honest answer, including negative ones.** He said explicitly that a
  pre-registered negative is "more valuable than a confirmation." Two panels returned NOT-DONE
  and he never once pushed to soften them.
* **He corrects the process, not just the output** — he changed the session *goal* when it was
  shaped so that an honest negative counted as failure. If a goal presupposes its own answer,
  say so and propose the fix: **make the deliverable the measurement, not the result.**
* **He runs multiple lanes and sometimes both platforms.** Never assume sole ownership; surface
  overlaps rather than resolving them. Ownership is his call.
* **He asks for the capability widget** (`docs/dev-log/capability-surface.html`, artifact
  `46e611f2-69d1-48e1-8b8b-ccab2e89983d`) as step 0, and for mission control to be kept current.
  Both were updated this arc; the Engine column now discloses AGHQ honestly.

---

## 5 · Loose ends that are HIS call, not an agent's

1. **Merge order.** `claude/aghq-family-axis-20260728` (`/private/tmp/gllvmtmb-family-axis`,
   1 commit ahead) **conflicts with this branch on `docs/dev-log/decisions.md`** — both append.
   The findings are compatible; the merge order is his.
2. **PR #801.** Two panels withheld the claim. The branch is safe where it sits (nothing
   exported, NAMESPACE untouched, default unchanged). **Merging is his decision, never a goal
   state.**
3. **An orphan note**, uncommitted in the MAIN worktree:
   `docs/dev-log/2026-07-22-quadrature-regime-trap-and-the-correlation-boundary-gap.md`. It
   holds the Rabe-Hesketh / Liu–Pierce regime analysis that *predicts* the arc's flat-likelihood
   finding. S1 lands it.
4. **Alex Stringer** (Waterloo, AGHQ specialist) is named in a 2026-07-28 Bolker brief as a
   possible advisory contact. **He has NOT agreed to anything.** Do not cite him as involved.

---

## 6 · One paragraph of state, if you read nothing else

AGHQ is built, opt-in, default unchanged, nothing exported. Its **integral is correct** — 1.2e-09
against an independent oracle at a fixed parameter point, monotone in k, regression-tested at
1504 passing assertions. Four engine bugs were found and fixed. **Its capability claim is
withheld by two D-43 panels**, both times on the measuring instrument rather than the engine.
The next job is that instrument: extend the certified profile route to low-rank Σ, fix the
Self–Liang reference first, then multinomial. Nothing is promoted, nothing is merged, and every
retracted number is listed in §2 of the main handover so you do not repeat them.

> **Query the brain before building. Compute the gate you wrote. A result that confirms your
> prediction is where the mechanism check is most needed, not least.**
