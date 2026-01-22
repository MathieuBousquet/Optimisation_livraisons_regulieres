function tcvrp(inst,nclients,clientsbyday,t)
model = Model(Gurobi.Optimizer)
set_time_limit_sec(model,600)

J= collect(1:length(clientsbyday))
V=collect(1:2)
p_loc = 500
S=0
F=720
p_traj=1
C=Int[]#collect(1:nclients)
Delta= 4*60

for j in J
    union!(C,clientsbyday[(j)].client)
end
#=
# Decision variables
X = Dict{Tuple{Int, Int, Int, Int}, VariableRef}()
Y = Dict{Tuple{Int, Int, Int}, VariableRef}()
D = Dict{Tuple{Int, Int}, VariableRef}()
E = Dict{Tuple{Int, Int}, VariableRef}()
L = Dict{Tuple{Int, Int}, VariableRef}()

@variable(model,  S<=e[c in C] <= F)

for j in J 
    for c in vcat(clientsbyday[(j)].client,nclients+1)
        if c != nclients+1
            L[(j,c)] = @variable(model, lower_bound = 0)
            E[(j,c)] = @variable(model, lower_bound = 0)
            D[(j,c)] = @variable(model,lower_bound = 0)
        end
        for v in V
            Y[(j, v, c)] = @variable(model, binary = true)
            for cp in vcat(setdiff(clientsbyday[(j)].client,c),nclients+1)
                X[(j, v, c, cp)] = @variable(model, binary = true)
            end
        end
    end
end

=#

@variable(model, X[j in J, v in V, c in vcat(clientsbyday[(j)].client,nclients+1), cp in vcat(setdiff(clientsbyday[(j)].client,c),nclients+1)],Bin)
@variable(model, Y[j in J, v in V, c in vcat(clientsbyday[(j)].client,nclients+1)],Bin)
@variable(model, D[j in J, c in clientsbyday[(j)].client] >= 0)
@variable(model, E[j in J, c in clientsbyday[(j)].client] >= 0)
@variable(model, L[j in J, c in clientsbyday[(j)].client] >= 0)
@variable(model, S <= e[ c in C] <= F)

# Objective
@objective(model, Min,
    (1 / length(J)) * sum(
        p_loc * sum(Y[j,v,nclients+1] for v in V) +
        p_traj * sum(sum(sum(t[c,cp]*X[j,v,c,cp] for cp in vcat(setdiff(clientsbyday[(j)].client, c),nclients+1)) for c in vcat(clientsbyday[(j)].client,nclients+1)) for v in V) +
        sum(clientsbyday[(j)][clientsbyday[(j)].client .== c,"loyalty"][1] * (E[j,c] + L[j,c]) for c in clientsbyday[(j)].client)
    for j in J)
)


# Constraints
@constraint(model, [j in J, c in clientsbyday[(j)].client], E[j,c] >= e[c] - D[j,c])
@constraint(model, [j in J, c in clientsbyday[(j)].client], L[j,c] >= D[j,c] - (e[c] + clientsbyday[(j)][clientsbyday[(j)].client .== c,"duration"][1]))

@constraint(model, [j in J, v in V, c in clientsbyday[(j)].client, cp in setdiff(clientsbyday[(j)].client, c)],
    D[j,c] + t[c,nclients+1] - (D[j,cp] - t[cp,nclients+1]) <= Delta + (F - S) * (2 - Y[j,v,cp] - Y[j,v,c])
)

@constraint(model, [j in J, v in V, c in clientsbyday[(j)].client, cp in setdiff(clientsbyday[(j)].client,c)],
    D[j,cp] <= D[j,c] + t[c, cp] + F * (1 - X[j,v,c,cp])
)

@constraint(model, [j in J, v in V, c in clientsbyday[(j)].client, cp in setdiff(clientsbyday[(j)].client,c)],
    D[j,cp] >= D[j,c]  + t[c, cp] - F * (1 - X[j,v,c,cp])
)

@constraint(model, [j in J, cp in clientsbyday[(j)].client], D[j,cp] >= S + t[cp,nclients+1])
@constraint(model, [j in J, c in clientsbyday[(j)].client],  D[j,c] <= F  - t[c,nclients+1])

