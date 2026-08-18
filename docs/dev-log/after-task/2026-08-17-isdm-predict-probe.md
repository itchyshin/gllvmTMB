# After-task — iSDM OWED-1: the predict() probe, certified core, scoped gap

Date: 2026-08-17 · Platform: Claude · Lane: `claude/isdm-predict-20260817`
Plan: `~/.claude/plans/read-agents-md-and-docs-dev-log-handover-steady-nebula.md`
(ultra-plan; approved by Shinichi). Handover executed:
`docs/dev-log/handover/2026-08-17-claude-handover-isdm-next.md` (merged as
[#1113](https://github.com/itchyshin/gllvmTMB/pull/1113) by this lane).

## Scope

The maintainer-ranked OWED list, and nothing else: (1) the prediction-maps
probe, run to its prescribed fork (certify what holds, scope what doesn't);
(2) the calibrated-uncertainty campaign advanced exactly to its D-139 gate (a
proposal document, nothing launched); (3) the real-data flagship advanced to
a candidate list for Shinichi's pick. The Ayumi #23/#24/#25 programme was
explicitly fenced out (its own lane, PR #1106); the single overlap —
`fitted()` wraps in-sample `predict()` — is served by the probe notes.

## Outcome

**The probe's verdict is mixed, and the fork was taken accordingly.**

Certified (tests, 15 assertions, 0 failures — `test-isdm-predict.R`):
in-sample `predict()` returns `report$eta` exactly (offset + all REs, SPDE
included); `type = "response"` dispatches each row's own arm inverse link;
the non-spatial `newdata` round-trip is exact; `re_form = ~0` and the
unseen-unit fallback behave as documented; in-sample `se.fit` works and
`newdata` + `se.fit` refuses with a classed error.

Not defensible — scoped, not patched (Design 126 + register ISDM-03):
1. 🔴 On spatial fits `predict(newdata=)` silently drops the SPDE field even
   at training locations (measured: dropped-piece sd 0.381 vs eta sd 0.949;
   cor(−diff, true field) 0.82; `~.` ≡ `~0` on a pure-spatial fit) while
   printing a message implying REs were added. Affects all spatial
   `gllvmTMB_multi` fits, not just isdm.
2. 🔴 `re_form = NA` includes REs though the roxygen documents it as
   fixed-only (`~0`-equivalent).
3. No `A_proj` projection at new locations — fine-grid maps are unreachable
   through `predict()`.

**The map-making article is therefore fenced** (it would map a surface that
drops the field it claims to map). Draft issue texts are in Design 126 §5,
to be filed after maintainer review.

## Checks

- `testthat::test_file("tests/testthat/test-isdm-predict.R")`: 15 pass /
  0 fail / 0 skip.
- Probe reproducible: `dev/isdm-predict-probe/probe.R` (seeds 7/23), output
  captured in `probe-output.txt`; all `PROBE[..]` lines cited in
  `findings.md` and Design 126.
- <MECHANICAL-VERIFY + full test-suite results: filled at close>

## Definition-of-done accounting (the six items)

1. Implementation — N/A by design: this lane changes no `R/`/`src/` code
   (probe + tests + docs only; fixes are maintainer-gated follow-ups).
2. Simulation recovery test — N/A: no new likelihood/family/keyword;
   the certification tests pin existing predict() behaviour.
3. Documentation — Design 126 + register row ISDM-03; no roxygen touched
   (the `re_form = NA` roxygen defect is deliberately left for the fix PR so
   docs and code change together).
4. Runnable user-facing example — deliberately withheld: the reader-facing
   map example is exactly what the probe found cannot yet be honest.
5. check-log entry — `docs/dev-log/check-log.md` (this date).
6. Review pass — Curie (test fidelity, producer); Gauss+Rose lens via the
   Opus adversarial verifier; Fisher lens on the campaign proposal;
   <verdicts recorded at close>.

## Companion deliverables (OWED-2, OWED-3)

- `docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md` —
  the D-139 gate artifact: estimands, design sketch, pre-run test, estimate.
  🔴 **Needs Shinichi: approval (or rejection) before anything runs.**
- `docs/dev-log/research/2026-08-17-isdm-flagship-candidates.md` — four
  candidates, all UNVERIFIED. 🔴 **Needs Shinichi: the taxon pick.**

## Follow-ups

- File Design 126 §5 issues A (spatial-newdata drop + `re_form = NA`) and
  B (map API) after maintainer review of this PR.
- The predict-semantics notes feed the Ayumi #25 `fitted.gllvmTMB_multi()`
  fix (that lane's work, not this one's).
- Deferred menu unchanged (carried in the handover; nothing dropped).
