__precompile__()

module OpenDiscCore
using Reexport

include("Doctrine.jl")
include("Wiring.jl")
include("Concepts.jl")
include("Annotations.jl")

@reexport using .Doctrine
@reexport using .Wiring
@reexport using .Concepts
@reexport using .Annotations

end
