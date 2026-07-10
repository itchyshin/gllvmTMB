# After-task: Arc E ground-truth triage + pure-R fix sweep

**Date:** 2026-07-09 · **Author:** Claude (Ada) · **Branch/PR:** `claude/arc-e-pureR-sweep` → [#741](https://github.com/itchyshin/gllvmTMB/pull/741) · **Base:** `main` @ `d6762956`

## Scope

Arc E (the capability-honesty sweep) was the ultra-plan's dominant unknown — estimated at ~45 real correctness/robustness bugs and 3–5 weeks. Before building anything, we ground-truthed **all 72 open Arc E / release issues** against `main` (the #588/#723/Arc-C "already-built" pattern demanded it), then landed the genuinely-open pure-R subset.

## Method

A background **ultracode workflow** (`arc-e-groundtruth`, 132 agents: one triage agent per issue + one adversarial verifier per already-fixed claim, ~8M tokens). Each triage agent read the issue via `gh`, ground-truthed the cited code on current `main`, checked for an asserting test, and classified verdict + fix-lane + size — **static analysis only, no live fits**. Every `already-fixed` verdict was then handed to a skeptic prompted to refute it; none were overturned.

## Outcome — the headline

| Verdict | Count |
|---------|------:|
| **already-fixed** on `main` (adversarially verified) | **60** |
| real-open, pure-R (Claude-lane) | 9 |
| real-open, docs | 3 |
| **total triaged** | **72** |

**60 of 72 (83%) were already fixed.** The "45 real bugs / 3–5 weeks" estimate was almost entirely stale. The genuine Arc E remainder is **12 issues, none needing a live TMB fit** — 9 pure-R, 3 docs.

## Landed this session — PR #741 (9 pure-R fixes)

All nine real-open pure-R issues, TDD-style, in three commits (julia-bridge guards / deprecation clarity / profile Sigma reconstruction). See the PR for the per-issue table and test results.

- **#593** (julia-bridge (binomial trials marshaling) — In the `if (isTRUE(units_are_rows))` block of gllvm_julia_fit() (R/julia-bridge.R ~2596), also transpose a matrix-valued
- **#629** (brms-sugar formula desugaring / scan_for) — Gate the spatial branch in scan_for_deprecated (R/brms-sugar.R:4025): emit the legacy-alias deprecation ONLY for legacy 
- **#640** (julia-bridge prediction alpha extractor) — Guard the ordinal zeroing with a non-empty check: `if (length(fam) > 0L && all(fam %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FA
- **#641** (julia-bridge Pearson residual variance () — In .gllvm_julia_residual_variance (R/julia-bridge.R:2316-2322) replace the global stop() with per-cell `var[!is.finite(v
- **#642** (julia-bridge (engine='julia') long-to-ma) — After computing ft/fu (line ~3617, before the pivot at 3629), add `if (anyDuplicated(cbind(as.integer(ft), as.integer(fu
- **#660** (julia-bridge confint extractor (confint.) — After `idx <- match(parm, payload$term)` in confint.gllvmTMB_julia (R/julia-bridge.R:3349), add `if (anyNA(idx)) stop("U
- **#662** (parser/deprecation (R/brms-sugar.R)) — Add a `see` field to each deprecated_map entry (e.g. "?phylo_latent" for phylo_rr, "?meta_V" for meta, "?spatial_indep" 
- **#696** (julia-bridge / mixed-family dispersion e) — In .gllvm_julia_dispersion_vector (R/julia-bridge.R:2227), replace the silent `rep(NA_real_, p)` fallback with a stop() 
- **#717** (profile-likelihood CI extractors (profil) — In profile_ci_correlation() target_fn (R/profile-derived.R:793-797), reconstruct the full per-trait Psi from the mapped 

## Open remainder — 3 docs issues (not yet landed)

| # | subsystem | what the doc fix is |
|---|-----------|---------------------|
| #486 | release / CRAN docs (roxygen man p | Rerun R CMD check --as-cran WITH the manual build on the release branch; if the PDF-manual WARNING recurs it is now the residual a |
| #680 | ordinal family / cross-package Jul | Document in ?ordinal_probit (and the Julia-bridge doc/NEWS) that gllvmTMB's ordinal_probit() is a probit threshold model (latent v |
| #697 | ordination / loadings extraction ( | Correct R/rotate-loadings.R:4 from "free-positive diagonal" to "free-signed diagonal" and note sign indeterminacy is resolved on d |

`#486` is the `--as-cran` punch list (an Arc A release task; overlaps `#483`/`#484`/`#485`). `#680`/`#697` are honest-surface doc corrections (ordinal-link divergence; the "free-positive" → "free-signed" loading-diagonal comment).

## Already-fixed close-list (60) — verified, ready to close/defer

Each was confirmed fixed on `main` (fixing commit or asserting test cited) and survived adversarial verification. **Recommend batch-closing with an evidence comment** (maintainer call — 60 outward-facing closes were held pending sign-off).

| # | subsystem | evidence (fixing commit / asserting test) |
|---|-----------|--------------------------------------------|
| #335 | missing-data | Feature/task issue (Phase 2a), not a bug. Fully implemented + tested on main. Impl: R/missing-predictor.R builds the Gaussian fixed-covariate model ta… |
| #355 | parser + TMB engine (grouping tier | Issue #355 is a feature (not a file:line bug): "parser + TMB engine for a 4th grouping slot beyond unit/unit_obs/cluster. Stop: before per-family vali… |
| #356 | recovery-validation / cluster2 gro | Not a code defect — a validation-slice tracking issue (Slice F of #342). Deliverable is committed on origin/main. tests/testthat/test-cluster2-familie… |
| #483 | julia-bridge / release (NAMESPACE  | The issue claimed the engine="julia" bridge exports were unregistered (grep -i julia NAMESPACE -> 0 lines; no man/*julia*.Rd). All false on main HEAD.… |
| #484 | release/cran | cran-comments.md now exists at package root (/Users/z3437171/Dropbox/Github Local/gllvmTMB/cran-comments.md, 70 lines) and contains all three componen… |
| #485 | docs/NEWS (engine="julia" GLLVM.jl | Issue premise `grep -ci julia NEWS.md` -> 0 is false on main (HEAD 8b27e387): 32 matches. NEWS.md:645-705 is a dedicated dev section `## R-side engine… |
| #582 | brms-sugar formula desugaring (par | Issue cited R/brms-sugar.R:3044 reading rank d by name only (d_val <- if("d" %in% nm) e[[which(nm=="d")]] else 1L), dropping positional d in spatial_l… |
| #586 | extractors (extract_correlations b | Cited defect is gone. R/extract-correlations.R:640-653 (bootstrap fallback branch) now directly computes out_rows <- .correlation_fisher_rows(R=R, pai… |
| #587 | extractors / extract_Omega covaria | FIXED on main. The proposed fix is already in place: R/extract-omega.R:225-231 calls extract_Sigma(fit, level = tier, part = "total", link_residual = … |
| #589 | weights normalisation / wide-matri | The exact defect described (na_mask = NULL passed in include mode, masked NA weights flowing into validation) is no longer present. R/gllvmTMB-wide.R:… |
| #590 | formula parsing / covstruct detect | The exact bug described (detect_covstruct_terms flagging exp() covariate transforms as unsupported covstructs) is already guarded on main. In R/gllvmT… |
| #596 | simulate/bootstrap (unconditional  | Fixed by commit 37f98fee "Fix propto simulation lambda scaling" (2026-07-05), after the issue was filed (2026-07-02). Current main: R/methods-gllvmTMB… |
| #604 | wide-format traits() keyword parse | R/traits-keyword.R:217-219 now lists "animal_scalar", "animal_unique", "animal_slope" in .traits_covstruct_keywords, so the pass-through branch at R/t… |
| #605 | confint / loading-CI (Lambda profi | The issue's cited line (R/z-confint-gllvmTMB.R:307) no longer holds the defect; the full-grid profile branch (parm=="Lambda", is.null(entries)) is now… |
| #606 | confint / Sigma CI | R/z-confint-gllvmTMB.R:1911 now defines .confint_sigma_profile(object, parm, level, nsim, seed) with the two params the issue said were missing; lines… |
| #608 | brms-sugar / augmented ordinary la | Fixed on origin/main (commit aec8df92 "feat(latent): augmented unique= opt-out (#608)"). R/brms-sugar.R:2997-3045 now reads BOTH `unique` and `residua… |
| #610 | mixed-family dispatch (multivariat | Fixed by commit eaccd299 ("Fix mixed-family named dispatch", 2026-07-04), an ancestor of origin/main; issue was filed 2026-07-02. R/fit-multi.R:55-84 … |
| #611 | phylogenetic-engine / sparse A-inv | The buggy tree-path line the issue cites (`log_det_A_phy_rr <- -sum(log(inv$dii))` via MCMCglmm inverseA at old R/fit-multi.R:2379) no longer exists; … |
| #612 | phylo/animal-model sparse Ainv eng | Defect no longer present on main (d6762956). Both sparse branches route through helpers that handle the extra-node (superset) case correctly. (1) Spar… |
| #614 | predict/extractors (per-row invers | R/methods-gllvmTMB.R:268 now has signature `.apply_linkinv_per_row(eta, family_id, link_id, sigma_eps = NULL)`, and the lognormal branch at R/methods-… |
| #615 | output-methods / variance-partitio | Fixed after filing (issue 2026-07-02; fix commit 0c0486cc "Fix VP non-Gaussian residual shares" 2026-07-04, confirmed ancestor of HEAD). R/output-meth… |
| #620 | confint / Sigma Wald CI (R/z-confi | R/z-confint-gllvmTMB.R:1885-1889 now guards the Wald Sigma path: `rr_used <- .sigma_info_rr_used(object, info); diag_used <- .sigma_info_diag_used(obj… |
| #621 | confint / Sigma Wald CI | The defect described (Wald path unconditionally fills diagonal CIs from theta_diag_<tier> = Psi-only, while the estimate is total variance) is no long… |
| #622 | TMB engine / response families (Ga | The issue's cited lines (cpp:1919/426/224) are stale; the Gamma family was re-parameterized to the exact proposed fix. src/gllvmTMB.cpp:606 declares P… |
| #625 | brms-sugar LHS classifier (phylo_d | The proposed fix is already implemented on main (HEAD, R/brms-sugar.R). A dedup guard `.assert_distinct_slope_cols()` at R/brms-sugar.R:1802-1814 does… |
| #626 | brms-sugar parser / augmented-LHS  | Fix already live: R/brms-sugar.R:1944 reads `lhs <- .strip_lhs_parens(bar[[2L]])` (the issue's exact proposed fix), and the comment at lines 1948-1950… |
| #627 | brms-sugar spatial formula orienta | Guard now present at R/brms-sugar.R:2055-2063 (function moved from cited :1873 to :1971): the `is.name(lhs) && is.name(rhs)` branch first checks `!ide… |
| #628 | meta-analysis brms-sugar parser (. | The cited match.arg call is gone. R/brms-sugar.R:2236-2242 (in .meta_type) now does the issue's exact proposed fix: `if (!type_expr %in% c("exact","pr… |
| #631 | extract-correlations / Fisher-z CI | The magic-30 fallback the issue cites is gone. On main, R/extract-correlations.R:21-31 replaces it: when the automatic effective N is NULL or <4L it c… |
| #632 | extractors (extract_Omega / covari | The exact proposed guard is present and committed on main. R/extract-omega.R:236-254 does `sigma <- out$Sigma; if (!is.matrix(sigma) || length(dim(sig… |
| #634 | R/fit-multi.R weights/n_trials dis | Current main already implements the issue's exact proposed fix. R/fit-multi.R:1919 `has_binom <- any(family_id_vec %in% c(1L, 8L))` (includes beta-bin… |
| #635 | fit-multi / start-value initializa | The defective inline expression cited at R/fit-multi.R:2087 (`log(max(stats::sd(resid_init), 1e-3))`) no longer exists. It was extracted into a helper… |
| #636 | fit-multi phylogenetic propto spar | Cited inline defect (Ainv_sub <- phylo_vcv[levs, levs]; Cphy_inv <- as.matrix(Ainv_sub)) is gone. R/fit-multi.R:2846 now calls helper .resolve_sparse_… |
| #643 | kernel-helpers / coevolution profi | R/kernel-helpers.R:239 already reads `best <- which(ok)[which.max(out$logLik[ok])]` — the exact tie-breaking fix the issue proposes, guaranteeing scal… |
| #645 | predict.gllvmTMB_multi / newdata f | Cited positional slice `eta <- X_new %*% bfix[seq_len(ncol(X_new))]` no longer exists. On main (HEAD 8b27e387), R/methods-gllvmTMB.R:1491-1498 routes … |
| #653 | profile-derived CI curve inversion | The exact buggy line the issue cites is gone from main. R/profile-derived-curves.R:268-272 now reads: `sub_dv <- dv[idx]; finite <- is.finite(sub_pv) … |
| #654 | profile/derived-quantity CIs (phyl | The exact defect is gone on main (HEAD 8b27e387). profile_ci_phylo_signal()'s 3+ component fallback no longer returns NA bounds: R/profile-derived.R:2… |
| #658 | TMB C++ likelihood engine (probabi | All three cited AD-unsafe ternary clips have been replaced with CppAD CondExp-based clamping, and a regression test asserts it. (a) The AD-safe helper… |
| #659 | fit-multi / family validation | The proposed positivity guard already exists on main at R/fit-multi.R:2235-2245: `positive_rows <- (family_id_vec %in% c(3L, 4L)) & !masked_response; … |
| #664 | extractors / Sigma tables (R/extra | R/extract-sigma-table.R:406-411 forces `table_entries <- "diag"` when part == "unique" (line 410), passed as entries= to .sigma_table_from_matrix() at… |
| #668 | profile-derived / communality CI e | Both cited sites now use the correct wrapped-vector form on origin/main. R/profile-derived.R:555-558: cli::cli_abort(c("Communality profiling requires… |
| #670 | extractors / correlation CIs (R/ex | The defect (per-tier bootstrap_Sigma() call inside the for-loop) is gone. On main, bootstrap_Sigma() is called ONCE, hoisted before the loop at R/extr… |
| #672 | fit-multi (fixed-effect design set | Issue cites dead `has_int <- "(Intercept)" %in% colnames(X_fix)` + misleading "Strip an unwanted (Intercept) column" comment at R/fit-multi.R:1545 (fi… |
| #673 | fit-multi / SPDE setup | Issue flagged `A_proj <- Matrix::sparseMatrix(i = 1:1, j = 1:1, x = 0, dims = c(n_obs, n_mesh))` immediately overwritten by `A_proj <- mesh$A_st`. Com… |
| #674 | fit-multi / start-parameter reclam | R/fit-multi.R:4800 (function .gllvmTMB_reclamp_start_par, def at 4797) now reads `phi <- grepl("(^|\\.)log_phi", nm)` — exactly the issue's proposed f… |
| #676 | R/enum.R internal family/link id m | Real at file-time: at commit 7bb8a446 (main on 2026-07-02) R/enum.R was verbatim sdmTMB make_enum output ("Generated by sdmTMB: do not edit by hand") … |
| #677 | extractors (R/extract-omega.R phyl | The scalar `sum(V_eta) > 0` guard the issue describes no longer exists (grep "sum(V_eta)" over R/ finds nothing). It was replaced by commit 3652e604 "… |
| #678 | predict.gllvmTMB_multi mixed-famil | The flagged `as.integer(stats::median(fid_vec[rows_t]))` code no longer exists. R/methods-gllvmTMB.R:1598-1605 now builds per-trait family/link ids vi… |
| #679 | profile-derived-curves (CI inversi | Fixed by commit c37eea34 "Fix profile-derived curve baseline" (2026-07-04), two days after the issue was filed (2026-07-02). (1) R/profile-derived-cur… |
| #682 | extractors (extract_Sigma / extrac | Both cited sites now route through the shared helper .safe_cov2cor() at R/extract-sigma.R:13-28, which implements the issue's exact proposed fix: `ok … |
| #683 | R/extractors.R (extract_ICC_site / | The defect described (R/extractors.R:111 `icc <- vB / (vB + vW)` producing NaN when vB+vW=0) is gone. Line 111 now calls a guarded helper: `icc <- .sa… |
| #684 | fit-multi / multi-start optimizer  | R/fit-multi.R:4386 now reads `if (success_i && objective_i < best_obj)` where success_i <- is.finite(objective_i) (L4367); the && short-circuits so a … |
| #685 | multi-start restart selection (R/f | Both defects the issue describes are fixed on main (HEAD 8b27e387). (1) best_opt is now guarded by finiteness: R/fit-multi.R:4386 `if (success_i && ob… |
| #686 | kernel separability diagnostic (co | Issue claims diagnose_kernel_separability() compares kernels positionally (.kernel_pair_similarity reads off-diagonal cells by index) without aligning… |
| #687 | loading-ci-bootstrap (Lambda perce | Issue asked to floor scale_guard with an absolute_floor and make the multiplier a documented arg. main implements exactly that: R/loading-ci-bootstrap… |
| #693 | predictive-diagnostics (rootogram) | Fixed by commit c7d526a1 "Cap automatic rootogram count bins" (2026-07-04, after the 2026-07-02 filing). The uncapped max() was replaced by helper .gl… |
| #695 | confint / Lambda loading intervals | Fixed by commit 0b95b1a6 "Guard pinned Lambda selected profiles" (2026-07-05, ancestor of HEAD d6762956). R/z-confint-gllvmTMB.R:449-456 now detects p… |
| #702 | plot / correlation interval metada | The issue's exact proposed fix is present on main at R/plot-gllvmTMB.R:488 — `tab$interval_method[!has_hit] <- "missing"` — inside .correlation_merge_… |
| #703 | plot / ordination extractors | Fixed by commit 64d8a47d1 (2026-07-04, after issue filed 2026-07-02; after-task doc named 2026-07-04-consolidation-cleanup-issues-703-704.md). On curr… |
| #704 | profile CI / derived-quantity cons | Issue flagged that R/profile-derived.R called nlminb with no gradient arg despite a comment claiming analytic-gradient use. Commit 4c22b721 (ancestor … |

## Checks

- `test-julia-bridge` PASS 558/0 (+19 live-Julia skips); `test-scan-deprecated-namespace` PASS 10/0; `test-profile-mapped-diag` PASS 4/0; broad regression (canonical-keywords, profile-derived-curves/refit, fisher-z, spatial-*) PASS 121/0. R-only fixes reuse the prebuilt `.so`.
- No likelihood / family / parser-grammar change; no NAMESPACE/man change (only an internal helper added).

## Follow-up

1. **Maintainer:** approve batch-closing the 60 already-fixed issues (list above), and review PR #741.
2. Land the 3 docs fixes (#486 folds into the Arc A CRAN punch list).
3. **Arc A release mechanics** are now the critical path: register/lifecycle honesty, `cran-comments` refresh, NEWS, and the `0.2.0 → 1.0.0` bump (bump gated on maintainer OK).
4. The same latent recycle pattern as #717 exists in `.proportion_target_fn` / `profile_ci_communality` (out of scope for #717) — a candidate follow-up.
