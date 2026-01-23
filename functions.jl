
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
    coord = select(unique(data,"client"),["client","x","y"])
    traveltimes = defineTravelTimes(coord)
    #Return desired data
    return filename, groupby(data,"day"), traveltimes
end


function readOwnInst2(numero,nclients,ndays)
    # read into a DataFrame
    dir = "instances/"
    filename="inst_"*string(numero)*"_"*string(nclients)*"clients_"*string(ndays)*"days"
    data = CSV.read(dir*filename*".csv",DataFrame)
    # Compute travel times
    coord = select(unique(data,"client"),["client","x","y","loyalty"], ["earliest","latest"] => ByRow((e,l) -> (e+l)/2) => "windowcenter")
    traveltimes = defineTravelTimes(coord)
    traveltimes2 = defineTravelTimes2(select(unique(data,"client"),["client","x","y","loyalty"], ["earliest","latest"] => ByRow((e,l) -> (e+l)/2) => "windowcenter"))
    # Construct clusters of clients
    groupedclients = groupby(data,"day")
    for d=1:ndays
        #groupedclients[(d)].cluster = clusterClients("max",[[[c] for c in groupedclients[(d)].client]], collect(1:cli(groupedclients[(d)],1)),traveltimes,traveltimes2)
        groupedclients[(d)].cluster = clusterClients2([[c] for c in groupedclients[(d)].client],collect(1:size(groupedclients[(d)],1)),traveltimes,traveltimes2)
        #push!(ncl,maximum(groupedclients[(d)].cluster ))
        #push!(nccl,size(groupedclients[(d)],1 ))
        #clientsclusters = clusterClients3(Dict(groupedclients[(d)].client .=> collect(1:size(groupedclients[(d)],1))),traveltimes,traveltimes2)
        #groupedclients[(d)].cluster = [ clientsclusters[c] for c in groupedclients[(d)].client ]
    end
    #Return desired data
    return filename, groupedclients, traveltimes,traveltimes2
end

function visualizeOwnInst(numero,nclients,ndays)
    # read into a DataFrame
    prefix = "instances/visual_"
    filename="inst_"*string(numero)*"_"*string(nclients)*"clients_"*string(ndays)*"days"
    if !isdir(prefix*string(filename))
        mkdir(prefix*string(filename))
    end
    data = CSV.read("instances/"*filename*".csv",DataFrame)
    #loyaltyrange= 1/(1+maximum(data.loyalty))
    #loyaltycmap = [get_cmap(:Greys)(nuance) for nuance=loyaltyrange/2:loyaltyrange:1-(loyaltyrange/2)]
    groupsbyday = groupby(data,"day")
    for d= 1:ndays
        fig = figure(figsize=(15,8))#gridspec_kw=Dict("width_ratios"=>[1, 2]))
        suptitle("Positions and time windows of clients to serve on day "*string(d))
        ax1 = fig.add_subplot(1,2,1)
        ax2 = fig.add_subplot(1,2,2)
        loyaltygroups = groupby(groupsbyday[(d)],"loyalty")
        for ik in eachindex(keys(loyaltygroups))
            ax1.scatter(loyaltygroups[(ik)].x,loyaltygroups[(ik)].y,color="C"*string(ik-1),label="loyalty class "*string(ik-1))
            ax2.hlines(loyaltygroups[(ik)].client,loyaltygroups[(ik)].earliest,loyaltygroups[(ik)].latest,color="C"*string(ik-1))
        end
        ax1.set_title("Positions in a space of 50x50")
        ax1.set_xlabel("X")
        ax1.set_ylabel("Y")
        ax2.set_title("Time windows")
        ax2.set_xlabel("Time (in minuts)")
        ax2.set_ylabel("clients identifiers")
        ax1.legend(loc="center left",bbox_to_anchor=(1,0.5))
        tight_layout(pad=2)
        savefig(prefix*string(filename)*"/day_"*string(d))
        close()
    end
end

function visualizeClustering(instance,clientsbyday,traveltimes)
    resultsdir="results_clustering/"*instance
    if !isdir(resultsdir)
        mkdir(resultsdir)
    end
    clustersmarkers=["o","^","*"]
    clusterscolors = ["tab:blue","tab:orange","tab:green","tab:red","tab:purple","tab:brown","tab:pink","tab:gray","tab:olive","tab:cyan"]
    for d in eachindex(keys(clientsbyday))
        ddayclients = clientsbyday[d]
        _, ax1 = subplots(figsize=(8,6))
        ax1.scatter(0,0,color="black",marker="s")
        markeridx = 1
        coloridx = 1
        for cluster = 1 : maximum(ddayclients.cluster)
            clusterclients = subset(ddayclients, :cluster => ByRow(==(cluster)))
            ax1.scatter(clusterclients.x,clusterclients.y,color=clusterscolors[coloridx],marker =clustersmarkers[markeridx],label="cluster $(string(cluster)) ($(size(clusterclients,1)) clients)")
            extreme = argmax(traveltimes[clusterclients.client,clusterclients.client])
            #ax1.plot(vcat(clusterclients[extreme[1],"x"],clusterclients[extreme[2],"x"]),vcat(clusterclients[extreme[1],"y"],clusterclients[extreme[2],"y"]))
            if coloridx == lastindex(clusterscolors)
                coloridx = 1
                markeridx +=1
            else
                coloridx += 1
            end
        end
        ax1.set_title("Overview of clustering on day $(string(d))")
        ax1.set_xlabel("X")
        ax1.set_ylabel("Y")
        ax1.legend(loc="center left",bbox_to_anchor=(1,0.5))
        tight_layout()
        savefig(resultsdir*"/day_"*string(d))
        close()
          
    end
