
### PACKAGES 

using CSV, DataFrames 
using LinearAlgebra, StatsBase
using JuMP, Gurobi
using PyPlot, Printf

include("structures.jl")
include("functions.jl")
include("greedy.jl")
include("milp.jl")
### BEGIN

let


    #=
    df .= ifelse.(df .< 0.5, 0.0, df)
    
    score=0
    for _=1:100000
        score += generateOwnInst(2,600,30)
    end    
    println(score)
    visualizeOwnInst(1,600,30)
    sleep(20)
    generateOwnInst(80,600,30)
    =#
    ### Main algorithm
    #
    inst=80
    nclients = 600
    # instance,clientsbyday,t,t2 = readOwnInst2(inst,nclients,ndays)
    instance,demandsbyday,t = readOwnInst2(inst,nclients,30)
    nworkdays = 5
    #visualizeClustering(instance,clientsbyday,t)
    #
    init =time()
    #=
    ddayroutes0 = Vector{Vector{Route}}(undef,nworkdays)
    for d =1 : nworkdays
        ddayroutes0[d] = greedy0(clientsbyday[d].client,t)
    end
    clientsdata = subset(clientsbyday, :day => ByRow(<=(nworkdays)))
    clientstw = twpfp(ddayroutes0,select(clientsdata,["day","client","loyalty","duration"]),t)
    print(clientstw)
    demandsbyday = groupby(innerjoin(select(clientsdata,Not(:earliest,:latest)),clientstw,on = "client"),:day)
    #
    t2 = defineTravelTimes2(nclients,unique(select(demandsbyday,["client","x","y","loyalty"], ["earliest","latest"] => ByRow((e,l) -> (e+l)/2) => "windowcenter"),"client"))
    #start = time()
    #ncl = Int[]
    #nccl=Int[]
    for d=1:nworkdays
        #groupedclients[(d)].cluster = clusterClients("max",[[[c] for c in groupedclients[(d)].client]], collect(1:cli(groupedclients[(d)],1)),traveltimes,traveltimes2)
        demandsbyday[(d)].cluster = clusterClients2([[c] for c in demandsbyday[(d)].client],collect(1:size(demandsbyday[(d)],1)),t,t2)
        #push!(ncl,maximum(groupedclients[(d)].cluster ))
        #push!(nccl,size(groupedclients[(d)],1 ))
        #clientsclusters = clusterClients3(Dict(groupedclients[(d)].client .=> collect(1:size(groupedclients[(d)],1))),traveltimes,traveltimes2)
        #groupedclients[(d)].cluster = [ clientsclusters[c] for c in groupedclients[(d)].client ]
    end
    #println("moyenne clusters par jour : $(sum(ncl)/30))")
    #println("moyenne nb clients par cluster : $(sum(nccl)/sum(ncl))")
    #cumchrono = time() - start)
   # println(cumchrono)   
    =#
    costbyday=Vector{Vector{Float64}}(undef,30)
    costbyday2=Vector{Vector{Float64}}(undef,30)
    routesbyday= []
    start=time()
    #totalchrono=0
    for d =1 : 30
        #timestart=time()
        #ddayroutes,ddaycost = greedy3(nclients,demandsbyday[d],t)
        ddayroutes,ddaycost = greedy4(nclients,demandsbyday[d],t)
       #=
        if d == 2
            for r in eachindex(ddayroutes)
                println(ddayroutes[r].clients)
                println(ddayroutes[r].hours)
            end
        end
        =#
        #ddayroutes, ddaycost,cumchrono,cumchrono2 = greedy4(nclients,ddayclients,t)
        #println("Cumulated runtime of LPs : ",cumchrono," seconds, that is ",round(100*cumchrono/(timestop - timestart)),"% of runtime.")
        #println("Cumulated runtime of entire LPs : ", cumchrono2," seconds, that is ",round(100*cumchrono2/(timestop - timestart)),"% of runtime.")
        costbyday[d] = ddaycost
        push!(routesbyday,ddayroutes)
        #timestop = time()
        #totalchrono+=timestop-timestart
        #println("Runtime of greedy algorithm day $d: ",timestop - timestart," seconds.")
    end
    stop=time()
    println(stop-start," seconds")
    #=
    greedy = sum(costbyday)/nworkdays
    visualizeResults2(instance,demandsbyday,routesbyday)
    @time exact = tcvrp(instance,nclients,clientsbyday[1:nworkdays],t)
    #

    println(stop - init)

    println("\n\n $(100*(greedy-exact)/exact)%")
    println(greedy,"   ",exact)
    =#
     _,demandsbyday,_ = readOwnInst(inst,nclients,30)
    is=time()
    for d =1 : 30
        #timestart=time()
        _,ddaycost = greedy3(nclients,demandsbyday[d],t)
        costbyday2[d] = ddaycost
    end
    println(time()-is)
    costlist=Vector{Vector{Float64}}(undef,3)
    costlist2=Vector{Vector{Float64}}(undef,3)
    for cost=1:3
        cl =[]
        cl2=[]
        for d in eachindex(costbyday)
        push!(cl2,costbyday2[d][cost])
        push!(cl,costbyday[d][cost])
    end
    costlist2[cost] = cl2
    costlist[cost] = cl
end
for cost=1:3
    fig, ax = subplots(figsize=(6,10))#gridspec_kw=Dict("width_ratios"=>[1, 2]))
    ax.plot(collect(1:30),costlist2[cost],color="orange",label="glouton")
    ax.plot(collect(1:30),costlist[cost],color="b",label="clustering + glouton")
    ax.legend()
    savefig("derresults/inst_"*string(inst)*"_part_"*string(cost)*".png")
    close()
end

end