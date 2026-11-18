args <- commandArgs(TRUE)
.libPaths(unique(c(args[1],path.expand('~/R/lib'),.libPaths())))
suppressPackageStartupMessages(library(gllvmTMB))
options(gllvmTMB.quiet_grammar_notes=TRUE)
ex <- readRDS(system.file('extdata','examples','behavioural-reaction-norm-example.rds',package='gllvmTMB'))
fit <- suppressMessages(suppressWarnings(gllvmTMB(ex$formula_long,data=ex$data_long,
  trait=ex$fit_args$trait,unit=ex$fit_args$unit,unit_obs=ex$fit_args$unit_obs,
  family=ex$fit_args$family,control=gllvmTMBcontrol(se=TRUE))))
h <- check_gllvmTMB(fit)
print(h[h$component %in% c('optimizer_convergence','max_gradient'),])
receipt <- list(library=find.package('gllvmTMB'),version=as.character(packageVersion('gllvmTMB')),
  convergence=fit$opt$convergence,objective=fit$opt$objective,fit_health=fit$fit_health,
  diagnostic=h[h$component %in% c('optimizer_convergence','max_gradient'),],fixture_md5=unname(tools::md5sum(system.file('extdata','examples','behavioural-reaction-norm-example.rds',package='gllvmTMB'))))
saveRDS(receipt,args[2]);jsonlite::write_json(receipt,sub('rds$','json',args[2]),auto_unbox=TRUE,pretty=TRUE)
