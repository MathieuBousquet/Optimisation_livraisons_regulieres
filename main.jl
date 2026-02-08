
### PACKAGES 

using CSV, DataFrames 
using LinearAlgebra, StatsBase
using JuMP, Gurobi
using PyPlot

include("structures.jl")
include("functions.jl")
include("visualizations.jl")
include("greedy.jl")
include("milp.jl")


let
    ### INSTANCES

    #=
    visualizeOwnInst(80,600,30)
    sleep(20)
    generateOwnInst(80,600,30)
    =#  
    inst=80 # si >= 5, indique nb clients par jour
    nclients = 600
    ndays = 30

    # instance,clientsbyday,t,t2 = readOwnInst(inst,nclients,ndays)
    instance,demandsbyday,t,t2 = readOwnInst(inst,nclients,ndays)
    
    ### MAIN ALGORITHMS
    
    # Resolution of VRP to get history of routes
    
    #= start =time()
    nworkdays = 5
    ddayroutes0 = Vector{Vector{Route}}(undef,nworkdays)
    for d =1 : nworkdays
        ddayroutes0[d] = greedy0(clientsbyday[d].client,t)
    end
    clientsdata = subset(clientsbyday, :day => ByRow(<=(nworkdays)))
    
    # Resolution of TWPFP to add TWs
    
    clientstw = twpfp(ddayroutes0,select(clientsdata,["day","client","loyalty","duration"]),t)
    demandsbyday = groupby(innerjoin(select(clientsdata,Not(:earliest,:latest)),clientstw,on = "client"),:day)
    =#
    
    # Resolution of VRP-softTW

    # Option clustering
    startcl = time()
    for d=1:ndays
        demandsbyday[(d)].cluster = clusterClients2([[c] for c in demandsbyday[(d)].client],collect(1:size(demandsbyday[(d)],1)),t,t2)
    end
    chronocl = time() - startcl
    #visualizeClustering(instance,demandsbyday,t)   
    
    # Greedy algorithm
    costbyday=Vector{Vector{Float64}}(undef,ndays)
    routesbyday= Vector{Vector{Route}}(undef,ndays)
    startgr=time()
    for d =1 : ndays
        #ddayroutes,ddaycost = greedy2(nclients,demandsbyday[d],t)
        ddayroutes,ddaycost = greedy3(nclients,demandsbyday[d],t)
        costbyday[d] = ddaycost
        routesbyday[d]=ddayroutes
    end
    chronogr = time() - startgr
    
    ### RESULTS
    
    println("Runtime of clustering: ",chronocl," seconds")
    println("Runtime of all greedys: ",chronogr," seconds")
    println("Total runtime : ",chronocl+chronogr," seconds")
    #visualizeResults2(instance,demandsbyday,routesbyday)
    
    #=
    greedy = sum(costbyday)/nworkdays
    @time exact = tcvrp(instance,nclients,clientsbyday[1:nworkdays],t)
    println("\n\n $(100*(greedy-exact)/exact)%")
    println(greedy,"   ",exact)
    =#


end