__precompile__()

module OpenDiscCore
using Reexport

include("Doctrine.jl")
include("ontology/Ontology.jl")
include("FlowGraph.jl")

@reexport using .Doctrine
@reexport using .Ontology
@reexport using .FlowGraph

end
