"""
num_integrate(f,a,b;order=5, method = gausslegendre)

Numerical integration helper function.
    Integrates function f on interval [a, b], using quadrature rule given by
        `method` of order `order`
"""
function num_integrate(f,a,b;order=5, method = gausslegendre)
    nodes, weights = method(order);
    t_nodes = 0.5*(b-a)*nodes+0.5(b+a)
    M = size(f(a),1)
    tmp = zeros(M)
    for i in 1:M
        g(x) = f(x)[i]
        tmp[i] = 0.5*(b-a)*dot(g.(t_nodes),weights)
    end
    return tmp
end

function inner_slopes_loop!(∇u,j,u,mesh,θ,M)
    ul = cellval_at_left(j,u,mesh)
    ur = cellval_at_right(j+1,u,mesh)
    @inbounds for i = 1:M
      ∇u[j,i] = minmod(θ*(u[j,i]-ul[i]),(ur[i]-ul[i])/2,θ*(ur[i]-u[j,i]))
    end
end

"""
function compute_slopes(u, mesh, θ, N, M, ::Type{Val{true}})
    Estimate slopes of the discretization of function u,
        using a generalized minmod limiter
    inputs:
    `u` discrete approx of function u
    `N` number of cells
    `M` number of variables
    `θ` parameter of generalized minmod limiter
    `mesh` problem mesh
    `Type{Val}` bool to choose threaded version
"""
function compute_slopes(u, mesh, θ, N, M, ::Type{Val{true}})
    ∇u = zeros(u)
    Threads.@threads for j = 1:N
        inner_slopes_loop!(∇u,j,u,mesh,θ,M)
    end
    ∇u
end

function compute_slopes(u, mesh, θ, N, M, ::Type{Val{false}})
    ∇u = zeros(u)
    for j = 1:N
        inner_slopes_loop!(∇u,j,u,mesh,θ,M)
    end
    ∇u
end

function update_dt(alg::AbstractFVAlgorithm,u::AbstractArray{T,2},Flux,
    DiffMat, CFL,mesh::Uniform1DFVMesh) where {T}
  maxρ = zero(T)
  maxρB = zero(T)
  N = numcells(mesh)
  for i in 1:N
    maxρ = max(maxρ, fluxρ(u[i,:], Flux))
    maxρB = max(maxρB, maximum(abs,eigvals(DiffMat(u[i,:]))))
  end
  CFL/(1/mesh.Δx*maxρ+1/(2*mesh.Δx^2)*maxρB)
end

function scheme_short_name(alg::AbstractFVAlgorithm)
    b = string(typeof(alg))
    replace(b[search(b, ".")[1]+1:end], r"(Algorithm)", s"")
end

function update_dt(alg::AbstractFVAlgorithm,u::AbstractArray{T,2},Flux,
    CFL,mesh::Uniform1DFVMesh) where {T}
  maxρ = zero(T)
  N = numcells(mesh)
  for i in 1:N
    maxρ = max(maxρ, fluxρ(u[i,:], Flux))
  end
  CFL/(1/mesh.Δx*maxρ)
end

@inline function maxfluxρ(u::AbstractArray{T,2},f) where {T}
    maxρ = zero(T)
    N = size(u,1)
    for i in 1:N
      maxρ = max(maxρ, fluxρ(u[i,:],f))
    end
    maxρ
end

@inline function fluxρ(uj::Vector,f)
  maximum(abs,eigvals(f(Val{:jac}, uj)))
end