end

function visualizeResults2(instance,clientsbyday,resultroutes)
    resultsdir="results/"*instance
    if !isdir(resultsdir)
        mkdir(resultsdir)
    end
    routemarkers=Any["o","d","p"]
    append!(routemarkers,[(numsides,category,angle) for numsides=3:5 for category in (isodd(numsides) ? [1,2] : [0,1,2]) for angle in 90*(isodd(numsides) ? [0,1,2,3] : [0,0.5])])
    #routemarkers=["o","*","+","x","p","d","h","^","v","<",">","1","2","3","4"]
    #routemarkers=["o","d","p","^","v","<",">","*","+"]
    for d in eachindex(resultroutes)
        stream=open(resultsdir*"/day_"*string(d)*".txt","w")
        fig = figure(figsize=(20,12))#gridspec_kw=Dict("width_ratios"=>[1, 2]))
        suptitle("Overview of solutions routes in space and time on day "*string(d))
        ax1 = fig.add_subplot(1,3,1)
        ax2 = fig.add_subplot(1,3,2)
        ax3 = fig.add_subplot(1,3,3)
        ddayclients = clientsbyday[(d)]
        permudico = Dict(ddayclients.client .=> sortperm(ddayclients.client))
        loyaltygroups = groupby(ddayclients,"loyalty")
        for ik in eachindex(keys(loyaltygroups))
            #ax1.scatter(loyaltygroups[(ik)].x,loyaltygroups[(ik)].y,color="C"*string(ik-1),label="loyalty class "*string(ik-1))
            ax2.hlines(get.([permudico],loyaltygroups[(ik)].client,missing),loyaltygroups[(ik)].earliest,loyaltygroups[(ik)].latest,color="C"*string(ik-1),label="Loyalty class "*string(ik-1))
        end
        ax1.scatter(0,0,color="black",marker="s")
        routepaths=[]
        
        for route in resultroutes[d]   
            write(stream,"Route "*string(findfirst(==(route),resultroutes[d]))*" :\n")
            write(stream,"costs = ("*string(route.costs[1])*","*string(route.costs[2])*","*string(route.costs[3])*")")
            totalcost = sum(route.costs)
            write(stream,", ie ("*string(round(100*route.costs[1]/totalcost))*"%,"*string(round(100*route.costs[2]/totalcost))*"%,"*string(round(100*route.costs[3]/totalcost))*"%)\n")
            write(stream,string(length(route.clients))*" clients served\n")
            for idx in eachindex(route.hours)
                if(idx == 1 || idx == length(route.hours))
                    write(stream,(idx == 1 ? "  route start" : "  route end  ")*" - hour = "*string(round(route.hours[idx]))*"\n")
                else
                    write(stream,"  client "*string(route.clients[idx-1])*"  - hour = "*string(round(route.hours[idx]))*" - penalty = "*string(round(route.penalties[idx-1]))*"\n")
                end
            end
            xc = [ ddayclients[ddayclients.client .== c,"x"][1] for c in route.clients ]
            yc =  [ ddayclients[ddayclients.client .== c,"y"][1] for c in route.clients ]
            lc = [ ddayclients[ddayclients.client .== c,"loyalty"][1] for c in route.clients ]
            ax1.plot(vcat(0,xc,0),vcat(0,yc,0),color="black",alpha=0.5,lw=1)
            ax1.scatter(xc,yc,color="C".*string.(lc),marker=routemarkers[findfirst(==(route),resultroutes[d])])
            ax2.plot(route.hours,vcat(0,get.([permudico],route.clients,missing),length(permudico)+1),c="black",alpha=0.5,lw=1)
            newpath = ax2.scatter(route.hours,vcat(0,get.([permudico],route.clients,missing),length(permudico)+1),color="black",alpha=0.5,marker=routemarkers[findfirst(==(route),resultroutes[d])])
            ax3.barh(get.([permudico],route.clients,missing),route.penalties,color="C".*string.(lc))
            push!(routepaths,newpath)
        end
        ax1.set_title("Positions in a space of 50x50")
        ax1.set_xlabel("X")
        ax1.set_ylabel("Y")
        ax1.legend([path for path in routepaths],"Route ".*string.(eachindex(routepaths)),loc="center left",bbox_to_anchor=(1,0.5))
        ax2.set_title("Time windows")
        ax2.set_xlabel("Time (in minuts)")
        ax2.set_ylabel("clients identifiers")
        ax2.set_yticks(sortperm(ddayclients.client), labels=string.(ddayclients.client))
        ax2.legend(loc="center left",bbox_to_anchor=(1,0.5))
        ax3.set_title("Penalties of advance\n(negative values) and delay (positive values)")
        ax3.set_xlabel("Time (in minuts)")
        ax3.set_ylabel("clients identifiers")
        ax3.set_yticks(sortperm(ddayclients.client), labels=string.(ddayclients.client))
        tight_layout()
        savefig(resultsdir*"/day_"*string(d))
        close()
        
        close(stream)
    
          
    end
