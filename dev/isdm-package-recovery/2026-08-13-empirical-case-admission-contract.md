# Shared empirical case admission contract — two-paper iSDM programme

**Status:** `CASE_SELECTION_ONLY`.  It authorises neither record-level download
nor empirical fitting.  It does not alter the retained Paper 1 spatial HOLD or
the terminal Paper 2 private STOP/HOLD.

## Provisional candidate

The leading candidate is **North American Breeding Bird Survey (BBS) plus
independently sourced GBIF bird occurrences**, at route/landscape resolution.

- BBS release: USGS, *North American Breeding Bird Survey dataset, 1966–2018,
  version 2018.0*; CC0.  It supplies standardised annual route surveys,
  protocol/observer/weather fields and start-point coordinates.
- GBIF: a versioned predicate download restricted to species-level `PRESENT`
  records in the chosen study window, with coordinate and issue filters; the
  eventual query must exclude BBS/eBird-derived publishers where provenance
  shows they overlap the survey source.

This is a case-selection lead, not an accepted data asset.  BBS locations are
route starts rather than exact stops, and annual revisits are not automatically
within-season replicated visits.  Therefore it may support source-only,
route-scale descriptive maps but cannot yet be assumed to match the current PA
cloglog observation law.

## Gate A — required receipt before download or use

The selected case must provide a signed, immutable packet with all items below.
Any missing item is a STOP, not a request to infer or manufacture the field.

| Domain | Required evidence |
| --- | --- |
| Authority | Dataset release/version, DOI or archive ID, access date, licence and redistribution/publication terms; versioned GBIF query and every publisher licence retained |
| Taxa | Target-taxon list, accepted backbone/version, source-neutral name/identifier crosswalk, and counted exclusion of unresolved names |
| Time and space | Study window, seasonal/bin rule, CRS, route/landscape grid, coordinate-uncertainty rule, land mask and covariate-time match |
| Survey events | Event-level IDs, route/cell, date/time, protocol, observer/method and measured effort/support; explicit evidence of what constitutes a distinct revisit |
| Covariates | Ecological `X` provenance, units, resolution and transformations; GBIF-only `B` sampling-process meaning, finite only on GBIF rows and structurally absent on surveys |
| Support diagnostics | Pre-fit source-overlap maps, taxa/cell counts, fixed-design rank, `X`--`B` confounding, and disconnected-support screen |
| Privacy | Sensitive-taxon/location assessment, approved aggregation/masking, restricted raw-data location, access list and retention/release plan |

## Claim fence

Before a later empirical model gate, the only permissible artefacts are
provenance tables and source-only QA maps labelled **observed sampling pattern**.
They are not ecology, suitability, occupancy, abundance, bias correction,
prediction, or validation.  Paper 2 may use only a source-geometry schematic;
it does not analyse the empirical case.

## Stop rules

Stop before download/use if a licence or privacy condition is unresolved; taxa,
space or time cannot be harmonised; survey effort is unknown; or the selected
case cannot supply a measured source-specific support.  Stop before fitting if
the chosen empirical observation law is not explicitly approved, if repeats are
pseudo-replicates, or if source support/covariates are disconnected or
rank-deficient.
