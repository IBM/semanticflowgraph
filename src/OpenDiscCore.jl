__precompile__()

module OpenDiscCore
using Reexport

include("Doctrine.jl")
include("Wiring.jl")
include("ontology/Ontology.jl")

@reexport using .Doctrine
@reexport using .Wiring
@reexport using .Ontology

end
