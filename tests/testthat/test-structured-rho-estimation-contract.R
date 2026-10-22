test_that("estimated rho requires complete replicated Gaussian source groups", {
  spec <- list(status="estimated", mode="dep", d=1L)
  dat <- expand.grid(trait=1:4, visit=1:2, group=1:3)
  check <- function(data=dat, family=rep(0L,nrow(data)), ordinary=FALSE,
                    mode="dep", rank=1L, reml=FALSE) {
    spec$mode <- mode; spec$d <- rank
    .structured_rho_assert_estimation(spec, family_id=family,
      group_id=data$group, observation_id=data$visit, trait_id=data$trait,
      n_traits=length(unique(data$trait)), is_observed=rep(1L,nrow(data)),
      competing=ordinary, REML=reml)
  }
  expect_silent(check())
  expect_silent(check(mode="latent"))
  expect_error(check(subset(dat,trait==1),mode="dep"), "two traits", class="gllvmTMB_structured_rho_identification")
  expect_error(check(family=rep(2L,nrow(dat))), class="gllvmTMB_structured_rho_identification")
  expect_error(check(ordinary=TRUE), "ordinary", class="gllvmTMB_structured_rho_identification")
  expect_error(check(dat[-1L,]), "complete", class="gllvmTMB_structured_rho_identification")
  expect_error(check(subset(dat,visit==1)), "two", class="gllvmTMB_structured_rho_identification")
  expect_error(check(mode="latent",rank=2L), "rank one", class="gllvmTMB_structured_rho_identification")
  expect_error(check(subset(dat,trait<4),mode="latent"), "four", class="gllvmTMB_structured_rho_identification")
  expect_error(check(reml=TRUE), class="gllvmTMB_structured_rho_identification")
})

test_that("estimated rho requires source contrast on the resolved scale", {
  expect_error(.structured_rho_assert_source(c(1,2), 0),
    class="gllvmTMB_structured_rho_identification")
  expect_error(.structured_rho_assert_source(c(0,2), .2),
    class="gllvmTMB_structured_rho_identification")
  expect_silent(.structured_rho_assert_source(c(2,3,4), .4))
})

test_that("contrast involving only unused source levels cannot identify rho", {
  K <- matrix(c(1,0,.2,0,1,.2,.2,.2,1),3)
  D <- diag(diag(K))
  expect_equal((.2*K+.8*D)[1:2,1:2], (.8*K+.2*D)[1:2,1:2])
  d <- expand.grid(trait=1:4,obs=1:2,group=1:2)
  expect_error(.structured_rho_assert_estimation(list(status="estimated",mode="dep"),
    family_id=rep(0L,nrow(d)), group_id=d$group, observation_id=d$obs,
    trait_id=d$trait,n_traits=4L,is_observed=rep(1L,nrow(d)),n_groups=3L),
    "unobserved",class="gllvmTMB_structured_rho_identification")
})
