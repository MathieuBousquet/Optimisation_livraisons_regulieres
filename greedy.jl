function greedy1(nclients,ddayclients,t)
    radius=50
    s = (ddayclients[findfirst(==(0),ddayclients.loyalty), "earliest"])[1]
    f = (ddayclients[findfirst(==(0),ddayclients.loyalty), "latest"])[1]
    routes=Route[]
    chronoLP=0
    chronoLP2=0
    #clients = ddayclients.client[sortperm(getTravelTime(t,0,ddayclients.client),rev=true)]
    nearestclient = ddayclients.client[argmin(getTravelTime(t,0,ddayclients.client))]
    hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
    timetonearest = getTravelTime(t,0,nearestclient)
    push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
    ddaycost = 2*timetonearest+10*radius   
    #while !isempty(clients)
    for client in ddayclients.client[ddayclients.client .!= nearestclient]
        #client = pop!(clients)
        newroute = 0
        newpos=0
        newhours=Int[]
        newpenalties=Int[]
        newcosts= zeros(2)
        for r in eachindex(routes)
            for pos=1:length(routes[r].clients)+1
                insert!(routes[r].clients,pos,client)
                #push!(routes[r].clients,client)
                V = 0 ∪ routes[r].clients ∪ (nclients+1)
                A = [(0,routes[r].clients[1])] ∪ [(routes[r].clients[end],nclients+1)] ∪ [(routes[r].clients[index],routes[r].clients[index+1]) for index=1:length(routes[r].clients)-1]
                #println(client," route: ",r," p: ",pos)
                #println(sum(newcosts),"  ",sum(getTravelTime(t,i,j) for (i,j) in A))
                if newroute == 0 || sum(newcosts) > sum(getTravelTime(t,i,j) for (i,j) in A)
                    timestartallLP = time()
                    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
                    m = direct_model(Gurobi.Optimizer(env))
                    @variable(m, s <= D[i in V] <= f)
                    @variable(m, L[i in routes[r].clients] >= 0)
                    @variable(m, E[i in routes[r].clients] >= 0)
                    @constraint(m, cstrD[(i,j) in A] , D[i] + getTravelTime(t,i,j) == D[j])
                    @constraint(m,cstrL[i in routes[r].clients], L[i] >= D[i] - (ddayclients[ddayclients.client .== i,"latest"])[1])
                    @constraint(m,cstrE[i in routes[r].clients], E[i] >= (ddayclients[ddayclients.client .== i,"earliest"])[1] - D[i])
                    @objective(m,Min, sum((ddayclients[ddayclients.client .== i,"loyalty"])[1]*(L[i]+E[i]) for i in routes[r].clients))
                    #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
                    timestartLP= time()
                    optimize!(m)
                    timestopLP = time()
                    chronoLP += timestopLP - timestartLP
                    chronoLP2 += timestopLP - timestartallLP
                    #runtime = MOI.get(model, MOI.SolveTime())   
                    #println("  ",termination_status(m),"  ",newroute,"  ",sum(newcosts),"  ",sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                    if has_values(m) && (newroute == 0 || sum(newcosts) > sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                        newroute=r
                        newpos=pos
                        newpenalties = value.(L) .- value.(E)
                        newcosts= [sum(value.(L)) + sum(value.(E)), sum(getTravelTime(t,i,j) for (i,j) in A)]
                        newhours = Vector(value.(D))
                        #=
                        println(newpenalties)
                        =#
                    end
                end
                #pop!(routes[r].clients)
                deleteat!(routes[r].clients,pos)
            end
        end
        #println("ff")
        if newroute == 0 || sum(newcosts) - sum(routes[newroute].costs[1:2]) > 2*getTravelTime(t,0,client)+10*radius
            clientdata = ddayclients[ddayclients.client .== client,:]
            timetoclient = getTravelTime(t,0,client)
            push!(routes, Route([client],[clientdata[1,"earliest"]-timetoclient,clientdata[1,"earliest"],clientdata[1,"earliest"]+timetoclient],[0],[0,2*timetoclient,10*radius]))
            ddaycost += 2*timetoclient+10*radius
        else
            #push!(routes[newroute].clients,client)
            insert!(routes[newroute].clients,newpos,client)
            ddaycost += sum(newcosts) - sum(routes[newroute].costs[1:2])
            routes[newroute].costs[1:2] .= newcosts 
            routes[newroute].hours = newhours
            routes[newroute].penalties = newpenalties
        end
        #println(routes[newroute].clients)
    end
    return routes, ddaycost,chronoLP,chronoLP2
end


