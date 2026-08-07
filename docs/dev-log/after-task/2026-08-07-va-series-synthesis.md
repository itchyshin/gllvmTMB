# After-task — VA series synthesis (G0=1, docs-only)

## Scope

Shinichi approved **G0=1**: durable docs-only synthesis of the 2026-08-07 VA
validation series working position. No fence, merge, Totoro, or R/src.

## Outcome

Locked working position in
`docs/dev-log/audits/2026-08-07-va-series-synthesis.md`:

- LA (+ named ridge if runaway) everyday default; MAP→select on unpenalised LA
- Binary: prefer probit; cloglog OK under LA; logit weak for abs Σ / JJ for VA logit
- NB2: VA-GH preferred for abs Σ at large n (~3× cost); LA for small-n/cost
- Most other families: LA when both clear; VA ≈ recovery, often much slower
- AGHQ: opt-in for binary σ/ρ; not “LA-GH”; not S1 abs winner
- Don’t pitch PoisG/AC/gllvm closed-VA collapse as Σ recovery
- Parked: #947, #948, multinomial VA later
- Honest “beat gllvm” mechanisms; no fence/Arc-1 merge/new campaign

Mission Control `next_safe_action` updated past G0=1. Ultra-plan + Melissa
receipt: `docs/dev-log/plan-actual/2026-08-07-va-series-synthesis.md`.

## Checks

- Cited audit paths under `docs/dev-log/audits/2026-08-07-va-*.md` resolved.
- Commit scoped to docs + vault MC status (no R/src/fence).
- Deliberately not run: package tests, Totoro, fence edits.

## Follow-up (next G0)

Stop / park; optional truncnb2+delta_ln only with go; or separate Arc-1
promotion/merge G0. Do not auto-campaign.