@constraint(model, [j in J, v in V, cp in clientsbyday[(j)].client],
    X[j,v,nclients+1,cp] + sum(X[j,v,c,cp] for c in setdiff(clientsbyday[(j)].client,cp)) == Y[j,v,cp]
)

@constraint(model, [j in J, v in V, c in clientsbyday[(j)].client],
    X[j,v,c,nclients+1] + sum(X[j,v,c,cp] for cp in setdiff(clientsbyday[(j)].client, c)) == Y[j,v,c]
)

@constraint(model, [j in J, c in clientsbyday[(j)].client], sum(Y[j,v,c] for v in V) == 1)
@constraint(model, [j in J, v in V, c in clientsbyday[(j)].client], Y[j,v,c] <= Y[j,v,nclients+1])
@constraint(model, [j in J, v in V[2:end]], Y[j,v,nclients+1] <= Y[j,v-1,nclients+1])

optimize!(model)
#=
for j in J
    #println(size(clientsbyday[(j)],1))
    for c in vcat(clientsbyday[(j)].client,nclients+1)
        print("D[",j,",",c,"]=",( c != nclients+1 ? value(D[j,c]) : 0),"   ")
        for cp in vcat(setdiff(clientsbyday[(j)].client,c),nclients+1)
            print("$c -> $cp = ",value(X[j, 1, c, cp]),"   ")
        end
        println()
    end
end
=#
for j in J
    println(size(clientsbyday[(j)],1))
    for v in V
        print("Y0[",j,",",v,"]=",value(Y[j,v,nclients+1]),"   ")
    end
        println()
end
return objective_value(model)

end


function twpfp(ddayroutes0,clientsdata,t)

    # Assume the following sets are predefined:
    J=collect(1:length(ddayroutes0))
    C=unique(clientsdata.client)
    clientsbyday = groupby(clientsdata,:day)
    S=0
    F=720
    model = Model(Gurobi.Optimizer)
    
    # === Decision Variables ===
    @variable(model, E[ j in J,c in clientsbyday[j].client] >= 0)
    @variable(model, L[ j in J,c in clientsbyday[j].client] >= 0)
    @variable(model, D[ j in J,c in clientsbyday[j].client] >= 0)
    @variable(model, e[c in C], lower_bound = S, upper_bound = F)
    @variable(model, delta[j in J, v in eachindex(ddayroutes0[j])], Bin)
    
    # === Objective Function ===
    @objective(model, Min,
        (1 / length(J)) * sum(
            sum(clientsbyday[j][clientsbyday[j].client .== c,"loyalty"][1] * (E[j,c] + L[j,c]) for c in clientsbyday[j].client)
            for j in J
        )
        )
        
        # === Constraints ===
    # Early/Late deviation constraints
    @constraint(model, [j in J, c in clientsbyday[j].client], E[j,c] >= e[c] - D[j,c])
    @constraint(model, [j in J, c in clientsbyday[j].client], L[j,c] >= D[j,c] - (e[c] + clientsbyday[j][clientsbyday[j].client .== c, "duration"][1]))

    # Time propagation constraint (only enforced when delta == 1 and Y, X == 1)
    
    @constraint(model, [j in J, v in eachindex(ddayroutes0[j]), pos=1:lastindex(ddayroutes0[j][v].clients)-1],
                    D[j,ddayroutes0[j][v].clients[pos]] + delta[j, v] *t[ddayroutes0[j][v].clients[pos], ddayroutes0[j][v].clients[pos+1]]
                    == D[j,ddayroutes0[j][v].clients[pos+1]] + (1 - delta[j, v]) * t[ddayroutes0[j][v].clients[pos+1], ddayroutes0[j][v].clients[pos]]
                )

    # Time window bounds
    @constraint(model, [j in J, c in clientsbyday[j].client], D[j,c] >= S + getTravelTime(t,0,c))
    @constraint(model, [j in J, c in clientsbyday[j].client], D[j,c] <= F - getTravelTime(t,0,c))

    optimize!(model)
    
    clientstw = DataFrame(client=Int64[],earliest=Float64[],latest=Float64[])
    for c in C
        push!(clientstw,(c , value(e[c]),value(e[c])+clientsdata[clientsdata.client .== c,"duration"][1]))
    end
    #=
    for j in [2]
        for c in clientsbyday[j].client
            print("D[$j,$c]=$(value(D[j,c]))    ")
        end
        println()
    end
    =#
    return clientstw
end