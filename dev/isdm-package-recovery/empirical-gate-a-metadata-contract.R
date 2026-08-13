## Metadata-only Paper 1 empirical Gate A. No row-level data is read or requested.

empirical_gate_a_required <- c(
  "bbs_release", "bbs_doi", "bbs_licence", "gbif_predicate", "gbif_download_key_or_doi",
  "publisher_licence_audit", "taxon_crosswalk", "season_rule", "crs_and_unit",
  "survey_event_revisit", "support_and_mask", "covariate_provenance",
  "privacy_review", "observation_law_decision"
)

empirical_gate_a_template <- function() {
  data.frame(
    field = empirical_gate_a_required,
    status = c("VERIFIED_METADATA", "VERIFIED_METADATA", "VERIFIED_METADATA",
      "UNRESOLVED", "UNRESOLVED", "UNRESOLVED", "UNRESOLVED", "UNRESOLVED",
      "PARTIAL", "FAILS_FROZEN_PA_MATCH", "UNRESOLVED", "UNRESOLVED",
      "UNRESOLVED", "DESCRIPTIVE_ONLY"),
    evidence = c(
      "USGS BBS 1966-2018 version 2018.0", "10.5066/P9HE8XYJ", "CC0 1.0",
      "No download authorised", "No download authorised", "No download authorised",
      "No focal taxa selected", "No common window selected",
      "Route-start coordinates; precise stop locations not generally recorded",
      "BBS routes once yearly; 50 stops are spatial locations, not within-cell revisits",
      "No support/grid rule selected", "No covariates selected",
      "No sensitive-taxon review", "Route/stop-scale observed source-pattern QA only"
    ),
    stringsAsFactors = FALSE
  )
}

empirical_gate_a_assess <- function(x) {
  if (!is.data.frame(x) || !identical(names(x), c("field", "status", "evidence")) ||
      !identical(x$field, empirical_gate_a_required) || any(!nzchar(x$evidence))) {
    stop("invalid empirical Gate A metadata contract", call. = FALSE)
  }
  unresolved <- x$field[x$status %in% c("UNRESOLVED", "PARTIAL", "FAILS_FROZEN_PA_MATCH")]
  list(
    schema = "EMPIRICAL_GATE_A_METADATA_RECEIPT_V1",
    candidate = "BBS_GBIF_ROUTE_SCALE_DESCRIPTIVE_QA_ONLY",
    descriptive_qa = TRUE,
    observation_law_admitted = FALSE,
    empirical_fit_admitted = FALSE,
    unresolved = unresolved,
    decision = "HOLD_FOR_FIT_AND_DOWNLOAD"
  )
}

empirical_gate_a_validate <- function(x) {
  if (!is.list(x) || !identical(x$schema, "EMPIRICAL_GATE_A_METADATA_RECEIPT_V1") ||
      !identical(x$candidate, "BBS_GBIF_ROUTE_SCALE_DESCRIPTIVE_QA_ONLY") ||
      !isTRUE(x$descriptive_qa) || isTRUE(x$observation_law_admitted) ||
      isTRUE(x$empirical_fit_admitted) ||
      !all(c("gbif_predicate", "survey_event_revisit", "privacy_review") %in% x$unresolved) ||
      !identical(x$decision, "HOLD_FOR_FIT_AND_DOWNLOAD")) {
    stop("invalid empirical Gate A decision", call. = FALSE)
  }
  invisible(TRUE)
}
