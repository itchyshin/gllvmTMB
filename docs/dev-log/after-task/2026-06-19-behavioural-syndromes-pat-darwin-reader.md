# Behavioural Syndromes Pat/Darwin Reader Cleanup

Date: 2026-06-19 00:45 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closed the narrow Pat/Darwin reader cleanup blocker for the internal
`behavioural-syndromes` candidate worked example. It did not promote the
article to public navigation.

## Changes

- Updated the internal gate so it no longer says Florence review is pending.
- Removed the unused `library(dplyr)` attach from the article setup chunk.
- Replaced the unsupported `Dingemanse et al. 2002` aside with citations already
  present in the article reference list.
- Softened simulated-example interpretation from "genuine syndrome" language to
  fitted variation and expected behavioural-syndrome structure.
- Updated the article-council ledger and dashboard surfaces to show that final
  rendered-HTML review remains the blocker.

## Verification

- The article rebuilt after the Pat/Darwin cleanup and again after the final
  gate wording correction.
- Stale blocker wording scans were clean after the final pass.
- Rendered-asset review passed on the generated HTML: gate text, diagnostic
  PASS rows, no stale citation/dependency/overclaim wording, and five nonempty
  PNG assets.
- Quick Look produced a top-page thumbnail with readable navbar, H1, internal
  gate, and opening biological prose.
- A true browser scroll-through remains blocked because the in-app browser was
  unavailable and Playwright's Chromium binary was missing.

## Definition of Done Notes

- Implementation: source and status wording updated locally only.
- Simulation recovery: not applicable; this was article prose cleanup.
- Documentation: article source and dev-log surfaces updated.
- Runnable example: unchanged; the existing article fit path remains runnable.
- Check-log: this after-task report is paired with the 2026-06-19 00:45 MDT
  check-log entry.
- Review pass: Pat/Darwin cleanup plus partial rendered-asset review; true
  browser scroll-through remains.

## Still Not Claimed

- No public promotion.
- No release readiness.
- No bridge completion.
- No scientific coverage completion.
