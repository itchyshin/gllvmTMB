## Run from the repository root with:
## Rscript --vanilla dev/test-design86-arc5-controlled-probe.R
## This exercises only the NON_GATE2 Gate-A controlled EVA diagnostic.

source("R/eva-proto.R")
source("dev/design86-optimizer-diagnostic-harness.R")
source("dev/design86-arc5-controlled-probe.R")

receipt <- design86_arc5_controlled_probe(rebuild = FALSE)
stopifnot(
  identical(receipt$label, "NON_GATE2_CONTROLLED_EVA_DIAGNOSTIC"),
  isTRUE(receipt$parlist_roundtrip),
  identical(unname(receipt$parameter_blocks), c(1L, 5L, 4L, 4L, 2L)),
  all(vapply(receipt$gradient_checks, `[[`, logical(1), "pass")),
  receipt$telemetry$convergent$stages[[4L]]$max_abs_gradient < 1e-4,
  receipt$telemetry$nonstationary$stages[[4L]]$max_abs_gradient >= 1e-4,
  !isTRUE(receipt$telemetry$nonstationary$stages[[4L]]$max_abs_gradient < 1e-4)
)

message("Design 86 Arc-5 NON_GATE2 controlled-probe checks passed.")
