GOAL: see GOAL.md.   STATE: **S6 FROZEN (option B)** — post-`#949` `main` integrated; re-verify green; freeze tip locked. **PAUSE before S7.**
ARCS DONE (verified):
- S0 — vault D-89 Path A amend + D-66 upload-identity note + AGENT_LOG
- S1 — RECON `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-s1-recon.md`
- S2 — DESCRIPTION/zzz narrow `profile_ci_total_variance` regime; AGHQ “fixed 9-node”
- S3 — Version `0.6.1` in DESCRIPTION, NEWS, CITATION, README, `_pkgdown.yml` comments
- S4 — `cran-comments.md` rewritten for 0.6.1; platform rows TBD; still `.Rbuildignore`d
- S5 — `pkgdown::check_pkgdown()` “No problems found.”
- S6 — Shinichi GO on **option B** (rebuild freeze from post-`#949` `main`)
- S6B — `git merge origin/main` (`d7bee2fa` `#949` squash); **no conflicts**; Path A `0.6.1` + honesty kept; Arc-1 VA landed; Rose scan clean; pkgdown OK; fence tests 57+33 PASS
ARC IN PROGRESS: none (S6 closed). **NEXT = S7** (exact-tag) — **OPEN GATE / PAUSE**
OPEN GATES (need human): **S7 exact-tag handoff** — do not cut RC/final tags or upload until fresh-chat GO; M5-g remains Shinichi only
TRUTH LIVES IN: `/private/tmp/gllvmtmb-cran-path-a-0.6.1` · `cursor/cran-path-a-0.6.1-20260807` · packet `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-s6-freeze-packet.md` · LOOP `lanes/gllvmtmb-cran-path-a-0.6.1/LOOP/`
FREEZE SHA: tip of this branch when clean — authoritative `git rev-parse HEAD` after S6B lock push (do not trust a stale embedded SHA in an older commit)
RESUME: You are gllvmTMB-cran-path-a-0.6.1 — Path A → submit-ready 0.6.1. **S6 FROZEN.** RESUME at S7 exact-tag only on maintainer GO (fresh chat).
READ FIRST: LOOP/GOAL.md → checkpoint.md → ultra-plan.md → AGENTS.md → s6-freeze-packet.md.
WORKSPACE: /private/tmp/gllvmtmb-cran-path-a-0.6.1 (reattach+pull; do NOT recreate; do NOT touch VA merge-fence).
CONTINUE FROM: S7 exact-tag ceremony only after GO; hand off Codex for heavy checks. Never M5-g upload. Do not patch inside M5. Do not invent soft-PASS Arc-2.
