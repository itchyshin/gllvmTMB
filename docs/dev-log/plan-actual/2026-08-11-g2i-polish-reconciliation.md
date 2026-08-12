# G2i deterministic-polish plan-versus-actual reconciliation

| Planned requirement | Actual evidence | Status |
| --- | --- | --- |
| Fresh G2i continuation from G2h | branch starts at `88e32955`; candidate `a45411a7` | met |
| Preserve G2h/G2c holds | contract and result boundary retain both labels | met |
| Private same-objective repair only | internal marker, one candidate from raw outer vector, map/boundary checks | met |
| Compiled-unit validation and independent review | focused suite passes; Noether/Curie/Fisher reviews resolved all P1s | met |
| One fresh local replacement smoke | only `g2i-smoke-20260811-001`; full SHA-bound root | met |
| Retained raw/candidate, fit, profiles, decision, provenance | root includes all; final closure hashes terminal receipt and manifest | met |
| Recovery pre-run / Totoro campaign | none launched | preserved |
| Public/package/docs / Issue #953 | no public surface or issue change | preserved |

Adaptive deviation: the first invocation supplied an abbreviated SHA and was
rejected before root creation or optimizer entry.  The one valid full-SHA
invocation then ran once.  The terminal wrapper returned before profile
completion; direct process/artifact inspection established that the same child
continued and eventually wrote a complete receipt.  This is recorded rather
than treated as a second attempt.

The smoke earned `G2I_SMOKE_COMPLETE`, not recovery evidence.  S7 remains a
separate approval gate.
