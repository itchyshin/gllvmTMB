# Session Handoff: G3P Gate-B request ready

The reviewed V2 runner baseline is `fdcb05cd`; the current branch records its
reviewed Gate-B-request readiness. The V2 proposal remains design-only. V1 is
immutable `INVALID_PROVENANCE`.

Next action requires maintainer approval: create only the exact V2 packet and
its ignored root, bound to `fdcb05cd`. Do not invoke `validate`, `preflight`,
or `smoke`. A later preflight needs separate explicit approval, and exactly one
smoke needs another explicit approval with a fresh 15–25 minute estimate and a
25-minute hard stop.