function greedy2(nclients,ddayclients,t)
    radius=50
    s = (ddayclients[findfirst(==(0),ddayclients.loyalty), "earliest"])[1]
    f = (ddayclients[findfirst(==(0),ddayclients.loyalty), "latest"])[1]
    routes=Route[]
    chronoLP=0
    chronoLP2=0
    nearestclient = ddayclients.client[argmin(getTravelTime(t,0,ddayclients.client))]
    hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
    timetonearest = getTravelTime(t,0,nearestclient)
    push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
    ddaycost = 2*timetonearest+10*radius   
    for client in ddayclients.client[ddayclients.client .!= nearestclient]
        clientdata = ddayclients[ddayclients.client .== client,:]
        timetoclient = getTravelTime(t,0,client)
        newcosts= Float64[0,2*timetoclient,10*radius]
        newroute = length(routes)+1
        newpos=1
        newhours= Float64[clientdata[1,"earliest"]-timetoclient,clientdata[1,"earliest"],clientdata[1,"earliest"]+timetoclient]
        newpenalties=Float64[0]
        for r in eachindex(routes)
            for pos=1:length(routes[r].clients)+1
                C = vcat(routes[r].clients[1:pos-1],client,routes[r].clients[pos:end]) 
                V = vcat(0,C,nclients+1)
                A = [(routes[r].clients[index],routes[r].clients[index+1]) for index in vcat(1:pos-2,pos:length(routes[r].clients)-1)]
                routeduration = routes[r].costs[2]
                if pos == 1
                    push!(A,(0,client),(client,routes[r].clients[1]),(routes[r].clients[end],nclients+1)) 
                    routeduration += getTravelTime(t,0,client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,0,routes[r].clients[pos])
                elseif pos == length(routes[r].clients)+1
                    push!(A,(0,routes[r].clients[1]),(routes[r].clients[end],client),(client,nclients+1))
                    routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,client,nclients+1) - getTravelTime(t,routes[r].clients[pos-1],nclients+1)
                else
                    push!(A,(0,routes[r].clients[1]),(routes[r].clients[pos-1],client),(client,routes[r].clients[pos]),(routes[r].clients[end],nclients+1))
                    routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,routes[r].clients[pos-1],routes[r].clients[pos])
                end
                #println("$client route: $r p: $pos rd: $routeduration s: ",sum(getTravelTime(t,i,j) for (i,j) in A))
                #println(sum(newcosts),"  ",sum(getTravelTime(t,i,j) for (i,j) in A))
                if sum(newcosts) > routeduration
                    timestartallLP = time()
                    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
                    m = direct_model(Gurobi.Optimizer(env))
                    @variable(m, s <= D[i in V] <= f)
                    @variable(m, L[i in C] >= 0)
                    @variable(m, E[i in C] >= 0)
                    @constraint(m, cstrD[(i,j) in A] , D[i] + getTravelTime(t,i,j) == D[j])
                    @constraint(m,cstrL[i in C], L[i] >= D[i] - (ddayclients[ddayclients.client .== i,"latest"])[1])
                    @constraint(m,cstrE[i in C], E[i] >= (ddayclients[ddayclients.client .== i,"earliest"])[1] - D[i])
                    @objective(m,Min, sum((ddayclients[ddayclients.client .== i,"loyalty"])[1]*(L[i]+E[i]) for i in C))
                    #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
                    timestartLP= time()
                    optimize!(m)
                    timestopLP = time()
                    chronoLP += timestopLP - timestartLP
                    chronoLP2 += timestopLP - timestartallLP
                    #runtime = MOI.get(model, MOI.SolveTime())   
                    #println("  ",termination_status(m),"  ",newroute,"  ",sum(newcosts),"  ",sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                    if has_values(m) && sum(newcosts) > sum(value.(L))+sum(value.(E))+routeduration
                        newroute=r
                        newpos=pos
                        newpenalties = value.(L) .- value.(E)
                        newcosts = [sum(value.(L)) + sum(value.(E)), routeduration,0]
                        newhours = Vector(value.(D))
                        #=
                        println(newhours)
                        println(newpenalties)
                        =#
                    end
                end
            end
        end
        #println("ff")
        if sum(newcosts) >= 2*timetoclient+10*radius
            push!(routes, Route([client],newhours,newpenalties,newcosts))
            ddaycost += 2*timetoclient+10*radius
        else
            insert!(routes[newroute].clients,newpos,client)
            ddaycost += sum(newcosts) - sum(routes[newroute].costs[1:2])
            routes[newroute].costs[1:2] = newcosts[1:2] 
            routes[newroute].hours = newhours
            routes[newroute].penalties = newpenalties
        end
    end
    return routes, ddaycost,chronoLP,chronoLP2
end

