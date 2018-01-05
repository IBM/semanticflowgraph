module IntegrationTest
using Base.Test

@testset "FlowGraphs" begin
  include("FlowGraphs.jl")
end
@testset "SemanticEnrichment" begin
  include("SemanticEnrichment.jl")
end

end
