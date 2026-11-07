# Writes reference.csv: GLLVModels.jl fits of the six data-*.csv tables
# (gen-data.R) at K = 1 and K = 2. NOT run by the test suite; provenance only.
# Needs GLLVModels.jl checked out at the commit pinned in GLLVMJL_COMMIT below,
# developed into a Julia project that also has CSV and DataFrames:
#   julia --project=<env> gen-reference.jl <path/to/GLLVModels.jl>
# Run from this directory.
#
# Five families go through `bridge_fit`, the flat R <-> Julia contract that
# gllvmTMB's engine = "julia" calls. Tweedie has no bridge route at this commit,
# so it is fitted natively with per-trait dispersion and per-trait power, which
# is gllvmTMB's tweedie() parameterisation.
#
# Recorded per case: loglik; LL = Lambda Lambda^T (p x p); and for Gaussian
# Sigma = Lambda Lambda^T + sigma_eps^2 I. Both are rotation invariant.
using GLLVModels, CSV, DataFrames, LinearAlgebra

const GLLVMJL_COMMIT = "aed938e1f377a2f584848c5dd100f10f1782b00d"
src = ARGS[1]
head = strip(read(`git -C $src rev-parse HEAD`, String))
head == GLLVMJL_COMMIT || error("GLLVModels.jl checkout is at $head, not $GLLVMJL_COMMIT")
dirty = strip(read(`git -C $src status --porcelain --untracked-files=no`, String))
isempty(dirty) || error("GLLVModels.jl checkout has local edits")

wide(d) = begin
    traits = sort(unique(d.trait)); sites = sort(unique(d.site))
    Y = Matrix{Float64}(undef, length(traits), length(sites))
    for r in eachrow(d)
        Y[findfirst(==(r.trait), traits), findfirst(==(r.site), sites)] = r.y
    end
    Y
end

rows = DataFrame(case = String[], quantity = String[], i = Int[], j = Int[], value = Float64[])
meta = DataFrame(case = String[], family = String[], K = Int[], route = String[],
                 converged = Bool[], loglik = Float64[])
push_mat!(case, q, M) = for i in axes(M, 1), j in axes(M, 2)
    push!(rows, (case, q, i, j, M[i, j]))
end

for fam in ("gaussian", "poisson", "nbinom2", "binomial", "zip", "tweedie"), K in (1, 2)
    Y = wide(CSV.read("data-$fam.csv", DataFrame))
    case = "$(fam)_K$(K)"
    if fam == "tweedie"
        fit = fit_gllvm(Y; family = GLLVModels.TweedieED(1.0, 1.5), K = K,
                        disp_group = :species, power_group = :species)
        L = Matrix{Float64}(fit.Λ); ll = fit.loglik; conv = fit.converged
        route = string(nameof(typeof(fit)))
    else
        fit = bridge_fit(; y = Y, family = fam, d = K)
        L = Matrix{Float64}(fit.loadings); ll = fit.loglik; conv = fit.converged
        route = fit.model
    end
    LL = L * L'; LL = (LL + LL') ./ 2
    push!(rows, (case, "loglik", 0, 0, ll))
    push_mat!(case, "LL", LL)
    if fam == "gaussian"
        push_mat!(case, "Sigma", LL + fit.sigma_eps^2 * I)
    end
    push!(meta, (case, fam, K, route, conv, ll))
    println(case, "  ", route, "  converged=", conv, "  loglik=", ll)
end

CSV.write("reference.csv", rows)
CSV.write("reference-meta.csv", meta)
