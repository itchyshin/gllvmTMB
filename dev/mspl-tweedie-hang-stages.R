## Staged #999 8x3 Tweedie hang probe. Not CI. Not a public door.
## Times MakeADFun vs first fn/gr vs nlminb(iter.max=1).
##   GLLVMTMB_MSPL_TWEEDIE_PROBE=1 Rscript --vanilla dev/mspl-tweedie-hang-stages.R

stamp <- function(msg) {
  cat(sprintf("STAGE %.3f %s\n", proc.time()[["elapsed"]], msg))
  flush.console()
}

Sys.setenv(GLLVMTMB_MSPL_TWEEDIE_PROBE = "1")
options(warn = 1)

stamp("load_pkg")
pkgload::load_all("/private/tmp/gllvmtmb-mspl-tweedie-hang", quiet = TRUE)
stamp(sprintf("lib=%s", system.file(package = "gllvmTMB")))

dat <- data.frame(
  site = factor(rep(seq_len(8L), each = 3L)),
  trait = factor(rep(paste0("t", seq_len(3L)), 8L)),
  y = rep(c(0.5, 1, 2), length.out = 24L)
)
form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

fn_n <- 0L
gr_n <- 0L
make_n <- 0L
nlminb_n <- 0L

trace(
  TMB::MakeADFun,
  tracer = quote({
    make_n <<- make_n + 1L
    cat(sprintf("MAKEADFUN_ENTER n=%d\n", make_n))
    flush.console()
  }),
  exit = quote({
    cat(sprintf("MAKEADFUN_EXIT n=%d\n", make_n))
    flush.console()
  }),
  print = FALSE
)
trace(
  stats::nlminb,
  tracer = quote({
    nlminb_n <<- nlminb_n + 1L
    cat(sprintf("NLMINB_ENTER n=%d\n", nlminb_n))
    flush.console()
  }),
  exit = quote({
    cat(sprintf("NLMINB_EXIT n=%d\n", nlminb_n))
    flush.console()
  }),
  print = FALSE
)

ctl_ml <- gllvmTMBcontrol(
  n_init = 1L,
  init_jitter = 0,
  se = FALSE,
  warn_runaway = FALSE,
  optArgs = list(control = list(iter.max = 2L, eval.max = 8L, trace = 1))
)

stamp("ML_START")
ml <- tryCatch(
  gllvmTMB(form, data = dat, family = tweedie(), control = ctl_ml),
  error = function(e) e
)
stamp(sprintf("ML_DONE class=%s", paste(class(ml), collapse = "/")))

wrap_obj_methods <- function() {
  if (!exists("obj", inherits = TRUE)) return(invisible(NULL))
}

## After first MakeADFun, wrap fn/gr of the last TMB object if we can
## find it via a hook on the next nlminb start argument.
untrace(stats::nlminb)
trace(
  stats::nlminb,
  tracer = quote({
    nlminb_n <<- nlminb_n + 1L
    cat(sprintf("NLMINB_ENTER n=%d npar=%s\n", nlminb_n, length(start)))
    flush.console()
    if (is.function(objective)) {
      raw_fn <- objective
      raw_gr <- gradient
      fn_n <<- 0L
      gr_n <<- 0L
      objective <- function(p) {
        fn_n <<- fn_n + 1L
        t0 <- proc.time()[["elapsed"]]
        val <- raw_fn(p)
        cat(sprintf(
          "FN n=%d elapsed=%.3f val=%s\n",
          fn_n,
          proc.time()[["elapsed"]] - t0,
          if (length(val) == 1L) format(val, digits = 6) else "nonscalar"
        ))
        flush.console()
        val
      }
      if (is.function(raw_gr)) {
        gradient <- function(p) {
          gr_n <<- gr_n + 1L
          t0 <- proc.time()[["elapsed"]]
          val <- raw_gr(p)
          cat(sprintf(
            "GR n=%d elapsed=%.3f maxabs=%s\n",
            gr_n,
            proc.time()[["elapsed"]] - t0,
            format(max(abs(val)), digits = 4)
          ))
          flush.console()
          val
        }
      }
    }
  }),
  exit = quote({
    cat(sprintf("NLMINB_EXIT n=%d fn=%d gr=%d\n", nlminb_n, fn_n, gr_n))
    flush.console()
  }),
  print = FALSE
)

ctl_mspl <- gllvmTMBcontrol(
  n_init = 1L,
  init_jitter = 0,
  se = FALSE,
  warn_runaway = FALSE,
  optArgs = list(control = list(iter.max = 1L, eval.max = 4L, trace = 1))
)

stamp("MSPL_START")
mspl <- tryCatch(
  gllvmTMB(
    form,
    data = dat,
    family = tweedie(),
    estimator = "mspl",
    control = ctl_mspl
  ),
  error = function(e) e
)
stamp(sprintf(
  "MSPL_DONE class=%s msg=%s",
  paste(class(mspl), collapse = "/"),
  if (inherits(mspl, "error")) conditionMessage(mspl) else "ok"
))
