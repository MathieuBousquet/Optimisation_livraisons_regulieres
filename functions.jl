
include("structures.jl")

function generateOwnInst(numero,nclients,ndays,radius=50,s=0,f=12*60)    
    allclients=Client[]
    monthocc=Int[]
    loyaltydico = Dict(0 => 1, 1 =>2,2=>4,3=>7,4=>11) 
    nloyalties = length(loyaltydico)-1
    # generation of new clients
    for client=1:nclients
        #coordinates 
        x = rand(-radius:radius)
        y = rand(-radius:radius)
        #loyalty loyalty and occurences 
        #occ = sample(occvalues,FrequencyWeights(occweights))
        loyalty = rand(0:nloyalties-1)
        push!(monthocc,rand(loyaltydico[loyalty]:loyaltydico[loyalty+1]-1))
        # time window
        timetodepot=round(sqrt(x^2+y^2))
        earliest = (loyalty == 0 ? s : rand(s+timetodepot:f-(nloyalties-loyalty)*60-timetodepot))
        latest= (loyalty == 0 ? f : earliest + (nloyalties-loyalty)*60)
        # Save data of client
        push!(allclients, Client(client,x,y,loyalty,earliest,latest))
    end
    #Generate daily lists of clients
    clientslists = []
    weights=copy(monthocc)
    nweights0 = 0
    ncbydaymean = sum(monthocc)/ndays
    currentmean= ncbydaymean
    noccserved = 0
    nclist = Int[]
    uppernclist=Float64[]
    lowernclist=Float64[]
    currmeanlist=Float64[]
    nctot=0
    for d in 1:ndays
        ddayclients = Int[]
        #nc = ncbydaymean ± 20%
        mu = ncbydaymean+(ncbydaymean-currentmean)
        sigma =ncbydaymean/15
        nc = round(randn()*sigma+mu)
        nc = min(max(1,nc),nclients-nweights0)
        nctot+=(nc)
        println(nc)
        push!(nclist,nc)
        push!(uppernclist,mu + 3*sigma) 
        push!(lowernclist,mu - 3*sigma)
        push!(currmeanlist,mu)
        c=1
        while c <= nc
            roulette = cumsum(weights)
            selected=findfirst(roulette .>= rand(1:roulette[end]))
            if !in(selected,ddayclients) 
                push!(ddayclients,selected)
                weights[selected] -= 1
                if weights[selected] == 0
                    nweights0 += 1
                end
                c +=1
            end
        end
        push!(clientslists,ddayclients)
        noccserved += nc
        currentmean = noccserved/d
    end
    println(nctot/30)
    #=
    println(sum(weights), "  ",nclients-nweights0,"!=0  ",length(findall(==(1),weights)),"==1")
    plot(1:ndays,nclist,"r--")
    plot(1:ndays,uppernclist,"b--")
    plot(1:ndays,lowernclist,"b--")
    plot(1:ndays,currmeanlist,"b--")
    plot(1:ndays,nclist,"r")
    show()
    =#
    permu=sample(1:length(nclist),length(nclist),replace=false)
    permute!(nclist,permu)
    #Reparation for non served occurences
    exmonthocc = monthocc[findall(!=(0),weights)]
    blacklist = Int[]
    for client in findall(!=(0),weights)
        if client == allclients[client].id
            newmonthocc = monthocc[client] - weights[client]
            if  newmonthocc == 0
                push!(blacklist,client)
            elseif newmonthocc >= loyaltydico[allclients[client].loyalty]
               monthocc[client] = newmonthocc
            else
                key = 0
                while newmonthocc >= loyaltydico[key+1]
                    key += 1
                end
               # println(client,"  ",getfield(allclients[client],:loyalty),"  ",key)
                if key == 0
                    allclients[client].earliest = s
                    allclients[client].latest = f
                else
                    extratime = (allclients[client].loyalty-key)*60 
                    if allclients[client].latest + sqrt(allclients[client].x^2+allclients[client].y^2) + extratime <= f
                        allclients[client].latest += extratime
                    elseif allclients[client].earliest - sqrt(allclients[client].x^2+allclients[client].y^2) - extratime >= s
                        allclients[client].earliest -= extratime
                    else
                        push!(blacklist,client)
                    end
                end
                allclients[client].loyalty = key
                monthocc[client] = newmonthocc
            end 
        else
            @error "impossible reparation, bad client id found"
        end
    end
        #=

    println(exmonthocc)
    println(monthocc)
    println(monthocc[findall(!=(0),weights)])
    println(blacklist)
    deleteat!(allclients, blacklist)
    deleteat!(monthocc, blacklist)
    nclients -= length(blacklist)
    =#
    if !isempty(blacklist)
        return 4#@error "Instance of only "*string(nclients)*" clients was going to be generated.\nLaunch again the generator of instances."
    end
    data = DataFrame(
        (
            day = d,
            client=allclients[client].id,
            x=allclients[client].x,
            y=allclients[client].y,
            loyalty= allclients[client].loyalty,
            occurences = monthocc[client],
            earliest=allclients[client].earliest,
            latest=allclients[client].latest,
            duration = allclients[client].latest - allclients[client].earliest,
        ) 
        for d in eachindex(clientslists)
          for client in clientslists[d]
     )
                    
    
    #Sort database and update clients identifiers
    sort!(data,["loyalty","earliest","client"])
    newids = collect(nclients:-1:1)
    oldids = data[:,"client"]
    for id in unique(oldids)
        data.client[oldids .== id] .= pop!(newids)
    end
    #print(length(newids))
    CSV.write("instances/inst_"*string(numero)*"_"*string(nclients)*"clients_"*string(ndays)*"days.csv", data)
    return nctot/30
    return @info "New instance generated with success"
end


function readOwnInst(numero,nclients,ndays)
    # read into a DataFrame
    dir = "instances/"
    filename="inst_"*string(numero)*"_"*string(nclients)*"clients_"*string(ndays)*"days"
    data = CSV.read(dir*filename*".csv",DataFrame)
    # Compute travel times
    coord = select(unique(data,"client"),["client","x","y","loyalty"], ["earliest","latest"] => ByRow((e,l) -> (e+l)/2) => "windowcenter")
    traveltimes = defineTravelTimes(coord)
    traveltimes2 = defineTravelTimes2(select(unique(data,"client"),["client","x","y","loyalty"], ["earliest","latest"] => ByRow((e,l) -> (e+l)/2) => "windowcenter"))
    #Return desired data
    return filename, groupby(data,"day"), traveltimes,traveltimes2
end


function defineTravelTimes(coord)
    # travel time between clients
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

function defineTravelTimes2(coord)
    # weighted travel time between clients
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

function getTravelTime(t,i,j)
    # Reader of travel times matrix
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

    
    