end

function visualizeResults(instance,clientsbyday,resultroutes)
    resultsdir="results/"*instance
    if !isdir(resultsdir)
        mkdir(resultsdir)
    end
    nclients = maximum(maximum(clientsbyday[k].client) for k in keys(clientsbyday))
    for d in eachindex(resultroutes)
        stream=open(resultsdir*"/day_"*string(d)*".txt","w")
        fig = figure(figsize=(20,12))#gridspec_kw=Dict("width_ratios"=>[1, 2]))
        suptitle("Overview of solutions routes in space and time on day "*string(d))
        ax1 = fig.add_subplot(1,3,1)
        ax2 = fig.add_subplot(1,3,2)
        ax3 = fig.add_subplot(1,3,3)
        ddayclients = clientsbyday[(d)]
        loyaltygroups = groupby(ddayclients,"loyalty")
        for ik in eachindex(keys(loyaltygroups))
            ax1.scatter(loyaltygroups[(ik)].x,loyaltygroups[(ik)].y,color="C"*string(ik-1),label="Loyalty class "*string(ik-1))
            ax2.hlines(loyaltygroups[(ik)].client,loyaltygroups[(ik)].earliest,loyaltygroups[(ik)].latest,color="C"*string(ik-1),label="Loyalty class "*string(ik-1))
        end
        ax1.scatter(0,0,color="black",marker="s")
        for route in resultroutes[d]   
            write(stream,"Route "*string(findfirst(==(route),resultroutes[d]))*" :\n")
            write(stream,"costs = ("*string(route.costs[1])*","*string(route.costs[2])*","*string(route.costs[3])*")")
            totalcost = sum(route.costs)
            write(stream,", ie ("*string(round(100*route.costs[1]/totalcost))*"%,"*string(round(100*route.costs[2]/totalcost))*"%,"*string(round(100*(route.costs[3])/totalcost))*"%)\n")
            write(stream,string(length(route.clients))*" clients served\n")
            for idx in eachindex(route.hours)
                if(idx == 1 || idx == length(route.hours))
                    write(stream,(idx == 1 ? "  departure from" : "  return to")*" depot - hour = "*string(route.hours[idx])*"\n")
                else
                    write(stream,"  client "*string(route.clients[idx-1])*" - hour = "*string(route.hours[idx])*" - penalty = "*string(route.penalties[idx-1])*"\n")
                end
            end
            xc = vcat(0,[ ddayclients[ddayclients.client .== c,"x"][1] for c in route.clients ],0)
            yc =  vcat(0,[ ddayclients[ddayclients.client .== c,"y"][1] for c in route.clients ],0)
            lc = [ ddayclients[ddayclients.client .== c,"loyalty"][1] for c in route.clients ]
            ax1.plot(xc,yc,color="black",alpha=0.5,lw=1)
            ax2.plot(route.hours,vcat(0,route.clients,nclients+1),c="black",alpha=0.5,lw=1)
            ax3.barh(route.clients,route.penalties,color="C".*string.(lc))
        end
        ax1.set_title("Positions in a space of 50x50")
        ax1.set_xlabel("X")
        ax1.set_ylabel("Y")
        ax1.legend(loc="center left",bbox_to_anchor=(1,0.5))
        ax2.set_title("Time windows")
        ax2.set_xlabel("Time (in minuts)")
        ax2.set_ylabel("clients identifiers")
        ax2.legend(loc="center left",bbox_to_anchor=(1,0.5))
        ax3.set_title("Penalties of advance\n(negative values) and delay (positive values)")
        ax3.set_xlabel("Time (in minuts)")
        ax3.set_ylabel("clients identifiers")
        tight_layout()
        #subplots_adjust(left=0.1,right=0.9,wspace=1)
        savefig(resultsdir*"/day_"*string(d))
        close()
        close(stream)
    end
end

    
    