function greedy2b(nclients,ddayclients,t)
    radius=50
    s = (ddayclients[findfirst(==(0),ddayclients.loyalty), "earliest"])[1]
    f = (ddayclients[findfirst(==(0),ddayclients.loyalty), "latest"])[1]
    routes=Route[]
    chronoLP=0
    chronoLP2=0
    nearestclient = ddayclients.client[argmin(getTravelTime(t,0,ddayclients.client))]
    hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
    timetonearest = getTravelTime(t,0,nearestclient)
    push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
    ddaycost = 2*timetonearest+10*radius   
    for client in ddayclients.client[ddayclients.client .!= nearestclient]
        clientdata = ddayclients[ddayclients.client .== client,:]
        timetoclient = getTravelTime(t,0,client)
        newcosts= Float64[0,2*timetoclient,10*radius]
        newroute = length(routes)+1
        newpos=1
        newhours= Float64[clientdata[1,"earliest"]-timetoclient,clientdata[1,"earliest"],clientdata[1,"earliest"]+timetoclient]
        newpenalties=Float64[0]
        for r in eachindex(routes)
            for pos=1:length(routes[r].clients)+1
                routeduration = routes[r].costs[2]
                if pos == 1
                    routeduration += getTravelTime(t,0,client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,0,routes[r].clients[pos])
                elseif pos == length(routes[r].clients)+1
                    routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,client,nclients+1) - getTravelTime(t,routes[r].clients[pos-1],nclients+1)
                else
                    routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,routes[r].clients[pos-1],routes[r].clients[pos])
                end
                #println("$client route: $r p: $pos rd: $routeduration s: ",sum(getTravelTime(t,i,j) for (i,j) in A))
                #println(sum(newcosts),"  ",sum(getTravelTime(t,i,j) for (i,j) in A))
                if sum(newcosts) > routeduration
                    V=vcat(0,routes[r].clients[1:pos-1],client,routes[r].clients[pos:end],nclients+1)
                    timestartallLP = time()
                    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
                    m = direct_model(Gurobi.Optimizer(env))
                    @variable(m, s <= D[i in V] <= f)
                    @variable(m, L[i=2:length(V)-1] >= 0)
                    @variable(m, E[i=2:length(V)-1] >= 0)
                    @constraint(m, cstrD[i=1:length(V)-1] , D[V[i]] + getTravelTime(t,V[i],V[i+1]) == D[V[i+1]])
                    @constraint(m,cstrL[i=2:length(V)-1], L[i] >= D[V[i]] - (ddayclients[ddayclients.client .== V[i],"latest"])[1])
                    @constraint(m,cstrE[i=2:length(V)-1], E[i] >= (ddayclients[ddayclients.client .== V[i],"earliest"])[1] - D[V[i]])
                    @objective(m,Min, sum((ddayclients[ddayclients.client .== V[i],"loyalty"])[1]*(L[i]+E[i]) for i=2:length(V)-1))
                    #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
                    timestartLP= time()
                    optimize!(m)
                    timestopLP = time()
                    chronoLP += timestopLP - timestartLP
                    chronoLP2 += timestopLP - timestartallLP
                    #runtime = MOI.get(model, MOI.SolveTime())   
                    #println("  ",termination_status(m),"  ",newroute,"  ",sum(newcosts),"  ",sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                    if has_values(m) && sum(newcosts) > sum(value.(L))+sum(value.(E))+routeduration
                        newroute=r
                        newpos=pos
                        newpenalties = value.(L) .- value.(E)
                        newcosts = [sum(value.(L)) + sum(value.(E)), routeduration,0]
                        newhours = Vector(value.(D))
                        #=
                        println(newhours)
                        println(newpenalties)
                        =#
                    end
                end
            end
        end
        #println("ff")
        if sum(newcosts) >= 2*timetoclient+10*radius
            push!(routes, Route([client],newhours,newpenalties,newcosts))
            ddaycost += 2*timetoclient+10*radius
        else
            insert!(routes[newroute].clients,newpos,client)
            ddaycost += sum(newcosts) - sum(routes[newroute].costs[1:2])
            routes[newroute].costs[1:2] = newcosts[1:2] 
            routes[newroute].hours = newhours
            routes[newroute].penalties = newpenalties
        end
    end
    return routes, ddaycost,chronoLP,chronoLP2
end

