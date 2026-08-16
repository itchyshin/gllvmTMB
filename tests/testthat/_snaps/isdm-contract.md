# the contract rejects malformed source, branch, support, and designs

    Code
      .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
    Condition
      Error:
      ! source must be either 'gbif' or 'survey'.

---

    Code
      .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
    Condition
      Error:
      ! gbif rows must use the count/Poisson branch.

---

    Code
      .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
    Condition
      Error:
      ! support must be known, finite, and strictly positive.

---

    Code
      .prepare_isdm_contract(.isdm_rows(), bad_x, .isdm_B())
    Condition
      Error:
      ! X must be a finite numeric matrix/data frame with one row per observation.

# the contract rejects incompatible observation records

    Code
      .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
    Condition
      Error:
      ! gbif rows must not carry a survey_event_id.

---

    Code
      .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
    Condition
      Error:
      ! pa rows must have binary 0/1 values.

---

    Code
      .prepare_isdm_contract(rows, X, B)
    Condition
      Error:
      ! survey rows must be unique by cell_id, trait, and survey_event_id; do not add a count-derived pa duplicate.

# B remains GBIF-only

    Code
      .prepare_isdm_contract(.isdm_rows(), .isdm_X(), B)
    Condition
      Error:
      ! B is GBIF-only: survey rows must be NA in every B column.
