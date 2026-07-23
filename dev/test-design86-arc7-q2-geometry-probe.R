source('R/eva-proto.R')
source('dev/design86-optimizer-diagnostic-harness.R')
source('dev/design86-arc7-q2-geometry-probe.R')
out <- file.path(tempdir(), 'design86-arc7-q2-test')
unlink(out, recursive = TRUE)
ledger <- design86_arc7_q2_geometry_probe(out, rebuild = FALSE)
stopifnot(
  identical(ledger$label, 'NON_GATE2_Q2_GEOMETRY_DIAGNOSTIC'),
  identical(ledger$decision, 'PARK_PENDING_REVIEW'),
  all(file.exists(file.path(out, c('ledger.json', 'a0_chain.csv', 'a1_q2_map.csv', 'a2_fd.csv', 'a3_hessian.csv', 'a3_trace.csv', 'a3_rank.csv'))))
)
message('Design 86 Arc-7 NON_GATE2 q2 geometry-probe checks passed.')