function greedy2c(nclients,ddayclients,t)
    radius=50
    s = (ddayclients[findfirst(==(0),ddayclients.loyalty), "earliest"])[1]
    f = (ddayclients[findfirst(==(0),ddayclients.loyalty), "latest"])[1]
    routes=Route[]
    chronoLP=0
    chronoLP2=0
    nearestclient = ddayclients.client[argmin(getTravelTime(t,0,ddayclients.client))]
    hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
    timetonearest = getTravelTime(t,0,nearestclient)
    push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
    #ddaycost = 2*timetonearest+10*radius   
    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
    for client in ddayclients.client[ddayclients.client .!= nearestclient]
        clientdata = ddayclients[ddayclients.client .== client,:]
        timetoclient = getTravelTime(t,0,client)
        newcosts= Float64[0,2*timetoclient,10*radius]
        newroute = length(routes)+1
        newpos=1
        newhours= Float64[clientdata[1,"earliest"]-timetoclient,clientdata[1,"earliest"],clientdata[1,"earliest"]+timetoclient]
        newpenalties=Float64[0]
        for r in eachindex(routes)
            V = vcat(0,routes[r].clients,nclients+1,client)
            clientsindex =  vcat(2:lastindex(V)-2,lastindex(V))
            timestartallLP = time()
            m = direct_model(Gurobi.Optimizer(env))
            @variable(m, s <= D[i in V] <= f)
            @variable(m, L[i in clientsindex] >= 0)
            @variable(m, E[i in clientsindex] >= 0)
            cstrD = Vector{ConstraintRef}(undef,length(V)-1)
            cstrD[1] = @constraint(m, D[0] + timetoclient == D[client])
            cstrD[2] = @constraint(m, D[client] + getTravelTime(t,client,V[2]) == D[V[2]])
            for i=3:lastindex(V)-1
                cstrD[i] = @constraint(m, D[V[i-1]] + getTravelTime(t,V[i-1],V[i]) == D[V[i]])
            end
            @constraint(m,cstrL[i in clientsindex], L[i] >= D[V[i]] - (ddayclients[ddayclients.client .== V[i],"latest"])[1])
            @constraint(m,cstrE[i in clientsindex], E[i] >= (ddayclients[ddayclients.client .== V[i],"earliest"])[1] - D[V[i]])
            @objective(m,Min, sum((ddayclients[ddayclients.client .== V[i],"loyalty"])[1]*(L[i]+E[i]) for i in clientsindex))
            #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
            for pos=1:lastindex(V)-2
                routeduration = routes[r].costs[2]
                if pos == 1
                    routeduration += timetoclient + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,0,V[pos+1])
                elseif pos == lastindex(V)-2
                    routeduration += getTravelTime(t,V[pos],client) + timetoclient - getTravelTime(t,V[pos],nclients+1)
                else
                    routeduration += getTravelTime(t,V[pos],client) + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,V[pos],V[pos+1])
                end
                #println("$client route: $r p: $pos rd: $routeduration s: ",sum(getTravelTime(t,i,j) for (i,j) in A))
                #println(sum(newcosts),"  ",sum(getTravelTime(t,i,j) for (i,j) in A))
                if sum(newcosts) > routeduration
                    timestartLP= time()
                    optimize!(m)
                    timestopLP = time()
                    chronoLP += timestopLP - timestartLP
                    chronoLP2 += timestopLP - timestartallLP
                    #runtime = MOI.get(model, MOI.SolveTime())   
                    #println("  ",termination_status(m),"  ",newroute,"  ",sum(newcosts),"  ",sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                    penaltiescost = sum(value.(L)) + sum(value.(E))
                    if has_values(m) && sum(newcosts) > penaltiescost + routeduration
                        newroute=r
                        newpos=pos
                        newpenalties = Vector(value.(L) .- value.(E))
                        newcosts = [penaltiescost, routeduration]
                        newhours = Vector(value.(D))
                        #=
                        println(newhours)
                        println(newpenalties)
                        =#
                    end
                end
                if pos != lastindex(V)-2
                    delete(m,cstrD[pos])
                    delete(m,cstrD[pos+1])
                    delete(m,cstrD[pos+2])
                    cstrD[pos] = @constraint(m, D[V[pos]] + getTravelTime(t,V[pos],V[pos+1]) == D[V[pos+1]])
                    cstrD[pos+1] = @constraint(m, D[V[pos+1]] + getTravelTime(t,V[pos+1],client) == D[client])
                    cstrD[pos+2] = @constraint(m, D[client] + getTravelTime(t,client,V[pos+2]) == D[V[pos+2]])
                end
            end
        end
        #println("ff")
        if sum(newcosts) >= 2*timetoclient+10*radius
            push!(routes, Route([client],newhours,newpenalties,newcosts))
            #ddaycost += 2*timetoclient+10*radius
        else
            #ddaycost += sum(newcosts) - sum(routes[newroute].costs[1:2])
            routes[newroute].costs[1:2] = newcosts 
            routes[newroute].hours = vcat(newhours[1:newpos],pop!(newhours),newhours[newpos+1:end])
            routes[newroute].penalties = vcat(newpenalties[1:newpos-1],pop!(newpenalties),newpenalties[newpos:end])
            insert!(routes[newroute].clients,newpos,client)
        end
    end
    return routes, 0,chronoLP,chronoLP2
end

