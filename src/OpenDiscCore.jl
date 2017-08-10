__precompile__()

module OpenDiscCore
using Reexport

include("Doctrine.jl")

@reexport using .Doctrine

end
