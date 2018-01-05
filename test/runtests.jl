using Base.Test

@testset "Doctrine" begin
  include("Doctrine.jl")
end

@testset "Ontology" begin
  include("ontology/Ontology.jl")
end

@testset "SemanticEnrichment" begin
  include("SemanticEnrichment.jl")
end

@testset "IntegrationTest" begin
  include("integration/IntegrationTest.jl")
end