function greedy2c2(nclients,ddayclients,t)
    radius=50
    s = (ddayclients[findfirst(==(0),ddayclients.loyalty), "earliest"])[1]
    f = (ddayclients[findfirst(==(0),ddayclients.loyalty), "latest"])[1]
    routes=Route[]
    nearestclient = ddayclients.client[argmin(getTravelTime(t,0,ddayclients.client))]
    hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
    timetonearest = getTravelTime(t,0,nearestclient)
    push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
    for client in ddayclients.client[ddayclients.client .!= nearestclient]
        clientdata = ddayclients[ddayclients.client .== client,:]
        timetoclient = getTravelTime(t,0,client)
        newcosts= Float64[0,2*timetoclient,10*radius]
        newroute = length(routes)+1
        newpos=1
        newhours= Float64[clientdata[1,"earliest"]-timetoclient,clientdata[1,"earliest"],clientdata[1,"earliest"]+timetoclient]
        newpenalties=Float64[0]
        for r in eachindex(routes)
            V = vcat(0,routes[r].clients,nclients+1,client)
            clientsindex = vcat(2:lastindex(V)-2,lastindex(V))
            m = direct_model(Gurobi.Optimizer(env))
            @variable(m, s <= D[i in V] <= f)
            @variable(m, L[i in clientsindex] >= 0)
            @variable(m, E[i in clientsindex] >= 0)
            cstrD = Vector{ConstraintRef}(undef,length(V)-1)
            cstrD[1] = @constraint(m, D[0] + timetoclient == D[client])
            cstrD[2] = @constraint(m, D[client] + getTravelTime(t,client,V[2]) == D[V[2]])
            for i=3:lastindex(V)-1
                cstrD[i] = @constraint(m, D[V[i-1]] + getTravelTime(t,V[i-1],V[i]) == D[V[i]])
            end
            @constraint(m,cstrL[i in clientsindex], L[i] >= D[V[i]] - (ddayclients[ddayclients.client .== V[i],"latest"])[1])
            @constraint(m,cstrE[i in clientsindex], E[i] >= (ddayclients[ddayclients.client .== V[i],"earliest"])[1] - D[V[i]])
            @objective(m,Min, sum((ddayclients[ddayclients.client .== V[i],"loyalty"])[1]*(L[i]+E[i]) for i in clientsindex))
            #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
            for pos=1:lastindex(V)-2
                routeduration = routes[r].costs[2]
                if pos == 1
                    routeduration += timetoclient + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,0,V[pos+1])
                elseif pos == lastindex(V)-2
                    routeduration += getTravelTime(t,V[pos],client) + timetoclient - getTravelTime(t,V[pos],nclients+1)
                else
                    routeduration += getTravelTime(t,V[pos],client) + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,V[pos],V[pos+1])
                end
                #println("$client route: $r p: $pos rd: $routeduration s: ",sum(getTravelTime(t,i,j) for (i,j) in A))
                #println(sum(newcosts),"  ",sum(getTravelTime(t,i,j) for (i,j) in A))
                if sum(newcosts) > routeduration
                    optimize!(m)
                    #runtime = MOI.get(model, MOI.SolveTime())   
                    #println("  ",termination_status(m),"  ",newroute,"  ",sum(newcosts),"  ",sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                    penaltiescost = sum(value.(L)) + sum(value.(E))
                    if has_values(m) && sum(newcosts) > penaltiescost + routeduration
                        newroute=r
                        newpos=pos
                        newpenalties = (value.(L) .- value.(E))
                        newcosts = [penaltiescost, routeduration]
                        newhours = value.(D)
                        #=
                        println(newhours)
                        println(newpenalties)
                        =#
                    end
                end
                if pos != lastindex(V)-2
                    delete(m,cstrD[pos])
                    delete(m,cstrD[pos+1])
                    delete(m,cstrD[pos+2])
                    cstrD[pos] = @constraint(m, D[V[pos]] + getTravelTime(t,V[pos],V[pos+1]) == D[V[pos+1]])
                    cstrD[pos+1] = @constraint(m, D[V[pos+1]] + getTravelTime(t,V[pos+1],client) == D[client])
                    cstrD[pos+2] = @constraint(m, D[client] + getTravelTime(t,client,V[pos+2]) == D[V[pos+2]])
                end
            end
        end
        #println("ff")
        if sum(newcosts) >= 2*timetoclient+10*radius
            push!(routes, Route([client],newhours,newpenalties,newcosts))
        else
            newhours = Vector(newhours)
            routes[newroute].hours = vcat(newhours[1:newpos],pop!(newhours),newhours[newpos+1:end])
            newpenalties = Vector(newpenalties)
            routes[newroute].penalties = vcat(newpenalties[1:newpos-1],pop!(newpenalties),newpenalties[newpos:end])
            routes[newroute].costs[1:2] = newcosts 
            insert!(routes[newroute].clients,newpos,client)
        end
    end
    return routes
end


