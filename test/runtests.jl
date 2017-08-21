using Base.Test

@testset "Doctrine" begin
  include("Doctrine.jl")
end

@testset "Diagram" begin
  include("Wiring.jl")
end

@testset "Ontology" begin
  include("Concepts.jl")
  include("Annotations.jl")
end
