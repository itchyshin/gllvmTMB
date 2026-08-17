# Plan vs actual — categorical paper-alignment + degeneracy-detector arc (2026-08-17)

**Reconciler**: Melissa (plan-vs-actual, receipt-based, material deviations only)
**Plan**: `~/.claude/plans/for-ordered-cateogrical-structure-noble-parasol.md`, ARC 2
sections (lines 1-297: reshaped slice order PA1-PA5, execution log, original
detector header, slices S0-S5, review amendments 1-7)
**Actual**: worktree `/private/tmp/gllvmtmb-categorical-alignment`, branch
`claude/categorical-paper-alignment-20260817`, 28 commits over merge-base
`2b2e6568`; the pass-criteria files' own VERDICT blocks; the landed docs
(Design 123, register 35, NEWS, after-task, #897 closeout draft).
**Method**: every row below was re-derived from `git log`, `git diff`, and the
committed criteria/verdict files in this worktree. Nothing is taken from the
task brief on trust; where a receipt does not exist the row is classified
`unclear` rather than assumed.

Classification key — **adaptive**: a deviation the plan authorised, or one made
for a stated reason and disclosed on every surface it touches. **drift**: a
deviation from a frozen or gated commitment, or a planned deliverable absent
without a recorded decision. **unclear**: no receipt exists either way.

## Axis 1 — Scope

| # | Planned | Actual | Class |
|---|---|---|---|
| 1.1 | Arc 2 as a detector arc (S0-S5) | Reshaped mid-plan to lead with PA1-PA5 after Shinichi supplied the Mizuno paper; reshape written into the plan header itself | adaptive |
| 1.2 | PA1-PA4 build, PA5 flagged "IN or DEFER?" as Shinichi's call | PA1 `98b01cda`, PA2 `a50760a2`+`da3eb3f6`, PA3 `04a3af4b`, PA4 `78507518`/`7e931c79`/`6db3296d`/`f9fe7d3c` all landed; PA5 left open and named as a maintainer decision in after-task §10.10 | adaptive |
| 1.3 | S2 ordinal arms O1-O4, with O3/O4 shape "from S1" | Only O1/O2 built. S1 measured flat-row share exactly 0 on 24 of 24 degenerate fits, so the saturation arm has no empirical basis; O4 was likewise not pre-registered. Refusal recorded in `pass-criteria-ordinal.md` "Why these two arms and no others" | adaptive |
| 1.4 | S5: "print method DECLINED (documented bare-data.frame contract; follow-up issue)" | No landed record of either half — no bare-data.frame contract note and no follow-up issue in the after-task, Design 123 §8, or the #897 draft (grep returns nothing) | **drift** |
| 1.5 | Detection only; no estimator change; `aghq_ridge` untouched; no new export | `R/` footprint is `R/diagnose.R` + `R/extract-omega.R` only (the third R file in the raw diff, `R/predictive-diagnostics.R`, is a main-side change no branch commit touches). The single `aghq_ridge` occurrence in the diagnose diff is advisory action text, not a change to the ridge | adaptive |
| 1.6 | S5 close-out of #897 with the FPR disposition spun out | Close-out drafted at `docs/dev-log/issue-897-closeout-draft.md` against all three directives, explicitly NOT posted; the binomial re-calibration follow-up is named but not filed. Public GitHub acts left to the maintainer | adaptive |

## Axis 2 — Evidence / verification

| # | Planned | Actual | Class |
|---|---|---|---|
| 2.1 | Ordinal campaign ~900 fits, n in {100, 400, 1600}, healthy pool >= 500 (review amendment 4) | 315 fits at n = 100/400: `n = 1600` dropped and `n = 400` seeds halved for the D-139 budget. Healthy pool 217, so the rule-of-three FPR bound is ~1.4%, not the ~0.6% the amendment sought. Trim stated verbatim in the VERDICT block, NEWS, register FAM-14, and after-task §10.1 | adaptive |
| 2.2 | Multinomial: M1 >= 6/7, M2 >= 7/8, M3 3/3, 0 FP | M1 6/7, M2 8/8, M3 0/3 then 3/3 after the scope fix (`860a91c0`); 0 FP on 40 informative healthy fits with the s4 denominator honestly excluded (bound ~7.5%). Criteria frozen `f6552ee9` before verdict `6f34568e` | adaptive |
| 2.3 | Not planned | Out-of-sample evidence beyond plan: M1 7/7 flagged and 0/13 healthy on the diagonal-V cell the detector never saw; M2 0/20 on healthy rank-1 fits, closing statistical-review blocking amendment 2 empirically | adaptive |
| 2.4 | D-43 panel at arc close, verdict recorded, before any register claim | Three panel children ran in-session (`panel-adversarial`, `panel-claims`, `panel-code`); **no landed record of their verdicts anywhere**: the after-task has no D-43 or panel section, and `git log origin/main..HEAD -- docs/dev-log/check-log.md` is empty | **drift** |
| 2.5 | Each campaign analysed by its dispatched child | S3-mn and S1 were analysed by the orchestrator after those children parked early. Criteria were frozen in advance and artifacts committed (`dev/*/results/`), so both analyses are reproducible from the repo — but no second reader is on record for either verdict; couples to 2.4 | adaptive |
| 2.6 | S3: "binomial 25% FPR measured + diagnosed ONLY" | The 25% is **cited from #897**, not re-measured this arc. NEWS and the register attribute it correctly ("#897 point 2"); after-task §10.7 reads "is measured and diagnosed" without attribution — a wording ambiguity, not a claim in a user-facing surface | unclear |
| 2.7 | Per-slice named tests green (Arc 2 states no end-to-end clause of its own; the full-test + `--as-cran` clause at plan line 782 belongs to the archived Arc-1 block) | `devtools::document()` clean with no `man/` diff; `devtools::test(filter = "sanity or multinomial or ordinal")` 0 FAIL / 617 PASS / 1 pre-existing WARN; PA3 heavy run 5 cells 0 fail 0 skip. No full `devtools::test()` and no `--as-cran` at arc close | unclear |

## Axis 3 — Model routing

| # | Planned | Actual | Class |
|---|---|---|---|
| 3.1 | Arc 2 carries **no** slice/model table — "Solo platform: Claude (this session)". The routing table at plan lines 724-741 is Arc-1's, archived | ~17 dispatched children plus a 3-agent close panel. No plan baseline exists to reconcile the fan-out against | unclear |
| 3.2 | House routing (Sonnet default builders, Opus adversarial, Fable orchestration) | No in-repo receipt of model tier or effort for any child; the after-task records roles (Ada/Pat/Rose/Grace) but not tiers. Unverifiable from artifacts | unclear |
| 3.3 | Plan-review before build (Rose, statistical reviewer), amendments 1-7 adopted | `rose-plan-review`, `stats-plan-review`, `detector-plan-review` all ran before the build, and the amendments are traceable in the shipped artifacts: S1 re-profiles the inner Laplace at each scale, M2 fires only at rank >= 2, O2's span variant is gated on an untested circularity precondition and stays unwired | adaptive |

## Axis 4 — Safety gates

| # | Planned | Actual | Class |
|---|---|---|---|
| 4.1 | Fit-time warnings are a behaviour change requiring maintainer sign-off | Not wired for either family; stated on NEWS, Design 123 §8, and register FAM-14 / FAM-20 / DIA-08 (grep: 2 / 2 / 4 hits). Gate respected conservatively | adaptive |
| 4.2 | S3 thresholds are a maintainer gate; the ordinal pre-registration's own fallback is "ship-disarmed-and-document if unreachable" | The frozen conjunction failed at every threshold. This reconcile originally found the arms shipped **armed at 40** on the lane's own judgement, against the maintainer-gate fallback. **CORRECTED IN-LANE, 2026-08-17, after a D-43 panel:** the "armed at 40" verdict itself was scored with a per-fit relabelling never in the pre-registration; the frozen arm-level rule was restored, both arms failed it at every threshold tested, and they now ship **DISARMED at `Inf`/`Inf`** — the pre-registered fallback, as originally specified. See `dev/ordinal-degeneracy/pass-criteria-ordinal.md`'s correction notice | **drift (corrected in-lane; see closure note below)** |
| 4.3 | Pre-registration frozen before results, draft and results in separate commits | Held in all four campaigns: `e932cf37` to `b33d3b90` (S1), `f6552ee9` to `6f34568e` (S3-mn), `1925bc24` to `5e745dcd` (diagonal-V), `78507518`/`6db3296d` to `f9fe7d3c` (PA4) | adaptive |
| 4.4 | Frozen bands never widened after results | `sd_true = c(0.8, 0)` proved mathematically unrunnable (singular V, `chol` fails); substituted `c(0.8, 0.05)` as a dated amendment **below** an untouched frozen block, and the planted-zero rail gate stands as FAIL-as-scored with the "correlation over ~zero variance is undefined" reading attached rather than retro-fitted | adaptive |
| 4.5 | D-139: estimate before running; > 30 min needs a pre-run test and approval | Every campaign time-estimated from a timing fit; the one projection that breached 30 min (the three-n ordinal grid) was trimmed rather than run — see 2.1 for the cost | adaptive |
| 4.6 | Not planned | Near-miss disclosed in after-task §8: a `git stash pop` in a clean tree popped **another lane's** parked stash, leaving a conflicted `R/fit-multi.R`; reverted immediately, stash entry intact, nothing lost. Recorded as a standing lesson | adaptive |

## Axis 5 — Public claims

| # | Planned | Actual | Class |
|---|---|---|---|
| 5.1 | Diagnostic coverage only; no register status promotion | No new export, no `method=`; register FAM-14 and FAM-20 each state in-line that this is "NOT a status change" and after-task §7 says the same | adaptive |
| 5.2 | Report measured numbers, never a verified zero | NEWS (corrected 2026-08-17 after the D-43 panel) carries the frozen arm-level numbers — O2 100.0%/39.2% at threshold 6, down to 0.0%/0.0% at 250, both arms shipping disarmed, the failed 90%-sensitivity/zero-FP target, and no ordinal FPR bound (there is no default threshold to bound); the multinomial surfaces carry the ~7.5% bound with the excluded s4 denominator explained | adaptive |
| 5.3 | PA4 claim scoped by its own gates | Multinomial fenced to components-only (12/20 rails against a frozen > 6/20); no rho claim under a competing species tier | adaptive |
| 5.4 | FAM-20D caveat closed either way | Closed with a **negative** result: replication does not rescue the diagonal-V mode (7/20, identical to baseline), with the register instructed not to extrapolate the s1b full-rank pass | adaptive |
| 5.5 | Nothing posted publicly | Nothing posted; the #897 comment is a draft and no issue was closed or commented on | adaptive |

## Axis 6 — Handoff state

| # | Planned | Actual | Class |
|---|---|---|---|
| 6.1 | Lane fully pushed at close | 5 of 28 commits are unpushed: `07f69eaf`, `4b3772d9`, `a182b43c`, `aa151927`, `144e369b` — i.e. the entire docs/NEWS/register/after-task tail. The brief's "all pushed" is stale | **drift** |
| 6.2 | Slice PRs as the default landing shape | No PR exists for this branch (`gh pr list` empty), and the branch sits 21 commits behind `origin/main` (`93d1cc05`) with no rebase or merge | **drift** |
| 6.3 | Agent-to-agent handoffs go in the repo (PR comment or a directed line in `docs/dev-log/check-log.md`) | Neither exists: `check-log.md` is untouched by this branch and there is no PR to comment on | **drift** |
| 6.4 | After-task per protocol | `docs/dev-log/after-task/2026-08-17-categorical-paper-alignment-and-detector.md`, 387 lines, all required sections including 3a decisions, 5 tests-of-the-tests, 6 consistency audit, 8 what-did-not-go-smoothly, 10 limits, plus the three-item "Needs the maintainer" list | adaptive |
| 6.5 | Fence: do not touch `R/mspl*` or `test-mspl-*`; worktree clean | Respected — no branch commit touches either; `git status --porcelain` empty | adaptive |

## Counts

- **adaptive 22** · **drift 6** · **unclear 4** (32 rows)

## Drift routed to owners

| Item | Owner | Action |
|---|---|---|
| 4.2 — ordinal arms armed at 40 against the pre-registered ship-disarmed fallback, on a threshold decision the plan named a maintainer gate | **CLOSED — corrected in-lane, 2026-08-17** | No longer needs Shinichi's ratification. A D-43 panel found the "armed at 40" verdict was scored with a per-fit relabelling not in the pre-registration; the frozen arm-level rule was restored, no threshold clears it, and both arms now ship `Inf`/`Inf` — the pre-registered fallback itself, applied as originally specified. Nothing routed to the maintainer here |
| 4.2b — `pass-criteria-ordinal.md` header still reads "DRAFT — pending sign-off" while its arms ship | **CLOSED — corrected in-lane** | The header now reads "FROZEN pre-registration; scored 2026-08-17. NOT signed off as a shipping threshold — both arms ship DISARMED per its own fallback clause", consistent with the disarmed disposition |
| 2.4 — D-43 panel verdicts not landed anywhere | orchestrator (`main`) | Append the three panel verdicts (or an explicit "panel not required, no status promotion" note) to the after-task §4 before handover. As it stands the panel is unfalsifiable from the repo |
| 1.4 — S5's declined print method: no contract note, no follow-up issue | orchestrator (lane) | Either record the bare-data.frame contract decision in Design 123 §8, or strike the item from scope explicitly |
| 6.1 — 5 unpushed commits | orchestrator (`main`) | Push (this reconciler does not push per brief) |
| 6.2 / 6.3 — no PR, 21 commits behind main, no repo-side message-bus line | orchestrator (`main`) | Open the PR (or land the branch) and leave the directed line; until then the arc's evidence lives only in one worktree |

## Verdict

The substantive work of this arc tracks its plan closely, and every deviation
that changed a number is disclosed on the surface where the number appears —
the trimmed ordinal grid, the failed frozen conjunction, the components-only
multinomial claim, the diagonal-V negative result, and the honest 40-not-56
false-positive denominator all reached NEWS and the register in the same words
they have in the pre-registrations. Two of the six drift items were substantive
at the time this reconcile first ran. One is now **closed**: the ordinal arms
had been armed on the lane's own judgement after the pre-registration's
fallback said ship-disarmed, on a threshold decision the plan had reserved to
the maintainer — a D-43 panel caught the scoring error behind that arming
in-lane (a per-fit relabelling never in the frozen rule), the arms were
reverted to `Inf`/`Inf`, and no maintainer ratification is now pending (item
4.2 above). The other stands: the arc-close D-43 panel ran without leaving a
consolidated verdict record in the repo (beyond what the ordinal correction
itself now documents), which means the check designed to catch an over-claim
is still short its own receipt for the arc as a whole. The remaining four are
handoff hygiene: five unpushed commits, no PR, no message-bus line, and a
silently dropped S5 sub-item. None of them threatens a public claim — nothing
was posted, no export was added, and no register status moved — but together
they mean the arc is finished in a worktree rather than landed, and a reader
outside this session cannot yet see any of it.