function greedy3(nclients,ddayclients,t)
    radius=50
    Delta= 4*60
    s = 0
    f = 720
    routes=Route[]
    allcandidates=DataFrame(client=Int[],route=Int[],position=Int[],newhours=Vector{Float64}[],newpenalties=Vector{Float64}[],newcosts=Tuple{Float64,Float64}[])
    nextclients = DataFrame(client=ddayclients.client,timetodepot=getTravelTime(t,0,ddayclients.client)) 
    sort!(nextclients,:timetodepot,rev=true)
    nearestclient,timetonearest = pop!(nextclients)
    hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
    push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
    ddaycost = Float64[0,2*timetonearest,10*radius]   
    lastmodifiedr = 1
    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
    while !isempty(nextclients)
        for r in eachindex(routes) 
            if r == lastmodifiedr
                V = vcat(0,routes[r].clients,nclients+1)
                clientsindex = vcat(2:lastindex(V)-1,lastindex(V)+1)
                m = direct_model(Gurobi.Optimizer(env))
                @variable(m, L[i in clientsindex] >= 0)
                @variable(m, E[i in clientsindex] >= 0)
                @variable(m, s <= D[i in vcat(V,-1)] <= f)
                cstrD = Vector{ConstraintRef}(undef,length(V))
                cstrL = Vector{ConstraintRef}(undef,length(V)-1)
                cstrE = Vector{ConstraintRef}(undef,length(V)-1)
                for i in clientsindex[1:end-1]
                    cstrL[i-1] = @constraint(m, L[i] >= D[V[i]] - (ddayclients[ddayclients.client .== V[i],"latest"])[1])
                    cstrE[i-1] = @constraint(m, E[i] >= (ddayclients[ddayclients.client .== V[i],"earliest"])[1] - D[V[i]])
                end
                for client in nextclients.client
                    push!(V,client)
                    cstrD[1] = @constraint(m, D[0] + getTravelTime(t,0,client) == D[-1])
                    cstrD[2] = @constraint(m, D[-1] + getTravelTime(t,client,V[2]) == D[V[2]])
                    for i=3:lastindex(V)-1
                        cstrD[i] = @constraint(m, D[V[i-1]] + getTravelTime(t,V[i-1],V[i]) == D[V[i]])
                    end
                    cstrL[end] = @constraint(m, L[lastindex(V)] >= D[-1] - (ddayclients[ddayclients.client .== client,"latest"])[1])
                    cstrE[end] = @constraint(m, E[lastindex(V)] >= (ddayclients[ddayclients.client .== client,"earliest"])[1] - D[-1])
                    @objective(m,Min, sum((ddayclients[ddayclients.client .== V[i],"loyalty"])[1]*(L[i]+E[i]) for i in clientsindex))
                    #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
                    for pos=1:lastindex(V)-2
                        routeduration = routes[r].costs[2]
                        if pos == 1
                            routeduration += getTravelTime(t,0,client) + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,0,V[pos+1])
                        elseif pos == lastindex(V)-2
                            routeduration += getTravelTime(t,V[pos],client) + getTravelTime(t,0,client) - getTravelTime(t,V[pos],nclients+1)
                        else
                            routeduration += getTravelTime(t,V[pos],client) + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,V[pos],V[pos+1])
                        end
                       # println("$client route: $r p: $pos rd: $routeduration")
                        #println(sum(newcosts),"  ",sum(getTravelTime(t,i,j) for (i,j) in A))
                        if routeduration <= Delta
                            optimize!(m)
                            #runtime = MOI.get(model, MOI.SolveTime())    (penaltiescost, routeduration)
                            #println("  ",termination_status(m),"  ",newroute,"  ",sum(newcosts),"  ",sum(value.(L))+sum(value.(E))+sum(getTravelTime(t,i,j) for (i,j) in A))
                            #penaltiescost = sum(value.(L)) + sum(value.(E))
                            if has_values(m)# && sum(newcosts) > penaltiescost + routeduration
                                push!(allcandidates,[client,r,pos,value.(D),value.(L) .- value.(E),(sum(value.(L))+sum(value.(E)),routeduration)])
                                #push!(allcandidates,[client,r,pos,value.(D),value.(L) .- value.(E),(objective_value(m),routeduration)])
                            end
                        end
                        if pos != lastindex(V)-2
                            delete(m,cstrD[pos])
                            delete(m,cstrD[pos+1])
                            delete(m,cstrD[pos+2])
                            cstrD[pos] = @constraint(m, D[V[pos]] + getTravelTime(t,V[pos],V[pos+1]) == D[V[pos+1]])
                            cstrD[pos+1] = @constraint(m, D[V[pos+1]] + getTravelTime(t,V[pos+1],client) == D[-1])
                            cstrD[pos+2] = @constraint(m, D[-1] + getTravelTime(t,client,V[pos+2]) == D[V[pos+2]])
                        end
                    end
                    pop!(V)
                    delete.(m,cstrD)
                    delete(m,cstrL[end])
                    delete(m,cstrE[end])
                    set_objective_sense(m, FEASIBILITY_SENSE)
                end
            end
        end
        sort!(allcandidates,:newcosts,by=sum,rev = true)
        #println("zzzzzz")
        if isempty(allcandidates) || sum(allcandidates[end,"newcosts"]) >= 2*nextclients[end,"timetodepot"]+10*radius
            nearestclient,timetonearest = pop!(nextclients)
            hourofnearest = ddayclients[ddayclients.client .== nearestclient,"earliest"][1]
            push!(routes, Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius]))
            ddaycost .+= [0,2*timetonearest,10*radius]
            lastmodifiedr = lastindex(routes)
            subset!(allcandidates, :client => ByRow(!=(nearestclient)))
        else
            newclient,newroute,newpos,newhours,newpenalties,newcosts = pop!(allcandidates)
            ddaycost[1:2] .+= newcosts .- routes[newroute].costs[1:2]
            routes[newroute].costs[1:2] .= newcosts
            routes[newroute].hours = vcat(newhours[1:newpos],pop!(newhours),newhours[newpos+1:end])
            routes[newroute].penalties = vcat(newpenalties[1:newpos-1],pop!(newpenalties),newpenalties[newpos:end])
            insert!(routes[newroute].clients,newpos,newclient)
            subset!(nextclients, :client => ByRow(!=(newclient)))
            subset!(allcandidates, ["client","route"] => ByRow((c,r) -> c != newclient && r != newroute))
            lastmodifiedr = newroute
        end
    end
    #println(routes)
    #deleteat!(findfirst(==(bestclient),nextclients),nextclients)
    #subset!(allcandidates)
    #for client in ddayclients.client[ddayclients.client .!= nearestclient]
    return routes,ddaycost
end


