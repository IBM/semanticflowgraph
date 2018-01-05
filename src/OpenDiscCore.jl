__precompile__()

module OpenDiscCore
using Reexport

include("Doctrine.jl")
include("ontology/Ontology.jl")
include("FlowGraphs.jl")
include("SemanticEnrichment.jl")

@reexport using .Doctrine
@reexport using .Ontology
@reexport using .FlowGraphs
@reexport using .SemanticEnrichment

end
