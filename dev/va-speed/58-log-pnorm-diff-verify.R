## THE he() GATE for va_r3_log_pnorm_diff -- the ordinal AC crux.
##
## va_r3_log_pnorm_diff / va_r3_log1mexp are currently DEAD CODE: nothing calls them until the
## ordinal family (code 5) is wired. So they cannot be exercised through a fit, and they must be
## put on a real AD tape some other way before anyone builds on them.
##
## The test template is BUILT BY EXTRACTING the helper block verbatim from
## inst/tmb/gllvmTMB_va_r3.cpp at run time -- never by hand-copying it. A hand copy would drift
## from the production code silently, and then this test would certify something that is not
## shipped.
##
## WHAT IS BEING PROVEN, and why gr() is not enough. The template's own comment (measured,
## adversarial review 2026-08-02): an unselected non-finite CondExp branch leaves fn and gr
## finite AND CORRECT while producing a NaN HESSIAN. So this checks obj$he(), and it checks it
## in the region where the unclamped code is known to break: both category bounds more than
## 8.2924 from eta on the SAME side, where pnorm() rounds to exactly 1.0, the two log-probs are
## bit-identical, their difference is exactly 0, and log1mexp(0) = log(0) = -Inf.
##
## NEGATIVE CONTROL IS MANDATORY. A guard that has never been shown to fire is not a guard, so
## an UNCLAMPED variant is compiled alongside and must produce NaN he() on the same points. If
## both variants pass, the test is not testing anything.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
stopifnot(requireNamespace("TMB", quietly = TRUE))

SRC <- "inst/tmb/gllvmTMB_va_r3.cpp"
src <- readLines(SRC)

## ---- extract the helper block verbatim: constants through va_r3_log_pnorm_diff ----
## Anchor on the DEFINITION of the first helper in the chain (va_r3_mills_cf) and back up to its
## `template <class Type>` line -- an earlier version anchored on the va_r3_logphi_z0 constant,
## which sits AFTER mills_cf, so the extracted block referenced a function it did not contain.
i_mills <- grep("^Type va_r3_mills_cf", src)[1]
stopifnot(!is.na(i_mills))
i0 <- max(grep("^template <class Type>", src[seq_len(i_mills)]))
i1 <- grep("^Type va_r3_log_pnorm_diff", src)[1]
stopifnot(!is.na(i0), !is.na(i1), i0 < i1)
## close of va_r3_log_pnorm_diff: first line that is exactly "}" at or after i1
i2 <- i1 + which(trimws(src[(i1 + 1):length(src)]) == "}")[1]
block <- src[i0:i2]
## Assert the DEFINITIONS are present, not merely the names -- the earlier version checked
## `grepl("va_r3_mills_cf", block)` and passed on a COMMENT mentioning it, while the definition
## was missing and the compile failed.
for (fn in c("va_r3_mills_cf", "va_r3_log_pnorm", "va_r3_log1mexp", "va_r3_log_pnorm_diff"))
  stopifnot(any(grepl(paste0("^Type ", fn, "\\("), block)))
cat(sprintf("extracted %d lines of helper block from %s (lines %d-%d)\n",
            length(block), SRC, max(1, i0 - 3), i2))

## The unclamped negative control: same code, clamp ceiling pushed to 1e-300 -- the floor the
## derivation says is NOT sufficient because it rescues the series branch and leaves the direct
## branch at log(1 - exp(-1e-300)) = log(0).
block_unclamped <- sub("Type\\(-1\\.2e-16\\)", "Type(-1e-300)", block, perl = TRUE)
stopifnot(!identical(paste(block, collapse = "\n"),
                     paste(block_unclamped, collapse = "\n")))

## TWO MODES, and the split is forced by TMB, not by preference.
##
##   mode 0 -- va_r3_log1mexp ONLY. This is where the clamp lives and where the -Inf would be
##             born, and its inputs are plain reals, so a REAL AD HESSIAN is available. This is
##             the he() gate.
##   mode 1 -- the full va_r3_log_pnorm_diff, for VALUES only.
##
## Why not he() on mode 1: va_r3_log_pnorm's direct branch calls pnorm(), which TMB implements
## as an ATOMIC with no 2nd-order derivative ("Atomic 'pnorm1' order not implemented"). That
## blocks obj$he() for ANY expression routing through it, clamp or no clamp -- it is a property
## of TMB's pnorm, not of this code, so gating he() there would test TMB rather than the clamp.
mk_template <- function(body, name) {
  txt <- c("#include <TMB.hpp>", "", body, "",
           "template<class Type>",
           "Type objective_function<Type>::operator() ()",
           "{",
           "  DATA_VECTOR(a);",
           "  DATA_VECTOR(b);",
           "  DATA_INTEGER(mode);",
           "  PARAMETER(shift);",
           "  Type nll = 0.0;",
           "  if (mode == 0) {",
           "    // a(i) carries the log1mexp argument directly (<= 0).",
           "    for (int i = 0; i < a.size(); i++)",
           "      nll -= va_r3_log1mexp(a(i) + shift);",
           "  } else {",
           "    for (int i = 0; i < a.size(); i++)",
           "      nll -= va_r3_log_pnorm_diff(a(i) + shift, b(i) + shift);",
           "  }",
           "  return nll;",
           "}")
  f <- file.path(tempdir(), paste0(name, ".cpp"))
  writeLines(txt, f)
  f
}

build <- function(body, name) {
  f <- mk_template(body, name)
  owd <- setwd(dirname(f)); on.exit(setwd(owd), add = TRUE)
  st <- TMB::compile(basename(f), flags = "-O1")
  if (!identical(st, 0L)) stop("compile failed for ", name)
  dyn.load(TMB::dynlib(tools::file_path_sans_ext(f)))
  name
}

