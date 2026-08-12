# Spatial iSDM Stage 1: plan-versus-actual reconciliation

## Scope

The approved first tranche was limited to a fresh private design lane, retained
evidence receipt, external source map, two-field feasibility review, and ADEMP
information review.  Implementation, fit, smoke, Totoro, and public work were
deferred.

## Receipt

| Planned item | Actual evidence | Status |
| --- | --- | --- |
| Fresh Codex-only lane | `codex/isdm-spatial-information-design` from `dfb835d5` | met |
| Protected nonspatial evidence | Gate-A packet names all four HOLDs as immutable historical evidence | met |
| Grounded research | NotebookLM token check failed due DNS; primary-source fallback map retained | adaptive deviation, recorded |
| Two-field architecture review | Gauss feasibility audit retained | met |
| ADEMP information review | Curie information audit retained | met |
| Implementation / compute | none | correctly deferred |

## Material decision

The initial plan assumed separately declared spatial ranges and meshes.  Gauss
found that the current engine supports only a shared-range, shared-mesh,
intercept-plus-GBIF-indicator implementation.  The Gate-A packet was amended
to make shared-range selection explicit; a separate-range design is an
architecture HOLD rather than an implicit extension.  This is adaptive scope
correction, not a relaxation of evidence standards.

## Next gate

Shinichi must choose whether to approve the shared-range architecture for
private implementation or retain an architecture HOLD pending a new TMB
design.  No compute decision is pending until that choice is made.
