using Base.Test

@testset "Doctrine" begin
  include("Doctrine.jl")
end

include("ontology/Ontology.jl")

@testset "FlowGraph" begin
  include("FlowGraph.jl")
end

include("integration/IntegrationTest.jl")
