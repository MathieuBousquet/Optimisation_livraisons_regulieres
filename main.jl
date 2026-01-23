
### PACKAGES 

using CSV, DataFrames 
using LinearAlgebra, StatsBase
using JuMP, Gurobi
using PyPlot

include("structures.jl")
include("functions.jl")
include("greedy.jl")
include("milp.jl")
### BEGIN

let

    ### Instances

    #=
    visualizeOwnInst(1,600,30)
    sleep(20)
    generateOwnInst(80,600,30)
    =#  
    inst=80
    nclients = 600
    ndays = 30
    # instance,clientsbyday,t,t2 = readOwnInst2(inst,nclients,ndays)
    instance,demandsbyday,t = readOwnInst2(inst,nclients,ndays)
    nworkdays = 5

    ### Main algorithms
    
    #init =time()
    #=
    # Resolution of VRP to get history of routes
    
    ddayroutes0 = Vector{Vector{Route}}(undef,nworkdays)
    for d =1 : nworkdays
        ddayroutes0[d] = greedy0(clientsbyday[d].client,t)
    end
    clientsdata = subset(clientsbyday, :day => ByRow(<=(nworkdays)))
    
    # Resolution of TWPFP to add TWs
    
    clientstw = twpfp(ddayroutes0,select(clientsdata,["day","client","loyalty","duration"]),t)
    print(clientstw)
    demandsbyday = groupby(innerjoin(select(clientsdata,Not(:earliest,:latest)),clientstw,on = "client"),:day)
    
    # Resolution of VRP-softTW

    =#
    # Option clustering
    t2 = defineTravelTimes2(unique(select(demandsbyday,["client","x","y","loyalty"], ["earliest","latest"] => ByRow((e,l) -> (e+l)/2) => "windowcenter"),"client"))
    #start = time()
    #ncl = Int[]
    #nccl=Int[]
    for d=1:nworkdays
        #groupedclients[(d)].cluster = clusterClients("max",[[[c] for c in groupedclients[(d)].client]], collect(1:cli(groupedclients[(d)],1)),traveltimes,traveltimes2)
        demandsbyday[(d)].cluster = clusterClients2([[c] for c in demandsbyday[(d)].client],collect(1:size(demandsbyday[(d)],1)),t,t2)
        #push!(ncl,maximum(groupedclients[(d)].cluster ))
        #push!(nccl,size(groupedclients[(d)],1 ))
        #clientsclusters = clusterClients3(Dict(groupedclients[(d)].client .=> collect(1:size(groupedclients[(d)],1))),traveltimes,traveltimes2)
    end
    #println("moyenne clusters par jour : $(sum(ncl)/30))")
    #println("moyenne nb clients par cluster : $(sum(nccl)/sum(ncl))")
    #cumchrono = time() - start)
    # println(cumchrono)   

    # Greedy algorithm
    costbyday=Vector{Vector{Float64}}(undef,30)
    routesbyday= []
    start=time()
    for d =1 : 30
        #timestart=time()
        #ddayroutes,ddaycost = greedy2(nclients,demandsbyday[d],t)
        ddayroutes,ddaycost = greedy3(nclients,demandsbyday[d],t)
        #ddayroutes, ddaycost,cumchrono,cumchrono2 = greedy3(nclients,ddayclients,t)
        #println("Cumulated runtime of LPs : ",cumchrono," seconds, that is ",round(100*cumchrono/(timestop - timestart)),"% of runtime.")
        #println("Cumulated runtime of entire LPs : ", cumchrono2," seconds, that is ",round(100*cumchrono2/(timestop - timestart)),"% of runtime.")
        costbyday[d] = ddaycost
        push!(routesbyday,ddayroutes)
        #timestop = time()
        #println("Runtime of greedy algorithm day $d: ",timestop - timestart," seconds.")
    end
    
    ### Results
    
    stop=time()
    println(stop-start," seconds")
    #println(stop - init)
    #=
    visualizeResults2(instance,demandsbyday,routesbyday)
    greedy = sum(costbyday)/nworkdays
    @time exact = tcvrp(instance,nclients,clientsbyday[1:nworkdays],t)
    #


    println("\n\n $(100*(greedy-exact)/exact)%")
    println(greedy,"   ",exact)
    =#


end