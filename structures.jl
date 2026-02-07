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

# travel time between clients
function defineTravelTimes(coord)
    nclients = size(coord,1)
    t = zeros(nclients+1,nclients+1)
    for i=1:nclients
        for j=i+1:nclients+1
            if j == nclients+1
                t[coord[i,"client"],j] = sqrt(coord[i,"x"]^2+coord[i,"y"]^2)
                t[j,coord[i,"client"]] = t[coord[i,"client"],j]
            else
                t[coord[i,"client"],coord[j,"client"]] = sqrt((coord[i,"x"]-coord[j,"x"])^2+(coord[i,"y"]-coord[j,"y"])^2)
                t[coord[j,"client"],coord[i,"client"]] = t[coord[i,"client"],coord[j,"client"]]
            end
        end
    end
    return t
end

# travel time between clients
function defineTravelTimes2(coord)
    nclients = size(coord,1)
    t = zeros(nclients,nclients)
    for i=1:nclients-1
        for j=i+1:nclients
                tmp = (coord[i,"x"]-coord[j,"x"])^2 + (coord[i,"y"]-coord[j,"y"])^2 + (coord[i,"loyalty"]*coord[j,"loyalty"])*(coord[i,"windowcenter"]-coord[j,"windowcenter"])^2
                t[coord[i,"client"],coord[j,"client"]] = sqrt(tmp*1/(2+(coord[i,"loyalty"])+(coord[j,"loyalty"])))
                t[coord[j,"client"],coord[i,"client"]] = t[coord[i,"client"],coord[j,"client"]]
        end
    end
    return t
end

# Reader of travel times matrix
function getTravelTime(t,i,j)
    if i == 0
        return t[end,j]
    elseif j==0
        return t[i,end]
    else
        return t[i,j]
    end
end

function clusterClients(method,clusterslist,idclusters,traveltimes,traveltimes2)
    clusters = clusterslist[end]
    if length(clusters) == 4
        return idclusters
    end
    selected = zeros(Int,2)
    best = 0
    if method == "single"
        for i=1:lastindex(clusters)-1
            for j=i+1:lastindex(clusters)
                for client1 in clusters[i]
                    for client2 in clusters[j]
                        if  best == 0 || traveltimes2[client1,client2] < best
                            best = traveltimes2[client1,client2]
                            selected[1] = i
                            selected[2] = j
                        end
                    end
                end
            end
        end
    elseif method == "max" || method == "complete"
        for i=1:lastindex(clusters)-1
            for j=i+1:lastindex(clusters)
                max = 0
                for client1 in clusters[i]
                    for client2 in clusters[j]
                        if  max == 0 || traveltimes2[client1,client2] > max
                            max = traveltimes2[client1,client2]
                        end
                    end
                end
                if best == 0 || max < best
                    best = max
                    selected[1] = i
                    selected[2] = j
                end
            end
        end
    else
        for i=1:lastindex(clusters)-1
            for j=i+1:lastindex(clusters)
                new = 0
                for client1 in clusters[i]
                    for client2 in clusters[j]
                        new += (method == "average" ? traveltimes2[client1,client2] : traveltimes2[client1,client2]^2)
                    end
                end
                new /= (length(clusters[i])*length(clusters[j]))
                if  best == 0 || new < best
                    best = new
                    selected[1] = i
                    selected[2] = j
                end
            end
        end
    end
    
    for index in eachindex(idclusters)
        if idclusters[index] == selected[2]
            idclusters[index] = selected[1]
        elseif idclusters[index] > selected[2]
            idclusters[index] -= 1
        end
    end
    #idclusters .= ifelse.(idclusters .== selected[2], selected[1],ifelse.(idclusters .> selected[2], idclusters .- 1, idclusters))
    newclusters = clusters[1:selected[1]-1]
    push!(newclusters,vcat(clusters[selected[1]],clusters[selected[2]]))
    append!(newclusters,clusters[selected[1]+1:selected[2]-1])
    append!(newclusters,clusters[selected[2]+1:end])
    push!(clusterslist,newclusters)
    clusterClients(method,clusterslist,idclusters,traveltimes,traveltimes2)
end


function clusterClients2(clusters,idclusters,traveltimes,traveltimes2)
    maxcapcity = 1*4*60
    selected1 = 0
    selected2 = 0
    best = 0
    for i=1:lastindex(clusters)-1
        for j=i+1:lastindex(clusters)
            timesbetween = maximum(traveltimes[clusters[i],clusters[j]]) + maximum(getTravelTime(traveltimes,0,clusters[i])) + maximum(getTravelTime(traveltimes,0,clusters[j]))
            timeswithin = maximum(traveltimes[clusters[i],clusters[i]]) + maximum(traveltimes[clusters[j],clusters[j]])
            #=
            timeswithin = 0
            if length(clusters[i]) > 1 && length(clusters[j]) > 1
                timeswithin += sum([minimum(traveltimes[setdiff(clusters[i],client),client]) for client in clusters[i]]) + sum([minimum(traveltimes[setdiff(clusters[j],client),client]) for client in clusters[j]])
            elseif length(clusters[i]) > 1
                timeswithin += sum([minimum(traveltimes[setdiff(clusters[i],client),client]) for client in clusters[i]])
            elseif length(clusters[j]) > 1
                timeswithin += sum([minimum(traveltimes[setdiff(clusters[j],client),client]) for client in clusters[j]])
            end
            =#
            if timeswithin + timesbetween < maxcapcity && (best == 0 || maximum(traveltimes2[clusters[i],clusters[j]]) < best)
                selected1 = i
                selected2=j
                best = maximum(traveltimes2[clusters[i],clusters[j]])
            end
        end
    end

    if best == 0
        return idclusters
    else
        for index in eachindex(idclusters)
            if idclusters[index] == selected2
                idclusters[index] = selected1
            elseif idclusters[index] > selected2
                idclusters[index] -= 1
            end
        end
        newclusters = clusters[1:selected1-1]
        push!(newclusters,vcat(clusters[selected1],clusters[selected2]))
        append!(newclusters,clusters[selected1+1:selected2-1])
        append!(newclusters,clusters[selected2+1:end])
        clusterClients2(newclusters,idclusters,traveltimes,traveltimes2)
    end
end