## ---- the danger region: both bounds far out on the SAME side ----
grid <- data.frame(
  a = c(-7.0,  -8.5,  -9.0, 9.0,  9.20,  30.20, -30.00, 0.5),
  b = c(-8.0,  -9.0, -10.0, 8.5,  9.00,  30.00, -30.20, -0.5)
)
grid$danger <- abs(grid$a) > 8.2924 & abs(grid$b) > 8.2924 &
  sign(grid$a) == sign(grid$b)

probe <- function(dll, a, b = 0, mode = 1L, at = 0) {
  obj <- TMB::MakeADFun(data = list(a = a, b = b, mode = as.integer(mode)),
                        parameters = list(shift = at), DLL = dll, silent = TRUE)
  g <- function(f) tryCatch(as.numeric(f(at)), error = function(e) NA_real_)
  c(fn = g(obj$fn), gr = g(obj$gr), he = g(obj$he))
}

cat("\n== building CLAMPED (as written) ==\n");   d1 <- build(block, "vartest_clamped")
cat("== building UNCLAMPED (negative control) ==\n"); d2 <- build(block_unclamped, "vartest_unclamped")

## ---- THE he() GATE, on va_r3_log1mexp where the clamp lives ----
## arg = 0 is the killer case: two log-probabilities bit-identical, difference exactly 0.
## Unclamped, log1mexp(0) takes its series branch with series_arg = 0 -> log(0) = -Inf.
l1m_args <- c(0, -1e-18, -1e-16, -1e-12, -1e-6, -0.5, -5, -40)
cat(sprintf("\n== he() GATE: va_r3_log1mexp (the clamp's home) ==\n"))
cat(sprintf("%12s | %-30s | %-30s\n", "log1mexp arg",
            "CLAMPED   fn / gr / he", "UNCLAMPED fn / gr / he"))
rows <- list()
for (a in l1m_args) {
  c1 <- probe(d1, a, mode = 0L); c2 <- probe(d2, a, mode = 0L)
  f1 <- all(is.finite(c1)); f2 <- all(is.finite(c2))
  cat(sprintf("%12.3g | %9.4f %8.3f %9.4g | %9.4f %8.3f %9.4g\n",
              a, c1[1], c1[2], c1[3], c2[1], c2[2], c2[3]))
  rows[[length(rows) + 1L]] <- data.frame(arg = a, danger = (a > -1e-15),
                                          clamped_finite = f1, unclamped_finite = f2,
                                          clamped_he = c1[3], unclamped_he = c2[3])
}
res <- do.call(rbind, rows)

## ---- VALUES of the full va_r3_log_pnorm_diff (fn only; see mk_template on why not he) ----
cat(sprintf("\n== va_r3_log_pnorm_diff VALUES (fn; he blocked by TMB's pnorm atomic) ==\n"))
cat(sprintf("%7s %7s %-7s | %14s | %14s\n", "a", "b", "danger", "CLAMPED fn", "UNCLAMPED fn"))
vrows <- list()
for (i in seq_len(nrow(grid))) {
  A <- grid$a[i]; B <- grid$b[i]
  v1 <- probe(d1, A, B, mode = 1L)[["fn"]]; v2 <- probe(d2, A, B, mode = 1L)[["fn"]]
  cat(sprintf("%7.2f %7.2f %-7s | %14.6f | %14.6f\n", A, B, grid$danger[i], v1, v2))
  vrows[[i]] <- data.frame(a = A, b = B, danger = grid$danger[i],
                           clamped_fn = v1, unclamped_fn = v2)
}
vals <- do.call(rbind, vrows)

## ---- accuracy: the two values the derivation states explicitly ----
cat("\n== accuracy against the derivation's stated values (section 5.7) ==\n")
acc <- rbind(
  data.frame(a = 9.20, b = 9.00, expect = -43.800817),
  data.frame(a = 30.20, b = 30.00, expect = -454.323660))
acc$got <- vapply(seq_len(nrow(acc)),
                  function(i) -probe(d1, acc$a[i], acc$b[i], mode = 1L)[["fn"]], numeric(1))
acc$abs_err <- abs(acc$got - acc$expect)
print(acc, row.names = FALSE, digits = 10)

## ---- verdict ----
dz <- res[res$danger, ]
pass_clamped  <- all(res$clamped_finite)
fired_control <- any(!dz$unclamped_finite)
acc_ok        <- all(is.finite(acc$abs_err)) && all(acc$abs_err < 1e-5)
vals_ok       <- all(is.finite(vals$clamped_fn))

cat("\n================ VERDICT ================\n")
cat(sprintf("he() GATE  -- clamped finite (fn, gr AND he), all %d args : %s\n",
            nrow(res), pass_clamped))
cat(sprintf("NEG CONTROL-- unclamped NON-finite on the killer arg      : %s  [%d/%d]\n",
            fired_control, sum(!dz$unclamped_finite), nrow(dz)))
cat(sprintf("VALUES     -- log_pnorm_diff finite at all %d (a,b) cells  : %s\n",
            nrow(vals), vals_ok))
cat(sprintf("ACCURACY   -- vs derivation section 5.7 (< 1e-5)          : %s\n", acc_ok))
ok <- pass_clamped && fired_control && vals_ok && acc_ok
cat(sprintf("\nGATE: %s\n", if (ok) "PASS" else "*** FAIL ***"))
if (!fired_control)
  cat("NOTE: a guard that never fires is not a guard -- if the control did not fire, this\n",
      "test proves nothing and must be fixed before the ordinal build proceeds.\n")
saveRDS(list(he_gate = res, values = vals, acc = acc, pass = ok),
        "dev/va-speed/58-log-pnorm-diff-verify.rds")
