__precompile__()

module OpenDiscCore
using Reexport

include("Doctrine.jl")
include("Wiring.jl")

@reexport using .Doctrine
@reexport using .Wiring

end
