# Writes reference-extra.csv: GLLVModels.jl fits of the data-*.csv tables written
# by gen-data-extra.R (fixed-effect covariates, random site effect, count offset,
# K = 3). NOT run by the test suite; provenance only. Needs GLLVModels.jl checked
# out at the commit pinned in GLLVMJL_COMMIT below, developed into a Julia
# project that also has CSV and DataFrames:
#   julia --project=<env> gen-reference-extra.jl <path/to/GLLVModels.jl>
# Run from this directory.
#
# Routes (all Laplace):
#   xcov   `bridge_fit(...; X = X)`, the contract behind gllvmTMB's engine =
#          "julia"; X is the p x n x 2 covariate array, one coefficient per
#          covariate shared by every trait. For Gaussian the route takes the
#          full mean structure, so X is [p trait dummies, x1, x2] (q = p + 2).
#   rowre  `fit_row_random_gllvm`: eta = beta + rho_s + Lambda z, rho_s ~
#          N(0, sigma_row^2). Poisson and Binomial have no dispersion, so the
#          model is the same as gllvmTMB's `(1 | site)` plus `latent()`.
#   offset `fit_poisson_gllvm(...; offset = O)` and, for NB2,
#          `fit_nb_gllvm_grouped(...; group = 1:p, offset = O)` (per-trait
#          dispersion, as in gllvmTMB). `bridge_fit` wires an offset only for
#          Gaussian, which gllvmTMB refuses, so the native fitters are used.
#   k3     `bridge_fit(...; d = 3)`.
#
# Recorded per case: loglik; LL = Lambda Lambda^T (p x p); gamma (covariate
# coefficients) for xcov; beta (trait intercepts) wherever the route reports
# per-trait intercepts; sigma_row for rowre; Sigma = LL + sigma_eps^2 I for
# Gaussian. All are invariant to the rotation of the latent axes.
using GLLVModels, CSV, DataFrames, LinearAlgebra
using GLLVModels.Distributions: Poisson, Binomial

const GLLVMJL_COMMIT = "aed938e1f377a2f584848c5dd100f10f1782b00d"
src = ARGS[1]
head = strip(read(`git -C $src rev-parse HEAD`, String))
head == GLLVMJL_COMMIT || error("GLLVModels.jl checkout is at $head, not $GLLVMJL_COMMIT")
dirty = strip(read(`git -C $src status --porcelain --untracked-files=no`, String))
isempty(dirty) || error("GLLVModels.jl checkout has local edits")

wide(d, col = :y) = begin
    traits = sort(unique(d.trait)); sites = sort(unique(d.site))
    M = Matrix{Float64}(undef, length(traits), length(sites))
    for r in eachrow(d)
        M[findfirst(==(r.trait), traits), findfirst(==(r.site), sites)] = r[col]
    end
    M
end

rows = DataFrame(case = String[], quantity = String[], i = Int[], j = Int[], value = Float64[])
meta = DataFrame(case = String[], family = String[], K = Int[], route = String[],
                 converged = Bool[], loglik = Float64[])
push_mat!(case, q, M) = for i in axes(M, 1), j in axes(M, 2)
    push!(rows, (case, q, i, j, M[i, j]))
end
push_vec!(case, q, v) = for i in eachindex(v)
    push!(rows, (case, q, i, 0, v[i]))
end

function record!(case, fam, K, route, L, ll, conv; beta = nothing, gamma = nothing,
                 sigma_row = nothing, sigma_eps = nothing)
    LL = L * L'; LL = (LL + LL') ./ 2
    push!(rows, (case, "loglik", 0, 0, ll))
    push_mat!(case, "LL", LL)
    beta === nothing || push_vec!(case, "beta", beta)
    gamma === nothing || push_vec!(case, "gamma", gamma)
    sigma_row === nothing || push!(rows, (case, "sigma_row", 1, 0, sigma_row))
    sigma_eps === nothing || push_mat!(case, "Sigma", LL + sigma_eps^2 * I)
    push!(meta, (case, fam, K, route, conv, ll))
    println(case, "  ", route, "  converged=", conv, "  loglik=", ll)
end

# --- xcov ------------------------------------------------------------------
for fam in ("gaussian", "poisson", "nbinom2", "binomial", "zip"), K in (1, 2)
    d = CSV.read("data-xcov-$fam.csv", DataFrame)
    Y = wide(d); p, n = size(Y)
    X = zeros(p, n, 2); X[:, :, 1] = wide(d, :x1); X[:, :, 2] = wide(d, :x2)
    if fam == "gaussian"
        # The Gaussian covariate route takes the FULL mean structure in X: p
        # per-trait intercept dummies, then the two covariates.
        Xg = zeros(p, n, p + 2)
        for t in 1:p; Xg[t, :, t] .= 1.0; end
        Xg[:, :, p + 1:p + 2] = X
        X = Xg
    end
    fit = bridge_fit(; y = Y, family = fam, d = K, X = X)
    L = Matrix{Float64}(fit.loadings)
    if fam == "gaussian"
        record!("xcov_$(fam)_K$K", fam, K, fit.model, L, fit.loglik, fit.converged;
                beta = fit.mean_coef[1:p], gamma = fit.mean_coef[p + 1:p + 2],
                sigma_eps = fit.sigma_eps)
    else
        record!("xcov_$(fam)_K$K", fam, K, fit.model, L, fit.loglik, fit.converged;
                beta = fit.alpha, gamma = fit.gamma)
    end
end

# --- rowre -----------------------------------------------------------------
for (fam, mk) in (("poisson", Poisson()), ("binomial", Binomial())), K in (1, 2)
    Y = wide(CSV.read("data-rowre-$fam.csv", DataFrame))
    fit = fit_row_random_gllvm(Y; family = mk, K = K)
    record!("rowre_$(fam)_K$K", fam, K, "row_random", Matrix{Float64}(fit.Λ), fit.loglik,
            fit.converged; beta = fit.β, sigma_row = fit.σ_row)
end

# --- offset ----------------------------------------------------------------
for fam in ("poisson", "nbinom2"), K in (1, 2)
    d = CSV.read("data-offset-$fam.csv", DataFrame)
    Y = wide(d); O = wide(d, :off); p = size(Y, 1)
    if fam == "poisson"
        fit = fit_poisson_gllvm(Y; K = K, offset = O)
    else
        fit = fit_nb_gllvm_grouped(Y; K = K, group = collect(1:p), offset = O)
    end
    record!("offset_$(fam)_K$K", fam, K, string(nameof(typeof(fit))), Matrix{Float64}(fit.Λ),
            fit.loglik, fit.converged; beta = fit.β)
end

# --- k3 --------------------------------------------------------------------
for fam in ("gaussian", "poisson")
    Y = wide(CSV.read("data-k3-$fam.csv", DataFrame))
    fit = bridge_fit(; y = Y, family = fam, d = 3)
    L = Matrix{Float64}(fit.loadings)
    if fam == "gaussian"
        record!("k3_$(fam)_K3", fam, 3, fit.model, L, fit.loglik, fit.converged;
                sigma_eps = fit.sigma_eps)
    else
        record!("k3_$(fam)_K3", fam, 3, fit.model, L, fit.loglik, fit.converged; beta = fit.alpha)
    end
end

CSV.write("reference-extra.csv", rows)
CSV.write("reference-extra-meta.csv", meta)
