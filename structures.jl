mutable struct Client
    id::Int
    x::Int
    y::Int
    loyalty::Int
    earliest::Int
    latest::Int
end

mutable struct Route
    clients::Vector{Int}
    hours::Vector{Float64}
    penalties::Vector{Float64}
    costs::Vector{Float64}
end

 #=
mutable struct Delivery
    client::Client
    left::Union{Delivery, Nothing}
    right::Union{Delivery, Nothing}
    Delivery(c) = new( c, nothing , nothing)
    Delivery(c,l,r) = new( c, l , r)
end
=#

