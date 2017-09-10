export PCGPChromo, process

# PCGP with mutated positions and constant scalar inputs, no constants

type Node
    connections::Array{Int64}
    f::Function
    param::Float64
    active::Bool
    output::Float64
end

type PCGPChromo <: Chromosome
    genes::Array{Float64}
    nodes::Array{Node}
    outputs::Array{Int64}
    nin::Int64
    nout::Int64
end

function Node(ins::Array{Int64}, f::Function, p::Float64, a::Bool)
    Node(ins, f, p, a, 0.0)
end

function snap(fc::Array{Float64}, p::Array{Float64})::Array{Int64}
    map(x->indmin(abs.(p-x)), fc)
end

function recur_active!(active::BitArray, connections::Array{Int64}, ind::Int64)::Void
    if ~active[ind]
        active[ind] = true
        for i in 1:2
            recur_active!(active, connections, connections[i, ind])
        end
    end
end

function find_active(nin::Int64, outputs::Array{Int64}, connections::Array{Int64})::BitArray
    active = BitArray(size(connections, 2)+nin)
    active[1:nin] = true
    for i in eachindex(outputs)
        recur_active!(active, connections, outputs[i])
    end
    active[1:nin] = false
    active
end

function PCGPChromo(genes::Array{Float64}, nin::Int64, nout::Int64)::PCGPChromo
    nodes = Array{Node}(nin+Config.num_nodes)
    rgenes = reshape(genes[(nin+nout+1):end], (Config.num_nodes, 5))
    positions = [genes[1:nin]; rgenes[:, 1]]
    fc = [rgenes[:, 2]'; rgenes[:, 3]']
    connections = [zeros(Int64, 2, nin) snap(fc, positions)]
    outputs = snap(genes[nin+(1:nout)], positions)
    f = Config.functions[Int64.(ceil.(rgenes[:, 4]*length(Config.functions)))]
    functions = [[x->x[i] for i in 1:nin];f]
    params = [zeros(nin); rgenes[:, 5]]
    active = find_active(nin, outputs, connections)
    for i in 1:(nin+Config.num_nodes)
        nodes[i] = Node(connections[:, i], functions[i], params[i], active[i])
    end
    PCGPChromo(genes, nodes, outputs, nin, nout)
end

function PCGPChromo(nin::Int64, nout::Int64)::PCGPChromo
    PCGPChromo(rand(nin+nout+5*Config.num_nodes), nin, nout)
end

function PCGPChromo(c::PCGPChromo)::PCGPChromo
    genes = deepcopy(c.genes)
    mutations = rand(size(genes)) .< Config.mutation_rate
    genes[mutations] = rand(sum(mutations))
    PCGPChromo(genes, c.nin, c.nout)
end

function process(c::PCGPChromo, inps::Array{Float64})::Array{Float64}
    for i in 1:c.nin
        c.nodes[i].output = inps[i]
    end
    for n in c.nodes
        if n.active
            n.output = n.f(c.nodes[n.connections[1]].output,
                           c.nodes[n.connections[2]].output,
                           n.param)
        end
    end
    map(x->c.nodes[x].output, c.outputs)
end