function greedy4(nclients,ddayclients,t)
    radius=50
    s=0
    f=720
    ddaycost=Vector{Float64}(undef,3)
    routes=Route[]
    nroutes = maximum(ddayclients.cluster)
    routes=Vector{Route}(undef,nroutes)
    env = Gurobi.Env(Dict{String,Any}("LogToConsole"=>0))
    for r =1:nroutes 
        clientsdata = subset(ddayclients, :cluster => ByRow(==(r))) 
        nextclients = clientsdata[:,"client"]
        nearestclient = nextclients[argmin(getTravelTime(t,0,nextclients))]
        timetonearest = getTravelTime(t,0,nearestclient)
        hourofnearest = clientsdata[nextclients .== nearestclient,"earliest"][1]
        routes[r] = Route([nearestclient],[hourofnearest-timetonearest,hourofnearest,hourofnearest+timetonearest],[0],[0,2*timetonearest,10*radius])
        deleteat!(nextclients, findfirst(==(nearestclient),nextclients))
        ddaycost .+= [0,2*timetonearest,10*radius]
        while !isempty(nextclients)
            newclient=0
            newpos=1
            newhours=Float64[]
            newpenalties=Float64[]
            newcosts=zeros(Float64,2)
            V = vcat(0,routes[r].clients,nclients+1)
            clientsindex = vcat(2:lastindex(V)-1,lastindex(V)+1)
            m = direct_model(Gurobi.Optimizer(env))
            @variable(m, L[i in clientsindex] >= 0)
            @variable(m, E[i in clientsindex] >= 0)
            @variable(m, s <= D[i in vcat(V,-1)] <= f)
            cstrD = Vector{ConstraintRef}(undef,length(V))
            cstrL = Vector{ConstraintRef}(undef,length(V)-1)
            cstrE = Vector{ConstraintRef}(undef,length(V)-1)
            for i in clientsindex[1:end-1]
                cstrL[i-1] = @constraint(m, L[i] >= D[V[i]] - (clientsdata[clientsdata.client .== V[i],"latest"])[1])
                cstrE[i-1] = @constraint(m, E[i] >= (clientsdata[clientsdata.client .== V[i],"earliest"])[1] - D[V[i]])
            end
            for client in nextclients
                push!(V,client)
                cstrD[1] = @constraint(m, D[0] + getTravelTime(t,0,client) == D[-1])
                cstrD[2] = @constraint(m, D[-1] + getTravelTime(t,client,V[2]) == D[V[2]])
                for i=3:lastindex(V)-1
                    cstrD[i] = @constraint(m, D[V[i-1]] + getTravelTime(t,V[i-1],V[i]) == D[V[i]])
                end
                cstrL[end] = @constraint(m, L[lastindex(V)] >= D[-1] - (clientsdata[clientsdata.client .== client,"latest"])[1])
                cstrE[end] = @constraint(m, E[lastindex(V)] >= (clientsdata[clientsdata.client .== client,"earliest"])[1] - D[-1])
                @objective(m,Min, sum((clientsdata[clientsdata.client .== V[i],"loyalty"])[1]*(L[i]+E[i]) for i in clientsindex))
                #@objective(m,Min, sum(L[i]+E[i] for i in routes[r].clients))
                for pos=1:lastindex(V)-2
                    routeduration = routes[r].costs[2]
                    if pos == 1
                        routeduration += getTravelTime(t,0,client) + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,0,V[pos+1])
                    elseif pos == lastindex(V)-2
                        routeduration += getTravelTime(t,V[pos],client) + getTravelTime(t,0,client) - getTravelTime(t,V[pos],nclients+1)
                    else
                        routeduration += getTravelTime(t,V[pos],client) + getTravelTime(t,client,V[pos+1]) - getTravelTime(t,V[pos],V[pos+1])
                    end
                    #println("$client route: $r p: $pos rd: $routeduration")
                    #if sum(newcosts) > routeduration
                    optimize!(m)
                    #println("  ",termination_status(m),"  ",sum(newcosts))
                    if has_values(m) && (newclient == 0 || sum(newcosts) > sum(value.(L)) + sum(value.(E)) + routeduration)
                        newclient = client
                        newpos = pos
                        newhours = value.(D)
                        newpenalties = value.(L) .- value.(E)
                        newcosts[1] = sum(value.(L)) + sum(value.(E)) 
                        #newcosts[1] = objective_value(m) 
                        newcosts[2] = routeduration
                    end
                    #end
                    if pos != lastindex(V)-2
                        delete(m,cstrD[pos])
                        delete(m,cstrD[pos+1])
                        delete(m,cstrD[pos+2])
                        cstrD[pos] = @constraint(m, D[V[pos]] + getTravelTime(t,V[pos],V[pos+1]) == D[V[pos+1]])
                        cstrD[pos+1] = @constraint(m, D[V[pos+1]] + getTravelTime(t,V[pos+1],client) == D[-1])
                        cstrD[pos+2] = @constraint(m, D[-1] + getTravelTime(t,client,V[pos+2]) == D[V[pos+2]])
                    end
                end
                pop!(V)
                delete.(m,cstrD)
                delete(m,cstrL[end])
                delete(m,cstrE[end])
                set_objective_sense(m, FEASIBILITY_SENSE)
            end
           # println("ff")
           ddaycost[1:2] .+= newcosts .- routes[r].costs[1:2]
            routes[r].costs[1:2] .= newcosts
            newhours = Vector(newhours)
            newpenalties = Vector(newpenalties)
            routes[r].hours = vcat(newhours[1:newpos],pop!(newhours),newhours[newpos+1:end])
            routes[r].penalties = vcat(newpenalties[1:newpos-1],pop!(newpenalties),newpenalties[newpos:end])
            insert!(routes[r].clients,newpos,newclient)
            deleteat!(nextclients,findfirst(==(newclient),nextclients))
        end
    end
    return routes,ddaycost
