isdm_attack_verdict <- function(attack_records, ordinary_complete) {
  acceptable <- vapply(attack_records, function(record) {
    fit_refusal <- identical(record$status, "error") &&
      identical(record$failure_phase, "fit")
    warned <- identical(record$status, "fit_returned") &&
      length(record$warnings %||% character()) > 0L
    diagnosed <- identical(record$status, "fit_returned") &&
      (!identical(record$diagnostics$convergence, 0L) ||
         !isTRUE(record$diagnostics$pd_hessian))
    fit_refusal || warned || diagnosed
  }, logical(1L))
  list(
    verdict = if (ordinary_complete && length(attack_records) == 200L &&
                  all(acceptable)) "PASS" else "FAIL",
    complete = ordinary_complete && length(attack_records) == 200L,
    planned = 200L,
    acceptable = sum(acceptable),
    silent_or_unqualified = 200L - sum(acceptable)
  )
}
