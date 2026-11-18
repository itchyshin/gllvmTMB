# Optional developer-check accounting. Inactive in normal package tests/CI.
.local_count_startup <- Sys.getenv("GLLVMTMB_CHECK_OPTIMIZER_STARTUP","")
if(nzchar(.local_count_startup)) sys.source(.local_count_startup,envir=.GlobalEnv)
rm(.local_count_startup)