end




function greedy0(clientslist,t)
    radius=50
    Delta= 4*60
    s = 0
    f = 720
    routes=Route[]
    allcandidates=DataFrame(client=Int[],route=Int[],position=Int[],travelcost=Float64[])
    nextclients = DataFrame(client=clientslist,timetodepot=getTravelTime(t,0,clientslist)) 
    sort!(nextclients,:timetodepot,rev=true)
    nearestclient,timetonearest = pop!(nextclients)
    push!(routes, Route([nearestclient],[0],[0],[0,2*timetonearest,10*radius]))
    #ddaycost = 2*timetonearest+10*radius   
    lastmodifiedr = 1
    while !isempty(nextclients)
        for r in eachindex(routes) 
            if r == lastmodifiedr
                for client in nextclients.client
                    for pos=1:length(routes[r].clients)+1
                        routeduration = routes[r].costs[2]
                        if pos == 1
                            routeduration += getTravelTime(t,0,client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,0,routes[r].clients[pos])
                        elseif pos == length(routes[r].clients)+1
                            routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,0,client) - getTravelTime(t,routes[r].clients[pos-1],0)
                        else
                            routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,routes[r].clients[pos-1],routes[r].clients[pos])
                        end
                        #println("ffzzzzzzzzzqf")
                        if routeduration <= Delta
                            push!(allcandidates,[client,r,pos,routeduration])
                        end
                    end
                end
            end
        end
        sort!(allcandidates,:travelcost,rev = true)
        #println("ff")
        if isempty(allcandidates) || allcandidates[end,"travelcost"] >= 2*nextclients[end,"timetodepot"]+10*radius
            nearestclient,timetonearest = pop!(nextclients)
            push!(routes, Route([nearestclient],[0],[0],[0,2*timetonearest,10*radius]))
            #ddaycost += 2*timetonearest+10*radius
            lastmodifiedr = lastindex(routes)
            subset!(allcandidates, :client => ByRow(!=(nearestclient)))
        else
            newclient,newroute,newpos,newcost = pop!(allcandidates)
            #ddaycost += sum(newcosts) - sum(routes[newroute].costs[1:2])
            routes[newroute].costs[2] = newcost
            insert!(routes[newroute].clients,newpos,newclient)
            subset!(nextclients, :client => ByRow(!=(newclient)))
            subset!(allcandidates, ["client","route"] => ByRow((c,r) -> c != newclient && r != newroute))
            lastmodifiedr = newroute
        end
    end
    
    return routes
end


function greedy0c(clientsclusters,t)
    radius=50
    s=0
    f=720
    routes=Route[]
    nroutes = maximum(ddayclients.cluster)
    routes=Vector{Route}(undef,nroutes)
    ddaycost=0
    for r =1:nroutes 
        clientsdata = subset(clientsclusters, :cluster => ByRow(==(r))) 
        nextclients = clientsdata[:,"client"]
        nearestclient = nextclients[argmin(getTravelTime(t,0,nextclients))]
        timetonearest = getTravelTime(t,0,nearestclient)
        routes[r] = Route([nearestclient],[0],[0],[0,2*timetonearest,10*radius])
        deleteat!(nextclients, findfirst(==(nearestclient),nextclients))
       ddaycost += 2*timetonearest+10*radius
        while !isempty(nextclients)
            newclient=0
            newpos=1
            best=0
            for client in nextclients.client
                    for pos=1:length(routes[r].clients)+1
                        routeduration = routes[r].costs[2]
                        if pos == 1
                            routeduration += getTravelTime(t,0,client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,0,routes[r].clients[pos])
                        elseif pos == length(routes[r].clients)+1
                            routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,0,client) - getTravelTime(t,routes[r].clients[pos-1],0)
                        else
                            routeduration += getTravelTime(t,routes[r].clients[pos-1],client) + getTravelTime(t,client,routes[r].clients[pos]) - getTravelTime(t,routes[r].clients[pos-1],routes[r].clients[pos])
                        end
                        #println("ffzzzzzzzzzqf")
                        if best == 0 || routeduration < best
                            newclient = client
                            newpos = pos
                            best = routeduration
                        end
                    end
                end
            #println("ff")
            ddaycost += best - routes[r].costs[2]
            routes[r].costs[2] = best
            insert!(routes[r].clients,newpos,newclient)
            deleteat!(nextclients,findfirst(==(newclient),nextclients))
        end
    end
  
    return routes
end